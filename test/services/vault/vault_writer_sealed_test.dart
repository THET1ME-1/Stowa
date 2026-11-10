import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/privacy/sealed_space.dart';
import 'package:stowa/services/vault/vault_layout.dart';
import 'package:stowa/services/vault/vault_writer.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late Directory vault;
  late Directory open;
  final now = DateTime(2026, 11, 10, 10);
  VaultWriter writer() => VaultWriter(db, root: vault, clock: () => now);

  setUp(() async {
    db = AppDatabase.memory();
    root = Directory.systemTemp.createTempSync('stowa_sealed_writer');
    vault = Directory(p.join(root.path, 'vault'))..createSync();
    open = Directory(p.join(root.path, 'sealed-open'))..createSync();
    SealedSpace.configure(open);
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'home', shape: 'pill'));
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'secret', name: 'Секрет', icon: 'lock', shape: 'pill', hidden: const Value(true)));
    await db.into(db.items).insert(
      ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'План', body: const Value('План побега через окно'), folderId: const Value('home'), createdAt: now, updatedAt: now),
    );
    void put(String relative) => File(p.join(vault.path, relative))
      ..createSync(recursive: true)
      ..writeAsStringSync('байты $relative');
    put('Дом/План/карта.jpg');
    put('.stowa/covers/a.jpg');
    put('.stowa/frames/a/0.jpg');
    put('.stowa/pages/a.html.gz');
    put('.stowa/articles/a/0.img');
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'att', itemId: 'a', path: 'Дом/План/карта.jpg', mime: 'image/jpeg', size: 4));
    await (db.update(db.items)..where((t) => t.id.equals('a'))).write(const ItemsCompanion(coverPath: Value('.stowa/covers/a.jpg')));
    await db.into(db.facts).insert(FactsCompanion.insert(id: 'f', itemId: 'a', extractor: 'video', kind: FactKind.frame, value: '.stowa/frames/a/0.jpg'));
    await writer().drain();
  });
  tearDown(() async {
    SealedSpace.configure(null);
    await db.close();
    root.deleteSync(recursive: true);
  });

  Future<void> moveTo(String folder) => (db.update(db.items)..where((t) => t.id.equals('a'))).write(ItemsCompanion(folderId: Value(folder)));
  Item? item;
  Future<Item> load() async => item = await (db.select(db.items)..where((t) => t.id.equals('a'))).getSingle();
  List<String> files(Directory dir) => [for (final file in dir.listSync(recursive: true).whereType<File>()) p.relative(file.path, from: dir.path)]..sort();

  test('заметку переложили в скрытую папку: из хранилища ушло всё, файлы — в открытой папке', () async {
    expect(File(p.join(vault.path, 'Дом/План.md')).existsSync(), isTrue);
    await moveTo('secret');
    await writer().drain();

    // в хранилище не осталось ни заметки, ни её файлов, ни имени папки
    for (final file in vault.listSync(recursive: true).whereType<File>()) {
      expect(file.readAsStringSync().contains('побега'), isFalse, reason: file.path);
      expect(file.readAsStringSync().contains('Секрет'), isFalse, reason: file.path);
      expect(file.path.contains('План'), isFalse, reason: file.path);
      expect(file.path.contains('/a.') || file.path.contains('/a/'), isFalse, reason: file.path);
    }
    expect(await db.select(db.vaultFiles).get(), isEmpty);
    expect(files(open), ['.stowa/articles/a/0.img', '.stowa/covers/a.jpg', '.stowa/frames/a/0.jpg', '.stowa/pages/a.html.gz', 'files/a/карта.jpg']);
    expect((await db.select(db.attachments).getSingle()).path, '${open.path}/files/a/карта.jpg');
    expect((await load()).coverPath, '${open.path}/.stowa/covers/a.jpg');
    expect((await db.select(db.facts).getSingle()).value, '${open.path}/.stowa/frames/a/0.jpg');
    // новое производное — сразу в открытую папку
    expect(SealedSpace.holds('a'), isTrue);
    expect(pageCopyFile('a'), '${open.path}/.stowa/pages/a.html.gz');
    expect(item!.body, 'План побега через окно');
  });

  test('обратно в обычную папку: заметка снова файлом, файлы вернулись, пути от хранилища', () async {
    await moveTo('secret');
    await writer().drain();
    await moveTo('home');
    await writer().drain();

    expect(File(p.join(vault.path, 'Дом/План.md')).readAsStringSync(), contains('План побега через окно'));
    expect(files(open), isEmpty);
    expect((await db.select(db.attachments).getSingle()).path, 'Дом/План/карта.jpg');
    expect(File(p.join(vault.path, 'Дом/План/карта.jpg')).existsSync(), isTrue);
    expect((await load()).coverPath, '.stowa/covers/a.jpg');
    expect((await db.select(db.facts).getSingle()).value, '.stowa/frames/a/0.jpg');
    for (final relative in ['.stowa/covers/a.jpg', '.stowa/frames/a/0.jpg', '.stowa/pages/a.html.gz', '.stowa/articles/a/0.img']) {
      expect(File(p.join(vault.path, relative)).existsSync(), isTrue, reason: relative);
    }
    expect(SealedSpace.holds('a'), isFalse);
    expect(File(p.join(vault.path, factsFile('a'))).existsSync(), isTrue);
  });

  test('стёртая насовсем скрытая заметка уносит свои файлы из открытой папки', () async {
    await moveTo('secret');
    await writer().drain();
    await (db.delete(db.attachments)..where((t) => t.itemId.equals('a'))).go();
    await (db.delete(db.items)..where((t) => t.id.equals('a'))).go();
    await writer().drain();
    expect(files(open), isEmpty);
  });
}
