import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../db/database.dart';

/// Вещь целиком: запись, теги с источником и вложения по порядку.
class ItemFull {
  const ItemFull({required this.item, required this.tags, required this.attachments});

  final Item item;
  final Map<String, TagSource> tags;
  final List<Attachment> attachments;
}

/// Карточка для лент: то, что нужно, чтобы нарисовать вещь в списке.
class ItemCard {
  const ItemCard({
    required this.id,
    required this.title,
    required this.kind,
    required this.folderId,
    required this.sortState,
    required this.createdAt,
    this.body = '',
    this.url,
    this.folderName,
    this.folderIcon,
    this.reminderAt,
    this.thumbPath,
  });

  final String id;
  final String title;
  final ItemKind kind;
  final String? folderId;
  final SortState sortState;
  final DateTime createdAt;
  final String body;
  final String? url;
  final String? folderName;
  final String? folderIcon;
  final DateTime? reminderAt;

  /// Первая картинка вещи, путь от папки приложения.
  final String? thumbPath;
}

// карточка целиком: вещь, её папка и первая картинка одним запросом
const _cardSelect = '''
SELECT items.*, folders.name AS folder_name, folders.icon AS folder_icon,
  (SELECT attachments.path FROM attachments
    WHERE attachments.item_id = items.id AND attachments.mime LIKE 'image/%'
    ORDER BY attachments.position LIMIT 1) AS thumb_path
FROM items LEFT JOIN folders ON folders.id = items.folder_id AND folders.deleted_at IS NULL
WHERE items.deleted_at IS NULL''';

class ItemsRepository {
  ItemsRepository(this._db);

  final AppDatabase _db;

  Future<ItemFull?> get(String id) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (item == null) return null;
    final tagRows = await (_db.select(_db.itemTags).join([
      innerJoin(_db.tags, _db.tags.id.equalsExp(_db.itemTags.tagId)),
    ])..where(_db.itemTags.itemId.equals(id)))
        .get();
    final attachments = await (_db.select(_db.attachments)
          ..where((t) => t.itemId.equals(id))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    return ItemFull(
      item: item,
      tags: {for (final row in tagRows) row.readTable(_db.tags).name: row.readTable(_db.itemTags).source},
      attachments: attachments,
    );
  }

  /// Последние живые вещи, новые первыми. Ничья разрешается по id, иначе
  /// SQLite отдаёт равные строки в любом порядке, и лента тасуется сама.
  Stream<List<ItemCard>> watchRecent({int limit = 20}) {
    return _db
        .customSelect(
          '$_cardSelect ORDER BY items.created_at DESC, items.id DESC LIMIT ?',
          variables: [Variable.withInt(limit)],
          readsFrom: {_db.items, _db.folders, _db.attachments},
        )
        .watch()
        .map((rows) => [for (final row in rows) _card(row)]);
  }

  /// Ближайшие напоминания с этого момента, по времени. Их мало, поэтому
  /// отбор идёт в Dart: время хранится текстом, сравнивать строки ненадёжно.
  Stream<List<ItemCard>> watchUpcoming(DateTime now, {int limit = 3}) {
    return _db
        .customSelect('$_cardSelect AND items.reminder_at IS NOT NULL', readsFrom: {_db.items, _db.folders, _db.attachments})
        .watch()
        .map((rows) {
          final cards = [for (final row in rows) _card(row)].where((card) => !card.reminderAt!.isBefore(now)).toList()
            ..sort((a, b) => a.reminderAt!.compareTo(b.reminderAt!));
          return cards.take(limit).toList();
        });
  }

  /// «Готово» у напоминания: вещь остаётся, напоминание снимается.
  Future<void> clearReminder(String id) {
    return (_db.update(_db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(reminderAt: Value(null)));
  }

  /// Мягкое удаление: вещь пропадает из лент и поиска, чистка — через 30 дней.
  Future<void> softDelete(String id, DateTime at) {
    return (_db.update(_db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(deletedAt: Value(at)));
  }

  /// Вернуть удалённое, пока человек жмёт «Отменить».
  Future<void> restore(String id) {
    return (_db.update(_db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(deletedAt: Value(null)));
  }

  ItemCard _card(QueryRow row) {
    final item = _db.items.map(row.data);
    return ItemCard(
      id: item.id,
      title: item.title,
      kind: item.kind,
      folderId: item.folderId,
      sortState: item.sortState,
      createdAt: item.createdAt,
      body: item.body,
      url: item.url,
      folderName: row.readNullable<String>('folder_name'),
      folderIcon: row.readNullable<String>('folder_icon'),
      reminderAt: item.reminderAt,
      thumbPath: row.readNullable<String>('thumb_path'),
    );
  }
}
