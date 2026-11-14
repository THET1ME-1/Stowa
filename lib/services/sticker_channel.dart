import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Где окно стикера и каков экран, в точках. Начало координат — левый верхний угол
/// свободной части экрана (под строкой состояния), ширина и высота — её размер.
typedef StickerPlacement = ({Rect window, Size screen});

/// Что служба сообщает стикеру: его утащили пальцем или экран стал другим.
sealed class StickerEvent {
  const StickerEvent();
}

/// Палец отпустил стикер: левый верхний угол окна теперь здесь.
class StickerMoved extends StickerEvent {
  const StickerMoved(this.at);

  final Offset at;
}

/// Поворот или складной экран: свободная часть экрана теперь такая, окно — здесь.
class StickerScreen extends StickerEvent {
  const StickerScreen(this.placement);

  final StickerPlacement placement;
}

/// Канал `stowa/sticker` в движке одного стикера. Окно двигает и меняет Kotlin
/// (перетаскивание нативное, ровно за пальцем), а решает, куда сворачиваться и куда
/// раскрываться, Dart: раскладка — `domain/sticker_geometry.dart`.
abstract class StickerChannel {
  Stream<StickerEvent> get events;

  /// Где окно сейчас и каков экран.
  Future<StickerPlacement> placement();

  /// Поставить окно сразу: стикер поменял высоту.
  Future<void> frame(Rect window);

  /// Плавно перевести окно в [window] за [duration] по кривой emphasized; завершается в конце.
  Future<void> morph(Rect window, Duration duration);

  /// Снять стикер: окно и движок уходят.
  Future<void> remove();

  /// Открыть заметку в Stowa.
  Future<void> openApp(String noteId);
}

class MethodStickerChannel implements StickerChannel {
  MethodStickerChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'moved':
          final at = (call.arguments as Map).cast<String, num>();
          _events.add(StickerMoved(Offset(at['x']!.toDouble(), at['y']!.toDouble())));
        case 'screen':
          _events.add(StickerScreen(_placementOf(call.arguments as Map)));
      }
    });
  }

  static const _channel = MethodChannel('stowa/sticker');
  final _events = StreamController<StickerEvent>.broadcast();

  static StickerPlacement _placementOf(Map raw) {
    final value = raw.cast<String, num>();
    double of(String key) => value[key]!.toDouble();
    return (window: Rect.fromLTWH(of('x'), of('y'), of('w'), of('h')), screen: Size(of('screenW'), of('screenH')));
  }

  static Map<String, double> _rect(Rect rect) => {'x': rect.left, 'y': rect.top, 'w': rect.width, 'h': rect.height};

  @override
  Stream<StickerEvent> get events => _events.stream;

  @override
  Future<StickerPlacement> placement() async => _placementOf((await _channel.invokeMethod<Map>('placement'))!);

  @override
  Future<void> frame(Rect window) => _channel.invokeMethod('frame', _rect(window));

  @override
  Future<void> morph(Rect window, Duration duration) => _channel.invokeMethod('morph', {..._rect(window), 'ms': duration.inMilliseconds});

  @override
  Future<void> remove() => _channel.invokeMethod('remove');

  @override
  Future<void> openApp(String noteId) => _channel.invokeMethod('openApp', noteId);
}

/// Для тестов: окно и экран — поля, вызовы пишутся по именам.
@visibleForTesting
class FakeStickerChannel implements StickerChannel {
  FakeStickerChannel({required this.window, this.screen = const Size(411, 860)});

  Rect window;
  Size screen;
  final calls = <String>[];
  final _events = StreamController<StickerEvent>.broadcast(sync: true);

  void send(StickerEvent event) => _events.add(event);

  @override
  Stream<StickerEvent> get events => _events.stream;

  @override
  Future<StickerPlacement> placement() async => (window: window, screen: screen);

  @override
  Future<void> frame(Rect next) async {
    calls.add('frame');
    window = next;
  }

  @override
  Future<void> morph(Rect next, Duration duration) async {
    calls.add('morph');
    window = next;
  }

  @override
  Future<void> remove() async => calls.add('remove');

  @override
  Future<void> openApp(String noteId) async => calls.add('openApp:$noteId');
}
