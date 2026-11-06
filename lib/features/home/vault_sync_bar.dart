import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../services/vault/vault_sync.dart';

/// «Синхронизация заметок 340 из 1000» с полоской, пока из папки хранилища забирается
/// много заметок. Пара правок полоски не показывает — они появятся и так.
class VaultSyncBar extends StatelessWidget {
  const VaultSyncBar({super.key, required this.sync});

  final VaultSync sync;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: sync.status,
      builder: (context, status, _) {
        if (status == null) return const SizedBox.shrink();
        final (done, total) = status;
        return Padding(
          key: const ValueKey('vault-sync-bar'),
          // снизу отступ даёт заголовок «Только что», сверху — свой: карточка напоминания без поля
          padding: const EdgeInsets.fromLTRB(Space.screen, 16, Space.screen, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(L.of(context).vaultSyncing(done, total), style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Tokens.muted)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: total == 0 ? null : done / total, minHeight: 4, color: Tokens.accent, backgroundColor: Tokens.graphite),
              ),
            ],
          ),
        );
      },
    );
  }
}
