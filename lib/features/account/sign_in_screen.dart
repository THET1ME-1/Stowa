import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_blocks.dart';
import 'email_code_form.dart';

/// Вход без покупки: забрать выданную подписку или войти перед оплатой. true — вошли.
Route<bool> signInRoute() => settingsPageRoute<bool>(const SignInScreen());

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            SettingsHeader(l.signInTitle),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
              child: Text(l.signInIntro, style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
            ),
            EmailCodeForm(onSignedIn: () => Navigator.of(context).pop(true)),
          ],
        ),
      ),
    );
  }
}
