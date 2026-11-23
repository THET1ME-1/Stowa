import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stowa/services/sync/sync_http.dart';

/// Ответ сервера: JSON в UTF-8, как у настоящего.
http.Response _json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  final asked = <String>[];
  late HttpSyncRemote remote;

  setUp(() {
    asked.clear();
    remote = HttpSyncRemote(
      MockClient((request) async {
        asked.add('${request.method} ${request.url.path}${request.url.hasQuery ? '?${request.url.query}' : ''}');
        expect(request.headers['authorization'], 'Bearer токен');
        final path = request.url.path;
        if (path == '/v1/files/f1/revisions') {
          return _json(
            {
              'revisions': [
                {'rev': 3, 'deleted': false, 'meta': 'm3', 'blobs': ['b3'], 'size': 5, 'at': '2026-11-23T10:00:00.123456Z', 'device': 'Pixel 8'},
                {'rev': 2, 'deleted': true, 'meta': 'm2', 'blobs': [], 'size': 0, 'at': '2026-11-22T10:00:00Z', 'device': null},
              ],
              'more': true,
            },
          );
        }
        if (path == '/v1/deleted') {
          return _json(
            {
              'files': [
                {
                  'file': 'f2',
                  'rev': 4,
                  'at': '2026-11-23T11:00:00Z',
                  'device': 'Сайт',
                  'meta': 'надгробие',
                  'last': {'rev': 3, 'meta': 'm', 'blobs': ['x'], 'size': 9, 'at': '2026-11-23T09:00:00Z', 'device': 'Pixel 8'},
                },
              ],
              'next': 'дальше',
            },
          );
        }
        if (path == '/v1/log') {
          return _json(
            {
              'entries': [
                {'file': 'f1', 'rev': 3, 'deleted': false, 'meta': 'm3', 'size': 5, 'at': '2026-11-23T10:00:00Z', 'device': 'Pixel 8'},
              ],
              'next': null,
            },
          );
        }
        if (request.method == 'DELETE' && path == '/v1/files/f1/history') return http.Response('', 204);
        return http.Response('', 402);
      }),
      'токен',
      base: 'https://sync.test',
    );
  });

  test('ревизии файла: время, устройство, надгробие, страницы', () async {
    final page = await remote.revisions('f1', before: 4, limit: 2);
    expect(asked.single, 'GET /v1/files/f1/revisions?before=4&limit=2');
    expect(page.more, true);
    final [last, tomb] = page.revisions;
    expect(last.rev, 3);
    expect(last.file, 'f1');
    expect(last.blobs, ['b3']);
    expect(last.at, DateTime.utc(2026, 11, 23, 10, 0, 0, 123, 456));
    expect(last.device, 'Pixel 8');
    expect(tomb.deleted, true);
    expect(tomb.device, isNull);
  });

  test('удалённые: надгробие и последняя живая ревизия, курсор', () async {
    final page = await remote.deleted(after: 'курсор');
    expect(asked.single, 'GET /v1/deleted?limit=100&after=%D0%BA%D1%83%D1%80%D1%81%D0%BE%D1%80');
    expect(page.next, 'дальше');
    final one = page.files.single;
    expect(one.tomb.file, 'f2');
    expect(one.tomb.rev, 4);
    expect(one.tomb.device, 'Сайт');
    expect(one.last.file, 'f2');
    expect(one.last.rev, 3);
    expect(one.last.blobs, ['x']);
  });

  test('журнал правок и стирание истории', () async {
    final page = await remote.log();
    expect(page.next, isNull);
    expect(page.entries.single.blobs, isEmpty);
    expect(page.entries.single.at, DateTime.utc(2026, 11, 23, 10));
    await remote.purgeHistory('f1');
    expect(asked, ['GET /v1/log?limit=100', 'DELETE /v1/files/f1/history']);
  });

  test('без подписки — ошибка с кодом', () async {
    expect(() => remote.revisions('f9'), throwsA(isA<SyncHttpError>().having((e) => e.status, 'status', 402)));
  });
}
