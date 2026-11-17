import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stowa/features/settings/sync_screen.dart';
import 'package:stowa/services/sync/sync_service.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  late List<http.Request> requests;
  late Directory vault;

  setUp(() {
    world = TestWorld();
    requests = [];
    vault = Directory.systemTemp.createTempSync('stowa_sync_screen');
    world.vaultRoot = vault;
    // сервер: код 123456 верный, ключа ещё нет, остальное пусто
    world.syncHttp = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path == '/v1/auth/start') return http.Response('', 204);
      if (path == '/v1/auth/verify') {
        final code = (jsonDecode(request.body) as Map)['code'];
        return code == '123456'
            ? http.Response(jsonEncode({'token': 't1', 'email': 'me@x.io', 'active': true}), 200, headers: {'content-type': 'application/json'})
            : http.Response('{"error":"code"}', 401);
      }
      if (path == '/v1/key' && request.method == 'GET') return http.Response('{"key":null}', 200);
      if (path == '/v1/key' && request.method == 'PUT') return http.Response('', 204);
      if (path == '/v1/changes') return http.Response('{"cursor":0,"more":false,"changes":[]}', 200);
      if (path == '/v1/session') return http.Response('', 204);
      return http.Response('', 404);
    });
  });

  tearDown(() async {
    await world.dispose();
    vault.deleteSync(recursive: true);
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const SyncScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> askCode(WidgetTester tester) async {
    await tester.enterText(find.byKey(const ValueKey('sync-email')), 'me@x.io');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sync-get-code')));
    await tester.pumpAndSettle();
  }

  testWidgets('почта → код: письмо просится с языком, устройством и поясом телефона', (tester) async {
    await open(tester);
    await askCode(tester);
    final start = jsonDecode(requests.single.body) as Map;
    expect(start['email'], 'me@x.io');
    expect(start['lang'], 'ru');
    expect(start.containsKey('device') && start.containsKey('tz_offset'), isTrue);
    expect(find.textContaining('me@x.io'), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-code')), findsOneWidget);
    // повтор не раньше минуты
    expect(find.textContaining('Прислать снова через'), findsOneWidget);
  });

  testWidgets('неверный код — ошибка под кнопкой, верный — вошли, ключ лёг на сервер', (tester) async {
    await open(tester);
    await askCode(tester);
    await tester.enterText(find.byKey(const ValueKey('sync-code')), '000000');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sync-error')), findsOneWidget);
    expect(await world.syncAccount.read(), isNull);

    await tester.enterText(find.byKey(const ValueKey('sync-code')), '123456');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sync-account')), findsOneWidget);
    expect(find.text('me@x.io'), findsOneWidget);
    final account = SyncAccount.fromJson(await world.syncAccount.read())!;
    expect(account.token, 't1');
    expect(account.key.length, 32);
    final put = requests.singleWhere((r) => r.url.path == '/v1/key' && r.method == 'PUT');
    expect(base64.decode((jsonDecode(put.body) as Map)['key'] as String), account.key);

    // выход: аккаунт стёрт, снова шаг почты
    await tester.tap(find.byKey(const ValueKey('sync-sign-out')));
    await tester.pumpAndSettle();
    expect(await world.syncAccount.read(), isNull);
    expect(find.byKey(const ValueKey('sync-email')), findsOneWidget);
  });

  testWidgets('без хранилища — подсказка выбрать папку, полей нет', (tester) async {
    world.vaultRoot = null;
    await open(tester);
    expect(find.byKey(const ValueKey('sync-email')), findsNothing);
    expect(find.textContaining('папку хранилища'), findsOneWidget);
  });
}
