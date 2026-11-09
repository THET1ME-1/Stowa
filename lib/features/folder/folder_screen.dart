import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion_bits.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/shape_badge.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../data/repositories/tags_repository.dart';
import '../../domain/folder_tree.dart';
import '../../domain/models.dart';
import '../../domain/money.dart' show formatTotal;
import '../../l10n/app_localizations.dart';
import '../composer/line_dock.dart';
import '../composer/panel_text.dart';
import '../graph/graph_screen.dart';
import '../home/folder_shelf.dart';
import '../item/item_screen.dart';
import '../sort/sort_screen.dart';
import '../tags/tag_picker.dart';
import 'canvas_view.dart';
import 'folder_cards.dart';
import 'folder_sheets.dart';
import 'folder_view.dart';

String folderRouteName(String? folderId) => 'folder/${folderId ?? ''}';

/// Папка въезжает справа, как страница вещи.
Route<void> folderRoute(String? folderId) => PageRouteBuilder(
  settings: RouteSettings(name: folderRouteName(folderId)),
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

  /// Папки, чьи экраны сейчас открыты: путь родителей ведёт назад к ним, а не открывает второй.
  static final _opened = <String?>[];

  @override
  void initState() {
    super.initState();
    _opened.add(widget.folderId);
    final id = widget.folderId;
    if (id != null) ref.read(foldersRepositoryProvider).markSeen(id).ignore();
  }

  @override
  void dispose() {
    _opened.remove(widget.folderId);
    super.dispose();
  }

  /// Выбранные вещи. Пусто — обычный режим: касание открывает, долгое нажатие начинает выбор.
  final _selected = <String>{};
  bool get _selecting => _selected.isNotEmpty;

  void _open(String id) => Navigator.of(context).push(itemRoute(id));

  void _tap(ItemCard card) => _selecting ? _toggle(card) : _open(card.id);

  void _act(ItemCard card) {
    if (!_selecting) HapticFeedback.mediumImpact();
    _toggle(card);
  }

  void _toggle(ItemCard card) => setState(() => _selected.contains(card.id) ? _selected.remove(card.id) : _selected.add(card.id));

  void _clear() => setState(_selected.clear);

  Future<void> _moveSelected(List<ItemCard> cards) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final items = ref.read(itemsRepositoryProvider);
    final clock = ref.read(clockProvider);
    final folders = ref.read(foldersProvider).value ?? const <FolderCard>[];
    final picked = await showModalBottomSheet<FolderCard>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => FolderPickerSheet(
        title: l.folderPickTitle,
        folders: [
          for (final folder in folders)
            if (folder.id != widget.folderId) folder,
        ],
        allowNone: widget.folderId != null,
        noneLabel: l.folderNone,
        onNew: () => askNewFolder(sheet, ref),
      ),
    );
    if (picked == null) return;
    final to = picked == FolderPickerSheet.none ? null : picked.id;
    final chosen = [
      for (final card in cards)
        if (_selected.contains(card.id)) card,
    ];
    for (final card in chosen) {
      await items.moveToFolder(card.id, to, clock());
    }
    _clear();
    showUndo(
      messenger,
      message: l.selMoved(chosen.length, to == null ? l.folderNone : picked.name),
      label: l.undo,
      onUndo: () async {
        for (final card in chosen) {
          await items.moveToFolder(card.id, card.folderId, clock());
        }
      },
    );
  }

  Future<void> _tagSelected(List<ItemCard> cards, {required bool remove}) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tags = ref.read(tagsRepositoryProvider);
    final chosen = [
      for (final card in cards)
        if (_selected.contains(card.id)) card,
    ];
    final all = ref.read(allTagsProvider).value ?? const <TagCard>[];
    // снимать есть смысл только те теги, что стоят хоть у одной выбранной вещи
    final present = {for (final card in chosen) ...card.tags};
    final name = await showTagPicker(
      context,
      tags: remove
          ? [
              for (final tag in all)
                if (present.contains(tag.name)) tag,
            ]
          : all,
      filesRoot: ref.read(filesRootProvider),
      allowNew: !remove,
    );
    if (name == null) return;
    for (final card in chosen) {
      remove ? await tags.unlink(card.id, name) : await tags.link(card.id, name);
    }
    _clear();
    showNote(messenger, remove ? l.selUntagged(name) : l.selTagged(name));
  }

  Future<void> _deleteSelected(List<ItemCard> cards) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final items = ref.read(itemsRepositoryProvider);
    final ids = [
      for (final card in cards)
        if (_selected.contains(card.id)) card.id,
    ];
    for (final id in ids) {
      await items.softDelete(id, ref.read(clockProvider)());
    }
    _clear();
    showUndo(
      messenger,
      message: l.selDeleted(ids.length),
      label: l.undo,
      onUndo: () async {
        for (final id in ids) {
          await items.restore(id);
        }
      },
    );
  }

  /// [colored] — у картинок папки уже есть главные цвета: можно разложить по цвету.
  Future<void> _pickOrder({required bool colored}) async {
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
              if (colored) (FolderOrder.color, l.sortByColor),
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
    final action = await showFolderMenu(context, canNest: folder.depth < maxFolderDepth);
    if (!mounted || action == null) return;
    switch (action) {
      case FolderAction.graph:
        await Navigator.of(context).push(graphRoute(folderId: folder.id, title: folder.name));
      case FolderAction.nest:
        await askNewFolder(context, ref, parentId: folder.id);
      case FolderAction.move:
        await _moveFolder(folder);
      case FolderAction.rename:
        final name = await showRenameSheet(context, folder.name);
        if (name != null) await repository.rename(folder.id, name);
      case FolderAction.look:
        final look = await showLookSheet(context, folder);
        if (look != null) await repository.setLook(folder.id, icon: look.icon, shape: look.shape, color: look.color);
      case FolderAction.delete:
        final l = L.of(context);
        final messenger = ScaffoldMessenger.of(context);
        if (!await confirmFolderDelete(context, folder.name)) return;
        final moved = await repository.delete(folder.id, ref.read(clockProvider)());
        if (mounted) Navigator.pop(context);
        showUndo(messenger, message: l.folderDeleted, label: l.restoreAction, onUndo: () => repository.restore(folder.id, moved), overDock: true);
    }
  }

  /// Лист «Переложить в…»: папки, куда эта влезает (не в себя, не в свою вложенную,
  /// не глубже трёх уровней), и «Наверх» у вложенной.
  Future<void> _moveFolder(FolderCard folder) async {
    final l = L.of(context);
    final folders = ref.read(foldersProvider).value ?? const <FolderCard>[];
    final tree = FolderTree([for (final one in folders) FolderNode(id: one.id, name: one.name, parentId: one.parentId)]);
    final targets = [
      for (final one in inTreeOrder(folders))
        if (one.id != folder.parentId && tree.canMoveInto(folder.id, one.id)) one,
    ];
    final top = folder.parentId != null && tree.canMoveInto(folder.id, null);
    final picked = await showModalBottomSheet<({String? parentId})>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen + 8, 0, Space.screen, 8),
              child: Text(l.folderMoveTo, style: Theme.of(sheet).textTheme.titleMedium),
            ),
            if (targets.isEmpty && !top)
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen + 8, 0, Space.screen + 8, Space.screen),
                child: Text(l.folderMoveNone, style: Theme.of(sheet).textTheme.bodyMedium!.copyWith(color: Tokens.muted)),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
                children: [
                  if (top) FolderOption(icon: 'vertical_align_top', shape: 'squircle', name: l.folderMoveTop, onTap: () => Navigator.pop(sheet, (parentId: null))),
                  for (final one in targets)
                    FolderOption(icon: one.icon, shape: one.shape, name: one.name, path: one.parentsLabel, onTap: () => Navigator.pop(sheet, (parentId: one.id))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) await ref.read(foldersRepositoryProvider).move(folder.id, picked.parentId);
  }

  /// Касание по пути родителей: родитель уже открыт под этим экраном — к нему назад,
  /// иначе он встаёт на место этого экрана. Экраны одной папки не копятся.
  void _openParent(String parentId) {
    final navigator = Navigator.of(context);
    if (_FolderScreenState._opened.contains(parentId)) {
      navigator.popUntil((route) => route.settings.name == folderRouteName(parentId) || route.isFirst);
    } else {
      navigator.pushReplacement(folderRoute(parentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final folders = ref.watch(foldersProvider).value ?? const [];
    final folder = folders.where((one) => one.id == widget.folderId).firstOrNull;
    final total = folder == null ? const <(double, String)>[] : ref.watch(folderTotalProvider(folder.id)).value ?? const <(double, String)>[];
    final children = folder == null ? const <FolderCard>[] : [for (final one in folders) if (one.parentId == folder.id) one];
    final cards = ref.watch(folderItemsProvider(widget.folderId)).value ?? const [];
    final filesRoot = ref.watch(filesRootProvider);
    final now = ref.read(clockProvider)();
    final board = showAsBoard(cards, folder?.view ?? FolderView.auto);
    final bottom = MediaQuery.paddingOf(context).bottom;

    // порядок чипов как на экране 6 макета: сначала то, что смотрят, потом читают
    const kindOrder = [ItemKind.video, ItemKind.voice, ItemKind.link, ItemKind.note, ItemKind.image, ItemKind.file];
    final kinds = <ItemKind>[
      for (final kind in kindOrder)
        if (cards.any((card) => card.kind == kind)) kind,
    ];
    final tags = folderTags(cards);
    final shown = orderCards(cards.where((card) => board ? (_tag == null || card.tags.contains(_tag)) : (_kind == null || card.kind == _kind)), _order);

    // вещь могла уйти из папки, пока была выбрана
    _selected.removeWhere((id) => !cards.any((card) => card.id == id));

    // холст занимает всё под шапкой и не прокручивается вместе с ней
    final canvas = folder != null && folder.view == FolderView.canvas && cards.isNotEmpty;
    final shownView = canvas ? FolderView.canvas : (board ? FolderView.board : FolderView.list);

    final headerRow = Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 0),
      child: _selecting
          ? Row(
              children: [
                _RoundButton(icon: 'close', tooltip: l.selClear, onTap: _clear),
                const SizedBox(width: 12),
                Expanded(child: Text(l.selCount(_selected.length), style: text.titleLarge!.copyWith(fontSize: 18))),
                if (_selected.length < shown.length) TextButton(onPressed: () => setState(() => _selected.addAll(shown.map((card) => card.id))), child: Text(l.selAll)),
              ],
            )
          : Row(
              children: [
                _RoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.pop(context)),
                const Spacer(),
                _RoundButton(icon: 'search', tooltip: l.folderSearch, onTap: () => _dock.currentState?.focusLine()),
                if (cards.length > 1 && !canvas) ...[const SizedBox(width: 8), _RoundButton(icon: 'sort', tooltip: l.sortTooltip, onTap: () => _pickOrder(colored: cards.any((card) => card.mainColor != null)))],
                if (folder != null) ...[const SizedBox(width: 8), _RoundButton(icon: 'more_vert', tooltip: l.folderMore, onTap: () => _menu(folder))],
              ],
            ),
    );
    final parents = folder?.parentsLabel;
    final titleRow = Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 16, Space.screen, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // путь родителей над именем: касание ведёт к ближайшему
          if ((parents, folder?.parentId) case (final String parents, final String parentId))
            Pressable(
              onTap: () => _openParent(parentId),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(symbolIcon('subdirectory_arrow_right'), size: 16, color: Tokens.muted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(parents, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelLarge!.copyWith(color: Tokens.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // значок в цвет папки: тот же цвет, что у пилюли на главной и меток заметок
              if (folder != null) ...[
                ShapeBadge(
                  shape: BadgeShape.values.asNameMap()[folder.shape] ?? BadgeShape.squircle,
                  size: 36,
                  color: folder.color,
                  child: Icon(symbolIcon(folder.icon, filled: true), size: 19, color: inkOn(folder.color)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(child: Text(folder?.name ?? l.folderNone, style: text.headlineMedium!.copyWith(fontSize: 26, height: 1.1, letterSpacing: -0.6))),
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
          // деньги из заметок папки и вложенных: «Всего 23 150 лей · €40»
          if (folder != null && total.isNotEmpty)
            Padding(
              key: const ValueKey('folder-total'),
              padding: const EdgeInsets.only(top: 8),
              child: Text(l.folderTotal(formatTotal(total, l.localeName)), style: text.bodyMedium!.copyWith(fontSize: 15, color: Tokens.onSurfaceVariant)),
            ),
        ],
      ),
    );
    final shelf = children.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 16),
            child: FolderShelf(folders: children, onOpen: (child) => Navigator.of(context).push(folderRoute(child.id))),
          );
    final viewSwitch = folder == null || cards.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, 14, Space.screen, 0),
            child: _Segments(
              view: shownView,
              labels: {FolderView.board: l.folderBoard, FolderView.canvas: l.folderCanvas, FolderView.list: l.folderList},
              onChanged: (view) {
                _clear();
                ref.read(foldersRepositoryProvider).setView(folder.id, view);
              },
            ),
          );

    return PopScope(
      // «Назад» сперва снимает выбор, а не закрывает папку
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clear();
      },
      child: Scaffold(
        body: Stack(
          children: [
            if (canvas)
              Column(
                children: [
                  SafeArea(bottom: false, child: headerRow),
                  titleRow,
                  ?shelf,
                  ?viewSwitch,
                  const SizedBox(height: 12),
                  Expanded(
                    child: CanvasView(folderId: folder.id, cards: cards, onOpen: _open, bottomInset: _dockSpace + bottom),
                  ),
                ],
              )
            else
              CustomScrollView(
                slivers: [
                  SliverSafeArea(bottom: false, sliver: SliverToBoxAdapter(child: headerRow)),
                  SliverToBoxAdapter(child: titleRow),
                  if (shelf != null) SliverToBoxAdapter(child: shelf),
                  // «Без папки»: разложить по одной карточке
                  if (widget.folderId == null && cards.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(Space.screen, 14, Space.screen, 0),
                        child: FilledButton.icon(onPressed: () => Navigator.of(context).push(sortRoute()), icon: Icon(symbolIcon('swipe_down')), label: Text(l.sortMode)),
                      ),
                    ),
                  if (viewSwitch != null) SliverToBoxAdapter(child: viewSwitch),
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
                              for (final tag in tags) _FilterChip(label: tag[0].toUpperCase() + tag.substring(1), on: _tag == tag, onTap: () => setState(() => _tag = tag))
                            else
                              for (final kind in kinds) _FilterChip(label: kindsLabel(l, kind), icon: kindIcon(kind), on: _kind == kind, onTap: () => setState(() => _kind = kind)),
                          ],
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  // в папке только вложенные: «пусто» было бы неправдой
                  if (cards.isEmpty && children.isNotEmpty)
                    SliverToBoxAdapter(child: SizedBox(height: _dockSpace + bottom))
                  else if (cards.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(40, 0, 40, _dockSpace + bottom),
                        child: Center(
                          child: Text(
                            l.folderEmpty,
                            textAlign: TextAlign.center,
                            style: text.bodyLarge!.copyWith(color: Tokens.muted),
                          ),
                        ),
                      ),
                    )
                  else if (board)
                    SliverToBoxAdapter(
                      child: _Board(cards: shown, filesRoot: filesRoot, selected: _selected, onTap: _tap, onAct: _act),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                      sliver: SliverList.separated(
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => RiseIn(
                          key: ValueKey(shown[index].id),
                          delay: index.clamp(0, 8),
                          child: _Selectable(
                            selecting: _selecting,
                            selected: _selected.contains(shown[index].id),
                            child: FolderItemCard(card: shown[index], filesRoot: filesRoot, now: now, onTap: () => _tap(shown[index]), onLongPress: () => _act(shown[index])),
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
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // прозрачный край того же цвета: от прозрачного чёрного светлая тема серела бы
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Tokens.background.withValues(alpha: 0), Tokens.background], stops: const [0, 0.3]),
                  ),
                ),
              ),
            ),
            // при выборе вместо строки — действия над выбранным
            if (_selecting)
              Positioned(
                left: Space.screen,
                right: Space.screen,
                bottom: bottom + 16,
                child: _SelectionBar(
                  onMove: () => _moveSelected(cards),
                  onTag: () => _tagSelected(cards, remove: false),
                  onUntag: cards.any((card) => _selected.contains(card.id) && card.tags.isNotEmpty) ? () => _tagSelected(cards, remove: true) : null,
                  onDelete: () => _deleteSelected(cards),
                ),
              )
            else
              Positioned.fill(
                child: LineDock(key: _dock, homeFolder: folder, onOpenItem: _open),
              ),
          ],
        ),
      ),
    );
  }
}

