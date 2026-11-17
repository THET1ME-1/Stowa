import 'package:drift/drift.dart';

import '../../data/db/database.dart';
import 'sync_ports.dart';

/// Память синхронизации в базе хранилища: у каждого хранилища своя.
class DbSyncState implements SyncState {
  DbSyncState(this._db);

  final AppDatabase _db;

  static const cursorFlag = 'sync:cursor';

  @override
  Future<int> cursor() async {
    final row = await (_db.select(_db.vaultFlags)..where((f) => f.name.equals(cursorFlag))).getSingleOrNull();
    return int.tryParse(row?.value ?? '') ?? 0;
  }

  @override
  Future<void> setCursor(int cursor) => _db.into(_db.vaultFlags).insertOnConflictUpdate(VaultFlagsCompanion.insert(name: cursorFlag, value: Value('$cursor')));

  @override
  Future<Map<String, SyncedFile>> files() async => {
    for (final row in await _db.select(_db.syncEntries).get()) row.file: SyncedFile(file: row.file, path: row.path, rev: row.rev, hash: row.hash, size: row.size, mtime: row.mtime),
  };

  @override
  Future<void> put(SyncedFile file) =>
      _db.into(_db.syncEntries).insertOnConflictUpdate(SyncEntriesCompanion.insert(file: file.file, path: file.path, rev: file.rev, hash: file.hash, size: file.size, mtime: file.mtime));

  @override
  Future<void> remove(String file) async {
    await (_db.delete(_db.syncEntries)..where((e) => e.file.equals(file))).go();
    await (_db.delete(_db.syncShadows)..where((e) => e.file.equals(file))).go();
  }

  @override
  Future<String?> shadow(String file) async => (await (_db.select(_db.syncShadows)..where((s) => s.file.equals(file))).getSingleOrNull())?.body;

  @override
  Future<void> setShadow(String file, String? text) async {
    if (text == null) {
      await (_db.delete(_db.syncShadows)..where((s) => s.file.equals(file))).go();
    } else {
      await _db.into(_db.syncShadows).insertOnConflictUpdate(SyncShadowsCompanion.insert(file: file, body: text));
    }
  }

  static const _pendingPrefix = 'sync:pending:';

  @override
  Future<Set<String>> pending() async => {for (final row in await (_db.select(_db.vaultFlags)..where((f) => f.name.like('$_pendingPrefix%'))).get()) row.name.substring(_pendingPrefix.length)};

  @override
  Future<void> setPending(String file, bool waiting) async {
    if (waiting) {
      await _db.into(_db.vaultFlags).insertOnConflictUpdate(VaultFlagsCompanion.insert(name: '$_pendingPrefix$file'));
    } else {
      await (_db.delete(_db.vaultFlags)..where((f) => f.name.equals('$_pendingPrefix$file'))).go();
    }
  }

  /// Забыть всё о синхронизации: после выхода следующий вход идёт как первый, без удалений.
  Future<void> clear() async {
    await _db.delete(_db.syncEntries).go();
    await _db.delete(_db.syncShadows).go();
    await (_db.delete(_db.vaultFlags)..where((f) => f.name.equals(cursorFlag) | f.name.like('$_pendingPrefix%'))).go();
  }
}
