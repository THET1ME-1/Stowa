import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/base/base_file_screen.dart';
import 'package:stowa/features/item/item_screen.dart';

import '../../helpers/test_app.dart';

const _base = '''
filters: file.inFolder("Книги")
properties:
  note.author:
    displayName: Автор
views:
  - type: table
    name: Все
    order: [file.name, note.author, rating]
    sort:
      - property: rating
        direction: DESC
  - type: list
    name: Читаю
    filters: status == "читаю"
''';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> seed() async {
    final db = world.db;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'books', name: 'Книги', icon: 'folder', shape: 'squircle'));
    for (final (id, title, props) in [
      ('a', 'Идиот', '{"author":"Достоевский","rating":3,"status":"прочитано"}'),
      ('b', 'Мастер и Маргарита', '{"author":"Булгаков","rating":5,"status":"читаю"}'),
    ]) {
      await db.into(db.items).insert(ItemsCompanion.insert(id: id, kind: ItemKind.note, title: title, folderId: const Value('books'), properties: Value(props), createdAt: world.now, updatedAt: world.now));
    }
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'other', kind: ItemKind.note, title: 'Купить', createdAt: world.now, updatedAt: world.now));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'base', kind: ItemKind.base, title: 'Книги', document: const Value(_base), createdAt: world.now, updatedAt: world.now));
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'base')));
    await tester.pumpAndSettle();
  }

  testWidgets('база открывается таблицей: заметки папки по оценке, подписи колонок из файла', (tester) async {
    await seed();
    await open(tester);
    expect(find.byType(BaseFileScreen), findsOneWidget);
    expect(find.text('База · 2 заметки'), findsOneWidget);
    expect(find.text('Автор'), findsOneWidget);
    expect(find.text('Название'), findsOneWidget);
    expect(find.text('Купить'), findsNothing);
    final master = tester.getTopLeft(find.text('Мастер и Маргарита')).dy;
    final idiot = tester.getTopLeft(find.text('Идиот')).dy;
    expect(master, lessThan(idiot));
    expect(find.text('Булгаков'), findsOneWidget);
  });

  testWidgets('второй вид — свои условия; касание строки открывает заметку', (tester) async {
    await seed();
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('base-view-1')));
    await tester.pumpAndSettle();
    expect(find.text('Идиот'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('base-row-b')));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((widget) => widget is ItemScreen && widget.id == 'b'), findsOneWidget);
  });

  testWidgets('новая заметка в папке появляется в открытой базе сама', (tester) async {
    await seed();
    await open(tester);
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'c', kind: ItemKind.note, title: 'Идиот 2', folderId: const Value('books'), createdAt: world.now, updatedAt: world.now),
    );
    await tester.pumpAndSettle();
    expect(find.text('Идиот 2'), findsOneWidget);
  });
}
