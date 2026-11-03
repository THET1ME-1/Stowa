import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion_bits.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/shape_badge.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../l10n/app_localizations.dart';
import '../folder/folder_cards.dart';
import '../folder/folder_sheets.dart';
import '../item/item_screen.dart';

Route<void> sortRoute() => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => const SortScreen(),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

/// «Разобрать»: всё, что без папки, по одной карточке. Касание папки кладёт туда,
/// свайп вниз пропускает. Первые три папки — подсказки по словам.
class SortScreen extends ConsumerStatefulWidget {
  const SortScreen({super.key});

  @override
  ConsumerState<SortScreen> createState() => _SortScreenState();
}

class _SortScreenState extends ConsumerState<SortScreen> {
  final _skipped = <String>{};
  int _total = 0;

  DateTime get _now => ref.read(clockProvider)();

  // каждое действие можно отменить: в разборе пальцы торопятся
  void _undoable(String message, VoidCallback undo) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: SnackBarAction(label: L.of(context).undo, onPressed: undo)));
  }

  Future<void> _put(String id, FolderCard folder) async {
    final items = ref.read(itemsRepositoryProvider);
    await items.moveToFolder(id, folder.id, _now);
    if (!mounted) return;
    _undoable(L.of(context).itemMoved(folder.name), () => items.moveToFolder(id, null, _now));
  }

  Future<void> _newFolder(String id) async {
    final name = await showRenameSheet(context, '');
    if (name == null || !mounted) return;
    await _put(id, await ref.read(foldersRepositoryProvider).create(name));
  }

  Future<void> _delete(String id) async {
    final items = ref.read(itemsRepositoryProvider);
    await items.softDelete(id, _now);
    if (!mounted) return;
    _undoable(L.of(context).itemDeleted, () => items.restore(id));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final cards = (ref.watch(folderItemsProvider(null)).value ?? const []).where((card) => !_skipped.contains(card.id)).toList();
    final folders = ref.watch(foldersProvider).value ?? const [];
    final index = ref.watch(folderIndexProvider).value;
    final filesRoot = ref.watch(filesRootProvider);
    final now = ref.read(clockProvider)();
    final card = cards.firstOrNull;
    // сколько было в начале разбора: полоса растёт с каждой разобранной вещью
    _total = max(_total, cards.length);
    final progress = _total == 0 ? 1.0 : 1 - cards.length / _total;

    // подсказки первыми, потом остальные папки
    final hints = card == null || index == null ? const <String>[] : index.rank('${card.title} ${card.body} ${card.tags.join(' ')}').take(3).toList();
    final ordered = [
      for (final id in hints) ?folders.where((folder) => folder.id == id).firstOrNull,
      ...folders.where((folder) => !hints.contains(folder.id)),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(backgroundColor: Tokens.containerHigh, fixedSize: const Size.square(44)),
                    icon: Icon(symbolIcon('close'), color: Tokens.onSurface),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(card == null ? l.sortDone : l.sortLeft(cards.length), style: text.titleLarge!.copyWith(fontFamily: 'Unbounded', fontWeight: FontWeight.w700, fontSize: 20)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 14, Space.screen, 0),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: Motion.medium,
                curve: Motion.emphasized,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                  color: Tokens.accent,
                  backgroundColor: Tokens.containerHigh,
                ),
              ),
            ),
            Expanded(
              child: card == null
                  ? Center(child: Icon(symbolIcon('task_alt'), size: 64, color: Tokens.muted))
                  : Padding(
                      padding: const EdgeInsets.all(Space.screen),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        reverseDuration: const Duration(milliseconds: 180),
                        switchInCurve: Motion.spatial,
                        switchOutCurve: Motion.emphasizedAccelerate.flipped,
                        transitionBuilder: riseTransition,
                        child: Dismissible(
                          key: ValueKey(card.id),
                          direction: DismissDirection.vertical,
                          onDismissed: (direction) {
                            if (direction == DismissDirection.up) {
                              _delete(card.id);
                            } else {
                              setState(() => _skipped.add(card.id));
                            }
                          },
                          child: Center(
                            child: SingleChildScrollView(
                              clipBehavior: Clip.none,
                              // колода: из-под карточки выглядывают края следующих
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  for (var layer = (cards.length - 1).clamp(0, 2); layer > 0; layer--)
                                    Positioned(
                                      left: 14.0 * layer,
                                      right: 14.0 * layer,
                                      top: 0,
                                      bottom: -10.0 * layer,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          // каждая следующая ближе к фону
                                          color: layer == 1 ? Tokens.containerLow : Tokens.containerLow.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(Radii.tile),
                                        ),
                                      ),
                                    ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FolderItemCard(card: card, filesRoot: filesRoot, now: now, onTap: () => Navigator.of(context).push(itemRoute(card.id))),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            if (card != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen * 2),
                child: Text(l.sortHint, textAlign: TextAlign.center, style: text.bodySmall!.copyWith(color: Tokens.muted)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                  itemCount: ordered.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, position) => position == ordered.length
                      ? _FolderButton(label: l.shareNewFolder, icon: 'add', shape: BadgeShape.squircle, hinted: false, onTap: () => _newFolder(card.id))
                      : _FolderButton(
                          label: ordered[position].name,
                          icon: ordered[position].icon,
                          shape: BadgeShape.values.asNameMap()[ordered[position].shape] ?? BadgeShape.squircle,
                          hinted: position < hints.length,
                          onTap: () => _put(card.id, ordered[position]),
                        ),
                ),
              ),
              TextButton(onPressed: () => setState(() => _skipped.add(card.id)), child: Text(l.sortSkip)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Кнопка папки внизу: значок и имя; подсказка — белая.
class _FolderButton extends StatelessWidget {
  const _FolderButton({required this.label, required this.icon, required this.shape, required this.hinted, required this.onTap});

  final String label;
  final String icon;
  final BadgeShape shape;
  final bool hinted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = hinted ? Tokens.onAccent : Tokens.onSurface;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.92,
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: hinted ? Tokens.accent : Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.tile)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShapeBadge(
              shape: shape,
              size: 36,
              color: hinted ? Tokens.graphite : Tokens.containerHighest,
              child: Icon(symbolIcon(icon), size: 18, color: Tokens.onSurface),
            ),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
