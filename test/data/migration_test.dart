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

  test('v7 → v8: заметки на месте, есть места и напоминание по месту, правка места ставит заметку в очередь', () async {
    final dir = Directory.systemTemp.createTempSync('stowa_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/stowa.sqlite');
    final now = DateTime(2026, 11, 6);

    final fresh = AppDatabase(NativeDatabase(file));
    await fresh.into(fresh.items).insert(ItemsCompanion.insert(id: 'old', kind: ItemKind.note, title: 'Кофе', createdAt: now, updatedAt: now));
    await fresh.close();
    final raw = sqlite3.open(file.path);
    _dropPlaces(raw);
    raw.execute('PRAGMA user_version = 7');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect((await upgraded.select(upgraded.items).getSingle()).title, 'Кофе');
    await upgraded.delete(upgraded.vaultQueue).go();
    await (upgraded.update(upgraded.items)..where((t) => t.id.equals('old'))).write(const ItemsCompanion(remindPlace: Value(PlaceReminderKind.work)));
    expect([for (final row in await upgraded.select(upgraded.vaultQueue).get()) row.target], ['item:old']);
    await upgraded.into(upgraded.places).insert(PlacesCompanion.insert(id: 'h', kind: PlaceKind.home, name: 'Дом', latitude: 47, longitude: 28, createdAt: now));
    expect(await upgraded.select(upgraded.places).get(), hasLength(1));
  });

  test('v8 → v9: папки на месте без цвета, выбранный цвет пишется и уходит в хранилище', () async {
    final dir = Directory.systemTemp.createTempSync('stowa_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/stowa.sqlite');

    final fresh = AppDatabase(NativeDatabase(file));
    await fresh.into(fresh.folders).insert(FoldersCompanion.insert(id: 'f', name: 'Рецепты', icon: 'folder', shape: 'pill'));
    await fresh.close();
    final raw = sqlite3.open(file.path);
    _dropFolderColor(raw);
    raw.execute('PRAGMA user_version = 8');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final folder = await upgraded.select(upgraded.folders).getSingle();
    expect(folder.name, 'Рецепты');
    expect(folder.color, isNull);
    await upgraded.delete(upgraded.vaultQueue).go();
    await (upgraded.update(upgraded.folders)..where((t) => t.id.equals('f'))).write(const FoldersCompanion(color: Value('mint')));
    expect((await upgraded.select(upgraded.folders).getSingle()).color, 'mint');
    expect([for (final row in await upgraded.select(upgraded.vaultQueue).get()) row.target], ['meta:folders']);
  });

  test('v9 → v10: ссылки на месте, цитата ставит заметку в очередь, след чтения и проверки — нет', () async {
    final dir = Directory.systemTemp.createTempSync('stowa_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/stowa.sqlite');
    final now = DateTime(2026, 11, 7);

    final fresh = AppDatabase(NativeDatabase(file));
    await fresh.into(fresh.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.link, title: 'Статья', url: const Value('https://blog.example.com/a'), createdAt: now, updatedAt: now));
    await fresh.close();
    final raw = sqlite3.open(file.path);
    _dropArticles(raw);
    raw.execute('PRAGMA user_version = 9');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final item = await upgraded.select(upgraded.items).getSingle();
    expect(item.goneAt, isNull);
    expect(item.goneKept, isFalse);
    expect(item.readPosition, isNull);
    await upgraded.delete(upgraded.vaultQueue).go();
    await (upgraded.update(upgraded.items)..where((t) => t.id.equals('a'))).write(ItemsCompanion(readPosition: const Value(0.4), goneAt: Value(now), linkCheckedAt: Value(now)));
    expect(await upgraded.select(upgraded.vaultQueue).get(), isEmpty);
    await upgraded.into(upgraded.highlights).insert(HighlightsCompanion.insert(id: 'h', itemId: 'a', quote: 'вода важнее зёрен', createdAt: now));
    expect([for (final row in await upgraded.select(upgraded.vaultQueue).get()) row.target], ['item:a']);
  });

  test('v10 → v11: папки верхние, перенос папки ставит в очередь заметки её и вложенных', () async {
    final dir = Directory.systemTemp.createTempSync('stowa_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/stowa.sqlite');
    final now = DateTime(2026, 11, 8);

    final fresh = AppDatabase(NativeDatabase(file));
    for (final (id, name) in [('home', 'Дом'), ('fix', 'Ремонт'), ('kitchen', 'Кухня')]) {
      await fresh.into(fresh.folders).insert(FoldersCompanion.insert(id: id, name: name, icon: 'folder', shape: 'pill'));
    }
    await fresh.into(fresh.items).insert(ItemsCompanion.insert(id: 'tile', kind: ItemKind.note, title: 'Плитка', folderId: const Value('kitchen'), createdAt: now, updatedAt: now));
    await fresh.into(fresh.items).insert(ItemsCompanion.insert(id: 'other', kind: ItemKind.note, title: 'Другое', folderId: const Value('home'), createdAt: now, updatedAt: now));
    await fresh.close();
    final raw = sqlite3.open(file.path);
    _dropNesting(raw);
    raw.execute("CREATE TRIGGER vault_folders_rename AFTER UPDATE OF name ON folders BEGIN SELECT 1; END");
    raw.execute('PRAGMA user_version = 10');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect([for (final folder in await upgraded.select(upgraded.folders).get()) folder.parentId], [null, null, null]);
    await (upgraded.update(upgraded.folders)..where((t) => t.id.equals('kitchen'))).write(const FoldersCompanion(parentId: Value('fix')));
    await upgraded.delete(upgraded.vaultQueue).go();
    await (upgraded.update(upgraded.folders)..where((t) => t.id.equals('fix'))).write(const FoldersCompanion(parentId: Value('home')));
    expect({for (final row in await upgraded.select(upgraded.vaultQueue).get()) row.target}, {'item:tile', 'meta:folders'});
  });

  test('v11 → v12: заметки на месте, правка после перерыва даёт снимок', () async {
    final dir = Directory.systemTemp.createTempSync('stowa_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/stowa.sqlite');
    final now = DateTime(2026, 11, 8);

    final fresh = AppDatabase(NativeDatabase(file));
    await fresh.into(fresh.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Плитка', body: const Value('Плитка\n20×20'), createdAt: now, updatedAt: now));
    await fresh.close();
    final raw = sqlite3.open(file.path);
    _dropHistory(raw);
    raw.execute('PRAGMA user_version = 11');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await (upgraded.update(upgraded.items)..where((t) => t.id.equals('a'))).write(ItemsCompanion(body: const Value('Плитка\n30×30'), updatedAt: Value(now.add(const Duration(hours: 1)))));
    expect((await upgraded.select(upgraded.noteVersions).getSingle()).body, 'Плитка\n20×20');
  });

  test('v6 → v7: первая строка, которую правка унесла в заголовок, вернулась в текст заметки', () async {
    final dir = Directory.systemTemp.createTempSync('stowa_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/stowa.sqlite');
    final now = DateTime(2026, 11, 6);

    final fresh = AppDatabase(NativeDatabase(file));
    await fresh.into(fresh.items).insert(ItemsCompanion.insert(id: 'recipe', kind: ItemKind.note, title: 'Борщ', body: const Value('Свёкла 2 шт'), createdAt: now, updatedAt: now));
    await fresh.into(fresh.items).insert(ItemsCompanion.insert(id: 'whole', kind: ItemKind.note, title: 'Плов', body: const Value('Плов\nРис 300 г'), createdAt: now, updatedAt: now));
    // у ссылки заголовок от сайта, в тексте его и не было
    await fresh.into(fresh.items).insert(ItemsCompanion.insert(id: 'link', kind: ItemKind.link, title: 'Кофе в турке', body: const Value('https://coffee.ru/turka'), createdAt: now, updatedAt: now));
    await fresh.close();
    final raw = sqlite3.open(file.path);
    _dropVault(raw);
    raw.execute('PRAGMA user_version = 6');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final bodies = {for (final item in await upgraded.select(upgraded.items).get()) item.id: item.body};
    expect(bodies, {'recipe': 'Борщ\nСвёкла 2 шт', 'whole': 'Плов\nРис 300 г', 'link': 'https://coffee.ru/turka'});
  });
}

