import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/places/places_screen.dart';
import 'package:stowa/services/place_service.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld(now: DateTime(2026, 11, 6, 20, 30)));
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const PlacesScreen()));
    await tester.pumpAndSettle();
  }

  Future<List<Place>> places() => world.db.select(world.db.places).get();

  testWidgets('без места «всегда» — карточка «Разрешить», после разрешения её нет', (tester) async {
    await open(tester);
    expect(find.text('Нужно место «всегда»'), findsOneWidget);
    await tester.tap(find.text('Разрешить'));
    await tester.pumpAndSettle();
    expect(world.placeChannel.asked, 1);
    expect(find.text('Нужно место «всегда»'), findsNothing);
  });

  testWidgets('«Я сейчас дома» берёт место и сеть Wi-Fi, строка показывает обе', (tester) async {
    world.placeChannel.background = true;
    world.placeChannel.wifi = 'HomeNet';
    world.currentPlace = const PlaceFix(latitude: 47.0245, longitude: 28.8323, name: 'Ботаника, Кишинёв');
    await open(tester);
    expect(find.text('Не задано'), findsNWidgets(2));
    await tester.tap(find.text('Дом'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Я сейчас дома'));
    await tester.pumpAndSettle();
    final home = (await places()).single;
    expect((home.kind, home.name, home.wifi, home.latitude), (PlaceKind.home, 'Ботаника, Кишинёв', 'HomeNet', 47.0245));
    expect(find.text('Ботаника, Кишинёв'), findsOneWidget);
    expect(find.text('Wi-Fi: HomeNet'), findsOneWidget);
  });

  testWidgets('подсказка дома по заметкам, сохранённым ночью', (tester) async {
    world.placeChannel.background = true;
    for (var day = 1; day <= 5; day++) {
      final at = DateTime(2026, 10, day, 23);
      await world.db.into(world.db.items).insert(ItemsCompanion.insert(
            id: 'n$day',
            kind: ItemKind.note,
            title: 'n$day',
            latitude: const Value(47.0245),
            longitude: const Value(28.8323),
            placeName: const Value('Ботаника, Кишинёв'),
            createdAt: at,
            updatedAt: at,
          ));
    }
    await open(tester);
    await tester.tap(find.text('Дом'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Похоже, дом — Ботаника, Кишинёв'));
    await tester.pumpAndSettle();
    expect((await places()).single.name, 'Ботаника, Кишинёв');
  });

  testWidgets('магазин: «Я в магазине — запомнить», своё название, крестик убирает', (tester) async {
    world.placeChannel.background = true;
    world.currentPlace = const PlaceFix(latitude: 47.01, longitude: 28.86, name: 'ул. Дечебал');
    await open(tester);
    await tester.tap(find.text('Я в магазине — запомнить'));
    await tester.pumpAndSettle();
    expect(find.text('ул. Дечебал'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Linella');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect((await places()).single.name, 'Linella');
    expect(find.text('Linella'), findsOneWidget);
    await tester.tap(find.byTooltip('Убрать'));
    await tester.pumpAndSettle();
    expect(await places(), isEmpty);
  });

  testWidgets('место не определилось — так и сказано', (tester) async {
    world.placeChannel.background = true;
    await open(tester);
    await tester.tap(find.text('Я в магазине — запомнить'));
    await tester.pumpAndSettle();
    expect(find.text('Не вышло узнать, где ты. Проверь, что место на телефоне включено и разрешено Stowa.'), findsOneWidget);
  });
}
