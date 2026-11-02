import 'package:drift/drift.dart';

import '../../domain/line_query.dart';
import '../../domain/models.dart';
import '../../domain/search_rank.dart';
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

/// Найденная вещь: карточка и что в ней совпало.
class SearchResult {
  const SearchResult({required this.card, required this.hit});

  final ItemCard card;
  final SearchHit hit;
}

// карточка целиком: вещь, её папка, первая картинка и теги одним запросом
const _cardSelect = '''
SELECT items.*, folders.name AS folder_name, folders.icon AS folder_icon,
  (SELECT attachments.path FROM attachments
    WHERE attachments.item_id = items.id AND attachments.mime LIKE 'image/%'
    ORDER BY attachments.position LIMIT 1) AS thumb_path,
  (SELECT group_concat(tags.name, char(31)) FROM item_tags JOIN tags ON tags.id = item_tags.tag_id
    WHERE item_tags.item_id = items.id) AS tag_names
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

  /// «Дописать»: новая мысль ложится в конец старой заметки, второй заметки нет.
  Future<void> append(String id, String text, DateTime at) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingle();
    final body = item.body.trim().isEmpty ? text : '${item.body.trimRight()}\n\n$text';
    await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(body: Value(body), updatedAt: Value(at)));
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

  /// Поиск строки ввода. Кандидаты — из индекса по основам слов и последние вещи
  /// (там ловятся опечатки и имена папок), порядок решает [rankSearch].
  Future<List<SearchResult>> search({required List<String> words, List<String> tags = const [], String? folderId, required DateTime now, int limit = 6}) async {
    if (words.isEmpty && tags.isEmpty && folderId == null) return const [];
    final ids = <String>{};
    if (words.isNotEmpty) {
      ids.addAll(await _db.searchIds(words.map((word) => '"${stem(word)}"*').join(' OR ')));
    }
    final recent = await _db
        .customSelect(
          'SELECT items.id FROM items WHERE items.deleted_at IS NULL ORDER BY items.created_at DESC LIMIT 500',
          readsFrom: {_db.items},
        )
        .get();
    ids.addAll(recent.map((row) => row.read<String>('id')));
    if (tags.isNotEmpty || folderId != null) {
      final filtered = await _db.customSelect(
        'SELECT DISTINCT items.id FROM items LEFT JOIN item_tags ON item_tags.item_id = items.id '
        'LEFT JOIN tags ON tags.id = item_tags.tag_id WHERE items.deleted_at IS NULL '
        '${folderId != null ? 'AND items.folder_id = ?' : ''} ${tags.isNotEmpty ? 'AND tags.name LIKE ?' : ''} LIMIT 500',
        variables: [if (folderId != null) Variable.withString(folderId), if (tags.isNotEmpty) Variable.withString('${tags.first}%')],
        readsFrom: {_db.items, _db.itemTags, _db.tags},
      ).get();
      ids.addAll(filtered.map((row) => row.read<String>('id')));
    }
    if (ids.isEmpty) return const [];

    final rows = await _db.customSelect(
      '$_cardSelect AND items.id IN (${List.filled(ids.length, '?').join(',')})',
      variables: [for (final id in ids) Variable.withString(id)],
      readsFrom: {_db.items, _db.folders, _db.attachments, _db.itemTags, _db.tags},
    ).get();
    final cards = <String, ItemCard>{};
    final docs = <SearchDoc>[];
    for (final row in rows) {
      final card = _card(row);
      final item = _db.items.map(row.data);
      final tagNames = row.readNullable<String>('tag_names');
      cards[card.id] = card;
      docs.add(SearchDoc(
        id: card.id,
        title: card.title,
        body: card.body,
        tags: tagNames == null || tagNames.isEmpty ? const [] : tagNames.split('\x1f'),
        folderName: card.folderName,
        folderId: card.folderId,
        deep: [item.aiDescription, item.transcript].nonNulls.join('\n'),
        url: card.url ?? '',
        ageDays: now.difference(item.updatedAt).inDays,
      ));
    }
    return [
      for (final hit in rankSearch(docs, words, tagFilters: tags, folderFilter: folderId, limit: limit))
        SearchResult(card: cards[hit.doc.id]!, hit: hit),
    ];
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
