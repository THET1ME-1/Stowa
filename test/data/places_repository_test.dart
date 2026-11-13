import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/places_repository.dart';
import 'package:stowa/domain/models.dart';

void main() {
  late AppDatabase db;
  late PlacesRepository places;
  setUp(() {
    db = AppDatabase.memory();
    var minute = 0;
    places = PlacesRepository(db, clock: () => DateTime(2026, 11, 13, 10, minute++));
  });
  tearDown(() => db.close());

  test('мест сколько угодно и любого вида: вторая работа не заменяет первую', () async {
    await places.add(PlaceKind.work, name: 'Офис', latitude: 47.0, longitude: 28.8);
    await places.add(PlaceKind.work, name: 'Склад', latitude: 47.1, longitude: 28.9);
    await places.add(PlaceKind.study, name: 'Универ', latitude: 47.2, longitude: 28.7);
    await places.add(PlaceKind.food, name: 'Andy\'s', latitude: 47.3, longitude: 28.6);
    final all = await places.all();
    expect([for (final place in all) (place.kind, place.name)], [
      (PlaceKind.work, 'Офис'),
      (PlaceKind.work, 'Склад'),
      (PlaceKind.study, 'Универ'),
      (PlaceKind.food, 'Andy\'s'),
    ]);
  });

  test('свой вид: подпись и значок хранятся у места, правка на готовый вид их стирает', () async {
    final id = await places.add(PlaceKind.other, name: 'English Time', label: 'Курсы', icon: 'school', latitude: 47.0, longitude: 28.8);
    final course = (await places.all()).single;
    expect((course.kind, course.label, course.icon), (PlaceKind.other, 'Курсы', 'school'));
    await places.update(id, name: 'English Time', kind: PlaceKind.study, latitude: 47.0, longitude: 28.8);
    final changed = (await places.all()).single;
    expect((changed.kind, changed.label, changed.icon), (PlaceKind.study, null, null));
  });

  test('правка меняет имя, вид и точку; удаление убирает одно место', () async {
    final id = await places.add(PlaceKind.other, name: 'Курсы', latitude: 47.0, longitude: 28.8);
    final keep = await places.add(PlaceKind.home, name: 'Дом', latitude: 46.9, longitude: 28.7, wifi: 'HomeNet');
    await places.update(id, name: 'Курсы английского', kind: PlaceKind.study, latitude: 47.05, longitude: 28.85);
    final changed = (await places.all()).firstWhere((place) => place.id == id);
    expect((changed.name, changed.kind, changed.latitude, changed.longitude), ('Курсы английского', PlaceKind.study, 47.05, 28.85));

    await places.remove(id);
    expect([for (final place in await places.all()) place.id], [keep]);
    expect((await places.all()).single.wifi, 'HomeNet');
  });
}
