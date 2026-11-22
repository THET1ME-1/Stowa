import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/features/settings/sync_screen.dart';
import 'package:stowa/features/subscription/panel_gate.dart';
import 'package:stowa/features/subscription/paywall_screen.dart';
import 'package:stowa/l10n/app_localizations.dart';
import 'package:stowa/services/billing/subscription.dart';
import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_service.dart';

import '../../helpers/test_app.dart';

String _snapshot({required bool active}) => jsonEncode(
  Subscription.fromAccount({
    'email': 'me@x.io',
    'active': active,
    'paid_until': DateTime.now().toUtc().add(Duration(days: active ? 30 : -1)).toIso8601String(),
    'source': 'lava',
  }).toJson(),
);

void main() {
  late TestWorld world;
  late bool paid;

  setUp(() {
    world = TestWorld();
    paid = false;
    world.syncHttp = MockClient((request) async {
      return switch (request.url.path) {
        '/v1/account' => http.Response(
          jsonEncode({'email': 'me@x.io', 'active': paid, 'paid_until': paid ? DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String() : null, 'buyer_id': 'b-1'}),
          200,
        ),
        '/v1/billing/plans' => http.Response('{"lava":null}', 200),
        _ => http.Response('', 404),
      };
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

  group('Stowa Sync', () {
    testWidgets('вошёл без подписки — предложение вместо управления', (tester) async {
      await world.syncAccount.write(SyncAccount(email: 'me@x.io', token: 't1', key: VaultKey.generate().bytes, vaultDb: 'stowa').toJson());
      await pumpScreen(tester, const SyncScreen());
      expect(find.byKey(const ValueKey('sync-offer')), findsOneWidget);
      expect(find.text('Синхронизация входит в Stowa Sync'), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-now')), findsNothing);
      // выйти можно и без подписки
      expect(find.byKey(const ValueKey('sync-sign-out')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sync-offer')));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsOneWidget);
    });

    testWidgets('не вошёл — купить и войти', (tester) async {
      await pumpScreen(tester, const SyncScreen());
      expect(find.byKey(const ValueKey('sync-buy')), findsOneWidget);
      expect(find.text('Уже есть подписка? Войдите'), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-email')), findsOneWidget);
    });

    testWidgets('с подпиской — управление, предложения нет', (tester) async {
      paid = true;
      await world.syncAccount.write(SyncAccount(email: 'me@x.io', token: 't1', key: VaultKey.generate().bytes, vaultDb: 'stowa').toJson());
      await world.subscription.write(_snapshot(active: true));
      await pumpScreen(tester, const SyncScreen());
      expect(find.byKey(const ValueKey('sync-offer')), findsNothing);
      expect(find.byKey(const ValueKey('sync-account')), findsOneWidget);
    });
  });

  group('боковая панель', () {
    final opened = <Uri>[];

    Future<void> pumpGate(WidgetTester tester, KeyStore store) async {
      opened.clear();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: PanelGate(
            store: store,
            open: (url) async {
              opened.add(url);
              return true;
            },
            child: const Text('строка панели'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('панель без подписки — замок, кнопка ведёт к покупке на сайте', (tester) async {
      await pumpGate(tester, MemoryKeyStore());
      expect(find.text('строка панели'), findsNothing);
      expect(find.text('Боковая панель входит в Stowa Sync'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('panel-subscribe')));
      expect(opened.single.toString(), 'https://stowa.work/?subscribe');
    });

    testWidgets('истёкшая подписка — тоже замок', (tester) async {
      await pumpGate(tester, MemoryKeyStore()..value = _snapshot(active: false));
      expect(find.text('строка панели'), findsNothing);
    });

    testWidgets('панель с подпиской — строка', (tester) async {
      await pumpGate(tester, MemoryKeyStore()..value = _snapshot(active: true));
      expect(find.text('строка панели'), findsOneWidget);
    });

    testWidgets('подписка появилась во вкладке — замок снимается сам', (tester) async {
      final store = MemoryKeyStore();
      await pumpGate(tester, store);
      expect(find.text('строка панели'), findsNothing);
      store.value = _snapshot(active: true);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text('строка панели'), findsOneWidget);
    });
  });
}
