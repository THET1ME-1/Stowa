import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/places/place_edit_screen.dart' show KindChip;
import 'package:stowa/features/places/places_screen.dart';
import 'package:stowa/services/place_search.dart';
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

  final name = find.byKey(const ValueKey('place-name'));
  final search = find.byKey(const ValueKey('place-search'));
  final map = find.byType(FlutterMap);

  Future<void> newPlace(WidgetTester tester) async {
    await tester.tap(find.text('Добавить место'));
    await tester.pumpAndSettle();
  }

  Future<void> here(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Я сейчас здесь'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
  }

  /// Чип вида в строке: строка листается вбок до него.
  Future<void> pickKind(WidgetTester tester, String label) async {
    final chip = find.byKey(ValueKey('kind-$label'));
    await tester.scrollUntilVisible(chip, 120, scrollable: find.descendant(of: find.byKey(const ValueKey('kind-row')), matching: find.byType(Scrollable)).first);
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  Future<void> addPlace(WidgetTester tester, {required String title, required String kind}) async {
    await newPlace(tester);
    await tester.enterText(name, title);
    await pickKind(tester, kind);
    await here(tester);
    await save(tester);
  }

  /// Какой чип выбран: у выбранного ключ `kind-…` и пометка selected в семантике.
  String? selectedKind(WidgetTester tester) {
    for (final element in find.byWidgetPredicate((widget) => widget is KindChip && widget.selected).evaluate()) {
      return (element.widget as KindChip).label;
    }
    return null;
  }

  testWidgets('вид — одна строка чипов: имя ведёт вид, выбор рукой закрепляет, чипы не меняются местами', (tester) async {
    world.placeChannel.background = true;
    await open(tester);
    await newPlace(tester);
    final row = tester.getRect(find.byKey(const ValueKey('kind-row')));
    expect(row.height, lessThan(56));
    List<String> order() => [for (final element in find.byType(KindChip).evaluate()) (element.widget as KindChip).label];
    final before = order();
    expect(before.take(3), ['Дом', 'Работа', 'Учёба']);
    expect(before.last, 'Свой вид');

    // имя ведёт вид, пока его не выбрали рукой
    await tester.enterText(name, 'Универ');
    await tester.pumpAndSettle();
    expect(selectedKind(tester), 'Учёба');
    await pickKind(tester, 'Работа');
    expect(selectedKind(tester), 'Работа');
    expect(order(), before);
    await tester.enterText(name, 'Универ на Ботанике');
    await tester.pumpAndSettle();
    expect(selectedKind(tester), 'Работа');
  });

  testWidgets('свой вид: «Свой вид» → «Создать «Дача»», чип встаёт выбранным и сохраняется', (tester) async {
    world.placeChannel.background = true;
    world.currentPlace = const PlaceFix(latitude: 47.1, longitude: 28.7, name: 'Вадул-луй-Водэ');
    await open(tester);
    await newPlace(tester);
    await tester.enterText(name, 'Дача родителей');
    await pickKind(tester, 'Свой вид');
    await tester.enterText(find.byKey(const ValueKey('type-search')), 'Дача');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать «Дача»'));
    await tester.pumpAndSettle();
    expect(selectedKind(tester), 'Дача');
    await here(tester);
    await save(tester);
    final dacha = (await places()).single;
    expect((dacha.name, dacha.kind, dacha.label), ('Дача родителей', PlaceKind.other, 'Дача'));
    expect(dacha.icon, isNotNull);
    expect(find.text('Дача'), findsOneWidget);

    // второе место: свой вид уже чипом в строке
    await newPlace(tester);
    expect(find.byKey(const ValueKey('kind-Дача')), findsOneWidget);
  });

  testWidgets('поиск адреса: список под полем, касание ставит точку, имя и вид', (tester) async {
    world.placeChannel.background = true;
    world.placeLookup.found = const [
      FoundPlace(name: 'Universitatea de Stat', address: 'Strada Alexei Mateevici 60, Chișinău', latitude: 47.0189, longitude: 28.8245),
      FoundPlace(name: 'Universitatea Tehnică', address: 'Bulevardul Ștefan cel Mare 168, Chișinău', latitude: 47.0336, longitude: 28.8169),
    ];
    world.placeLookup.pointName = 'Strada Alexei Mateevici 60, Chișinău';
    await open(tester);
    await newPlace(tester);
    // точки нет — «Сохранить» не нажимается, на карте подсказка
    expect(find.text('Найди адрес или зажми карту, чтобы поставить точку'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Сохранить')).onPressed, isNull);

    await tester.tap(search);
    await tester.enterText(search, 'univ');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Universitatea de Stat'), findsOneWidget);
    expect(find.text('Strada Alexei Mateevici 60, Chișinău'), findsOneWidget);
    await tester.tap(find.text('Universitatea de Stat'));
    await tester.pumpAndSettle();
    // список закрыт, имя подставилось, адрес точки под картой
    expect(find.text('Universitatea Tehnică'), findsNothing);
    expect(tester.widget<TextField>(name).controller!.text, 'Universitatea de Stat');
    expect(find.text('Strada Alexei Mateevici 60, Chișinău'), findsOneWidget);
    expect(find.text('Найди адрес или зажми карту, чтобы поставить точку'), findsNothing);
    await save(tester);
    final place = (await places()).single;
    expect((place.name, place.latitude, place.longitude), ('Universitatea de Stat', 47.0189, 28.8245));
  });

  testWidgets('коротко или ничего — «Ничего не нашлось», запрос от трёх букв', (tester) async {
    world.placeChannel.background = true;
    await open(tester);
    await newPlace(tester);
    await tester.tap(search);
    await tester.enterText(search, 'ab');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(world.placeLookup.queries, isEmpty);
    await tester.enterText(search, 'abcdef');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Ничего не нашлось'), findsOneWidget);
  });

  testWidgets('карту листаешь — точка стоит; долгое нажатие переносит, «Отменить» возвращает', (tester) async {
    world.placeChannel.background = true;
    world.currentPlace = const PlaceFix(latitude: 47.0245, longitude: 28.8323, name: 'Ботаника, Кишинёв');
    await open(tester);
    await newPlace(tester);
    await tester.enterText(name, 'Офис');
    await here(tester);
    await tester.drag(map, const Offset(-120, 60));
    await tester.pumpAndSettle();
    expect(find.text('Ботаника, Кишинёв'), findsOneWidget);

    // долгое нажатие сбоку от центра: точка уезжает туда
    final center = tester.getCenter(map);
    await tester.longPressAt(center + const Offset(60, 40));
    await tester.pumpAndSettle();
    expect(find.text('Точка перенесена'), findsOneWidget);
    expect(find.text('Strada Pușkin 52, Chișinău'), findsOneWidget);
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Ботаника, Кишинёв'), findsOneWidget);
    await save(tester);
    final place = (await places()).single;
    expect((place.latitude, place.longitude), (47.0245, 28.8323));
  });

  testWidgets('долгое нажатие без точки ставит её, без плашки', (tester) async {
    world.placeChannel.background = true;
    await open(tester);
    await newPlace(tester);
    await tester.longPressAt(tester.getCenter(map));
    await tester.pumpAndSettle();
    expect(find.text('Точка перенесена'), findsNothing);
    expect(find.text('Strada Pușkin 52, Chișinău'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Сохранить')).onPressed, isNotNull);
    await save(tester);
    expect((await places()).single.name, 'Strada Pușkin 52, Chișinău');
  });

  testWidgets('радиус: пилюля «150 м», выбор 300 м сохраняется', (tester) async {
    world.placeChannel.background = true;
    world.currentPlace = const PlaceFix(latitude: 47.0, longitude: 28.8, name: 'Центр');
    await open(tester);
    await newPlace(tester);
    await tester.enterText(name, 'Mall Dova');
    await here(tester);
    await tester.tap(find.text('150 м'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('300 м').last);
    await tester.pumpAndSettle();
    expect(find.text('300 м'), findsOneWidget);
    await save(tester);
    expect((await places()).single.radius, 300);
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
    await addPlace(tester, title: 'Универ', kind: 'Учёба');
    await addPlace(tester, title: 'Офис', kind: 'Работа');
    await addPlace(tester, title: 'Склад', kind: 'Работа');

    expect([for (final place in await places()) (place.name, place.kind, place.latitude)], [
      ('Универ', PlaceKind.study, 47.0245),
      ('Офис', PlaceKind.work, 47.0245),
      ('Склад', PlaceKind.work, 47.0245),
    ]);
    for (final title in ['Универ', 'Офис', 'Склад']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Работа'), findsNWidgets(2));
  });

  testWidgets('дом через «я сейчас здесь» берёт и сеть Wi-Fi', (tester) async {
    world.placeChannel.background = true;
    world.placeChannel.wifi = 'HomeNet';
    world.currentPlace = const PlaceFix(latitude: 47.0245, longitude: 28.8323, name: 'Ботаника, Кишинёв');
    await open(tester);
    await addPlace(tester, title: 'Дом', kind: 'Дом');
    final home = (await places()).single;
    expect((home.kind, home.name, home.wifi), (PlaceKind.home, 'Дом', 'HomeNet'));
    expect(find.text('Wi-Fi: HomeNet'), findsOneWidget);
  });

  testWidgets('без имени имя берётся от адреса точки', (tester) async {
    world.placeChannel.background = true;
    world.currentPlace = const PlaceFix(latitude: 47.01, longitude: 28.86, name: 'ул. Дечебал');
    await open(tester);
    await newPlace(tester);
    await pickKind(tester, 'Магазин');
    await here(tester);
    await save(tester);
    expect(((await places()).single.name, (await places()).single.kind), ('ул. Дечебал', PlaceKind.shop));
  });

  testWidgets('свой значок места: поиск по набору, выбранный сохраняется и виден в списке', (tester) async {
    world.placeChannel.background = true;
    world.currentPlace = const PlaceFix(latitude: 47.0, longitude: 28.8, name: 'Центр');
    await open(tester);
    await newPlace(tester);
    await tester.enterText(name, 'Любимая кофейня');
    await tester.tap(find.byTooltip('Значок'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'кофе');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('icon-local_cafe')));
    await tester.pumpAndSettle();
    await here(tester);
    await save(tester);
    final cafe = (await places()).single;
    expect((cafe.name, cafe.kind, cafe.icon), ('Любимая кофейня', PlaceKind.food, 'local_cafe'));

    // правка вида значок не сбивает
    await tester.tap(find.text('Любимая кофейня'));
    await tester.pumpAndSettle();
    await pickKind(tester, 'Другое');
    await save(tester);
    expect((await places()).single.icon, 'local_cafe');
  });

  testWidgets('касание места открывает правку: точка на месте, адрес узнаётся; «Убрать» удаляет', (tester) async {
    world.placeChannel.background = true;
    world.placeLookup.pointName = 'Strada Bucuriei 1, Chișinău';
    await world.db.into(world.db.places).insert(PlacesCompanion.insert(id: 'p', kind: PlaceKind.other, name: 'Курсы', latitude: 47.0, longitude: 28.8, createdAt: world.now));
    await open(tester);
    await tester.tap(find.text('Курсы'));
    await tester.pumpAndSettle();
    expect(find.text('Strada Bucuriei 1, Chișinău'), findsOneWidget);
    await tester.enterText(name, 'Курсы английского');
    await pickKind(tester, 'Учёба');
    await save(tester);
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
    await newPlace(tester);
    await here(tester);
    expect(find.text('Не вышло узнать, где ты. Проверь, что место на телефоне включено и разрешено Stowa.'), findsOneWidget);
  });

  testWidgets('экран места влезает в 320 точек при крупном шрифте, и со списком найденного', (tester) async {
    world.placeChannel.background = true;
    world.placeLookup.found = const [
      FoundPlace(name: 'Universitatea de Stat din Moldova, corpul central', address: 'Strada Alexei Mateevici 60, Chișinău', latitude: 47.0189, longitude: 28.8245),
    ];
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await open(tester, size: const Size(320, 700));
    expect(tester.takeException(), isNull);
    await newPlace(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(search);
    await tester.enterText(search, 'univ');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
