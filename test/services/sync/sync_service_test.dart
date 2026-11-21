import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_service.dart';
import 'package:stowa/services/vault/vault_reader.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late SyncService service;

  setUp(() async {
    db = AppDatabase.memory();
    root = Directory.systemTemp.createTempSync('stowa_sync_service');
    final store = MemoryKeyStore();
    await store.write(SyncAccount(email: 'me@x.io', token: 't', key: VaultKey.generate().bytes, vaultDb: 'stowa').toJson());
    // сервер: изменений нет, части и файлы принимает
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path == '/v1/changes') return http.Response('{"cursor":0,"more":false,"changes":[]}', 200);
      if (path.startsWith('/v1/blobs/')) return http.Response('', request.method == 'HEAD' ? 404 : 204);
      if (path.startsWith('/v1/files/')) return http.Response('{"rev":1}', 200);
      return http.Response('', 404);
    });
    service = SyncService(db: db, root: root, vaultDb: () => 'stowa', reader: VaultReader(db, root: root, clock: DateTime.now), store: store, client: client);
  });

  tearDown(() async {
    service.dispose();
    await db.close();
    root.deleteSync(recursive: true);
  });

  // свои правки возвращаются с сервера, экран открылся — за проходом с работой сразу идёт
  // пустой, и «Отправлено: 1» исчезало через секунду
  test('итог прохода с работой не стирает следующий пустой проход', () async {
    File('${root.path}/Идеи.md').writeAsStringSync('Идеи\n');
    await service.run();
    expect(service.status.value.sent, 1);
    await service.run();
    expect(service.status.value.sent, 1);
  });
}
