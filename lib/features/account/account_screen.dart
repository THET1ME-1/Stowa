import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/desk_mode.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/billing/subscription.dart';
import '../settings/settings_blocks.dart';

Route<void> accountRoute() => settingsPageRoute(const AccountScreen());

/// Срок подписки по-человечески: «22 декабря», другой год — «22 декабря 2027 г.».
String subscriptionDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  final local = date.toLocal();
  return local.year == DateTime.now().year ? DateFormat.MMMMd(locale).format(local) : DateFormat.yMMMMd(locale).format(local);
}

/// Аккаунт: почта, подписка, выход и удаление. Удаление требуют App Store и Google Play: аккаунт
/// заводится в приложении — значит, и удаляется в нём.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.onSubscription});

  /// Касание строки подписки: экран подписки или покупка. null — строка только показывает.
  final void Function(BuildContext context, Subscription subscription)? onSubscription;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  String? _error;
  bool _busy = false;

  Future<void> _signOut() async {
    await ref.read(syncServiceProvider).signOut();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _delete(Subscription subscription) async {
    final l = L.of(context);
    final store = switch (subscription.activeNow ? subscription.source : null) {
      SubSource.play => l.accountDeleteStorePlay,
      SubSource.apple => l.accountDeleteStoreApple,
      _ => null,
    };
    final yes = await showStowaSheet<bool>(
      context,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.accountDeleteAsk(subscription.email ?? ''), style: Theme.of(sheet).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l.accountDeleteHint, style: Theme.of(sheet).textTheme.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
            if (store != null) ...[
              const SizedBox(height: 8),
              Text(store, style: Theme.of(sheet).textTheme.bodyMedium!.copyWith(color: Tokens.onSurface, height: 1.4)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('account-delete-yes'),
              style: FilledButton.styleFrom(backgroundColor: Tokens.error, foregroundColor: Tokens.onError),
              onPressed: () => Navigator.pop(sheet, true),
              child: Text(l.accountDelete),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(sheet, false), child: Text(l.cancel)),
          ],
        ),
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final sync = ref.read(syncServiceProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final token = await sync.token();
      final deleted = token != null && await ref.read(billingApiProvider).deleteAccount(token);
      if (!mounted) return;
      if (!deleted) {
        setState(() {
          _busy = false;
          _error = l.accountDeleteLive;
        });
        return;
      }
      await sync.signOut();
      messenger?.showSnackBar(SnackBar(content: Text(l.accountDeleted)));
      if (mounted) Navigator.of(context).maybePop();
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
    final subscription = ref.watch(subscriptionProvider).value ?? Subscription.none;
    final status = ref.watch(syncServiceProvider).status.value;
    final email = subscription.email ?? status.email ?? '';
    final onSubscription = widget.onSubscription;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            SettingsHeader(l.accountTitle),
            SettingsGroup(
              tint: settingsTint('sky'),
              children: [
                SettingsRow(
                  key: const ValueKey('account-email'),
                  icon: 'mail',
                  title: email,
                  value: subscription.activeNow ? l.subActiveUntil(subscriptionDate(context, subscription.paidUntil!)) : null,
                  onTap: onSubscription == null ? null : () => onSubscription(context, subscription),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsGroup(
              tint: settingsTint('rose'),
              children: [
                SettingsRow(key: const ValueKey('account-sign-out'), icon: 'logout', title: l.syncSignOut, onTap: _busy ? null : _signOut),
                SettingsRow(key: const ValueKey('account-delete'), icon: 'delete', title: l.accountDelete, onTap: _busy ? null : () => _delete(subscription.signedIn ? subscription : Subscription(signedIn: true, email: email))),
              ],
            ),
            if (_error != null)
              Padding(
                key: const ValueKey('account-error'),
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Tokens.error, height: 1.4)),
              ),
            SettingsHint(l.syncSignOutHint),
          ],
        ),
      ),
    );
  }
}
