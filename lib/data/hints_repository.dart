import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/hints.dart';

/// Что человек уже видел из знакомства и подсказок: в prefs, с потоком для экранов.
/// Без prefs ([HintsRepository.memory]) живёт в памяти — так его берут тесты.
class HintsRepository {
  HintsRepository(SharedPreferences prefs) : _prefs = prefs, _state = _read(prefs);

  HintsRepository.memory([HintsState initial = HintsState.fresh]) : _prefs = null, _state = initial;

  final SharedPreferences? _prefs;
  HintsState _state;
  final _changes = StreamController<HintsState>.broadcast();

  static const _off = 'hints_off';
  static const _done = 'hints_done';
  static const _step = 'hints_step';
  static const _stows = 'hints_stows';
  static const _stepStows = 'hints_step_stows';
  static const _closed = 'hints_closed';
  static const _shows = 'hints_shows';

  HintsState get state => _state;

  Stream<HintsState> watch() async* {
    yield _state;
    yield* _changes.stream;
  }

  Future<void> record(Iterable<StartEvent> events) => _set(hintsAfter(_state, events));

  Future<void> skipStep() => _set(skipStepIn(_state));

  Future<void> tipShown(Tip tip) => _set(tipShownIn(_state, tip));

  Future<void> closeTip(Tip tip) => _set(closeTipIn(_state, tip));

  Future<void> setOff(bool off) => _set(_state.copyWith(off: off));

  /// «Начать знакомство заново»: шаги с первого, подсказки снова видны и включены.
  Future<void> restart() => _set(HintsState.fresh);

  /// «Отменить» после сброса: всё как было.
  Future<void> restore(HintsState state) => _set(state);

  /// Первый запуск версии со знакомством. Место хранилища выбрали раньше — человек давно
  /// пользуется приложением: шаги и подсказки сразу пройдены. Уже решённое не трогается.
  Future<void> settleOldInstall({required bool vaultAskedBefore}) async {
    final prefs = _prefs;
    if (prefs == null || prefs.containsKey(_step)) return;
    await _set(vaultAskedBefore ? HintsState.finished : HintsState.fresh);
  }

  Future<void> _set(HintsState next) async {
    _state = next;
    _changes.add(next);
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setBool(_off, next.off);
    await prefs.setStringList(_done, [for (final event in next.done) event.name]);
    // «done» вместо имени шага — знакомство закончено
    await prefs.setString(_step, next.step?.name ?? 'done');
    await prefs.setInt(_stows, next.stows);
    if (next.doneAt == null) {
      await prefs.remove(_stepStows);
    } else {
      await prefs.setInt(_stepStows, next.doneAt!);
    }
    await prefs.setStringList(_closed, [for (final tip in next.closed) tip.name]);
    await prefs.setStringList(_shows, [for (final MapEntry(:key, :value) in next.shows.entries) '${key.name}:$value']);
  }

  static HintsState _read(SharedPreferences prefs) {
    if (!prefs.containsKey(_step)) return HintsState.fresh;
    final step = prefs.getString(_step);
    return HintsState(
      off: prefs.getBool(_off) ?? false,
      done: {for (final name in prefs.getStringList(_done) ?? const <String>[]) ?StartEvent.values.asNameMap()[name]},
      step: step == 'done' ? null : StartStep.values.asNameMap()[step] ?? StartStep.stow,
      stows: prefs.getInt(_stows) ?? 0,
      doneAt: prefs.getInt(_stepStows),
      closed: {for (final name in prefs.getStringList(_closed) ?? const <String>[]) ?Tip.values.asNameMap()[name]},
      shows: {
        for (final one in prefs.getStringList(_shows) ?? const <String>[]) ?Tip.values.asNameMap()[one.split(':').first]: int.tryParse(one.split(':').last) ?? 0,
      },
    );
  }
}
