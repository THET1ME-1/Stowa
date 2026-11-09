import 'package:drift/drift.dart';

import '../data/db/database.dart';
import '../data/repositories/items_repository.dart';
import '../domain/folder_guess.dart';
import '../domain/models.dart';

/// Весь текст вещи для угадывателя: то же, что видит поиск, плюс превью ссылки.
const _itemText = "items.title || ' ' || items.body || ' ' || coalesce(items.ai_description, '') || ' ' || "
    "coalesce(items.transcript, '') || ' ' || coalesce(items.preview_text, '')";

const _firstFile = '(SELECT attachments.path FROM attachments WHERE attachments.item_id = items.id ORDER BY attachments.position LIMIT 1)';

/// Тегов, которые алгоритм ставит одной вещи сам, не больше этого.
const _maxAutoTags = 2;

/// Разбор без ИИ после сохранения: «Без папки» раскладывается заново, когда
/// в папках появились похожие вещи, а вещь получает теги своих соседей. Всё,
/// что он сделал, помечено `similar` и отменяется.
class AutoSorter {
  AutoSorter(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;

  /// Сейчас: своя догадка становится образцом, когда неделю не перекладывали.
  final DateTime Function() _clock;

  /// Что человек вернул «Отменить» в этом запуске: второй раз не тащим.
  final _undone = <String>{};

  /// Разложить вещи без папки, которые человек не оставлял там сам. Вернёт
  /// id переложенных: по ним «Отменить» вернёт всё как было.
  Future<List<String>> sortInbox({String? onlyId, Iterable<String> skip = const []}) async {
    final index = FolderIndex(await ItemsRepository(_db, clock: _clock).folderDocs());
    final rows = await _db
        .customSelect(
          'SELECT items.id, items.kind, items.url, $_itemText AS text, $_firstFile AS file_path FROM items '
          "WHERE items.deleted_at IS NULL AND items.folder_id IS NULL AND items.sorted_by = 'none'"
          '${onlyId == null ? '' : ' AND items.id = ?'}',
          variables: [if (onlyId != null) Variable.withString(onlyId)],
        )
        .get();
    final moved = <String>[];
    for (final row in rows) {
      final id = row.read<String>('id');
      if (_undone.contains(id) || skip.contains(id)) continue;
      final signals = itemSignals(kind: ItemKind.values.byName(row.read<String>('kind')), url: row.readNullable<String>('url'), fileName: row.readNullable<String>('file_path'));
      final guess = index.guess(row.read<String>('text'), signals: signals);
      if (guess == null) continue;
      await (_db.update(_db.items)..where((t) => t.id.equals(id) & t.folderId.isNull() & t.sortedBy.equalsValue(SortedBy.none))).write(
        ItemsCompanion(folderId: Value(guess.folderId), sortedBy: const Value(SortedBy.similar), sortState: const Value(SortState.sorted)),
      );
      moved.add(id);
    }
    return moved;
  }

  /// Вернуть разложенное в «Без папки». Что человек успел переложить сам, остаётся.
  Future<void> undoSort(List<String> ids) async {
    _undone.addAll(ids);
    await (_db.update(_db.items)..where((t) => t.id.isIn(ids) & t.sortedBy.equalsValue(SortedBy.similar))).write(
      const ItemsCompanion(folderId: Value(null), sortedBy: Value(SortedBy.none), sortState: Value(SortState.pending)),
    );
  }

  /// Поставить вещи теги, которые стоят у похожих на неё. Учится только на
  /// тегах, поставленных человеком, правилами и из текста — не на своих.
  Future<List<String>> tagItem(String id) async => (await tagItems([id]))[id] ?? const [];

  /// То же для пачки: индекс соседей строится один раз. Перенос из Telegram по одной
  /// заметке перечитывал всю базу на каждую — две тысячи сообщений шли минутами.
  /// Соседи — заметки вне пачки.
  Future<Map<String, List<String>>> tagItems(List<String> ids) async {
    if (ids.isEmpty) return const {};
    // вещи без тегов тоже в индексе, с пустым ярлыком: редкость слова считается по всей базе,
    // иначе слово, общее для двух вещей с тегом, выглядело бы общим вообще
    final docs = await _db
        .customSelect(
          "SELECT coalesce(tags.name, '') AS tag, items.kind, items.url, $_itemText AS text, $_firstFile AS file_path "
          "FROM items LEFT JOIN item_tags ON item_tags.item_id = items.id AND item_tags.source != 'similar' "
          'LEFT JOIN tags ON tags.id = item_tags.tag_id '
          'WHERE items.deleted_at IS NULL AND items.id NOT IN (${List.filled(ids.length, '?').join(', ')})',
          variables: [for (final id in ids) Variable.withString(id)],
        )
        .get();
    if (docs.every((row) => row.read<String>('tag').isEmpty)) return {for (final id in ids) id: const <String>[]};
    final index = FolderIndex([
      for (final row in docs)
        FolderDoc(
          folderId: row.read<String>('tag'),
          text: row.read<String>('text'),
          signals: itemSignals(kind: ItemKind.values.byName(row.read<String>('kind')), url: row.readNullable<String>('url'), fileName: row.readNullable<String>('file_path')),
        ),
    ]);
    final added = <String, List<String>>{};
    for (final id in ids) {
      final target = await _db
          .customSelect(
            'SELECT items.kind, items.url, $_itemText AS text, $_firstFile AS file_path, '
            '(SELECT group_concat(tags.name, char(31)) FROM item_tags JOIN tags ON tags.id = item_tags.tag_id WHERE item_tags.item_id = items.id) AS tag_names '
            'FROM items WHERE items.id = ? AND items.deleted_at IS NULL',
            variables: [Variable.withString(id)],
          )
          .getSingleOrNull();
      if (target == null) {
        added[id] = const [];
        continue;
      }
      final has = (target.readNullable<String>('tag_names') ?? '').split('\x1f').toSet();
      final signals = itemSignals(kind: ItemKind.values.byName(target.read<String>('kind')), url: target.readNullable<String>('url'), fileName: target.readNullable<String>('file_path'));
      final picked = index
          .strong(target.read<String>('text'), signals: signals, minScore: 1.2)
          .where((tag) => tag.isNotEmpty && !has.contains(tag))
          .take(_maxAutoTags)
          .toList();
      for (final name in picked) {
        final tag = await (_db.select(_db.tags)..where((t) => t.name.equals(name))).getSingle();
        await _db.into(_db.itemTags).insert(ItemTagsCompanion.insert(itemId: id, tagId: tag.id, source: TagSource.similar), mode: InsertMode.insertOrIgnore);
      }
      added[id] = picked;
    }
    return added;
  }
}
