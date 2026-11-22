import 'package:intl/intl.dart';

import 'subscription.dart';

/// Тариф на экране покупки: срок, цена строкой и числом.
class PlanOffer {
  const PlanOffer({required this.plan, required this.price, required this.amount, required this.currency, this.native});

  final SubPlan plan;

  /// Цена, как её показать: «1 990 ₽», «$19.99».
  final String price;
  final num amount;
  final String currency;

  /// Товар магазина для покупки; у внешней кассы — нет.
  final Object? native;

  /// Месяцев в сроке: для цены в месяц и выгоды.
  int get months => switch (plan) {
    SubPlan.month => 1,
    SubPlan.quarter => 3,
    SubPlan.year => 12,
  };
}

/// Цена по правилам языка: целое без копеек («299 ₽»), дробное — с ними («6,99 $»).
String formatPrice(num amount, String currency, String locale) {
  final whole = amount == amount.roundToDouble();
  return NumberFormat.simpleCurrency(locale: locale, name: currency, decimalDigits: whole ? 0 : 2).format(amount);
}

/// Выгода тарифа к помесячной оплате в процентах; 0 — выгоды нет.
int savingPercent(PlanOffer offer, PlanOffer? month) {
  if (month == null || offer.months == 1 || month.currency != offer.currency || month.amount <= 0) return 0;
  final full = month.amount * offer.months;
  return ((1 - offer.amount / full) * 100).floor().clamp(0, 99);
}

/// Чем кончилась покупка.
sealed class BuyResult {
  const BuyResult();
}

/// Подписка включилась.
class BuyDone extends BuyResult {
  const BuyDone(this.subscription);

  final Subscription subscription;
}

/// Ждём оплату: страница оплаты открыта ([url]) или магазин держит покупку в ожидании (null).
class BuyWaiting extends BuyResult {
  const BuyWaiting([this.url]);

  final String? url;
}

/// Человек сам закрыл оплату.
class BuyCancelled extends BuyResult {
  const BuyCancelled();
}

/// Покупка магазина принадлежит другому аккаунту Stowa.
class BuyOwned extends BuyResult {
  const BuyOwned();
}

/// Оплата не прошла.
class BuyFailed extends BuyResult {
  const BuyFailed();
}

/// Касса или сервер не ответили: покупка цела, проверка повторится.
class BuyUnavailable extends BuyResult {
  const BuyUnavailable();
}

/// Восстанавливать нечего.
class BuyNothing extends BuyResult {
  const BuyNothing();
}

/// Касса сборки: внешняя или магазин.
abstract class Checkout {
  /// Тарифы с ценами на языке [locale]. Пусто — касса недоступна.
  Future<List<PlanOffer>> offers(String locale);

  /// Купить; [locale] — язык страницы оплаты внешней кассы.
  Future<BuyResult> buy(PlanOffer offer, String locale);

  /// «Восстановить покупку» есть только у магазинов.
  bool get canRestore;

  Future<BuyResult> restore();

  /// Валюты на выбор (внешняя касса); у магазина цену и валюту даёт он сам.
  List<String> get currencies;

  String get currency;
  set currency(String value);
}
