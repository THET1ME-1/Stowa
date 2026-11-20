import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/folder_guess.dart';
import 'package:stowa/domain/models.dart';

void main() {
  late AppDatabase db;
  late ItemsRepository repository;
  final now = DateTime(2026, 11, 20, 12);

  Future<void> note(String id, String folder, String text) => db
      .into(db.items)
      .insert(ItemsCompanion.insert(id: id, kind: ItemKind.note, title: '', body: Value(text), folderId: Value(folder), createdAt: now, updatedAt: now));

  setUp(() async {
    db = AppDatabase.memory();
    repository = ItemsRepository(db, clock: () => now);
    for (final (id, name) in [('car', 'Гараж'), ('novel', 'Роман'), ('home', 'Быт')]) {
      await db.into(db.folders).insert(FoldersCompanion.insert(id: id, name: name, icon: 'folder', shape: 'squircle'));
    }
    await note('a', 'car', 'Замена масла и фильтра, мастер сказал прийти через месяц');
    await note('b', 'novel', 'милтон работает курьером и боится высоты');
    await note('c', 'novel', 'милтон спорит с сестрой из-за денег');
    await note('d', 'home', 'купить лампочки в коридор');
  });
  tearDown(() => db.close());

  test('угадыватель из базы помнит разобранные заметки: второй раз слова не режутся', () async {
    final first = await repository.folderIndex();
    expect(first.guess('поменять масло и фильтр до зимы')?.folderId, 'car');
    final parsed = repository.folderMemory.parsed;
    expect(parsed, 4);
    // другой экземпляр над той же базой, как у разбора после сохранения
    final again = await ItemsRepository(db, clock: () => now).folderIndex();
    expect(again.guess('поменять масло и фильтр до зимы')?.folderId, 'car');
    expect(repository.folderMemory.parsed, parsed);
  });

  test('после новой заметки заново режется только она', () async {
    await repository.folderIndex();
    final parsed = repository.folderMemory.parsed;
    await note('e', 'home', 'пылесос барахлит, отнести в ремонт');
    final index = await repository.folderIndex();
    expect(repository.folderMemory.parsed, parsed + 1);
    expect(index.guess('пылесос опять сломался')?.folderId, 'home');
  });

  test('два запроса разом на пустой памяти: каждая заметка режется один раз', () async {
    final both = await Future.wait([repository.folderIndex(), ItemsRepository(db, clock: () => now).folderIndex()]);
    expect(repository.folderMemory.parsed, 4);
    expect(both[1].guess('поменять масло и фильтр до зимы')?.folderId, 'car');
  });

  test('запись, которая слов и папок не касается, отдаёт тот же угадыватель', () async {
    final first = await repository.folderIndex();
    // так пишет разбор фактов: по заметке за раз, тысячи раз после первой загрузки хранилища
    await (db.update(db.items)..where((t) => t.id.equals('a'))).write(const ItemsCompanion(factsText: Value('120 лей')));
    expect(identical(await repository.folderIndex(), first), isTrue);
    expect(repository.folderMemory.parsed, 4);
  });

  test('правка текста, перенос в другую папку, новое имя папки, тег — каждый раз новый угадыватель', () async {
    var last = await repository.folderIndex();
    Future<FolderIndex> next() async {
      final index = await repository.folderIndex();
      expect(identical(index, last), isFalse);
      return last = index;
    }

    // слово, которого нет ни в одном словаре тем: папку решают только заметки
    await (db.update(db.items)..where((t) => t.id.equals('d'))).write(ItemsCompanion(body: const Value('zorbex лежит на полке'), updatedAt: Value(now.add(const Duration(minutes: 1)))));
    expect((await next()).guess('zorbex')?.folderId, 'home');
    expect(repository.folderMemory.parsed, 5);

    await (db.update(db.items)..where((t) => t.id.equals('d'))).write(const ItemsCompanion(folderId: Value('car')));
    expect((await next()).guess('zorbex')?.folderId, 'car');
    expect(repository.folderMemory.parsed, 5, reason: 'текст тот же: резать нечего');

    await (db.update(db.folders)..where((t) => t.id.equals('home'))).write(const FoldersCompanion(name: Value('Дача')));
    expect((await next()).guess('поехать на дачу в субботу')?.folderId, 'home');

    await db.into(db.tags).insert(TagsCompanion.insert(id: 't1', name: 'шиномонтаж', createdAt: now));
    await db.into(db.itemTags).insert(ItemTagsCompanion.insert(itemId: 'a', tagId: 't1', source: TagSource.user));
    expect((await next()).guess('записаться на шиномонтаж')?.folderId, 'car');
  });

  test('текст поменялся без отметки времени — всё равно виден: длина другая', () async {
    await repository.folderIndex();
    // так кладут свои поля фоновые службы: описание ИИ, расшифровка, превью страницы
    await (db.update(db.items)..where((t) => t.id.equals('d'))).write(const ItemsCompanion(transcript: Value('zorbex барахлит')));
    expect((await repository.folderIndex()).guess('zorbex')?.folderId, 'home');
  });

  test('заметки ушли в корзину — их слов в угадывателе и в памяти больше нет', () async {
    expect((await repository.folderIndex()).guess('и тут вошёл Милтон')?.folderId, 'novel');
    await (db.update(db.items)..where((t) => t.id.isIn(['b', 'c']))).write(ItemsCompanion(deletedAt: Value(now)));
    expect((await repository.folderIndex()).guess('и тут вошёл Милтон'), isNull);
    expect(repository.folderMemory.size, 2);
  });

  test('для напоминания о копии: сколько заметок всего и сколько правили после копии', () async {
    // корзина не в счёт; без даты копии правлеными считаются все
    await (db.update(db.items)..where((t) => t.id.equals('d'))).write(ItemsCompanion(deletedAt: Value(now)));
    expect(await repository.copyCounts(null), (notes: 3, editedSince: 3));
    final copied = now.add(const Duration(hours: 1));
    expect(await repository.copyCounts(copied), (notes: 3, editedSince: 0));
    await (db.update(db.items)..where((t) => t.id.equals('a'))).write(ItemsCompanion(updatedAt: Value(copied.add(const Duration(minutes: 5)))));
    expect(await repository.copyCounts(copied), (notes: 3, editedSince: 1));
  });

  test('поток отдаёт угадыватель при подписке и новый — после правки заметок', () async {
    final seen = <FolderIndex>[];
    final sub = repository.watchFolderIndex().listen(seen.add);
    await pumpEventQueue();
    expect(seen, hasLength(1));
    expect(seen.last.guess('пылесос опять сломался'), isNull);
    await note('e', 'home', 'пылесос барахлит, отнести в ремонт');
    await pumpEventQueue();
    expect(seen.length, greaterThan(1));
    expect(seen.last.guess('пылесос опять сломался')?.folderId, 'home');
    await sub.cancel();
  });

  test('двадцать правок подряд не дают двадцати пересборок', () async {
    final seen = <FolderIndex>[];
    final sub = repository.watchFolderIndex().listen(seen.add);
    await pumpEventQueue();
    // правки одной пачкой, как при сверке хранилища и переносе
    await Future.wait([for (var index = 0; index < 20; index++) note('n$index', 'home', 'заметка номер $index про быт')]);
    await pumpEventQueue();
    expect(seen.length, lessThan(8), reason: 'пересборок: ${seen.length}');
    expect(seen.last.guess('пылесос'), isNull);
    await sub.cancel();
  });
}
