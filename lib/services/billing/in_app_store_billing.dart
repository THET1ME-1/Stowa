import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'checkout.dart';
import 'store_channel.dart';
import 'store_checkout.dart';

/// Подписка Google Play: один товар, сроки — базовые планы.
const playSubscription = 'stowa_sub';

/// Товары App Store: по товару на срок.
const appStoreProducts = {'stowa_sub_month', 'stowa_sub_quarter', 'stowa_sub_year'};

/// Магазин устройства через `in_app_purchase`: Google Play Billing на Android, StoreKit 2 на iPhone.
class InAppStoreBilling implements StoreBilling {
  InAppStoreBilling(this.channel);

  final StoreChannel channel;
  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  Future<List<PlanOffer>> products() async {
    if (!await _iap.isAvailable()) return const [];
    final ids = channel == StoreChannel.play ? {playSubscription} : appStoreProducts;
    final response = await _iap.queryProductDetails(ids);
    final offers = <PlanOffer>[];
    for (final details in response.productDetails) {
      final String planId;
      if (details is GooglePlayProductDetails) {
        // каждый базовый план и каждое промо-предложение приходят отдельной строкой: берём планы
        final index = details.subscriptionIndex;
        final offer = index == null ? null : details.productDetails.subscriptionOfferDetails?[index];
        if (offer == null || offer.offerId != null) continue;
        planId = offer.basePlanId;
      } else {
        planId = details.id;
      }
      final plan = planForStore(planId);
      if (plan == null || offers.any((o) => o.plan == plan)) continue;
      offers.add(PlanOffer(plan: plan, price: details.price, amount: details.rawPrice, currency: details.currencyCode, native: details));
    }
    offers.sort((a, b) => a.plan.index.compareTo(b.plan.index));
    return offers;
  }

  @override
  Future<bool> buy(PlanOffer offer, String buyerId) {
    final details = offer.native! as ProductDetails;
    // номер покупателя магазин вернёт в чеке: obfuscatedAccountId у Google, appAccountToken у Apple
    final param = details is GooglePlayProductDetails
        ? GooglePlayPurchaseParam(productDetails: details, applicationUserName: buyerId)
        : PurchaseParam(productDetails: details, applicationUserName: buyerId);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  @override
  Future<void> restore(String buyerId) => _iap.restorePurchases(applicationUserName: buyerId);

  @override
  Stream<List<StorePurchase>> get purchases => _iap.purchaseStream.map((list) => [for (final details in list) _purchase(details)]);

  StorePurchase _purchase(PurchaseDetails details) => StorePurchase(
    productId: details.productID,
    state: switch (details.status) {
      PurchaseStatus.pending => StorePurchaseState.pending,
      PurchaseStatus.purchased => StorePurchaseState.purchased,
      PurchaseStatus.restored => StorePurchaseState.restored,
      PurchaseStatus.canceled => StorePurchaseState.canceled,
      PurchaseStatus.error => StorePurchaseState.error,
    },
    // Google проверяется по токену покупки, Apple — по номеру сделки StoreKit 2
    token: channel == StoreChannel.play ? details.verificationData.serverVerificationData : details.purchaseID,
    native: details,
  );

  @override
  Future<void> complete(StorePurchase purchase) async {
    final details = purchase.native;
    if (details is PurchaseDetails && details.pendingCompletePurchase) await _iap.completePurchase(details);
  }
}
