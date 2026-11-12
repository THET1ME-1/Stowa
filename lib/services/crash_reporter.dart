import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/settings_repository.dart';
import 'crash_report.dart';

/// Свой Bugsink, без сервисов Google. Ключ открытый: он только принимает события.
final _endpoint = Uri.parse('https://bugsink.togetherly.day/api/3/envelope/');
const _key = 'c94514b828594315be1f835d37f7e340';

/// Телефон, версия Android и приложения: файл кладёт Android при запуске процесса.
const _aboutFile = 'about.json';
const _mostPerRun = 10;
const _mostWaiting = 20;
const _patience = Duration(seconds: 10);

/// Сборщик для окна или фоновой задачи. В отладке выключен: ошибки и так в консоли.
CrashReporter crashReporterFor(Directory appSupport, SettingsRepository settings, String window) =>
    CrashReporter(folder: Directory(p.join(appSupport.path, 'crashes')), window: window, enabled: () => !kDebugMode && settings.crashReports);

/// Сбор ошибок. Ошибка сперва ложится в файл — приложение может тут же закрыться, —
/// а уходит на сервер при следующем удобном случае. В отчёте только то, что положено
/// сюда: вид ошибки, место в коде, версия, телефон. Текста заметок и имён файлов нет.
class CrashReporter {
  CrashReporter({required this.folder, required this.window, required this.enabled, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Папка очереди: `crashes` в папке приложения. В неё же пишет Android.
  final Directory folder;

  /// Какое окно ловит: `main`, `share`, `quick` или `background`.
  final String window;

  /// Включены ли отчёты: спрашивается перед каждой записью и отправкой.
  final bool Function() enabled;
  final DateTime Function() _clock;

  final _seen = <String>{};
  var _written = 0;
  late final Map<String, Object?> _about = _readAbout();

  /// Ловить всё, что не поймал код: ошибки внутри Flutter и вне его. Прежние
  /// обработчики остаются: в консоль ошибка пишется как раньше.
  void attach() {
    final flutterBefore = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.silent) record(details.exception, details.stack ?? StackTrace.empty, library: details.library);
      flutterBefore?.call(details);
    };
    final platformBefore = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack);
      return platformBefore?.call(error, stack) ?? false;
    };
  }

  /// Записать ошибку в очередь. Никогда не падает сама.
  void record(Object error, StackTrace stack, {String? library}) {
    try {
      if (!enabled()) return clear();
      final crash = CrashRecord(
        id: const Uuid().v4().replaceAll('-', ''),
        at: _clock(),
        platform: 'dart',
        type: crashType(error),
        message: crashMessage(error),
        frames: crashFrames(stack),
        window: window,
        library: library,
        release: _about['release'] as String?,
        environment: kReleaseMode ? 'production' : (kProfileMode ? 'profile' : 'debug'),
        os: _about['os'] as String?,
        model: _about['model'] as String?,
        maker: _about['maker'] as String?,
      );
      // ошибка в кадре повторяется десятки раз в секунду: одной записи хватит
      if (_written >= _mostPerRun || !_seen.add(crash.fingerprint)) return;
      _written++;
      folder.createSync(recursive: true);
      // место под новую запись: самые старые уходят
      final waiting = _waiting();
      for (var i = 0; i <= waiting.length - _mostWaiting; i++) {
        waiting[i].deleteSync();
      }
      File(p.join(folder.path, '${crash.at.millisecondsSinceEpoch}-${crash.id}.json')).writeAsStringSync(jsonEncode(crash.toJson()));
    } catch (_) {}
  }

  /// Отправить очередь. Принятое и отвергнутое сервером стирается; нет сети или
  /// сервер лежит — всё ждёт следующего раза.
  Future<void> send([http.Client? client]) async {
    final own = client == null ? http.Client() : null;
    client ??= own!;
    try {
      if (!enabled()) return clear();
      for (final file in _waiting()) {
        final CrashRecord crash;
        try {
          crash = CrashRecord.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, Object?>);
        } catch (_) {
          file.deleteSync();
          continue;
        }
        final event = jsonEncode(crash.toEvent());
        final envelope = [
          jsonEncode({'event_id': crash.id, 'sent_at': _clock().toUtc().toIso8601String()}),
          jsonEncode({'type': 'event', 'length': utf8.encode(event).length}),
          event,
        ].join('\n');
        final reply = await client
            .post(
              _endpoint,
              headers: {'Content-Type': 'application/x-sentry-envelope', 'X-Sentry-Auth': 'Sentry sentry_version=7, sentry_key=$_key, sentry_client=stowa/1'},
              body: utf8.encode(envelope),
            )
            .timeout(_patience);
        if (reply.statusCode == 429 || reply.statusCode >= 500) return;
        file.deleteSync();
      }
    } catch (_) {
    } finally {
      own?.close();
    }
  }

  /// Стереть очередь: человек выключил отчёты.
  void clear() {
    try {
      for (final file in _waiting()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  /// Записи от старых к новым: имя файла начинается со времени.
  List<File> _waiting() {
    if (!folder.existsSync()) return [];
    final files = [
      for (final file in folder.listSync().whereType<File>())
        if (file.path.endsWith('.json') && p.basename(file.path) != _aboutFile) file,
    ];
    return files..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
  }

  Map<String, Object?> _readAbout() {
    try {
      return jsonDecode(File(p.join(folder.path, _aboutFile)).readAsStringSync()) as Map<String, Object?>;
    } catch (_) {
      return const {};
    }
  }
}