/// Отметка выбора поверх карточки: белый круг с галочкой, пустой — у невыбранных.
class _Selectable extends StatelessWidget {
  const _Selectable({required this.selecting, required this.selected, required this.child});

  final bool selecting;
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      // ширина от ленты как есть: иначе короткие заметки сжимаются до текста
      fit: StackFit.passthrough,
      children: [
        AnimatedScale(scale: selected ? 0.95 : 1, duration: Motion.short, curve: Motion.emphasized, child: child),
        Positioned(
          top: 10,
          right: 10,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: selecting ? 1 : 0,
              duration: Motion.short,
              child: AnimatedContainer(
                duration: Motion.short,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selected ? Tokens.accent : Tokens.background.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: selected ? null : Border.all(color: Tokens.onSurfaceVariant, width: 2),
                ),
                child: selected ? Icon(symbolIcon('check'), size: 18, color: Tokens.onAccent) : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Плавающая пилюля действий над выбранным, как панель на странице вещи.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.onMove, required this.onTag, required this.onUntag, required this.onDelete});

  final VoidCallback onMove;
  final VoidCallback onTag;
  final VoidCallback? onUntag;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    Widget action(String icon, String label, VoidCallback? onTap, {bool danger = false}) {
      final color = onTap == null ? Tokens.muted : (danger ? Tokens.error : Tokens.onSurface);
      return Expanded(
        child: Pressable(
          onTap: onTap,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(symbolIcon(icon), size: 22, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(fontSize: 12, color: color),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: BorderRadius.circular(100)),
      child: Row(
        children: [action('drive_file_move', l.selMove, onMove), action('sell', l.selTag, onTag), action('label_off', l.selUntag, onUntag), action('delete', l.selDelete, onDelete, danger: true)],
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
          decoration: BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
          child: Icon(symbolIcon(icon), color: Tokens.onSurface),
        ),
      ),
    );
  }
}

