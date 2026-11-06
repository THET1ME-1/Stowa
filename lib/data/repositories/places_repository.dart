import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models.dart';
import '../db/database.dart';

/// Отмеченные места: дом и работа — по одному, магазинов сколько угодно.
class PlacesRepository {
  PlacesRepository(this._db, {DateTime Function()? clock, Uuid? uuid}) : _clock = clock ?? DateTime.now, _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  Stream<List<Place>> watchAll() => (_db.select(_db.places)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

  Future<List<Place>> all() => (_db.select(_db.places)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

  /// Дом или работа: новое место заменяет прежнее.
  Future<void> setOwn(PlaceKind kind, {required String name, required double latitude, required double longitude, String? wifi}) async {
    assert(kind != PlaceKind.shop);
    await _db.transaction(() async {
      await (_db.delete(_db.places)..where((t) => t.kind.equals(kind.name))).go();
      await _insert(kind, name: name, latitude: latitude, longitude: longitude, wifi: wifi);
    });
  }

  Future<String> addShop({required String name, required double latitude, required double longitude}) =>
      _insert(PlaceKind.shop, name: name, latitude: latitude, longitude: longitude);

  Future<void> rename(String id, String name) => (_db.update(_db.places)..where((t) => t.id.equals(id))).write(PlacesCompanion(name: Value(name)));

  /// Где сохраняли заметки: из этого угадываются дом и работа.
  Future<List<({double latitude, double longitude, DateTime at, String? name})>> savedPoints() async => [
    for (final item in await (_db.select(_db.items)..where((t) => t.latitude.isNotNull() & t.longitude.isNotNull() & t.deletedAt.isNull())).get())
      (latitude: item.latitude!, longitude: item.longitude!, at: item.createdAt, name: item.placeName),
  ];

  Future<void> remove(String id) => (_db.delete(_db.places)..where((t) => t.id.equals(id))).go();

  Future<void> removeKind(PlaceKind kind) => (_db.delete(_db.places)..where((t) => t.kind.equals(kind.name))).go();

  Future<String> _insert(PlaceKind kind, {required String name, required double latitude, required double longitude, String? wifi}) async {
    final id = _uuid.v4();
    await _db.into(_db.places).insert(
      PlacesCompanion.insert(id: id, kind: kind, name: name, latitude: latitude, longitude: longitude, wifi: Value(wifi), createdAt: _clock()),
    );
    return id;
  }
}
