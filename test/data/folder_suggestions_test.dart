import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/folder_suggestions.dart';
import 'package:stowa/domain/models.dart';

void main() {
  late AppDatabase db;
  late FolderSuggestions suggestions;
  final now = DateTime(2026, 11, 9, 12);

  setUp(() async {
    db = AppDatabase.memory();
    suggestions = FolderSuggestions(db, clock: () => now);
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'work', name: 'Работа', icon: 'work', shape: 'squircle'));
  });
  tearDown(() => db.close());

  Future<void> link(String id, String url, {String? site, String? folder, bool deleted = false}) => db.into(db.items).insert(ItemsCompanion.insert(
        id: id,
        kind: ItemKind.link,
        title: id,
        url: Value(url),
        previewSite: Value(site),
        folderId: Value(folder),
        deletedAt: Value(deleted ? now : null),
        createdAt: now,
        updatedAt: now,
      ));

  Future<void> shot(String id) async {
    await db.into(db.items).insert(ItemsCompanion.insert(id: id, kind: ItemKind.image, title: id, createdAt: now, updatedAt: now));
    await db.into(db.facts).insert(FactsCompanion.insert(id: '$id-s', itemId: id, extractor: 'photo', kind: FactKind.screenshot, value: '1'));
  }

  test('самая большая группа без папки: сайт с именем из превью, порог — 8', () async {
    for (var index = 0; index < 9; index++) {
      await link('h$index', 'https://www.habr.com/ru/articles/$index/', site: 'Хабр');
    }
    // в папке и в корзине — не считаются
    await link('h-work', 'https://habr.com/ru/articles/100/', folder: 'work');
    await link('h-gone', 'https://habr.com/ru/articles/101/', deleted: true);
    for (var index = 0; index < 8; index++) {
      await shot('s$index');
    }
    for (var index = 0; index < 7; index++) {
      await link('y$index', 'https://youtu.be/$index');
    }

    final first = (await suggestions.find(dismissed: const {}))!;
    expect((first.key, first.count, first.name, first.host), ('site:habr.com', 9, 'Хабр', 'habr.com'));
    final next = (await suggestions.find(dismissed: {first.key}))!;
    expect((next.key, next.count, next.kind), ('kind:screenshot', 8, SuggestKind.screenshot));
    expect(await suggestions.find(dismissed: {first.key, next.key}), isNull, reason: 'семь роликов — меньше порога');
  });

  test('«Сделать»: папка, заметки в ней, правило сайта; «Отменить» возвращает всё', () async {
    for (var index = 0; index < 8; index++) {
      await link('h$index', 'https://habr.com/ru/articles/$index/', site: 'Хабр');
    }
    final suggestion = (await suggestions.find(dismissed: const {}))!;
    final done = await suggestions.accept(suggestion, name: 'Хабр');

    final moved = await (db.select(db.items)..where((t) => t.folderId.equals(done.folderId))).get();
    expect(moved, hasLength(8));
    expect(moved.every((item) => item.sortedBy == SortedBy.rule), isTrue);
    final rule = await db.select(db.rules).getSingle();
    expect((rule.conditionKind, rule.conditionValue, rule.actionKind, rule.actionValue), (RuleConditionKind.domain, 'habr.com', RuleActionKind.toFolder, done.folderId));
    expect(await suggestions.find(dismissed: const {}), isNull);

    await suggestions.undo(done);
    final back = await (db.select(db.items)..where((t) => t.folderId.isNull())).get();
    expect(back, hasLength(8));
    expect(back.every((item) => item.sortedBy == SortedBy.none), isTrue);
    expect(await db.select(db.rules).get(), isEmpty);
    expect((await (db.select(db.folders)..where((t) => t.id.equals(done.folderId))).getSingle()).deletedAt, isNotNull);
  });
}
