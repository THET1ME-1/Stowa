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
