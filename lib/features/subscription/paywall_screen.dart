import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/billing/checkout.dart';
import '../../services/billing/store_channel.dart';
import '../../services/billing/subscription.dart';
import '../account/sign_in_screen.dart';
import '../settings/settings_blocks.dart';
import '../../core/widgets/pressable.dart';
import '../settings/settings_screen.dart' show privacyPolicyUrl;
import 'subscription_date.dart';
import 'subscription_screen.dart';

Route<void> paywallRoute() => settingsPageRoute(const PaywallScreen());

/// Экран подписки один на оба случая, как Togetherly+: не куплено — что даёт и покупка,
/// куплено — то же самое с отметкой «уже куплена», сроком и управлением.
Route<void> subscriptionRoute() => paywallRoute();

/// Условия подписки: в сборке App Store — стандартное соглашение Apple, иначе — свои.
Uri termsUrl(Locale locale, StoreChannel channel) => channel == StoreChannel.appstore
    ? Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/')
    : Uri.parse('https://thet1me-1.github.io/Stowa/${locale.languageCode == 'ru' ? 'ru/' : ''}terms.html');

/// Что даёт подписка. [soon] — ещё не вышло: экран не продаёт несделанное как готовое.
typedef _Feature = ({String icon, String tint, String Function(L) title, String Function(L) hint, bool soon});

final List<_Feature> _features = [
  (icon: 'cloud_sync', tint: 'sky', title: (l) => l.featureSync, hint: (l) => l.featureSyncHint, soon: false),
  (icon: 'photo_library', tint: 'teal', title: (l) => l.featureFiles, hint: (l) => l.featureFilesHint, soon: false),
  (icon: 'history', tint: 'amber', title: (l) => l.featureHistory, hint: (l) => l.featureHistoryHint, soon: false),
  (icon: 'link', tint: 'rose', title: (l) => l.featureLinks, hint: (l) => l.featureLinksHint, soon: true),
];

enum _Phase { choose, waiting, done }

