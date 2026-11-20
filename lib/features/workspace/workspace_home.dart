import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion_bits.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/sliver_by_width.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/note_blocks.dart' show toggleCheckLine;
import '../../l10n/app_localizations.dart';
import '../home/note_timeline.dart' show CardDepth, NoteCard, dayLabel;
import '../folder/folder_sheets.dart' show askNewFolder;
import '../item/item_actions.dart';
import '../web/copy_nudge.dart';
import 'workspace_model.dart';
import 'workspace_shell.dart';

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
    final count = ref.watch(notesCountProvider).value;
    final notes = count ?? 0;
    final inbox = [...pinned, ...recent].where((card) => card.folderId == null).length;
    // пока счёт не пришёл, пустую главную не показывать: она мигнула бы при каждом запуске
    final empty = count == 0 && recent.isEmpty && pinned.isEmpty;

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
                    // в браузере заметки лежат только в нём: напоминание о копии
                    const CopyNudgeHost(padding: EdgeInsets.only(top: 16)),
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
              NoteMasonry(cards: pinned, columns: columns, side: side, dated: true, onOpen: onOpen),
            ],
            for (final MapEntry(key: day, value: cards) in days.entries) ...[
              _DayTitle(name: dayLabel(l, day, now).$1, date: dayLabel(l, day, now).$2, side: side),
              NoteMasonry(cards: cards, columns: columns, side: side, onOpen: onOpen),
            ],
            if (empty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(side, 0, side, bottomSpace),
                  child: const Center(child: _DeskEmpty()),
                ),
              )
            else
              SliverToBoxAdapter(child: SizedBox(height: bottomSpace)),
          ],
        );
      },
    );
  }
}

/// Пустая главная: что здесь будет, как начать, и три первых шага плитками. Шаги
/// проявляются лесенкой, плитки отвечают на наведение.
class _DeskEmpty extends ConsumerWidget {
  const _DeskEmpty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final ws = WorkspaceScope.maybeOf(context);
    final steps = [
      _FirstStep(key: const ValueKey('ws-empty-write'), icon: 'edit', tint: 'teal', label: l.wsEmptyWrite, keys: 'Ctrl K', onTap: () => ws?.find?.call()),
      _FirstStep(
        key: const ValueKey('ws-empty-folder'),
        icon: 'create_new_folder',
        tint: 'amber',
        label: l.wsEmptyFolder,
        onTap: () async {
          final folder = await askNewFolder(context, ref);
          if (folder != null) ws?.open(WsTab.folder(folder.id));
        },
      ),
      _FirstStep(key: const ValueKey('ws-empty-restore'), icon: 'settings_backup_restore', tint: 'sky', label: l.wsEmptyRestore, onTap: () => ws?.open(const WsTab.settings('vault'))),
    ];
    return ConstrainedBox(
      key: const ValueKey('ws-empty'),
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RiseIn(child: Text(l.wsEmptyTitle, textAlign: TextAlign.center, style: text.displaySmall!.copyWith(fontSize: 28, height: 1.2))),
          const SizedBox(height: 12),
          RiseIn(
            delay: 1,
            child: Text(l.wsEmptyBody, textAlign: TextAlign.center, style: text.bodyLarge!.copyWith(color: Tokens.onSurfaceVariant, height: 1.5)),
          ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [for (final (index, step) in steps.indexed) RiseIn(delay: 2 + index, child: step)],
          ),
        ],
      ),
    );
  }
}

/// Плитка первого шага: значок в цвет, подпись, клавиши, если есть.
class _FirstStep extends StatelessWidget {
  const _FirstStep({super.key, required this.icon, required this.tint, required this.label, required this.onTap, this.keys});

