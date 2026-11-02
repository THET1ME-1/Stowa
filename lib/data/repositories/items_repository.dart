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
  });

  final String id;
  final String title;
  final ItemKind kind;
  final String? folderId;
  final SortState sortState;
  final DateTime createdAt;
}

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
    final query = _db.select(_db.items)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt), (t) => OrderingTerm.desc(t.id)])
      ..limit(limit);
    return query.watch().map((rows) => [
          for (final row in rows)
            ItemCard(
              id: row.id,
              title: row.title,
              kind: row.kind,
              folderId: row.folderId,
              sortState: row.sortState,
              createdAt: row.createdAt,
            ),
        ]);
  }
}
