import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../data/repositories/return_repository.dart';
import '../../domain/return_plan.dart';
import '../../l10n/app_localizations.dart';
import '../../services/reminder_service.dart' show reminderItemId;
import '../../services/return_service.dart' show returnText;
import '../folder/folder_cards.dart';
import '../item/item_screen.dart';
import '../privacy/hidden_item_route.dart';

Route<void> returnRoute(ReturnKind kind) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => ReturnScreen(kind: kind),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

/// Куда ведёт касание уведомления: `return:<вид>` — экран возврата, `note:<id>` — заметка,
/// голый id — заметка, как у напоминаний до возврата.
({ReturnKind? kind, String? itemId}) notificationTarget(String payload) {
  if (payload.startsWith('return:')) return (kind: ReturnKind.values.asNameMap()[payload.substring(7)], itemId: null);
  if (payload.startsWith('note:')) return (kind: null, itemId: payload.substring(5));
  return (kind: null, itemId: payload);
}

/// Экран по касанию уведомления или ничего, если адрес незнакомый.
Route<void>? notificationRoute(String payload) {
  // скрытая заметка: сперва код или отпечаток, потом сама заметка
  if (payload.startsWith('hidden:')) return hiddenItemRoute(reminderItemId(payload));
  final target = notificationTarget(payload);
  if (target.kind case final kind?) return returnRoute(kind);
  if (target.itemId case final id?) return itemRoute(id);
  return null;
}

/// Что вернулось: очередь «посмотреть потом», «в этот день», неделя, покупки.
/// Сюда ведут вечернее уведомление и пилюли главной.
class ReturnScreen extends ConsumerWidget {
  const ReturnScreen({super.key, required this.kind});

  final ReturnKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final (title, summary, sections, empty) = switch (kind) {
      ReturnKind.watchLater => _watch(l, ref.watch(watchLaterProvider).value),
      ReturnKind.onThisDay => _day(l, ref.watch(onThisDayProvider).value),
      ReturnKind.week => _week(l, ref.watch(weekReturnProvider).value),
      ReturnKind.shopping => _shopping(l, ref.watch(shoppingProvider).value),
    };

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: Tokens.containerHigh, fixedSize: const Size.square(44)),
                  icon: Icon(symbolIcon('arrow_back'), size: 20, color: Tokens.onSurface),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: text.titleLarge!.copyWith(fontSize: 18))),
              ],
            ),
            if (summary != null) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(summary, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
              ),
            ],
            const SizedBox(height: 16),
            if (sections.every((section) => section.ids.isEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Text(empty, textAlign: TextAlign.center, style: text.titleMedium!.copyWith(color: Tokens.onSurfaceVariant)),
              ),
            for (final section in sections)
              if (section.ids.isNotEmpty) ...[
                if (section.title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                    child: Text(section.title!, style: text.titleSmall!.copyWith(color: Tokens.onSurfaceVariant)),
                  ),
                _Cards(ids: section.ids),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  (String, String?, List<_Section>, String) _watch(L l, List<WatchLaterEntry>? queue) {
    final entries = queue ?? const <WatchLaterEntry>[];
    final found = summarizeWatchLater(entries);
    return (
      l.returnWatchTitle,
      found.count == 0 ? null : returnText(l, ReturnPick(ReturnKind.watchLater, watch: found)).body,
      [_Section(null, [for (final entry in entries) entry.id])],
      l.returnWatchEmpty,
    );
  }

  (String, String?, List<_Section>, String) _day(L l, OnThisDay? day) {
    if (day == null) return (l.returnOnThisDay, null, const [], l.returnDayEmpty);
    final title = returnText(l, ReturnPick(ReturnKind.onThisDay, day: day.found)).title;
    return (title, null, [_Section(null, day.ids)], l.returnDayEmpty);
  }

  (String, String?, List<_Section>, String) _week(L l, WeekSummary? week) {
    if (week == null || week.found.saved == 0) return (l.returnWeekTitle, null, const [], l.returnWeekEmpty);
    return (
      l.returnWeekTitle,
      returnText(l, ReturnPick(ReturnKind.week, week: week.found)).body,
      [_Section(l.returnWeekUnopenedTitle, week.unopened), _Section(l.returnWeekUnsortedTitle, week.unsorted)],
      l.returnWeekEmpty,
    );
  }

  (String, String?, List<_Section>, String) _shopping(L l, List<ShoppingList>? lists) =>
      (l.returnShopping, null, [_Section(null, [for (final list in lists ?? const <ShoppingList>[]) list.id])], l.returnShoppingEmpty);
}

class _Section {
  const _Section(this.title, this.ids);

  final String? title;
  final List<String> ids;
}

/// Лента карточек, как в папке: у ролика обложка и длина, у заметки текст.
class _Cards extends ConsumerWidget {
  const _Cards({required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(cardsProvider(ids.join('\x1f'))).value ?? const [];
    final filesRoot = ref.watch(filesRootProvider);
    final now = ref.read(clockProvider)();
    // без растяжки короткая заметка сжимается до своего текста и встаёт по центру
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final card in cards)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FolderItemCard(card: card, filesRoot: filesRoot, now: now, onTap: () => Navigator.of(context).push(itemRoute(card.id))),
          ),
      ],
    );
  }
}
