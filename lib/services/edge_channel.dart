import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/settings_repository.dart';
import '../domain/edge_settings.dart';
import '../domain/spine_colors.dart';

/// Канал `stowa/edge`: «Под рукой» со стороны Dart. В главном окне — право и служба,
/// в окне полки — фокус, закрытие и цвета корешков. На iPhone рисовать поверх других
/// приложений нельзя: там [NoEdgeChannel].
abstract class EdgeChannel {
  Future<bool> canDraw();

  /// Системный экран права «Поверх других приложений» для Stowa.
  Future<void> askDraw();
  Future<void> start();
  Future<void> stop();

  /// Служба перечитывает настройки корешков из prefs и плавно переставляет их.
  Future<void> apply();

  /// Из окна полки: цвета корешков сверху вниз.
  Future<void> spines(List<Spine> spines);

  /// Из окна полки: взять клавиатуру на время набора или отдать.
  Future<void> setFocusable(bool on);

  /// Из окна полки: убрать полку.
  Future<void> close();
}

class MethodEdgeChannel implements EdgeChannel {
  const MethodEdgeChannel();

  static const _channel = MethodChannel('stowa/edge');

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
  Future<void> setFocusable(bool on) => _channel.invokeMethod('setFocusable', on);

  @override
  Future<void> close() => _channel.invokeMethod('close');
}

/// iPhone и всё, где окон поверх нет: ничего не делает, права нет.
class NoEdgeChannel implements EdgeChannel {
  const NoEdgeChannel();

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
  Future<void> setFocusable(bool on) async {}

  @override
  Future<void> close() async {}
}

/// Для тестов: пишет вызовы по именам, право — [canDrawAnswer].
@visibleForTesting
class FakeEdgeChannel implements EdgeChannel {
  final calls = <String>[];
  var canDrawAnswer = true;
  List<Spine> lastSpines = const [];

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
  Future<void> setFocusable(bool on) async => calls.add('setFocusable:$on');

  @override
  Future<void> close() async => calls.add('close');
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
