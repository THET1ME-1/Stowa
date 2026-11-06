import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';

void main() {
  test('база версии 1 открывается: поля превью добавлены, вещи на месте', () async {
    final dir = Directory.systemTemp.createTempSync('stowa_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/stowa.sqlite');
    final now = DateTime(2026, 11, 3);

    // новая база, из которой убраны поля версии 2 — так выглядит база с телефона до обновления
    final fresh = AppDatabase(NativeDatabase(file));
    await fresh.into(fresh.items).insert(ItemsCompanion.insert(id: 'old', kind: ItemKind.link, title: 'Старая', url: const Value('https://a.b'), createdAt: now, updatedAt: now));
    await fresh.close();
    final raw = sqlite3.open(file.path);
    _dropSearch(raw);
    for (final column in ['cover_path', 'preview_text', 'preview_site', 'preview_author', 'duration_seconds', 'preview_at']) {
      raw.execute('ALTER TABLE items DROP COLUMN $column');
    }
    for (final column in ['latitude', 'longitude', 'place_name']) {
      raw.execute('ALTER TABLE items DROP COLUMN $column');
    }
    raw.execute('PRAGMA user_version = 1');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final old = await upgraded.select(upgraded.items).getSingle();
    expect(old.title, 'Старая');
    expect(old.previewAt, isNull);
    await (upgraded.update(upgraded.items)..where((t) => t.id.equals('old'))).write(const ItemsCompanion(previewSite: Value('a.b')));
    expect((await upgraded.select(upgraded.items).getSingle()).previewSite, 'a.b');
  });

  test('база версии 2 открывается: у вещей появилось место', () async {
    final dir = Directory.systemTemp.createTempSync('stowa_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/stowa.sqlite');
    final now = DateTime(2026, 11, 3);

    final fresh = AppDatabase(NativeDatabase(file));
    await fresh.into(fresh.items).insert(ItemsCompanion.insert(id: 'old', kind: ItemKind.note, title: 'Старая', createdAt: now, updatedAt: now));
    await fresh.close();
    final raw = sqlite3.open(file.path);
    _dropSearch(raw);
    for (final column in ['latitude', 'longitude', 'place_name']) {
      raw.execute('ALTER TABLE items DROP COLUMN $column');
    }
    raw.execute('PRAGMA user_version = 2');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await (upgraded.update(upgraded.items)..where((t) => t.id.equals('old'))).write(
      const ItemsCompanion(latitude: Value(47.02), longitude: Value(28.83), placeName: Value('Кишинёв')),
    );
    final old = await upgraded.select(upgraded.items).getSingle();
    expect(old.title, 'Старая');
    expect(old.placeName, 'Кишинёв');
  });

  test('база версии 3: индекс строится заново, ищется по месту и по «ł»', () async {
    final dir = Directory.systemTemp.createTempSync('stowa_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/stowa.sqlite');
    final now = DateTime(2026, 11, 3);

    // индекс версии 3: без места и без замены «ł»
    final fresh = AppDatabase(NativeDatabase(file));
    await fresh.customSelect('SELECT 1').get();
    await fresh.close();
    final raw = sqlite3.open(file.path);
    _dropSearch(raw);
    const columns = 'title, body, ai_description, transcript, url';
    String values(String row) => columns.split(', ').map((column) => "replace(replace(coalesce($row.$column, ''), 'ё', 'е'), 'Ё', 'Е')").join(', ');
    raw.execute("CREATE VIRTUAL TABLE items_fts USING fts5($columns, content='items', content_rowid='rowid', tokenize='unicode61 remove_diacritics 2')");
    raw.execute('CREATE TRIGGER items_fts_insert AFTER INSERT ON items BEGIN INSERT INTO items_fts(rowid, $columns) VALUES (new.rowid, ${values('new')}); END');
    raw.execute(
      "INSERT INTO items (id, kind, title, body, place_name, sort_state, sorted_by, created_at, updated_at) VALUES "
      "('old', 'note', 'Łódź', '', 'Кишинёв', 'pending', 'none', '${now.toIso8601String()}', '${now.toIso8601String()}')",
    );
    raw.execute('PRAGMA user_version = 3');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect(await upgraded.searchIds('"кишинев"*'), ['old']);
    expect(await upgraded.searchIds('"lodz"*'), ['old']);
    // текст фактов ищется вместе с вещью
    await upgraded.customStatement("UPDATE items SET facts_text = 'договор аренды квартиры' WHERE id = 'old'");
    expect(await upgraded.searchIds('"аренд"*'), ['old']);
    expect(await upgraded.select(upgraded.facts).get(), isEmpty);
  });

  test('v6 → v7: вещи на месте, все вещи и meta:* стоят в очереди записи', () async {
    final dir = Directory.systemTemp.createTempSync('stowa_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/stowa.sqlite');
    final now = DateTime(2026, 11, 6);

    final fresh = AppDatabase(NativeDatabase(file));
    await fresh.into(fresh.folders).insert(FoldersCompanion.insert(id: 'f', name: 'Рецепты', icon: 'folder', shape: 'pill'));
    await fresh.into(fresh.items).insert(ItemsCompanion.insert(id: 'old', kind: ItemKind.note, title: 'Старая', folderId: const Value('f'), createdAt: now, updatedAt: now));
    await fresh.close();
    final raw = sqlite3.open(file.path);
    _dropVault(raw);
    raw.execute('PRAGMA user_version = 6');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect((await upgraded.select(upgraded.items).getSingle()).title, 'Старая');
    final queued = {for (final row in await upgraded.select(upgraded.vaultQueue).get()) row.target};
    expect(queued, containsAll(['item:old', 'facts:old', 'meta:folders', 'meta:tags', 'meta:rules', 'meta:links', 'meta:learned', 'meta:canvas']));
  });
}

// очередь хранилища и её триггеры появились в версии 7
void _dropVault(Database raw) {
  for (final row in raw.select("SELECT name FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'vault_%'")) {
    raw.execute('DROP TRIGGER ${row['name']}');
  }
  for (final table in ['vault_queue', 'vault_files', 'vault_flags']) {
    raw.execute('DROP TABLE IF EXISTS $table');
  }
}

// триггеры индекса ссылаются на поля: без них поля можно убрать, а миграция строит индекс заново.
// Заодно убирается то, чего до версии 6 не было: факты и их текст
void _dropSearch(Database raw) {
  _dropVault(raw);
  for (final trigger in ['items_fts_insert', 'items_fts_delete', 'items_fts_update']) {
    raw.execute('DROP TRIGGER IF EXISTS $trigger');
  }
  raw.execute('DROP TABLE IF EXISTS items_fts');
  raw.execute('DROP TABLE IF EXISTS facts');
  raw.execute('DROP TABLE IF EXISTS extractor_runs');
  raw.execute('ALTER TABLE items DROP COLUMN facts_text');
}
