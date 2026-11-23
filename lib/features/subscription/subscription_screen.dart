import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/desk_mode.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/billing/store_channel.dart';
import '../../services/billing/subscription.dart';
import '../settings/settings_blocks.dart';
import 'subscription_date.dart';

/// Страницы подписок магазинов: отменяют магазинную подписку там.
final _playSubscriptions = Uri.parse('https://play.google.com/store/account/subscriptions?sku=stowa_sub&package=app.stowa');
final _appleSubscriptions = Uri.parse('https://apps.apple.com/account/subscriptions');

String planName(L l, SubPlan plan) => switch (plan) {
  SubPlan.month => l.planMonth,
  SubPlan.quarter => l.planQuarter,
  SubPlan.year => l.planYear,
};

/// Откуда подписка, без названия внешней кассы: сборки магазинов показывают тот же экран.
String sourceName(L l, SubSource source) => switch (source) {
  SubSource.grant => l.subSourceGrant,
  SubSource.lava => l.subSourceCard,
  SubSource.play => l.subSourcePlay,
  SubSource.apple => l.subSourceApple,
};

/// Что о купленной подписке написано под тем, что она даёт: тариф, откуда, продление. Отменить
/// продление оплаты картой можно здесь (только вне магазинов), магазинную — на странице
/// подписок своего магазина. Срок — в карточке «Подписка уже куплена» над списком.
class SubscriptionDetails extends ConsumerStatefulWidget {
  const SubscriptionDetails({super.key});

  @override
  ConsumerState<SubscriptionDetails> createState() => _SubscriptionDetailsState();
}

/// Срок купленной подписки одной фразой: «Продлится 21 декабря», «Продление отменено,
/// доступ до 21 декабря», «Выдана командой Stowa, до 21 декабря».
String ownedLine(BuildContext context, L l, Subscription subscription) {
  final until = subscription.paidUntil;
  if (until == null) return l.subUntil;
  // дата не рвётся по строкам: «2 января» на одной, «2027 г.» на другой читается плохо
  final date = subscriptionDate(context, until).replaceAll(' ', ' ');
  return switch (subscription.source) {
    SubSource.grant || null => l.subOwnedGrant(date),
    _ when subscription.autoRenew => l.subRenewOn(date),
    _ => l.subRenewOff(date),
  };
}

class _SubscriptionDetailsState extends ConsumerState<SubscriptionDetails> {
  bool _busy = false;
  String? _error;

  Future<void> _cancel(Subscription subscription) async {
    final l = L.of(context);
    final date = subscriptionDate(context, subscription.paidUntil!);
    final yes = await showStowaSheet<bool>(
      context,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.subCancelAsk(date), style: Theme.of(sheet).textTheme.titleMedium!.copyWith(height: 1.35)),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('sub-cancel-yes'),
              style: FilledButton.styleFrom(backgroundColor: Tokens.error, foregroundColor: Tokens.onError),
              onPressed: () => Navigator.pop(sheet, true),
              child: Text(l.subCancel),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(sheet, false), child: Text(l.subKeep)),
          ],
        ),
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final token = await ref.read(syncServiceProvider).token();
      if (token != null) await ref.read(billingApiProvider).lavaCancel(token);
      await ref.read(subscriptionServiceProvider).refresh();
      messenger?.showSnackBar(SnackBar(content: Text(l.subCancelled)));
      if (mounted) setState(() => _busy = false);
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.syncNoServer;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final subscription = ref.watch(subscriptionProvider).value ?? Subscription.none;
    final channel = ref.watch(storeChannelProvider);
    final source = subscription.source;
    // магазинную подписку отменяют в её магазине; чужой магазин сборка не называет
    final manage = switch (source) {
      SubSource.play when channel != StoreChannel.appstore => (l.subManagePlay, _playSubscriptions),
      SubSource.apple when channel != StoreChannel.play => (l.subManageApple, _appleSubscriptions),
      _ => null,
    };
    final canCancel = channel == StoreChannel.direct && source == SubSource.lava && subscription.cancellable;
    final plan = subscription.plan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plan != null || source != null)
          SettingsGroup(
            tint: settingsTint('sky'),
            children: [
              if (plan != null) SettingsRow(key: const ValueKey('sub-plan'), icon: 'event_repeat', title: planName(l, plan), value: l.subPlan, onTap: null),
              if (source != null) SettingsRow(key: const ValueKey('sub-source'), icon: 'payments', title: sourceName(l, source), value: subscription.test ? l.subTest : null, onTap: null),
            ],
          ),
        if (canCancel || manage != null) ...[
          const SizedBox(height: 16),
          SettingsGroup(
            tint: settingsTint('rose'),
            children: [
              if (canCancel) SettingsRow(key: const ValueKey('sub-cancel'), icon: 'event_busy', title: l.subCancel, onTap: _busy ? null : () => _cancel(subscription)),
              if (manage case (final label, final url)) SettingsRow(key: const ValueKey('sub-manage'), icon: 'open_in_new', title: label, onTap: () => ref.read(urlOpenerProvider)(url)),
            ],
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(_error!, style: text.bodyMedium!.copyWith(color: Tokens.error, height: 1.4)),
          ),
      ],
    );
  }
}
