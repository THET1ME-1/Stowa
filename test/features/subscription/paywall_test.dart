import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stowa/features/subscription/paywall_screen.dart';
import 'package:stowa/services/billing/checkout.dart';
import 'package:stowa/services/billing/store_channel.dart';
import 'package:stowa/services/billing/store_checkout.dart';
import 'package:stowa/services/billing/subscription.dart';
import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_service.dart';

import '../../helpers/test_app.dart';

/// Подставной магазин: тарифы, покупка присылает покупку в поток, закрытые запоминаются.
class FakeStore implements StoreBilling {
  final _purchases = StreamController<List<StorePurchase>>.broadcast();
  final completed = <String>[];
  final bought = <(SubPlan, String)>[];
  var restoredTokens = <String>[];
  StorePurchaseState outcome = StorePurchaseState.purchased;

  @override
  Future<List<PlanOffer>> products() async => [
    const PlanOffer(plan: SubPlan.month, price: '2,99 \$', amount: 2.99, currency: 'USD', native: 'month'),
    const PlanOffer(plan: SubPlan.quarter, price: '6,99 \$', amount: 6.99, currency: 'USD', native: 'quarter'),
    const PlanOffer(plan: SubPlan.year, price: '19,99 \$', amount: 19.99, currency: 'USD', native: 'year'),
  ];

  @override
  Future<bool> buy(PlanOffer offer, String buyerId) async {
    bought.add((offer.plan, buyerId));
    scheduleMicrotask(() => _purchases.add([StorePurchase(productId: 'stowa_sub', state: outcome, token: 'tok-${offer.plan.name}')]));
    return true;
  }

  @override
  Future<void> restore(String buyerId) async {
    for (final token in restoredTokens) {
      _purchases.add([StorePurchase(productId: 'stowa_sub', state: StorePurchaseState.restored, token: token)]);
    }
  }

  @override
  Stream<List<StorePurchase>> get purchases => _purchases.stream;

  @override
  Future<void> complete(StorePurchase purchase) async => completed.add(purchase.token!);
}

