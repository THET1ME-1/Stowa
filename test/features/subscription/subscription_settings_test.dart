import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stowa/features/account/account_screen.dart';
import 'package:stowa/features/settings/settings_screen.dart';
import 'package:stowa/features/settings/sync_screen.dart';
import 'package:stowa/features/subscription/paywall_screen.dart';
import 'package:stowa/features/subscription/subscription_screen.dart';
import 'package:stowa/services/billing/store_channel.dart';
import 'package:stowa/services/billing/subscription.dart';
import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_service.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  late List<String> requests;
  late Map<String, Object?> account;

  final until = DateTime.now().toUtc().add(const Duration(days: 40));

  setUp(() {
    world = TestWorld();
    requests = [];
    account = {'email': 'me@x.io', 'active': false, 'buyer_id': 'b-1'};
    world.syncHttp = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      return switch (request.url.path) {
        '/v1/account' => http.Response(jsonEncode(account), 200),
        '/v1/billing/lava/cancel' => () {
          account = {...account, 'auto_renew': false, 'cancellable': false};
          return http.Response(jsonEncode({'until': until.toIso8601String()}), 200);
        }(),
        '/v1/billing/plans' => http.Response('{"lava":null}', 200),
        _ => http.Response('', 404),
      };
    });
  });

  tearDown(() => world.dispose());

  /// Вошли и подписка из [source]: снимок на устройстве и тот же ответ сервера.
  Future<void> subscribed(SubSource source, {bool cancellable = false}) async {
    await world.syncAccount.write(SyncAccount(email: 'me@x.io', token: 't1', key: VaultKey.generate().bytes, vaultDb: 'stowa').toJson());
    account = {
      'email': 'me@x.io',
      'active': true,
      'paid_until': until.toIso8601String(),
      'buyer_id': 'b-1',
      'source': source.name,
      'plan': 'quarter',
      'auto_renew': true,
      'cancellable': cancellable,
      'test': false,
    };
    await world.subscription.write(jsonEncode(Subscription.fromAccount(account).toJson()));
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(screen));
    await tester.pumpAndSettle();
  }

  // хозяин 22.11 со снимков: «почему отступа снизу от „Аккаунт“ не сделал» — группа липла к заголовку.
  // Под заголовком экрана, как в «Хранилище» и «Возврате», 18 точек до первой группы
  testWidgets('под заголовком экранов подписки и аккаунта — отступ до первой группы', (tester) async {
    await subscribed(SubSource.grant);
    double gap(String title, Finder first) => tester.getTopLeft(first).dy - tester.getBottomLeft(find.text(title).first).dy;

    await pumpScreen(tester, const SettingsScreen(section: 'account', title: 'Аккаунт'));
    expect(gap('Аккаунт', find.byKey(const ValueKey('settings-subscription'))), greaterThanOrEqualTo(16));

    await pumpScreen(tester, const SubscriptionScreen());
    expect(gap('Подписка', find.byKey(const ValueKey('sub-plan'))), greaterThanOrEqualTo(16));

    await pumpScreen(tester, const AccountScreen());
    expect(gap('Аккаунт', find.byKey(const ValueKey('account-email'))), greaterThanOrEqualTo(16));

    await pumpScreen(tester, const SyncScreen());
    expect(gap('Stowa Sync', find.byKey(const ValueKey('sync-account'))), greaterThanOrEqualTo(16));
  });

  testWidgets('без подписки первым пунктом — купить, касание открывает экран покупки', (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    final buy = find.byKey(const ValueKey('settings-subscribe'));
    expect(buy, findsOneWidget);
    expect(find.text('Купить подписку'), findsOneWidget);
    expect(tester.getTopLeft(buy).dy, lessThan(tester.getTopLeft(find.byKey(const ValueKey('settings-sign-in'))).dy));
    expect(tester.getTopLeft(buy).dy, lessThan(tester.getTopLeft(find.byKey(const ValueKey('settings-catalog'))).dy));
    await tester.tap(buy);
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsOneWidget);
  });

  testWidgets('с подпиской — срок вместо покупки', (tester) async {
    await subscribed(SubSource.lava);
    await pumpScreen(tester, const SettingsScreen(section: 'account'));
    expect(find.byKey(const ValueKey('settings-subscribe')), findsNothing);
    expect(find.byKey(const ValueKey('settings-subscription')), findsOneWidget);
    expect(find.textContaining('Stowa Sync до '), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-subscription')));
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionScreen), findsOneWidget);
  });

  testWidgets('экран подписки: тариф, срок, откуда', (tester) async {
    await subscribed(SubSource.grant);
    await pumpScreen(tester, const SubscriptionScreen());
    expect(find.text('3 месяца'), findsOneWidget);
    expect(find.text('Выдана командой Stowa'), findsOneWidget);
    expect(find.byKey(const ValueKey('sub-cancel')), findsNothing);
    expect(find.byKey(const ValueKey('sub-manage')), findsNothing);
  });

  testWidgets('отмена продления спрашивает и показывает срок', (tester) async {
    await subscribed(SubSource.lava, cancellable: true);
    await pumpScreen(tester, const SubscriptionScreen());
    await tester.tap(find.byKey(const ValueKey('sub-cancel')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Отменить продление? Stowa Sync будет работать до'), findsOneWidget);
    expect(requests, isNot(contains('POST /v1/billing/lava/cancel')));
    await tester.tap(find.byKey(const ValueKey('sub-cancel-yes')));
    await tester.pumpAndSettle();
    expect(requests, contains('POST /v1/billing/lava/cancel'));
    expect(find.text('Продление отменено'), findsWidgets);
    expect(find.byKey(const ValueKey('sub-cancel')), findsNothing);
  });

  testWidgets('подписка Google Play — управление в Google Play', (tester) async {
    world.storeChannel = StoreChannel.play;
    await subscribed(SubSource.play);
    await pumpScreen(tester, const SubscriptionScreen());
    await tester.tap(find.byKey(const ValueKey('sub-manage')));
    await tester.pump();
    expect(world.openedUrls.single.toString(), 'https://play.google.com/store/account/subscriptions?sku=stowa_sub&package=app.stowa');
  });

  testWidgets('в сборке App Store подписка картой — без отмены и без чужого магазина', (tester) async {
    world.storeChannel = StoreChannel.appstore;
    await subscribed(SubSource.lava, cancellable: true);
    await pumpScreen(tester, const SubscriptionScreen());
    expect(find.byKey(const ValueKey('sub-cancel')), findsNothing);
    expect(find.textContaining('Google Play'), findsNothing);
  });
}
