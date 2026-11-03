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
}