/// Экран подписки Stowa Sync. Не куплено: что даёт подписка, три срока, оплата кассой этой
/// сборки; не вошёл — сперва вход по почте, потом оплата, без лишнего касания. Куплено: тот
/// же список с карточкой «Подписка уже куплена», тариф, откуда и управление продлением.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  List<PlanOffer>? _offers;
  SubPlan _selected = SubPlan.year;
  _Phase _phase = _Phase.choose;
  bool _busy = false;
  String? _error;
  String? _payUrl;
  Timer? _poll;
  late final AppLifecycleListener _lifecycle;

  Checkout get _checkout => ref.read(checkoutProvider);
  String get _locale => Localizations.localeOf(context).toString();

  @override
  void initState() {
    super.initState();
    // вернулся со страницы оплаты — сразу спросить сервер, не дожидаясь следующего опроса
    _lifecycle = AppLifecycleListener(onResume: () {
      if (_phase == _Phase.waiting) _check();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final offers = await _checkout.offers(_locale);
    if (!mounted) return;
    setState(() {
      _offers = offers;
      if (offers.isNotEmpty && !offers.any((o) => o.plan == _selected)) _selected = offers.last.plan;
    });
  }

  Future<void> _check() async {
    final fresh = await ref.read(subscriptionServiceProvider).refresh();
    if (mounted && fresh.activeNow) _finish();
  }

  void _finish() {
    _poll?.cancel();
    setState(() {
      _phase = _Phase.done;
      _busy = false;
      _error = null;
    });
  }

  /// Ждём оплату: раз в 5 секунд полчаса спрашиваем сервер.
  void _wait(String? url) {
    _poll?.cancel();
    final until = DateTime.now().add(const Duration(minutes: 30));
    _poll = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (DateTime.now().isAfter(until)) return timer.cancel();
      _check();
    });
    setState(() {
      _phase = _Phase.waiting;
      _payUrl = url;
      _busy = false;
    });
  }

  Future<void> _continue() async {
    final offer = _offers?.where((o) => o.plan == _selected).firstOrNull;
    if (offer == null || _busy) return;
    final l = L.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    // покупка живёт на аккаунте: без входа платить некуда
    if (await ref.read(syncServiceProvider).account() == null) {
      if (!mounted) return;
      final signedIn = await Navigator.of(context).push(signInRoute());
      if (!mounted) return;
      if (signedIn != true) return setState(() => _busy = false);
      // выданная подписка нашлась сразу после входа — платить незачем
      if ((await ref.read(subscriptionServiceProvider).refresh()).activeNow) return _finish();
    }
    final result = await _checkout.buy(offer, _locale);
    if (!mounted) return;
    switch (result) {
      case BuyDone():
        _finish();
      case BuyWaiting(:final url):
        _wait(url);
      case BuyCancelled():
        setState(() => _busy = false);
      case BuyOwned():
        _fail(l.paywallOwned);
      case BuyFailed():
        _fail(l.paywallFailed);
      case BuyUnavailable() || BuyNothing():
        _fail(l.paywallUnavailable);
    }
  }

  void _fail(String message) => setState(() {
    _busy = false;
    _error = message;
  });

  Future<void> _restore() async {
    final l = L.of(context);
    if (await ref.read(syncServiceProvider).account() == null) {
      if (!mounted) return;
      final signedIn = await Navigator.of(context).push(signInRoute());
      if (!mounted || signedIn != true) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _checkout.restore();
    if (!mounted) return;
    switch (result) {
      case BuyDone():
        _finish();
      case BuyOwned():
        _fail(l.paywallOwned);
      case BuyNothing():
        _fail(l.paywallRestoreNothing);
      case _:
        _fail(l.paywallUnavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final subscription = ref.watch(subscriptionProvider).value ?? Subscription.none;
    // оплата пришла, пока экран открыт (опрос, уведомление, другое устройство)
    ref.listen(subscriptionProvider, (_, next) {
      if ((next.value?.activeNow ?? false) && _phase == _Phase.waiting) _finish();
    });
    // подписка уже есть (открыли купленную или оплата только что прошла): вместо покупки — что
    // куплено и как ей управлять
    final owned = subscription.activeNow && _phase != _Phase.waiting && !_busy;
    final copyUntil = subscription.copyAtRisk ? subscription.copyUntil : null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            SettingsHeader(l.syncTitle),
            const SizedBox(height: 18),
            if (owned)
              _OwnedCard(title: l.subOwnedTitle, line: ownedLine(context, l, subscription))
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(l.paywallLead, style: text.bodyLarge!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
              ),
              // подписка кончилась, копия на сервере ещё живёт: до какого дня
              if (copyUntil != null)
                Padding(
                  key: const ValueKey('paywall-copy-until'),
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                  child: Text(l.syncCopyUntil(subscriptionDate(context, copyUntil)), style: text.bodyMedium!.copyWith(color: Tokens.onSurface, height: 1.4)),
                ),
            ],
            const SizedBox(height: 20),
            _FeatureList(l: l),
            const SizedBox(height: 24),
            // оплата только что прошла: подтверждение там, где человек нажимал «Продолжить»
            if (_phase == _Phase.done)
              _DoneCard(subscription: subscription, onClose: () => Navigator.of(context).maybePop())
            else if (owned)
              const SubscriptionDetails()
            else if (_phase == _Phase.waiting)
              _WaitingCard(url: _payUrl, onOpen: _payUrl == null ? null : () => ref.read(urlOpenerProvider)(Uri.parse(_payUrl!)))
            else
              _choose(l, text),
          ],
        ),
      ),
    );
  }

  Widget _choose(L l, TextTheme text) {
    final channel = ref.watch(storeChannelProvider);
    final offers = _offers;
    final month = offers?.where((o) => o.plan == SubPlan.month).firstOrNull;
    final currencies = _checkout.currencies;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (currencies.length > 1) ...[
          Wrap(
            spacing: 8,
            children: [
              for (final currency in currencies)
                ChoiceChip(
                  key: ValueKey('currency-$currency'),
                  label: Text(_currencySign(currency)),
                  selected: currency == _checkout.currency,
                  onSelected: (_) {
                    _checkout.currency = currency;
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (offers == null)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (offers.isEmpty)
          Text(l.paywallUnavailable, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant))
        else
          for (final offer in offers.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlanCard(
                offer: offer,
                saving: savingPercent(offer, month),
                perMonth: offer.months == 1 ? null : _perMonth(offer),
                selected: offer.plan == _selected,
                onTap: _busy ? null : () => setState(() => _selected = offer.plan),
              ),
            ),
        if (_error != null)
          Padding(
            key: const ValueKey('paywall-error'),
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(_error!, style: text.bodyMedium!.copyWith(color: Tokens.error, height: 1.4)),
          ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('paywall-continue'),
          onPressed: offers == null || offers.isEmpty || _busy ? null : _continue,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: Tokens.accent, foregroundColor: Tokens.onAccent),
          child: _busy ? SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Tokens.onAccent)) : Text(l.paywallContinue),
        ),
        const SizedBox(height: 16),
        Text(
          switch (channel) {
            StoreChannel.direct => l.paywallRenewDirect,
            StoreChannel.play => l.paywallRenewPlay,
            StoreChannel.appstore => l.paywallRenewApple,
          },
          style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant, height: 1.45),
        ),
        const SizedBox(height: 4),
        Wrap(
          children: [
            TextButton(key: const ValueKey('paywall-terms'), onPressed: () => ref.read(urlOpenerProvider)(termsUrl(Localizations.localeOf(context), channel)), child: Text(l.paywallTerms)),
            TextButton(key: const ValueKey('paywall-privacy'), onPressed: () => ref.read(urlOpenerProvider)(privacyPolicyUrl(Localizations.localeOf(context))), child: Text(l.paywallPrivacy)),
            if (_checkout.canRestore) TextButton(key: const ValueKey('paywall-restore'), onPressed: _busy ? null : _restore, child: Text(l.paywallRestore)),
          ],
        ),
      ],
    );
  }

  /// Цена в месяц: рубли и крупные суммы — целыми, мелкие — с копейками.
  String _perMonth(PlanOffer offer) {
    final value = offer.amount / offer.months;
    final rounded = offer.currency == 'RUB' || value >= 100 ? value.roundToDouble() : (value * 100).floor() / 100;
    return L.of(context).planPerMonth(formatPrice(rounded, offer.currency, _locale));
  }

  static String _currencySign(String currency) => switch (currency) {
    'RUB' => '₽',
    'USD' => r'$',
    'EUR' => '€',
    _ => currency,
  };
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.l});

  final L l;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        children: [
          for (final feature in _features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsIconChip(feature.icon, color: settingsTint(feature.tint)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(feature.title(l), style: text.titleSmall!.copyWith(fontWeight: FontWeight.w600)),
                            if (feature.soon)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: FolderPalette.tint(settingsTint(feature.tint), 0.22), borderRadius: BorderRadius.circular(100)),
                                child: Text(l.soon, style: text.labelSmall!.copyWith(color: FolderPalette.ink(settingsTint(feature.tint)), fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(feature.hint(l), style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Тариф: выбранный обведён акцентом, у длинных — цена в месяц и выгода.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.offer, required this.saving, required this.perMonth, required this.selected, required this.onTap});

  final PlanOffer offer;
  final int saving;
  final String? perMonth;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final name = switch (offer.plan) {
      SubPlan.month => l.planMonth,
      SubPlan.quarter => l.planQuarter,
      SubPlan.year => l.planYear,
    };
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        key: ValueKey('plan-${offer.plan.name}'),
        color: Tokens.containerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card), side: BorderSide(color: selected ? Tokens.accent : Colors.transparent, width: 2)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Tokens.accent : Colors.transparent,
                    border: Border.all(color: selected ? Tokens.accent : Tokens.outline, width: 2),
                  ),
                  child: selected ? Icon(symbolIcon('check'), size: 14, color: Tokens.onAccent) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(name, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w600)),
                          if (saving > 0)
                            Container(
                              key: ValueKey('saving-${offer.plan.name}'),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(100)),
                              child: Text(l.planSave(saving), style: text.labelSmall!.copyWith(color: Tokens.onAccent, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      if (perMonth != null) ...[
                        const SizedBox(height: 2),
                        Text(perMonth!, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(offer.price, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.url, required this.onOpen});

  final String? url;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('paywall-waiting'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Tokens.accent)),
              const SizedBox(width: 12),
              Expanded(child: Text(l.paywallWaiting, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 10),
          Text(l.paywallWaitingHint, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
          if (onOpen != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(key: const ValueKey('paywall-open-again'), onPressed: onOpen, child: Text(l.paywallOpenAgain)),
          ],
        ],
      ),
    );
  }
}

