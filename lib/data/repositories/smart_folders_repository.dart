import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';

/// Умные папки: сохранённые запросы поиска. Сами заметки не хранятся — запрос
/// разбирается заново при каждом открытии.
class SmartFoldersRepository {
  SmartFoldersRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Stream<List<SmartFolder>> watchAll() => (_db.select(_db.smartFolders)
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  /// Новая умная папка в конце полки. Пустое имя — сам запрос с заглавной.
  Future<String> create({required String name, required String query}) async {
    final id = const Uuid().v4();
    final last = await _db.customSelect('SELECT coalesce(max(sort_order), -1) AS last FROM smart_folders', readsFrom: {_db.smartFolders}).getSingle();
    final text = query.trim();
    final shown = name.trim().isNotEmpty ? name.trim() : '${text[0].toUpperCase()}${text.substring(1)}';
    await _db.into(_db.smartFolders).insert(
      SmartFoldersCompanion.insert(id: id, name: shown, query: text, sortOrder: Value(last.read<int>('last') + 1), createdAt: _clock()),
    );
    return id;
  }

  Future<void> rename(String id, String name) =>
      (_db.update(_db.smartFolders)..where((t) => t.id.equals(id))).write(SmartFoldersCompanion(name: Value(name.trim())));

  /// Удалить и отдать удалённое: его вернёт «Отменить».
  Future<SmartFolder?> remove(String id) async {
    final row = await (_db.select(_db.smartFolders)..where((t) => t.id.equals(id))).getSingleOrNull();
    await (_db.delete(_db.smartFolders)..where((t) => t.id.equals(id))).go();
    return row;
  }

  Future<void> restore(SmartFolder folder) => _db.into(_db.smartFolders).insert(folder, mode: InsertMode.insertOrReplace);
}
