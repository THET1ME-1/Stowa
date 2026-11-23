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
  Future<void> restore(NoteVersion version, DateTime at) => restoreText(version.itemId, title: version.title, body: version.body, at: at);

  /// Вернуть заметке заголовок и текст — из снимка устройства или из облака. Шапка (метки,
  /// напоминание, свойства) остаётся нынешней.
  Future<void> restoreText(String itemId, {required String title, required String body, required DateTime at}) async {
    final current = await (_db.select(_db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (current == null) return;
    await _db.transaction(() async {
      await _db.into(_db.noteVersions).insert(
        NoteVersionsCompanion.insert(id: const Uuid().v4(), itemId: current.id, title: current.title, body: current.body, savedAt: current.updatedAt),
      );
      // время правки сдвигается отдельно: без перерыва триггер не снимет нынешнее второй раз
      await (_db.update(_db.items)..where((t) => t.id.equals(current.id))).write(ItemsCompanion(updatedAt: Value(at)));
      await _items.setTitleBody(current.id, title: title, body: body, at: at);
    });
  }

  /// Путь файла заметки в хранилище: по нему история в облаке.
  Future<String?> pathOf(String itemId) async => (await (_db.select(_db.vaultFiles)..where((t) => t.itemId.equals(itemId))).getSingleOrNull())?.path;

  /// Живая заметка (или холст, база, рисунок), чей файл лежит по пути [path]; null — такого нет.
  Future<Item?> itemAt(String path) async {
    final query = _db.select(_db.vaultFiles).join([innerJoin(_db.items, _db.items.id.equalsExp(_db.vaultFiles.itemId))])
      ..where(_db.vaultFiles.path.equals(path) & _db.items.deletedAt.isNull());
    return (await query.getSingleOrNull())?.readTable(_db.items);
  }
}
