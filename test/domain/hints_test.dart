import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/data/hints_repository.dart';
import 'package:stowa/domain/hints.dart';

void main() {
  HintsState after(HintsState state, List<StartEvent> events) => hintsAfter(state, events);

  test('шаги идут по порядку и ждут новую заметку', () {
    var state = HintsState.fresh;
    expect(visibleStep(state), StartStep.stow);
    // первая заметка сразу открывает поиск
    state = after(state, [StartEvent.stowed]);
    expect(visibleStep(state), StartStep.search);
    // нашёл — карточка уходит, следующая ждёт новой заметки
    state = after(state, [StartEvent.found]);
    expect(visibleStep(state), isNull);
    state = after(state, [StartEvent.stowed]);
    expect(visibleStep(state), StartStep.remind);
    // заметка с напоминанием делает шаг, но следующий — только на следующем сохранении
    state = after(state, [StartEvent.stowed, StartEvent.reminded]);
    expect(visibleStep(state), isNull);
    state = after(state, [StartEvent.stowed]);
    expect(visibleStep(state), StartStep.folder);
  });

  test('сделанное заранее засчитано: тег до шага 5 — после папки сразу команды', () {
    var state = after(HintsState.fresh, [StartEvent.stowed, StartEvent.tagged]);
    state = after(state, [StartEvent.found]);
    state = after(state, [StartEvent.stowed, StartEvent.reminded]);
    state = after(state, [StartEvent.stowed]);
    expect(visibleStep(state), StartStep.folder);
    state = after(state, [StartEvent.stowed, StartEvent.foldered]);
    state = after(state, [StartEvent.stowed]);
    expect(visibleStep(state), StartStep.commands);
  });

  test('шесть действий — финальная карточка, её пропуск — конец знакомства', () {
    var state = HintsState.fresh;
    for (final events in [
      [StartEvent.stowed],
      [StartEvent.found],
      [StartEvent.stowed],
      [StartEvent.stowed, StartEvent.reminded],
      [StartEvent.stowed],
      [StartEvent.stowed, StartEvent.foldered],
      [StartEvent.stowed],
      [StartEvent.stowed, StartEvent.tagged],
      [StartEvent.stowed],
      [StartEvent.stowed, StartEvent.commanded],
      [StartEvent.stowed],
    ]) {
      state = after(state, events);
    }
    expect(visibleStep(state), StartStep.finish);
    state = skipStepIn(state);
    expect(state.step, isNull);
    expect(visibleStep(state), isNull);
  });

  test('пропуск шага: следующий ждёт новой заметки, как после сделанного', () {
    var state = after(HintsState.fresh, [StartEvent.stowed]);
    state = skipStepIn(state);
    expect(visibleStep(state), isNull);
    state = after(state, [StartEvent.stowed]);
    expect(visibleStep(state), StartStep.remind);
  });

  test('подсказка: до трёх показов или до «×»; «зажми заметку» — только после знакомства', () {
    var state = HintsState.fresh;
    expect(tipVisible(state, Tip.catalog), isTrue);
    for (var i = 0; i < 3; i++) {
      state = tipShownIn(state, Tip.catalog);
    }
    expect(tipVisible(state, Tip.catalog), isFalse);
    expect(tipVisible(closeTipIn(state, Tip.canvas), Tip.canvas), isFalse);
    expect(tipVisible(state, Tip.longPress), isFalse);
    expect(tipVisible(HintsState.finished.copyWith(closed: const {}), Tip.longPress), isTrue);
    expect(tipVisible(HintsState.fresh.copyWith(off: true), Tip.catalog), isFalse);
    expect(visibleStep(HintsState.fresh.copyWith(off: true)), isNull);
  });

  group('хранилище', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('новичок — знакомство с начала, события сохраняются', () async {
      final hints = HintsRepository(await SharedPreferences.getInstance());
      await hints.settleOldInstall(vaultAskedBefore: false);
      expect(visibleStep(hints.state), StartStep.stow);
      await hints.record([StartEvent.stowed]);
      final again = HintsRepository(await SharedPreferences.getInstance());
      expect(visibleStep(again.state), StartStep.search);
    });

    test('старая установка — ни шагов, ни подсказок; «заново» возвращает', () async {
      final hints = HintsRepository(await SharedPreferences.getInstance());
      await hints.settleOldInstall(vaultAskedBefore: true);
      expect(visibleStep(hints.state), isNull);
      expect(tipVisible(hints.state, Tip.noteBar), isFalse);
      // второй запуск ничего не трогает
      await hints.restart();
      await hints.settleOldInstall(vaultAskedBefore: true);
      expect(visibleStep(hints.state), StartStep.stow);
      expect(tipVisible(hints.state, Tip.noteBar), isTrue);
    });
  });
}
