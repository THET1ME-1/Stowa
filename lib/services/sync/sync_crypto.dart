/// Шифрование синхронизации. Телефон шифрует всё до отправки: сервер и бакет
/// видят номера файлов и зашифрованные куски, имена лежат внутри заголовка.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Размер части файла до шифрования.
const syncChunk = 8 * 1024 * 1024;

/// Версия формата заголовка и частей.
const syncFormat = 1;

class SyncSealBroken implements Exception {
  const SyncSealBroken();

  @override
  String toString() => 'SyncSealBroken';
}

/// Путь в одном виде: iPhone отдаёт кириллицу разложенной (NFD), Android — собранной.
String normalizePath(String path) => unorm.nfc(path);

/// Что телефон знает о файле. Лежит на сервере только зашифрованным.
class FileMeta {
  const FileMeta({required this.path, required this.mtime, required this.size, required this.hash, this.deleted = false, this.v = syncFormat, this.chunk = syncChunk});

  final int v;
  final String path;

  /// Время правки, мс.
  final int mtime;
  final int size;

  /// sha256 открытого содержимого, hex.
  final String hash;
  final bool deleted;
  final int chunk;

  Map<String, Object?> toJson() => {'v': v, 'path': path, 'mtime': mtime, 'size': size, 'hash': hash, 'deleted': deleted, 'chunk': chunk};

  factory FileMeta.fromJson(Map<String, Object?> json) => FileMeta(
    v: json['v'] as int,
    path: json['path'] as String,
    mtime: json['mtime'] as int,
    size: json['size'] as int,
    hash: json['hash'] as String,
    deleted: json['deleted'] as bool? ?? false,
    chunk: json['chunk'] as int? ?? syncChunk,
  );
}

final _aes = AesGcm.with256bits();

/// Ключ хранилища: 32 байта. Номер файла — от него и пути, заголовки и части — им же.
class VaultKey {
  VaultKey(List<int> bytes) : bytes = List.unmodifiable(bytes), _secret = SecretKey(bytes) {
    if (bytes.length != 32) throw ArgumentError('ключ хранилища — 32 байта');
  }

  factory VaultKey.generate() {
    final random = Random.secure();
    return VaultKey([for (var i = 0; i < 32; i++) random.nextInt(256)]);
  }

  final List<int> bytes;
  final SecretKey _secret;

  /// Номер файла: один для любой записи пути и регистра, другой у другого хранилища.
  String fileId(String path) {
    final digest = hash.Hmac(hash.sha256, bytes).convert(utf8.encode('path:${normalizePath(path).toLowerCase()}'));
    return base64Url.encode(digest.bytes).substring(0, 32);
  }

  Future<String> sealMeta(FileMeta meta) async => base64.encode(await _seal(utf8.encode(jsonEncode(meta.toJson()))));

  Future<FileMeta> openMeta(String sealed) async {
    try {
      return FileMeta.fromJson(jsonDecode(utf8.decode(await _open(base64.decode(sealed)))) as Map<String, Object?>);
    } on SyncSealBroken {
      rethrow;
    } on Object {
      throw const SyncSealBroken();
    }
  }

  /// Часть шифруется одинаково при каждом повторе: nonce выводится из её содержимого.
  /// Так после обрыва уже отправленные части узнаются по имени и не идут второй раз.
  /// Один nonce бывает только у одинаковых частей, поэтому повтор nonce безопасен.
  Future<List<int>> sealChunk(List<int> plain) {
    final digest = hash.Hmac(hash.sha256, bytes).convert([...utf8.encode('nonce:'), ...hash.sha256.convert(plain).bytes]);
    return _seal(plain, nonce: digest.bytes.sublist(0, _aes.nonceLength));
  }

  Future<List<int>> openChunk(List<int> box) => _open(box);

  // nonce | шифр | mac
  Future<List<int>> _seal(List<int> plain, {List<int>? nonce}) async {
    final box = await _aes.encrypt(plain, secretKey: _secret, nonce: nonce ?? _aes.newNonce());
    return box.concatenation();
  }

  Future<List<int>> _open(List<int> data) async {
    try {
      final box = SecretBox.fromConcatenation(data, nonceLength: _aes.nonceLength, macLength: _aes.macAlgorithm.macLength, copy: false);
      return await _aes.decrypt(box, secretKey: _secret);
    } on Object {
      throw const SyncSealBroken();
    }
  }
}

/// sha256 байтов, hex: имя части на сервере и отпечаток содержимого.
String sha256Hex(List<int> data) => hash.sha256.convert(data).toString();
