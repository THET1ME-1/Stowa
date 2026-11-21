import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_dock.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/features/workspace/workspace_model.dart';
import 'package:stowa/features/workspace/workspace_shell.dart';
import 'package:stowa/services/place_search.dart';
import 'package:stowa/services/place_service.dart';

import '../../helpers/test_app.dart';

// 21.11 хозяин: «у готовых заметок нельзя выбрать местоположение вручную, если его не было
// изначально при создании». Место ставится и меняется на странице заметки, на телефоне и на мониторе
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> note(TestWorld world, {double? latitude, double? longitude, String? placeName}) => world.db.into(world.db.items).insert(
    ItemsCompanion.insert(
      id: 'a',
      kind: ItemKind.note,
      title: 'Кофе',
      body: const Value('зерно из той лавки'),
      latitude: Value(latitude),
      longitude: Value(longitude),
      placeName: Value(placeName),
      createdAt: world.now,
      updatedAt: world.now,
    ),
  );

  Future<void> home(TestWorld world) => world.db.into(world.db.places).insert(PlacesCompanion.insert(id: 'home', kind: PlaceKind.home, name: 'Дом', latitude: 47.06, longitude: 28.86, createdAt: world.now));

  Future<Item> stored(TestWorld world) => (world.db.select(world.db.items)..where((t) => t.id.equals('a'))).getSingle();

  Future<void> phone(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
  }

  testWidgets('телефон: у заметки без места — «Добавить место», своё место из списка ставится одним касанием', (tester) async {
    await note(world);
    await home(world);
    await phone(tester);

    await tester.tap(find.byKey(const ValueKey('place-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-place-sheet')), findsOneWidget);
    expect(find.text('Убрать место'), findsNothing, reason: 'убирать нечего');
    await tester.tap(find.text('Дом'));
    await tester.pumpAndSettle();

    final item = await stored(world);
    expect((item.latitude, item.longitude, item.placeName), (47.06, 28.86, 'Дом'));
    expect(find.byKey(const ValueKey('item-place')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('item-place')), matching: find.text('Дом')), findsOneWidget);
  });

  testWidgets('поиск адреса: найденное ставится с городом в названии', (tester) async {
    await note(world);
    world.placeLookup.found = const [FoundPlace(name: 'Strada Mihai Eminescu 12', address: 'Chișinău', latitude: 47.0201, longitude: 28.8302)];
    await phone(tester);

    await tester.tap(find.byKey(const ValueKey('place-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('note-place-search')), 'Eminescu');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(world.placeLookup.queries, contains('Eminescu'));
    await tester.tap(find.text('Strada Mihai Eminescu 12'));
    await tester.pumpAndSettle();

    final item = await stored(world);
    expect((item.latitude, item.longitude, item.placeName), (47.0201, 28.8302, 'Strada Mihai Eminescu 12, Chișinău'));
  });

  testWidgets('«Я сейчас здесь» ставит точку, где человек сейчас', (tester) async {
    await note(world);
    world.currentPlace = const PlaceFix(latitude: 47.0245, longitude: 28.8323, name: 'Ботаника, Кишинёв');
    await phone(tester);

    await tester.tap(find.byKey(const ValueKey('place-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Я сейчас здесь'));
    await tester.pumpAndSettle();

    final item = await stored(world);
    expect((item.latitude, item.longitude, item.placeName), (47.0245, 28.8323, 'Ботаника, Кишинёв'));
  });

  testWidgets('место не узнать — подсказка, заметка без изменений', (tester) async {
    await note(world);
    world.currentPlace = null;
    await phone(tester);

    await tester.tap(find.byKey(const ValueKey('place-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Я сейчас здесь'));
    await tester.pumpAndSettle();

    expect((await stored(world)).latitude, isNull);
    expect(find.textContaining('Не вышло узнать, где ты'), findsOneWidget);
  });

  testWidgets('выбор на карте: булавка в середине, «Поставить сюда» берёт точку и её адрес', (tester) async {
    await note(world);
    await home(world);
    await phone(tester);

    await tester.tap(find.byKey(const ValueKey('place-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выбрать на карте'));
    // карта тянет плитки из сети: ждём только въезд экрана
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('note-place-map')), findsOneWidget);
    // карта открылась у своего места: точка заметки ещё не стоит
    await tester.tap(find.byKey(const ValueKey('note-place-set')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final item = await stored(world);
    expect(item.latitude, closeTo(47.06, 0.0001));
    expect(item.longitude, closeTo(28.86, 0.0001));
    expect(item.placeName, 'Strada Pușkin 52, Chișinău');
  });

  testWidgets('место есть: касание — лист с картой и «Убрать место», «Отменить» возвращает', (tester) async {
    await note(world, latitude: 47.0245, longitude: 28.8323, placeName: 'Ботаника, Кишинёв');
    await phone(tester);

    await tester.tap(find.byKey(const ValueKey('item-place')));
    await tester.pumpAndSettle();
    expect(find.text('Показать на карте'), findsOneWidget);
    await tester.tap(find.text('Убрать место'));
    await tester.pumpAndSettle();
    expect((await stored(world)).latitude, isNull);
    expect(find.byKey(const ValueKey('place-add')), findsOneWidget);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    final item = await stored(world);
    expect((item.latitude, item.longitude, item.placeName), (47.0245, 28.8323, 'Ботаника, Кишинёв'));
  });

  testWidgets('монитор: строка «Место» есть всегда, пустая — «+ Место», выбор ставит место', (tester) async {
    await note(world);
    await home(world);
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!.open(const WsTab.item('a'));
    await tester.pumpAndSettle();

    final props = find.byKey(const ValueKey('desk-props'));
    expect(find.descendant(of: props, matching: find.text('Место')), findsOneWidget);
    await tester.tap(find.descendant(of: props, matching: find.byKey(const ValueKey('place-add'))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-place-sheet')), findsOneWidget);
    await tester.tap(find.text('Дом'));
    await tester.pumpAndSettle();

    expect((await stored(world)).placeName, 'Дом');
    expect(find.descendant(of: props, matching: find.text('Дом')), findsOneWidget);
  });
}
