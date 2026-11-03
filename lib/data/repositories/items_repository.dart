import 'package:drift/drift.dart';

import '../../domain/folder_guess.dart';
import '../../domain/line_query.dart';
import '../../domain/models.dart';
import '../../domain/search_rank.dart';
import '../../services/reminder_service.dart' show Reminder, reminderText;
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
    this.tags = const [],
    this.filePath,
    this.fileMime,
    this.fileSize = 0,
    this.transcript,
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
  final List<String> tags;

  /// Первое вложение любого вида: голосовое, ролик, файл.
  final String? filePath;
  final String? fileMime;
  final int fileSize;
  final String? transcript;
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
    WHERE item_tags.item_id = items.id) AS tag_names,
  (SELECT attachments.path || char(31) || attachments.mime || char(31) || attachments.size FROM attachments
    WHERE attachments.item_id = items.id ORDER BY attachments.position LIMIT 1) AS first_file
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
    ])..where(_db.itemTags.itemId.equals(id))).get();
    final attachments =
        await (_db.select(_db.attachments)
              ..where((t) => t.itemId.equals(id))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    return ItemFull(item: item, tags: {for (final row in tagRows) row.readTable(_db.tags).name: row.readTable(_db.itemTags).source}, attachments: attachments);
  }

  /// Последние живые вещи, новые первыми. Ничья разрешается по id, иначе
  /// SQLite отдаёт равные строки в любом порядке, и лента тасуется сама.
  Stream<List<ItemCard>> watchRecent({int limit = 20}) {
    return _db
        .customSelect(
          '$_cardSelect ORDER BY items.created_at DESC, items.id DESC LIMIT ?',
          variables: [Variable.withInt(limit)],
          readsFrom: {_db.items, _db.folders, _db.attachments, _db.itemTags, _db.tags},
        )
        .watch()
        .map((rows) => [for (final row in rows) _card(row)]);
  }

  /// Ближайшие напоминания с этого момента, по времени. Их мало, поэтому
  /// отбор идёт в Dart: время хранится текстом, сравнивать строки ненадёжно.
  Stream<List<ItemCard>> watchUpcoming(DateTime now, {int limit = 3}) {
    return _db
        .customSelect('$_cardSelect AND items.reminder_at IS NOT NULL', readsFrom: {_db.items, _db.folders, _db.attachments, _db.itemTags, _db.tags})
        .watch()
        .map((rows) {
      final cards = [for (final row in rows) _card(row)].where((card) => !card.reminderAt!.isBefore(now)).toList()
        ..sort((a, b) => a.reminderAt!.compareTo(b.reminderAt!));
      return cards.take(limit).toList();
    });
  }

  static const _folderDocsSql = '''
SELECT items.folder_id AS folder_id,
  items.title || ' ' || items.body || ' ' || coalesce(items.ai_description, '') || ' ' || coalesce(items.transcript, '') || ' ' ||
  coalesce((SELECT group_concat(tags.name, ' ') FROM item_tags JOIN tags ON tags.id = item_tags.tag_id
    WHERE item_tags.item_id = items.id), '') AS text
FROM items JOIN folders ON folders.id = items.folder_id AND folders.deleted_at IS NULL
WHERE items.deleted_at IS NULL''';

  FolderDoc _folderDoc(QueryRow row) => FolderDoc(folderId: row.read<String>('folder_id'), text: row.read<String>('text'));

  /// Всё, что уже разложено по живым папкам: из этого учится угадыватель папки.
  Future<List<FolderDoc>> folderDocs() async => [for (final row in await _db.customSelect(_folderDocsSql).get()) _folderDoc(row)];

  Stream<List<FolderDoc>> watchFolderDocs() => _db
      .customSelect(_folderDocsSql, readsFrom: {_db.items, _db.folders, _db.itemTags, _db.tags})
      .watch()
      .map((rows) => [for (final row in rows) _folderDoc(row)]);

  /// Все живые напоминания: по ним ставятся будильники системы.
  Stream<List<Reminder>> watchReminders() {
    return (_db.select(_db.items)..where((t) => t.reminderAt.isNotNull() & t.deletedAt.isNull()))
        .watch()
        .map((rows) => [for (final row in rows) _reminder(row)]);
  }

  Reminder _reminder(Item row) => (id: row.id, title: row.title, body: reminderText(row.title, row.body), at: row.reminderAt!);

  /// «Через час» на уведомлении: то же напоминание позже. Вернёт его, чтобы сразу поставить будильник.
  Future<Reminder?> snoozeReminder(String id, DateTime at) async {
    await (_db.update(_db.items)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(ItemsCompanion(reminderAt: Value(at)));
    final row = await (_db.select(_db.items)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _reminder(row);
  }

  /// Вещи папки, новые первыми; без id — всё, что лежит без папки.
  Stream<List<ItemCard>> watchFolder(String? folderId) {
    return _db
        .customSelect(
          '$_cardSelect AND ${folderId == null ? 'items.folder_id IS NULL' : 'items.folder_id = ?'} ORDER BY items.created_at DESC, items.id DESC',
          variables: [if (folderId != null) Variable.withString(folderId)],
          readsFrom: {_db.items, _db.folders, _db.attachments, _db.itemTags, _db.tags},
        )
        .watch()
        .map((rows) => [for (final row in rows) _card(row)]);
  }

  /// Вещь целиком и дальше при каждой правке.
  Stream<ItemFull?> watchItem(String id) {
    return _db.customSelect('SELECT 1', readsFrom: {_db.items, _db.itemTags, _db.tags, _db.attachments}).watch().asyncMap((_) => get(id));
  }

  /// Человек переложил вещь сам: ИИ её больше не трогает, а пример запоминается.
  Future<void> moveToFolder(String id, String? folderId, DateTime at) async {
    await _db.transaction(() async {
      final item = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingle();
      await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
        ItemsCompanion(folderId: Value(folderId), sortedBy: const Value(SortedBy.user), sortState: const Value(SortState.sorted), updatedAt: Value(at)),
      );
      if (folderId != null && folderId != item.folderId) {
        await _db
            .into(_db.corrections)
            .insert(
              CorrectionsCompanion.insert(id: '$id-${at.microsecondsSinceEpoch}', itemId: id, fromFolderId: Value(item.folderId), toFolderId: folderId, at: at),
            );
      }
    });
  }

  Future<void> setBody(String id, String body, DateTime at) {
    return (_db.update(_db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(body: Value(body), updatedAt: Value(at)));
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
        .customSelect('SELECT items.id FROM items WHERE items.deleted_at IS NULL ORDER BY items.created_at DESC LIMIT 500', readsFrom: {_db.items})
        .get();
    ids.addAll(recent.map((row) => row.read<String>('id')));
    if (tags.isNotEmpty || folderId != null) {
      final filtered = await _db
          .customSelect(
            'SELECT DISTINCT items.id FROM items LEFT JOIN item_tags ON item_tags.item_id = items.id '
            'LEFT JOIN tags ON tags.id = item_tags.tag_id WHERE items.deleted_at IS NULL '
            '${folderId != null ? 'AND items.folder_id = ?' : ''} ${tags.isNotEmpty ? 'AND tags.name LIKE ?' : ''} LIMIT 500',
            variables: [if (folderId != null) Variable.withString(folderId), if (tags.isNotEmpty) Variable.withString('${tags.first}%')],
            readsFrom: {_db.items, _db.itemTags, _db.tags},
          )
          .get();
      ids.addAll(filtered.map((row) => row.read<String>('id')));
    }
    if (ids.isEmpty) return const [];

    final rows = await _db
        .customSelect(
          '$_cardSelect AND items.id IN (${List.filled(ids.length, '?').join(',')})',
          variables: [for (final id in ids) Variable.withString(id)],
          readsFrom: {_db.items, _db.folders, _db.attachments, _db.itemTags, _db.tags},
        )
        .get();
    final cards = <String, ItemCard>{};
    final docs = <SearchDoc>[];
    for (final row in rows) {
      final card = _card(row);
      final item = _db.items.map(row.data);
      final tagNames = row.readNullable<String>('tag_names');
      cards[card.id] = card;
      docs.add(
        SearchDoc(
          id: card.id,
          title: card.title,
          body: card.body,
          tags: tagNames == null || tagNames.isEmpty ? const [] : tagNames.split('\x1f'),
          folderName: card.folderName,
          folderId: card.folderId,
          deep: [item.aiDescription, item.transcript].nonNulls.join('\n'),
          url: card.url ?? '',
          ageDays: now.difference(item.updatedAt).inDays,
        ),
      );
    }
    return [
      for (final hit in rankSearch(docs, words, tagFilters: tags, folderFilter: folderId, limit: limit)) SearchResult(card: cards[hit.doc.id]!, hit: hit),
    ];
  }

  ItemCard _card(QueryRow row) {
    final item = _db.items.map(row.data);
    final tagNames = row.readNullable<String>('tag_names');
    final file = row.readNullable<String>('first_file')?.split('\x1f');
    return ItemCard(
      tags: tagNames == null || tagNames.isEmpty ? const [] : tagNames.split('\x1f'),
      filePath: file?[0],
      fileMime: file != null && file.length > 1 ? file[1] : null,
      fileSize: file != null && file.length > 2 ? int.tryParse(file[2]) ?? 0 : 0,
      transcript: item.transcript,
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