/// «Доска · Холст · Список», как переключатель на экране 4 макета.
class _Segments extends StatelessWidget {
  const _Segments({required this.view, required this.labels, required this.onChanged});

  final FolderView view;
  final Map<FolderView, String> labels;
  final ValueChanged<FolderView> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(String icon, FolderView target, BorderRadius radius) {
      final on = view == target;
      final label = labels[target]!;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(target),
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
    }

    return Row(
      children: [
        segment('grid_view', FolderView.board, const BorderRadius.horizontal(left: Radius.circular(22), right: Radius.circular(8))),
        const SizedBox(width: 2),
        segment('gesture', FolderView.canvas, BorderRadius.circular(8)),
        const SizedBox(width: 2),
        segment('view_agenda', FolderView.list, const BorderRadius.horizontal(left: Radius.circular(8), right: Radius.circular(22))),
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
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Доска в две колонки: картинки в своих пропорциях, по очереди слева и справа.
class _Board extends StatelessWidget {
  const _Board({required this.cards, required this.filesRoot, required this.selected, required this.onTap, required this.onAct});

  final List<ItemCard> cards;
  final Directory filesRoot;
  final Set<String> selected;
  final ValueChanged<ItemCard> onTap;
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
                        child: _Selectable(
                          selecting: selected.isNotEmpty,
                          selected: selected.contains(card.id),
                          child: BoardTile(card: card, filesRoot: filesRoot, width: width, darkPill: index % 3 == 1, onTap: () => onTap(card), onLongPress: () => onAct(card)),
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
