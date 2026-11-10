/// Шифр скрытых папок. Код человека через Argon2id запирает закрытый ключ X25519;
/// файлы запечатываются открытым ключом, поэтому запечатать можно без кода, а открыть — только с ним.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Сколько открытого текста в одном куске запечатанного файла.
const sealChunk = 1024 * 1024;

const _magic = [0x53, 0x54, 0x57, 0x53, 0x01]; // «STWS», версия 1
const _info = 'stowa-seal-1';
const _macLength = 16;

/// Файл не открылся: подменён, обрезан или запечатан другим ключом.
class SealBroken implements Exception {
  const SealBroken(this.reason);

  final String reason;

  @override
  String toString() => 'SealBroken: $reason';
}

/// Цена ключа из кода. На телефоне 64 МБ и два прохода — около секунды.
class KdfSettings {
  const KdfSettings({this.memoryKib = 64 * 1024, this.passes = 2});

  final int memoryKib;
  final int passes;
}

/// `.stowa/lock.json`: соль и цена ключа, открытый ключ, закрытый — под кодом.
class LockFile {
  const LockFile({required this.salt, required this.kdf, required this.publicKey, required this.wrapped});

  final List<int> salt;
  final KdfSettings kdf;
  final List<int> publicKey;

  /// Закрытый ключ под ключом из кода: nonce, шифр и метка подряд.
  final List<int> wrapped;

  Map<String, Object?> toJson() => {
    'version': 1,
    'kdf': {'name': 'argon2id', 'memory_kib': kdf.memoryKib, 'passes': kdf.passes, 'salt': base64.encode(salt)},
    'public_key': base64.encode(publicKey),
    'wrapped_key': base64.encode(wrapped),
  };

  factory LockFile.fromJson(Map<String, Object?> json) {
    final kdf = json['kdf']! as Map<String, Object?>;
    return LockFile(
      salt: base64.decode(kdf['salt']! as String),
      kdf: KdfSettings(memoryKib: kdf['memory_kib']! as int, passes: kdf['passes']! as int),
      publicKey: base64.decode(json['public_key']! as String),
      wrapped: base64.decode(json['wrapped_key']! as String),
    );
  }
}

/// Пара ключей X25519, открытая кодом или отпечатком.
class SealKeys {
  SealKeys._(this._pair, this.publicKey);

  final SimpleKeyPair _pair;
  final List<int> publicKey;

  Future<List<int>> privateBytes() => _pair.extractPrivateKeyBytes();
}

final _x25519 = X25519();
final _aes = AesGcm.with256bits();

/// Ключ из кода считается в отдельном потоке: Argon2id на 64 МБ иначе подвесил бы экран.
/// Малая цена (тесты) — на месте: поддельное время виджет-теста поток не дождётся.
Future<SecretKey> _codeKey(String code, List<int> salt, KdfSettings kdf) async {
  Future<List<int>> derive() async {
    final argon = Argon2id(parallelism: 1, memory: kdf.memoryKib, iterations: kdf.passes, hashLength: 32);
    final key = await argon.deriveKeyFromPassword(password: code, nonce: salt);
    return key.extractBytes();
  }

  return SecretKey(kdf.memoryKib < 4096 ? await derive() : await Isolate.run(derive));
}

/// Новые ключи под кодом.
Future<(LockFile, SealKeys)> createLock(String code, {KdfSettings kdf = const KdfSettings()}) async {
  final pair = await _x25519.newKeyPair();
  final keys = SealKeys._(pair, (await pair.extractPublicKey()).bytes);
  return (await _wrap(keys, code, kdf), keys);
}

/// Те же ключи под новым кодом.
Future<LockFile> rewrapLock(LockFile lock, SealKeys keys, String code) => _wrap(keys, code, lock.kdf);

