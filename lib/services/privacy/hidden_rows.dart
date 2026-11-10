/// Строки скрытых папок в базе: что к ним относится, выгрузка в `rows.json` открытой папки,
/// стирание при закрытии и возврат при открытии. Пока скрытое закрыто, этих строк в базе нет.
library;

import 'package:drift/drift.dart';

import '../../data/db/database.dart';

/// Метка папки открытого скрытого в выгруженных путях: сама папка после переустановки может смениться.
const sealedRootToken = '{sealed}';

const _hiddenFolders = 'SELECT id FROM folders WHERE hidden = 1';
const _hiddenItems = 'SELECT id FROM items WHERE folder_id IN ($_hiddenFolders)';

/// Теги, которые стоят только на скрытых заметках: без скрытого их не видно.
const _ownTags = 'SELECT tag_id FROM item_tags WHERE item_id IN ($_hiddenItems) EXCEPT SELECT tag_id FROM item_tags WHERE item_id NOT IN ($_hiddenItems)';

/// Что в таблице относится к скрытому. Теги выгружаются все, что стоят на скрытых заметках,
/// а стираются и прячутся из служебного только свои.
const _hiddenWhere = {
  'folders': 'id IN ($_hiddenFolders)',
  'items': 'id IN ($_hiddenItems)',
  'attachments': 'item_id IN ($_hiddenItems)',
  'item_tags': 'item_id IN ($_hiddenItems)',
  'highlights': 'item_id IN ($_hiddenItems)',
  'facts': 'item_id IN ($_hiddenItems)',
  'extractor_runs': 'item_id IN ($_hiddenItems)',
  'note_versions': 'item_id IN ($_hiddenItems)',
  'file_jobs': 'item_id IN ($_hiddenItems)',
  'ai_jobs': 'item_id IN ($_hiddenItems)',
  'ai_log': 'item_id IN ($_hiddenItems)',
  'rule_hits': 'item_id IN ($_hiddenItems)',
  'tags': 'id IN (SELECT tag_id FROM item_tags WHERE item_id IN ($_hiddenItems))',
  'links': 'from_id IN ($_hiddenItems) OR to_id IN ($_hiddenItems)',
  'rules': "action_kind = 'toFolder' AND action_value IN ($_hiddenFolders)",
  'corrections': 'item_id IN ($_hiddenItems) OR from_folder_id IN ($_hiddenFolders) OR to_folder_id IN ($_hiddenFolders)',
  'word_stats': 'target_id IN ($_hiddenFolders)',
  'canvas_positions': 'folder_id IN ($_hiddenFolders) OR item_id IN ($_hiddenItems)',
};

/// Пути файлов: у скрытых заметок — внутри открытой папки.
const _pathColumns = {
  'items': ['cover_path'],
  'attachments': ['path', 'thumb_path'],
  'file_jobs': ['target'],
};

/// Условие «не скрытое» для служебного хранилища. NULL в сравнении не должен прятать строку.
String plainWhere(String table) {
  if (table == 'tags') return 'id NOT IN ($_ownTags)';
  final hidden = _hiddenWhere[table];
  return hidden == null ? '1' : 'NOT coalesce(($hidden), 0)';
}

Future<Set<String>> _ids(AppDatabase db, String sql) async => {for (final row in await db.customSelect(sql).get()) row.data.values.first! as String};

Future<Set<String>> hiddenFolderIds(AppDatabase db) => _ids(db, _hiddenFolders);

Future<Set<String>> hiddenItemIds(AppDatabase db) => _ids(db, _hiddenItems);

/// Все строки скрытого по таблицам; пути открытой папки — через [sealedRootToken].
Future<Map<String, Object?>> dumpHidden(AppDatabase db, {required String openRoot}) async {
  final dump = <String, Object?>{'version': 1};
  for (final MapEntry(key: table, value: where) in _hiddenWhere.entries) {
    final rows = await db.customSelect('SELECT * FROM $table WHERE $where').get();
    dump[table] = [
      for (final row in rows)
        {
          for (final MapEntry(:key, :value) in row.data.entries)
            key: value is String && (_pathColumns[table]?.contains(key) ?? false) && value.startsWith('$openRoot/')
                ? '$sealedRootToken${value.substring(openRoot.length)}'
                : value,
        },
    ];
  }
  return dump;
}

