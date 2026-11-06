import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../l10n/app_localizations.dart';
import 'vault_actions.dart';

/// Первый запуск: где хранить заметки. Три пути, как у Obsidian: создать хранилище
/// в памяти телефона, открыть папку с заметками или хранить внутри приложения.
class VaultSetupScreen extends ConsumerWidget {
  const VaultSetupScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    Future<void> act(Future<bool> Function(BuildContext context, WidgetRef ref) action) async {
      if (await action(context, ref)) onDone();
    }

    return Scaffold(
      backgroundColor: Tokens.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 48, Space.screen, 24),
          children: [
            Text(l.vaultSetupTitle, style: text.headlineMedium),
            const SizedBox(height: 12),
            Text(l.vaultSetupHint, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.45)),
            const SizedBox(height: 28),
            VaultChoice(title: l.vaultCreate, hint: l.vaultCreateHint, button: l.vaultCreateButton, primary: true, first: true, onTap: () => act(createVault)),
            const SizedBox(height: 2),
            VaultChoice(title: l.vaultOpen, hint: l.vaultOpenHint, button: l.vaultOpenButton, onTap: () => act(openVaultFolder)),
            const SizedBox(height: 2),
            VaultChoice(title: l.vaultInApp, hint: l.vaultInAppHint, button: l.vaultInAppButton, last: true, onTap: () => act(keepInsideApp)),
          ],
        ),
      ),
    );
  }
}

/// Один путь: заголовок и пояснение слева, кнопка справа. Блоки сцеплены: крупные углы снаружи.
class VaultChoice extends StatelessWidget {
  const VaultChoice({
    super.key,
    required this.title,
    required this.hint,
    required this.button,
    required this.onTap,
    this.primary = false,
    this.first = false,
    this.last = false,
  });

  final String title;
  final String hint;
  final String button;
  final VoidCallback onTap;

  /// Путь по умолчанию: белая кнопка.
  final bool primary;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        color: Tokens.containerHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(first ? Radii.card : 8), bottom: Radius.circular(last ? Radii.card : 8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: 4),
                Text(hint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: primary ? Tokens.accent : Tokens.containerHighest,
              foregroundColor: primary ? Tokens.onAccent : Tokens.onSurface,
            ),
            child: Text(button),
          ),
        ],
      ),
    );
  }
}

/// Папки хранилища нет или забрали доступ: база цела, нужно вернуть доступ или выбрать папку.
class VaultMissingScreen extends ConsumerWidget {
  const VaultMissingScreen({super.key, required this.onFixed});

  final VoidCallback onFixed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final settings = ref.read(settingsRepositoryProvider);
    final path = settings.vaultPath ?? '';
    return Scaffold(
      backgroundColor: Tokens.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 48, Space.screen, 24),
          children: [
            Text(l.vaultMissingTitle, style: text.headlineMedium),
            const SizedBox(height: 12),
            Text(l.vaultMissingHint(shortVaultPath(path)), style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.45)),
            const SizedBox(height: 28),
            if (settings.vaultMode == VaultMode.device)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FilledButton(
                  onPressed: () async {
                    if (!await ensureFileAccess(context, ref)) return;
                    final root = await ref.read(vaultLocationProvider).resolve(hasData: true);
                    if (root.vault == null) return;
                    ref.read(vaultRootProvider.notifier).change(root.vault);
                    onFixed();
                  },
                  child: Text(l.vaultGrantAccess),
                ),
              ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Tokens.containerHighest, foregroundColor: Tokens.onSurface),
              onPressed: () async {
                if (await openVaultFolder(context, ref)) onFixed();
              },
              child: Text(l.vaultChooseAgain),
            ),
          ],
        ),
      ),
    );
  }
}
