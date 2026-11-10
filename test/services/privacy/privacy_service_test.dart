import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/settings_repository.dart' show MemoryKeyStore;
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/privacy/privacy_service.dart';
import 'package:stowa/services/privacy/seal_crypto.dart';
import 'package:stowa/services/privacy/sealed_space.dart';
import 'package:stowa/services/vault/vault_writer.dart';

void main() {
  const fast = KdfSettings(memoryKib: 256, passes: 1);
  final now = DateTime(2026, 11, 10, 12);
  late AppDatabase db;
  late Directory root;
  late Directory vault;
  late Directory appData;
  late MemoryKeyStore fingerprint;

  PrivacyService service({int processId = 100}) => PrivacyService(
    db: db,
    vault: vault,
    appData: appData,
    flush: () => VaultWriter(db, root: vault, clock: () => now).drain(),
    fingerprintKey: fingerprint,
    processId: processId,
  );

  setUp(() async {
    db = AppDatabase.memory();
    root = Directory.systemTemp.createTempSync('stowa_privacy');
    vault = Directory(p.join(root.path, 'vault'))..createSync();
    appData = Directory(p.join(root.path, 'app'))..createSync();
    fingerprint = MemoryKeyStore();
    SealedSpace.configure(Directory(p.join(appData.path, 'sealed-open')));
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'home', shape: 'pill'));
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'secret', name: 'Секрет', icon: 'lock', shape: 'pill'));
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'deep', name: 'Глубже', icon: 'lock', shape: 'pill', parentId: const Value('secret')));
    Future<void> note(String id, String folder, String body, {DateTime? remind}) => db.into(db.items).insert(
      ItemsCompanion.insert(id: id, kind: ItemKind.note, title: body.split(' ').first, body: Value(body), folderId: Value(folder), createdAt: now, updatedAt: now, reminderAt: Value(remind)),
    );
    await note('a', 'home', 'Лампочки в коридор');
    await note('b', 'secret', 'План побега через окно', remind: DateTime(2026, 11, 12, 9));
    await note('c', 'deep', 'Ключ под ковриком');
    File(p.join(vault.path, 'Секрет/План/карта.jpg'))
      ..createSync(recursive: true)
      ..writeAsStringSync('картинка карты');
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(id: 'att', itemId: 'b', path: 'Секрет/План/карта.jpg', mime: 'image/jpeg', size: 14));
    await VaultWriter(db, root: vault, clock: () => now).drain();
  });
  tearDown(() async {
    SealedSpace.configure(null);
    await db.close();
    root.deleteSync(recursive: true);
  });

  // ни одного открытого следа скрытого в хранилище: ни текста, ни имён
  void expectNothingPlain() {
    for (final dir in vault.listSync(recursive: true).whereType<Directory>()) {
      for (final secret in ['Секрет', 'Глубже', 'План']) {
        expect(dir.path.contains(secret), isFalse, reason: dir.path);
      }
    }
    for (final file in vault.listSync(recursive: true).whereType<File>()) {
      final text = String.fromCharCodes(file.readAsBytesSync());
      for (final secret in ['побега', 'ковриком', 'Секрет', 'Глубже', 'карты']) {
        expect(text.contains(secret), isFalse, reason: '${file.path}: $secret');
        expect(file.path.contains(secret), isFalse, reason: file.path);
      }
    }
  }

  Future<List<String>> found(String word) => db.searchIds(word);

  test('скрыть, закрыть, открыть кодом: в закрытом ни строк, ни открытых файлов; открытое — как было', () async {
    final privacy = service();
    await privacy.settle();
    await privacy.createCode('123456', kdf: fast);
    await privacy.hideFolder('secret');
    expect(await found('ковриком'), ['c']);
    expect(File(p.join(vault.path, 'Секрет/План.md')).existsSync(), isFalse);

    await privacy.close();
    expect(privacy.isOpen, isFalse);
    expect(await found('побега'), isEmpty);
    expect([for (final row in await db.select(db.folders).get()) row.id], ['home']);
    expect(privacy.openDir.existsSync(), isFalse);
    expectNothingPlain();
    expect(await found('коридор'), ['a']);
    // напоминание звенит и закрытым: время без текста
    expect([for (final one in await privacy.sealedReminders(now)) one.itemId], ['b']);

    expect(await privacy.openWithCode('000000'), isFalse);
    expect(await privacy.openWithCode('123456'), isTrue);
    expect(await found('побега'), ['b']);
    expect(await found('ковриком'), ['c']);
    final attachment = await db.select(db.attachments).getSingle();
    expect(File(attachment.path).readAsStringSync(), 'картинка карты');
    expect(attachment.path, startsWith(privacy.openDir.path));
    expect((await (db.select(db.folders)..where((t) => t.id.equals('deep'))).getSingle().then((row) => row.parentId)), 'secret');
    expect(await privacy.sealedReminders(now), isEmpty);
  });

  test('правка в открытом переживает закрытие; неизменённая картинка не перешифровывается', () async {
    final privacy = service();
    await privacy.settle();
    await privacy.createCode('123456', kdf: fast);
    await privacy.hideFolder('secret');
    await privacy.close();
    final sealedDir = Directory(p.join(vault.path, '.stowa', 'sealed'));
    Set<String> blobs() => {for (final file in sealedDir.listSync()) p.basename(file.path)};
    await privacy.openWithCode('123456');
    final before = blobs();

    await (db.update(db.items)..where((t) => t.id.equals('b'))).write(const ItemsCompanion(body: Value('План побега через крышу')));
    await privacy.close();
    expect(blobs().intersection(before), isNotEmpty);
    expectNothingPlain();
    await privacy.openWithCode('123456');
    expect(await found('крышу'), ['b']);
  });

  test('приложение убили при открытом скрытом: новый процесс запечатывает его без кода', () async {
    final first = service(processId: 1);
    await first.settle();
    await first.createCode('123456', kdf: fast);
    await first.hideFolder('secret');
    await (db.update(db.items)..where((t) => t.id.equals('c'))).write(const ItemsCompanion(body: Value('Ключ под цветком')));

    // «Поделиться» в том же процессе открытое не трогает
    await service(processId: 1).settle();
    expect(await found('цветком'), ['c']);

    final second = service(processId: 2);
    await second.settle();
    expect(await found('цветком'), isEmpty);
    expect(second.openDir.existsSync(), isFalse);
    expectNothingPlain();
    expect(await second.openWithCode('123456'), isTrue);
    expect(await found('цветком'), ['c']);
  });

  test('обрыв посреди открытия: копия цела, недооткрытое стирается', () async {
    final privacy = service();
    await privacy.settle();
    await privacy.createCode('123456', kdf: fast);
    await privacy.hideFolder('secret');
    await privacy.close();
    await privacy.openWithCode('123456');
    // как будто процесс умер, не дописав метку «open»
    File(p.join(appData.path, 'sealed-open.state')).writeAsStringSync('unsealed');

    final next = service(processId: 2);
    await next.settle();
    expect(await found('побега'), isEmpty);
    expect(await next.openWithCode('123456'), isTrue);
    expect(await found('побега'), ['b']);
  });

  test('вернуть папку из скрытых: заметки снова файлами, после закрытия ничего не прячется', () async {
    final privacy = service();
    await privacy.settle();
    await privacy.createCode('123456', kdf: fast);
    await privacy.hideFolder('secret');
    await privacy.close();
    await privacy.openWithCode('123456');
    await privacy.unhideFolder('secret');
    expect(File(p.join(vault.path, 'Секрет/План.md')).readAsStringSync(), contains('побега'));
    expect(File(p.join(vault.path, 'Секрет/План/карта.jpg')).existsSync(), isTrue);
    await privacy.close();
    expect(await found('побега'), ['b']);
    expect(await found('ковриком'), ['c']);
  });

  test('отпечаток открывает тем же ключом; «забыл код» стирает скрытое и замок', () async {
    final privacy = service();
    await privacy.settle();
    final keys = await privacy.createCode('123456', kdf: fast);
    await privacy.rememberForFingerprint(keys);
    await privacy.hideFolder('secret');
    await privacy.close();
    expect(await privacy.openWithFingerprint(), isTrue);
    expect(await found('побега'), ['b']);

    await privacy.forget();
    expect(privacy.hasCode, isFalse);
    expect(await privacy.hasSealed(), isFalse);
    expect(await found('побега'), isEmpty);
    expect(await privacy.hasFingerprintKey(), isFalse);
    expect(await found('коридор'), ['a']);
  });
}
