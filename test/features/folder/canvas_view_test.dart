import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/app.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/data/repositories/canvas_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/canvas/canvas_kit.dart' show CanvasLinksPainter;
import 'package:stowa/features/home/folder_shelf.dart';

import '../../helpers/test_app.dart';

/// Хранилище мест, которое помнит, кого расставляла пачкой сама расстановка новых карточек.
class _RecordingCanvas extends CanvasRepository {
  _RecordingCanvas(super.db);

  final arranged = <String>{};

  @override
  Future<void> saveAll(String folderId, Map<String, CanvasSpot> spots) {
    arranged.addAll(spots.keys);
    return super.saveAll(folderId, spots);
  }
}

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> openCanvas(WidgetTester tester, {List<Override> extra = const []}) async {
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
    await tester.pumpWidget(extra.isEmpty ? world.app() : ProviderScope(overrides: [...world.overrides, ...extra], child: const StowaApp(locale: Locale('ru'))));
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
  Future<void> openBig(WidgetTester tester, {List<Override> extra = const []}) async {
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
    await tester.pumpWidget(extra.isEmpty ? world.app() : ProviderScope(overrides: [...world.overrides, ...extra], child: const StowaApp(locale: Locale('ru'))));
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

  // хозяин 22.11: «Сделай на холсте функции привязки к сетке»; точки холста папки — шаг 32 от
  // начала мира, а мир сдвинут на 10000
  testWidgets('привязка к сетке: отпущенная карточка и угол растянутой встают на точки сетки', (tester) async {
    SharedPreferences.setMockInitialValues({});
    world.settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore());
    bool onGrid(double value) => (value + 10000) % 32 == 0;
    await openBig(tester);
    final card = find.text('Вещь 0').last;
    final finger = await tester.startGesture(tester.getCenter(card));
    for (var step = 0; step < 6; step++) {
      await finger.moveBy(const Offset(9, 7));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    await tester.pumpAndSettle();
    final spot = (await spots()).firstWhere((one) => one.itemId == 'b0');
    expect((onGrid(spot.x), onGrid(spot.y)), (true, true), reason: '${spot.x}, ${spot.y}');
  });

  // хозяин 22.11: «Когда передвигаешь любой элемент, он телепается обратно и на новую позицию» —
  // экран забывал своё место раньше, чем оно приходило из базы
  testWidgets('отпустил карточку — ни в одном кадре она не прыгает назад, пока место пишется', (tester) async {
    // в браузере база в своём потоке: записанное место приходит назад заметно позже записи
    await openBig(tester, extra: [
      canvasSpotsProvider.overrideWith(
        (ref, folderId) => ref.watch(canvasRepositoryProvider).watch(folderId).asyncMap((spots) async {
          await Future<void>.delayed(const Duration(milliseconds: 150));
          return spots;
        }),
      ),
    ]);
    // места приходят с задержкой таймером, а pumpAndSettle таймеров без кадров не ждёт
    for (var step = 0; step < 6; step++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();
    final card = find.text('Вещь 0').last;
    final finger = await tester.startGesture(tester.getCenter(card));
    for (var step = 0; step < 6; step++) {
      await finger.moveBy(const Offset(10, 6));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final dragged = tester.getTopLeft(card);
    await finger.up();
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect((tester.getTopLeft(find.text('Вещь 0').last) - dragged).distance, lessThan(1.5), reason: 'кадр $frame');
    }
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

  // ——— мышь и клавиатура: компьютер и браузер ———

  Future<void> wheel(WidgetTester tester, Offset at, Offset delta) async {
    tester.binding.handlePointerEvent(PointerScrollEvent(position: at, scrollDelta: delta, kind: PointerDeviceKind.mouse));
    await tester.pumpAndSettle();
  }

  testWidgets('колесо мыши листает холст, а не масштабирует', (tester) async {
    await openBig(tester);
    final start = percent(tester);
    final card = find.text('Вещь 0').last;
    final before = tester.getTopLeft(card);
    await wheel(tester, tester.getCenter(find.byType(InteractiveViewer)), const Offset(0, 100));
    expect(percent(tester), start);
    expect(tester.getTopLeft(card).dy, closeTo(before.dy - 100, 1));
    // Shift+колесо — вбок
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await wheel(tester, tester.getCenter(find.byType(InteractiveViewer)), const Offset(0, 50));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(tester.getTopLeft(card).dx, closeTo(before.dx - 50, 1));
  });

  testWidgets('Ctrl+колесо масштабирует, точка под курсором стоит на месте', (tester) async {
    await openBig(tester);
    final start = percent(tester);
    final card = find.text('Вещь 0').last;
    final under = tester.getTopLeft(card) + const Offset(5, 5);
    final before = tester.getTopLeft(card);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await wheel(tester, under, const Offset(0, -120));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(percent(tester), greaterThan(start));
    // угол карточки рядом с курсором почти не сдвинулся
    expect((tester.getTopLeft(card) - before).distance, lessThan(8));
  });

  testWidgets('Ctrl+колесо в браузере (событие масштаба) — шаг мягкий, точка под курсором на месте', (tester) async {
    await openBig(tester);
    final start = percent(tester);
    final card = find.text('Вещь 0').last;
    final under = tester.getTopLeft(card) + const Offset(5, 5);
    final before = tester.getTopLeft(card);
    // Chromium отдаёт Ctrl+колесо масштабом exp(100/200) ≈ 1,65 за щелчок
    tester.binding.handlePointerEvent(PointerScaleEvent(position: under, scale: 1.65, kind: PointerDeviceKind.mouse));
    await tester.pumpAndSettle();
    expect(percent(tester), greaterThan(start));
    expect(percent(tester), lessThanOrEqualTo(start * 1.19));
    expect((tester.getTopLeft(card) - before).distance, lessThan(8));
  });

  testWidgets('щелчок мышью выделяет карточку, стрелка двигает, Delete — в корзину с «Отменить»', (tester) async {
    await openCanvas(tester);
    final before = (await spots()).firstWhere((spot) => spot.itemId == 'i1');
    await tester.tap(find.text('Свет').last, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    final moved = (await spots()).firstWhere((spot) => spot.itemId == 'i1');
    expect(moved.x, before.x + 10);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    final item = await (world.db.select(world.db.items)..where((t) => t.id.equals('i1'))).getSingle();
    expect(item.deletedAt, isNotNull);
    expect(find.text('Отменить'), findsOneWidget);
  });

  Future<void> shiftClick(WidgetTester tester, Finder target) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(target, kind: PointerDeviceKind.mouse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Shift+щелчок выбирает несколько: стрелка двигает все, Delete убирает все', (tester) async {
    await openCanvas(tester);
    final before = {for (final spot in await spots()) spot.itemId: spot};
    await tester.tap(find.text('Кухня').last, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    await shiftClick(tester, find.text('Свет').last);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final after = {for (final spot in await spots()) spot.itemId: spot};
    expect(after['i0']!.y, before['i0']!.y + 10);
    expect(after['i1']!.y, before['i1']!.y + 10);
    expect(after['i2']!.y, before['i2']!.y);
    // Shift+щелчок по выбранной снимает её
    await shiftClick(tester, find.text('Свет').last);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    final items = {for (final item in await world.db.select(world.db.items).get()) item.id: item};
    expect(items['i0']!.deletedAt, isNotNull);
    expect(items['i1']!.deletedAt, isNull);
  });

  testWidgets('тянешь одну из выбранных — едут все выбранные', (tester) async {
    await openCanvas(tester);
    final before = {for (final spot in await spots()) spot.itemId: spot};
    await tester.tap(find.text('Кухня').last, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    await shiftClick(tester, find.text('Пол').last);
    final mouse = await tester.startGesture(tester.getCenter(find.text('Кухня').last), kind: PointerDeviceKind.mouse);
    for (var step = 0; step < 10; step++) {
      await mouse.moveBy(const Offset(5, 3));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await mouse.up();
    await tester.pumpAndSettle();
    final after = {for (final spot in await spots()) spot.itemId: spot};
    for (final id in ['i0', 'i2']) {
      expect(after[id]!.x, greaterThan(before[id]!.x), reason: id);
      expect(after[id]!.x - before[id]!.x, closeTo(after['i0']!.x - before['i0']!.x, 0.5), reason: id);
    }
    expect(after['i1']!.x, before['i1']!.x);
  });

  testWidgets('Shift+тянуть по пустому месту — рамка выбирает всё, что в неё попало', (tester) async {
    await openCanvas(tester);
    final cards = [for (final title in ['Кухня', 'Свет', 'Пол']) tester.getRect(find.text(title).last)];
    final area = cards.reduce((a, b) => a.expandToInclude(b)).inflate(30);
    final viewBefore = tester.getTopLeft(find.text('Кухня').last);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    final mouse = await tester.startGesture(area.topLeft, kind: PointerDeviceKind.mouse);
    for (var step = 1; step <= 10; step++) {
      await mouse.moveTo(Offset.lerp(area.topLeft, area.bottomRight, step / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await mouse.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    // рамка не тащит холст
    expect(tester.getTopLeft(find.text('Кухня').last), viewBefore);
    final before = {for (final spot in await spots()) spot.itemId: spot};
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    final after = {for (final spot in await spots()) spot.itemId: spot};
    for (final id in ['i0', 'i1', 'i2']) {
      expect(after[id]!.x, before[id]!.x + 10, reason: id);
    }
  });

  // ——— стрелки-связи ———

  List<(String, String)> drawnLinks(WidgetTester tester) =>
      (tester.widget<CustomPaint>(find.byKey(const ValueKey('canvas-links'))).painter! as CanvasLinksPainter).links.map((link) => (link.from, link.to)).toList();

  Future<List<(String, String)>> storedLinks() async => [for (final link in await world.db.select(world.db.links).get()) if (!link.rejected) (link.fromId, link.toId)];

  testWidgets('связь между заметками папки видна стрелкой', (tester) async {
    await world.db.into(world.db.links).insert(LinksCompanion.insert(fromId: 'i0', toId: 'i2', source: LinkSource.manual));
    await openCanvas(tester);
    expect(drawnLinks(tester), [('i0', 'i2')]);
  });

  testWidgets('провод из точки-выхода на другую карточку — связь записана', (tester) async {
    await openCanvas(tester);
    final from = tester.getRect(find.byKey(const ValueKey('i0')));
    final to = tester.getRect(find.byKey(const ValueKey('i1')));
    // мышь над карточкой: точки-выходы проявились
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: from.center);
    await mouse.moveTo(from.center);
    await tester.pumpAndSettle();
    final socket = tester.getCenter(find.byKey(const ValueKey('socket-i0-right')));
    await mouse.down(socket);
    for (var step = 1; step <= 10; step++) {
      await mouse.moveTo(Offset.lerp(socket, to.center, step / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await mouse.up();
    await tester.pumpAndSettle();
    expect(await storedLinks(), [('i0', 'i1')]);
    expect(drawnLinks(tester), [('i0', 'i1')]);
    // карточка, из которой тянули, осталась на месте
    expect(tester.getRect(find.byKey(const ValueKey('i0'))), from);
  });

  testWidgets('ссылка [[…]] в тексте заметки — тоже стрелка', (tester) async {
    await openCanvas(tester);
    await (world.db.update(world.db.items)..where((t) => t.id.equals('i0'))).write(const ItemsCompanion(body: Value('Кухня\nсм. [[Свет]]')));
    await tester.pumpAndSettle();
    expect(drawnLinks(tester), [('i0', 'i1')]);
  });

  testWidgets('связи выбранной карточки рисуются поверх карточек', (tester) async {
    await world.db.into(world.db.links).insert(LinksCompanion.insert(fromId: 'i0', toId: 'i2', source: LinkSource.manual));
    await openCanvas(tester);
    List<(String, String)> over() =>
        (tester.widget<CustomPaint>(find.byKey(const ValueKey('canvas-links-over'))).painter! as CanvasLinksPainter).links.map((link) => (link.from, link.to)).toList();
    expect(over(), isEmpty);
    await tester.tap(find.byKey(const ValueKey('i2')), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(over(), [('i0', 'i2')]);
  });

  testWidgets('щелчок по стрелке выбирает её, Delete убирает связь', (tester) async {
    // соседние карточки: стрелка между ними не уходит под третью
    await world.db.into(world.db.links).insert(LinksCompanion.insert(fromId: 'i0', toId: 'i1', source: LinkSource.manual));
    await openCanvas(tester);
    final painter = tester.widget<CustomPaint>(find.byKey(const ValueKey('canvas-links'))).painter! as CanvasLinksPainter;
    // мир холста → экран по настоящему прямоугольнику карточки (мир сдвинут на 10000)
    final spot = (await spots()).firstWhere((spot) => spot.itemId == 'i0');
    final onScreen = tester.getRect(find.byKey(const ValueKey('i0')));
    final scale = onScreen.width / spot.width;
    final middle = onScreen.topLeft + (painter.links.single.middle - Offset(10000 + spot.x, 10000 + spot.y)) * scale;
    await tester.tapAt(middle, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(await storedLinks(), isEmpty);
  });


  // файл из системы, брошенный мышью: так его отдаёт пакет перетаскивания
  Future<void> dropFile(WidgetTester tester, Offset at, String path) async {
    const codec = StandardMethodCodec();
    Future<void> send(String method, Object arguments) =>
        tester.binding.defaultBinaryMessenger.handlePlatformMessage('desktop_drop', codec.encodeMethodCall(MethodCall(method, arguments)), (_) {});
    await send('entered', [at.dx, at.dy]);
    await tester.pump();
    await send('performOperation', [path]);
    // сохранение читает файл с диска: настоящее время
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump(const Duration(seconds: 4));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
  }

  testWidgets('файл, брошенный мышью на холст папки, — заметка этой папки там, где отпустили', (tester) async {
    final folder = Directory.systemTemp.createTempSync('stowa_drop');
    addTearDown(() => folder.deleteSync(recursive: true));
    final file = File('${folder.path}/план кухни.txt')..writeAsStringSync('плитка 20×20');
    await openCanvas(tester);
    final before = (await world.db.select(world.db.items).get()).length;
    await dropFile(tester, const Offset(200, 500), file.path);
    final all = await world.db.select(world.db.items).get();
    expect(all, hasLength(before + 1));
    final added = all.firstWhere((item) => !['i0', 'i1', 'i2'].contains(item.id));
    expect(added.folderId, 'ideas');
    expect((await spots()).map((spot) => spot.itemId), contains(added.id));
    // там, где отпустили, а не в ячейке справа от разложенных: расстановка новых карточек
    // не должна затирать место, которое выбрал бросок
    final card = tester.getRect(find.byKey(ValueKey(added.id)));
    expect(card.contains(const Offset(200, 500)), isTrue, reason: 'карточка $card, бросили в (200, 500)');
    final others = [for (final id in ['i0', 'i1', 'i2']) tester.getRect(find.byKey(ValueKey(id)))];
    expect(card.top, greaterThan(others.map((rect) => rect.top).reduce((a, b) => a < b ? a : b) + 40), reason: 'не в верхнем ряду');
  });

  testWidgets('место брошенного файла не затирает расстановка новых карточек, когда места доходят до холста с опозданием', (tester) async {
    // так в браузере: заметка уже на холсте, а её место из базы ещё в пути. Холст считал
    // карточку неразложенной, ставил её справа от остальных и этой записью затирал место броска
    final folder = Directory.systemTemp.createTempSync('stowa_drop_late');
    addTearDown(() => folder.deleteSync(recursive: true));
    final file = File('${folder.path}/план кухни.txt')..writeAsStringSync('плитка 20×20');
    final repository = _RecordingCanvas(world.db);
    final late = canvasSpotsProvider.overrideWith(
      (ref, folderId) => repository.watch(folderId).asyncMap((spots) => Future.delayed(const Duration(milliseconds: 400), () => spots)),
    );
    await openCanvas(tester, extra: [canvasRepositoryProvider.overrideWithValue(repository), late]);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    const codec = StandardMethodCodec();
    Future<void> send(String method, Object arguments) =>
        tester.binding.defaultBinaryMessenger.handlePlatformMessage('desktop_drop', codec.encodeMethodCall(MethodCall(method, arguments)), (_) {});
    await send('entered', [200.0, 500.0]);
    await tester.pump();
    await send('performOperation', [file.path]);
    // заметка сохраняется и её место пишется в базу (настоящее время: файл читается с диска)
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    // кадры идут, заметка уже на холсте, а место ещё в пути: тут расстановка и затирала его
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    final added = (await world.db.select(world.db.items).get()).firstWhere((item) => !['i0', 'i1', 'i2'].contains(item.id));
    expect((await spots()).map((spot) => spot.itemId), contains(added.id));
    expect(repository.arranged, isNot(contains(added.id)), reason: 'расстановка новых карточек записала место поверх выбранного броском');
  });

  testWidgets('пальцем карточка не выделяется: Delete на телефоне ничего не удаляет', (tester) async {
    await openCanvas(tester);
    await tester.tap(find.text('Свет').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    final item = await (world.db.select(world.db.items)..where((t) => t.id.equals('i1'))).getSingle();
    expect(item.deletedAt, isNull);
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
