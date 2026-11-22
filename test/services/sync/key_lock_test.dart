import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/services/sync/key_lock.dart';
import 'package:stowa/services/sync/sync_service.dart';
import 'package:stowa/services/vault/vault_reader.dart';

/// В тестах Argon2 лёгкий: настоящая цена (19 МиБ, 2 прохода) проверяется отдельным тестом.
const _cheap = KeyLockCost(memory: 64, iterations: 1);

void main() {
  final key = List<int>.generate(32, (i) => i * 3);

  group('замок ключа', () {
    test('открывается своим паролем, чужим — нет', () async {
      final lock = await KeyLock.close(key, 'верблюд-42', cost: _cheap);
      expect(await KeyLock.open(lock, 'верблюд-42'), key);
      expect(await KeyLock.open(lock, 'верблюд-43'), isNull);
      expect(lock['kdf'], 'argon2id');
      expect(jsonEncode(lock), isNot(contains(base64.encode(key))));
    });

    test('пароль в разных записях Юникода — один и тот же', () async {
      // «й» собранной буквой и разложенной: iPhone и Android присылают по-разному
      final lock = await KeyLock.close(key, 'мой', cost: _cheap);
      expect(await KeyLock.open(lock, 'мой'), key);
    });

    test('настоящая цена — нижняя граница OWASP', () async {
      final lock = await KeyLock.close(key, 'пароль', salt: List.filled(16, 1));
      expect((lock['m'], lock['t'], lock['p']), (19456, 2, 1));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('отпечаток ключа совпадает с тем, что считает сервер', () {
      // сервер: base64(HMAC-SHA256(ключ, "stowa-key-check"))
      expect(KeyLock.check(List<int>.generate(32, (i) => i)), 'dZhWKNthJWs2YFRm5J8BTMm5wXaaLpMw/WeEWEj5COg=');
    });
  });

  group('вход с паролем шифрования', () {
    late AppDatabase db;
    late Directory root;
    late SyncService service;
    late MemoryKeyStore store;
    late Map<String, Object?> lock;
    final requests = <String>[];

    setUp(() async {
      db = AppDatabase.memory();
      root = Directory.systemTemp.createTempSync('stowa_key_lock');
      store = MemoryKeyStore();
      requests.clear();
      lock = await KeyLock.close(key, 'верблюд-42', cost: _cheap);
      final client = MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        return switch ((request.method, request.url.path)) {
          ('POST', '/v1/auth/verify') => http.Response(jsonEncode({'token': 't1', 'email': 'me@x.io', 'active': true}), 200),
          ('GET', '/v1/key') => http.Response(jsonEncode({'key': null, 'lock': lock}), 200),
          ('PUT', '/v1/key/lock') => http.Response('', 204),
          ('DELETE', '/v1/key/lock') => http.Response('', 204),
          _ => http.Response('', 404),
        };
      });
      service = SyncService(db: db, root: root, vaultDb: () => 'stowa', reader: VaultReader(db, root: root, clock: DateTime.now), store: store, client: client);
    });

    tearDown(() async {
      service.dispose();
      await db.close();
      root.deleteSync(recursive: true);
    });

    test('сервер отдал замок — вход просит пароль, неверный не пускает, верный открывает ключ', () async {
      expect(await service.verify('me@x.io', '123456'), SignInStep.needsPassword);
      expect(await store.read(), isNull);
      expect(await service.unlock('неверный'), isFalse);
      expect(await service.unlock('верблюд-42'), isTrue);
      final account = SyncAccount.fromJson(await store.read())!;
      expect(account.key, key);
      expect(service.status.value.email, 'me@x.io');
    });

    test('свой пароль: замок уходит на сервер с отпечатком, выключение отдаёт ключ', () async {
      await store.write(SyncAccount(email: 'me@x.io', token: 't1', key: key, vaultDb: 'stowa').toJson());
      expect(await service.setPassword('новый-пароль', cost: _cheap), isTrue);
      expect(requests, contains('PUT /v1/key/lock'));
      expect(await service.removePassword(), isTrue);
      expect(requests, contains('DELETE /v1/key/lock'));
    });
  });
}
