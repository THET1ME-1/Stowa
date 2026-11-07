import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../data/repositories/return_repository.dart';
import '../../domain/return_plan.dart';
import '../../l10n/app_localizations.dart';
import '../../services/return_service.dart' show returnText;
import '../returns/return_screen.dart';

/// Пилюли над «Только что»: «Посмотреть потом · 24 мин» и «Год назад». То же, что вечером
/// придёт уведомлением, — но видно и без него.
class ReturnPills extends ConsumerWidget {
  const ReturnPills({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final queue = ref.watch(watchLaterProvider).value ?? const [];
    final day = ref.watch(onThisDayProvider).value;
    final pills = [
      if (queue.isNotEmpty) (icon: 'smart_display', label: '${l.returnWatchTitle} · ${l.returnMinutesShort(summarizeWatchLater(queue).minutes)}', kind: ReturnKind.watchLater),
      if (day != null) (icon: 'history', label: returnText(l, ReturnPick(ReturnKind.onThisDay, day: day.found)).title, kind: ReturnKind.onThisDay),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final pill in pills)
            Material(
              key: ValueKey('return-${pill.kind.name}'),
              color: Tokens.containerHigh,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).push(returnRoute(pill.kind)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(symbolIcon(pill.icon), size: 18, color: Tokens.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Flexible(child: Text(pill.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Tokens.onSurface))),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// «Возвращать сохранённое?» — один раз, когда в Stowa уже что-то есть. «Включить» —
/// системный запрос разрешения на уведомления, «Не сейчас» — больше не спрашиваем.
class ReturnsAskCard extends ConsumerWidget {
  const ReturnsAskCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    Future<void> answer({required bool on}) async {
      if (on) await ref.read(notificationPortProvider).ensurePermission();
      await ref.read(settingsRepositoryProvider).setReturnsAsked();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
        decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(28)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(symbolIcon('notifications'), size: 20, color: Tokens.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(child: Text(l.returnsAskTitle, style: text.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text(l.returnsAskBody, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
            const SizedBox(height: 6),
            // на узком экране и крупном шрифте кнопки встают друг под друга, а не вылезают
            OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 4,
              children: [
                TextButton(onPressed: () => answer(on: false), child: Text(l.returnsAskLater)),
                FilledButton(onPressed: () => answer(on: true), child: Text(l.returnsAskOn)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
