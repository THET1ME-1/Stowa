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
    final kinds = [
      ('n', ItemKind.note, 'Борщ как у бабушки', null),
      ('l', ItemKind.link, 'Как варить кофе в турке', 'https://coffee-guide.ru/turka'),
      ('v', ItemKind.video, 'Тарт с малиной', 'https://www.tiktok.com/@chef/1'),
    ];
    for (final (index, (id, kind, title, url)) in kinds.indexed) {
      final at = world.now.subtract(Duration(minutes: 10 - index));
      await db.into(db.items).insert(ItemsCompanion.insert(
            id: id,
            kind: kind,
            title: title,
            body: Value(title),
            url: Value(url),
            folderId: const Value('food'),
            sortState: const Value(SortState.sorted),
            createdAt: at,
            updatedAt: at,
          ));
    }
  }

  Future<void> openFolder(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    // имя папки есть и в подписях карточек «Только что», жмём по плитке
    await tester.tap(find.descendant(of: find.byType(FolderTile), matching: find.text('Рецепты')));
    await tester.pumpAndSettle();
  }

  testWidgets('тап по папке на главной открывает её: имя, число, все вещи', (tester) async {
    await seed();
    await openFolder(tester);
    expect(find.text('Рецепты'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Борщ как у бабушки'), findsOneWidget);
    expect(find.text('Как варить кофе в турке'), findsOneWidget);
    expect(find.text('tiktok.com'), findsOneWidget);
  });

  testWidgets('чип вида оставляет только ссылки', (tester) async {
    await seed();
    await openFolder(tester);
    await tester.tap(find.text('Ссылки'));
    await tester.pumpAndSettle();
    expect(find.text('Как варить кофе в турке'), findsOneWidget);
    expect(find.text('Борщ как у бабушки'), findsNothing);
  });

  testWidgets('«Закинуть сюда» кладёт прямо в эту папку', (tester) async {
    await seed();
    await openFolder(tester);
    expect(find.text('Закинуть сюда'), findsOneWidget);
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Сырники на рисовой муке');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Закинуть в «Рецепты»'), findsOneWidget);
    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();

    final saved = await (world.db.select(world.db.items)..where((t) => t.title.equals('Сырники на рисовой муке'))).getSingle();
    expect(saved.folderId, 'food');
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('переименовать через меню', (tester) async {
    await seed();
    await openFolder(tester);
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переименовать'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Рецепты'), 'еда дома');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Еда дома'), findsOneWidget);
  });

  testWidgets('удалить папку: вещи без папки, «Вернуть» возвращает', (tester) async {
    await seed();
    await openFolder(tester);
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить папку'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить папку'));
    await tester.pumpAndSettle();

    expect(find.text('Папка удалена'), findsOneWidget);
    expect((await world.db.select(world.db.items).get()).every((item) => item.folderId == null), isTrue);
    await tester.tap(find.text('Вернуть'));
    await tester.pumpAndSettle();
    expect((await world.db.select(world.db.items).get()).every((item) => item.folderId == 'food'), isTrue);
  });

  testWidgets('папка влезает в 320 точек при крупном шрифте', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seed();
    await openFolder(tester);
    expect(tester.takeException(), isNull);
  });
}
