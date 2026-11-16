import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/services/vault/vault_reader.dart';

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
