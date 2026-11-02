import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';

/// Главная. Пока каркас: заголовок и разделы, строка ввода придёт следом.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.screen),
          children: [
            Text(l.appName, style: text.headlineSmall),
            const SizedBox(height: 24),
            Text(l.homeRecent, style: text.titleSmall!.copyWith(color: Tokens.onSurfaceVariant)),
            const SizedBox(height: 24),
            Text(l.homeFolders, style: text.titleSmall!.copyWith(color: Tokens.onSurfaceVariant)),
            const SizedBox(height: 12),
            Text(l.homeEmpty, style: text.bodyMedium!.copyWith(color: Tokens.muted)),
          ],
        ),
      ),
    );
  }
}
