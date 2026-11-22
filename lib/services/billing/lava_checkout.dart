import 'billing_api.dart';
import 'checkout.dart';
import 'subscription.dart';

/// Страны, где платят рублями.
const _rubleCountries = {'RU', 'BY', 'KZ', 'KG', 'AM', 'UZ', 'TJ', 'AZ'};

/// Страны евро на 2026 год (Болгария — с 1 января 2026).
const _euroCountries = {'AT', 'BE', 'BG', 'CY', 'DE', 'EE', 'ES', 'FI', 'FR', 'GR', 'HR', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PT', 'SI', 'SK'};

/// Валюта внешней кассы по стране устройства: рубли, евро или доллары.
String currencyForCountry(String? country) {
  final code = country?.toUpperCase();
  if (_rubleCountries.contains(code)) return 'RUB';
  if (_euroCountries.contains(code)) return 'EUR';
  return 'USD';
}

/// Внешняя касса: счёт заводит сервер на почту аккаунта, оплата — страницей в браузере.
/// Подписку включает уведомление кассы на сервере; экран узнаёт об этом, спрашивая сервер.
class LavaCheckout implements Checkout {
  // ignore: prefer_initializing_formals
  LavaCheckout({required this.api, required this.token, required this.open, required String currency}) : _currency = currency;

  final BillingApi api;
  final Future<String?> Function() token;

  /// Открыть страницу оплаты во внешнем браузере.
  final Future<bool> Function(Uri url) open;

  String _currency;
  Map<String, Map<SubPlan, num>>? _prices;

  @override
  String get currency => _currency;

  @override
  set currency(String value) => _currency = value;

  @override
  List<String> get currencies => _prices?.keys.toList() ?? const [];

  @override
  bool get canRestore => false;

  @override
  Future<List<PlanOffer>> offers(String locale) async {
    try {
      _prices ??= await api.lavaPrices();
    } on Object {
      return const [];
    }
    final prices = _prices;
    if (prices == null || prices.isEmpty) return const [];
    if (!prices.containsKey(_currency)) _currency = prices.containsKey('USD') ? 'USD' : prices.keys.first;
    return [
      for (final plan in SubPlan.values)
        if (prices[_currency]?[plan] case final num amount) PlanOffer(plan: plan, price: formatPrice(amount, _currency, locale), amount: amount, currency: _currency),
    ];
  }

  @override
  Future<BuyResult> buy(PlanOffer offer, String locale) async {
    final token = await this.token();
    if (token == null) return const BuyFailed();
    try {
      final invoice = await api.lavaCheckout(token, offer.plan, offer.currency, locale.split(RegExp('[_-]')).first);
      await open(Uri.parse(invoice.url));
      return BuyWaiting(invoice.url);
    } on Object {
      return const BuyUnavailable();
    }
  }

  @override
  Future<BuyResult> restore() async => const BuyNothing();
}
