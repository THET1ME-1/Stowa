import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/place_service.dart';

class FakePlaces implements PlaceSource {
  FakePlaces(this.fix);

  PlaceFix? fix;
  int asked = 0;

  /// Можно ли было показать системное окно разрешения при каждом запросе.
  final prompts = <bool>[];

  @override
  Future<PlaceFix?> current({bool ask = true}) async {
    asked++;
    prompts.add(ask);
    return fix;
  }
}

void main() {
  late AppDatabase db;
  var now = DateTime(2026, 11, 3, 20, 14);
  setUp(() async {
    db = AppDatabase.memory();
    now = DateTime(2026, 11, 3, 20, 14);
    for (final id in ['a', 'b', 'c']) {
      await db.into(db.items).insert(ItemsCompanion.insert(id: id, kind: ItemKind.note, title: id, body: const Value('x'), createdAt: now, updatedAt: now));
    }
  });
  tearDown(() => db.close());

  Future<Item> item(String id) => (db.select(db.items)..where((t) => t.id.equals(id))).getSingle();

  test('вещь получает координаты и название места', () async {
    final places = FakePlaces(const PlaceFix(latitude: 47.0245, longitude: 28.8323, name: 'Ботаника, Кишинёв'));
    await PlaceService(db, source: places, clock: () => now, enabled: () => true).stamp('a');
    final saved = await item('a');
    expect(saved.latitude, 47.0245);
    expect(saved.longitude, 28.8323);
    expect(saved.placeName, 'Ботаника, Кишинёв');
  });

  test('обычное сохранение окно разрешения не показывает, «напомни тут» — показывает', () async {
    final places = FakePlaces(const PlaceFix(latitude: 47, longitude: 28));
    await PlaceService(db, source: places, clock: () => now, enabled: () => true).stamp('a');
    await (db.update(db.items)..where((t) => t.id.equals('b'))).write(const ItemsCompanion(remindPlace: Value(PlaceReminderKind.point)));
    await PlaceService(db, source: places, clock: () => now, enabled: () => true).stamp('b');
    expect(places.prompts, [false, true]);
  });

  test('выключено в настройках — телефон о месте не спрашивают', () async {
    final places = FakePlaces(const PlaceFix(latitude: 1, longitude: 2));
    await PlaceService(db, source: places, clock: () => now, enabled: () => false).stamp('a');
    expect(places.asked, 0);
    expect((await item('a')).latitude, isNull);
  });

  test('несколько вещей подряд — место берётся одно, GPS не дёргается каждый раз', () async {
    final places = FakePlaces(const PlaceFix(latitude: 47, longitude: 28, name: 'Центр'));
    final service = PlaceService(db, source: places, clock: () => now, enabled: () => true);
    await service.stamp('a');
    now = now.add(const Duration(seconds: 40));
    await service.stamp('b');
    expect(places.asked, 1);
    now = now.add(const Duration(minutes: 3));
    await service.stamp('c');
    expect(places.asked, 2);
  });

  test('«напомни тут»: точка напоминания берётся, даже если запоминать место выключено', () async {
    await (db.update(db.items)..where((t) => t.id.equals('a'))).write(const ItemsCompanion(remindPlace: Value(PlaceReminderKind.point)));
    final places = FakePlaces(const PlaceFix(latitude: 47.0245, longitude: 28.8323, name: 'Ботаника, Кишинёв'));
    final service = PlaceService(db, source: places, clock: () => now, enabled: () => false);
    await service.stamp('a');
    final a = await item('a');
    expect((a.remindLatitude, a.remindLongitude, a.remindPlaceName), (47.0245, 28.8323, 'Ботаника, Кишинёв'));
    // где сохранено — не пишется: это выключено
    expect(a.latitude, isNull);
    // обычная заметка при выключенном месте телефон не дёргает
    await service.stamp('b');
    expect(places.asked, 1);
  });

  test('места нет (не разрешили) — вещь остаётся без места', () async {
    await PlaceService(db, source: FakePlaces(null), clock: () => now, enabled: () => true).stamp('a');
    expect((await item('a')).latitude, isNull);
  });

  group('название места', () {
    test('из геокодера телефона: улица или район, затем город', () {
      expect(placeLabel(street: 'улица Пушкина 12', subLocality: 'Центр', locality: 'Кишинёв'), 'улица Пушкина 12, Кишинёв');
      expect(placeLabel(subLocality: 'Ботаника', locality: 'Кишинёв'), 'Ботаника, Кишинёв');
      expect(placeLabel(locality: 'Кишинёв', administrativeArea: 'Кишинёв'), 'Кишинёв');
      expect(placeLabel(), isNull);
    });

    test('улица без города: геокодер кладёт в street всю строку адреса', () {
      expect(streetOf(street: 'Bulevardul Iuri Gagarin 7, Chișinău, Молдова', thoroughfare: 'Bulevardul Iuri Gagarin', subThoroughfare: '7'), 'Bulevardul Iuri Gagarin 7');
      expect(streetOf(street: 'Bulevardul Iuri Gagarin 7, Chișinău, Молдова', thoroughfare: 'Bulevardul Iuri Gagarin'), 'Bulevardul Iuri Gagarin');
      expect(streetOf(street: 'улица Пушкина 12, Кишинёв'), 'улица Пушкина 12');
      expect(streetOf(street: '  ', thoroughfare: ''), isNull);
    });

    test('из OpenStreetMap, когда на телефоне нет геокодера', () {
      expect(
        placeLabelFromNominatim({
          'address': {'road': 'бульвар Штефан чел Маре', 'suburb': 'Центр', 'city': 'Кишинёв', 'country': 'Молдова'},
        }),
        'бульвар Штефан чел Маре, Кишинёв',
      );
      expect(placeLabelFromNominatim({'address': {'village': 'Ватра', 'county': 'Кишинёв'}}), 'Ватра');
      expect(placeLabelFromNominatim({'error': 'Unable to geocode'}), isNull);
    });
  });
}
