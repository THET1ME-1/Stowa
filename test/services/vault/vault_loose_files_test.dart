import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
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
    await (db.update(db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(title: Value('Годовой отчёт')));
    await writer().drain();
    expect(file('Книги/report.pdf').existsSync(), isFalse);
    expect(file('Книги/Годовой отчёт.pdf').existsSync(), isTrue);
    final attachment = (await (db.select(db.attachments)..where((t) => t.itemId.equals(id))).get()).single;
    expect(attachment.path, 'Книги/Годовой отчёт.pdf');
  });

  test('дописал к файлу текст — стала обычная заметка с этим файлом во вложениях', () async {
    put('Книги/report.pdf', List.filled(10, 1));
    await reader().reconcile();
    final id = (await items()).single.id;
    await (db.update(db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(body: Value('Прочитать до пятницы')));
    await writer().drain();
    expect(file('Книги/report.md').existsSync(), isTrue);
    final saved = (await ItemsRepository(db).get(id))!;
    expect(saved.attachments, hasLength(1));
    expect(file(saved.attachments.single.path).existsSync(), isTrue);
    expect(file('Книги/report.pdf').existsSync(), isFalse);
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
