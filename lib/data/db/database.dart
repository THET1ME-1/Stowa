import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/models.dart';
import 'tables.dart';

part 'database.g.dart';

// поля, которые ищутся
const _ftsColumns = 'title, body, ai_description, transcript, url';
const _ftsSource = ['title', 'body', 'ai_description', 'transcript', 'url'];

// unicode61 не снимает точки с «ё», поэтому индекс получает «е»; NULL — пустая
// строка, одинаково при записи и при удалении из индекса
String _ftsValues(String row) => _ftsSource
    .map((column) => "replace(replace(coalesce($row.$column, ''), 'ё', 'е'), 'Ё', 'Е')")
    .join(', ');

final _ftsNew = _ftsValues('new');
final _ftsOld = _ftsValues('old');

/// Запрос к индексу с той же заменой «ё», что и в самом индексе.
String normalizeSearchText(String text) => text.replaceAll('ё', 'е').replaceAll('Ё', 'Е');

@DriftDatabase(
  tables: [Items, Attachments, Folders, Tags, ItemTags, Rules, Links, AiJobs, AiLog, WordStats, Corrections, CanvasPositions],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'stowa'));

  /// База в памяти для тестов. Стримы закрываются сразу: иначе drift ждёт
  /// оборот цикла событий, а часы теста поддельные, и закрытие виснет.
  AppDatabase.memory() : super(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
          await _createSearch();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

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
