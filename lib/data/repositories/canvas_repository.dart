import 'package:drift/drift.dart';

import '../db/database.dart';

/// Где вещь лежит на холсте папки. Высоты нет: она следует из ширины и содержимого.
typedef CanvasSpot = ({double x, double y, double width});

/// Раскладка холста по папке: своя у каждой папки, вещь в двух папках не бывает,
/// но после переноса старое место остаётся и пригодится, если вернуть.
class CanvasRepository {
  CanvasRepository(this._db);

  final AppDatabase _db;

  Stream<Map<String, CanvasSpot>> watch(String folderId) => (_db.select(_db.canvasPositions)..where((t) => t.folderId.equals(folderId)))
      .watch()
      .map((rows) => {for (final row in rows) row.itemId: (x: row.x, y: row.y, width: row.width)});

  Future<void> save(String folderId, String itemId, CanvasSpot spot) => _db
      .into(_db.canvasPositions)
      .insertOnConflictUpdate(CanvasPositionsCompanion.insert(folderId: folderId, itemId: itemId, x: spot.x, y: spot.y, width: spot.width));

  Future<void> saveAll(String folderId, Map<String, CanvasSpot> spots) => _db.batch((batch) {
    for (final MapEntry(key: itemId, value: spot) in spots.entries) {
      batch.insert(
        _db.canvasPositions,
        CanvasPositionsCompanion.insert(folderId: folderId, itemId: itemId, x: spot.x, y: spot.y, width: spot.width),
        mode: InsertMode.insertOrReplace,
      );
    }
  });
}
