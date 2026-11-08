import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/catalog/catalog_screen.dart';
import 'package:stowa/features/item/item_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> seed() async {
    final db = world.db;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'food', name: 'Рецепты', icon: 'restaurant', shape: 'cookie9'));
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'car', name: 'Машина', icon: 'directions_car', shape: 'pill', sortOrder: const Value(1)));
    for (final (index, (id, folder, title)) in [('b', 'food', 'Борщ'), ('s', 'food', 'Сырники'), ('o', 'car', 'Замена масла'), ('x', null, 'Мысль без папки')].indexed) {
      final at = world.now.subtract(Duration(minutes: index));
      await db.into(db.items).insert(ItemsCompanion.insert(id: id, kind: ItemKind.note, title: title, folderId: Value(folder), createdAt: at, updatedAt: at));
    }
  }

  Future<void> open(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Каталог'));
    await tester.pumpAndSettle();
  }

  Finder inCatalog(String text) => find.descendant(of: find.byType(CatalogScreen), matching: find.text(text));

  testWidgets('каталог с главной: папки свёрнуты, с числом заметок, «Без папки» в конце', (tester) async {
    await seed();
    await open(tester);
    expect(inCatalog('Рецепты'), findsOneWidget);
    expect(inCatalog('Машина'), findsOneWidget);
    expect(inCatalog('Без папки'), findsOneWidget);
    expect(inCatalog('2'), findsOneWidget);
    expect(inCatalog('Борщ'), findsNothing);
  });

  testWidgets('касание папки раскрывает её заметки, второе — сворачивает', (tester) async {
    await seed();
    await open(tester);
    await tester.tap(inCatalog('Рецепты'));
    await tester.pumpAndSettle();
    expect(inCatalog('Борщ'), findsOneWidget);
    expect(inCatalog('Сырники'), findsOneWidget);
    expect(inCatalog('Замена масла'), findsNothing);

    await tester.tap(inCatalog('Рецепты'));
    await tester.pumpAndSettle();
    expect(inCatalog('Борщ'), findsNothing);
  });

  testWidgets('«Раскрыть всё» показывает все заметки, касание заметки её открывает', (tester) async {
    await seed();
    await open(tester);
    await tester.tap(find.byTooltip('Раскрыть всё'));
    await tester.pumpAndSettle();
    for (final title in ['Борщ', 'Сырники', 'Замена масла', 'Мысль без папки']) {
      expect(inCatalog(title), findsOneWidget);
    }
    await tester.tap(inCatalog('Замена масла'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsOneWidget);
  });

  testWidgets('вложенные папки — ветками внутри родителя, заметки не считаются дважды', (tester) async {
    await seed();
    final db = world.db;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'soup', name: 'Супы', icon: 'soup_kitchen', shape: 'pill', parentId: const Value('food')));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'sh', kind: ItemKind.note, title: 'Щи', folderId: const Value('soup'), createdAt: world.now, updatedAt: world.now));
    await open(tester);
    expect(inCatalog('Супы'), findsNothing);
    // всего пять заметок, а не шесть: «Щи» в «Супах» и в числе «Рецептов»
    expect(inCatalog('5'), findsOneWidget);
    expect(inCatalog('3'), findsOneWidget);

    await tester.tap(inCatalog('Рецепты'));
    await tester.pumpAndSettle();
    expect(inCatalog('Супы'), findsOneWidget);
    expect(inCatalog('Щи'), findsNothing);
    // вложенная папка стоит выше заметок родителя и с отступом
    expect(tester.getTopLeft(inCatalog('Супы')).dy, lessThan(tester.getTopLeft(inCatalog('Борщ')).dy));
    expect(tester.getTopLeft(inCatalog('Супы')).dx, greaterThan(tester.getTopLeft(inCatalog('Рецепты')).dx));

    await tester.tap(inCatalog('Супы'));
    await tester.pumpAndSettle();
    expect(inCatalog('Щи'), findsOneWidget);
  });
}
