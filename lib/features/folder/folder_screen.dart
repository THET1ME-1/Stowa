import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion_bits.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../composer/line_dock.dart';
import '../composer/panel_text.dart';
import '../item/item_actions.dart';
import '../item/item_screen.dart';
import '../sort/sort_screen.dart';
import 'folder_cards.dart';
import 'folder_sheets.dart';
import 'folder_view.dart';

/// Папка въезжает справа, как страница вещи.
Route<void> folderRoute(String? folderId) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => FolderScreen(folderId: folderId),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

/// Место под свёрнутую строку внизу, чтобы последняя карточка не пряталась.
const _dockSpace = 150.0;

/// Папка: картинки доской, остальное лентой с карточкой под каждый вид.
/// [folderId] null — всё, что лежит без папки.
class FolderScreen extends ConsumerStatefulWidget {
  const FolderScreen({super.key, required this.folderId});

  final String? folderId;

  @override
  ConsumerState<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends ConsumerState<FolderScreen> {
  final _dock = GlobalKey<LineDockState>();
  ItemKind? _kind;
  String? _tag;

  FolderOrder _order = FolderOrder.newest;

  void _open(String id) => Navigator.of(context).push(itemRoute(id));

  void _act(ItemCard card) => showItemActions(context, ref, card);

  Future<void> _pickOrder() async {
    final l = L.of(context);
    final picked = await showModalBottomSheet<FolderOrder>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (order, label) in [
              (FolderOrder.newest, l.sortNewest),
              (FolderOrder.oldest, l.sortOldest),
              (FolderOrder.name, l.sortByName),
            ])
              ListTile(
                title: Text(label),
                trailing: order == _order ? Icon(symbolIcon('check'), color: Tokens.accent) : null,
                onTap: () => Navigator.pop(context, order),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _order = picked);
  }

  Future<void> _menu(FolderCard folder) async {
    final repository = ref.read(foldersRepositoryProvider);
    final action = await showFolderMenu(context);
    if (!mounted || action == null) return;
    switch (action) {
      case FolderAction.rename:
        final name = await showRenameSheet(context, folder.name);
        if (name != null) await repository.rename(folder.id, name);
      case FolderAction.look:
        final look = await showLookSheet(context, folder);
        if (look != null) await repository.setLook(folder.id, icon: look.icon, shape: look.shape);
      case FolderAction.delete:
        final l = L.of(context);
        final messenger = ScaffoldMessenger.of(context);
        if (!await confirmFolderDelete(context, folder.name)) return;
        final moved = await repository.delete(folder.id, ref.read(clockProvider)());
        if (mounted) Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l.folderDeleted),
            action: SnackBarAction(label: l.restoreAction, onPressed: () => repository.restore(folder.id, moved)),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final folders = ref.watch(foldersProvider).value ?? const [];
    final folder = folders.where((one) => one.id == widget.folderId).firstOrNull;
    final cards = ref.watch(folderItemsProvider(widget.folderId)).value ?? const [];
    final filesRoot = ref.watch(filesRootProvider);
    final now = ref.read(clockProvider)();
    final board = showAsBoard(cards, folder?.view ?? FolderView.auto);
    final bottom = MediaQuery.paddingOf(context).bottom;

    // порядок чипов как на экране 6 макета: сначала то, что смотрят, потом читают
    const kindOrder = [ItemKind.video, ItemKind.voice, ItemKind.link, ItemKind.note, ItemKind.image, ItemKind.file];
    final kinds = <ItemKind>[for (final kind in kindOrder) if (cards.any((card) => card.kind == kind)) kind];
    final tags = folderTags(cards);
    final shown = orderCards(
      cards.where((card) => board ? (_tag == null || card.tags.contains(_tag)) : (_kind == null || card.kind == _kind)),
      _order,
    );

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 0),
                    child: Row(
                      children: [
                        _RoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.pop(context)),
                        const Spacer(),
                        _RoundButton(icon: 'search', tooltip: l.folderSearch, onTap: () => _dock.currentState?.focusLine()),
                        if (cards.length > 1) ...[
                          const SizedBox(width: 8),
                          _RoundButton(icon: 'sort', tooltip: l.sortTooltip, onTap: _pickOrder),
                        ],
                        if (folder != null) ...[
                          const SizedBox(width: 8),
                          _RoundButton(icon: 'more_vert', tooltip: l.folderMore, onTap: () => _menu(folder)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.screen, 16, Space.screen, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(folder?.name ?? l.folderNone, style: text.headlineMedium!.copyWith(fontSize: 26, height: 1.1, letterSpacing: -0.6)),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '${cards.length}',
                          style: text.titleSmall!.copyWith(fontFamily: 'Unbounded', fontSize: 15, fontWeight: FontWeight.w600, color: Tokens.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // «Без папки»: разложить по одной карточке
              if (widget.folderId == null && cards.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.screen, 14, Space.screen, 0),
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(sortRoute()),
                      icon: Icon(symbolIcon('swipe_down')),
                      label: Text(l.sortMode),
                    ),
                  ),
                ),
              if (folder != null && cards.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.screen, 14, Space.screen, 0),
                    child: _Segments(
                      board: board,
                      boardLabel: l.folderBoard,
                      listLabel: l.folderList,
                      onChanged: (toBoard) => ref.read(foldersRepositoryProvider).setView(folder.id, toBoard ? FolderView.board : FolderView.list),
                    ),
                  ),
                ),
              if (board ? tags.isNotEmpty : kinds.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(Space.screen, 12, Space.screen, 0),
                      children: [
                        _FilterChip(label: l.filterAll, on: board ? _tag == null : _kind == null, onTap: () => setState(() => board ? _tag = null : _kind = null)),
                        if (board)
                          // теги над доской словами с заглавной, как «Интерьер · Двери» в макете
                          for (final tag in tags)
                            _FilterChip(label: tag[0].toUpperCase() + tag.substring(1), on: _tag == tag, onTap: () => setState(() => _tag = tag))
                        else
                          for (final kind in kinds)
                            _FilterChip(label: kindsLabel(l, kind), icon: kindIcon(kind), on: _kind == kind, onTap: () => setState(() => _kind = kind)),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (cards.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(40, 0, 40, _dockSpace + bottom),
                    child: Center(
                      child: Text(l.folderEmpty, textAlign: TextAlign.center, style: text.bodyLarge!.copyWith(color: Tokens.muted)),
                    ),
                  ),
                )
              else if (board)
                SliverToBoxAdapter(child: _Board(cards: shown, filesRoot: filesRoot, onOpen: _open, onAct: _act))
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                  sliver: SliverList.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => RiseIn(
                      key: ValueKey(shown[index].id),
                      delay: index.clamp(0, 8),
                      child: FolderItemCard(
                        card: shown[index],
                        filesRoot: filesRoot,
                        now: now,
                        onTap: () => _open(shown[index].id),
                        onLongPress: () => _act(shown[index]),
                      ),
                    ),
                  ),
                ),
              if (cards.isNotEmpty) SliverToBoxAdapter(child: SizedBox(height: _dockSpace + bottom)),
            ],
          ),
          // лента уходит под строку в тень фона, как dock.float в макете
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _dockSpace + bottom,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Tokens.background],
                    stops: [0, 0.3],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: LineDock(key: _dock, homeFolder: folder, onOpenItem: _open),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        pressedScale: 0.9,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
          child: Icon(symbolIcon(icon), color: Tokens.onSurface),
        ),
      ),
    );
  }
}

