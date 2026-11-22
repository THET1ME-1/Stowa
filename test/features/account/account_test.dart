import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stowa/features/account/account_screen.dart';
import 'package:stowa/features/settings/settings_screen.dart';
import 'package:stowa/services/billing/subscription.dart';
import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_service.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  late List<String> requests;
  late int deleteStatus;
  late Map<String, Object?> account;

  setUp(() {
    world = TestWorld();
    requests = [];
    deleteStatus = 204;
    account = {'email': 'me@x.io', 'active': false, 'paid_until': null, 'buyer_id': 'b-1', 'source': null, 'plan': null, 'auto_renew': false, 'test': false, 'cancellable': false};
    // сервер: код 123456 верный, аккаунт без подписки
    world.syncHttp = MockClient((request) async {
      final path = request.url.path;
      requests.add('${request.method} $path');
      if (path == '/v1/auth/start') return http.Response('', 204);
      if (path == '/v1/auth/verify') {
        return (jsonDecode(request.body) as Map)['code'] == '123456'
            ? http.Response(jsonEncode({'token': 't1', 'email': 'me@x.io', 'active': false}), 200)
            : http.Response('{"error":"code"}', 401);
      }
      if (path == '/v1/key' && request.method == 'GET') return http.Response('{"key":null}', 200);
      if (path == '/v1/key' && request.method == 'PUT') return http.Response('', 204);
      if (path == '/v1/account' && request.method == 'GET') return http.Response(jsonEncode(account), 200);
      if (path == '/v1/account' && request.method == 'DELETE') return http.Response(deleteStatus == 409 ? '{"error":"live_subscription"}' : '', deleteStatus);
      if (path == '/v1/session') return http.Response('', 204);
      if (path == '/v1/changes') return http.Response('{"cursor":0,"more":false,"changes":[]}', 200);
      return http.Response('', 404);
    });
  });

  tearDown(() => world.dispose());

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(screen));
    await tester.pumpAndSettle();
  }

  Future<void> signedIn({SubSource? source}) async {
    await world.syncAccount.write(SyncAccount(email: 'me@x.io', token: 't1', key: VaultKey.generate().bytes, vaultDb: 'stowa').toJson());
    if (source != null) {
      account = {...account, 'active': true, 'paid_until': DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String(), 'source': source.name};
    }
  }

  testWidgets('пункт «Войти» ведёт ко входу, после входа — почта', (tester) async {
    await pumpScreen(tester, const SettingsScreen(section: 'account'));
    expect(find.text('Если вам выдали подписку'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('Вход'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('sync-email')), 'me@x.io');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sync-get-code')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sync-code')), '123456');
    await tester.pumpAndSettle();
    // экран входа закрылся сам, в настройках — почта аккаунта
    expect(find.byKey(const ValueKey('sync-code')), findsNothing);
    expect(find.byKey(const ValueKey('settings-account')), findsOneWidget);
    expect(find.text('me@x.io'), findsOneWidget);
    expect(requests, contains('GET /v1/account'));
  });

  testWidgets('удаление аккаунта спрашивает и выходит', (tester) async {
    await signedIn();
    await pumpScreen(tester, const AccountScreen());
    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Удалить аккаунт me@x.io?'), findsOneWidget);
    expect(requests, isNot(contains('DELETE /v1/account')));
    await tester.tap(find.byKey(const ValueKey('account-delete-yes')));
    await tester.pumpAndSettle();
    expect(requests, contains('DELETE /v1/account'));
    expect(await world.syncAccount.read(), isNull);
  });

  testWidgets('удаление при живой подписке — объяснение, вход остаётся', (tester) async {
    await signedIn(source: SubSource.lava);
    deleteStatus = 409;
    await pumpScreen(tester, const AccountScreen());
    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-delete-yes')));
    await tester.pumpAndSettle();
    expect(find.text('Сначала отмените продление подписки, иначе оплата продолжит списываться.'), findsOneWidget);
    expect(await world.syncAccount.read(), isNotNull);
  });

  testWidgets('подписка магазина: перед удалением напоминаем отменить её в магазине', (tester) async {
    await signedIn(source: SubSource.play);
    await pumpScreen(tester, const AccountScreen());
    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Подписка Google Play сама не остановится: отмените её в Google Play.'), findsOneWidget);
  });

  testWidgets('выход из аккаунта', (tester) async {
    await signedIn();
    await pumpScreen(tester, const AccountScreen());
    await tester.tap(find.byKey(const ValueKey('account-sign-out')));
    await tester.pumpAndSettle();
    expect(await world.syncAccount.read(), isNull);
  });
}
