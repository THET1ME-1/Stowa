import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/home/folder_shelf.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> openCanvas(WidgetTester tester) async {
    final db = world.db;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'ideas', name: 'Идеи', icon: 'lightbulb', shape: 'pill'));
    for (final (index, title) in ['Кухня', 'Свет', 'Пол'].indexed) {
      final at = world.now.subtract(Duration(minutes: index));
      await db.into(db.items).insert(
        ItemsCompanion.insert(id: 'i$index', kind: ItemKind.note, title: title, body: Value(title), folderId: const Value('ideas'), sortState: const Value(SortState.sorted), createdAt: at, updatedAt: at),
      );
    }
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(FolderPill), matching: find.text('Идеи')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Холст'));
    await tester.pumpAndSettle();
  }

  Future<List<CanvasPosition>> spots() => world.db.select(world.db.canvasPositions).get();

  testWidgets('холст раскладывает все вещи папки и запоминает выбор вида', (tester) async {
    await openCanvas(tester);
    expect((await spots()).map((spot) => spot.itemId), unorderedEquals(['i0', 'i1', 'i2']));
    final folder = await world.db.select(world.db.folders).getSingle();
    expect(folder.view, FolderView.canvas);
    expect(find.text('Кухня'), findsWidgets);
  });

  testWidgets('обложка ссылки 18+ на холсте размыта, пока показ выключен', (tester) async {
    final db = world.db;
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'x',
          kind: ItemKind.link,
          title: 'Ссылка',
          url: const Value('https://www.xvideos.com/x'),
          coverPath: const Value('covers/x.jpg'),
          folderId: const Value('ideas'),
          sortState: const Value(SortState.sorted),
          createdAt: world.now,
          updatedAt: world.now,
        ));
    await db.into(db.facts).insert(FactsCompanion.insert(id: 'x-adult', itemId: 'x', extractor: 'page', kind: FactKind.adult, value: '18+'));
    await openCanvas(tester);
    expect(find.byKey(const ValueKey('adult-veil-x')), findsOneWidget);
  });

  // большая папка: целиком она видна только мельче 100 %
  Future<void> openBig(WidgetTester tester) async {
    final db = world.db;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'big', name: 'Большая', icon: 'folder', shape: 'pill'));
    for (var index = 0; index < 14; index++) {
      await db.into(db.items).insert(
        ItemsCompanion.insert(id: 'b$index', kind: ItemKind.note, title: 'Вещь $index', folderId: const Value('big'), sortState: const Value(SortState.sorted), createdAt: world.now, updatedAt: world.now),
      );
    }
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(FolderPill), matching: find.text('Большая')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Холст'));
    await tester.pumpAndSettle();
  }

  int percent(WidgetTester tester) => int.parse(tester.widget<Text>(find.textContaining('%')).data!.replaceAll('%', ''));

  testWidgets('на отдалённом холсте карточка идёт ровно за пальцем, а не быстрее', (tester) async {
    await openBig(tester);
    expect(percent(tester), lessThan(100));
    final card = find.text('Вещь 0').last;
    final before = tester.getTopLeft(card);
    // палец как на телефоне: кадры идут между движениями
    final finger = await tester.startGesture(tester.getCenter(card));
    for (var step = 0; step < 10; step++) {
      await finger.moveBy(const Offset(6, 4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    await tester.pumpAndSettle();
    final moved = tester.getTopLeft(find.text('Вещь 0').last) - before;
    expect(moved.dx, closeTo(60, 1.5));
    expect(moved.dy, closeTo(40, 1.5));
  });

  testWidgets('щипок двумя пальцами, один на карточке, — масштаб, а карточка на месте', (tester) async {
    await openBig(tester);
    final start = percent(tester);
    final card = find.text('Вещь 0').last;
    final spotBefore = (await spots()).firstWhere((spot) => spot.itemId == 'b0');
    final onCard = tester.getCenter(card);
    // карточка у нижнего края: второй палец ставим выше, внутри экрана
    final aside = onCard - const Offset(0, 160);
    final first = await tester.startGesture(onCard, pointer: 1);
    await tester.pump(const Duration(milliseconds: 20));
    final second = await tester.startGesture(aside, pointer: 2);
    for (var step = 1; step <= 10; step++) {
      await first.moveTo(onCard + Offset(0, step * 4.0));
      await second.moveTo(aside - Offset(0, step * 12.0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(percent(tester), greaterThan(start));
    final spotAfter = (await spots()).firstWhere((spot) => spot.itemId == 'b0');
    expect(spotAfter.x, spotBefore.x);
    expect(spotAfter.y, spotBefore.y);
  });

  testWidgets('угол карточки на отдалённом холсте растит её ровно на сдвиг пальца', (tester) async {
    await openBig(tester);
    final scale = percent(tester) / 100;
    final before = (await spots()).firstWhere((spot) => spot.itemId == 'b0');
    final card = tester.getRect(find.byKey(const ValueKey('b0')));
    // угол сидит за правым нижним краем карточки
    final finger = await tester.startGesture(card.bottomRight - Offset(8 * scale, 8 * scale));
    for (var step = 0; step < 10; step++) {
      await finger.moveBy(const Offset(4, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    await tester.pumpAndSettle();
    final after = (await spots()).firstWhere((spot) => spot.itemId == 'b0');
    // 40 точек экрана на холсте в масштабе scale — это 40 / scale единиц холста
    expect(after.width - before.width, closeTo(40 / scale, 40 / scale * 0.05));
    expect(after.x, before.x);
  });

  testWidgets('первый показ умещает всё, масштаб в пилюле честный', (tester) async {
    final db = world.db;
    // много вещей: целиком они помещаются только мельче 100 %
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'big', name: 'Большая', icon: 'folder', shape: 'pill'));
    for (var index = 0; index < 14; index++) {
      await db.into(db.items).insert(
        ItemsCompanion.insert(id: 'b$index', kind: ItemKind.note, title: 'Вещь $index', folderId: const Value('big'), sortState: const Value(SortState.sorted), createdAt: world.now, updatedAt: world.now),
      );
    }
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'x', name: 'Пустая', icon: 'folder', shape: 'pill', sortOrder: const Value(9)));
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(FolderPill), matching: find.text('Большая')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Холст'));
    await tester.pumpAndSettle();
    final label = find.textContaining('%');
    final percent = int.parse(tester.widget<Text>(label).data!.replaceAll('%', ''));
    expect(percent, lessThan(100));
  });

  testWidgets('перетащил вещь — новое место записано, когда отпустил палец', (tester) async {
    await openCanvas(tester);
    final before = (await spots()).firstWhere((spot) => spot.itemId == 'i0');
    await tester.drag(find.text('Кухня').last, const Offset(60, 40));
    await tester.pumpAndSettle();
    final after = (await spots()).firstWhere((spot) => spot.itemId == 'i0');
    expect(after.x, greaterThan(before.x));
    expect(after.y, greaterThan(before.y));
  });

  testWidgets('двойное касание открывает вещь', (tester) async {
    await openCanvas(tester);
    await tester.tap(find.text('Свет').last);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Свет').last);
    await tester.pumpAndSettle();
    // открылась страница вещи: внизу её белая кнопка
    expect(find.text('Дописать'), findsOneWidget);
  });
}
