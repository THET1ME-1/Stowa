import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/settings_repository.dart';
import '../domain/telegram_updates.dart';
import 'capture_service.dart';

/// Токен не принят, бот недоступен или Telegram ответил ошибкой.
class TelegramFailure implements Exception {
  const TelegramFailure(this.message, {this.badToken = false});

  final String message;
  final bool badToken;

  @override
  String toString() => 'TelegramFailure: $message';
}

/// Что видно в настройках: подключён ли бот и кого он слушает.
class TelegramState {
  const TelegramState({this.botName, this.ownerName});

  final String? botName;
  final String? ownerName;

  bool get connected => botName != null;
}

/// Свой бот человека. Приложение само забирает сообщения через getUpdates,
/// сервер не нужен. Слушает только хозяина — первого, кто написал боту.
class TelegramService {
  TelegramService({required CaptureService capture, required SharedPreferences prefs, required KeyStore tokens, required http.Client http, required Directory inbox})
    : _capture = capture, // ignore: prefer_initializing_formals
      _prefs = prefs, // ignore: prefer_initializing_formals
      _tokens = tokens, // ignore: prefer_initializing_formals
      _http = http, // ignore: prefer_initializing_formals
      _inbox = inbox; // ignore: prefer_initializing_formals

  final CaptureService _capture;
  final SharedPreferences _prefs;
  final KeyStore _tokens;
  final http.Client _http;
  final Directory _inbox;
  final _changes = StreamController<void>.broadcast();
  bool _pulling = false;

  static const _offset = 'tg_offset';
  static const _ownerId = 'tg_owner_id';
  static const _ownerName = 'tg_owner_name';
  static const _botName = 'tg_bot_name';

  TelegramState get state => TelegramState(botName: _prefs.getString(_botName), ownerName: _prefs.getString(_ownerName));

  Stream<TelegramState> watch() async* {
    yield state;
    yield* _changes.stream.map((_) => state);
  }

  /// Проверить токен через getMe и запомнить бота. Новый бот — новый хозяин и счёт с нуля.
  Future<String> connect(String rawToken) async {
    final token = rawToken.trim();
    final me = await _call(token, 'getMe');
    final name = (me as Map<String, Object?>)['username'] as String? ?? '';
    await _tokens.write(token);
    await _prefs.setString(_botName, name);
    for (final key in [_offset, _ownerId, _ownerName]) {
      await _prefs.remove(key);
    }
    _changes.add(null);
    return name;
  }

  Future<void> disconnect() async {
    await _tokens.write(null);
    for (final key in [_offset, _ownerId, _ownerName, _botName]) {
      await _prefs.remove(key);
    }
    _changes.add(null);
  }

  /// Забрать новые сообщения и сохранить каждое вещью. Возвращает, сколько сохранено.
  /// Offset двигается только после записи, поэтому обрыв посередине ничего не теряет.
  Future<int> pull() async {
    if (_pulling) return 0;
    _pulling = true;
    try {
      final token = await _tokens.read();
      if (token == null) return 0;
      final offset = _prefs.getInt(_offset) ?? 0;
      final raw = await _call(token, 'getUpdates', {'offset': '$offset', 'timeout': '0'});
      final batch = parseUpdates({'result': raw});
      if (batch.lastUpdateId == null) return 0;

      var ownerId = _prefs.getInt(_ownerId);
      if (ownerId == null && batch.senders.isNotEmpty) {
        ownerId = batch.senders.first.id;
        await _prefs.setInt(_ownerId, ownerId);
        await _prefs.setString(_ownerName, batch.senders.first.name);
        _changes.add(null);
      }

      var saved = 0;
      for (final message in batch.messages) {
        // чужие сообщения не сохраняются: бот найти может любой
        if (message.fromId == ownerId) {
          await _save(token, message);
          saved++;
        }
        await _prefs.setInt(_offset, message.updateId + 1);
      }
      await _prefs.setInt(_offset, batch.lastUpdateId! + 1);
      return saved;
    } finally {
      _pulling = false;
    }
  }

  Future<void> _save(String token, IncomingMessage message) async {
    final files = <PickedFile>[];
    for (final ref in message.files) {
      final file = await _download(token, ref);
      if (file != null) files.add(file);
    }
    await _capture.capture(CaptureInput(text: message.text, files: files));
    if (files.isEmpty) return;
    // файлы копируются в папку приложения после возврата: скачанное удаляем только потом
    await _capture.settled();
    for (final file in files) {
      final downloaded = File(file.path);
      if (downloaded.existsSync()) await downloaded.delete();
    }
  }

  /// Скачать файл бота. Больше 20 МБ Bot API не отдаёт — тогда вещь сохранится без него.
  Future<PickedFile?> _download(String token, TelegramFileRef ref) async {
    try {
      final info = await _call(token, 'getFile', {'file_id': ref.fileId}) as Map<String, Object?>;
      final path = info['file_path'] as String?;
      if (path == null) return null;
      final response = await _http.get(Uri.parse('https://api.telegram.org/file/bot$token/$path')).timeout(const Duration(seconds: 90));
      if (response.statusCode != 200) return null;
      await _inbox.create(recursive: true);
      final target = File(p.join(_inbox.path, '${DateTime.now().microsecondsSinceEpoch}_${p.basename(ref.fileName)}'));
      await target.writeAsBytes(response.bodyBytes);
      return PickedFile(path: target.path, mime: ref.mime, size: response.bodyBytes.length);
    } on TelegramFailure {
      return null;
    }
  }

  Future<Object?> _call(String token, String method, [Map<String, String>? query]) async {
    final http.Response response;
    try {
      response = await _http.get(Uri.https('api.telegram.org', '/bot$token/$method', query)).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const TelegramFailure('нет ответа');
    } on SocketException catch (error) {
      throw TelegramFailure(error.message);
    } on http.ClientException catch (error) {
      throw TelegramFailure(error.message);
    }
    final Map<String, Object?> json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
    } catch (_) {
      throw TelegramFailure('ответ ${response.statusCode}', badToken: response.statusCode == 401 || response.statusCode == 404);
    }
    if (json['ok'] != true) {
      throw TelegramFailure(json['description'] as String? ?? 'ошибка', badToken: response.statusCode == 401 || response.statusCode == 404);
    }
    return json['result'];
  }
}
