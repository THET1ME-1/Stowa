import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
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

  testWidgets('мест ещё нет — карта говорит, откуда они возьмутся', (tester) async {
    await add('d', 'Без места');
    await openMap(tester);
    expect(find.textContaining('Новые заметки запомнят'), findsOneWidget);
  });
}
