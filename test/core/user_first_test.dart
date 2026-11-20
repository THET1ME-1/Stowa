import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/user_first.dart';

void main() {
  var now = DateTime(2026, 11, 20, 12);
  DateTime clock() => now;

  setUp(() => now = DateTime(2026, 11, 20, 12));

  test('человек ничего не трогал — фон идёт сразу, без таймера', () async {
    final gate = UserFirst(enabled: true, clock: clock);
    expect(gate.busy, isFalse);
    var timerFired = false;
    Timer.run(() => timerFired = true);
    await gate.calm();
    expect(timerFired, isFalse);
  });

  test('после нажатия человек занят, пока не выйдет срок', () {
    final gate = UserFirst(enabled: true, clock: clock, hold: const Duration(seconds: 2));
    gate.touch();
    expect(gate.busy, isTrue);
    now = now.add(const Duration(milliseconds: 1900));
    expect(gate.busy, isTrue);
    now = now.add(const Duration(milliseconds: 200));
    expect(gate.busy, isFalse);
  });

  test('каждое нажатие отодвигает срок', () {
    final gate = UserFirst(enabled: true, clock: clock, hold: const Duration(seconds: 2));
    gate.touch();
    now = now.add(const Duration(seconds: 1));
    gate.touch();
    now = now.add(const Duration(milliseconds: 1500));
    expect(gate.busy, isTrue);
  });

  test('фон ждёт, пока человек занят, и идёт дальше, когда срок вышел', () async {
    final gate = UserFirst(enabled: true, clock: clock, hold: const Duration(seconds: 2), poll: const Duration(milliseconds: 10));
    gate.touch();
    var passed = false;
    final waiting = gate.calm().then((_) => passed = true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(passed, isFalse);
    now = now.add(const Duration(seconds: 3));
    await waiting;
    expect(passed, isTrue);
  });

  test('пока идёт работа человека (поиск), он занят, сколько бы она ни шла; после — ещё срок', () async {
    final gate = UserFirst(enabled: true, clock: clock, hold: const Duration(seconds: 2));
    final search = Completer<int>();
    final found = gate.during(search.future);
    now = now.add(const Duration(seconds: 30));
    expect(gate.busy, isTrue);
    search.complete(6);
    expect(await found, 6);
    expect(gate.busy, isTrue, reason: 'после работы — обычный срок');
    now = now.add(const Duration(seconds: 3));
    expect(gate.busy, isFalse);
  });

  test('работа человека упала — занятость снимается', () async {
    final gate = UserFirst(enabled: true, clock: clock, hold: const Duration(seconds: 2));
    await expectLater(gate.during(Future<int>.error(StateError('база закрыта'))), throwsStateError);
    now = now.add(const Duration(seconds: 3));
    expect(gate.busy, isFalse);
  });

  test('выключено (телефон, компьютер) — нажатия не считаются и фон не ждёт', () async {
    final gate = UserFirst(enabled: false, clock: clock);
    gate.touch();
    expect(gate.busy, isFalse);
    await gate.calm();
  });
}
