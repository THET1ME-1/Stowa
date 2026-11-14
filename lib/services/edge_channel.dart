import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/settings_repository.dart';
import '../domain/edge_settings.dart';
import '../domain/spine_colors.dart';
import 'launch_actions.dart' show LaunchAction;

/// Что служба сообщает полке: корешки коснулись или тянут, человек хочет её убрать.
sealed class EdgeEvent {
  const EdgeEvent();
}

/// Касание корешков: окно полки уже стоит, полке выехать.
class EdgeOpen extends EdgeEvent {
  const EdgeOpen();
}

/// Палец потянул корешки внутрь экрана: окно полки стоит, дальше полка идёт за пальцем.
class EdgeDragStart extends EdgeEvent {
  const EdgeDragStart();
}

/// Палец ушёл от края на [distance] точек с начала свайпа.
class EdgeDrag extends EdgeEvent {
  const EdgeDrag(this.distance);

  final double distance;
}

/// Палец отпустили; [velocity] — точек в секунду, плюс — внутрь экрана.
class EdgeDragEnd extends EdgeEvent {
  const EdgeDragEnd(this.velocity);

  final double velocity;
}

/// «Назад» или касание мимо окна: полке уехать.
class EdgeDismiss extends EdgeEvent {
  const EdgeDismiss();
}

/// Канал `stowa/edge`: «Под рукой» со стороны Dart. В главном окне — право и служба,
/// в окне полки — фокус, закрытие и цвета корешков. На iPhone рисовать поверх других
/// приложений нельзя: там [NoEdgeChannel].
abstract class EdgeChannel {
  /// В окне полки: касания и свайпы корешков от службы.
  Stream<EdgeEvent> get events;

  /// Из окна полки: полка начала уезжать, корешкам пора возвращаться.
  Future<void> closing();

  Future<bool> canDraw();

  /// Системный экран права «Поверх других приложений» для Stowa.
  Future<void> askDraw();
  Future<void> start();
  Future<void> stop();

  /// Служба перечитывает настройки корешков из prefs и плавно переставляет их.
  Future<void> apply();

  /// Из окна полки: цвета корешков сверху вниз.
  Future<void> spines(List<Spine> spines);

  /// Из окна полки: убрать полку.
  Future<void> close();

  /// Из окна полки: открыть Stowa, с заметкой [noteId] или на главной, полку убрать.
  Future<void> openApp(String? noteId);

  /// Из окна полки: повесить заметку стикером поверх приложений. [at] — куда, в точках от
  /// левого верхнего угла свободной части экрана; нет — служба поставит сама у края.
  Future<void> pinSticker(String noteId, {Offset? at});

  /// Из окна полки: камере, файлам и запросу микрофона нужна Activity — дело переходит
  /// в окно виджета вместе с набранным, полка уходит.
  Future<void> handOff(LaunchAction action, String text);

  /// Из окна полки: есть ли право на микрофон (плагин записи без Activity его не видит).
  Future<bool> micGranted();
}

class MethodEdgeChannel implements EdgeChannel {
  const MethodEdgeChannel();

  static const _channel = MethodChannel('stowa/edge');

  // служба зовёт тот же канал в обратную сторону; слушатель ставится при первой подписке
  static final StreamController<EdgeEvent> _events = StreamController<EdgeEvent>.broadcast(
    onListen: () => _channel.setMethodCallHandler((call) async {
      final event = switch (call.method) {
        'open' => const EdgeOpen(),
        'dragStart' => const EdgeDragStart(),
        'drag' => EdgeDrag((call.arguments as num).toDouble()),
        'dragEnd' => EdgeDragEnd((call.arguments as num).toDouble()),
        'dismiss' => const EdgeDismiss(),
        _ => null,
      };
      if (event != null) _events.add(event);
    }),
  );

  @override
  Stream<EdgeEvent> get events => _events.stream;

  @override
  Future<void> closing() => _channel.invokeMethod('closing');

  @override
  Future<bool> canDraw() async => await _channel.invokeMethod<bool>('canDraw') ?? false;

  @override
  Future<void> askDraw() => _channel.invokeMethod('askDraw');

  @override
  Future<void> start() => _channel.invokeMethod('start');

  @override
  Future<void> stop() => _channel.invokeMethod('stop');

  @override
  Future<void> apply() => _channel.invokeMethod('apply');

  @override
  Future<void> spines(List<Spine> spines) => _channel.invokeMethod('spines', [
    for (final spine in spines) {'color': spine.color.toARGB32(), 'weight': spine.weight},
  ]);

  @override
  @override
  Future<void> close() => _channel.invokeMethod('close');

  @override
  Future<void> openApp(String? noteId) => _channel.invokeMethod('openApp', noteId);

  @override
  Future<void> pinSticker(String noteId, {Offset? at}) => _channel.invokeMethod('pinSticker', {'id': noteId, if (at != null) 'x': at.dx, if (at != null) 'y': at.dy});

