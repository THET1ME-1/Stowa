import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

@DriftDatabase(tables: [Items, Attachments, FileJobs, Facts, ExtractorRuns, Folders, Tags, ItemTags, Rules, Links, AiJobs, AiLog, WordStats, Corrections, CanvasPositions])
class AppDatabase extends _$AppDatabase {
  // одна база на процесс: кнопки уведомлений пишут из фонового Dart, и ленты приложения это видят
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'stowa', native: const DriftNativeOptions(shareAcrossIsolates: true)));

  /// База в памяти для тестов. Стримы закрываются сразу: иначе drift ждёт
  /// оборот цикла событий, а часы теста поддельные, и закрытие виснет.
  AppDatabase.memory() : super(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createSearch();
      await _createFactIndexes();
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
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // факты вещи — по вещи; суммы для «до 500 лей» — по виду и числу
  Future<void> _createFactIndexes() async {
    await customStatement('CREATE INDEX IF NOT EXISTS facts_item ON facts (item_id, extractor)');
    await customStatement('CREATE INDEX IF NOT EXISTS facts_kind ON facts (kind, number)');
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