Future<LockFile> _wrap(SealKeys keys, String code, KdfSettings kdf) async {
  final salt = SecretKeyData.random(length: 16).bytes;
  final box = await _aes.encrypt(await keys.privateBytes(), secretKey: await _codeKey(code, salt, kdf), aad: keys.publicKey);
  return LockFile(salt: salt, kdf: kdf, publicKey: keys.publicKey, wrapped: box.concatenation());
}

/// Ключи по коду; неверный код — null.
Future<SealKeys?> openLock(LockFile lock, String code) async {
  try {
    final box = SecretBox.fromConcatenation(lock.wrapped, nonceLength: _aes.nonceLength, macLength: _macLength);
    final private = await _aes.decrypt(box, secretKey: await _codeKey(code, lock.salt, lock.kdf), aad: lock.publicKey);
    final keys = await keysFromPrivate(private);
    return _same(keys.publicKey, lock.publicKey) ? keys : null;
  } on SecretBoxAuthenticationError {
    return null;
  }
}

/// Ключи из закрытого ключа, сохранённого для входа отпечатком.
Future<SealKeys> keysFromPrivate(List<int> private) async {
  final pair = await _x25519.newKeyPairFromSeed(private);
  return SealKeys._(pair, (await pair.extractPublicKey()).bytes);
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var index = 0; index < a.length; index++) {
    diff |= a[index] ^ b[index];
  }
  return diff == 0;
}

// ключ файла: общий секрет одноразовой пары и открытого ключа, растянутый HKDF
Future<SecretKey> _fileKey(SimpleKeyPair ours, List<int> ourPublic, List<int> theirPublic, {required bool sealing}) async {
  final shared = await _x25519.sharedSecretKey(keyPair: ours, remotePublicKey: SimplePublicKey(theirPublic, type: KeyPairType.x25519));
  final ephemeral = sealing ? ourPublic : theirPublic;
  final recipient = sealing ? theirPublic : ourPublic;
  return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(secretKey: shared, nonce: [...ephemeral, ...recipient], info: utf8.encode(_info));
}

// ключ одноразовый, поэтому nonce — просто номер куска
List<int> _nonce(int counter) {
  final nonce = Uint8List(12);
  ByteData.sublistView(nonce).setUint64(4, counter);
  return nonce;
}

/// Запечатать файл: внутри [header] (путь, время правки) и содержимое. Пишется рядом и встаёт на место.
Future<void> sealFile(File source, File target, List<int> publicKey, {required Map<String, Object?> header}) async {
  final pair = await _x25519.newKeyPair();
  final ephemeral = (await pair.extractPublicKey()).bytes;
  final key = await _fileKey(pair, ephemeral, publicKey, sealing: true);
  final temp = File('${target.path}.tmp');
  final out = await temp.open(mode: FileMode.write);
  final input = await source.open();
  try {
    await out.writeFrom([..._magic, ...ephemeral]);
    final head = utf8.encode(jsonEncode(header));
    final length = ByteData(4)..setUint32(0, head.length);
    // открытый текст: длина заголовка, заголовок, файл — кусками по sealChunk
    var pending = BytesBuilder(copy: false)
      ..add(length.buffer.asUint8List())
      ..add(head);
    var counter = 0;
    while (true) {
      final need = sealChunk - pending.length;
      final read = need > 0 ? await input.read(need) : Uint8List(0);
      if (read.isNotEmpty) pending.add(read);
      final last = read.length < need || await input.position() == await input.length();
      if (pending.length < sealChunk && !last) continue;
      final plain = pending.takeBytes();
      final box = await _aes.encrypt(plain, secretKey: key, nonce: _nonce(counter++), aad: [if (last) 1 else 0]);
      final size = ByteData(4)..setUint32(0, plain.length + _macLength);
      await out.writeFrom([...size.buffer.asUint8List(), ...box.cipherText, ...box.mac.bytes]);
      pending = BytesBuilder(copy: false);
      if (last) break;
    }
    await out.flush();
  } finally {
    await input.close();
    await out.close();
  }
  await temp.rename(target.path);
}

