import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../domain/models.dart';
import '../db/database.dart';

/// Сколько удалённое лежит в корзине, пока не сотрётся само.
const trashKeep = Duration(days: 30);

/// Удалённая вещь в корзине: что это было, где лежало и когда удалено.
class TrashEntry {
  const TrashEntry({required this.id, required this.title, required this.kind, required this.deletedAt, this.folderName, this.thumbPath});

  final String id;
  final String title;
  final ItemKind kind;
  final DateTime deletedAt;
  final String? folderName;

  /// Первая картинка или обложка превью, путь от папки приложения.
  final String? thumbPath;
}

/// Корзина: удалённое можно вернуть или стереть навсегда вместе с файлами.
class TrashRepository {
  TrashRepository(this._db, {required Directory filesRoot}) : _filesRoot = filesRoot; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final Directory _filesRoot;

  Stream<List<TrashEntry>> watch() {
    return _db
        .customSelect(
          '''
SELECT items.id, items.title, items.kind, items.deleted_at, folders.name AS folder_name,
  coalesce((SELECT attachments.path FROM attachments
    WHERE attachments.item_id = items.id AND attachments.mime LIKE 'image/%'
    ORDER BY attachments.position LIMIT 1), items.cover_path) AS thumb_path
FROM items LEFT JOIN folders ON folders.id = items.folder_id
WHERE items.deleted_at IS NOT NULL
ORDER BY items.deleted_at DESC''',
          readsFrom: {_db.items, _db.folders, _db.attachments},
        )
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              TrashEntry(
                id: row.read<String>('id'),
                title: row.read<String>('title'),
                kind: ItemKind.values.byName(row.read<String>('kind')),
                deletedAt: _db.typeMapping.read(DriftSqlType.dateTime, row.data['deleted_at'])!,
                folderName: row.readNullable<String>('folder_name'),
                thumbPath: row.readNullable<String>('thumb_path'),
              ),
          ],
        );
  }

  Stream<int> watchCount() {
    final count = _db.items.id.count();
    final query = _db.selectOnly(_db.items)
      ..addColumns([count])
      ..where(_db.items.deletedAt.isNotNull());
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  Future<void> restore(String id) {
    return (_db.update(_db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(deletedAt: Value(null)));
  }

  /// Стереть навсегда: вещь, её следы в других таблицах и файлы на диске.
  Future<void> purge(String id) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
    final files = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(id))).get();
    await _db.transaction(() async {
      await (_db.delete(_db.attachments)..where((t) => t.itemId.equals(id))).go();
      await (_db.delete(_db.itemTags)..where((t) => t.itemId.equals(id))).go();
      await (_db.delete(_db.links)..where((t) => t.fromId.equals(id) | t.toId.equals(id))).go();
      await (_db.delete(_db.aiJobs)..where((t) => t.itemId.equals(id))).go();
      await (_db.delete(_db.aiLog)..where((t) => t.itemId.equals(id))).go();
      await (_db.delete(_db.corrections)..where((t) => t.itemId.equals(id))).go();
      await (_db.delete(_db.canvasPositions)..where((t) => t.itemId.equals(id))).go();
      await (_db.delete(_db.items)..where((t) => t.id.equals(id))).go();
    });
    // файлы — после базы: упадёт удаление файла, вещь всё равно стёрта
    final paths = [for (final file in files) file.path, if (item?.coverPath != null) item!.coverPath!];
    for (final path in paths) {
      await _remove(File(p.join(_filesRoot.path, path)));
    }
    final folder = Directory(p.join(_filesRoot.path, 'attachments', id));
    if (await folder.exists()) await folder.delete(recursive: true).catchError((_) => folder);
  }

  Future<void> _remove(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // файл занят или уже стёрт — в базе вещи всё равно нет
    }
  }

  Future<int> purgeAll() => _purgeWhere((t) => t.deletedAt.isNotNull());

  /// Стереть то, что лежит в корзине дольше [trashKeep].
  Future<int> purgeExpired(DateTime now) => _purgeWhere((t) => t.deletedAt.isSmallerThanValue(now.subtract(trashKeep)));

  Future<int> _purgeWhere(Expression<bool> Function($ItemsTable t) filter) async {
    final ids = await (_db.selectOnly(_db.items)
          ..addColumns([_db.items.id])
          ..where(filter(_db.items)))
        .map((row) => row.read(_db.items.id)!)
        .get();
    for (final id in ids) {
      await purge(id);
    }
    return ids.length;
  }
}
