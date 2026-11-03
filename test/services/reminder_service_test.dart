import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/services/reminder_service.dart';

class _FakePort implements NotificationPort {
  final scheduled = <int, ({String title, DateTime at, String payload})>{};
  var cancels = 0;
  var asked = 0;

  @override
  Future<void> ensurePermission() async => asked++;

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled.clear();
  }

  @override
  Future<void> schedule({required int id, required String title, required DateTime at, required String payload}) async {
    scheduled[id] = (title: title, at: at, payload: payload);
  }
}

void main() {
  final now = DateTime(2026, 11, 3, 12);
  late _FakePort port;
  late ReminderService service;

  setUp(() {
    port = _FakePort();
    service = ReminderService(port);
  });

  test('напоминание из будущего ставится будильником на своё время, тап откроет вещь', () async {
    await service.sync([(id: 'tooth', title: 'Зубной', at: DateTime(2026, 11, 4, 10))], now);
    final one = port.scheduled.values.single;
    expect(one.at, DateTime(2026, 11, 4, 10));
    expect(one.title, 'Зубной');
    expect(one.payload, 'tooth');
  });

  test('прошедшее не ставится, ближайшие первыми и не больше полусотни', () async {
    await service.sync([
      (id: 'old', title: 'Было', at: now.subtract(const Duration(hours: 1))),
      for (var index = 0; index < 60; index++) (id: 'r$index', title: 'Дело $index', at: now.add(Duration(hours: 60 - index))),
    ], now);
    expect(port.scheduled, hasLength(50));
    expect(port.scheduled.values.any((one) => one.payload == 'old'), isFalse);
    expect(port.scheduled.values.any((one) => one.payload == 'r59'), isTrue);
  });

  test('сняли напоминание — будильник пропал; тот же список второй раз не дёргает систему', () async {
    final tooth = (id: 'tooth', title: 'Зубной', at: DateTime(2026, 11, 4, 10));
    await service.sync([tooth], now);
    await service.sync([tooth], now);
    expect(port.cancels, 1);
    await service.sync(const [], now);
    expect(port.scheduled, isEmpty);
  });

  test('разрешение спрашивается один раз и только когда есть что ставить', () async {
    await service.sync(const [], now);
    expect(port.asked, 0);
    await service.sync([(id: 'a', title: 'А', at: now.add(const Duration(hours: 1)))], now);
    await service.sync([(id: 'b', title: 'Б', at: now.add(const Duration(hours: 2)))], now);
    expect(port.asked, 1);
  });

  test('у одной вещи всегда один и тот же номер уведомления', () {
    expect(notificationId('tooth'), notificationId('tooth'));
    expect(notificationId('tooth'), isNot(notificationId('teeth')));
    expect(notificationId('tooth'), inInclusiveRange(0, 0x7fffffff));
  });
}
