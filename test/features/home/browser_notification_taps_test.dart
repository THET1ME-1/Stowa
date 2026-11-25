import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/reminder_service.dart';

import '../../helpers/test_app.dart';

/// Кнопки уведомлений браузера выполняет сама вкладка: фонового процесса, как у телефона, нет.
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld(now: DateTime(2026, 11, 25, 10)));
  tearDown(() => world.dispose());

  Future<void> reminded(String id) => world.db.into(world.db.items).insert(
        ItemsCompanion.insert(
          id: id,
          kind: ItemKind.note,
          title: id,
          body: Value(id),
          createdAt: world.now,
          updatedAt: world.now,
          reminderAt: Value(world.now.add(const Duration(minutes: 5))),
        ),
      );

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    world.inBrowser = true;
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  Future<Item> item(WidgetTester tester, String id) async =>
      (await tester.runAsync(() => (world.db.select(world.db.items)..where((row) => row.id.equals(id))).getSingle()))!;

  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 10; round++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
  }

  testWidgets('«Готово» снимает напоминание', (tester) async {
    await reminded('Позвонить маме');
    await open(tester);
    world.notificationTaps.add((action: reminderDone, payload: 'Позвонить маме'));
    await settle(tester);
    expect((await item(tester, 'Позвонить маме')).reminderAt, isNull);
  });

  testWidgets('«Через час» переносит напоминание на час от нажатия', (tester) async {
    await reminded('Купить хлеб');
    await open(tester);
    world.notificationTaps.add((action: reminderSnooze, payload: 'Купить хлеб'));
    await settle(tester);
    expect((await item(tester, 'Купить хлеб')).reminderAt, world.now.add(const Duration(hours: 1)));
  });

  testWidgets('касание открывает заметку', (tester) async {
    await reminded('Счётчики');
    await open(tester);
    world.notificationTaps.add((action: notificationOpen, payload: 'Счётчики'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('item-date')), findsOneWidget);
  });
}
