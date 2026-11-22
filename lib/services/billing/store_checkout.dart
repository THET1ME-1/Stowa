import 'dart:async';

import 'billing_api.dart';
import 'checkout.dart';
import 'store_channel.dart';
import 'subscription.dart';
import 'subscription_service.dart';

/// Состояние покупки магазина.
enum StorePurchaseState { pending, purchased, restored, canceled, error }

/// Покупка, как её прислал магазин.
class StorePurchase {
  const StorePurchase({required this.productId, required this.state, this.token, this.native});

  final String productId;
  final StorePurchaseState state;

  /// Что проверяет сервер: токен покупки Google или номер сделки Apple.
  final String? token;

  /// Покупка плагина: её закрывают на устройстве.
  final Object? native;
}

/// Магазин устройства: Google Play или App Store.
abstract interface class StoreBilling {
  /// Тарифы магазина. Пусто — магазин недоступен (нет сервисов Google, чужой аккаунт).
  Future<List<PlanOffer>> products();

  /// Начать покупку. false — магазин не открыл оплату.
  Future<bool> buy(PlanOffer offer, String buyerId);

  Future<void> restore(String buyerId);

  Stream<List<StorePurchase>> get purchases;

  /// Закрыть покупку на устройстве: Google подтверждает её, Apple снимает из очереди.
  Future<void> complete(StorePurchase purchase);
}

/// Касса магазина. Каждая покупка сперва уходит на сервер, и только после его ответа
/// закрывается на устройстве: так оплаченное не теряется, а сервер знает о каждой покупке.
class StoreCheckout implements Checkout {
  StoreCheckout({required this.store, required this.api, required this.subscription, required this.channel}) {
    _updates = store.purchases.listen((list) {
      for (final purchase in list) {
        unawaited(_handle(purchase));
      }
    });
  }

  final StoreBilling store;
  final BillingApi api;
  final SubscriptionService subscription;
  final StoreChannel channel;
  late final StreamSubscription<List<StorePurchase>> _updates;

  /// Ждёт исход начатой покупки.
  Completer<BuyResult>? _buying;

  /// Исходы покупок, пришедших при восстановлении.
  final _restored = <BuyResult>[];

  @override
  bool get canRestore => true;

  @override
  List<String> get currencies => const [];

  @override
  String get currency => '';

  @override
  set currency(String value) {}

  @override
  Future<List<PlanOffer>> offers(String locale) async {
    try {
      return await store.products();
    } on Object {
      return const [];
    }
  }

  Future<String?> _buyerId() async {
    final known = subscription.state.value.buyerId;
    if (known != null) return known;
    return (await subscription.refresh()).buyerId;
  }

  @override
  Future<BuyResult> buy(PlanOffer offer, String locale) async {
    final buyer = await _buyerId();
    if (buyer == null) return const BuyUnavailable();
    final waiting = _buying = Completer<BuyResult>();
    try {
      if (!await store.buy(offer, buyer)) {
        _buying = null;
        return const BuyUnavailable();
      }
    } on Object {
      _buying = null;
      return const BuyFailed();
    }
    return waiting.future;
  }

  @override
  Future<BuyResult> restore() async {
    final buyer = await _buyerId();
    if (buyer == null) return const BuyUnavailable();
    _restored.clear();
    try {
      await store.restore(buyer);
    } on Object {
      return const BuyUnavailable();
    }
    // магазин присылает восстановленное следом за ответом: даём ему пару секунд
    await Future<void>.delayed(const Duration(seconds: 2));
    final done = _restored.whereType<BuyDone>().toList();
    if (done.isNotEmpty) return done.last;
    if (_restored.any((r) => r is BuyOwned)) return const BuyOwned();
    return (await subscription.refresh()).activeNow ? BuyDone(subscription.state.value) : const BuyNothing();
  }

  Future<void> _handle(StorePurchase purchase) async {
    final result = await _resultOf(purchase);
    if (purchase.state == StorePurchaseState.restored) _restored.add(result);
    final waiting = _buying;
    // покупка пришла сама (недоделанная с прошлого запуска, восстановление) — экран не ждёт её
    if (waiting == null || waiting.isCompleted || purchase.state == StorePurchaseState.restored) return;
    // ожидание магазина (оплата наличными, одобрение родителя): экран покажет «Ждём оплату»,
    // а исход придёт позже и включит подписку сам
    _buying = null;
    waiting.complete(result);
  }

  Future<BuyResult> _resultOf(StorePurchase purchase) async {
    switch (purchase.state) {
      case StorePurchaseState.pending:
        return const BuyWaiting();
      case StorePurchaseState.canceled:
        await _complete(purchase);
        return const BuyCancelled();
      case StorePurchaseState.error:
        await _complete(purchase);
        return const BuyFailed();
      case StorePurchaseState.purchased || StorePurchaseState.restored:
        final token = purchase.token;
        final session = await subscription.sync.token();
        if (token == null || session == null) return const BuyUnavailable();
        final verdict = channel == StoreChannel.appstore ? await api.verifyApple(session, token) : await api.verifyPlay(session, token);
        switch (verdict) {
          case StoreOk():
            await _complete(purchase);
            final fresh = await subscription.refresh();
            return BuyDone(fresh);
          case StoreOwned():
            // покупка цела, но на другом аккаунте: на этом устройстве её можно закрыть
            await _complete(purchase);
            return const BuyOwned();
          case StoreInvalid():
            await _complete(purchase);
            return const BuyFailed();
          case StoreUnavailable():
            // не закрываем: магазин пришлёт покупку снова при следующем запуске
            return const BuyUnavailable();
        }
    }
  }

  Future<void> _complete(StorePurchase purchase) async {
    try {
      await store.complete(purchase);
    } on Object {
      // магазин пришлёт покупку снова — закроем тогда
    }
  }

  void dispose() => unawaited(_updates.cancel());
}

/// Тариф по товару магазина: базовый план Google или товар Apple.
SubPlan? planForStore(String id) => switch (id) {
  'month' || 'stowa_sub_month' => SubPlan.month,
  'quarter' || 'stowa_sub_quarter' => SubPlan.quarter,
  'year' || 'stowa_sub_year' => SubPlan.year,
  _ => null,
};
