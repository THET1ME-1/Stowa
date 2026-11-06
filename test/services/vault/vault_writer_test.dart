import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/vault_note.dart';
import 'package:stowa/services/vault/vault_writer.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  final now = DateTime(2026, 11, 6, 10);

  setUp(() async {
    db = AppDatabase.memory();
    root = Directory.systemTemp.createTempSync('stowa_vault');
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'recipes', name: 'Рецепты', icon: 'restaurant', shape: 'pill'));
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'food', name: 'Еда', icon: 'folder', shape: 'pill'));
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  VaultWriter writer({Future<void> Function(File temp, File target)? commit}) => VaultWriter(db, root: root, clock: () => now, commit: commit);
  Future<void> note(String id, String title, {String? folder, String? body}) => db
      .into(db.items)
      .insert(ItemsCompanion.insert(id: id, kind: ItemKind.note, title: title, body: Value(body ?? title), folderId: Value(folder), createdAt: now, updatedAt: now));
  Future<void> edit(String id, ItemsCompanion change) => (db.update(db.items)..where((t) => t.id.equals(id))).write(change);
  File file(String relative) => File(p.join(root.path, relative));
  Future<String?> pathOf(String id) async => (await (db.select(db.vaultFiles)..where((t) => t.itemId.equals(id))).getSingleOrNull())?.path;
  Future<List<String>> queue() async => [for (final row in await db.select(db.vaultQueue).get()) row.target];

  test('новая заметка появляется файлом в своей папке, с тегами; очередь пустая', () async {
    await note('a', 'Карбонара', folder: 'recipes', body: 'Карбонара\nгуанчиале');
    await db.into(db.tags).insert(TagsCompanion.insert(id: 't', name: 'паста', createdAt: now));
    await db.into(db.itemTags).insert(ItemTagsCompanion.insert(itemId: 'a', tagId: 't', source: TagSource.user));
    await writer().drain();
    final text = file('Рецепты/Карбонара.md').readAsStringSync();
    final back = readVaultNote(text, fileName: 'Карбонара.md', fileModified: now);
    expect(back.id, 'a');
    expect(back.body, 'Карбонара\nгуанчиале');
    expect(back.tags, ['паста']);
    expect(await pathOf('a'), 'Рецепты/Карбонара.md');
    expect(await queue(), isEmpty);
  });

  test('перенос в другую папку переносит файл и вложения, пути в базе обновлены', () async {
    await note('a', 'Карбонара', folder: 'recipes');
    file('Рецепты/Карбонара/фото.jpg')
      ..createSync(recursive: true)
      ..writeAsStringSync('jpeg');
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'p', itemId: 'a', path: 'Рецепты/Карбонара/фото.jpg', mime: 'image/jpeg', size: 4));
    await writer().drain();
    await edit('a', const ItemsCompanion(folderId: Value('food')));
    await writer().drain();
    expect(file('Еда/Карбонара.md').existsSync(), isTrue);
    expect(file('Еда/Карбонара/фото.jpg').readAsStringSync(), 'jpeg');
    expect(Directory(p.join(root.path, 'Рецепты')).existsSync(), isFalse, reason: 'пустая старая папка убрана');
    expect((await db.select(db.attachments).getSingle()).path, 'Еда/Карбонара/фото.jpg');
    expect(file('Еда/Карбонара.md').readAsStringSync(), contains('![[Еда/Карбонара/фото.jpg]]'));
    expect(await queue(), isEmpty, reason: 'правка путей вложений не встаёт в очередь снова');
  });

  test('вложения из входящих и старой папки переезжают к заметке под своим именем, без номера и без затирания', () async {
    await note('a', 'Карбонара', folder: 'recipes');
    for (final (id, path, position) in [('p1', '.stowa/incoming/a/0_фото.jpg', 0), ('p2', 'attachments/a/1_фото.jpg', 1)]) {
      file(path)
        ..createSync(recursive: true)
        ..writeAsStringSync(id);
      await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: id, itemId: 'a', path: path, mime: 'image/jpeg', size: 2, position: Value(position)));
    }
    await writer().drain();
    final paths = [for (final row in await (db.select(db.attachments)..orderBy([(t) => OrderingTerm.asc(t.position)])).get()) row.path];
    expect(paths, ['Рецепты/Карбонара/фото.jpg', 'Рецепты/Карбонара/фото 2.jpg']);
    expect(file('Рецепты/Карбонара/фото.jpg').readAsStringSync(), 'p1');
    expect(file('Рецепты/Карбонара/фото 2.jpg').readAsStringSync(), 'p2');
    expect(Directory(p.join(root.path, '.stowa', 'incoming', 'a')).existsSync(), isFalse);
    expect(await queue(), isEmpty);
  });

  test('переименование папки переносит её вещи', () async {
    await note('a', 'Карбонара', folder: 'recipes');
    await writer().drain();
    await (db.update(db.folders)..where((t) => t.id.equals('recipes'))).write(const FoldersCompanion(name: Value('Паста')));
    await writer().drain();
    expect(file('Паста/Карбонара.md').existsSync(), isTrue);
    expect(Directory(p.join(root.path, 'Рецепты')).existsSync(), isFalse);
  });

  test('одинаковые заголовки — «… 2.md»; смена заголовка переименовывает файл, повторная запись имён не меняет', () async {
    await note('a', 'Купить молоко');
    await note('b', 'Купить молоко');
    await writer().drain();
    expect({await pathOf('a'), await pathOf('b')}, {'Купить молоко.md', 'Купить молоко 2.md'});
    final second = (await pathOf('a')) == 'Купить молоко.md' ? 'b' : 'a';
    await edit(second, const ItemsCompanion(body: Value('Купить молоко\nи хлеб')));
    await writer().drain();
    expect(await pathOf(second), 'Купить молоко 2.md', reason: 'номер остаётся, файл не прыгает');
    await edit(second, const ItemsCompanion(title: Value('Купить хлеб')));
    await writer().drain();
    expect(await pathOf(second), 'Купить хлеб.md');
    expect(file('Купить молоко 2.md').existsSync(), isFalse);
  });

  test('обрыв посреди записи: на диске старый целый файл, задача в очереди, следующий проход дописывает', () async {
    await note('a', 'Идеи', body: 'Идеи\nпервая');
    await writer().drain();
    await edit('a', const ItemsCompanion(body: Value('Идеи\nвторая')));
    await writer(commit: (temp, target) async => throw const FileSystemException('телефон выключился')).drain();
    expect(file('Идеи.md').readAsStringSync(), contains('первая'));
    expect(await queue(), ['item:a']);
    await writer().drain();
    expect(file('Идеи.md').readAsStringSync(), contains('вторая'));
    expect(root.listSync().whereType<File>().map((f) => p.basename(f.path)), ['Идеи.md'], reason: 'временного файла не осталось');
  });

  test('удалённая вещь уезжает в .trash, возвращённая — обратно, стёртая — пропадает', () async {
    await note('a', 'Карбонара', folder: 'recipes');
    await writer().drain();
    await edit('a', ItemsCompanion(deletedAt: Value(now)));
    await writer().drain();
    expect(file('.trash/Рецепты/Карбонара.md').existsSync(), isTrue);
    expect(file('Рецепты/Карбонара.md').existsSync(), isFalse);
    await edit('a', const ItemsCompanion(deletedAt: Value(null)));
    await writer().drain();
    expect(file('Рецепты/Карбонара.md').existsSync(), isTrue);
    await (db.delete(db.items)..where((t) => t.id.equals('a'))).go();
    await writer().drain();
    expect(file('Рецепты/Карбонара.md').existsSync(), isFalse);
    expect(await pathOf('a'), isNull);
  });

  test('факты, прогоны, расшифровка и описание ИИ — в .stowa/facts/<id>.json', () async {
    await note('a', 'Голосовое');
    await edit('a', const ItemsCompanion(transcript: Value('купить плитку'), aiDescription: Value('Список для ремонта')));
    await db.into(db.facts).insert(FactsCompanion.insert(id: 'x', itemId: 'a', extractor: 'text', kind: FactKind.price, value: '5 лей', number: const Value(5)));
    await db.into(db.extractorRuns).insert(ExtractorRunsCompanion.insert(itemId: 'a', extractor: 'text', version: 2, itemStamp: const Value('s')));
    await writer().drain();
    final json = jsonDecode(file('.stowa/facts/a.json').readAsStringSync()) as Map<String, Object?>;
    expect(json['transcript'], 'купить плитку');
    expect(json['ai_description'], 'Список для ремонта');
    expect((json['facts'] as List).single, containsPair('value', '5 лей'));
    expect((json['runs'] as List).single, containsPair('version', 2));
  });

  test('теги, правила, папки, связи, выученное и холст — в .stowa/*.json', () async {
    await db.into(db.tags).insert(TagsCompanion.insert(id: 't', name: 'паста', createdAt: now));
    await db.into(db.rules).insert(RulesCompanion.insert(id: 'r', conditionKind: RuleConditionKind.hasTag, conditionValue: 'паста', actionKind: RuleActionKind.toFolder, actionValue: 'recipes'));
    await db.into(db.wordStats).insert(WordStatsCompanion.insert(word: 'паст', targetKind: 'folder', targetId: 'recipes'));
    await db.into(db.links).insert(LinksCompanion.insert(fromId: 'a', toId: 'b', source: LinkSource.values.first, rejected: const Value(true)));
    await db.into(db.canvasPositions).insert(CanvasPositionsCompanion.insert(folderId: 'recipes', itemId: 'a', x: 10, y: 20, width: 160));
    await writer().drain();
    List<Object?> rows(String name) => (jsonDecode(file('.stowa/$name.json').readAsStringSync()) as Map)[name] as List;
    expect(rows('tags').single, containsPair('name', 'паста'));
    expect(rows('rules').single, containsPair('condition_value', 'паста'));
    expect(rows('folders').map((row) => (row as Map)['name']), containsAll(['Рецепты', 'Еда']));
    expect(file('.stowa/learned.json').existsSync(), isTrue);
    expect(file('.stowa/links.json').existsSync(), isTrue);
    expect(file('.stowa/canvas.json').existsSync(), isTrue);
  });

  test('чужая аренда: задачу, занятую другим писателем, не берём', () async {
    await note('a', 'Идеи');
    await (db.update(db.vaultQueue)..where((t) => t.target.equals('item:a'))).write(VaultQueueCompanion(claimedUntil: Value(now.millisecondsSinceEpoch + 15000)));
    await writer().drain();
    expect(file('Идеи.md').existsSync(), isFalse);
    expect(await queue(), contains('item:a'));
  });

  test('хранилище не выбрано — ничего не пишет, очередь ждёт', () async {
    await note('a', 'Идеи');
    expect(await VaultWriter(db, root: null, clock: () => now).drain(), 0);
    expect(await queue(), contains('item:a'));
  });
}
