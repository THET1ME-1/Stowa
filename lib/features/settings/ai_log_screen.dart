import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

Route<void> aiLogRoute() => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => const AiLogScreen(),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

/// Последние запросы к поставщику: что разложено, что упало и почему.
/// Ключ свой, поэтому и разбираться, почему не работает, человеку самому.
class AiLogScreen extends ConsumerWidget {
  const AiLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final rows = ref.watch(aiLogProvider).value ?? const [];
    final time = DateFormat('d MMM, HH:mm', Localizations.localeOf(context).toLanguageTag());

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            Row(
              children: [
                Tooltip(
                  message: MaterialLocalizations.of(context).backButtonTooltip,
                  child: Pressable(
                    pressedScale: 0.9,
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
                      child: Icon(symbolIcon('arrow_back'), color: Tokens.onSurface),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(l.aiLog, style: text.titleLarge!.copyWith(fontSize: 18))),
              ],
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty) Text(l.aiLogEmpty, style: text.bodyMedium!.copyWith(color: Tokens.muted)),
            for (final row in rows)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.tile)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      symbolIcon(row.error == null ? 'check_circle' : 'error', filled: true),
                      size: 20,
                      color: row.error == null ? Tokens.onSurfaceVariant : Tokens.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.title ?? l.aiLogCluster, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyLarge),
                          const SizedBox(height: 2),
                          Text(time.format(row.at), style: text.bodySmall!.copyWith(color: Tokens.muted)),
                          if (row.error != null) ...[
                            const SizedBox(height: 6),
                            Text(row.error!, maxLines: 4, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