void main() {
  late TestWorld world;
  late List<String> requests;
  late bool paid;
  late int verifyStatus;

  setUp(() {
    world = TestWorld();
    requests = [];
    paid = false;
    verifyStatus = 200;
    final until = DateTime.now().toUtc().add(const Duration(days: 365)).toIso8601String();
    world.syncHttp = MockClient((request) async {
      final path = request.url.path;
      requests.add('${request.method} $path');
      Map<String, Object?> body() => request.body.isEmpty ? const {} : jsonDecode(request.body) as Map<String, Object?>;
      return switch (path) {
        '/v1/auth/start' => http.Response('', 204),
        '/v1/auth/verify' => http.Response(jsonEncode({'token': 't1', 'email': 'me@x.io', 'active': false}), 200),
        '/v1/key' when request.method == 'GET' => http.Response('{"key":null}', 200),
        '/v1/key' => http.Response('', 204),
        '/v1/account' => http.Response(
          jsonEncode({
            'email': 'me@x.io',
            'active': paid,
            'paid_until': paid ? until : null,
            'buyer_id': '5d0c3c47-3b47-4b67-a1c4-6a0b2a1f9e10',
            'source': paid ? 'lava' : null,
            'plan': paid ? 'year' : null,
            'auto_renew': paid,
            'cancellable': paid,
            'test': false,
          }),
          200,
        ),
        '/v1/billing/plans' => http.Response(
          jsonEncode({
            'lava': {
              'RUB': {'month': 299, 'quarter': 749, 'year': 1990},
              'USD': {'month': 5, 'quarter': 6.99, 'year': 19.99},
              'EUR': {'month': 5, 'quarter': 6.99, 'year': 19.99},
            },
          }),
          200,
        ),
        '/v1/billing/lava/checkout' => http.Response(jsonEncode({'url': 'https://pay.test/${body()['plan']}-${body()['currency']}', 'invoice': 'inv-1'}), 200),
        '/v1/billing/play' => () {
          if (verifyStatus == 200) paid = true;
          return http.Response(verifyStatus == 200 ? jsonEncode({'active': true, 'until': until}) : '{"error":"owned"}', verifyStatus);
        }(),
        '/v1/changes' => http.Response('{"cursor":0,"more":false,"changes":[]}', 200),
        _ => http.Response('', 404),
      };
    });
  });

  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const PaywallScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> signedIn() async => world.syncAccount.write(SyncAccount(email: 'me@x.io', token: 't1', key: VaultKey.generate().bytes, vaultDb: 'stowa').toJson());

  /// Список ленивый: тарифы и кнопка под пятью пунктами подписки строятся, когда до них долистали.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  /// Ожидание оплаты крутит индикатор без конца: pumpAndSettle его не дождётся, кадры — вручную.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await reveal(tester, find.byKey(const ValueKey('paywall-continue')));
    await tester.tap(find.byKey(const ValueKey('paywall-continue')));
    await settle(tester);
  }

  // история версий вышла 23.11.2026: «Скоро» осталось только у доски по ссылке. Боковая панель
  // в подписку не входит: хозяин 23.11 — «по сути это расширение, а его любой поставить может»
  testWidgets('четыре пункта, один — скоро, панели браузера нет', (tester) async {
    await open(tester);
    for (final title in ['Синхронизация со сквозным шифрованием', 'Облако для файлов', 'История версий', 'Доска по ссылке']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Боковая панель в браузере'), findsNothing);
    expect(find.text('Скоро'), findsOneWidget);
    expect(find.textContaining('за месяц — все'), findsOneWidget);
  });

  testWidgets('цены внешней кассы в валюте страны, смена валюты', (tester) async {
    await open(tester);
    await reveal(tester, find.byKey(const ValueKey('paywall-continue')));
    // страна устройства — Россия: рубли (тысячи через неразрывный пробел), у года выгода к помесячной
    expect(find.textContaining(RegExp(r'1\s990')), findsOneWidget);
    expect(find.textContaining('299'), findsWidgets);
    expect(find.byKey(const ValueKey('saving-year')), findsOneWidget);
    expect(find.text('Выгода 44%'), findsOneWidget);
    await reveal(tester, find.byKey(const ValueKey('currency-USD')));
    await tester.tap(find.byKey(const ValueKey('currency-USD')));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('plan-year')));
    expect(find.textContaining('19,99'), findsOneWidget);
    expect(find.textContaining(RegExp(r'1\s990')), findsNothing);
  });

  testWidgets('не вошёл — сперва вход, потом счёт', (tester) async {
    await open(tester);
    await tapContinue(tester);
    expect(find.text('Вход'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('sync-email')), 'me@x.io');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sync-get-code')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sync-code')), '123456');
    await settle(tester);
    // вход закрылся, счёт выписан на выбранный год в рублях, страница оплаты открыта
    expect(requests, contains('POST /v1/billing/lava/checkout'));
    expect(world.openedUrls.single.toString(), 'https://pay.test/year-RUB');
    expect(find.byKey(const ValueKey('paywall-waiting')), findsOneWidget);
  });

  testWidgets('внешняя касса: вернулся — подписка включилась', (tester) async {
    await signedIn();
    await open(tester);
    await reveal(tester, find.byKey(const ValueKey('plan-month')));
    await tester.tap(find.byKey(const ValueKey('plan-month')));
    await tester.pump();
    await tapContinue(tester);
    expect(world.openedUrls.single.toString(), 'https://pay.test/month-RUB');
    expect(find.text('Ждём оплату'), findsOneWidget);
    // человек заплатил и вернулся в приложение
    paid = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(find.byKey(const ValueKey('paywall-done')), findsOneWidget);
    expect(find.text('Stowa Sync включена'), findsOneWidget);
  });

  testWidgets('внешняя касса: опрос сервера тоже видит оплату', (tester) async {
    await signedIn();
    await open(tester);
    await tapContinue(tester);
    paid = true;
    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
    expect(find.byKey(const ValueKey('paywall-done')), findsOneWidget);
  });

  testWidgets('сборка магазина: только магазин', (tester) async {
    world
      ..storeChannel = StoreChannel.play
      ..storeBilling = FakeStore();
    await signedIn();
    await open(tester);
    await reveal(tester, find.byKey(const ValueKey('paywall-restore')));
    expect(find.text('19,99 \$'), findsOneWidget);
    expect(find.byKey(const ValueKey('currency-RUB')), findsNothing);
    expect(find.byKey(const ValueKey('paywall-restore')), findsOneWidget);
    expect(find.textContaining('Google Play'), findsOneWidget);
    expect(requests, isNot(contains('GET /v1/billing/plans')));
  });

  testWidgets('покупка в магазине закрывается после ответа сервера', (tester) async {
    final store = FakeStore();
    world
      ..storeChannel = StoreChannel.play
      ..storeBilling = store;
    await signedIn();
    await open(tester);
    await tapContinue(tester);
    expect(store.bought.single, (SubPlan.year, '5d0c3c47-3b47-4b67-a1c4-6a0b2a1f9e10'));
    expect(requests, contains('POST /v1/billing/play'));
    expect(store.completed, ['tok-year']);
    expect(find.byKey(const ValueKey('paywall-done')), findsOneWidget);
  });

  testWidgets('чек другого аккаунта — сообщение, покупка закрыта', (tester) async {
    final store = FakeStore();
    verifyStatus = 409;
    world
      ..storeChannel = StoreChannel.play
      ..storeBilling = store;
    await signedIn();
    await open(tester);
    await tapContinue(tester);
    expect(find.textContaining('привязана к другому аккаунту'), findsOneWidget);
    expect(store.completed, ['tok-year']);
  });

  testWidgets('сервер не ответил — покупка не закрывается, магазин пришлёт её снова', (tester) async {
    final store = FakeStore();
    verifyStatus = 502;
    world
      ..storeChannel = StoreChannel.play
      ..storeBilling = store;
    await signedIn();
    await open(tester);
    await tapContinue(tester);
    expect(find.textContaining('Оплата сейчас недоступна'), findsOneWidget);
    expect(store.completed, isEmpty);
  });

  test('ни одна строка словарей не называет внешнюю кассу', () {
    for (final file in Directory('lib/l10n').listSync().whereType<File>().where((f) => f.path.endsWith('.arb'))) {
      final values = (jsonDecode(file.readAsStringSync()) as Map<String, Object?>).entries.where((e) => !e.key.startsWith('@')).map((e) => '${e.value}'.toLowerCase());
      expect(values.where((v) => v.contains('lava')), isEmpty, reason: file.path);
    }
  });
}
