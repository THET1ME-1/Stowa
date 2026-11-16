import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/json_canvas.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/canvas/canvas_file_screen.dart';
import 'package:stowa/features/item/item_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> canvas(CanvasDoc doc) => world.db.into(world.db.items).insert(
    ItemsCompanion.insert(id: 'c', kind: ItemKind.canvas, title: 'План ремонта', document: Value(doc.encode()), body: Value(doc.plainText()), createdAt: world.now, updatedAt: world.now),
  );
  Future<CanvasDoc> stored() async => CanvasDoc.parse((await (world.db.select(world.db.items)..where((t) => t.id.equals('c'))).getSingle()).document!);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'c')));
    await tester.pumpAndSettle();
  }

  // у карточки есть двойное касание: одиночное срабатывает после его срока
  Future<void> tapNode(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(ValueKey('node-$id')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  // правка уходит в файл через 0,6 с после последнего движения
  Future<void> saved(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('карточка заметки со ссылкой на заголовок показывает только этот раздел', (tester) async {
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Ремонт', body: const Value('Вступление.\n\n## Покупки\n- молоко\n\n## Сроки\n- март'), createdAt: world.now, updatedAt: world.now),
    );
    await canvas(CanvasDoc.parse('{"nodes":[{"id":"f","type":"file","file":"Ремонт.md","subpath":"#Покупки","x":0,"y":0,"width":300,"height":200}],"edges":[]}'));
    await open(tester);
    expect(find.text('Ремонт › Покупки'), findsOneWidget);
    expect(find.textContaining('молоко', findRichText: true), findsOneWidget);
    expect(find.textContaining('Вступление', findRichText: true), findsNothing);
    expect(find.textContaining('март', findRichText: true), findsNothing);
  });

  testWidgets('заметка-холст открывается холстом: имя и число карточек в шапке', (tester) async {
    await canvas(CanvasDoc.empty().addText('купить плитку', x: 0, y: 0));
    await open(tester);
    expect(find.byType(CanvasFileScreen), findsOneWidget);
    expect(find.text('План ремонта'), findsOneWidget);
    expect(find.text('Холст · 1 карточка'), findsOneWidget);
    expect(find.text('купить плитку'), findsOneWidget);
  });

  testWidgets('«+» → «Текст»: карточка встаёт на холст и пишется в файл', (tester) async {
    await canvas(CanvasDoc.empty());
    await open(tester);
    expect(find.text('Пустой холст. Коснитесь дважды, чтобы добавить карточку.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('canvas-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Текст'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('canvas-text-field')), 'Позвонить электрику');
    await tester.tap(find.byKey(const ValueKey('canvas-text-done')));
    await tester.pumpAndSettle();
    expect(find.text('Позвонить электрику'), findsOneWidget);
    await saved(tester);
    final doc = await stored();
    expect(doc.nodes.single.text, 'Позвонить электрику');
    // текст карточки ищется
    expect(await world.db.searchIds('электрику'), ['c']);
  });

  testWidgets('выбрал карточку, «Связать», коснулся второй — стрелка в файле', (tester) async {
    final doc = CanvasDoc.empty().addText('Замер', x: -300, y: 0).addText('Заказ плитки', x: 100, y: 0);
    await canvas(doc);
    await open(tester);
    final [first, second] = doc.nodes;
    await tapNode(tester, first.id);
    await tester.tap(find.byKey(const ValueKey('node-connect')));
    await tester.pumpAndSettle();
    expect(find.text('Коснитесь карточки, к которой провести стрелку'), findsOneWidget);
    await tapNode(tester, second.id);
    await saved(tester);
    final edge = (await stored()).edges.single;
    expect((edge.fromNode, edge.toNode), (first.id, second.id));
  });

  testWidgets('удаление карточки убирает и её стрелки, «Отменить» возвращает всё', (tester) async {
    var doc = CanvasDoc.empty().addText('Замер', x: -300, y: 0).addText('Заказ', x: 100, y: 0);
    doc = doc.connect(doc.nodes.first.id, doc.nodes.last.id);
    await canvas(doc);
    await open(tester);
    await tapNode(tester, doc.nodes.first.id);
    await tester.tap(find.byKey(const ValueKey('node-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Замер'), findsNothing);
    await tester.tap(find.text('Отменить'));
    await saved(tester);
    final back = await stored();
    expect(back.nodes, hasLength(2));
    expect(back.edges, hasLength(1));
  });

  testWidgets('правка файла снаружи видна на открытом холсте', (tester) async {
    final doc = CanvasDoc.empty().addText('Было', x: 0, y: 0);
    await canvas(doc);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    final item = await (world.db.select(world.db.items)..where((t) => t.id.equals('c'))).getSingle();
    await tester.pumpWidget(world.wrap(CanvasFileScreen(item: item)));
    await tester.pumpAndSettle();
    expect(find.text('Было'), findsOneWidget);
    // экран заметки отдаёт холсту новую версию, когда файл правили в Obsidian
    final next = doc.updateNode(doc.nodes.single.id, {'text': 'Стало'});
    await tester.pumpWidget(world.wrap(CanvasFileScreen(item: item.copyWith(document: Value(next.encode())))));
    await tester.pumpAndSettle();
    expect(find.text('Стало'), findsOneWidget);
  });

  testWidgets('битый файл: пометка, кнопки добавить нет, файл не переписывается', (tester) async {
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'c', kind: ItemKind.canvas, title: 'Сломанный', document: const Value('{"nodes": ['), createdAt: world.now, updatedAt: world.now),
    );
    await open(tester);
    expect(find.text('Файл холста повреждён, Stowa его не меняет. Откройте его в Obsidian.'), findsOneWidget);
    expect(find.byKey(const ValueKey('canvas-add')), findsNothing);
  });
}