// версия 10: статьи — цитаты, жива ли ссылка, где остановился читать
// версия 11: папка в папке. Триггер переименования смотрит на parent_id, уходит первым
// версия 12: история правок
void _dropHistory(Database raw) {
  for (final trigger in ['items_history', 'items_history_purge', 'vault_note_versions_insert', 'vault_note_versions_delete']) {
    raw.execute('DROP TRIGGER IF EXISTS $trigger');
  }
  raw.execute('DROP TABLE IF EXISTS note_versions');
}

void _dropNesting(Database raw) {
  _dropHistory(raw);
  raw.execute('DROP TRIGGER IF EXISTS vault_folders_rename');
  raw.execute('ALTER TABLE folders DROP COLUMN parent_id');
}

void _dropArticles(Database raw) {
  _dropNesting(raw);
  for (final row in raw.select("SELECT name FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'vault_highlights_%'")) {
    raw.execute('DROP TRIGGER ${row['name']}');
  }
  raw.execute('DROP TABLE IF EXISTS highlights');
  for (final column in ['gone_at', 'gone_kept', 'link_checked_at', 'read_position']) {
    raw.execute('ALTER TABLE items DROP COLUMN $column');
  }
}

// версия 9: цвет папки
void _dropFolderColor(Database raw) {
  _dropArticles(raw);
  raw.execute('ALTER TABLE folders DROP COLUMN color');
}

// версия 8: открыта ли заметка, напоминание по месту и места. Триггер правки заметки
// ссылается на поля — без него их можно убрать, миграция ставит его заново
void _dropPlaces(Database raw) {
  _dropFolderColor(raw);
  for (final row in raw.select("SELECT name FROM sqlite_master WHERE type = 'trigger' AND (name LIKE 'vault_places_%' OR name = 'vault_items_update')")) {
    raw.execute('DROP TRIGGER ${row['name']}');
  }
  for (final column in ['opened_at', 'remind_place', 'remind_latitude', 'remind_longitude', 'remind_place_name']) {
    raw.execute('ALTER TABLE items DROP COLUMN $column');
  }
  raw.execute('DROP TABLE IF EXISTS places');
}

// очередь хранилища и её триггеры появились в версии 7
void _dropVault(Database raw) {
  _dropPlaces(raw);
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
