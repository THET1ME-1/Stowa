import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/place_groups.dart';

void main() {
  test('точки в пределах ~150 м — одно место, дальние — отдельно', () {
    final groups = groupPlaces([
      (id: 'a', latitude: 47.02450, longitude: 28.83230),
      (id: 'b', latitude: 47.02470, longitude: 28.83260), // в 30 м
      (id: 'c', latitude: 47.06000, longitude: 28.86000), // другой район
    ]);
    expect(groups, hasLength(2));
    final home = groups.firstWhere((group) => group.ids.contains('a'));
    expect(home.ids, unorderedEquals(['a', 'b']));
    expect(home.latitude, closeTo(47.0246, 0.0001));
  });

  test('порядок вещей внутри места сохраняется: свежие первыми', () {
    final groups = groupPlaces([
      (id: 'new', latitude: 47.0, longitude: 28.0),
      (id: 'old', latitude: 47.0001, longitude: 28.0001),
    ]);
    expect(groups.single.ids, ['new', 'old']);
  });

  test('пусто — пусто', () {
    expect(groupPlaces(const []), isEmpty);
  });

  test('километр — это километр', () {
    expect(metersBetween(47.0, 28.0, 47.009, 28.0), closeTo(1000, 10));
  });

  group('дом и работа', () {
    // ночью дома, в будни днём на работе, в выходные днём где попало
    List<({double latitude, double longitude, DateTime at})> life() => [
      for (var day = 1; day <= 6; day++) (latitude: 47.0245, longitude: 28.8323, at: DateTime(2026, 10, day, 23)),
      for (var day = 5; day <= 9; day++) (latitude: 47.0400, longitude: 28.8100, at: DateTime(2026, 10, day, 11)),
      for (var day = 10; day <= 11; day++) (latitude: 47.0600, longitude: 28.8600, at: DateTime(2026, 10, day, 14)),
    ];

    test('дом — где сохраняют ночью, работа — где в будни днём', () {
      final places = homeAndWork(life());
      expect(places.home!.latitude, closeTo(47.0245, 0.001));
      expect(places.work!.latitude, closeTo(47.0400, 0.001));
    });

    test('подсказка дома и работы с названием: самым частым у заметок этого места', () {
      final points = [
        for (final (index, point) in life().indexed) (latitude: point.latitude, longitude: point.longitude, at: point.at, name: index == 0 ? 'Рышкановка' : (point.latitude < 47.03 ? 'Ботаника, Кишинёв' : 'Центр, Кишинёв')),
      ];
      final guess = guessHomeAndWork(points);
      expect(guess.home!.name, 'Ботаника, Кишинёв');
      expect(guess.home!.latitude, closeTo(47.0245, 0.001));
      expect(guess.work!.name, 'Центр, Кишинёв');
    });

    test('мало точек — не угадывает', () {
      final places = homeAndWork(life().take(2).toList());
      expect(places.home, isNull);
      expect(places.work, isNull);
    });
  });
}
