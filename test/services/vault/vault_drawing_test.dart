import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/vault/vault_reader.dart';
import 'package:stowa/services/vault/vault_writer.dart';

// Рисунок Excalidraw в хранилище: Stowa показывает его и переносит, но байты файла не трогает —
// правка мимо Obsidian испортила бы рисунок
void main() {
  late AppDatabase db;
  late Directory root;
  final now = DateTime(2026, 11, 15, 10);
  final sample = File('test/fixtures/excalidraw/Схема.excalidraw.md').readAsStringSync();

  setUp(() async {
    db = AppDatabase.memory();
    root = Directory.systemTemp.createTempSync('stowa_drawing');
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

  test('рисунок — своя заметка: подписи в тексте для поиска, файл целиком, id в файл не пишется', () async {
    put('Учёба/Схема.excalidraw.md', File('test/fixtures/excalidraw/Схема.excalidraw.md').readAsBytesSync());
    await reader().reconcile();
    final drawing = (await items()).single;
    expect(drawing.kind, ItemKind.drawing);
    expect(drawing.title, 'Схема');
    expect(drawing.body, 'Вход\nf(x) = x²\nвторая строка');
    expect(drawing.document, sample);
    expect(file('Учёба/Схема.excalidraw.md').readAsStringSync(), sample);
  });

  test('картинка рисунка и его готовая копия — не отдельные заметки', () async {
    put('Учёба/Схема.excalidraw.md', File('test/fixtures/excalidraw/Схема.excalidraw.md').readAsBytesSync());
    // Obsidian кладёт вставленные картинки в общую папку вложений
    put('Вложения/Фото схемы.png', List.filled(40, 7));
    put('Учёба/Схема.excalidraw.svg', '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"/>'.codeUnits);
    await reader().reconcile();
    expect((await items()).map((item) => item.kind), [ItemKind.drawing]);
  });

  test('переименовал и переложил в Stowa — файл переехал байт в байт', () async {
    put('Учёба/Схема.excalidraw.md', File('test/fixtures/excalidraw/Схема.excalidraw.md').readAsBytesSync());
    await reader().reconcile();
    final id = (await items()).single.id;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'folder', shape: 'squircle'));
    await (db.update(db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(title: Value('План кухни'), folderId: Value('home')));
    await writer().drain();
    expect(file('Учёба/Схема.excalidraw.md').existsSync(), isFalse);
    expect(file('Дом/План кухни.excalidraw.md').readAsStringSync(), sample);
  });

  test('рисунок, прочитанный прежней Stowa заметкой, перечитывается рисунком', () async {
    put('Схема.excalidraw.md', File('test/fixtures/excalidraw/Схема.excalidraw.md').readAsBytesSync());
    await reader().reconcile();
    final id = (await items()).single.id;
    // так его оставила версия без рисунков: обычная заметка с сырым текстом
    await db.customStatement("UPDATE items SET kind = 'note', document = NULL WHERE id = ?", [id]);
    // правка теста — не правка человека: в очереди записи ей не место
    await db.delete(db.vaultQueue).go();
    await reader().reconcile();
    final drawing = (await items()).single;
    expect((drawing.id, drawing.kind, drawing.document), (id, ItemKind.drawing, sample));
  });
}
