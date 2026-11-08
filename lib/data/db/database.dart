import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/item_title.dart';
import '../../domain/models.dart';
import 'tables.dart';

part 'database.g.dart';

// поля, которые ищутся
const _ftsColumns = 'title, body, ai_description, transcript, url, place_name, facts_text';
const _ftsSource = ['title', 'body', 'ai_description', 'transcript', 'url', 'place_name', 'facts_text'];

// unicode61 снимает знаки с латиницы, но не трогает «ё» и польскую «ł»: их индекс
// получает уже заменёнными; NULL — пустая строка, одинаково при записи и при удалении
const _ftsSwaps = [('ё', 'е'), ('Ё', 'Е'), ('ł', 'l'), ('Ł', 'L')];

String _ftsValue(String expression) => _ftsSwaps.fold("coalesce($expression, '')", (value, swap) => "replace($value, '${swap.$1}', '${swap.$2}')");

String _ftsValues(String row) => _ftsSource.map((column) => _ftsValue('$row.$column')).join(', ');

final _ftsNew = _ftsValues('new');
final _ftsOld = _ftsValues('old');

/// Запрос к индексу с теми же заменами, что и в самом индексе.
String normalizeSearchText(String text) => _ftsSwaps.fold(text, (value, swap) => value.replaceAll(swap.$1, swap.$2));

// поля вещи, которые идут в файл хранилища: их правка ставит вещь в очередь записи
const _vaultItemColumns =
    'kind, title, body, url, folder_id, sorted_by, cover_path, preview_text, preview_site, preview_author, '
    'duration_seconds, latitude, longitude, place_name, reminder_at, remind_place, remind_latitude, remind_longitude, remind_place_name, '
    'deleted_at, created_at, updated_at';

// всё, что пишется в .stowa/*.json: таблица → цель очереди
const _vaultMetaTables = {
  'folders': 'meta:folders',
  'tags': 'meta:tags',
  'rules': 'meta:rules',
  'links': 'meta:links',
  'word_stats': 'meta:learned',
  'corrections': 'meta:learned',
  'canvas_positions': 'meta:canvas',
  'places': 'meta:places',
};

const _vaultMetaTargets = ['meta:folders', 'meta:tags', 'meta:rules', 'meta:links', 'meta:learned', 'meta:canvas', 'meta:places'];

const _notImporting = "NOT EXISTS (SELECT 1 FROM vault_flags WHERE name = 'importing')";

// новая просьба поверх старой поднимает версию и снимает аренду
const _vaultUpsert = 'ON CONFLICT(target) DO UPDATE SET version = version + 1, claimed_until = NULL';

String _vaultEnqueue(String target) => 'INSERT INTO vault_queue (target) VALUES ($target) $_vaultUpsert;';

