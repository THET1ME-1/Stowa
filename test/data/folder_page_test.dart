import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/folders_repository.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/models.dart';

void main() {
  late AppDatabase db;
  late ItemsRepository items;
  late FoldersRepository folders;
  final at = DateTime(2026, 11, 3, 12);

  Future<void> item(String id, {String? folder, int minutes = 0, List<String> tags = const []}) async {
    final when = at.add(Duration(minutes: minutes));
    await db.into(db.items).insert(ItemsCompanion.insert(id: id, kind: ItemKind.note, title: 'Вещь $id', folderId: Value(folder), createdAt: when, updatedAt: when));
    for (final tag in tags) {
      await db.into(db.tags).insert(TagsCompanion.insert(id: 't$tag', name: tag, createdAt: at), mode: InsertMode.insertOrIgnore);
      await db.into(db.itemTags).insert(ItemTagsCompanion.insert(itemId: id, tagId: 't$tag', source: TagSource.user));
    }
  }

  setUp(() async {
    db = AppDatabase.memory();
    items = ItemsRepository(db);
    folders = FoldersRepository(db);
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'food', name: 'Рецепты', icon: 'restaurant', shape: 'cookie9'));
  });
  tearDown(() => db.close());

  test('вещи папки, новые первыми, с тегами', () async {
    await item('a', folder: 'food', minutes: 1, tags: ['выпечка']);
    await item('b', folder: 'food', minutes: 2);
    await item('c', minutes: 3);
    final cards = await items.watchFolder('food').first;
    expect(cards.map((card) => card.id), ['b', 'a']);
    expect(cards.last.tags, ['выпечка']);
  });

  test('«Без папки» — отдельный список', () async {
    await item('a', folder: 'food');
    await item('b');
    expect((await items.watchFolder(null).first).map((card) => card.id), ['b']);
  });

  test('переименовать, сменить иконку, форму и вид', () async {
    await folders.rename('food', 'Еда дома');
    await folders.setLook('food', icon: 'soup_kitchen', shape: 'gem');
    await folders.setView('food', FolderView.board);
    final card = (await folders.watchAll().first).single;
    expect((card.name, card.icon, card.shape, card.view), ('Еда дома', 'soup_kitchen', 'gem', FolderView.board));
  });

  test('удалить папку: вещи остаются без папки, «Вернуть» всё возвращает', () async {
    await item('a', folder: 'food');
    await item('b', folder: 'food');
    final moved = await folders.delete('food', at);
    expect(await folders.watchAll().first, isEmpty);
    expect((await items.get('a'))!.item.folderId, isNull);
    expect((await items.get('a'))!.item.deletedAt, isNull);

    await folders.restore('food', moved);
    expect((await folders.watchAll().first).single.count, 2);
  });
}
