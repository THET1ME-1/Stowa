import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_blocks.dart';
import 'account_screen.dart';
import 'sign_in_screen.dart';

/// Строка аккаунта в настройках: «Войти» для тех, кому выдали подписку, или почта аккаунта.
class AccountRow extends ConsumerWidget {
  const AccountRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final email = ref.watch(accountEmailProvider).value;
    // вошли здесь — служба подписки спросит сервер, даже если настройки открыты одни
    ref.listen(subscriptionProvider, (_, _) {});
    return SettingsGroup(
      tint: settingsTint('amber'),
      children: [
        if (email == null)
          SettingsRow(
            key: const ValueKey('settings-sign-in'),
            icon: 'login',
            title: l.accountSignIn,
            value: l.accountSignInHint,
            onTap: () => Navigator.of(context).push(signInRoute()),
          )
        else
          SettingsRow(key: const ValueKey('settings-account'), icon: 'account_circle', title: email, value: l.accountTitle, onTap: () => Navigator.of(context).push(accountRoute())),
      ],
    );
  }
}