/// Стереть скрытое из базы тихо: файлы хранилища уже не о нём.
Future<void> deleteHidden(AppDatabase db) => _quietly(db, () async {
  final folders = await hiddenFolderIds(db);
  final items = await hiddenItemIds(db);
  final ownTags = await _ids(db, _ownTags);
  if (folders.isEmpty && items.isEmpty) return;
  Future<void> drop(String table, String column, Set<String> ids) async {
    if (ids.isEmpty) return;
    await db.customStatement('DELETE FROM $table WHERE $column IN (${List.filled(ids.length, '?').join(', ')})', [...ids]);
  }

  for (final table in ['attachments', 'item_tags', 'highlights', 'facts', 'extractor_runs', 'note_versions', 'file_jobs', 'ai_jobs', 'ai_log', 'rule_hits', 'vault_files']) {
    await drop(table, 'item_id', items);
  }
  await drop('links', 'from_id', items);
  await drop('links', 'to_id', items);
  await drop('corrections', 'item_id', items);
  await drop('corrections', 'from_folder_id', folders);
  await drop('corrections', 'to_folder_id', folders);
  await drop('canvas_positions', 'item_id', items);
  await drop('canvas_positions', 'folder_id', folders);
  await drop('word_stats', 'target_id', folders);
  if (folders.isNotEmpty) {
    await db.customStatement(
      "DELETE FROM rules WHERE action_kind = 'toFolder' AND action_value IN (${List.filled(folders.length, '?').join(', ')})",
      [...folders],
    );
  }
  await drop('tags', 'id', ownTags);
  // записи в хранилище о скрытых заметках больше не нужны: писать их некому и некуда
  for (final prefix in ['item:', 'facts:', 'history:']) {
    await drop('vault_queue', 'target', {for (final id in items) '$prefix$id'});
  }
  await drop('items', 'id', items);
  await drop('folders', 'id', folders);
});

/// Вернуть выгруженное. Тег, который стёрли, пока скрытое было закрыто, заводится снова;
/// тег с тем же именем, заведённый за это время, становится тем же тегом.
Future<void> restoreHidden(AppDatabase db, Map<String, Object?> dump, {required String openRoot}) => _quietly(db, () async {
  List<Map<String, Object?>> rows(String table) => [for (final row in (dump[table] as List?) ?? const []) (row as Map).cast<String, Object?>()];

  final remap = <String, String>{};
  for (final tag in rows('tags')) {
    final id = tag['id']! as String;
    if ((await db.customSelect('SELECT 1 FROM tags WHERE id = ?', variables: [Variable.withString(id)]).get()).isNotEmpty) continue;
    final same = await db.customSelect('SELECT id FROM tags WHERE name = ?', variables: [Variable.withString(tag['name']! as String)]).getSingleOrNull();
    if (same != null) {
      remap[id] = same.read<String>('id');
      continue;
    }
    await _insert(db, 'tags', tag);
  }
  for (final table in _hiddenWhere.keys) {
    if (table == 'tags') continue;
    for (final row in rows(table)) {
      final fixed = {
        for (final MapEntry(:key, :value) in row.entries)
          key: value is String && (_pathColumns[table]?.contains(key) ?? false) && value.startsWith(sealedRootToken)
              ? '$openRoot${value.substring(sealedRootToken.length)}'
              : value,
      };
      if (table == 'item_tags') fixed['tag_id'] = remap[fixed['tag_id']] ?? fixed['tag_id'];
      // номер строки журнала мог занять свежий запрос: возвращённая строка получает новый
      if (table == 'ai_log') fixed.remove('id');
      await _insert(db, table, fixed);
    }
  }
});

Future<void> _insert(AppDatabase db, String table, Map<String, Object?> row) {
  final columns = row.keys.toList();
  return db.customStatement(
    'INSERT OR REPLACE INTO $table (${columns.join(', ')}) VALUES (${List.filled(columns.length, '?').join(', ')})',
    [for (final column in columns) row[column]],
  );
}

/// Правка без записи в хранилище: флаг глушит триггеры очереди, как у читателя хранилища.
Future<void> _quietly(AppDatabase db, Future<void> Function() change) => db.transaction(() async {
  await db.into(db.vaultFlags).insertOnConflictUpdate(VaultFlagsCompanion.insert(name: 'importing'));
  try {
    await change();
  } finally {
    await (db.delete(db.vaultFlags)..where((t) => t.name.equals('importing'))).go();
  }
});
