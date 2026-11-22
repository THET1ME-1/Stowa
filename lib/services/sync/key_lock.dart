/// Свой пароль шифрования: ключ хранилища закрыт ключом, выведенным из пароля человека.
/// Сервер хранит только этот замок и открыть его не может.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Цена вывода ключа из пароля. По умолчанию — нижняя граница OWASP для Argon2id: 19 МиБ и
/// 2 прохода. Больше нельзя: в браузере Argon2 считается на Dart, и вход тянулся бы минутами.
class KeyLockCost {
  const KeyLockCost({this.memory = 19456, this.iterations = 2, this.parallelism = 1});

  /// Блоков по 1 КиБ.
  final int memory;
  final int iterations;
  final int parallelism;
}

final _aes = AesGcm.with256bits();

abstract final class KeyLock {
  /// Закрыть ключ паролем: замок `{v, kdf, m, t, p, salt, box}` для сервера.
  static Future<Map<String, Object?>> close(List<int> key, String password, {KeyLockCost cost = const KeyLockCost(), List<int>? salt}) async {
    final random = Random.secure();
    final grains = salt ?? [for (var i = 0; i < 16; i++) random.nextInt(256)];
    final wrapper = await _derive(password, grains, cost.memory, cost.iterations, cost.parallelism);
    final box = await _aes.encrypt(key, secretKey: wrapper, nonce: _aes.newNonce());
    return {
      'v': 1,
      'kdf': 'argon2id',
      'm': cost.memory,
      't': cost.iterations,
      'p': cost.parallelism,
      'salt': base64.encode(grains),
      'box': base64.encode(box.concatenation()),
    };
  }

  /// Открыть замок паролем; null — пароль не тот или замок повреждён.
  static Future<List<int>?> open(Map<String, Object?> lock, String password) async {
    try {
      if (lock['kdf'] != 'argon2id') return null;
      final wrapper = await _derive(password, base64.decode(lock['salt'] as String), lock['m'] as int, lock['t'] as int, lock['p'] as int);
      final box = SecretBox.fromConcatenation(base64.decode(lock['box'] as String), nonceLength: _aes.nonceLength, macLength: _aes.macAlgorithm.macLength);
      return await _aes.decrypt(box, secretKey: wrapper);
    } on Object {
      return null;
    }
  }

  /// Отпечаток ключа: по нему сервер узнаёт тот же ключ, а сам ключ по нему не восстановить.
  static String check(List<int> key) => base64.encode(hash.Hmac(hash.sha256, key).convert(utf8.encode('stowa-key-check')).bytes);

  // пароль в одной записи Юникода: iPhone присылает «й» разложенной, Android — собранной
  static Future<SecretKey> _derive(String password, List<int> salt, int memory, int iterations, int parallelism) =>
      Argon2id(memory: memory, iterations: iterations, parallelism: parallelism, hashLength: 32).deriveKey(secretKey: SecretKey(utf8.encode(unorm.nfc(password))), nonce: salt);
}
