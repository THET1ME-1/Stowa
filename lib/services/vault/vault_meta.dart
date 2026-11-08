/// Служебное хранилища в JSON: теги, правила, папки, связи, выученное, холст
/// и всё добытое о вещи. Строки таблиц пишутся как есть, читатель вставляет их обратно.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/db/database.dart';

/// Какие таблицы лежат в каком файле `.stowa/<имя>.json`.
const vaultMetaTables = {
  'folders': ['folders'],
  'tags': ['tags'],
  'rules': ['rules'],
  'links': ['links'],
  'learned': ['word_stats', 'corrections'],
  'canvas': ['canvas_positions'],
  'places': ['places'],
};

const _pretty = JsonEncoder.withIndent('  ');

Future<List<Map<String, Object?>>> _rows(AppDatabase db, String sql, [List<Variable<Object>> variables = const []]) async =>
    [for (final row in await db.customSelect(sql, variables: variables).get()) row.data];

/// Текст `.stowa/<name>.json`: `{"<таблица>": [строки]}`.
Future<String> metaJson(AppDatabase db, String name) async {
  final tables = vaultMetaTables[name]!;
  return _pretty.convert({for (final table in tables) table: await _rows(db, 'SELECT * FROM $table')});
}

/// Текст `.stowa/history/<id>.json` или null, если снимков нет.
Future<String?> historyJson(AppDatabase db, String itemId) async {
  final versions = await _rows(db, 'SELECT * FROM note_versions WHERE item_id = ? ORDER BY saved_at', [Variable.withString(itemId)]);
  return versions.isEmpty ? null : _pretty.convert({'versions': versions});
}

/// Текст `.stowa/facts/<id>.json` или null, если добытого нет и файл не нужен.
/// Прогоны извлекателей идут вместе с фактами: после переустановки конвейер не переделывает добытое.
Future<String?> factsJson(AppDatabase db, String itemId) async {
  final item = await (db.select(db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
  if (item == null) return null;
  final facts = await _rows(db, 'SELECT * FROM facts WHERE item_id = ? ORDER BY extractor, position', [Variable.withString(itemId)]);
  final runs = await _rows(db, 'SELECT * FROM extractor_runs WHERE item_id = ? ORDER BY extractor', [Variable.withString(itemId)]);
  if (facts.isEmpty && runs.isEmpty && item.transcript == null && item.aiDescription == null) return null;
  return _pretty.convert({
    'facts': facts,
    'runs': runs,
    'transcript': ?item.transcript,
    'ai_description': ?item.aiDescription,
  });
}
