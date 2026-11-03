import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/folder/folder_cards.dart';
import 'package:stowa/features/sort/sort_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> note(String id, String title, {String? folder, int minutes = 0}) async {
    final at = world.now.subtract(Duration(minutes: 30 - minutes));
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: id,
          kind: ItemKind.note,
          title: title,
          body: Value(title),
          folderId: Value(folder),
          createdAt: at,
          updatedAt: at,
        ));
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const SortScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('подсказка первой, касание кладёт в папку и показывает следующую', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'car', name: 'Машина', icon: 'directions_car', shape: 'pill'));
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'home', shape: 'squircle'));
    await note('c1', 'Замена масла и фильтра', folder: 'car');
    await note('c2', 'Масло 5W-30', folder: 'car');
    await note('h1', 'Пароль от вайфая', folder: 'home');
    await note('a', 'Купить масло для машины', minutes: 1);
    await note('b', 'Позвонить маме', minutes: 2);
    await open(tester);

    expect(find.text('Осталось 2'), findsOneWidget);
    expect(find.text('Позвонить маме'), findsOneWidget);
    await tester.tap(find.text('Дом'));
    await tester.pumpAndSettle();
    expect((await (world.db.select(world.db.items)..where((t) => t.id.equals('b'))).getSingle()).folderId, 'home');

    expect(find.text('Купить масло для машины'), findsOneWidget);
    // первая кнопка — подсказка по словам
    final first = tester.getTopLeft(find.text('Машина')).dx;
    expect(first, lessThan(tester.getTopLeft(find.text('Дом')).dx));
  });

  testWidgets('карточка во всю ширину, полоса показывает, сколько разобрано', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'home', shape: 'squircle'));
    await note('a', 'Мысль', minutes: 1);
    await note('b', 'Ещё мысль', minutes: 2);
    await open(tester);
    final card = find.ancestor(of: find.text('Ещё мысль'), matching: find.byType(FolderItemCard));
    expect(tester.getSize(card).width, greaterThan(400 - 2 * 24 - 1));
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0);

    await tester.tap(find.text('Дом'));
    await tester.pumpAndSettle();
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.5);
  });

  testWidgets('«Пропустить» оставляет вещь без папки', (tester) async {
    await note('a', 'Мысль');
    await open(tester);
    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();
    expect(find.text('Всё разобрано'), findsOneWidget);
    expect((await world.db.select(world.db.items).getSingle()).folderId, isNull);
  });

  testWidgets('нажал не ту папку — «Отменить» возвращает вещь в разбор', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'home', shape: 'squircle'));
    await note('a', 'Мысль');
    await open(tester);
    await tester.tap(find.text('Дом'));
    await tester.pumpAndSettle();
    expect(find.text('Переложил в «Дом»'), findsOneWidget);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Мысль'), findsOneWidget);
    expect((await world.db.select(world.db.items).getSingle()).folderId, isNull);
  });

  testWidgets('новая папка прямо из разбора', (tester) async {
    await note('a', 'Рецепт сырников');
    await open(tester);
    await tester.tap(find.text('Новая'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'рецепты');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final item = await world.db.select(world.db.items).getSingle();
    final folder = await world.db.select(world.db.folders).getSingle();
    expect(folder.name, 'Рецепты');
    expect(item.folderId, folder.id);
  });

  testWidgets('смахнул вверх — в корзину, «Отменить» возвращает', (tester) async {
    await note('a', 'Мусор');
    await open(tester);
    await tester.fling(find.text('Мусор'), const Offset(0, -400), 2000);
    await tester.pumpAndSettle();
    expect(find.text('Всё разобрано'), findsOneWidget);
    expect((await world.db.select(world.db.items).getSingle()).deletedAt, isNotNull);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Мусор'), findsOneWidget);
  });
}
