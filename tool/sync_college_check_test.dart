// Копия настоящего хранилища через боевой сервер sync.stowa.work туда и обратно,
// байт в байт. Оригинал не трогается: работаем с копией во временной папке.
//
//   VAULT_COPY=~/Projects/College SYNC_TOKEN=<токен пробного аккаунта> \
//   TMPDIR=~/.cache/flutter-tmp flutter test tool/sync_college_check_test.dart
//
// Аккаунт — пробный (support@stowa.work) с подпиской. После прогона его файлы
// стираются на сервере: `docker compose exec sync admin purge support@stowa.work`.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_disk.dart';
import 'package:stowa/services/sync/sync_engine.dart';
import 'package:stowa/services/sync/sync_http.dart';

import '../test/services/sync/fakes.dart' show MemoryState;

/// md5 всех синхронизируемых файлов папки: путь → отпечаток.
Map<String, String> _prints(Directory root) => {
  for (final file in root.listSync(recursive: true, followLinks: false).whereType<File>())
    if (syncable(p.split(p.relative(file.path, from: root.path)).join('/')))
      p.split(p.relative(file.path, from: root.path)).join('/'): md5.convert(file.readAsBytesSync()).toString(),
};

void main() {
  final source = Platform.environment['VAULT_COPY'];
  final token = Platform.environment['SYNC_TOKEN'];

  test('копия хранилища уходит на сервер и приходит на второй телефон байт в байт', () async {
    final scratch = Directory(p.join(Platform.environment['HOME']!, '.cache', 'flutter-tmp')).createTempSync('college_sync');
    addTearDown(() => scratch.deleteSync(recursive: true));
    final a = Directory(p.join(scratch.path, 'a'));
    final b = Directory(p.join(scratch.path, 'b'))..createSync();
    final copy = await Process.run('cp', ['-a', source!, a.path]);
    expect(copy.exitCode, 0, reason: '${copy.stderr}');

    final client = http.Client();
    final api = SyncAccountApi(client);
    var keyBytes = await api.key(token!);
    if (keyBytes == null) {
      keyBytes = VaultKey.generate().bytes;
      if (!await api.putKey(token, keyBytes)) keyBytes = await api.key(token);
    }
    final key = VaultKey(keyBytes!);
    SyncEngine phone(Directory root) => SyncEngine(vault: DiskSyncFiles(root), remote: HttpSyncRemote(client, token), state: MemoryState(), key: key);

    final before = _prints(a);
    final watch = Stopwatch()..start();
    final up = await phone(a).sync();
    final upTime = watch.elapsed;
    stdout.writeln('отправка: $up, ${upTime.inSeconds} с, файлов ${before.length}');
    expect(up.error, isNull);

    // второй телефон: застрявшие в бакете файлы откладываются и дочитываются следующим проходом
    watch.reset();
    final second = phone(b);
    var down = await second.sync();
    stdout.writeln('приём: $down, ${watch.elapsed.inSeconds} с');
    for (var pass = 2; pass <= 4 && down.error != null; pass++) {
      down = await second.sync();
      stdout.writeln('приём, проход $pass: $down, ${watch.elapsed.inSeconds} с');
    }
    expect(down.error, isNull);

    final after = _prints(b);
    final missing = before.keys.toSet().difference(after.keys.toSet());
    final extra = after.keys.toSet().difference(before.keys.toSet());
    final differ = [for (final path in before.keys) if (after.containsKey(path) && after[path] != before[path]) path];
    stdout.writeln(jsonEncode({'файлов': before.length, 'нет': missing.take(10).toList(), 'лишние': extra.take(10).toList(), 'разные': differ.take(10).toList()}));
    expect(missing, isEmpty);
    expect(extra, isEmpty);
    expect(differ, isEmpty);
    // оригинал не тронут
    expect(_prints(Directory(source)), before);
  }, skip: source == null || token == null ? 'нужны VAULT_COPY и SYNC_TOKEN' : false, timeout: const Timeout(Duration(minutes: 60)));
}
