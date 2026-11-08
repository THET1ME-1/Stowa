import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import 'items_repository.dart';

/// История правок заметки. Снимки пишет триггер базы `items_history`; здесь — список
/// и возврат версии.
class HistoryRepository {
  HistoryRepository(this._db, this._items);

  final AppDatabase _db;
  final ItemsRepository _items;

  /// Версии заметки, новая первой. Снимки пишет триггер, а drift о нём не знает:
  /// запрос пересчитывается и от правки заметок — снимок встаёт только вместе с ней.
  Stream<List<NoteVersion>> watch(String itemId) => _db
      .customSelect(
        'SELECT * FROM note_versions WHERE item_id = ? ORDER BY saved_at DESC',
        variables: [Variable.withString(itemId)],
        readsFrom: {_db.noteVersions, _db.items},
      )
      .watch()
      .map((rows) => [for (final row in rows) _db.noteVersions.map(row.data)]);

  /// Самый свежий снимок: после возврата версии это то, что было до него.
  Future<NoteVersion?> latest(String itemId) =>
      (_db.select(_db.noteVersions)
            ..where((t) => t.itemId.equals(itemId))
            ..orderBy([(t) => OrderingTerm.desc(t.savedAt)])
            ..limit(1))
          .getSingleOrNull();

  /// Заметка снова такая, как в [version]. Нынешнее сперва уходит в историю снимком —
  /// даже без перерыва в правке, — поэтому возврат отменяется тем же экраном.
  Future<void> restore(NoteVersion version, DateTime at) async {
    final current = await (_db.select(_db.items)..where((t) => t.id.equals(version.itemId))).getSingleOrNull();
    if (current == null) return;
    await _db.transaction(() async {
      await _db.into(_db.noteVersions).insert(
        NoteVersionsCompanion.insert(id: const Uuid().v4(), itemId: current.id, title: current.title, body: current.body, savedAt: current.updatedAt),
      );
      // время правки сдвигается отдельно: без перерыва триггер не снимет нынешнее второй раз
      await (_db.update(_db.items)..where((t) => t.id.equals(current.id))).write(ItemsCompanion(updatedAt: Value(at)));
      await _items.setTitleBody(current.id, title: version.title, body: version.body, at: at);
    });
  }
}
