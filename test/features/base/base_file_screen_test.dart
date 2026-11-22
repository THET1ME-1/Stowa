import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/base_edit.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/obsidian_base.dart';
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
    // в шапке ещё и папка, как у заметки
    expect(find.textContaining('База · 2 заметки'), findsOneWidget);
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

  Future<String> document() async => (await (world.db.select(world.db.items)..where((t) => t.id.equals('base'))).getSingle()).document!;

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
  }

  testWidgets('сортировка из панели ложится в файл, таблица пересобирается', (tester) async {
    await seed();
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('base-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('base-sort-direction-0')));
    await tester.pumpAndSettle();
    await closeSheet(tester);
    expect(ObsidianBase.parse(await document()).views.first.sort, [(property: 'rating', descending: false)]);
    expect(tester.getTopLeft(find.text('Идиот')).dy, lessThan(tester.getTopLeft(find.text('Мастер и Маргарита')).dy));
  });

  testWidgets('условие «этого вида» из окна фильтра: свойство, значение, файл', (tester) async {
    await seed();
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('base-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Этот вид'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filter-add-')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('base-pick-status')));
    await tester.tap(find.byKey(const ValueKey('base-pick-status')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filter-value')), 'прочитано');
    await tester.pump();
    await closeSheet(tester);
    final base = ObsidianBase.parse(await document());
    expect(describeFilter(base.views.first.filters), 'and(status == "прочитано")');
    // общее условие осталось где было
    expect(describeFilter(base.filters), 'file.inFolder("Книги")');
    expect(find.text('Мастер и Маргарита'), findsNothing);
    expect(find.text('Идиот'), findsOneWidget);
  });

  testWidgets('свойства: включённое свойство становится колонкой', (tester) async {
    await seed();
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('base-properties')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('base-prop-switch-status')), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(const ValueKey('base-prop-switch-status')));
    await tester.pumpAndSettle();
    await closeSheet(tester);
    expect(ObsidianBase.parse(await document()).views.first.order, ['file.name', 'note.author', 'rating', 'status']);
    expect(find.text('читаю'), findsOneWidget);
  });

  testWidgets('итог колонки из её меню: «Среднее» под таблицей', (tester) async {
    await seed();
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('base-head-rating')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Итог'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Среднее'));
    await tester.pumpAndSettle();
    expect(ObsidianBase.parse(await document()).views.first.summaryOf('rating'), 'Average');
    expect(find.text('Среднее 4'), findsOneWidget);
  });

  testWidgets('«Создать» во втором виде: заметка в папке базы со свойством из условия вида', (tester) async {
    await seed();
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('base-view-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('base-create')));
    await tester.pumpAndSettle();
    final made = await (world.db.select(world.db.items)..where((t) => t.title.equals('Без названия'))).getSingle();
    expect(made.folderId, 'books');
    expect(made.properties, contains('"status":"читаю"'));
    expect(find.byWidgetPredicate((widget) => widget is ItemScreen && widget.id == made.id), findsOneWidget);
  });

  testWidgets('доска: карточку перетащили в другую колонку — свойство заметки поменялось', (tester) async {
    await seed();
    await (world.db.update(world.db.items)..where((t) => t.id.equals('base'))).write(
      const ItemsCompanion(document: Value('filters: file.inFolder("Книги")\nviews:\n  - type: kanban\n    name: Доска\n    groupBy:\n      property: status\n      direction: ASC\n')),
    );
    await open(tester);
    expect(find.byKey(const ValueKey('base-column-читаю')), findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('base-row-a'))));
    await tester.pump(const Duration(milliseconds: 600));
    // соседняя колонка за краем экрана: карточку держат у края, доска едет сама
    final edge = Offset(tester.view.physicalSize.width / tester.view.devicePixelRatio - 20, 300);
    for (var i = 0; i < 20; i++) {
      await gesture.moveTo(edge + Offset(0, i.isEven ? 1 : 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.moveTo(tester.getTopLeft(find.byKey(const ValueKey('base-column-читаю'))) + const Offset(40, 120));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    final idiot = await (world.db.select(world.db.items)..where((t) => t.id.equals('a'))).getSingle();
    expect(idiot.properties, contains('"status":"читаю"'));
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
