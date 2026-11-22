import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/data/repositories/trash_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/vault/vault_reader.dart';
import 'package:stowa/services/vault/vault_writer.dart';

// Файлы сами по себе: картинка, PDF или запись в папке хранилища без заметки. Obsidian
// показывает их в списке файлов — Stowa показывает их заметками, файл остаётся на месте.
void main() {
  late AppDatabase db;
  late Directory root;
  final now = DateTime(2026, 11, 15, 10);

  setUp(() async {
    db = AppDatabase.memory();
    root = Directory.systemTemp.createTempSync('stowa_loose');
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  VaultWriter writer() => VaultWriter(db, root: root, clock: () => now);
  VaultReader reader() => VaultReader(db, root: root, clock: () => now);
  File file(String relative) => File(p.join(root.path, relative));
  void put(String relative, List<int> bytes) => file(relative)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
  Future<List<Item>> items() => db.select(db.items).get();

  test('PDF и картинка в папке — заметки с этим файлом, файл не тронут и не скопирован', () async {
    put('Книги/Отчёт за год.pdf', List.filled(200, 1));
    put('Фото/закат.png', List.filled(100, 2));
    final scan = await reader().reconcile();
    expect(scan.added, 2);
    final all = await items();
    final pdf = all.singleWhere((item) => item.kind == ItemKind.file);
    final png = all.singleWhere((item) => item.kind == ItemKind.image);
    expect((pdf.title, png.title), ('Отчёт за год', 'закат'));
    expect(pdf.body, '');
    final attachments = await (db.select(db.attachments)..where((t) => t.itemId.equals(pdf.id))).get();
    expect(attachments.single.path, 'Книги/Отчёт за год.pdf');
    expect(attachments.single.mime, 'application/pdf');
    final folder = await (db.select(db.folders)..where((t) => t.id.equals(pdf.folderId!))).getSingle();
    expect(folder.name, 'Книги');
    // писатель не делает из файла заметку .md и не переносит его
    await writer().drain();
    expect(file('Книги/Отчёт за год.pdf').existsSync(), isTrue);
    expect(file('Книги/Отчёт за год.md').existsSync(), isFalse);
    expect(Directory(p.join(root.path, 'Книги', 'Отчёт за год')).existsSync(), isFalse);
    // вторая сверка ничего не плодит
    await reader().reconcile();
    expect(await items(), hasLength(2));
  });

  test('вложение заметки и файлы в папке вложений — не отдельные заметки', () async {
    file('Дом/Плитка.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('Плитка\n\n![[фасад.jpg]]\n');
    put('Дом/фасад.jpg', List.filled(50, 3));
    put('Дом/Плитка/замер.png', List.filled(50, 4));
    await reader().reconcile();
    final all = await items();
    expect(all, hasLength(1));
    expect(all.single.kind, ItemKind.note);
  });

  test('служебное и чужое служебное не берётся', () async {
    put('.obsidian/workspace.json', [1]);
    put('.stowa/facts/x.json', [1]);
    put('.trash/old.png', [1]);
    await reader().reconcile();
    expect(await items(), isEmpty);
  });

  test('переименовал файл в Stowa — переименовался и файл на диске', () async {
    put('Книги/report.pdf', List.filled(10, 1));
    await reader().reconcile();
    final id = (await items()).single.id;
    // заголовок из имени файла дало приложение
    expect((await items()).single.titleAuto, isTrue);
    // своё название — как его ставит страница заметки
    await ItemsRepository(db, clock: () => now).setTitleBody(id, title: 'Годовой отчёт', body: '', at: now);
    await writer().drain();
    expect(file('Книги/report.pdf').existsSync(), isFalse);
    expect(file('Книги/Годовой отчёт.pdf').existsSync(), isTrue);
    final attachment = (await (db.select(db.attachments)..where((t) => t.itemId.equals(id))).get()).single;
    expect(attachment.path, 'Книги/Годовой отчёт.pdf');
  });

  test('подпись «Фото от …» от приложения файл на диске не переименовывает', () async {
    put('Фото/IMG_20260820_094401.jpg', [1, 2, 3]);
    await reader().reconcile();
    final id = (await items()).single.id;
    await (db.update(db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(title: Value('Фото от 20 августа'), titleAuto: Value(true)));
    await writer().drain();
    expect(file('Фото/IMG_20260820_094401.jpg').existsSync(), isTrue);
    expect(file('Фото/Фото от 20 августа.jpg').existsSync(), isFalse);
  });

  test('дописал к файлу текст — рядом заметка со вставкой, сам файл на месте', () async {
    put('Книги/report.pdf', List.filled(10, 1));
    await reader().reconcile();
    final id = (await items()).single.id;
    await (db.update(db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(body: Value('Прочитать до пятницы')));
    await writer().drain();
    expect(file('Книги/report.md').readAsStringSync(), contains('Прочитать до пятницы\n\n![[report.pdf]]'));
    final saved = (await ItemsRepository(db).get(id))!;
    expect(saved.attachments.single.path, 'Книги/report.pdf');
    // файл человека не двигается: в Obsidian на него могут ссылаться другие заметки
    expect(file('Книги/report.pdf').existsSync(), isTrue);
  });

  // эмулятор 16.11 и жалоба тестировщика «не видно фоток»: писатель перенёс фото из входящих
  // («0_IMG.jpg») в каталог заметки («IMG.jpg»), а путь в базе и «.md» пишутся следом. Сверка,
  // попавшая в этот миг, заводила папку «Фото от 20 августа» и заметку-файл на чужую картинку;
  // удаление такого дубля уносило в корзину фото настоящей заметки — плитки серели
  test('фото на полпути из входящих к заметке — не заметка-файл и не папка', () async {
    final at = now;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'f', name: 'Stowa', icon: 'folder', shape: 'squircle'));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'n', kind: ItemKind.image, title: 'Фото от 20 августа', folderId: const Value('f'), createdAt: at, updatedAt: at));
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'a', itemId: 'n', path: '.stowa/incoming/n/0_IMG_20260820.jpg', mime: 'image/jpeg', size: 3));
    // файл уже у заметки, «.md» ещё нет
    put('Stowa/Фото от 20 августа/IMG_20260820.jpg', [1, 2, 3]);
    await reader().reconcile();
    expect((await items()).map((item) => item.id), ['n']);
    expect((await db.select(db.folders).get()).map((folder) => folder.name), ['Stowa']);
  });

  test('дубль уже есть: заметка-файл на картинку живой заметки уходит в корзину, файл на месте', () async {
    final at = now;
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'n', kind: ItemKind.image, title: 'Фото от 20 августа', createdAt: at, updatedAt: at));
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'a', itemId: 'n', path: 'Фото от 20 августа/IMG.jpg', mime: 'image/jpeg', size: 3));
    put('Фото от 20 августа/IMG.jpg', [1, 2, 3]);
    final noteText = await writer().drain().then((_) => file('Фото от 20 августа.md').readAsStringSync());
    expect(noteText, contains('IMG.jpg'));
    // дубль, заведённый прежней гонкой: своя папка с именем заметки и своя строка карты файлов на ту же картинку
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'ghost', name: 'Фото от 20 августа', icon: 'folder', shape: 'squircle'));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'dup', kind: ItemKind.image, title: 'IMG', folderId: const Value('ghost'), createdAt: at, updatedAt: at));
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'b', itemId: 'dup', path: 'Фото от 20 августа/IMG.jpg', mime: 'image/jpeg', size: 3));
    final stat = file('Фото от 20 августа/IMG.jpg').statSync();
    await db.into(db.vaultFiles).insert(VaultFilesCompanion.insert(itemId: 'dup', path: 'Фото от 20 августа/IMG.jpg', modified: stat.modified.millisecondsSinceEpoch, size: stat.size));
    await reader().reconcile();
    final all = {for (final item in await items()) item.id: item};
    expect(all['dup']!.deletedAt, isNotNull);
    expect(all['n']!.deletedAt, isNull);
    // пустая папка-призрак с именем заметки рядом с её «.md» уходит
    expect((await (db.select(db.folders)..where((t) => t.deletedAt.isNull())).get()).map((folder) => folder.id), isNot(contains('ghost')));
    // корзина дубля картинку живой заметки не уносит, и стирание навсегда тоже
    await writer().drain();
    expect(file('Фото от 20 августа/IMG.jpg').existsSync(), isTrue);
    await TrashRepository(db, filesRoot: root).purge('dup');
    expect(file('Фото от 20 августа/IMG.jpg').existsSync(), isTrue);
  });

  // эмулятор 16.11: угадыватель успел разложить в папку-призрак две фотозаметки — пустой она
  // уже не была и оставалась висеть внутри каталога вложений чужой заметки
  test('папка-призрак с разложенными в неё заметками: заметки — в родительскую, папка уходит', () async {
    final at = now;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'stowa', name: 'Stowa', icon: 'folder', shape: 'squircle'));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'n', kind: ItemKind.image, title: 'Фото от 20 августа', folderId: const Value('stowa'), createdAt: at, updatedAt: at));
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'a', itemId: 'n', path: 'Stowa/Фото от 20 августа/IMG.jpg', mime: 'image/jpeg', size: 3));
    put('Stowa/Фото от 20 августа/IMG.jpg', [1, 2, 3]);
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'ghost', name: 'Фото от 20 августа', icon: 'folder', shape: 'squircle', parentId: const Value('stowa')));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'sorted', kind: ItemKind.note, title: 'Закат', body: const Value('Закат'), folderId: const Value('ghost'), createdAt: at, updatedAt: at));
    await writer().drain();
    expect(file('Stowa/Фото от 20 августа/Закат.md').existsSync(), isTrue);
    await reader().reconcile();
    expect((await (db.select(db.folders)..where((t) => t.deletedAt.isNull())).get()).map((folder) => folder.id), ['stowa']);
    expect((await (db.select(db.items)..where((t) => t.id.equals('sorted'))).getSingle()).folderId, 'stowa');
    // файл заметки уезжает из каталога вложений в саму папку, картинка чужой заметки на месте
    await writer().drain();
    expect(file('Stowa/Закат.md').existsSync(), isTrue);
    expect(file('Stowa/Фото от 20 августа/IMG.jpg').existsSync(), isTrue);
  });

  // копия College 16.11: «Огневая подготовка.md» рядом с папкой «Огневая подготовка/» с
  // конспектами (заметка-папка Obsidian) — чистка призраков уносила конспекты уровнем выше
  test('заметка-папка Obsidian рядом с одноимённой папкой — папка и её заметки на месте', () async {
    file('Военка/Огневая.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('Огневая\n\n[[Автомат]]\n');
    file('Военка/Огневая/Автомат.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('Автомат\n');
    file('Военка/Тема.md').writeAsStringSync('Тема\n');
    Directory(p.join(root.path, 'Военка', 'Тема')).createSync();
    await reader().reconcile();
    await writer().drain();
    await reader().reconcile();
    await writer().drain();
    expect(file('Военка/Огневая/Автомат.md').existsSync(), isTrue);
    expect(file('Военка/Автомат.md').existsSync(), isFalse);
    final names = (await (db.select(db.folders)..where((t) => t.deletedAt.isNull())).get()).map((folder) => folder.name).toSet();
    expect(names, containsAll(['Военка', 'Огневая']));
  });

  test('пустая своя папка рядом с одноимённой заметкой — не призрак', () async {
    file('Проект.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('Проект\n');
    await reader().reconcile();
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'mine', name: 'Проект', icon: 'folder', shape: 'squircle'));
    await reader().reconcile();
    expect((await (db.select(db.folders)..where((t) => t.id.equals('mine'))).getSingleOrNull())?.deletedAt, isNull);
    expect(await (db.select(db.folders)..where((t) => t.id.equals('mine'))).getSingleOrNull(), isNotNull);
  });

  // хозяин 22.11: «что будет, если в качестве хранилища выбрана папка с совершенно другим
  // форматом файлов». Чужая папка — проект с кодом, архивы, двоичный мусор, битая кодировка:
  // сверка не падает, каждый файл виден заметкой-файлом, служебное чужое не берётся
  test('папка чужого формата: сверка не падает, файлы — заметками, битый .md читается как есть', () async {
    put('проект/main.cpp', 'int main() { return 0; }'.codeUnits);
    put('проект/Makefile', 'all:\n\tcc main.cpp'.codeUnits);
    put('проект/сборка/app.exe', [0x4D, 0x5A, 0x90, 0x00, 0xFF, 0xFE, 0x00]);
    put('архив.zip', [0x50, 0x4B, 0x03, 0x04, 0x00]);
    put('макет.psd', List.generate(300, (i) => (i * 31) & 0xFF));
    put('пустой.dat', const []);
    put('Битая.md', [0xD0, 0x97, 0xFF, 0xFE, 0x0A, 0xC3, 0x28]);
    put('a/b/c/d/e/глубоко.bin', [1, 2, 3]);
    put('.git/config', '[core]'.codeUnits);
    put('node_modules/.cache/x.json', '{}'.codeUnits);
    final scan = await reader().reconcile();
    expect(scan.added, greaterThanOrEqualTo(8));
    final all = await items();
    final byTitle = {for (final item in all) item.title: item};
    for (final title in ['main', 'Makefile', 'app', 'архив', 'макет', 'пустой', 'глубоко']) {
      expect(byTitle[title]?.kind, ItemKind.file, reason: title);
    }
    // служебные папки чужих программ — не заметки
    expect(byTitle.keys, isNot(contains('config')));
    expect(byTitle.keys, isNot(contains('x')));
    // битая кодировка — заметка с тем, что прочиталось, без падения
    expect(all.where((item) => item.kind == ItemKind.note), hasLength(1));
    final mime = {for (final row in await db.select(db.attachments).get()) p.basename(row.path): row.mime};
    expect(mime['макет.psd'], isNotEmpty);
    expect(mime['app.exe'], isNotEmpty);
    // вторая сверка ничего не плодит и ничего не теряет
    final again = await reader().reconcile();
    expect(again.added, 0);
    expect(again.removed, 0);
    expect(await items(), hasLength(all.length));
    // и писатель чужие файлы не трогает
    await writer().drain();
    expect(file('макет.psd').readAsBytesSync(), List.generate(300, (i) => (i * 31) & 0xFF));
    expect(file('проект/сборка/app.exe').existsSync(), isTrue);
  });

  test('удалили файл снаружи — заметка в корзине', () async {
    put('Фото/закат.png', [1, 2]);
    await reader().reconcile();
    file('Фото/закат.png').deleteSync();
    final scan = await reader().reconcile();
    expect(scan.removed, 1);
    expect((await items()).single.deletedAt, isNotNull);
  });
}
