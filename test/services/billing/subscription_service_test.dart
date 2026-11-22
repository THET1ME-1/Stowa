import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/services/billing/billing_api.dart';
import 'package:stowa/services/billing/store_channel.dart';
import 'package:stowa/services/billing/subscription.dart';
import 'package:stowa/services/billing/subscription_service.dart';
import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_service.dart';
import 'package:stowa/services/vault/vault_reader.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late SyncService sync;
  late MemoryKeyStore subStore;
  late SubscriptionService service;
  late List<String> requests;
  late Map<String, Object?> account;
  late bool offline;

  final soon = DateTime.now().toUtc().add(const Duration(days: 20));

  Map<String, Object?> paidAccount() => {
    'email': 'me@x.io',
    'active': true,
    'paid_until': soon.toIso8601String(),
    'buyer_id': '5d0c3c47-3b47-4b67-a1c4-6a0b2a1f9e10',
    'source': 'lava',
    'plan': 'quarter',
    'auto_renew': true,
    'test': false,
    'cancellable': true,
  };

  setUp(() async {
    db = AppDatabase.memory();
    root = Directory.systemTemp.createTempSync('stowa_subscription');
    final syncStore = MemoryKeyStore();
    await syncStore.write(SyncAccount(email: 'me@x.io', token: 't', key: VaultKey.generate().bytes, vaultDb: 'stowa').toJson());
    subStore = MemoryKeyStore();
    requests = [];
    offline = false;
    account = {...paidAccount(), 'active': false, 'paid_until': null, 'source': null, 'plan': null, 'cancellable': false};
    final client = MockClient((request) async {
      if (offline) throw const SocketException('нет сети');
      final path = request.url.path;
      requests.add('${request.method} $path');
      if (path == '/v1/account') return http.Response(jsonEncode(account), 200, headers: {'content-type': 'application/json'});
      if (path == '/v1/changes') {
        // ожидание правок: настоящий сервер держит запрос, здесь — короткая пауза вместо холостого круга
        if (request.url.queryParameters['wait'] != '0' && request.url.queryParameters['wait'] != null) await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response('{"cursor":0,"more":false,"changes":[]}', 200);
      }
      if (path == '/v1/billing/plans') {
        return http.Response(jsonEncode({'lava': {'RUB': {'month': 299, 'quarter': 749, 'year': 1990}, 'USD': {'month': 5, 'quarter': 6.99, 'year': 19.99}}}), 200);
      }
      return http.Response('', 404);
    });
    sync = SyncService(db: db, root: root, vaultDb: () => 'stowa', reader: VaultReader(db, root: root, clock: DateTime.now), store: syncStore, client: client);
    sync.trigger = () => sync.run().then((_) {});
    service = SubscriptionService(sync: sync, store: subStore, api: BillingApi(client));
  });

  tearDown(() async {
    sync.dispose();
    await db.close();
    root.deleteSync(recursive: true);
  });

  test('сборка выбирает кассу по метке', () {
    expect(storeChannelFrom(''), StoreChannel.direct);
    expect(storeChannelFrom('play'), StoreChannel.play);
    expect(storeChannelFrom('appstore'), StoreChannel.appstore);
    expect(storeChannelFrom('что-то'), StoreChannel.direct);
  });

  test('снимок подписки читается без сети', () async {
    await subStore.write(jsonEncode(Subscription.fromAccount(paidAccount()).toJson()));
    offline = true;
    await service.load();
    expect(service.state.value.activeNow, isTrue);
    expect(service.state.value.plan, SubPlan.quarter);
    expect(service.state.value.source, SubSource.lava);
    await service.refresh();
    expect(service.state.value.activeNow, isTrue);
  });

  test('истёкший снимок не открывает', () async {
    await subStore.write(jsonEncode(Subscription.fromAccount({...paidAccount(), 'paid_until': DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String()}).toJson()));
    offline = true;
    await service.load();
    expect(service.state.value.signedIn, isTrue);
    expect(service.state.value.activeNow, isFalse);
  });

  test('обновление включает синхронизацию', () async {
    sync.deactivate();
    expect(sync.status.value.inactive, isTrue);
    account = paidAccount();
    final now = await service.refresh();
    expect(now.activeNow, isTrue);
    expect(sync.status.value.inactive, isFalse);
    // проход пошёл сразу: ждать следующей правки незачем
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(requests, contains('GET /v1/changes'));
    expect(jsonDecode((await subStore.read())!), containsPair('active', true));
    sync.stopListening();
  });

  test('подписка кончилась — синхронизация гаснет', () async {
    account = paidAccount();
    await service.refresh();
    account = {...paidAccount(), 'active': false};
    await service.refresh();
    expect(service.state.value.activeNow, isFalse);
    expect(sync.status.value.inactive, isTrue);
    sync.stopListening();
  });

  test('сеть упала — снимок прежний', () async {
    account = paidAccount();
    await service.refresh();
    offline = true;
    await service.refresh();
    expect(service.state.value.activeNow, isTrue);
    sync.stopListening();
  });

  test('не вошёл — снимок пустой, сервер не спрашивают', () async {
    await sync.signOut();
    requests.clear();
    expect((await service.refresh()).signedIn, isFalse);
    expect(requests, isEmpty);
  });

  test('выход стирает снимок', () async {
    account = paidAccount();
    await service.refresh();
    await service.signedOut();
    expect(service.state.value.signedIn, isFalse);
    expect(await subStore.read(), isNull);
    sync.stopListening();
  });

  test('цены внешней кассы и ответы на чеки', () async {
    final prices = await BillingApi(MockClient((_) async => http.Response(jsonEncode({'lava': {'RUB': {'month': 299, 'quarter': 749, 'year': 1990}}}), 200))).lavaPrices();
    expect(prices, {'RUB': {SubPlan.month: 299, SubPlan.quarter: 749, SubPlan.year: 1990}});
    expect(await BillingApi(MockClient((_) async => http.Response('{"lava":null}', 200))).lavaPrices(), isNull);
    Future<StoreVerdict> verdict(int status, [String body = '{}']) => BillingApi(MockClient((_) async => http.Response(body, status))).verifyPlay('t', 'purchase');
    expect(await verdict(200, '{"active":true,"until":"2027-01-01T00:00:00Z"}'), isA<StoreOk>().having((v) => v.until, 'until', DateTime.utc(2027)));
    expect(await verdict(409), isA<StoreOwned>());
    expect(await verdict(422), isA<StoreInvalid>());
    expect(await verdict(502), isA<StoreUnavailable>());
  });
}
