import 'package:drift/drift.dart' show OrderingTerm, Value;
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

  Future<void> open(WidgetTester tester, {Size size = const Size(400, 880)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const PlacesScreen()));
    await tester.pumpAndSettle();
  }

  Future<List<Place>> places() => (world.db.select(world.db.places)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

  /// Вид через «Найти или создать»: в листе у каждого вида свой ключ.
  Future<void> pickType(WidgetTester tester, String label) async {
    await tester.tap(find.text('Найти или создать'));
    await tester.pumpAndSettle();
    final row = find.byKey(ValueKey('type-$label'));
    await tester.scrollUntilVisible(row, 120, scrollable: find.descendant(of: find.byKey(const ValueKey('type-sheet')), matching: find.byType(Scrollable)).first);
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  Future<void> addPlace(WidgetTester tester, {required String name, required String kind}) async {
    await tester.tap(find.text('Добавить место'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), name);
    await pickType(tester, kind);
    await tester.tap(find.text('Я сейчас здесь'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
  }

  testWidgets('вид — три плитки в ряд: выбранный, подходящий к имени и «Найти или создать»', (tester) async {
    world.placeChannel.background = true;
    await open(tester);
    await tester.tap(find.text('Добавить место'));
    await tester.pumpAndSettle();
    final tiles = find.byKey(const ValueKey('type-row'));
    final row = tester.getRect(tiles);
    // три плитки одной ширины в одну строку, без переноса
    final kids = find.descendant(of: tiles, matching: find.byWidgetPredicate((widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('tile-')));
    expect(kids, findsNWidgets(3));
    final rects = [for (final element in kids.evaluate()) tester.getRect(find.byWidget(element.widget))];
    expect(rects.map((rect) => rect.top.round()).toSet(), hasLength(1));
    expect(rects.every((rect) => rect.bottom <= row.bottom + 1), isTrue);
    expect(find.text('Найти или создать'), findsOneWidget);

    // имя ведёт вид, пока его не выбрали рукой: «Универ» — учёба выбрана сама
    await tester.enterText(find.byType(TextField), 'Универ');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tile-selected-Учёба')), findsOneWidget);
    // выбрал рукой вторую плитку — имя больше не перебивает
    final second = find.byWidgetPredicate((widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('tile-suggested-'));
    final picked = ((tester.widget(second).key! as ValueKey<String>).value).substring('tile-suggested-'.length);
    await tester.tap(second);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Универ на Ботанике');
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('tile-selected-$picked')), findsOneWidget);
  });

  testWidgets('свой вид: «Найти или создать» → «Создать «Дача»», вид встаёт выбранным и сохраняется', (tester) async {
    world.placeChannel.background = true;
    world.currentPlace = const PlaceFix(latitude: 47.1, longitude: 28.7, name: 'Вадул-луй-Водэ');
    await open(tester);
    await tester.tap(find.text('Добавить место'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Дача родителей');
    await tester.tap(find.text('Найти или создать'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Дача');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать «Дача»'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tile-selected-Дача')), findsOneWidget);
    await tester.tap(find.text('Я сейчас здесь'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    final dacha = (await places()).single;
    expect((dacha.name, dacha.kind, dacha.label), ('Дача родителей', PlaceKind.other, 'Дача'));
    expect(dacha.icon, isNotNull);
    // в списке подпись — свой вид
    expect(find.text('Дача'), findsOneWidget);

    // второе место: свой вид уже в листе, создавать заново не нужно
    await tester.tap(find.text('Добавить место'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Найти или создать'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('type-Дача')), findsOneWidget);
  });

  testWidgets('без места «всегда» — карточка «Разрешить», после разрешения её нет', (tester) async {
    await open(tester);
    expect(find.text('Нужно место «всегда»'), findsOneWidget);
    await tester.tap(find.text('Разрешить'));
    await tester.pumpAndSettle();
    expect(world.placeChannel.asked, 1);
    expect(find.text('Нужно место «всегда»'), findsNothing);
  });

  testWidgets('мест нет — так и сказано, блока «Магазины» больше нет', (tester) async {
    world.placeChannel.background = true;
    await open(tester);
    expect(find.text('Мест пока нет: добавь дом, работу, любимое кафе или друга.'), findsOneWidget);
    expect(find.text('Магазины'), findsNothing);
    expect(find.text('Добавить место'), findsOneWidget);
  });

  testWidgets('своё место: имя, вид и «я сейчас здесь»; две работы рядом', (tester) async {
    world.placeChannel.background = true;
    world.currentPlace = const PlaceFix(latitude: 47.0245, longitude: 28.8323, name: 'Ботаника, Кишинёв');
    await open(tester);
    await addPlace(tester, name: 'Универ', kind: 'Учёба');
    await addPlace(tester, name: 'Офис', kind: 'Работа');
    await addPlace(tester, name: 'Склад', kind: 'Работа');

    expect([for (final place in await places()) (place.name, place.kind, place.latitude)], [
      ('Универ', PlaceKind.study, 47.0245),
      ('Офис', PlaceKind.work, 47.0245),
      ('Склад', PlaceKind.work, 47.0245),
    ]);
    for (final name in ['Универ', 'Офис', 'Склад']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Работа'), findsNWidgets(2));
  });

  testWidgets('дом через «я сейчас здесь» берёт и сеть Wi-Fi', (tester) async {
    world.placeChannel.background = true;
    world.placeChannel.wifi = 'HomeNet';
    world.currentPlace = const PlaceFix(latitude: 47.0245, longitude: 28.8323, name: 'Ботаника, Кишинёв');
    await open(tester);
    await addPlace(tester, name: 'Дом', kind: 'Дом');
    final home = (await places()).single;
    expect((home.kind, home.name, home.wifi), (PlaceKind.home, 'Дом', 'HomeNet'));
    // вид не повторяет имя: у «Дома» в подписи только сеть
    expect(find.text('Wi-Fi: HomeNet'), findsOneWidget);
  });

  testWidgets('без имени имя берётся от места на карте', (tester) async {
    world.placeChannel.background = true;
    world.currentPlace = const PlaceFix(latitude: 47.01, longitude: 28.86, name: 'ул. Дечебал');
    await open(tester);
    await tester.tap(find.text('Добавить место'));
    await tester.pumpAndSettle();
    await pickType(tester, 'Магазин');
    await tester.tap(find.text('Я сейчас здесь'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(((await places()).single.name, (await places()).single.kind), ('ул. Дечебал', PlaceKind.shop));
  });

  testWidgets('свой значок места: поиск по набору, выбранный сохраняется и виден в списке', (tester) async {
    world.placeChannel.background = true;
    world.currentPlace = const PlaceFix(latitude: 47.0, longitude: 28.8, name: 'Центр');
    await open(tester);
    await tester.tap(find.text('Добавить место'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Любимая кофейня');
    await tester.tap(find.byTooltip('Значок'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'кофе');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('icon-local_cafe')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Я сейчас здесь'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    final cafe = (await places()).single;
    expect((cafe.name, cafe.kind, cafe.icon), ('Любимая кофейня', PlaceKind.food, 'local_cafe'));

    // правка вида значок не сбивает
    await tester.tap(find.text('Любимая кофейня'));
    await tester.pumpAndSettle();
    await pickType(tester, 'Другое');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect((await places()).single.icon, 'local_cafe');
  });

  testWidgets('касание места открывает правку: другой вид, другое имя; «Убрать» удаляет', (tester) async {
    world.placeChannel.background = true;
    await world.db.into(world.db.places).insert(PlacesCompanion.insert(id: 'p', kind: PlaceKind.other, name: 'Курсы', latitude: 47.0, longitude: 28.8, createdAt: world.now));
    await open(tester);
    await tester.tap(find.text('Курсы'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Курсы английского');
    await pickType(tester, 'Учёба');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    final changed = (await places()).single;
    expect((changed.name, changed.kind, changed.latitude), ('Курсы английского', PlaceKind.study, 47.0));

    await tester.tap(find.text('Курсы английского'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Убрать'));
    await tester.pumpAndSettle();
    expect(await places(), isEmpty);
  });

  testWidgets('подсказка дома по заметкам, сохранённым ночью, добавляет дом касанием', (tester) async {
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
    await tester.tap(find.text('Похоже, дом — Ботаника, Кишинёв'));
    await tester.pumpAndSettle();
    final home = (await places()).single;
    expect((home.kind, home.name), (PlaceKind.home, 'Дом'));
    expect(find.text('Похоже, дом — Ботаника, Кишинёв'), findsNothing);
  });

  testWidgets('место не определилось — так и сказано', (tester) async {
    world.placeChannel.background = true;
    await open(tester);
    await tester.tap(find.text('Добавить место'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Я сейчас здесь'));
    await tester.pumpAndSettle();
    expect(find.text('Не вышло узнать, где ты. Проверь, что место на телефоне включено и разрешено Stowa.'), findsOneWidget);
  });

  testWidgets('экран места влезает в 320 точек при крупном шрифте', (tester) async {
    world.placeChannel.background = true;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await open(tester, size: const Size(320, 700));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Добавить место'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
