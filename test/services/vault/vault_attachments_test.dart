import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/vault/vault_layout.dart' show readAttachmentSetting, writeAttachmentSetting;
import 'package:stowa/services/vault/vault_reader.dart';
import 'package:stowa/services/vault/vault_writer.dart';

// Вложения как в Obsidian (16.11.2026): файл лежит сам по себе, место в тексте задаёт
// `![[имя]]`. Старые заметки Stowa с хвостом и каталогом «Заметка/» читаются как раньше.
void main() {
  late AppDatabase db;
  late Directory root;
  final now = DateTime(2026, 11, 16, 10);

  setUp(() {
    db = AppDatabase.memory();
    root = Directory.systemTemp.createTempSync('stowa_attach');
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  VaultReader reader() => VaultReader(db, root: root, clock: () => now);
  File file(String relative) => File(p.join(root.path, relative));
  void put(String relative, [List<int> bytes = const [1, 2, 3]]) => file(relative)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
  void note(String relative, String text) => file(relative)
    ..createSync(recursive: true)
    ..writeAsStringSync(text);
  Future<Item> only() => db.select(db.items).getSingle();
  Future<List<String>> paths(String id) async => [
    for (final row in await (db.select(db.attachments)..where((t) => t.itemId.equals(id))..orderBy([(t) => OrderingTerm.asc(t.position)])).get()) row.path,
  ];

  test('старый хвост в свой каталог «Заметка/» — вложения, текст чистый', () async {
    note('Дом/Плитка.md', 'Плитка\n\n![[Дом/Плитка/a.jpg]]\n');
    put('Дом/Плитка/a.jpg');
    await reader().reconcile();
    final item = await only();
    expect(item.body, 'Плитка');
    expect(await paths(item.id), ['Дом/Плитка/a.jpg']);
  });

  test('вставка с путём в конце нового текста остаётся в тексте на своём месте', () async {
    note('Дом/План.md', 'План\n\n![[Изображения/b.jpg]]\n');
    put('Изображения/b.jpg');
    await reader().reconcile();
    final item = await only();
    expect(item.body, 'План\n\n![[Изображения/b.jpg]]');
    expect(await paths(item.id), ['Изображения/b.jpg']);
  });

  test('короткое имя находится в общей папке вложений Obsidian', () async {
    put('.obsidian/app.json', utf8.encode(jsonEncode({'attachmentFolderPath': 'Изображения'})));
    note('Дом/План.md', 'План\n\n![[c.jpg]]\n\nдальше текст\n');
    put('Изображения/c.jpg');
    await reader().reconcile();
    final item = await only();
    expect(item.body, contains('![[c.jpg]]'));
    expect(await paths(item.id), ['Изображения/c.jpg']);
  });

  test('короткое имя без настройки — по всему хранилищу', () async {
    note('Дом/X.md', 'X\n![[d.jpg]]\n');
    put('Где-то/далеко/d.jpg');
    await reader().reconcile();
    expect(await paths((await only()).id), ['Где-то/далеко/d.jpg']);
  });

  // ── запись ──

  VaultWriter writer() => VaultWriter(db, root: root, clock: () => now);
  Future<void> folder(String id, String name) => db.into(db.folders).insert(FoldersCompanion.insert(id: id, name: name, icon: 'folder', shape: 'squircle'));
  Future<void> item(String id, {String title = 'Заметка', String body = '', String? folderId, bool auto = false, ItemKind kind = ItemKind.note}) => db
      .into(db.items)
      .insert(ItemsCompanion.insert(id: id, kind: kind, title: title, body: Value(body), folderId: Value(folderId), titleAuto: Value(auto), createdAt: now, updatedAt: now));
  Future<void> attach(String itemId, String path, {String id = 'a', int position = 0}) async {
    put(path);
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: id, itemId: itemId, path: path, mime: 'image/jpeg', size: 3, position: Value(position)));
  }

  Future<String?> mapped(String id) async => (await (db.select(db.vaultFiles)..where((t) => t.itemId.equals(id))).getSingleOrNull())?.path;

  test('новая заметка с фото: файл в общей папке, вставка в тексте, хвоста и каталога нет', () async {
    writeAttachmentSetting(root, 'Вложения');
    await folder('f', 'Stowa');
    await item('n', title: 'Купить молоко', body: 'Купить молоко\n\n![[IMG_1.jpg]]', folderId: 'f');
    await attach('n', '.stowa/incoming/n/0_IMG_1.jpg');
    await writer().drain();
    expect(file('Вложения/IMG_1.jpg').existsSync(), isTrue);
    expect(await paths('n'), ['Вложения/IMG_1.jpg']);
    final text = file('Stowa/Купить молоко.md').readAsStringSync();
    expect('![[IMG_1.jpg]]'.allMatches(text), hasLength(1));
    expect(text.trimRight().endsWith('![[IMG_1.jpg]]'), isTrue);
    expect(Directory(p.join(root.path, 'Stowa', 'Купить молоко')).existsSync(), isFalse);
  });

  test('одно фото без текста в папке — голый файл с именем камеры, без .md', () async {
    writeAttachmentSetting(root, 'Вложения');
    await folder('f', 'Stowa');
    await item('n', title: 'Фото от 20 августа', folderId: 'f', auto: true, kind: ItemKind.image);
    await attach('n', '.stowa/incoming/n/0_IMG_2.jpg');
    await writer().drain();
    expect(file('Stowa/IMG_2.jpg').existsSync(), isTrue);
    expect(file('Stowa/Фото от 20 августа.md').existsSync(), isFalse);
    expect(await mapped('n'), 'Stowa/IMG_2.jpg');
    expect(await paths('n'), ['Stowa/IMG_2.jpg']);
    // сверка не плодит из него вторую заметку
    await reader().reconcile();
    expect(await db.select(db.items).get(), hasLength(1));
  });

  test('фото без текста без папки — заметка-вставка в корне, сам файл во «Вложениях»', () async {
    writeAttachmentSetting(root, 'Вложения');
    await item('n', title: 'Фото от 20 августа', auto: true, kind: ItemKind.image);
    await attach('n', '.stowa/incoming/n/0_IMG_3.jpg');
    await writer().drain();
    expect(file('Вложения/IMG_3.jpg').existsSync(), isTrue);
    expect(file('IMG_3.jpg').existsSync(), isFalse);
    expect(file('Фото от 20 августа.md').readAsStringSync(), contains('![[IMG_3.jpg]]'));
  });

  test('метка у голого файла — рядом .md со вставкой, файл на месте', () async {
    await folder('f', 'Stowa');
    await item('n', title: 'Фото от 20 августа', folderId: 'f', auto: true, kind: ItemKind.image);
    await attach('n', '.stowa/incoming/n/0_IMG_4.jpg');
    await writer().drain();
    expect(await mapped('n'), 'Stowa/IMG_4.jpg');
    await db.into(db.tags).insert(TagsCompanion.insert(id: 't', name: 'закат', createdAt: now));
    await db.into(db.itemTags).insert(ItemTagsCompanion.insert(itemId: 'n', tagId: 't', source: TagSource.user));
    await writer().drain();
    expect(file('Stowa/IMG_4.jpg').existsSync(), isTrue);
    final text = file('Stowa/Фото от 20 августа.md').readAsStringSync();
    expect(text, contains('![[IMG_4.jpg]]'));
    expect(text, contains('закат'));
    expect(await mapped('n'), 'Stowa/Фото от 20 августа.md');
  });

  test('имя уже занято в хранилище — «IMG_1 2.jpg», вставка следом', () async {
    writeAttachmentSetting(root, 'Вложения');
    await item('other', title: 'Другая', body: 'Другая');
    await attach('other', 'Где-то/IMG_1.jpg', id: 'o');
    await item('n', title: 'Купить', body: 'Купить\n\n![[IMG_1.jpg]]');
    await attach('n', '.stowa/incoming/n/0_IMG_1.jpg');
    await writer().drain();
    expect(await paths('n'), ['Вложения/IMG_1 2.jpg']);
    expect(file('Купить.md').readAsStringSync(), contains('![[IMG_1 2.jpg]]'));
    expect(file('Где-то/IMG_1.jpg').existsSync(), isTrue);
  });

  test('корзина: своё вложение уходит с заметкой и возвращается, общее остаётся', () async {
    writeAttachmentSetting(root, 'Вложения');
    await item('n', title: 'Своя', body: 'Своя\n\n![[a.jpg]]\n![[b.jpg]]');
    await attach('n', 'Вложения/a.jpg');
    await attach('n', 'Вложения/b.jpg', id: 'b', position: 1);
    await item('m', title: 'Чужая', body: 'Чужая\n\n![[b.jpg]]');
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'mb', itemId: 'm', path: 'Вложения/b.jpg', mime: 'image/jpeg', size: 3));
    await writer().drain();
    await (db.update(db.items)..where((t) => t.id.equals('n'))).write(ItemsCompanion(deletedAt: Value(now)));
    await writer().drain();
    expect(file('.trash/Вложения/a.jpg').existsSync(), isTrue);
    expect(file('Вложения/a.jpg').existsSync(), isFalse);
    expect(file('Вложения/b.jpg').existsSync(), isTrue);
    await (db.update(db.items)..where((t) => t.id.equals('n'))).write(const ItemsCompanion(deletedAt: Value(null)));
    await writer().drain();
    expect(file('Вложения/a.jpg').existsSync(), isTrue);
    expect(await paths('n'), ['Вложения/a.jpg', 'Вложения/b.jpg']);
  });

  test('старая заметка с каталогом «Заметка/»: правка ничего не переносит', () async {
    note('Дом/Плитка.md', 'Плитка\n\n![[Дом/Плитка/a.jpg]]\n');
    put('Дом/Плитка/a.jpg');
    await reader().reconcile();
    final id = (await only()).id;
    await (db.update(db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(body: Value('Плитка белая')));
    await writer().drain();
    expect(file('Дом/Плитка/a.jpg').existsSync(), isTrue);
    expect(file('Дом/Плитка.md').readAsStringSync(), contains('![[Дом/Плитка/a.jpg]]'));
  });

  test('заметка Obsidian со ссылкой в «Изображения»: правка не уносит картинку', () async {
    put('.obsidian/app.json', utf8.encode(jsonEncode({'attachmentFolderPath': 'Изображения'})));
    note('Дом/План.md', 'План\n![[c.jpg]]\n');
    put('Изображения/c.jpg');
    await reader().reconcile();
    final id = (await only()).id;
    await (db.update(db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(body: Value('План новый\n![[c.jpg]]')));
    await writer().drain();
    expect(file('Изображения/c.jpg').existsSync(), isTrue);
    expect(Directory(p.join(root.path, 'Дом', 'План')).existsSync(), isFalse);
    expect(file('Дом/План.md').readAsStringSync(), contains('![[c.jpg]]'));
  });

  test('хранилище без Obsidian и без выбора: запись сама ставит «Вложения» на языке приложения', () async {
    await item('n', title: 'Купить', body: 'Купить\n\n![[IMG_5.jpg]]');
    await attach('n', '.stowa/incoming/n/0_IMG_5.jpg');
    await VaultWriter(db, root: root, clock: () => now, attachmentsDefault: () => 'Вложения').drain();
    expect(readAttachmentSetting(root), (obsidian: false, setting: 'Вложения'));
    expect(await paths('n'), ['Вложения/IMG_5.jpg']);
  });

  test('с Obsidian без ключа запись умолчание не ставит: решает Obsidian', () async {
    put('.obsidian/app.json', utf8.encode(jsonEncode({'promptDelete': false})));
    await item('n', title: 'Купить', body: 'Купить\n\n![[IMG_6.jpg]]');
    await attach('n', '.stowa/incoming/n/0_IMG_6.jpg');
    await VaultWriter(db, root: root, clock: () => now, attachmentsDefault: () => 'Вложения').drain();
    expect(readAttachmentSetting(root), (obsidian: true, setting: null));
    expect(await paths('n'), ['IMG_6.jpg']);
    expect(jsonDecode(file('.obsidian/app.json').readAsStringSync()), {'promptDelete': false});
  });

  // копия College 16.11: правка текста переименовывала файл — ссылки [[…]] в Obsidian ломались
  test('свойство title: из Obsidian и длинное имя — правка текста файл не переименовывает', () async {
    note('Проекты/Речь защита.md', '---\ntitle: Защита курсовой\n---\nТекст\n');
    // длиннее 200 байт, которые даёт имя из названия, но в пределе диска 255
    final long = 'Семинар №1. ${'Очень длинное название семинара по этике ' * 2}ааааааааааааааааааааконец';
    note('Этика/$long.md', 'Текст\n');
    await reader().reconcile();
    for (final item in await db.select(db.items).get()) {
      await (db.update(db.items)..where((t) => t.id.equals(item.id))).write(ItemsCompanion(body: Value('${item.body}\nещё')));
    }
    await writer().drain();
    expect(file('Проекты/Речь защита.md').readAsStringSync(), contains('ещё'));
    expect(file('Проекты/Защита курсовой.md').existsSync(), isFalse);
    expect(file('Этика/$long.md').readAsStringSync(), contains('ещё'));
    expect(Directory(p.join(root.path, 'Этика')).listSync(), hasLength(1));
    // а сменил название в Stowa — файл переименовался
    final id = (await (db.select(db.vaultFiles)..where((t) => t.path.equals('Проекты/Речь защита.md'))).getSingle()).itemId;
    await (db.update(db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(title: Value('Речь на защите')));
    await writer().drain();
    expect(file('Проекты/Речь на защите.md').existsSync(), isTrue);
  });

  // хозяин 16.11: «если менять название файлов, то менять во ВСЕХ местах, где он упомянут»
  test('переименовал заметку в Stowa — ссылки на неё в других заметках и на холсте следуют', () async {
    note('Проекты/Речь.md', 'Речь\n');
    note('План.md', 'см. [[Речь]] и [[Проекты/Речь#Вступление|вступление]], [ссылка](Проекты/Речь.md)\n');
    note('Доска.canvas', '{"nodes":[{"id":"a","type":"file","file":"Проекты/Речь.md","x":0,"y":0,"width":400,"height":400}],"edges":[]}');
    note('Чужое.md', 'про [[Речка]]\n');
    await reader().reconcile();
    final id = (await (db.select(db.vaultFiles)..where((t) => t.path.equals('Проекты/Речь.md'))).getSingle()).itemId;
    final before = file('Чужое.md').readAsStringSync();
    await (db.update(db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(title: Value('Речь на защите')));
    await writer().drain();
    expect(file('Проекты/Речь на защите.md').existsSync(), isTrue);
    expect(file('План.md').readAsStringSync(), contains('см. [[Речь на защите]] и [[Проекты/Речь на защите#Вступление|вступление]], [ссылка](Проекты/Речь на защите.md)'));
    expect(file('Доска.canvas').readAsStringSync(), contains('"file":"Проекты/Речь на защите.md"'));
    expect(file('Чужое.md').readAsStringSync(), before);
  });

  // копия College 16.11: ссылки стоят в свойствах («Предмет: "[[Курсы/Военка|Военка]]"»)
  test('ссылки в свойствах шапки тоже следуют за переименованным', () async {
    note('Курсы/Военка.md', 'Военка\n');
    note('Тема.md', '---\nПредмет: "[[Курсы/Военка|🎖️ Военка]]"\nСвязи:\n  - "[[Военка]]"\n---\nТема\n');
    await reader().reconcile();
    final id = (await (db.select(db.vaultFiles)..where((t) => t.path.equals('Курсы/Военка.md'))).getSingle()).itemId;
    await (db.update(db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(title: Value('Военная подготовка')));
    await writer().drain();
    final text = file('Тема.md').readAsStringSync();
    expect(text, contains('[[Курсы/Военная подготовка|🎖️ Военка]]'));
    expect(text, contains('[[Военная подготовка]]'));
    expect(text, isNot(contains('[[Военка]]')));
  });

  // копия College 16.11: «ЗОМП.md» рядом с папкой «ЗОМП/» с конспектами — правка дописывала
  // конспекты хвостом ![[…]] в заметку-папку
  test('заметка-папка Obsidian: конспекты и картинки папки — не её вложения', () async {
    note('Военка/ЗОМП.md', 'ЗОМП\n\n[[Ядерное оружие]]\n');
    note('Военка/ЗОМП/Ядерное оружие.md', 'Ядерное\n');
    put('Военка/ЗОМП/схема.png');
    await reader().reconcile();
    final zomp = (await (db.select(db.vaultFiles)..where((t) => t.path.equals('Военка/ЗОМП.md'))).getSingle()).itemId;
    expect(await paths(zomp), isEmpty);
    await (db.update(db.items)..where((t) => t.id.equals(zomp))).write(const ItemsCompanion(body: Value('ЗОМП\n\n[[Ядерное оружие]]\nещё')));
    await writer().drain();
    expect(file('Военка/ЗОМП.md').readAsStringSync(), isNot(contains('![[')));
  });

  test('старый каталог вложений Stowa без заметок внутри — по-прежнему вложения', () async {
    note('Дом/Плитка.md', 'Плитка\n');
    put('Дом/Плитка/a.jpg');
    await reader().reconcile();
    expect(await paths((await only()).id), ['Дом/Плитка/a.jpg']);
  });

  test('файл ещё копируется — голую заметку не пишут раньше файла', () async {
    await folder('f', 'Stowa');
    await item('n', title: 'Фото от 20 августа', folderId: 'f', auto: true, kind: ItemKind.image);
    await db.into(db.fileJobs).insert(FileJobsCompanion.insert(id: 'j', itemId: 'n', position: 0, source: '/tmp/IMG.jpg', target: '.stowa/incoming/n/0_IMG.jpg', mime: 'image/jpeg', size: 3, createdAt: now));
    await writer().drain();
    expect(file('Stowa/Фото от 20 августа.md').existsSync(), isFalse);
  });

  test('файл в общей папке, на который ссылается заметка, — не заметка-файл', () async {
    put('.obsidian/app.json', utf8.encode(jsonEncode({'attachmentFolderPath': 'Изображения'})));
    note('Дом/План.md', 'План\n![[e.jpg]]\n');
    put('Изображения/e.jpg');
    await reader().reconcile();
    await reader().reconcile();
    expect(await db.select(db.items).get(), hasLength(1));
    expect(await db.select(db.folders).get(), hasLength(1));
  });
}
