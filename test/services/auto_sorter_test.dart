import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/auto_sorter.dart';

void main() {
  late AppDatabase db;
  late AutoSorter sorter;
  final now = DateTime(2026, 11, 3, 12);
  var counter = 0;

  setUp(() async {
    db = AppDatabase.memory();
    sorter = AutoSorter(db);
    for (final (id, name) in [('read', 'Чтение'), ('car', 'Машина')]) {
      await db.into(db.folders).insert(FoldersCompanion.insert(id: id, name: name, icon: 'book', shape: 'squircle'));
    }
  });
  tearDown(() => db.close());

  Future<String> add(String title, {String? folder, ItemKind kind = ItemKind.note, String? url, SortedBy by = SortedBy.none, List<(String, TagSource)> tags = const []}) async {
    final id = 'i${counter++}';
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: id,
          kind: kind,
          title: title,
          body: Value(title),
          url: Value(url),
          folderId: Value(folder),
          sortedBy: Value(by),
          sortState: Value(folder == null ? SortState.pending : SortState.sorted),
          createdAt: now,
          updatedAt: now,
        ));
    for (final (name, source) in tags) {
      await db.into(db.tags).insertOnConflictUpdate(TagsCompanion.insert(id: 't$name', name: name, createdAt: now));
      await db.into(db.itemTags).insert(ItemTagsCompanion.insert(itemId: id, tagId: 't$name', source: source));
    }
    return id;
  }

  Future<Item> item(String id) => (db.select(db.items)..where((t) => t.id.equals(id))).getSingle();

  Future<void> seed() async {
    await add('Сборщик мусора в Dart', folder: 'read', kind: ItemKind.link, url: 'https://habr.com/a/1', by: SortedBy.user);
    await add('Как устроен Flutter', folder: 'read', kind: ItemKind.link, url: 'https://habr.com/a/2', by: SortedBy.user);
    await add('Замена масла и фильтра', folder: 'car', by: SortedBy.user);
    await add('Шины на зиму, масло', folder: 'car', by: SortedBy.user);
  }

  test('«Без папки» раскладывается по словам и по сайту ссылки', () async {
    await seed();
    final oil = await add('Купить масло на зиму');
    final link = await add('https://habr.com/a/3', kind: ItemKind.link, url: 'https://habr.com/a/3');
    final unknown = await add('Позвонить бабушке');
    final moved = await sorter.sortInbox();
    expect(moved, unorderedEquals([oil, link]));
    expect((await item(oil)).folderId, 'car');
    expect((await item(oil)).sortedBy, SortedBy.similar);
    expect((await item(link)).folderId, 'read');
    expect((await item(unknown)).folderId, isNull);
  });

  test('своя догадка — не образец: PDF, переложенная по похожести, не тянет за собой другие PDF', () async {
    await seed();
    // угадыватель однажды ошибся: смету положил к статьям
    final estimate = await add('Смета ремонта', folder: 'read', kind: ItemKind.file, by: SortedBy.similar);
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'a-est', itemId: estimate, path: 'Смета/смета.pdf', mime: 'application/pdf', size: 1));
    final pdf = await add('Скан договора', kind: ItemKind.file);
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'a-pdf', itemId: pdf, path: 'Скан/скан.pdf', mime: 'application/pdf', size: 1));
    expect(await sorter.sortInbox(), isEmpty);
    expect((await item(pdf)).folderId, isNull);
  });

  test('что человек сам оставил без папки, алгоритм не трогает', () async {
    await seed();
    final kept = await add('Масло для дома', by: SortedBy.user);
    expect(await sorter.sortInbox(), isEmpty);
    expect((await item(kept)).folderId, isNull);
  });

  test('«Отменить» возвращает разложенное в «Без папки»', () async {
    await seed();
    final oil = await add('Купить масло на зиму');
    final moved = await sorter.sortInbox();
    await sorter.undoSort(moved);
    final back = await item(oil);
    expect(back.folderId, isNull);
    expect(back.sortedBy, SortedBy.none);
    // и следующий разбор его снова не тащит, пока человек не разложит что-то ещё
    expect(await sorter.sortInbox(skip: moved), isEmpty);
  });

  test('тег похожих вещей ставится сам, если он у них уже не случайно', () async {
    await add('Борщ с говядиной, рецепт бабушки', tags: [('рецепт', TagSource.user)]);
    await add('Рецепт борща на скорую руку', tags: [('рецепт', TagSource.user)]);
    for (final note in ['Купить хлеб', 'Позвонить в банк', 'Забрать посылку', 'Счёт за свет', 'Записаться к врачу', 'Идея для подарка']) {
      await add(note);
    }
    final soup = await add('Постный борщ без мяса');
    final added = await sorter.tagItem(soup);
    expect(added, ['рецепт']);
    final link = await (db.select(db.itemTags)..where((t) => t.itemId.equals(soup))).getSingle();
    expect(link.source, TagSource.similar);
  });

  test('пачка заметок: теги соседей ставятся всем, база читается один раз', () async {
    await add('Борщ с говядиной, рецепт бабушки', tags: [('рецепт', TagSource.user)]);
    await add('Рецепт борща на скорую руку', tags: [('рецепт', TagSource.user)]);
    for (final note in ['Купить хлеб', 'Позвонить в банк', 'Забрать посылку', 'Счёт за свет', 'Записаться к врачу', 'Идея для подарка']) {
      await add(note);
    }
    final soup = await add('Постный борщ без мяса');
    final bread = await add('Купить батон');
    final added = await sorter.tagItems([soup, bread]);
    expect(added, {soup: ['рецепт'], bread: <String>[]});
  });

  test('тег одной вещи ещё не повод ставить его другим', () async {
    await add('Борщ с говядиной', tags: [('рецепт', TagSource.user)]);
    await add('Купить хлеб');
    final soup = await add('Постный борщ');
    expect(await sorter.tagItem(soup), isEmpty);
  });
}