  final String icon;
  final String tint;
  final String label;
  final String? keys;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = FolderPalette.colors[tint]!;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.97,
      radius: BorderRadius.circular(Radii.tile),
      child: Container(
        width: 188,
        // одной высоты все три: подпись в две строки и клавиши под ней помещаются
        height: 140,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.tile)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: FolderPalette.tint(color, 0.18), borderRadius: BorderRadius.circular(12)),
              child: Icon(symbolIcon(icon), size: 20, color: FolderPalette.ink(color)),
            ),
            const Spacer(),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall!.copyWith(height: 1.25)),
            if (keys case final keys?) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(7)),
                child: Text(keys, style: text.labelSmall!.copyWith(color: Tokens.onSurfaceVariant)),
              ),
            ],
          ],
        ),
      ),
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
/// по содержимому, этого хватает, чтобы колонки не разъезжались. Плитка главной и папки на
/// мониторе. [columns] null — сколько колонок по 200 точек помещается.
class NoteMasonry extends ConsumerWidget {
  const NoteMasonry({super.key, required this.cards, this.columns, required this.side, required this.onOpen, this.dated = false});

  final List<ItemCard> cards;
  final int? columns;
  final double side;
  final bool dated;
  final ValueChanged<String> onOpen;

  // прикидка высоты карточки по содержимому, с теми же пределами, что у [CardDepth] ниже
  static double _guess(ItemCard card, double width) {
    final perLine = math.max(14, width / 8.6);
    final title = (card.title.length / perLine).ceil().clamp(1, 3) * 22.0;
    final rows = card.body.split('\n').where((line) => line.trim().isNotEmpty).fold<int>(0, (sum, line) => sum + (line.length / perLine).ceil());
    final body = rows.clamp(0, _lines) * 22.0;
    final photo = card.thumbPath == null ? 0.0 : math.min(width * (card.thumbRatio ?? 0.75), _photoMax);
    return 64 + title + body + photo;
  }

  static const _lines = 8;
  static const _photoMax = 420.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesRoot = ref.watch(filesRootProvider);
    final now = ref.read(clockProvider)();
    final aiSorting = ref.watch(aiSettingsProvider).value?.active ?? false;
    final items = ref.read(itemsRepositoryProvider);
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: side),
      // раскладка по колонкам — только при смене ширины, а не на каждый кадр прокрутки
      sliver: SliverByWidth(
        builder: (context, extent) {
          final columns = this.columns ?? math.max(1, ((extent + _gap) / (_column + _gap)).floor()).clamp(1, 6);
          final width = (extent - _gap * (columns - 1)) / columns;
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
          Widget tile(ItemCard card) => Padding(
            key: ValueKey('ws-card-${card.id}'),
            padding: const EdgeInsets.only(bottom: _gap),
            // правый щелчок — то же меню, что долгое нажатие на телефоне
            child: GestureDetector(
              onSecondaryTap: () => showItemActions(context, ref, card),
              child: NoteCard(
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
          );
          // карточка показывает столько, сколько в заметке есть: высота у каждой своя.
          // Каждая колонка — свой ленивый список: строится и рисуется только то, что на экране,
          // иначе папка в тысячу заметок строит тысячу карточек, и прокрутка дёргается
          return CardDepth(
            lines: _lines,
            photoMax: _photoMax,
            child: SliverCrossAxisGroup(
              slivers: [
                for (var i = 0; i < columns; i++) ...[
                  if (i > 0) const SliverConstrainedCrossAxis(maxExtent: _gap, sliver: SliverToBoxAdapter()),
                  SliverCrossAxisExpanded(
                    flex: 1,
                    sliver: SliverList.builder(
                      itemCount: placed[i].length,
                      findChildIndexCallback: (key) {
                        final id = (key as ValueKey<String>).value.substring('ws-card-'.length);
                        final index = placed[i].indexWhere((card) => card.id == id);
                        return index < 0 ? null : index;
                      },
                      itemBuilder: (context, index) => tile(placed[i][index]),
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
      radius: BorderRadius.circular(100),
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
      radius: BorderRadius.circular(100),
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