/// «Подписка уже куплена»: спокойная карточка вместо покупки, как у Togetherly+, когда он есть.
/// Залитая акцентом — только «Купить»: купленное не зовёт, а сообщает.
class OwnedCard extends StatelessWidget {
  const OwnedCard({super.key, required this.title, required this.line, this.onTap});

  final String title;
  final String line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.card)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Tokens.accent, shape: BoxShape.circle),
            child: Icon(symbolIcon('verified', filled: true), size: 22, color: Tokens.onAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(line, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.3)),
              ],
            ),
          ),
          if (onTap != null) ...[const SizedBox(width: 8), Icon(symbolIcon('chevron_right'), size: 22, color: Tokens.muted)],
        ],
      ),
    );
    return onTap == null ? card : Pressable(radius: BorderRadius.circular(Radii.card), onTap: onTap, child: card);
  }
}

class _OwnedCard extends StatelessWidget {
  const _OwnedCard({required this.title, required this.line});

  final String title;
  final String line;

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: const ValueKey('paywall-owned'), child: OwnedCard(title: title, line: line));
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.subscription, required this.onClose});

  final Subscription subscription;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final until = subscription.paidUntil;
    return Container(
      key: const ValueKey('paywall-done'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(symbolIcon('check_circle', filled: true), color: Tokens.onAccent, size: 26),
              const SizedBox(width: 12),
              Expanded(child: Text(l.paywallDone, style: text.titleLarge!.copyWith(color: Tokens.onAccent, fontWeight: FontWeight.w700))),
            ],
          ),
          if (until != null) ...[
            const SizedBox(height: 8),
            Text(l.paywallDoneUntil(subscriptionDate(context, until)), style: text.bodyLarge!.copyWith(color: Tokens.onAccent, height: 1.4)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('paywall-close'),
            onPressed: onClose,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: Tokens.onAccent, foregroundColor: Tokens.accent),
            child: Text(l.paywallDoneButton),
          ),
        ],
      ),
    );
  }
}
