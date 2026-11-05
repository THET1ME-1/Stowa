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

  Future<void> addDeleted(String id, String title, {required int daysAgo}) => world.db
      .into(world.db.items)
      .insert(
        ItemsCompanion.insert(
          id: id,
          kind: ItemKind.note,
          title: title,
          createdAt: world.now,
          updatedAt: world.now,
          deletedAt: Value(world.now.subtract(Duration(days: daysAgo))),
        ),
      );

  Future<void> openTrash(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Корзина'), 200);
    await tester.ensureVisible(find.text('Корзина'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Корзина'));
    await tester.pumpAndSettle();
  }

  testWidgets('обложка удалённой ссылки 18+ в корзине размыта, пока показ выключен', (tester) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'x',
          kind: ItemKind.link,
          title: 'Ссылка',
          url: const Value('https://www.xvideos.com/x'),
          coverPath: const Value('covers/x.jpg'),
          createdAt: world.now,
          updatedAt: world.now,
          deletedAt: Value(world.now),
        ));
    await world.db.into(world.db.facts).insert(FactsCompanion.insert(id: 'x-adult', itemId: 'x', extractor: 'page', kind: FactKind.adult, value: '18+'));
    await openTrash(tester);
    expect(find.byKey(const ValueKey('adult-veil-x')), findsOneWidget);
  });

  testWidgets('удалённое лежит в корзине со сроком и возвращается одним касанием', (tester) async {
    await addDeleted('a', 'Список покупок', daysAgo: 2);
    await openTrash(tester);
    expect(find.text('Список покупок'), findsOneWidget);
    expect(find.textContaining('сотрётся через 28 дней'), findsOneWidget);
    await tester.tap(find.text('Вернуть'));
    await tester.pumpAndSettle();
    final item = await (world.db.select(world.db.items)..where((t) => t.id.equals('a'))).getSingle();
    expect(item.deletedAt, isNull);
  });

  testWidgets('просроченное стирается при запуске', (tester) async {
    await addDeleted('old', 'Старое', daysAgo: 31);
    await addDeleted('fresh', 'Свежее', daysAgo: 1);
    await openTrash(tester);
    expect(find.text('Старое'), findsNothing);
    expect(find.text('Свежее'), findsOneWidget);
    expect(await world.db.select(world.db.items).get(), hasLength(1));
  });
}
