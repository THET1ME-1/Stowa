import 'dart:math';

/// Расстояние между двумя точками в метрах, по шару Земли.
double metersBetween(double latitude, double longitude, double otherLatitude, double otherLongitude) {
  const earth = 6371000.0;
  double radians(double degrees) => degrees * pi / 180;
  final northSouth = radians(otherLatitude - latitude);
  final eastWest = radians(otherLongitude - longitude);
  final half = pow(sin(northSouth / 2), 2) + cos(radians(latitude)) * cos(radians(otherLatitude)) * pow(sin(eastWest / 2), 2);
  return 2 * earth * asin(sqrt(half));
}

/// Место на карте: несколько вещей, сохранённых рядом.
class PlaceGroup {
  const PlaceGroup({required this.ids, required this.latitude, required this.longitude});

  /// В порядке, в каком пришли: свежие первыми.
  final List<String> ids;
  final double latitude;
  final double longitude;
}

/// Клетка склейки: ~150 м по широте. У телефонного GPS такой разброс и есть,
/// десять заметок с одной кухни — одна метка, иначе карта превращается в кашу.
const _cell = 0.0015;

/// Столько сохранений нужно, чтобы назвать место домом или работой.
const _enoughVisits = 4;

/// Дом — место, где чаще всего сохраняют ночью (с 21 до 7), работа — другое
/// место, где чаще всего сохраняют в будни днём (с 9 до 18). Без настроек и без
/// сети: телефон и так знает, где человек спит и где сидит днём.
({PlaceGroup? home, PlaceGroup? work}) homeAndWork(List<({double latitude, double longitude, DateTime at})> points) {
  final groups = groupPlaces([for (final (index, point) in points.indexed) (id: '$index', latitude: point.latitude, longitude: point.longitude)]);
  int count(PlaceGroup group, bool Function(DateTime at) when) => group.ids.where((id) => when(points[int.parse(id)].at)).length;
  bool night(DateTime at) => at.hour >= 21 || at.hour < 7;
  bool workday(DateTime at) => at.weekday <= DateTime.friday && at.hour >= 9 && at.hour < 18;

  PlaceGroup? most(bool Function(DateTime at) when, {PlaceGroup? besides}) {
    PlaceGroup? best;
    var bestCount = _enoughVisits - 1;
    for (final group in groups) {
      if (identical(group, besides)) continue;
      final visits = count(group, when);
      if (visits > bestCount) {
        best = group;
        bestCount = visits;
      }
    }
    return best;
  }

  final home = most(night);
  return (home: home, work: most(workday, besides: home));
}

/// Склеить точки в места по клетке сетки. Центр места — среднее его точек.
List<PlaceGroup> groupPlaces(List<({String id, double latitude, double longitude})> points) {
  final cells = <(int, int), List<({String id, double latitude, double longitude})>>{};
  for (final point in points) {
    final key = ((point.latitude / _cell).round(), (point.longitude / _cell).round());
    cells.putIfAbsent(key, () => []).add(point);
  }
  return [
    for (final members in cells.values)
      PlaceGroup(
        ids: [for (final point in members) point.id],
        latitude: members.map((point) => point.latitude).reduce((a, b) => a + b) / members.length,
        longitude: members.map((point) => point.longitude).reduce((a, b) => a + b) / members.length,
      ),
  ];
}
