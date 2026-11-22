import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/billing/subscription.dart';
import '../settings/settings_blocks.dart';
import 'paywall_screen.dart';
import 'subscription_date.dart';
import 'subscription_screen.dart';

/// Первый пункт настроек. Подписки нет — «Купить подписку», залитая акцентом темы: её видно
/// с первого взгляда. Подписка есть — строка со сроком, ведёт на экран подписки.
class SubscribeCard extends ConsumerWidget {
  const SubscribeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final subscription = ref.watch(subscriptionProvider).value ?? Subscription.none;
    if (subscription.activeNow) {
      final source = subscription.source;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SettingsGroup(
          tint: settingsTint('sky'),
          children: [
            SettingsRow(
              key: const ValueKey('settings-subscription'),
              icon: 'cloud_sync',
              title: l.subActiveUntil(subscriptionDate(context, subscription.paidUntil!)),
              value: source == null ? null : sourceName(l, source),
              onTap: () => Navigator.of(context).push(subscriptionRoute()),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AccentCard(key: const ValueKey('settings-subscribe'), title: l.subBuy, hint: l.subBuyHint, onTap: () => Navigator.of(context).push(paywallRoute())),
    );
  }
}

/// Карточка, залитая акцентом темы: предложение подписки видно с первого взгляда.
class AccentCard extends StatelessWidget {
  const AccentCard({super.key, required this.title, required this.hint, required this.onTap, this.icon = 'cloud_sync'});

  final String title;
  final String hint;
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      radius: BorderRadius.circular(Radii.card),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
        decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(Radii.card)),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Tokens.onAccent.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Icon(symbolIcon(icon, filled: true), size: 22, color: Tokens.onAccent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium!.copyWith(color: Tokens.onAccent, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(hint, style: text.bodyMedium!.copyWith(color: Tokens.onAccent.withValues(alpha: 0.82), height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(symbolIcon('chevron_right'), size: 22, color: Tokens.onAccent),
          ],
        ),
      ),
    );
  }
}
