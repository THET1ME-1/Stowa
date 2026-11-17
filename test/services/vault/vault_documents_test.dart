import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/json_canvas.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/vault/vault_reader.dart';
import 'package:stowa/services/vault/vault_writer.dart';

// холсты и базы Obsidian — файлами хранилища, как заметки
const _canvas = '{\n\t"nodes":[\n\t\t{"id":"a1","type":"text","text":"купить плитку","x":0,"y":0,"width":250,"height":60}\n\t],\n\t"edges":[]\n}';
const _base = 'filters: file.inFolder("Книги")\nviews:\n  - type: table\n    name: Все книги\n  - type: cards\n    name: Обложки\n';

void main() {
  late AppDatabase db;
  late Directory root;
  final now = DateTime(2026, 11, 15, 10);

  setUp(() async {
    db = AppDatabase.memory();
    root = Directory.systemTemp.createTempSync('stowa_docs');
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  VaultWriter writer() => VaultWriter(db, root: root, clock: () => now);
  VaultReader reader() => VaultReader(db, root: root, clock: () => now);
  File file(String relative) => File(p.join(root.path, relative));
  void put(String relative, String text) => file(relative)
    ..createSync(recursive: true)
    ..writeAsStringSync(text);
  void touch(String relative, String text) {
    file(relative).writeAsStringSync(text);
    file(relative).setLastModifiedSync(DateTime.now().add(const Duration(minutes: 5)));
  }

  Future<List<Item>> items() => db.select(db.items).get();

  test('холст из Obsidian — заметка-холст в своей папке, файл не тронут, текст карточек ищется', () async {
    put('Дом/План ремонта.canvas', _canvas);
    final scan = await reader().reconcile();
    expect(scan.added, 1);
    final one = (await items()).single;
    expect(one.kind, ItemKind.canvas);
    expect(one.title, 'План ремонта');
    expect(one.document, _canvas);
    expect(one.body, 'купить плитку');
    final folder = await (db.select(db.folders)..where((t) => t.id.equals(one.folderId!))).getSingle();
    expect(folder.name, 'Дом');
    // id в JSON не дописывается: файл байт в байт тот же
    expect(file('Дом/План ремонта.canvas').readAsStringSync(), _canvas);
    expect(await db.searchIds('плитку'), [one.id]);
  });

  test('правка холста снаружи — та же заметка, не копия', () async {
    put('План.canvas', _canvas);
    await reader().reconcile();
    final id = (await items()).single.id;
    touch('План.canvas', _canvas.replaceFirst('купить плитку', 'купить затирку'));
    final scan = await reader().reconcile();
    expect(scan.changed, 1);
    final all = await items();
    expect(all.single.id, id);
    expect(all.single.body, 'купить затирку');
  });

  test('база из Obsidian — заметка-база, в тексте названия видов', () async {
    put('Книги.base', _base);
    await reader().reconcile();
    final one = (await items()).single;
    expect(one.kind, ItemKind.base);
    expect(one.title, 'Книги');
    expect(one.document, _base);
    expect(one.body, 'Все книги\nОбложки');
  });

  test('холст, заведённый в Stowa, ложится файлом .canvas; правка и новое имя — в тот же файл', () async {
    final doc = CanvasDoc.empty().addText('Первая мысль', x: 0, y: 0);
    await db.into(db.items).insert(
      ItemsCompanion.insert(id: 'c', kind: ItemKind.canvas, title: 'Доска', body: const Value('Первая мысль'), document: Value(doc.encode()), createdAt: now, updatedAt: now),
    );
    await writer().drain();
    expect(file('Доска.canvas').readAsStringSync(), doc.encode());
    expect(file('Доска.md').existsSync(), isFalse);

    final next = doc.addText('Вторая', x: 300, y: 0);
    await (db.update(db.items)..where((t) => t.id.equals('c'))).write(ItemsCompanion(title: const Value('Доска идей'), document: Value(next.encode())));
    await writer().drain();
    expect(file('Доска.canvas').existsSync(), isFalse);
    expect(CanvasDoc.parse(file('Доска идей.canvas').readAsStringSync()).nodes, hasLength(2));

    // сверка после своей записи ничего не плодит
    await reader().reconcile();
    expect(await items(), hasLength(1));
  });

  test('заметку с холста переложили в другую папку — карточка холста идёт за ней', () async {
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'f', name: 'Физика', icon: 'folder', shape: 'pill'));
    await db.into(db.items).insert(ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Закон Ома', body: const Value('U = IR'), createdAt: now, updatedAt: now));
    await writer().drain();
    final path = (await (db.select(db.vaultFiles)..where((t) => t.itemId.equals('n'))).getSingle()).path;
    expect(path, 'Закон Ома.md');
    final doc = CanvasDoc.empty().addFile(path, x: 0, y: 0);
    await db.into(db.items).insert(
      ItemsCompanion.insert(id: 'c', kind: ItemKind.canvas, title: 'Доска', body: Value(doc.plainText()), document: Value(doc.encode()), createdAt: now, updatedAt: now),
    );
    await writer().drain();
    // угадыватель или ИИ разложил заметку по папке
    await (db.update(db.items)..where((t) => t.id.equals('n'))).write(const ItemsCompanion(folderId: Value('f')));
    await writer().drain();
    await writer().drain();
    expect(CanvasDoc.parse(file('Доска.canvas').readAsStringSync()).nodes.single.file, 'Физика/Закон Ома.md');
  });

  test('холст из Obsidian после нескольких сверок и записей — одна заметка', () async {
    put('Курсовая/Схема.canvas', _canvas);
    for (var pass = 0; pass < 3; pass++) {
      await reader().reconcile();
      await writer().drain();
    }
    expect(await items(), hasLength(1));
    expect(file('Курсовая/Схема.canvas').readAsStringSync(), _canvas);
  });

  test('холст из Obsidian правят в Stowa — пишется в тот же файл, копии «2» нет', () async {
    put('Курсовая/Схема курсовой работы.canvas', _canvas);
    await reader().reconcile();
    final one = (await items()).single;
    final next = CanvasDoc.parse(one.document!).addText('Новая', x: 300, y: 0);
    await (db.update(db.items)..where((t) => t.id.equals(one.id))).write(ItemsCompanion(document: Value(next.encode()), body: Value(next.plainText()), updatedAt: Value(now.add(const Duration(minutes: 1)))));
    await writer().drain();
    expect(Directory(p.join(root.path, 'Курсовая')).listSync().map((entry) => p.basename(entry.path)), ['Схема курсовой работы.canvas']);
    expect(CanvasDoc.parse(file('Курсовая/Схема курсовой работы.canvas').readAsStringSync()).nodes, hasLength(2));
    await reader().reconcile();
    expect(await items(), hasLength(1));
  });

  test('удалили файл холста снаружи — заметка уходит в корзину', () async {
    put('План.canvas', _canvas);
    await reader().reconcile();
    file('План.canvas').deleteSync();
    final scan = await reader().reconcile();
    expect(scan.removed, 1);
    expect((await items()).single.deletedAt, isNotNull);
  });
}
