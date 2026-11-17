import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/services/sync/sync_crypto.dart';

void main() {
  test('один файл при разной записи кириллицы и регистре', () {
    final key = VaultKey.generate();
    const nfc = 'Учёба/Заметка.md';
    final nfd = 'Учёба/Заметка.md'.replaceAll('ё', 'ё');
    expect(nfd, isNot(nfc));
    expect(key.fileId(nfd), key.fileId(nfc));
    expect(key.fileId('учёба/заметка.md'), key.fileId(nfc));
    expect(key.fileId('Другая.md'), isNot(key.fileId(nfc)));
    expect(key.fileId(nfc).length, 32);
    expect(normalizePath(nfd), nfc);
  });

  test('у разных хранилищ разные номера одного пути', () {
    expect(VaultKey.generate().fileId('a.md'), isNot(VaultKey.generate().fileId('a.md')));
  });

  test('заголовок открывается своим ключом', () async {
    final key = VaultKey.generate();
    const meta = FileMeta(path: 'Папка/Фото.jpg', mtime: 1700000000000, size: 42, hash: 'abc');
    final sealed = await key.sealMeta(meta);
    expect(sealed, isNot(contains('Папка')));
    final opened = await key.openMeta(sealed);
    expect(opened.path, meta.path);
    expect(opened.mtime, meta.mtime);
    expect(opened.size, 42);
    expect(opened.hash, 'abc');
    expect(opened.v, 1);
    expect(opened.chunk, syncChunk);
    expect(opened.deleted, isFalse);
    await expectLater(VaultKey.generate().openMeta(sealed), throwsA(isA<SyncSealBroken>()));
  });

  test('часть открывается своим ключом, подмена ловится', () async {
    final key = VaultKey.generate();
    final plain = List<int>.generate(1000, (i) => i % 251);
    final box = await key.sealChunk(plain);
    expect(await key.openChunk(box), plain);
    final broken = [...box]..[20] ^= 1;
    await expectLater(key.openChunk(broken), throwsA(isA<SyncSealBroken>()));
    await expectLater(VaultKey.generate().openChunk(box), throwsA(isA<SyncSealBroken>()));
  });

  test('одна и та же часть шифруется одинаково, разные — по-разному', () async {
    final key = VaultKey.generate();
    expect(await key.sealChunk([1, 2, 3]), await key.sealChunk([1, 2, 3]));
    expect(await key.sealChunk([1, 2, 3]), isNot(await key.sealChunk([1, 2, 4])));
    expect(await key.sealMeta(const FileMeta(path: 'a', mtime: 1, size: 1, hash: 'h')), isNot(await key.sealMeta(const FileMeta(path: 'a', mtime: 1, size: 1, hash: 'h'))));
  });

  test('ключ переживает перевод в байты', () {
    final key = VaultKey.generate();
    expect(VaultKey(key.bytes).fileId('x.md'), key.fileId('x.md'));
  });
}
