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

  // хозяин 22.11: картинка, вставленная на холст, должна быть видна картинкой, а не «Image» с
  // пустой карточкой; Obsidian кладёт на холст сам файл картинки
  test('карточка холста для заметки-картинки — сам файл картинки, когда он лёг на место', () async {
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'p', kind: ItemKind.image, title: 'Фото от 22 ноября', createdAt: now, updatedAt: now));
    await db.into(db.vaultFiles).insert(VaultFilesCompanion.insert(itemId: 'p', path: 'Фото от 22 ноября.md', modified: 0, size: 0));
    // файл ещё во входящих: места у картинки пока нет
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'f', itemId: 'p', path: '.stowa/incoming/p/0_IMG-20261122-182003.png', mime: 'image/png', size: 10));
    expect(await repo.placedPathOf('p'), isNull);
    // писатель перенёс картинку в папку вложений и дописал в заметку вставку
    await (db.update(db.attachments)..where((t) => t.id.equals('f'))).write(const AttachmentsCompanion(path: Value('Вложения/IMG-20261122-182003.png')));
    await (db.update(db.items)..where((t) => t.id.equals('p'))).write(const ItemsCompanion(body: Value('![[IMG-20261122-182003.png]]')));
    expect(await repo.placedPathOf('p'), 'Вложения/IMG-20261122-182003.png');
    // двойной щелчок по такой карточке находит заметку картинки
    expect(await repo.itemAt('Вложения/IMG-20261122-182003.png'), 'p');
  });

  test('карточка, вставленная до того, как файл лёг, переходит на него сама — даже если холст уже закрыли', () async {
    final canvasId = await repo.create(ItemKind.canvas, title: 'Доска');
    final doc = CanvasDoc.empty().addFile('IMG-20261122-182003.png', x: 0, y: 0, width: 320, height: 240);
    await repo.save(canvasId, doc);
    final nodeId = doc.nodes.single.id;
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'p', kind: ItemKind.image, title: 'Фото от 22 ноября', createdAt: now, updatedAt: now));
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'f', itemId: 'p', path: '.stowa/incoming/p/0_IMG-20261122-182003.png', mime: 'image/png', size: 10));
    repo.followPlaced(canvasId, nodeId, 'p');
    await pumpEventQueue();
    Future<String?> file() async => CanvasDoc.parse((await (db.select(db.items)..where((t) => t.id.equals(canvasId))).getSingle()).document!).node(nodeId)?.file;
    expect(await file(), 'IMG-20261122-182003.png', reason: 'картинка ещё во входящих');
    await (db.update(db.attachments)..where((t) => t.id.equals('f'))).write(const AttachmentsCompanion(path: Value('Вложения/IMG-20261122-182003.png')));
    await pumpEventQueue();
    expect(await file(), 'Вложения/IMG-20261122-182003.png');
  });

  test('карточку убрали, пока файл ложился, — холст не трогается', () async {
    final canvasId = await repo.create(ItemKind.canvas, title: 'Доска');
    final doc = CanvasDoc.empty().addFile('IMG.png', x: 0, y: 0, width: 320, height: 240);
    await repo.save(canvasId, doc);
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'p', kind: ItemKind.image, title: 'Фото', createdAt: now, updatedAt: now));
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'f', itemId: 'p', path: '.stowa/incoming/p/0_IMG.png', mime: 'image/png', size: 10));
    repo.followPlaced(canvasId, doc.nodes.single.id, 'p');
    await pumpEventQueue();
    await repo.save(canvasId, CanvasDoc.empty());
    await (db.update(db.attachments)..where((t) => t.id.equals('f'))).write(const AttachmentsCompanion(path: Value('Вложения/IMG.png')));
    await pumpEventQueue();
    expect(CanvasDoc.parse((await (db.select(db.items)..where((t) => t.id.equals(canvasId))).getSingle()).document!).nodes, isEmpty);
  });

  test('карточка холста для заметки с текстом — файл заметки, даже если в ней картинка', () async {
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Плитка', body: const Value('Плитка\n![[IMG.png]]'), createdAt: now, updatedAt: now));
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'f', itemId: 'n', path: 'Вложения/IMG.png', mime: 'image/png', size: 10));
    expect(await repo.placedPathOf('n'), isNull, reason: 'файл заметки ещё не записан');
    await db.into(db.vaultFiles).insert(VaultFilesCompanion.insert(itemId: 'n', path: 'Плитка.md', modified: 0, size: 0));
    expect(await repo.placedPathOf('n'), 'Плитка.md');
  });
}
