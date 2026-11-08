import 'package:flutter/services.dart';

/// Что система знает о своём ролике.
class VideoInfo {
  const VideoInfo({required this.length, this.width, this.height});

  final Duration length;

  /// Размер, как видит человек: вертикальное видео — выше, чем шире.
  final int? width;
  final int? height;
}

/// Свой ролик глазами системы: длина и кадры. На телефоне — канал `stowa/media`
/// (`MediaMetadataRetriever`), в тестах — подмена.
abstract class MediaProbe {
  /// Длина и размер; система ролик не прочитала — null.
  Future<VideoInfo?> probe(String path);

  /// Кадры в моменты [at] файлами JPEG по путям [outs], не больше [maxSide] по длинной стороне.
  /// На каждый кадр — записан ли он.
  Future<List<bool>> frames(String path, List<Duration> at, List<String> outs, {int maxSide = 720});
}

class ChannelMediaProbe implements MediaProbe {
  const ChannelMediaProbe();

  static const _channel = MethodChannel('stowa/media');

  @override
  Future<VideoInfo?> probe(String path) async {
    final info = await _channel.invokeMapMethod<String, Object?>('probe', {'path': path});
    final ms = info?['ms'];
    if (info == null || ms is! int) return null;
    return VideoInfo(length: Duration(milliseconds: ms), width: info['width'] as int?, height: info['height'] as int?);
  }

  @override
  Future<List<bool>> frames(String path, List<Duration> at, List<String> outs, {int maxSide = 720}) async {
    final written = await _channel.invokeListMethod<bool>('frames', {
      'path': path,
      'ms': [for (final moment in at) moment.inMilliseconds],
      'outs': outs,
      'maxSide': maxSide,
    });
    return written ?? [for (final _ in at) false];
  }
}
