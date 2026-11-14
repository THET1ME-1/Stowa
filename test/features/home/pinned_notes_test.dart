import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> note(String id, String title, {int daysAgo = 1, DateTime? pinnedAt}) async {
    final at = world.now.subtract(Duration(days: daysAgo));
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: id, kind: ItemKind.note, title: title, body: Value(title), sortState: const Value(SortState.sorted), pinnedAt: Value(pinnedAt), createdAt: at, updatedAt: at),
    );
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  Future<DateTime?> pinnedAt(String id) async => (await (world.db.select(world.db.items)..where((t) => t.id.equals(id))).getSingle()).pinnedAt;

  testWidgets('долгое нажатие → «Закрепить»: заметка встаёт в «Закреплено» над лентой, «Отменить» возвращает', (tester) async {
    await note('wifi', 'Пароль от Wi-Fi', daysAgo: 30);
    await note('milk', 'Купить молоко');
    await open(tester);
    expect(find.byKey(const ValueKey('pinned-header')), findsNothing);

    await tester.longPress(find.text('Пароль от Wi-Fi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закрепить'));
    await tester.pumpAndSettle();
    expect(await pinnedAt('wifi'), isNotNull);
    expect(find.byKey(const ValueKey('pinned-header')), findsOneWidget);
    // блок выше ленты, и заметка в нём один раз
    expect(tester.getTopLeft(find.text('Пароль от Wi-Fi')).dy, lessThan(tester.getTopLeft(find.text('Купить молоко')).dy));
    expect(find.text('Пароль от Wi-Fi'), findsOneWidget);
    expect(find.text('Закрепил наверху главной'), findsOneWidget);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(await pinnedAt('wifi'), isNull);
    expect(find.byKey(const ValueKey('pinned-header')), findsNothing);
  });

  testWidgets('у закреплённой в листе «Открепить»', (tester) async {
    await note('wifi', 'Пароль от Wi-Fi', pinnedAt: world.now);
    await open(tester);
    await tester.longPress(find.text('Пароль от Wi-Fi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открепить'));
    await tester.pumpAndSettle();
    expect(await pinnedAt('wifi'), isNull);
    expect(find.byKey(const ValueKey('pinned-header')), findsNothing);
    expect(find.text('Пароль от Wi-Fi'), findsOneWidget);
  });

  testWidgets('больше трёх закреплённых — видны три последние, «Ещё 2» раскрывает остальные', (tester) async {
    for (var index = 1; index <= 5; index++) {
      await note('p$index', 'Закреп $index', pinnedAt: world.now.subtract(Duration(minutes: index)));
    }
    await open(tester);
    expect(find.text('Закреп 1'), findsOneWidget);
    expect(find.text('Закреп 3'), findsOneWidget);
    expect(find.text('Закреп 4'), findsNothing);
    await tester.tap(find.text('Ещё 2'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Закреп 5'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Закреп 5'), findsOneWidget);
    expect(find.text('Свернуть'), findsOneWidget);
  });
}