/// «Доска · Список», как переключатель на экране 4 макета.
class _Segments extends StatelessWidget {
  const _Segments({required this.board, required this.boardLabel, required this.listLabel, required this.onChanged});

  final bool board;
  final String boardLabel;
  final String listLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(String icon, String label, bool on, BorderRadius radius, bool toBoard) => Expanded(
      child: GestureDetector(
        onTap: () => onChanged(toBoard),
        child: AnimatedContainer(
          duration: Motion.short,
          height: 44,
          decoration: BoxDecoration(color: on ? Tokens.accent : Tokens.containerHigh, borderRadius: on ? BorderRadius.circular(22) : radius),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(symbolIcon(icon), size: 19, color: on ? Tokens.onAccent : Tokens.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14, color: on ? Tokens.onAccent : Tokens.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        segment('grid_view', boardLabel, board, const BorderRadius.horizontal(left: Radius.circular(22), right: Radius.circular(8)), true),
        const SizedBox(width: 2),
        segment('view_agenda', listLabel, !board, const BorderRadius.horizontal(left: Radius.circular(8), right: Radius.circular(22)), false),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.on, required this.onTap, this.icon});

  final String label;
  final String? icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = on ? Tokens.onAccent : Tokens.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.short,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: on ? Tokens.accent : Tokens.containerHigh, borderRadius: BorderRadius.circular(18)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(symbolIcon(icon), size: 18, color: color), const SizedBox(width: 6)],
              Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Доска в две колонки: картинки в своих пропорциях, по очереди слева и справа.
class _Board extends StatelessWidget {
  const _Board({required this.cards, required this.filesRoot, required this.onOpen, required this.onAct});

  final List<ItemCard> cards;
  final Directory filesRoot;
  final ValueChanged<String> onOpen;
  final ValueChanged<ItemCard> onAct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 8) / 2;
          final columns = boardColumns(cards);
          Widget column(List<ItemCard> side) => Expanded(
            child: Column(
              children: [
                for (final card in side)
                  if (cards.indexOf(card) case final index)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RiseIn(
                        key: ValueKey(card.id),
                        delay: index.clamp(0, 8),
                        child: BoardTile(
                          card: card,
                          filesRoot: filesRoot,
                          width: width,
                          darkPill: index % 3 == 1,
                          onTap: () => onOpen(card.id),
                          onLongPress: () => onAct(card),
                        ),
                      ),
                    ),
              ],
            ),
          );
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [column(columns.left), const SizedBox(width: 8), column(columns.right)]);
        },
      ),
    );
  }
}