  @override
  Future<void> handOff(LaunchAction action, String text) => _channel.invokeMethod('handOff', {'action': action.name, 'text': text});

  @override
  Future<bool> micGranted() async => await _channel.invokeMethod<bool>('micGranted') ?? false;
}

/// iPhone и всё, где окон поверх нет: ничего не делает, права нет.
class NoEdgeChannel implements EdgeChannel {
  const NoEdgeChannel();

  @override
  Stream<EdgeEvent> get events => const Stream.empty();

  @override
  Future<void> closing() async {}

  @override
  Future<bool> canDraw() async => false;

  @override
  Future<void> askDraw() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> apply() async {}

  @override
  Future<void> spines(List<Spine> spines) async {}

  @override
  @override
  Future<void> close() async {}

  @override
  Future<void> openApp(String? noteId) async {}

  @override
  Future<void> pinSticker(String noteId, {Offset? at}) async {}

  @override
  Future<void> handOff(LaunchAction action, String text) async {}

  @override
  Future<bool> micGranted() async => false;
}

/// Для тестов: пишет вызовы по именам, право — [canDrawAnswer].
@visibleForTesting
class FakeEdgeChannel implements EdgeChannel {
  final calls = <String>[];
  var canDrawAnswer = true;
  var micAnswer = true;
  List<Spine> lastSpines = const [];
  final _events = StreamController<EdgeEvent>.broadcast(sync: true);

  /// Как будто служба прислала [event].
  void send(EdgeEvent event) => _events.add(event);

  @override
  Stream<EdgeEvent> get events => _events.stream;

  @override
  Future<void> closing() async => calls.add('closing');

  @override
  Future<bool> canDraw() async {
    calls.add('canDraw');
    return canDrawAnswer;
  }

  @override
  Future<void> askDraw() async => calls.add('askDraw');

  @override
  Future<void> start() async => calls.add('start');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> apply() async => calls.add('apply');

  @override
  Future<void> spines(List<Spine> spines) async {
    calls.add('spines');
    lastSpines = spines;
  }

  @override
  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> openApp(String? noteId) async => calls.add('openApp:$noteId');

  @override
  Future<void> pinSticker(String noteId, {Offset? at}) async => calls.add('pinSticker:$noteId${at == null ? '' : '@${at.dx.round()},${at.dy.round()}'}');

  @override
  Future<void> handOff(LaunchAction action, String text) async => calls.add('handOff:${action.name}:$text');

  @override
  Future<bool> micGranted() async {
    calls.add('micGranted');
    return micAnswer;
  }
}

/// Канал по платформе: окна поверх есть только на Android.
EdgeChannel platformEdgeChannel() => !kIsWeb && Platform.isAndroid ? const MethodEdgeChannel() : const NoEdgeChannel();

/// Включение, выключение и правка корешков: настройка в prefs и служба — всегда вместе.
class EdgeControl {
  EdgeControl({required EdgeSettings Function() read, required Future<void> Function(EdgeSettings settings) write, required EdgeChannel channel})
    : _read = read, // ignore: prefer_initializing_formals
      _write = write, // ignore: prefer_initializing_formals
      _channel = channel; // ignore: prefer_initializing_formals

  /// Над настоящими настройками приложения.
  EdgeControl.over(SettingsRepository settings, EdgeChannel channel) : this(read: () => settings.edge, write: settings.setEdge, channel: channel);

  final EdgeSettings Function() _read;
  final Future<void> Function(EdgeSettings settings) _write;
  final EdgeChannel _channel;

  /// Человек включал и ушёл в настройки системы за правом: по возвращении с правом — включить.
  var _wanted = false;

  /// Включить. Права нет — ведёт к нему и возвращает false: включится по возвращении ([resumed]).
  Future<bool> enable() async {
    if (!await _channel.canDraw()) {
      _wanted = true;
      await _channel.askDraw();
      return false;
    }
    await _write(_read().copyWith(enabled: true));
    await _channel.start();
    return true;
  }

  Future<void> disable() async {
    await _write(_read().copyWith(enabled: false));
    await _channel.stop();
  }

  /// Возврат в приложение. Включено и право есть — служба поднимается (умерла — оживёт, жива —
  /// ничего не изменится); право отозвали — включатель гаснет; ходил за правом и получил — включается.
  Future<void> resumed() async {
    final edge = _read();
    final wanted = _wanted;
    _wanted = false;
    if (!edge.enabled && !wanted) return;
    if (!await _channel.canDraw()) {
      if (edge.enabled) await _write(edge.copyWith(enabled: false));
      return;
    }
    if (!edge.enabled) await _write(edge.copyWith(enabled: true));
    await _channel.start();
  }

  /// Край, место, размер, заметность: пишутся сразу, включённые корешки переезжают плавно.
  Future<void> change(EdgeSettings next) async {
    await _write(next);
    if (next.enabled) await _channel.apply();
  }
}
