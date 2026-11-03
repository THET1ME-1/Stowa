import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/home/folders_grid.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> seed() async {
    final db = world.db;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'food', name: 'Рецепты', icon: 'restaurant', shape: 'cookie9'));
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'home', shape: 'pill', sortOrder: const Value(1)));
    await db.into(db.tags).insert(TagsCompanion.insert(id: 'q', name: 'быстро', createdAt: world.now));
    for (final (index, (id, title)) in [('a', 'Борщ'), ('b', 'Сырники'), ('c', 'Плов')].indexed) {
      final at = world.now.subtract(Duration(minutes: 10 - index));
      await db.into(db.items).insert(
        ItemsCompanion.insert(id: id, kind: ItemKind.note, title: title, body: Value(title), folderId: const Value('food'), sortState: const Value(SortState.sorted), createdAt: at, updatedAt: at),
      );
    }
    await db.into(db.itemTags).insert(ItemTagsCompanion.insert(itemId: 'a', tagId: 'q', source: TagSource.user));
  }

  Future<void> openFolder(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(FolderTile), matching: find.text('Рецепты')));
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester) async {
    await tester.longPress(find.text('Борщ').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сырники').last);
    await tester.pumpAndSettle();
  }

  Future<Item> item(String id) => (world.db.select(world.db.items)..where((t) => t.id.equals(id))).getSingle();

  testWidgets('долгое нажатие выбирает, касания добавляют, «Назад» снимает выбор', (tester) async {
    await seed();
    await openFolder(tester);
    await select(tester);
    expect(find.text('Выбрано: 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Снять выбор'));
    await tester.pumpAndSettle();
    expect(find.text('Выбрано: 2'), findsNothing);
    // без выбора касание снова открывает вещь, а не выбирает
    expect(find.text('Рецепты'), findsWidgets);
  });

  testWidgets('короткая заметка в ленте во всю ширину, как была до выбора', (tester) async {
    await seed();
    await openFolder(tester);
    final card = find.ancestor(of: find.text('Плов').last, matching: find.byType(Container)).first;
    expect(tester.getSize(card).width, greaterThan(300));
  });

  testWidgets('пачкой в другую папку и «Отменить» возвращает всё', (tester) async {
    await seed();
    await openFolder(tester);
    await select(tester);
    await tester.tap(find.text('В папку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дом').last);
    await tester.pumpAndSettle();
    expect((await item('a')).folderId, 'home');
    expect((await item('b')).folderId, 'home');
    expect((await item('c')).folderId, 'food');
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect((await item('a')).folderId, 'food');
  });

  testWidgets('тег пачкой: выбор из готовых тегов', (tester) async {
    await seed();
    await openFolder(tester);
    await select(tester);
    await tester.tap(find.text('Тег'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('быстро').last);
    await tester.pumpAndSettle();
    final links = await (world.db.select(world.db.itemTags)..where((t) => t.tagId.equals('q'))).get();
    expect(links.map((link) => link.itemId), unorderedEquals(['a', 'b']));
  });

  testWidgets('снять тег пачкой предлагает только теги выбранных вещей', (tester) async {
    await seed();
    await openFolder(tester);
    await select(tester);
    await tester.tap(find.text('Снять тег'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('быстро').last);
    await tester.pumpAndSettle();
    expect(await world.db.select(world.db.itemTags).get(), isEmpty);
  });

  testWidgets('удалить пачкой — в корзину, «Отменить» возвращает', (tester) async {
    await seed();
    await openFolder(tester);
    await select(tester);
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect((await item('a')).deletedAt, isNotNull);
    expect((await item('b')).deletedAt, isNotNull);
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect((await item('a')).deletedAt, isNull);
  });
}
