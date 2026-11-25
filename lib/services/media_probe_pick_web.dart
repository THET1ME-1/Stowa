import 'dart:async';
import 'dart:io';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import 'media_probe.dart';

/// Разбор своих роликов на этой платформе: в браузере — его же проигрыватель.
MediaProbe platformMediaProbe() => const WebMediaProbe();

/// Ролик глазами браузера: `<video>` читает длину и размер, кадр рисуется на `<canvas>` и
/// уходит в JPEG. Браузер читает не всё, что телефон (H.265 у Firefox, старые AVI), — такой
/// ролик остаётся без кадров, как у телефона без кодека.
class WebMediaProbe implements MediaProbe {
  const WebMediaProbe();

  static const _patience = Duration(seconds: 15);

  @override
  Future<VideoInfo?> probe(String path) async {
    final video = await _open(path);
    if (video == null) return null;
    try {
      final seconds = video.element.duration;
      if (!seconds.isFinite || seconds <= 0) return null;
      final width = video.element.videoWidth;
      final height = video.element.videoHeight;
      return VideoInfo(length: Duration(milliseconds: (seconds * 1000).round()), width: width > 0 ? width : null, height: height > 0 ? height : null);
    } finally {
      video.close();
    }
  }

  @override
  Future<List<bool>> frames(String path, List<Duration> at, List<String> outs, {int maxSide = 720}) async {
    final written = [for (final _ in at) false];
    final video = await _open(path);
    if (video == null) return written;
    try {
      final element = video.element;
      final width = element.videoWidth;
      final height = element.videoHeight;
      if (width <= 0 || height <= 0) return written;
      final scale = math.min(1.0, maxSide / math.max(width, height));
      final canvas = web.HTMLCanvasElement()
        ..width = (width * scale).round()
        ..height = (height * scale).round();
      final context = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
      if (context == null) return written;
      for (var index = 0; index < at.length && index < outs.length; index++) {
        if (!await _seek(element, at[index])) continue;
        context.drawImage(element, 0, 0, canvas.width, canvas.height);
        final bytes = await _jpeg(canvas);
        if (bytes == null) continue;
        await File(outs[index]).writeAsBytes(bytes);
        written[index] = true;
      }
    } on Object {
      // браузер не отдал кадр: что успели — записано
    } finally {
      video.close();
    }
    return written;
  }

  // ролик из файла сайта в проигрыватель: ссылка blob живёт, пока не закрыли
  Future<_Opened?> _open(String path) async {
    final String url;
    try {
      final bytes = await File(path).readAsBytes();
      url = web.URL.createObjectURL(web.Blob(<JSAny>[bytes.toJS].toJS));
    } on Object {
      return null;
    }
    final element = web.HTMLVideoElement()
      ..muted = true
      ..preload = 'auto'
      ..playsInline = true;
    final ready = Completer<bool>();
    void finish(bool ok) => ready.isCompleted ? null : ready.complete(ok);
    final loaded = ((web.Event _) => finish(true)).toJS;
    final failed = ((web.Event _) => finish(false)).toJS;
    element
      ..addEventListener('loadeddata', loaded)
      ..addEventListener('error', failed)
      ..src = url;
    final ok = await ready.future.timeout(_patience, onTimeout: () => false);
    element
      ..removeEventListener('loadeddata', loaded)
      ..removeEventListener('error', failed);
    final opened = _Opened(element, url);
    if (!ok) {
      opened.close();
      return null;
    }
    return opened;
  }

  Future<bool> _seek(web.HTMLVideoElement element, Duration moment) async {
    final done = Completer<bool>();
    final seeked = ((web.Event _) => done.isCompleted ? null : done.complete(true)).toJS;
    element.addEventListener('seeked', seeked);
    try {
      // конец ролика иногда не перематывается: кадр за 50 мс до конца
      final end = element.duration - 0.05;
      element.currentTime = math.min(moment.inMilliseconds / 1000, end > 0 ? end : 0);
      return await done.future.timeout(_patience, onTimeout: () => false);
    } finally {
      element.removeEventListener('seeked', seeked);
    }
  }

  Future<List<int>?> _jpeg(web.HTMLCanvasElement canvas) async {
    final done = Completer<web.Blob?>();
    canvas.toBlob(((web.Blob? blob) => done.complete(blob)).toJS, 'image/jpeg', 0.85.toJS);
    final blob = await done.future.timeout(_patience, onTimeout: () => null);
    if (blob == null) return null;
    return (await blob.arrayBuffer().toDart).toDart.asUint8List();
  }
}

class _Opened {
  _Opened(this.element, this.url);

  final web.HTMLVideoElement element;
  final String url;

  void close() {
    element
      ..removeAttribute('src')
      ..load();
    web.URL.revokeObjectURL(url);
  }
}
