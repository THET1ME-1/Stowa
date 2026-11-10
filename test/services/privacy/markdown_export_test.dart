import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/settings_repository.dart' show MemoryKeyStore;
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/privacy/markdown_export.dart';
import 'package:stowa/services/privacy/privacy_service.dart';
import 'package:stowa/services/privacy/seal_crypto.dart';
import 'package:stowa/services/privacy/sealed_space.dart';
import 'package:stowa/services/vault/vault_reader.dart';
import 'package:stowa/services/vault/vault_writer.dart';

void main() {
  final now = DateTime(2026, 11, 10, 12);
  late AppDatabase db;
  late Directory root;
  late Directory vault;
  late Directory out;
  late PrivacyService privacy;

  setUp(() async {
    db = AppDatabase.memory();
    root = Directory.systemTemp.createTempSync('stowa_export');
    vault = Directory(p.join(root.path, 'vault'))..createSync();
    out = Directory(p.join(root.path, 'out'))..createSync();
    final app = Directory(p.join(root.path, 'app'))..createSync();
    SealedSpace.configure(Directory(p.join(app.path, 'sealed-open')));
    privacy = PrivacyService(db: db, vault: vault, appData: app, flush: () => VaultWriter(db, root: vault, clock: () => now).drain(), fingerprintKey: MemoryKeyStore());
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'home', shape: 'pill'));
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'secret', name: 'Секрет', icon: 'lock', shape: 'pill'));
    await db.into(db.items).insert(
      ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Лампочки', body: const Value('Лампочки в коридор'), folderId: const Value('home'), createdAt: now, updatedAt: now),
    );
    await db.into(db.items).insert(
      ItemsCompanion.insert(id: 'b', kind: ItemKind.note, title: 'План', body: const Value('План\nпобег через окно'), folderId: const Value('secret'), createdAt: now, updatedAt: now),
    );
    await db.into(db.tags).insert(TagsCompanion.insert(id: 't', name: 'тайна', createdAt: now));
    await db.into(db.itemTags).insert(ItemTagsCompanion.insert(itemId: 'b', tagId: 't', source: TagSource.user));
    File(p.join(vault.path, 'Секрет/План/карта.jpg'))
      ..createSync(recursive: true)
      ..writeAsStringSync('картинка');
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'att', itemId: 'b', path: 'Секрет/План/карта.jpg', mime: 'image/jpeg', size: 8));
    await VaultWriter(db, root: vault, clock: () => now).drain();
    await privacy.settle();
    await privacy.createCode('123456', kdf: const KdfSettings(memoryKib: 256, passes: 1));
    await privacy.hideFolder('secret');
  });
  tearDown(() async {
    SealedSpace.configure(null);
    await db.close();
    root.deleteSync(recursive: true);
  });

  List<String> files(Directory dir) => [for (final file in dir.listSync(recursive: true).whereType<File>()) p.relative(file.path, from: dir.path)]..sort();

  test('выгрузка без скрытого: заметки и служебное, без шифра и замка', () async {
    final done = await MarkdownExport(db, vault: vault, clock: () => now).export(out);
    expect(p.basename(done.path), 'Stowa-2026-11-10');
    final names = files(done);
    expect(names, contains('Дом/Лампочки.md'));
    expect(names.any((name) => name.contains('sealed') || name.endsWith('lock.json')), isFalse);
    expect(names.any((name) => name.contains('Секрет')), isFalse);
  });

  test('со скрытым: скрытые заметки открытыми файлами в своих папках, база из выгрузки та же', () async {
    final done = await MarkdownExport(db, vault: vault, clock: () => now).export(out, includeHidden: true);
    expect(File(p.join(done.path, 'Секрет/План.md')).readAsStringSync(), contains('побег через окно'));
    expect(File(p.join(done.path, 'Секрет/План/карта.jpg')).readAsStringSync(), 'картинка');

    // выгрузку открывают как хранилище: всё на месте
    final fresh = AppDatabase.memory();
    addTearDown(fresh.close);
    SealedSpace.configure(null);
    await VaultReader(fresh, root: done, clock: () => now).rebuild();
    final items = {for (final row in await fresh.select(fresh.items).get()) row.title: row};
    expect(items.keys.toSet(), {'Лампочки', 'План'});
    expect(items['План']!.body, 'План\nпобег через окно');
    expect([for (final row in await fresh.select(fresh.tags).get()) row.name], ['тайна']);
    final attachment = await fresh.select(fresh.attachments).getSingle();
    expect(attachment.path, 'Секрет/План/карта.jpg');
  });

  test('повторная выгрузка в тот же день не затирает прежнюю', () async {
    final first = await MarkdownExport(db, vault: vault, clock: () => now).export(out);
    final second = await MarkdownExport(db, vault: vault, clock: () => now).export(out);
    expect(first.path, isNot(second.path));
    expect(p.basename(second.path), 'Stowa-2026-11-10 2');
  });
}
