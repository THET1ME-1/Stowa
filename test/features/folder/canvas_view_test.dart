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
    await tester.tap(find.descendant(of: find.byType(FolderTile), matching: find.text('Идеи')));
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
