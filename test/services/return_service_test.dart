import 'dart:ui';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/return_plan.dart';
import 'package:stowa/l10n/app_localizations.dart';
import 'package:stowa/services/reminder_service.dart';
import 'package:stowa/services/return_service.dart';

class _FakePort implements NotificationPort {
  final shown = <({int id, String title, String body, String payload})>[];

  @override
  Future<void> ensurePermission() async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule({required int id, required String title, required String body, required DateTime at, required String payload}) async {}

  @override
  Future<void> show({required int id, required String title, required String body, required String payload}) async => shown.add((id: id, title: title, body: body, payload: payload));
}

void main() {
  late AppDatabase db;
  late _FakePort port;
  late SharedPreferences prefs;
  var now = DateTime(2026, 11, 6, 20, 30);
  var settings = const ReturnSettings();

  setUp(() async {
    db = AppDatabase.memory();
    port = _FakePort();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 11, 6, 20, 30);
    settings = const ReturnSettings();
  });
  tearDown(() => db.close());

  ReturnService service() => ReturnService(db, prefs: prefs, port: port, clock: () => now, settings: () => settings, l: () => lookupL(const Locale('ru')));

  Future<void> note(String id, DateTime created, {ItemKind kind = ItemKind.note, int? seconds}) => db.into(db.items).insert(
        ItemsCompanion.insert(id: id, kind: kind, title: id, body: Value(id), durationSeconds: Value(seconds), createdAt: created, updatedAt: created),
      );

  test('вечером очередь уходит одним тихим уведомлением, второй раз за день — нет', () async {
    await note('Ролик про турку', now.subtract(const Duration(days: 1)), kind: ItemKind.video, seconds: 754);
    await note('Ещё ролик', now.subtract(const Duration(days: 2)), kind: ItemKind.video, seconds: 600);
    await service().tick();
    expect(port.shown.single.title, 'Посмотреть потом');
    // 754 с — 13 минут с округлением вверх, 600 с — 10
    expect(port.shown.single.body, '2 ролика — 23 минуты');
    expect(port.shown.single.payload, 'return:watchLater');
    expect(prefs.getString(returnDayPref), '2026-11-06');

    now = now.add(const Duration(minutes: 30));
    await service().tick();
    expect(port.shown, hasLength(1));
  });

  test('ролики и статья вместе: «3 ролика и 1 статья»', () async {
    for (final id in ['a', 'b', 'c']) {
      await note(id, now.subtract(const Duration(days: 1)), kind: ItemKind.video, seconds: 120);
    }
    await note('статья', now.subtract(const Duration(days: 1)), kind: ItemKind.link);
    await db.into(db.facts).insert(FactsCompanion.insert(id: 'r', itemId: 'статья', extractor: 'page', kind: FactKind.readingTime, value: '5', number: const Value(5)));
    await service().tick();
    expect(port.shown.single.body, '3 ролика и 1 статья — 11 минут');
  });

  test('«в этот день» с одной заметкой открывает её саму, с несколькими — экран', () async {
    await note('Борщ бабушкин', DateTime(2025, 11, 6, 9));
    await service().tick();
    expect((port.shown.single.title, port.shown.single.body, port.shown.single.payload), ('Год назад', '«Борщ бабушкин»', 'note:Борщ бабушкин'));

    prefs.remove(returnDayPref);
    port.shown.clear();
    await note('Плов', DateTime(2025, 11, 6, 10));
    await service().tick();
    expect((port.shown.single.body, port.shown.single.payload), ('«Борщ бабушкин» и ещё 1', 'return:onThisDay'));
  });

  test('сводка в воскресенье вечером', () async {
    now = DateTime(2026, 11, 8, 20, 30);
    await note('a', now.subtract(const Duration(days: 1)));
    await note('b', now.subtract(const Duration(days: 2)));
    await service().tick();
    expect((port.shown.single.title, port.shown.single.body), ('Неделя в Stowa', 'За неделю 2 заметки: 2 не открыты, 2 без папки'));
  });

  test('днём, в тихие часы и при выключенном виде — тишина', () async {
    await note('ролик', now.subtract(const Duration(days: 1)), kind: ItemKind.video, seconds: 754);
    now = DateTime(2026, 11, 6, 15);
    await service().tick();
    now = DateTime(2026, 11, 6, 23);
    await service().tick();
    now = DateTime(2026, 11, 6, 20, 30);
    settings = const ReturnSettings(watchLater: false);
    await service().tick();
    expect(port.shown, isEmpty);
    expect(prefs.getString(returnDayPref), isNull);
  });
}
