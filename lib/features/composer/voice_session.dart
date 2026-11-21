import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

import '../../services/capture_service.dart';

const waveBars = 34;

/// Одна запись голосового: время, уровни для волны, файл в конце.
class VoiceSession extends ChangeNotifier {
  VoiceSession(this._folder);

  final Directory _folder;
  final _recorder = AudioRecorder();
  final List<double> levels = List.filled(waveBars, 0.1, growable: true);
  DateTime? _startedAt;
  StreamSubscription<Amplitude>? _amplitude;
  Timer? _tick;

  Duration get elapsed => _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);

  /// Начать запись. Нет доступа к микрофону — false.
  /// [checked] — право уже проверено снаружи: плагин без Activity его не видит и отвечает «нет».
  Future<bool> start({bool checked = false}) async {
    if (!checked && !await _recorder.hasPermission()) return false;
    await _folder.create(recursive: true);
    final path = p.join(_folder.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.$_extension');
    // браузер пишет Opus в webm: AAC его записыватель не умеет, и запись падала как «нет доступа»
    await _recorder.start(RecordConfig(encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc), path: path);
    _startedAt = DateTime.now();
    // громкость в децибелах от −50 до 0 превращается в высоту палочки
    _amplitude = _recorder.onAmplitudeChanged(const Duration(milliseconds: 90)).listen((amplitude) {
      levels
        ..removeAt(0)
        ..add(((amplitude.current + 50) / 50).clamp(0.08, 1.0));
      notifyListeners();
    });
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => notifyListeners());
    return true;
  }

  Future<PickedFile?> stop() async {
    _stopTicking();
    final seconds = elapsed.inSeconds;
    final path = await _recorder.stop();
    if (path == null) return null;
    // в браузере записыватель отдаёт ссылку «blob:…» в память страницы, а не файл: байты
    // ложатся файлом в ту же папку черновиков, дальше всё как на телефоне
    if (kIsWeb) {
      final bytes = await XFile(path).readAsBytes();
      if (bytes.isEmpty) return null;
      final file = File(p.join(_folder.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.$_extension'));
      await file.writeAsBytes(bytes, flush: true);
      return PickedFile(path: file.path, mime: _mime, size: bytes.length, seconds: seconds);
    }
    final file = File(path);
    if (!file.existsSync()) return null;
    return PickedFile(path: path, mime: _mime, size: file.lengthSync(), seconds: seconds);
  }

  static String get _extension => kIsWeb ? 'webm' : 'm4a';

  static String get _mime => kIsWeb ? 'audio/webm' : 'audio/mp4';

  Future<void> cancel() async {
    _stopTicking();
    await _recorder.cancel();
  }

  void _stopTicking() {
    _amplitude?.cancel();
    _tick?.cancel();
  }

  @override
  void dispose() {
    _stopTicking();
    _recorder.dispose();
    super.dispose();
  }
}

/// Брошенные записи старше суток удаляются при запуске. Запись из [waiting] ещё
/// ждёт переноса во вложения (телефон выключили до того): её не трогаем.
Future<void> cleanVoiceDrafts(Directory folder, DateTime now, {Set<String> waiting = const {}}) async {
  if (!folder.existsSync()) return;
  await for (final entity in folder.list()) {
    if (waiting.contains(entity.path)) continue;
    if (entity is File && now.difference(entity.statSync().modified) > const Duration(days: 1)) {
      await entity.delete();
    }
  }
}
