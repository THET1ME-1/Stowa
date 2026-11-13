import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show TileLayer;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> add(String id, String title, {double? latitude, double? longitude, String? place}) => world.db
      .into(world.db.items)
      .insert(
        ItemsCompanion.insert(
          id: id,
          kind: ItemKind.note,
          title: title,
          body: Value(title),
          latitude: Value(latitude),
          longitude: Value(longitude),
          placeName: Value(place),
          createdAt: world.now,
          updatedAt: world.now,
        ),
      );

  Future<void> openMap(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Карта'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    // камера встаёт по размеру карты кадром позже
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('метка ссылки 18+ с обложкой — размыта, пока показ выключен', (tester) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'x',
          kind: ItemKind.link,
          title: 'Ссылка',
          url: const Value('https://www.xvideos.com/x'),
          coverPath: const Value('covers/x.jpg'),
          latitude: const Value(47.0245),
          longitude: const Value(28.8323),
          createdAt: world.now,
          updatedAt: world.now,
        ));
    await world.db.into(world.db.facts).insert(FactsCompanion.insert(id: 'x-adult', itemId: 'x', extractor: 'page', kind: FactKind.adult, value: '18+'));
    await openMap(tester);
    expect(find.byKey(const ValueKey('adult-veil-x')), findsOneWidget);
  });

  testWidgets('вещи рядом — одна метка с числом, касание показывает их снизу', (tester) async {
    await add('a', 'Кофе', latitude: 47.02450, longitude: 28.83230, place: 'Ботаника, Кишинёв');
    await add('b', 'Круассаны', latitude: 47.02460, longitude: 28.83250, place: 'Ботаника, Кишинёв');
    await add('c', 'Парк', latitude: 47.06, longitude: 28.86, place: 'Рышкановка, Кишинёв');
    await add('d', 'Без места');
    await openMap(tester);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('2'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ботаника, Кишинёв'), findsOneWidget);
    expect(find.text('Кофе'), findsOneWidget);
    expect(find.text('Круассаны'), findsOneWidget);
    expect(find.text('Без места'), findsNothing);
  });

  testWidgets('карта перекрашивается целым слоем, а не каждой плиткой; метки рисуются один раз', (tester) async {
    await add('a', 'Кофейня', latitude: 47.0245, longitude: 28.8323, place: 'Ботаника');
    await add('b', 'Парк', latitude: 47.05, longitude: 28.86, place: 'Центр');
    await openMap(tester);
    // перекраска на каждой плитке — два слоя на плитку, 40–60 слоёв на кадр прокрутки
    final tiles = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(tiles.tileBuilder, isNull);
    expect(find.ancestor(of: find.byType(TileLayer), matching: find.byType(ColorFiltered)), findsNWidgets(2));
    // метка не перерисовывается при сдвиге карты: у каждой свой слой
    for (final mark in find.byKey(const ValueKey('map-mark')).evaluate()) {
      expect(find.ancestor(of: find.byWidget(mark.widget), matching: find.byType(RepaintBoundary)), findsWidgets);
    }
    expect(find.byKey(const ValueKey('map-mark')), findsNWidgets(2));
  });

  testWidgets('мест ещё нет — карта говорит, откуда они возьмутся', (tester) async {
    await add('d', 'Без места');
    await openMap(tester);
    expect(find.textContaining('Новые заметки запомнят'), findsOneWidget);
  });
}
