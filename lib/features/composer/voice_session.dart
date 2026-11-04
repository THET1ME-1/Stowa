import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    await _folder.create(recursive: true);
    final path = p.join(_folder.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
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
    final file = File(path);
    if (!file.existsSync()) return null;
    return PickedFile(path: path, mime: 'audio/mp4', size: file.lengthSync(), seconds: seconds);
  }

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

/// Старые записи, которые уже скопированы во вложения, удаляются при запуске.
Future<void> cleanVoiceDrafts(Directory folder, DateTime now) async {
  if (!folder.existsSync()) return;
  await for (final entity in folder.list()) {
    if (entity is File && now.difference(entity.statSync().modified) > const Duration(days: 1)) {
      await entity.delete();
    }
  }
}
