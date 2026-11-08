import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/history_screen.dart';
import 'package:stowa/features/item/item_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> seed({bool versions = true}) async {
    final db = world.db;
    final before = world.now.subtract(const Duration(hours: 2));
    await db.into(db.items).insert(
      ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Ремонт кухни', body: const Value('Ремонт кухни\nплитка 20×20\nклей'), createdAt: before, updatedAt: before),
    );
    if (!versions) return;
    // правка час спустя: прежний текст уходит в историю сам
    await (db.update(db.items)..where((t) => t.id.equals('a'))).write(
      ItemsCompanion(body: const Value('Ремонт кухни\nплитка 30×30\nклей\nзатирка серая'), updatedAt: Value(world.now.subtract(const Duration(hours: 1)))),
    );
  }

  Future<void> openHistory(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('История'));
    await tester.pumpAndSettle();
  }

  testWidgets('без снимков пункта «История» в меню нет', (tester) async {
    await seed(versions: false);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё').first);
    await tester.pumpAndSettle();
    expect(find.text('История'), findsNothing);
  });

  testWidgets('история: «Сейчас» и версии со сводкой правок, разница строк', (tester) async {
    await seed();
    await openHistory(tester);
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text('Сейчас'), findsOneWidget);
    // от версии до нынешнего: две строки добавлены, одна убрана
    expect(find.text('+2 −1'), findsOneWidget);

    await tester.tap(find.text('+2 −1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Разница'));
    await tester.pumpAndSettle();
    expect(find.text('плитка 20×20'), findsOneWidget);
    expect(find.text('плитка 30×30'), findsOneWidget);
    expect(find.text('затирка серая'), findsOneWidget);
  });

  testWidgets('«Вернуть эту версию» возвращает текст, «Отменить» — обратно', (tester) async {
    await seed();
    await openHistory(tester);
    await tester.tap(find.text('+2 −1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вернуть эту версию'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsNothing);
    expect(find.byType(ItemScreen), findsOneWidget);
    expect((await world.db.select(world.db.items).getSingle()).body, 'Ремонт кухни\nплитка 20×20\nклей');
    expect(find.text('Версия возвращена'), findsOneWidget);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.items).getSingle()).body, 'Ремонт кухни\nплитка 30×30\nклей\nзатирка серая');
  });

  testWidgets('история и версия влезают в 320 точек при крупном шрифте', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seed();
    await openHistory(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('+2 −1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Разница'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
