import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/json_canvas.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/canvas/canvas_file_screen.dart';
import 'package:stowa/features/canvas/canvas_kit.dart' show CanvasLinksPainter;
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

  // ——— мышь и клавиатура: то же управление, что у холста папки ———

  Future<void> openWide(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'c')));
    await tester.pumpAndSettle();
  }

  int percent(WidgetTester tester) {
    final label = tester.widgetList<Text>(find.byType(Text)).map((text) => text.data ?? '').firstWhere((data) => RegExp(r'^\d+%$').hasMatch(data));
    return int.parse(label.substring(0, label.length - 1));
  }

  Future<void> click(WidgetTester tester, Offset at) async {
    await tester.tapAt(at, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  Rect nodeRect(WidgetTester tester, String id) => tester.getRect(find.byKey(ValueKey('node-$id')));

  // точка мира холста (координаты файла) на экране — по настоящему прямоугольнику узла
  Offset onScreen(WidgetTester tester, CanvasNode node, Offset world) {
    final rect = nodeRect(tester, node.id);
    final scale = rect.width / node.width;
    return rect.topLeft + (world - Offset(node.x.toDouble(), node.y.toDouble())) * scale;
  }

  Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: from);
    await mouse.moveTo(from);
    await tester.pumpAndSettle();
    await mouse.down(from);
    for (var step = 1; step <= 10; step++) {
      await mouse.moveTo(Offset.lerp(from, to, step / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await mouse.up();
    await tester.pumpAndSettle();
    await mouse.removePointer();
  }

  testWidgets('мышь: колесо листает, Ctrl+колесо масштабирует мягко', (tester) async {
    await canvas(CanvasDoc.empty().addText('Замер', x: 0, y: 0).addText('Заказ', x: 900, y: 600));
    await openWide(tester);
    final start = percent(tester);
    final card = CanvasDoc.parse((await stored()).encode()).nodes.first;
    final before = nodeRect(tester, card.id).topLeft;
    tester.binding.handlePointerEvent(PointerScrollEvent(position: const Offset(700, 450), scrollDelta: const Offset(0, 100), kind: PointerDeviceKind.mouse));
    await tester.pumpAndSettle();
    expect(percent(tester), start);
    expect(nodeRect(tester, card.id).top, closeTo(before.dy - 100, 1));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    tester.binding.handlePointerEvent(PointerScrollEvent(position: const Offset(700, 450), scrollDelta: const Offset(0, -100), kind: PointerDeviceKind.mouse));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(percent(tester), greaterThan(start));
    expect(percent(tester), lessThanOrEqualTo((start * 1.19).ceil()));
  });

  testWidgets('мышь: щелчок и Shift+щелчок выбирают две, Delete убирает обе одним «Отменить», заметка за карточкой цела', (tester) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Ремонт', body: const Value('план'), createdAt: world.now, updatedAt: world.now));
    final doc = CanvasDoc.empty().addText('Замер', x: -300, y: 0).addFile('Ремонт.md', x: 100, y: 0);
    await canvas(doc);
    await openWide(tester);
    await click(tester, nodeRect(tester, doc.nodes.first.id).center);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await click(tester, nodeRect(tester, doc.nodes.last.id).center);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await saved(tester);
    expect((await stored()).nodes, isEmpty);
    final note = await (world.db.select(world.db.items)..where((t) => t.id.equals('n'))).getSingle();
    expect(note.deletedAt, isNull);
    await tester.tap(find.text('Отменить'));
    await saved(tester);
    expect((await stored()).nodes, hasLength(2));
  });

  testWidgets('мышь: стрелка клавиатуры двигает выбранную на 10, с Shift — на 50', (tester) async {
    final doc = CanvasDoc.empty().addText('Замер', x: 0, y: 0);
    await canvas(doc);
    await openWide(tester);
    await click(tester, nodeRect(tester, doc.nodes.single.id).center);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await saved(tester);
    final node = (await stored()).nodes.single;
    expect((node.x, node.y), (10, 50));
  });

  testWidgets('мышь: Shift+тянуть по пустому месту — рамка выбирает, тянуть выбранную — едут обе', (tester) async {
    final doc = CanvasDoc.empty().addText('Замер', x: 0, y: 0).addText('Заказ', x: 400, y: 0).addText('Далеко', x: 0, y: 900);
    await canvas(doc);
    await openWide(tester);
    final [first, second, far] = doc.nodes;
    final a = nodeRect(tester, first.id), b = nodeRect(tester, second.id);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await drag(tester, a.topLeft - const Offset(20, 20), b.bottomRight + const Offset(20, 20));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await drag(tester, a.center, a.center + const Offset(0, 60));
    await saved(tester);
    final moved = await stored();
    expect(moved.node(first.id)!.y, greaterThan(0));
    expect(moved.node(second.id)!.y, moved.node(first.id)!.y);
    expect(moved.node(far.id)!.y, 900);
  });

  testWidgets('мышь: провод из точки-выхода на другую карточку — стрелка в файле от этой стороны', (tester) async {
    final doc = CanvasDoc.empty().addText('Замер', x: 0, y: 0).addText('Заказ', x: 500, y: 300);
    await canvas(doc);
    await openWide(tester);
    final [first, second] = doc.nodes;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: nodeRect(tester, first.id).center);
    await mouse.moveTo(nodeRect(tester, first.id).center);
    await tester.pumpAndSettle();
    final socket = tester.getCenter(find.byKey(ValueKey('socket-${first.id}-bottom')));
    await mouse.down(socket);
    final target = nodeRect(tester, second.id).center;
    for (var step = 1; step <= 10; step++) {
      await mouse.moveTo(Offset.lerp(socket, target, step / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await mouse.up();
    await saved(tester);
    final edge = (await stored()).edges.single;
    expect((edge.fromNode, edge.toNode, edge.fromSide), (first.id, second.id, CanvasSide.bottom));
    // карточка, из которой тянули, осталась на месте
    expect((await stored()).node(first.id)!.x, 0);
  });

  testWidgets('мышь: двойной щелчок по пустому месту — заметка, она ложится карточкой-файлом', (tester) async {
    await canvas(CanvasDoc.empty().addText('Замер', x: 0, y: 0));
    await openWide(tester);
    final empty = nodeRect(tester, (await stored()).nodes.single.id).bottomRight + const Offset(200, 150);
    await tester.tapAt(empty, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(empty, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('canvas-note-field')), 'Купить затирку');
    await tester.tap(find.byKey(const ValueKey('canvas-note-done')));
    await tester.pump(const Duration(seconds: 4));
    await saved(tester);
    final note = (await world.db.select(world.db.items).get()).firstWhere((item) => item.kind == ItemKind.note);
    expect(note.body, 'Купить затирку');
    final file = (await stored()).nodes.where((node) => node.type == CanvasNodeType.file).single;
    expect(file.file, endsWith('.md'));
    expect(find.text('Купить затирку'), findsWidgets);
  });

  testWidgets('мышь: щелчок по стрелке выбирает её, Delete убирает', (tester) async {
    var doc = CanvasDoc.empty().addText('Замер', x: 0, y: 0).addText('Заказ', x: 600, y: 0);
    doc = doc.connect(doc.nodes.first.id, doc.nodes.last.id);
    await canvas(doc);
    await openWide(tester);
    final painter = tester.widget<CustomPaint>(find.byKey(const ValueKey('canvas-links'))).painter! as CanvasLinksPainter;
    // мир рисовальщика сдвинут на середину холста (20000)
    final middle = painter.links.single.point(0.3) - const Offset(20000, 20000);
    await click(tester, onScreen(tester, doc.nodes.first, middle));
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await saved(tester);
    expect((await stored()).edges, isEmpty);
    expect((await stored()).nodes, hasLength(2));
  });
}
