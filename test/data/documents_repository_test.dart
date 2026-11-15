import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/documents_repository.dart';
import 'package:stowa/domain/json_canvas.dart';
import 'package:stowa/domain/models.dart';

void main() {
  late AppDatabase db;
  late DocumentsRepository repo;
  final now = DateTime(2026, 11, 15, 12);

  setUp(() {
    db = AppDatabase.memory();
    repo = DocumentsRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  Future<void> folder(String id, String name, {String? parent}) =>
      db.into(db.folders).insert(FoldersCompanion.insert(id: id, name: name, icon: 'folder', shape: 'squircle', parentId: Value(parent)));

  test('новый холст — пустой файл в папке, разложен человеком, в очереди записи', () async {
    await folder('home', 'Дом');
    final id = await repo.create(ItemKind.canvas, title: 'План ремонта', folderId: 'home');
    final item = await (db.select(db.items)..where((t) => t.id.equals(id))).getSingle();
    expect((item.kind, item.title, item.folderId, item.sortedBy, item.sortState), (ItemKind.canvas, 'План ремонта', 'home', SortedBy.user, SortState.sorted));
    expect(CanvasDoc.parse(item.document!).nodes, isEmpty);
    expect([for (final row in await db.select(db.vaultQueue).get()) row.target], contains('item:$id'));
  });

  test('новая база папки смотрит на путь папки с вложенными', () async {
    await folder('home', 'Дом');
    await folder('fix', 'Ремонт', parent: 'home');
    final id = await repo.create(ItemKind.base, title: 'Таблица ремонта', folderId: 'fix');
    final item = await (db.select(db.items)..where((t) => t.id.equals(id))).getSingle();
    expect(item.document, contains('file.inFolder("Дом/Ремонт")'));
  });

  test('сохранение холста: файл, текст для поиска и время правки', () async {
    final id = await repo.create(ItemKind.canvas, title: 'Доска');
    final doc = CanvasDoc.empty().addText('купить плитку', x: 0, y: 0);
    await repo.save(id, doc);
    final item = await (db.select(db.items)..where((t) => t.id.equals(id))).getSingle();
    expect(item.document, doc.encode());
    expect(item.body, 'купить плитку');
    expect(await db.searchIds('плитку'), [id]);
  });

  test('заметки для базы: путь по папкам, теги, ссылки из текста и свойства; холсты и корзина мимо', () async {
    await folder('books', 'Книги');
    await db.into(db.items).insert(ItemsCompanion.insert(
      id: 'n1', kind: ItemKind.note, title: 'Идиот', body: const Value('Перечитать [[Братья Карамазовы]]'), folderId: const Value('books'),
      properties: const Value('{"author":"Достоевский","rating":3}'), createdAt: now, updatedAt: now,
    ));
    await db.into(db.tags).insert(TagsCompanion.insert(id: 't', name: 'книга', createdAt: now));
    await db.into(db.itemTags).insert(ItemTagsCompanion.insert(itemId: 'n1', tagId: 't', source: TagSource.user));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'gone', kind: ItemKind.note, title: 'Старое', deletedAt: Value(now), createdAt: now, updatedAt: now));
    await repo.create(ItemKind.canvas, title: 'Доска');
    final notes = await repo.baseNotes();
    expect(notes, hasLength(1));
    final note = notes.single;
    expect(note.path, 'Книги/Идиот.md');
    expect(note.tags, ['книга']);
    expect(note.links, ['Братья Карамазовы']);
    expect(note.properties['author'], 'Достоевский');
  });

  test('заметка по пути файла: из карты файлов, иначе по папке и имени', () async {
    await folder('home', 'Дом');
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Плитка', folderId: const Value('home'), createdAt: now, updatedAt: now));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'b', kind: ItemKind.note, title: 'Затирка', createdAt: now, updatedAt: now));
    await db.into(db.vaultFiles).insert(VaultFilesCompanion.insert(itemId: 'b', path: 'Склад/Затирка 2.md', modified: 0, size: 0));
    expect(await repo.itemAt('Дом/Плитка.md'), 'a');
    expect(await repo.itemAt('Склад/Затирка 2.md'), 'b');
    expect(await repo.itemAt('Нет/Такой.md'), isNull);
    expect(await repo.pathOf('a'), 'Дом/Плитка.md');
    expect(await repo.pathOf('b'), 'Склад/Затирка 2.md');
  });
}
