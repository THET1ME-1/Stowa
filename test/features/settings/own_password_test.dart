import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stowa/features/settings/sync_screen.dart';
import 'package:stowa/services/billing/subscription.dart';
import 'package:stowa/services/sync/key_lock.dart';
import 'package:stowa/services/sync/sync_service.dart';

import '../../helpers/test_app.dart';

/// В тестах Argon2 лёгкий: цена не влияет на то, что проверяется.
const _cheap = KeyLockCost(memory: 64, iterations: 1);

void main() {
  late TestWorld world;
  late List<String> requests;
  late Map<String, Object?>? lock;
  final key = List<int>.generate(32, (i) => i + 5);
  final until = DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String();

  setUp(() {
    world = TestWorld()..keyLockCost = _cheap;
    requests = [];
    lock = null;
    world.syncHttp = MockClient((request) async {
      final path = request.url.path;
      requests.add('${request.method} $path');
      return switch ((request.method, path)) {
        ('POST', '/v1/auth/start') => http.Response('', 204),
        ('POST', '/v1/auth/verify') => http.Response(jsonEncode({'token': 't1', 'email': 'me@x.io', 'active': true}), 200),
        ('GET', '/v1/account') => http.Response(jsonEncode({'email': 'me@x.io', 'active': true, 'paid_until': until, 'source': 'lava', 'buyer_id': 'b-1'}), 200),
        ('GET', '/v1/key') => http.Response(jsonEncode({'key': lock == null ? base64.encode(key) : null, 'lock': lock}), 200),
        ('PUT', '/v1/key/lock') => () {
          lock = (jsonDecode(request.body) as Map)['lock'] as Map<String, Object?>;
          return http.Response('', 204);
        }(),
        ('DELETE', '/v1/key/lock') => () {
          lock = null;
          return http.Response('', 204);
        }(),
        ('GET', '/v1/changes') => http.Response('{"cursor":0,"more":false,"changes":[]}', 200),
        _ => http.Response('', 404),
      };
    });
  });

  tearDown(() => world.dispose());

  Future<void> signedIn() async {
    await world.syncAccount.write(SyncAccount(email: 'me@x.io', token: 't1', key: key, vaultDb: 'stowa').toJson());
    await world.subscription.write(jsonEncode(Subscription.fromAccount({'email': 'me@x.io', 'active': true, 'paid_until': until, 'source': 'lava'}).toJson()));
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const SyncScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('свой пароль: предупреждение, пароль дважды, замок уходит на сервер', (tester) async {
    await signedIn();
    await open(tester);
    expect(find.text('Выключен: для нового устройства хватает входа'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sync-own-password')));
    await tester.pumpAndSettle();
    expect(find.textContaining('наша копия ключа сотрётся'), findsOneWidget);
    expect(find.textContaining('Забудете пароль'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('own-password')), 'коротко');
    await tester.enterText(find.byKey(const ValueKey('own-password-repeat')), 'коротко');
    await tester.tap(find.byKey(const ValueKey('own-password-on')));
    await tester.pumpAndSettle();
    expect(find.text('Не короче 8 знаков'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('own-password')), 'верблюд-42');
    await tester.enterText(find.byKey(const ValueKey('own-password-repeat')), 'верблюд-43');
    await tester.tap(find.byKey(const ValueKey('own-password-on')));
    await tester.pumpAndSettle();
    expect(find.text('Пароли не совпадают'), findsOneWidget);
    expect(requests, isNot(contains('PUT /v1/key/lock')));

    await tester.enterText(find.byKey(const ValueKey('own-password-repeat')), 'верблюд-42');
    await tester.tap(find.byKey(const ValueKey('own-password-on')));
    await tester.pumpAndSettle();
    expect(requests, contains('PUT /v1/key/lock'));
    expect(await KeyLock.open(lock!, 'верблюд-42'), key);
    expect(find.text('Включён: прочитать заметки можете только вы'), findsOneWidget);
  });

  testWidgets('выключение спрашивает и возвращает ключ серверу', (tester) async {
    await signedIn();
    lock = await KeyLock.close(key, 'верблюд-42', cost: _cheap);
    await open(tester);
    expect(find.text('Включён: прочитать заметки можете только вы'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sync-own-password')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('own-password-off')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Выключить свой пароль?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('own-password-off-yes')));
    await tester.pumpAndSettle();
    expect(requests, contains('DELETE /v1/key/lock'));
    expect(find.text('Выключен: для нового устройства хватает входа'), findsOneWidget);
  });

  testWidgets('вход на новом устройстве с паролем шифрования', (tester) async {
    lock = await KeyLock.close(key, 'верблюд-42', cost: _cheap);
    await open(tester);
    await tester.enterText(find.byKey(const ValueKey('sync-email')), 'me@x.io');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sync-get-code')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sync-code')), '123456');
    await tester.pumpAndSettle();
    expect(find.textContaining('Заметки закрыты вашим паролем шифрования'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('sync-password')), 'неверный');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sync-unlock')));
    await tester.pumpAndSettle();
    expect(find.text('Пароль не подходит'), findsOneWidget);
    expect(await world.syncAccount.read(), isNull);
    await tester.enterText(find.byKey(const ValueKey('sync-password')), 'верблюд-42');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sync-unlock')));
    await tester.pumpAndSettle();
    expect(SyncAccount.fromJson(await world.syncAccount.read())!.key, key);
    expect(find.byKey(const ValueKey('sync-account')), findsOneWidget);
  });
}
