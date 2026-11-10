import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/services/privacy/seal_crypto.dart';

void main() {
  // в тестах ключ из кода считается на малой памяти: на телефоне 64 МБ
  const fast = KdfSettings(memoryKib: 256, passes: 1);
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('seal_crypto'));
  tearDown(() => dir.delete(recursive: true));

  test('верный код открывает ключи, неверный — нет', () async {
    final (lock, keys) = await createLock('123456', kdf: fast);
    final opened = await openLock(lock, '123456');
    expect(opened, isNotNull);
    expect(opened!.publicKey, keys.publicKey);
    expect(await openLock(lock, '123457'), isNull);
  });

  test('файл замка переживает запись в JSON и обратно', () async {
    final (lock, keys) = await createLock('246810', kdf: fast);
    final again = LockFile.fromJson(lock.toJson());
    expect((await openLock(again, '246810'))!.publicKey, keys.publicKey);
  });

  test('смена кода: новый открывает, старый больше нет, ключи те же', () async {
    final (lock, keys) = await createLock('111111', kdf: fast);
    final changed = await rewrapLock(lock, keys, '222222');
    expect(await openLock(changed, '111111'), isNull);
    expect((await openLock(changed, '222222'))!.publicKey, keys.publicKey);
  });

  test('закрытый ключ из хранилища отпечатка даёт те же ключи', () async {
    final (_, keys) = await createLock('135790', kdf: fast);
    final again = await keysFromPrivate(await keys.privateBytes());
    expect(again.publicKey, keys.publicKey);
  });

  for (final size in [0, 10, sealChunk, sealChunk + 1, sealChunk * 2 + 777]) {
    test('файл $size байт запечатывается и открывается тем же, с путём внутри', () async {
      final (_, keys) = await createLock('123456', kdf: fast);
      final random = Random(size);
      final bytes = List<int>.generate(size, (_) => random.nextInt(256));
      final source = File(p.join(dir.path, 'plain.bin'))..writeAsBytesSync(bytes);
      final sealed = File(p.join(dir.path, 'sealed.bin'));
      await sealFile(source, sealed, keys.publicKey, header: {'path': 'Секрет/План.md'});
      expect(sealed.readAsBytesSync(), isNot(bytes));
      final opened = File(p.join(dir.path, 'opened.bin'));
      final header = await openSealedFile(sealed, opened, keys);
      expect(header['path'], 'Секрет/План.md');
      expect(opened.readAsBytesSync(), bytes);
    });
  }

  test('подменённый байт и обрезанный хвост ловятся, чужой ключ не открывает', () async {
    final (_, keys) = await createLock('123456', kdf: fast);
    final (_, other) = await createLock('654321', kdf: fast);
    final source = File(p.join(dir.path, 'plain.bin'))..writeAsBytesSync(List<int>.filled(sealChunk + 100, 5));
    final sealed = File(p.join(dir.path, 'sealed.bin'));
    await sealFile(source, sealed, keys.publicKey, header: const {});
    final good = sealed.readAsBytesSync();
    final out = File(p.join(dir.path, 'out.bin'));

    final broken = [...good]..[good.length ~/ 2] ^= 1;
    sealed.writeAsBytesSync(broken);
    await expectLater(openSealedFile(sealed, out, keys), throwsA(isA<SealBroken>()));

    // без последнего куска: файл кончился раньше метки конца
    sealed.writeAsBytesSync(good.sublist(0, 5 + 32 + 4 + sealChunk + 16));
    await expectLater(openSealedFile(sealed, out, keys), throwsA(isA<SealBroken>()));

    sealed.writeAsBytesSync(good);
    await expectLater(openSealedFile(sealed, out, other), throwsA(isA<SealBroken>()));
    expect((await openSealedFile(sealed, out, keys)).isEmpty, isTrue);
  });

  test('короткие данные целиком: туда и обратно', () async {
    final (_, keys) = await createLock('123456', kdf: fast);
    final sealed = await sealBytes([1, 2, 3, 4], keys.publicKey);
    expect(await openSealedBytes(sealed, keys), [1, 2, 3, 4]);
  });
}
