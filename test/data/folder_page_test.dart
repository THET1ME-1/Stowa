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

  test('у карточки пропорция первой картинки, без размера — null', () async {
    await item('a', folder: 'food');
    await item('b', folder: 'food', minutes: 1);
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'fa', itemId: 'a', path: 'a.jpg', mime: 'image/jpeg', size: 1, width: const Value(30), height: const Value(20)));
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'fb', itemId: 'b', path: 'b.jpg', mime: 'image/jpeg', size: 1));
    final cards = await items.watchFolder('food').first;
    expect(cards.firstWhere((card) => card.id == 'a').thumbRatio, closeTo(20 / 30, 0.001));
    expect(cards.firstWhere((card) => card.id == 'b').thumbRatio, isNull);
  });

  test('правка текста пересчитывает вид и адрес, если файлов нет', () async {
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'x', kind: ItemKind.link, title: 'Дипломная', url: const Value('https://flutter.dev/docs'), createdAt: at, updatedAt: at));
    await items.setTitleBody('x', title: 'Дипломная', body: 'Дипломная\nрасширить до 40 страниц\n20 источников\nДокументация: flutter.dev/docs', at: at);
    var item = (await items.get('x'))!.item;
    expect((item.kind, item.url), (ItemKind.note, 'https://flutter.dev/docs'));

    await items.setTitleBody('x', title: 'Кофе', body: 'Кофе https://coffee.ru/turka', at: at);
    item = (await items.get('x'))!.item;
    expect((item.kind, item.url), (ItemKind.link, 'https://coffee.ru/turka'));
  });

  test('длинный заголовок от сайта не делает ссылку заметкой, когда к ней дописали пару слов', () async {
    const url = 'https://rt.pornhub.com/view_video.php?viewkey=644065a6a9a54';
    const title = 'Школьница в очках и с красной помадой проглотила всё. от первого лица, лучший ролик недели';
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'x', kind: ItemKind.link, title: title, body: const Value(url), url: const Value(url), createdAt: at, updatedAt: at));
    await items.setTitleBody('x', title: title, body: '$url\n\nЛучшее видео, на которое у меня 100%.', at: at);
    final item = (await items.get('x'))!.item;
    expect((item.kind, item.url), (ItemKind.link, url));
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
