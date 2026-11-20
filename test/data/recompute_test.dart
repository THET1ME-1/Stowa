import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/recompute.dart';

void main() {
  late StreamController<void> changes;
  late List<Completer<int>> running;
  late List<Object> seen;

  setUp(() {
    changes = StreamController<void>();
    running = [];
    seen = [];
  });
  tearDown(() => changes.close());

  // пересчёт, который кончается, когда скажет тест
  Future<int> compute() {
    final one = Completer<int>();
    running.add(one);
    return one.future;
  }

  Future<void> turn() => Future<void>.delayed(Duration.zero);

  test('первый сигнал — сразу пересчёт, его ответ уходит подписчику', () async {
    final sub = recomputeOn(changes.stream, compute).listen(seen.add);
    changes.add(null);
    await turn();
    expect(running, hasLength(1));
    running.single.complete(7);
    await turn();
    expect(seen, [7]);
    await sub.cancel();
  });

  test('десять сигналов, пока идёт пересчёт, — один следующий пересчёт, а не десять', () async {
    final sub = recomputeOn(changes.stream, compute).listen(seen.add);
    changes.add(null);
    await turn();
    for (var index = 0; index < 10; index++) {
      changes.add(null);
    }
    await turn();
    expect(running, hasLength(1), reason: 'пока первый считает, второй не начинается');
    running[0].complete(1);
    await turn();
    expect(running, hasLength(2));
    running[1].complete(2);
    await turn();
    await turn();
    expect(running, hasLength(2), reason: 'сигналы слились в один пересчёт');
    expect(seen, [1, 2]);
    await sub.cancel();
  });

  test('сигнал после законченного пересчёта — новый пересчёт сразу', () async {
    final sub = recomputeOn(changes.stream, compute).listen(seen.add);
    changes.add(null);
    await turn();
    running[0].complete(1);
    await turn();
    changes.add(null);
    await turn();
    expect(running, hasLength(2));
    running[1].complete(2);
    await turn();
    expect(seen, [1, 2]);
    await sub.cancel();
  });

  test('после тяжёлого пересчёта следующий ждёт отдых, а сигналы за это время сливаются', () async {
    final sub = recomputeOn(changes.stream, compute, rest: (value) => const Duration(milliseconds: 150)).listen(seen.add);
    changes.add(null);
    await turn();
    changes.add(null);
    running[0].complete(1);
    await turn();
    changes.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    changes.add(null);
    await turn();
    expect(running, hasLength(1), reason: 'отдых ещё идёт');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(running, hasLength(2));
    running[1].complete(2);
    await turn();
    expect(seen, [1, 2]);
    await sub.cancel();
  });

  test('сигнал во время отдыха после спокойного пересчёта тоже ждёт его конца', () async {
    final sub = recomputeOn(changes.stream, compute, rest: (value) => const Duration(milliseconds: 150)).listen(seen.add);
    changes.add(null);
    await turn();
    running[0].complete(1);
    await turn();
    // пока считали, сигналов не было; новый пришёл сразу после
    changes.add(null);
    await turn();
    expect(running, hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(running, hasLength(2));
    running[1].complete(2);
    await sub.cancel();
  });

  test('тот же самый ответ второй раз подписчику не уходит', () async {
    final answer = Object();
    final other = Object();
    final answers = [answer, answer, other];
    final got = <Object>[];
    final sub = recomputeOn<Object>(changes.stream, () async => answers.removeAt(0)).listen(got.add);
    for (var index = 0; index < 3; index++) {
      changes.add(null);
      await turn();
      await turn();
    }
    expect(got, [answer, other]);
    await sub.cancel();
  });

  test('отписались во время отдыха — пересчёта больше нет', () async {
    final sub = recomputeOn(changes.stream, compute, rest: (value) => const Duration(milliseconds: 60)).listen(seen.add);
    changes.add(null);
    await turn();
    changes.add(null);
    running[0].complete(1);
    await turn();
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(running, hasLength(1));
  });

  test('ошибка пересчёта уходит подписчику, следующий сигнал считается как обычно', () async {
    final errors = <Object>[];
    final sub = recomputeOn(changes.stream, compute).listen(seen.add, onError: errors.add);
    changes.add(null);
    await turn();
    running[0].completeError(StateError('база закрыта'));
    await turn();
    expect(errors, hasLength(1));
    changes.add(null);
    await turn();
    running[1].complete(2);
    await turn();
    expect(seen, [2]);
    await sub.cancel();
  });
}