/// Открыть запечатанный файл в [target]; отдаёт заголовок. Подмена или чужой ключ — [SealBroken].
Future<Map<String, Object?>> openSealedFile(File source, File target, SealKeys keys) async {
  final input = await source.open();
  final temp = File('${target.path}.tmp');
  await temp.parent.create(recursive: true);
  final out = await temp.open(mode: FileMode.write);
  Map<String, Object?>? header;
  try {
    final start = await input.read(_magic.length + 32);
    if (start.length < _magic.length + 32 || !_same(start.sublist(0, _magic.length), _magic)) throw const SealBroken('не запечатанный файл');
    final key = await _fileKey(keys._pair, keys.publicKey, start.sublist(_magic.length), sealing: false);
    var counter = 0;
    var finished = false;
    final head = BytesBuilder(copy: false);
    int? headLength;
    while (!finished) {
      final sizeBytes = await input.read(4);
      if (sizeBytes.length < 4) throw const SealBroken('нет конца');
      final size = ByteData.sublistView(sizeBytes).getUint32(0);
      if (size < _macLength || size > sealChunk + _macLength) throw const SealBroken('кусок не того размера');
      final chunk = await input.read(size);
      if (chunk.length < size) throw const SealBroken('обрезан');
      final atEnd = await input.position() == await input.length();
      final box = SecretBox(chunk.sublist(0, size - _macLength), nonce: _nonce(counter++), mac: Mac(chunk.sublist(size - _macLength)));
      List<int> plain;
      try {
        // метку конца проверяет сама подпись куска: последний кусок нельзя выдать за средний
        plain = await _aes.decrypt(box, secretKey: key, aad: [if (atEnd) 1 else 0]);
      } on SecretBoxAuthenticationError {
        throw const SealBroken('подпись не сходится');
      }
      finished = atEnd;
      var body = plain;
      if (header == null) {
        head.add(plain);
        final have = head.toBytes();
        if (have.length < 4) continue;
        headLength ??= ByteData.sublistView(Uint8List.fromList(have.sublist(0, 4))).getUint32(0);
        if (have.length < 4 + headLength) {
          if (finished) throw const SealBroken('нет заголовка');
          continue;
        }
        header = (jsonDecode(utf8.decode(have.sublist(4, 4 + headLength))) as Map).cast<String, Object?>();
        body = have.sublist(4 + headLength);
      }
      if (body.isNotEmpty) await out.writeFrom(body);
    }
    await out.flush();
  } catch (_) {
    await out.close();
    if (await temp.exists()) await temp.delete();
    rethrow;
  } finally {
    await input.close();
  }
  await out.close();
  await temp.rename(target.path);
  return header ?? const {};
}

/// Запечатать короткие данные целиком (список файлов скрытого).
Future<List<int>> sealBytes(List<int> plain, List<int> publicKey) async {
  final pair = await _x25519.newKeyPair();
  final ephemeral = (await pair.extractPublicKey()).bytes;
  final box = await _aes.encrypt(plain, secretKey: await _fileKey(pair, ephemeral, publicKey, sealing: true), nonce: _nonce(0), aad: const [1]);
  return [..._magic, ...ephemeral, ...box.cipherText, ...box.mac.bytes];
}

Future<List<int>> openSealedBytes(List<int> sealed, SealKeys keys) async {
  if (sealed.length < _magic.length + 32 + _macLength || !_same(sealed.sublist(0, _magic.length), _magic)) throw const SealBroken('не запечатанные данные');
  final ephemeral = sealed.sublist(_magic.length, _magic.length + 32);
  final body = sealed.sublist(_magic.length + 32);
  try {
    return await _aes.decrypt(
      SecretBox(body.sublist(0, body.length - _macLength), nonce: _nonce(0), mac: Mac(body.sublist(body.length - _macLength))),
      secretKey: await _fileKey(keys._pair, keys.publicKey, ephemeral, sealing: false),
      aad: const [1],
    );
  } on SecretBoxAuthenticationError {
    throw const SealBroken('подпись не сходится');
  }
}
