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

/// Круглая кнопка в шапке главной: «Год назад», «Месяц назад», «Неделю назад» — в подсказке.
/// Есть, только когда в этот день раньше что-то сохраняли; блоком под напоминаниями главная
/// была перегружена (хозяин, 13.11.2026).
class OnThisDayButton extends ConsumerWidget {
  const OnThisDayButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(onThisDayProvider).value;
    if (day == null) return const SizedBox.shrink();
    final label = returnText(L.of(context), ReturnPick(ReturnKind.onThisDay, day: day.found)).title;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: label,
        child: Material(
          key: const ValueKey('return-onThisDay'),
          color: Tokens.containerHigh,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(returnRoute(ReturnKind.onThisDay)),
            child: SizedBox.square(
              dimension: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(symbolIcon('history'), size: 21, color: Tokens.onSurface),
                  // точка: есть что вспомнить именно сегодня
                  Positioned(
                    top: 11,
                    right: 11,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: Tokens.accent, shape: BoxShape.circle, border: Border.all(color: Tokens.containerHigh, width: 1.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Пилюля над лентой: «Посмотреть потом · 24 мин». То же, что вечером придёт уведомлением,
/// — но видно и без него.
class ReturnPills extends ConsumerWidget {
  const ReturnPills({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final queue = ref.watch(watchLaterProvider).value ?? const [];
    final pills = [
      if (queue.isNotEmpty) (icon: 'smart_display', label: '${l.returnWatchTitle} · ${l.returnMinutesShort(summarizeWatchLater(queue).minutes)}', kind: ReturnKind.watchLater),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();
    // во всю строку, две — пополам: справа не остаётся пустоты, стрелка говорит, что внутри список
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 16),
      child: Row(
        children: [
          for (final (index, pill) in pills.indexed) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: Material(
                key: ValueKey('return-${pill.kind.name}'),
                color: Tokens.containerHigh,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(returnRoute(pill.kind)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                    child: Row(
                      children: [
                        Icon(symbolIcon(pill.icon), size: 18, color: Tokens.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(child: Text(pill.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Tokens.onSurface))),
                        Icon(symbolIcon('chevron_right'), size: 20, color: Tokens.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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
