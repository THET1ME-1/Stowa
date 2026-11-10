import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/privacy/hidden_rows.dart';
import 'package:stowa/services/vault/vault_meta.dart';

void main() {
  const open = '/data/user/0/app.stowa/files/sealed-open';
  final now = DateTime(2026, 11, 10, 12);
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    Future<void> folder(String id, String name, {String? parent, bool hidden = false}) =>
        db.into(db.folders).insert(FoldersCompanion.insert(id: id, name: name, icon: 'folder', shape: 'gem', parentId: Value(parent), hidden: Value(hidden)));
    Future<void> item(String id, String title, String? folder, String body) => db.into(db.items).insert(
      ItemsCompanion.insert(id: id, kind: ItemKind.note, title: title, body: Value(body), folderId: Value(folder), createdAt: now, updatedAt: now),
    );
    await folder('home', 'Дом');
    await folder('secret', 'Секрет', hidden: true);
    await folder('deep', 'Глубже', parent: 'secret', hidden: true);
    await item('a', 'Лампочки', 'home', 'купить лампочки');
    await item('b', 'План', 'secret', 'план побега через окно');
    await item('c', 'Шифр', 'deep', 'ключ под ковриком');
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'att', itemId: 'b', path: '$open/files/b/карта.jpg', mime: 'image/jpeg', size: 10));
    await (db.update(db.items)..where((t) => t.id.equals('b'))).write(const ItemsCompanion(coverPath: Value('$open/.stowa/covers/b.jpg')));
    for (final (id, name) in [('t1', 'общий'), ('t2', 'тайный')]) {
      await db.into(db.tags).insert(TagsCompanion.insert(id: id, name: name, createdAt: now));
    }
    for (final (item, tag) in [('a', 't1'), ('b', 't1'), ('b', 't2')]) {
      await db.into(db.itemTags).insert(ItemTagsCompanion.insert(itemId: item, tagId: tag, source: TagSource.user));
    }
    await db.into(db.links).insert(LinksCompanion.insert(fromId: 'a', toId: 'b', source: LinkSource.manual));
    await db.into(db.rules).insert(
      RulesCompanion.insert(id: 'r1', conditionKind: RuleConditionKind.hasTag, conditionValue: 'тайный', actionKind: RuleActionKind.toFolder, actionValue: 'secret'),
    );
    await db.into(db.rules).insert(
      RulesCompanion.insert(id: 'r2', conditionKind: RuleConditionKind.hasTag, conditionValue: 'общий', actionKind: RuleActionKind.toFolder, actionValue: 'home'),
    );
    await db.into(db.corrections).insert(CorrectionsCompanion.insert(id: 'k', itemId: 'b', fromFolderId: const Value(null), toFolderId: 'secret', at: now));
    await db.into(db.canvasPositions).insert(CanvasPositionsCompanion.insert(folderId: 'secret', itemId: 'b', x: 1, y: 2, width: 3));
    await db.into(db.highlights).insert(HighlightsCompanion.insert(id: 'h', itemId: 'b', quote: 'через окно', createdAt: now));
    await db.into(db.noteVersions).insert(NoteVersionsCompanion.insert(id: 'v', itemId: 'b', title: 'План', body: 'план побега', savedAt: now));
    await db.into(db.aiLog).insert(AiLogCompanion.insert(at: now, itemId: const Value('b'), request: 'разложи «план побега»'));
    await db.into(db.aiLog).insert(AiLogCompanion.insert(at: now, itemId: const Value('a'), request: 'разложи лампочки'));
  });
  tearDown(() => db.close());

  Future<List<String>> found(String word) => db.searchIds(word);

  test('скрытые папки и заметки — с вложенной, остальное не скрыто', () async {
    expect(await hiddenFolderIds(db), {'secret', 'deep'});
    expect(await hiddenItemIds(db), {'b', 'c'});
  });

  test('выгрузка, стирание и возврат: база снова та же, поиск снова находит', () async {
    final dump = await dumpHidden(db, openRoot: open);
    // пути открытой папки — меткой: после переустановки папка приложения может стать другой
    expect(jsonEncode(dump).contains(open), isFalse);
    expect(await found('побега'), ['b']);

    await db.delete(db.vaultQueue).go();
    await deleteHidden(db);
    expect(await found('побега'), isEmpty);
    expect(await found('ковриком'), isEmpty);
    expect([for (final row in await db.select(db.folders).get()) row.id], ['home']);
    expect([for (final row in await db.select(db.tags).get()) row.name], ['общий']);
    expect(await db.select(db.links).get(), isEmpty);
    expect([for (final row in await db.select(db.rules).get()) row.id], ['r2']);
    expect(await db.select(db.attachments).get(), isEmpty);
    expect(await db.select(db.highlights).get(), isEmpty);
    expect(await db.select(db.noteVersions).get(), isEmpty);
    expect(await db.select(db.corrections).get(), isEmpty);
    expect(await db.select(db.canvasPositions).get(), isEmpty);
    expect([for (final row in await db.select(db.aiLog).get()) row.itemId], ['a']);
    // стирание тихое: писатель хранилища ничего не трогает
    expect(await db.select(db.vaultQueue).get(), isEmpty);

    await restoreHidden(db, dump, openRoot: open);
    expect(await found('побега'), ['b']);
    expect(await found('ковриком'), ['c']);
    final again = await dumpHidden(db, openRoot: open);
    expect(_withoutLogIds(again), _withoutLogIds(dump));
    expect((await (db.select(db.items)..where((t) => t.id.equals('b'))).getSingle()).coverPath, '$open/.stowa/covers/b.jpg');
    expect((await db.select(db.attachments).getSingle()).path, '$open/files/b/карта.jpg');
    expect(await db.select(db.vaultQueue).get(), isEmpty);
  });

  test('общий тег стёрли, пока скрытое было закрыто, — вернётся; тег с тем же именем — тот же', () async {
    final dump = await dumpHidden(db, openRoot: open);
    await deleteHidden(db);
    await (db.delete(db.itemTags)..where((t) => t.tagId.equals('t1'))).go();
    await (db.delete(db.tags)..where((t) => t.id.equals('t1'))).go();
    await db.into(db.tags).insert(TagsCompanion.insert(id: 't9', name: 'тайный', createdAt: now));

    await restoreHidden(db, dump, openRoot: open);
    final tags = {for (final row in await db.select(db.tags).get()) row.id: row.name};
    expect(tags, {'t1': 'общий', 't9': 'тайный'});
    expect({for (final row in await (db.select(db.itemTags)..where((t) => t.itemId.equals('b'))).get()) row.tagId}, {'t1', 't9'});
  });

  test('служебное хранилища пишется без скрытого', () async {
    expect(await metaJson(db, 'folders'), isNot(contains('Секрет')));
    expect(await metaJson(db, 'folders'), contains('Дом'));
    final tags = await metaJson(db, 'tags');
    expect(tags, contains('общий'));
    expect(tags, isNot(contains('тайный')));
    expect(await metaJson(db, 'links'), isNot(contains('"b"')));
    expect(await metaJson(db, 'rules'), isNot(contains('r1')));
    expect(await metaJson(db, 'rules'), contains('r2'));
    expect(await metaJson(db, 'learned'), isNot(contains('secret')));
    expect(await metaJson(db, 'canvas'), isNot(contains('secret')));
  });
}

// номер строки журнала ИИ при возврате новый: старый мог занять свежий запрос
Map<String, Object?> _withoutLogIds(Map<String, Object?> dump) => {
  for (final MapEntry(:key, :value) in dump.entries)
    key: key == 'ai_log' ? [for (final row in value! as List) {...(row as Map)}..remove('id')] : value,
};
