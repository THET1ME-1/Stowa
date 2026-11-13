import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models.dart';
import '../db/database.dart';

/// Отмеченные места: сколько угодно, любого вида.
class PlacesRepository {
  PlacesRepository(this._db, {DateTime Function()? clock, Uuid? uuid}) : _clock = clock ?? DateTime.now, _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  Stream<List<Place>> watchAll() => (_db.select(_db.places)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

  Future<List<Place>> all() => (_db.select(_db.places)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

  /// Новое место: вторая работа рядом с первой, а не вместо неё.
  /// [label] и [icon] — свой вид («Курсы»), тогда [kind] — other.
  Future<String> add(PlaceKind kind, {required String name, required double latitude, required double longitude, String? wifi, String? label, String? icon}) =>
      _insert(kind, name: name, latitude: latitude, longitude: longitude, wifi: wifi, label: label, icon: icon);

  /// Правка места целиком: имя, вид (готовый или свой) и точка.
  Future<void> update(String id, {required String name, required PlaceKind kind, String? label, String? icon, required double latitude, required double longitude}) {
    return (_db.update(_db.places)..where((t) => t.id.equals(id))).write(
      PlacesCompanion(name: Value(name), kind: Value(kind), label: Value(label), icon: Value(icon), latitude: Value(latitude), longitude: Value(longitude)),
    );
  }

  Future<void> rename(String id, String name) => (_db.update(_db.places)..where((t) => t.id.equals(id))).write(PlacesCompanion(name: Value(name)));

  /// Где сохраняли заметки: из этого угадываются дом и работа.
  Future<List<({double latitude, double longitude, DateTime at, String? name})>> savedPoints() async => [
    for (final item in await (_db.select(_db.items)..where((t) => t.latitude.isNotNull() & t.longitude.isNotNull() & t.deletedAt.isNull())).get())
      (latitude: item.latitude!, longitude: item.longitude!, at: item.createdAt, name: item.placeName),
  ];

  Future<void> remove(String id) => (_db.delete(_db.places)..where((t) => t.id.equals(id))).go();

  Future<String> _insert(PlaceKind kind, {required String name, required double latitude, required double longitude, String? wifi, String? label, String? icon}) async {
    final id = _uuid.v4();
    await _db.into(_db.places).insert(
      PlacesCompanion.insert(
        id: id,
        kind: kind,
        name: name,
        label: Value(label),
        icon: Value(icon),
        latitude: latitude,
        longitude: longitude,
        wifi: Value(wifi),
        createdAt: _clock(),
      ),
    );
    return id;
  }
}
