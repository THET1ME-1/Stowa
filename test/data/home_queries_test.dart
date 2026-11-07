import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/folder_palette.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/folders_repository.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/reminder_actions.dart';

final _day = DateTime(2026, 11, 2, 12);

Future<void> _item(AppDatabase db, String id, {String? folder, String? image, int minutes = 0, bool deleted = false}) async {
  final at = _day.add(Duration(minutes: minutes));
  await db.into(db.items).insert(ItemsCompanion.insert(
        id: id,
        kind: image == null ? ItemKind.note : ItemKind.image,
        title: 'Вещь $id',
        folderId: Value(folder),
        createdAt: at,
        updatedAt: at,
        deletedAt: Value(deleted ? at : null),
      ));
  if (image != null) {
    await db.into(db.attachments).insert(
          AttachmentsCompanion.insert(id: 'a$id', itemId: id, path: image, mime: 'image/jpeg', size: 1),
        );
  }
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  test('папки со счётом живых вещей, обложками и последними заголовками', () async {
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'refs', name: 'Референсы', icon: 'palette', shape: 'squircle'));
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'car', name: 'Машина', icon: 'directions_car', shape: 'pill', sortOrder: const Value(1)));
    await _item(db, '1', folder: 'refs', image: 'p/1.jpg', minutes: 1);
    await _item(db, '2', folder: 'refs', image: 'p/2.jpg', minutes: 2);
    await _item(db, '3', folder: 'refs', minutes: 3);
    await _item(db, '4', folder: 'refs', image: 'p/4.jpg', minutes: 4, deleted: true);
    await _item(db, '5', folder: 'car', minutes: 5);

    final folders = await FoldersRepository(db).watchAll().first;
    expect(folders.map((folder) => folder.name), ['Референсы', 'Машина']);
    final refs = folders.first;
    expect(refs.count, 3);
    expect(refs.covers, ['p/2.jpg', 'p/1.jpg']);
    expect(refs.recentTitles.first, 'Вещь 3');
    expect(folders.last.count, 1);
  });

  test('мёртвая ссылка на карточке: с копией статьи и без неё; живая — без пометки', () async {
    for (final id in ['copy', 'bare', 'alive']) {
      await db.into(db.items).insert(ItemsCompanion.insert(
            id: id,
            kind: ItemKind.link,
            title: id,
            url: Value('https://$id.md'),
            goneAt: Value(id == 'alive' ? null : _day),
            createdAt: _day,
            updatedAt: _day,
          ));
    }
    await db.into(db.facts).insert(FactsCompanion.insert(id: 'f', itemId: 'copy', extractor: 'article', kind: FactKind.articleText, value: 'текст'));
    final cards = {for (final card in await ItemsRepository(db).watchRecent().first) card.id: card};
    expect((cards['copy']!.gone, cards['copy']!.hasCopy), (true, true));
    expect((cards['bare']!.gone, cards['bare']!.hasCopy), (true, false));
    expect(cards['alive']!.gone, isFalse);
  });

  test('цвет папки: выбранный из палитры, без выбора — по месту в списке; заметка берёт цвет своей папки', () async {
    final folders = FoldersRepository(db);
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'a', name: 'Первая', icon: 'folder', shape: 'pill'));
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'b', name: 'Вторая', icon: 'folder', shape: 'pill', sortOrder: const Value(1)));
    await _item(db, 'n', folder: 'b');
    await _item(db, 'loose');

    var cards = {for (final card in await folders.watchAll().first) card.id: card};
    expect(cards['a']!.color, FolderPalette.colors['coral']);
    expect(cards['b']!.color, FolderPalette.colors['tangerine']);

    await folders.setLook('b', icon: 'eco', shape: 'gem', color: 'mint');
    cards = {for (final card in await folders.watchAll().first) card.id: card};
    expect(cards['b']!.colorKey, 'mint');
    expect(cards['b']!.color, FolderPalette.colors['mint']);

    final recent = {for (final card in await ItemsRepository(db).watchRecent().first) card.id: card};
    expect(recent['n']!.folderColor, FolderPalette.colors['mint']);
    expect(recent['loose']!.folderColor, isNull);
  });

  test('удалённая папка не показывается', () async {
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'x', name: 'Старое', icon: 'folder', shape: 'gem', deletedAt: Value(_day)));
    expect(await FoldersRepository(db).watchAll().first, isEmpty);
  });

  test('закреплённые теги по порядку и с числом вещей', () async {
    final tags = TagsRepository(db, clock: () => _day);
    final car = await tags.ensure('машина');
    final food = await tags.ensure('рецепт');
    await tags.ensure('прочее');
    await (db.update(db.tags)..where((t) => t.id.equals(car.id))).write(const TagsCompanion(pinned: Value(true), pinOrder: Value(2), iconValue: Value('directions_car')));
    await (db.update(db.tags)..where((t) => t.id.equals(food.id))).write(const TagsCompanion(pinned: Value(true), pinOrder: Value(1)));
    await _item(db, '1');
    await _item(db, '2');
    await _item(db, '3', deleted: true);
    for (final id in ['1', '2', '3']) {
      await db.into(db.itemTags).insert(ItemTagsCompanion.insert(itemId: id, tagId: car.id, source: TagSource.inline));
    }

    final pinned = await tags.watchPinned().first;
    expect(pinned.map((tag) => tag.name), ['рецепт', 'машина']);
    expect(pinned.last.count, 2);
    expect(pinned.last.iconValue, 'directions_car');
    expect(pinned.first.count, 0);
  });

  test('новая папка из строки: имя с заглавной, своя форма, в конце списка', () async {
    final folders = FoldersRepository(db);
    await folders.create('книги');
    final created = await folders.create('беспроводные возможности');
    expect(created.name, 'Беспроводные возможности');
    final all = await folders.watchAll().first;
    expect(all.map((folder) => folder.name), ['Книги', 'Беспроводные возможности']);
    expect(all.first.shape, isNot(all.last.shape));
  });

  test('«Готово» у напоминания убирает его из ближайших, вещь остаётся', () async {
    await _item(db, '1');
    await (db.update(db.items)..where((t) => t.id.equals('1'))).write(ItemsCompanion(reminderAt: Value(_day.add(const Duration(hours: 1)))));
    final items = ItemsRepository(db);
    expect(await items.watchUpcoming(_day).first, hasLength(1));

    await items.clearReminder('1');
    expect(await items.watchUpcoming(_day).first, isEmpty);
    expect(await items.watchRecent().first, hasLength(1));
  });

  test('кнопки уведомления: «Через час» переносит, «Готово» снимает', () async {
    await _item(db, '1');
    await db.update(db.items).write(ItemsCompanion(body: const Value('Вещь 1\nвзять паспорт'), reminderAt: Value(_day)));
    final items = ItemsRepository(db);

    final again = await handleReminderAction(items, actionId: reminderSnooze, itemId: '1', now: _day);
    expect(again, (id: '1', title: 'Вещь 1', body: 'взять паспорт', at: _day.add(const Duration(hours: 1))));
    expect((await items.watchReminders().first).single.at, _day.add(const Duration(hours: 1)));

    expect(await handleReminderAction(items, actionId: reminderDone, itemId: '1', now: _day), isNull);
    expect(await items.watchReminders().first, isEmpty);
  });
}