@DriftDatabase(
  tables: [Items, Attachments, FileJobs, Facts, ExtractorRuns, Folders, Tags, ItemTags, Rules, Links, AiJobs, AiLog, WordStats, Corrections, CanvasPositions, VaultQueue, VaultFiles, VaultFlags, Places, Highlights],
)
class AppDatabase extends _$AppDatabase {
  // одна база на процесс: кнопки уведомлений пишут из фонового Dart, и ленты приложения это видят
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'stowa', native: const DriftNativeOptions(shareAcrossIsolates: true)));

  /// База в памяти для тестов. Стримы закрываются сразу: иначе drift ждёт
  /// оборот цикла событий, а часы теста поддельные, и закрытие виснет.
  AppDatabase.memory() : super(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createSearch();
      await _createFactIndexes();
      await _createVaultTriggers();
    },
    onUpgrade: (migrator, from, to) async {
      // 2: превью ссылок и роликов
      if (from < 2) {
        for (final column in [items.coverPath, items.previewText, items.previewSite, items.previewAuthor, items.durationSeconds, items.previewAt]) {
          await migrator.addColumn(items, column);
        }
      }
      // 3: где вещь сохранена
      if (from < 3) {
        for (final column in [items.latitude, items.longitude, items.placeName]) {
          await migrator.addColumn(items, column);
        }
      }
      // 5: очередь файлов, которые ещё копируются
      if (from < 5) await migrator.createTable(fileJobs);
      // 6: факты извлекателей; их текст ищется вместе с вещью
      if (from < 6) {
        await migrator.addColumn(items, items.factsText);
        await migrator.createTable(facts);
        await migrator.createTable(extractorRuns);
        await _createFactIndexes();
      }
      // 4 и 6: индекс поиска строится заново — место, «ł» как «l», текст фактов
      if (from < 6) {
        for (final trigger in ['items_fts_insert', 'items_fts_delete', 'items_fts_update']) {
          await customStatement('DROP TRIGGER IF EXISTS $trigger');
        }
        await customStatement('DROP TABLE IF EXISTS items_fts');
        await _createSearch();
        await customStatement('INSERT INTO items_fts(rowid, $_ftsColumns) SELECT rowid, ${_ftsValues('items')} FROM items');
      }
      // 8: открыта ли заметка, напоминание по месту и места. До очереди хранилища: у базы
      // старше 7 её триггеры ставятся ниже и уже ссылаются на эти поля и таблицу
      if (from < 8) {
        for (final column in <GeneratedColumn<Object>>[items.openedAt, items.remindPlace, items.remindLatitude, items.remindLongitude, items.remindPlaceName]) {
          await migrator.addColumn(items, column);
        }
        await migrator.createTable(places);
      }
      // 11: папка в папке. До очереди хранилища: её триггер переименования смотрит на parent_id
      if (from < 11) await migrator.addColumn(folders, folders.parentId);
      // 7: хранилище файлами — очередь записи, карта файлов; всё уже накопленное ждёт выгрузки
      if (from < 7) {
        // до очереди: файлы хранилища сразу пишутся с целым текстом
        await _restoreTitleLines();
        await migrator.createTable(vaultQueue);
        await migrator.createTable(vaultFiles);
        await migrator.createTable(vaultFlags);
        // триггеры очереди ставятся и на цитаты (v10): таблица нужна до них
        await migrator.createTable(highlights);
        await _createVaultTriggers();
        await enqueueWholeVault();
      }
      // 8 у базы с очередью: триггер правки заметки знает новые поля, места — свой meta:places
      if (from == 7) {
        await customStatement('DROP TRIGGER IF EXISTS vault_items_update');
        await customStatement("CREATE TRIGGER vault_items_update AFTER UPDATE OF $_vaultItemColumns ON items WHEN $_notImporting BEGIN ${_vaultEnqueue("'item:' || new.id")} END");
        for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
          await customStatement("CREATE TRIGGER vault_places_${event.toLowerCase()}_meta AFTER $event ON places WHEN $_notImporting BEGIN ${_vaultEnqueue("'meta:places'")} END");
        }
      }
      // 9: цвет папки
      if (from < 9) await migrator.addColumn(folders, folders.color);
      // 10: статьи — цитаты, жива ли ссылка, где остановился читать
      if (from < 10) {
        for (final column in <GeneratedColumn<Object>>[items.goneAt, items.goneKept, items.linkCheckedAt, items.readPosition]) {
          await migrator.addColumn(items, column);
        }
        // базе младше 7 таблицу и её триггеры уже поставил переход на очередь хранилища
        if (from >= 7) {
          await migrator.createTable(highlights);
          await _createChildTriggers('highlights', 'item:');
        }
      }
      // 11 у базы с очередью: переименование и перенос папки двигают и заметки вложенных
      if (from >= 7 && from < 11) {
        await customStatement('DROP TRIGGER IF EXISTS vault_folders_rename');
        await _createFolderMoveTrigger();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // прежняя правка уносила первую строку заметки в заголовок и сохраняла текст без неё.
  // Заметки без файлов получают её обратно; у ссылок и файлов заголовок свой, их не трогаем
  Future<void> _restoreTitleLines() async {
    final rows = await customSelect(
      "SELECT id, title, body FROM items WHERE kind = 'note' AND NOT EXISTS (SELECT 1 FROM attachments WHERE attachments.item_id = items.id)",
    ).get();
    for (final row in rows) {
      final body = bodyWithTitleLine(row.readNullable<String>('body') ?? '', row.read<String>('title'));
      if (body == null) continue;
      await customUpdate('UPDATE items SET body = ? WHERE id = ?', variables: [Variable(body), Variable(row.read<String>('id'))], updates: {items});
    }
  }

  // факты вещи — по вещи; суммы для «до 500 лей» — по виду и числу
  Future<void> _createFactIndexes() async {
    await customStatement('CREATE INDEX IF NOT EXISTS facts_item ON facts (item_id, extractor)');
    await customStatement('CREATE INDEX IF NOT EXISTS facts_kind ON facts (kind, number)');
  }

  /// Всё в очередь записи хранилища: вещи, их факты и служебное. После переноса,
  /// восстановления копии и перехода со старой схемы файлы пишутся заново из базы.
  Future<void> enqueueWholeVault() async {
    await customStatement("INSERT INTO vault_queue (target) SELECT 'item:' || id FROM items WHERE true $_vaultUpsert");
    await customStatement("INSERT INTO vault_queue (target) SELECT 'facts:' || id FROM items WHERE true $_vaultUpsert");
    for (final target in _vaultMetaTargets) {
      await customStatement(_vaultEnqueue("'$target'"));
    }
  }

  /// Очередь записи хранилища: сколько задач и сумма их версий. По одному числу задач писатель
  /// не просыпался, когда правка поднимала версию уже стоящей задачи: задач столько же, а файл старый.
  /// Очередь пишут триггеры, а о них drift не знает, поэтому запрос пересчитывается от записи
  /// в любую таблицу: он дешёвый, в очереди считанные строки.
  Stream<(int, int)> watchVaultQueue() => customSelect(
    'SELECT count(*) AS tasks, coalesce(sum(version), 0) AS versions FROM vault_queue',
    readsFrom: allTables.toSet(),
  ).watchSingle().map((row) => (row.read<int>('tasks'), row.read<int>('versions')));

  // переименованная или переложенная папка меняет путь вещей в ней и во всех вложенных.
  // WITH в триггере SQLite не умеет: вложенные перечислены подзапросами на восемь уровней
  Future<void> _createFolderMoveTrigger() async {
    var level = 'SELECT new.id';
    final levels = [level];
    for (var depth = 0; depth < 8; depth++) {
      level = 'SELECT id FROM folders WHERE parent_id IN ($level)';
      levels.add(level);
    }
    await customStatement(
      'CREATE TRIGGER vault_folders_rename AFTER UPDATE OF name, parent_id ON folders WHEN $_notImporting BEGIN '
      "INSERT INTO vault_queue (target) SELECT 'item:' || id FROM items WHERE folder_id IN (${levels.join(' UNION ')}) $_vaultUpsert; END",
    );
  }

  // строки таблицы при вещи: любая их правка ставит в очередь вещь или её факты
  Future<void> _createChildTriggers(String table, String target) async {
    Future<void> trigger(String name, String event, String body) =>
        customStatement('CREATE TRIGGER $name AFTER $event ON $table WHEN $_notImporting BEGIN $body END');
    await trigger('vault_${table}_insert', 'INSERT', _vaultEnqueue("'$target' || new.item_id"));
    await trigger('vault_${table}_update', 'UPDATE', '${_vaultEnqueue("'$target' || old.item_id")} ${_vaultEnqueue("'$target' || new.item_id")}');
    await trigger('vault_${table}_delete', 'DELETE', _vaultEnqueue("'$target' || old.item_id"));
  }

  // любую правку, кто бы её ни сделал, ловит сама база: семьдесят мест записи в коде не трогаются
  Future<void> _createVaultTriggers() async {
    Future<void> trigger(String name, String event, String table, String body) =>
        customStatement('CREATE TRIGGER $name AFTER $event ON $table WHEN $_notImporting BEGIN $body END');

    await trigger('vault_items_insert', 'INSERT', 'items', _vaultEnqueue("'item:' || new.id"));
    await trigger('vault_items_update', 'UPDATE OF $_vaultItemColumns', 'items', _vaultEnqueue("'item:' || new.id"));
    await trigger('vault_items_delete', 'DELETE', 'items', _vaultEnqueue("'item:' || old.id"));
    // расшифровка и описание ИИ добыты платным ключом: лежат рядом с фактами
    await trigger('vault_items_derived', 'UPDATE OF transcript, ai_description', 'items', _vaultEnqueue("'facts:' || new.id"));

    // вложения, теги и цитаты — часть файла вещи; факты и прогоны — её .stowa/facts/<id>.json
    for (final (table, target) in [('attachments', 'item:'), ('item_tags', 'item:'), ('highlights', 'item:'), ('facts', 'facts:'), ('extractor_runs', 'facts:')]) {
      await _createChildTriggers(table, target);
    }

    // переименованная папка меняет путь всех своих вещей, тег — их свойство tags
    await _createFolderMoveTrigger();
    await trigger(
      'vault_tags_rename',
      'UPDATE OF name',
      'tags',
      "INSERT INTO vault_queue (target) SELECT 'item:' || item_id FROM item_tags WHERE tag_id = new.id $_vaultUpsert;",
    );

    for (final MapEntry(key: table, value: target) in _vaultMetaTables.entries) {
      for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
        await trigger('vault_${table}_${event.toLowerCase()}_meta', event, table, _vaultEnqueue("'$target'"));
      }
    }
  }

  Future<void> _createSearch() async {
    // remove_diacritics 2 делает «ё» и «е» одной буквой
    await customStatement(
      "CREATE VIRTUAL TABLE items_fts USING fts5($_ftsColumns, content='items', content_rowid='rowid', "
      "tokenize='unicode61 remove_diacritics 2')",
    );
    await customStatement(
      'CREATE TRIGGER items_fts_insert AFTER INSERT ON items BEGIN '
      'INSERT INTO items_fts(rowid, $_ftsColumns) VALUES (new.rowid, $_ftsNew); END',
    );
    await customStatement(
      'CREATE TRIGGER items_fts_delete AFTER DELETE ON items BEGIN '
      "INSERT INTO items_fts(items_fts, rowid, $_ftsColumns) VALUES ('delete', old.rowid, $_ftsOld); END",
    );
    await customStatement(
      'CREATE TRIGGER items_fts_update AFTER UPDATE ON items BEGIN '
      "INSERT INTO items_fts(items_fts, rowid, $_ftsColumns) VALUES ('delete', old.rowid, $_ftsOld); "
      'INSERT INTO items_fts(rowid, $_ftsColumns) VALUES (new.rowid, $_ftsNew); END',
    );
  }

  /// Id живых вещей по запросу FTS5, лучшие первыми.
  Future<List<String>> searchIds(String ftsMatch) async {
    final rows = await customSelect(
      'SELECT items.id FROM items_fts JOIN items ON items.rowid = items_fts.rowid '
      'WHERE items_fts MATCH ? AND items.deleted_at IS NULL ORDER BY items_fts.rank',
      variables: [Variable.withString(normalizeSearchText(ftsMatch))],
      readsFrom: {items},
    ).get();
    return [for (final row in rows) row.read<String>('id')];
  }
}
