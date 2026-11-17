import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/note_blocks.dart' show toggleCheckLine;
import '../../l10n/app_localizations.dart';
import '../home/note_timeline.dart' show NoteCard, dayLabel;
import '../item/item_actions.dart';

/// Ширина колонки плитки, от которой колонок становится больше.
const _column = 200.0;
const _gap = 12.0;

/// Главная широкого экрана: заголовок, полка папок и заметки плиткой по дням, как в
/// Pinterest — колонки по ширине окна, высота карточки по содержимому.
class WorkspaceHome extends ConsumerWidget {
  const WorkspaceHome({super.key, required this.onOpen, required this.onFolder, this.bottomSpace = 132});

  final ValueChanged<String> onOpen;

  /// null — «Без папки».
  final ValueChanged<String?> onFolder;

  /// Место под строкой ввода, чтобы последние карточки не прятались.
  final double bottomSpace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final now = ref.read(clockProvider)();
    final recent = ref.watch(recentItemsProvider).value ?? const <ItemCard>[];
    final pinned = ref.watch(pinnedItemsProvider).value ?? const <ItemCard>[];
    final folders = (ref.watch(foldersProvider).value ?? const <FolderCard>[]).where((folder) => folder.parentId == null).toList();
    final notes = ref.watch(notesCountProvider).value ?? 0;
    final inbox = [...pinned, ...recent].where((card) => card.folderId == null).length;

    // заметки по дням, свежий день сверху
    final days = <DateTime, List<ItemCard>>{};
    for (final card in recent) {
      final at = card.createdAt;
      days.putIfAbsent(DateTime(at.year, at.month, at.day), () => []).add(card);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < 700 ? 18.0 : 28.0;
        final inner = constraints.maxWidth - side * 2;
        final columns = math.max(1, ((inner + _gap) / (_column + _gap)).floor()).clamp(1, 6);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 26, side, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.wsHome, style: text.displaySmall!.copyWith(fontSize: 30, height: 1.15)),
                    if (notes > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        [l.itemsCount(notes), if (folders.isNotEmpty) l.foldersCount(folders.length)].join(' · '),
                        style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),
            if (folders.isNotEmpty || inbox > 0)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(side, 0, side, 0),
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final folder in folders) ...[_FolderPill(folder: folder, onTap: () => onFolder(folder.id)), const SizedBox(width: 8)],
                      if (inbox > 0) _InboxPill(label: l.folderNone, count: inbox, onTap: () => onFolder(null)),
                    ],
                  ),
                ),
              ),
            if (pinned.isNotEmpty) ...[
              _DayTitle(name: l.homePinned, side: side),
              _Masonry(cards: pinned, columns: columns, side: side, dated: true, onOpen: onOpen),
            ],
            for (final MapEntry(key: day, value: cards) in days.entries) ...[
              _DayTitle(name: dayLabel(l, day, now).$1, date: dayLabel(l, day, now).$2, side: side),
              _Masonry(cards: cards, columns: columns, side: side, onOpen: onOpen),
            ],
            SliverToBoxAdapter(child: SizedBox(height: bottomSpace)),
          ],
        );
      },
    );
  }
}

class _DayTitle extends StatelessWidget {
  const _DayTitle({required this.name, this.date, required this.side});

  final String name;
  final String? date;
  final double side;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(side + 2, 30, side, 14),
      sliver: SliverToBoxAdapter(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(name, style: text.headlineSmall!.copyWith(fontSize: 18)),
            if (date case final date?) ...[
              const SizedBox(width: 10),
              Flexible(child: Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: Tokens.muted))),
            ],
          ],
        ),
      ),
    );
  }
}

/// Карточки в колонки: каждая ложится в самую короткую колонку. Высота заранее — прикидкой
/// по содержимому, этого хватает, чтобы колонки не разъезжались.
class _Masonry extends ConsumerWidget {
  const _Masonry({required this.cards, required this.columns, required this.side, required this.onOpen, this.dated = false});

  final List<ItemCard> cards;
  final int columns;
  final double side;
  final bool dated;
  final ValueChanged<String> onOpen;

  static double _guess(ItemCard card, double width) {
    final perLine = math.max(14, width / 8.6);
    final title = (card.title.length / perLine).ceil().clamp(1, 2) * 22.0;
    final body = card.body.isEmpty ? 0.0 : (card.body.length / perLine).ceil().clamp(0, 3) * 21.0;
    final photo = card.thumbPath == null ? 0.0 : width * 0.75;
    return 64 + title + body + photo;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesRoot = ref.watch(filesRootProvider);
    final now = ref.read(clockProvider)();
    final aiSorting = ref.watch(aiSettingsProvider).value?.active ?? false;
    final items = ref.read(itemsRepositoryProvider);
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: side),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.crossAxisExtent - _gap * (columns - 1)) / columns;
          final heights = List.filled(columns, 0.0);
          final placed = List.generate(columns, (_) => <ItemCard>[]);
          for (final card in cards) {
            var shortest = 0;
            for (var i = 1; i < columns; i++) {
              if (heights[i] < heights[shortest]) shortest = i;
            }
            placed[shortest].add(card);
            heights[shortest] += _guess(card, width) + _gap;
          }
          return SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < columns; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  Expanded(
                    child: Column(
                      children: [
                        for (final card in placed[i])
                          Padding(
                            padding: const EdgeInsets.only(bottom: _gap),
                            // правый щелчок — то же меню, что долгое нажатие на телефоне
                            child: GestureDetector(
                              onSecondaryTap: () => showItemActions(context, ref, card),
                              child: NoteCard(
                                key: ValueKey('ws-card-${card.id}'),
                                item: card,
                                dated: dated,
                                filesRoot: filesRoot,
                                now: now,
                                aiSorting: aiSorting,
                                onOpen: () => onOpen(card.id),
                                onMove: () => moveItem(context, ref, card),
                                onAct: () => showItemActions(context, ref, card),
                                onToggle: (line) {
                                  final body = toggleCheckLine(card.body, line);
                                  if (body != card.body) items.setBody(card.id, body, ref.read(clockProvider)()).ignore();
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Папка на полке: значок и имя в цвет папки, число заметок.
class _FolderPill extends StatelessWidget {
  const _FolderPill({required this.folder, required this.onTap});

  final FolderCard folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
        decoration: BoxDecoration(color: FolderPalette.tint(folder.color, 0.16), borderRadius: BorderRadius.circular(100)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(symbolIcon(folder.icon, filled: true), size: 18, color: FolderPalette.ink(folder.color)),
            const SizedBox(width: 8),
            Text(folder.name, style: text.labelLarge!.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text('${folder.count}', style: text.labelMedium!.copyWith(color: Tokens.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );
  }
}

class _InboxPill extends StatelessWidget {
  const _InboxPill({required this.label, required this.count, required this.onTap});

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
        decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(100)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(symbolIcon('inbox'), size: 18, color: Tokens.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(label, style: text.labelLarge!.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text('$count', style: text.labelMedium!.copyWith(color: Tokens.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
