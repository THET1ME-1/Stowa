import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/platform.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../domain/return_plan.dart';
import '../../l10n/app_localizations.dart';
import '../../services/return_service.dart' show returnText;
import '../vault/vault_actions.dart' show addVault, switchVault, vaultLabel;
import 'workspace_model.dart';
import 'workspace_shell.dart';

/// Левый док: хранилище и «Найти или записать» сверху, ниже — панели, внизу тема и настройки.
class LeftDock extends StatelessWidget {
  const LeftDock({super.key, required this.onFind, required this.onTheme});

  final VoidCallback onFind;
  final VoidCallback onTheme;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ws = WorkspaceScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VaultCard(),
        _FindButton(label: l.wsFind, onTap: onFind),
        const Expanded(child: _PanelList(left: true)),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          child: Row(
            children: [
              const _AddPanel(left: true),
              const Spacer(),
              _DockIcon(icon: Tokens.palette.isDark ? 'light_mode' : 'dark_mode', tooltip: l.wsTheme, onTap: onTheme),
              _DockIcon(icon: 'settings', tooltip: l.settingsTitle, onTap: () => ws.open(const WsTab.settings())),
            ],
          ),
        ),
      ],
    );
  }
}

/// Правый док: только панели и «+ Панель».
class RightDock extends StatelessWidget {
  const RightDock({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _PanelList(left: false)),
        Padding(padding: EdgeInsets.fromLTRB(10, 4, 10, 10), child: Row(children: [_AddPanel(left: false)])),
      ],
    );
  }
}

/// Название и значок панели.
(String, String) _panelLook(L l, String id) => switch (id) {
  'sections' => ('explore', l.wsSections),
  'pinned' => ('keep', l.homePinned),
  'folders' => ('folder', l.homeFolders),
  'later' => ('schedule', l.returnWatchTitle),
  'yearAgo' => ('history', l.wsYearAgo),
  _ => ('cloud_sync', l.syncTitle),
};

/// Панели дока по порядку. Заголовок панели тянут мышью: место, куда она встанет,
/// подсвечивается полосой; бросить можно и в другой док.
class _PanelList extends StatelessWidget {
  const _PanelList({required this.left});

  final bool left;

  @override
  Widget build(BuildContext context) {
    final controller = WorkspaceScope.of(context);
    final panels = left ? controller.workspace.left : controller.workspace.right;
    return ListView(
      padding: EdgeInsets.fromLTRB(8, left ? 4 : 10, 8, 12),
      children: [
        for (final (index, id) in panels.indexed)
          _PanelDrop(key: ValueKey('drop-$id'), left: left, index: index, child: _Panel(key: ValueKey('panel-$id'), id: id, left: left)),
        // в конец дока — и в пустой док тоже
        _DropSlot(left: left, index: panels.length, tall: true),
      ],
    );
  }
}

/// Панель как цель перетаскивания: верхняя половина — встать перед ней, нижняя — после.
class _PanelDrop extends StatefulWidget {
  const _PanelDrop({super.key, required this.left, required this.index, required this.child});

  final bool left;
  final int index;
  final Widget child;

  @override
  State<_PanelDrop> createState() => _PanelDropState();
}

class _PanelDropState extends State<_PanelDrop> {
  bool _after = false;

  void _track(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final after = box.globalToLocal(global).dy > box.size.height / 2;
    if (after != _after) setState(() => _after = after);
  }

  @override
  Widget build(BuildContext context) {
    final controller = WorkspaceScope.of(context);
    return DragTarget<String>(
      onMove: (details) => _track(details.offset),
      onAcceptWithDetails: (details) => controller.update((ws) => ws.placePanel(details.data, left: widget.left, index: widget.index + (_after ? 1 : 0))),
      builder: (context, candidates, _) {
        final over = candidates.isNotEmpty;
        Widget line(bool show) => AnimatedContainer(
          duration: Motion.short,
          curve: Motion.emphasized,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: show ? Tokens.accent : Colors.transparent, borderRadius: BorderRadius.circular(2)),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [line(over && !_after), widget.child, line(over && _after)],
        );
      },
    );
  }
}

/// Место между панелями, куда можно бросить перетаскиваемую.
class _DropSlot extends StatelessWidget {
  const _DropSlot({required this.left, required this.index, this.tall = false});

  final bool left;
  final int index;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final controller = WorkspaceScope.of(context);
    return DragTarget<String>(
      onAcceptWithDetails: (details) => controller.update((ws) => ws.placePanel(details.data, left: left, index: index)),
      builder: (context, candidates, _) {
        final over = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: Motion.short,
          curve: Motion.emphasized,
          height: tall ? 160 : (over ? 12 : 6),
          alignment: Alignment.topCenter,
          child: AnimatedContainer(
            duration: Motion.short,
            curve: Motion.emphasized,
            height: over ? 4 : 0,
            decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(2)),
          ),
        );
      },
    );
  }
}

/// «+ Панель»: вернуть убранную панель в этот док.
class _AddPanel extends StatelessWidget {
  const _AddPanel({required this.left});

  final bool left;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final controller = WorkspaceScope.of(context);
    final hidden = controller.workspace.hiddenPanels;
    return AnimatedOpacity(
      duration: Motion.medium,
      curve: Motion.emphasized,
      opacity: hidden.isEmpty ? 0.45 : 1,
      child: MenuAnchor(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(Tokens.containerHigh),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        ),
        menuChildren: [
          for (final id in hidden)
            MenuItemButton(
              leadingIcon: Icon(symbolIcon(_panelLook(l, id).$1), size: 18, color: Tokens.onSurfaceVariant),
              onPressed: () {
                final target = left ? controller.workspace.left : controller.workspace.right;
                controller.update((ws) => ws.placePanel(id, left: left, index: target.length));
              },
              child: Text(_panelLook(l, id).$2),
            ),
        ],
        builder: (context, menu, _) => TextButton.icon(
          onPressed: hidden.isEmpty ? null : () => menu.isOpen ? menu.close() : menu.open(),
          style: TextButton.styleFrom(foregroundColor: Tokens.muted, textStyle: text.labelLarge),
          icon: Icon(symbolIcon('add'), size: 18),
          label: Text(l.wsAddPanel),
        ),
      ),
    );
  }
}

/// Что внутри панели.
class _PanelBody extends ConsumerWidget {
  const _PanelBody({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final ws = WorkspaceScope.of(context);
    final active = ws.workspace.focusedPane.activeTab;
    Widget empty(String message) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      child: Text(message, style: text.bodySmall!.copyWith(color: Tokens.muted)),
    );
    Widget nav(String icon, String label, WsTab tab, {int? count}) =>
        _NavRow(icon: icon, label: label, count: count, selected: active == tab, onTap: () => ws.open(tab));
    final List<Widget> rows;
    switch (id) {
      case 'sections':
        final pinned = ref.watch(pinnedItemsProvider).value ?? const [];
        final recent = ref.watch(recentItemsProvider).value ?? const [];
        final inbox = {for (final card in [...pinned, ...recent]) if (card.folderId == null) card.id}.length;
        final later = ref.watch(watchLaterProvider).value?.length ?? 0;
        rows = [
          nav('home', l.wsHome, const WsTab.home()),
          nav('inbox', l.folderNone, const WsTab.inbox(), count: inbox),
          nav('schedule', l.returnWatchTitle, const WsTab.later(), count: later),
          if (!isWeb) nav('map', l.mapTitle, const WsTab.map()),
          nav('hub', l.graphTitle, const WsTab.graph()),
        ];
      case 'pinned':
        final pinned = ref.watch(pinnedItemsProvider).value ?? const [];
        rows = pinned.isEmpty
            ? [empty(l.wsPanelEmpty)]
            : [
                for (final card in pinned.take(8))
                  _NavRow(icon: 'keep', label: card.title, selected: active == WsTab.item(card.id), onTap: () => ws.open(WsTab.item(card.id)), filledIcon: true),
              ];
      case 'folders':
        final folders = ref.watch(foldersProvider).value ?? const <FolderCard>[];
        rows = folders.isEmpty
            ? [empty(l.wsPanelEmpty)]
            : [
                for (final folder in folders)
                  _FolderDrag(
                    key: ValueKey('dock-folder-${folder.id}'),
                    folder: folder,
                    onDrop: (dragged, after) => ref.read(foldersRepositoryProvider).reorder(folderOrderAfterDrop(folders, dragged: dragged, target: folder, after: after)).ignore(),
                    child: _FolderRow(folder: folder, selected: active == WsTab.folder(folder.id), onTap: () => ws.open(WsTab.folder(folder.id))),
                  ),
              ];
      case 'later':
        final later = ref.watch(watchLaterProvider).value ?? const [];
        rows = later.isEmpty
            ? [empty(l.returnWatchEmpty)]
            : [for (final entry in later.take(6)) _LaterRow(title: entry.title, video: entry.isVideo, minutes: entry.minutes, onTap: () => ws.open(WsTab.item(entry.id)))];
      case 'yearAgo':
        final day = ref.watch(onThisDayProvider).value;
        rows = day == null
            ? [empty(l.wsPanelEmpty)]
            : [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: FolderPalette.tint(FolderPalette.colors['rose']!, 0.18),
                    borderRadius: BorderRadius.circular(Radii.tile),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => ws.open(WsTab.item(day.found.firstId)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Text(returnText(l, ReturnPick(ReturnKind.onThisDay, day: day.found)).title, style: text.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              ];
      default:
        // следит за входом и выходом, а не спрашивает один раз при показе панели
        final signedIn = ref.watch(syncSignedInProvider).value ?? false;
        rows = [
          _NavRow(icon: signedIn ? 'cloud_done' : 'cloud_off', label: signedIn ? l.wsSynced : l.wsSyncOff, selected: false, onTap: () => ws.open(const WsTab.settings('sync'))),
        ];
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// Шапка левой панели: буква и имя открытого хранилища, где оно лежит, стрелка. Нажали —
/// выпадает список хранилищ для переключения, стрелка поворачивается вверх (хозяин 22.11:
/// «вместо Stowa надо название текущей папки. При нажатии и стрелочку вниз»).
class _VaultCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_VaultCard> createState() => _VaultCardState();
}

class _VaultCardState extends ConsumerState<_VaultCard> {
  final _menu = MenuController();
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final root = ref.watch(vaultRootProvider);
    final signedIn = ref.watch(syncSignedInProvider).value ?? false;
    final inBrowser = ref.watch(storedInBrowserProvider);
    final list = ref.watch(vaultsProvider).value;
    final current = list?.all.where((one) => one.db == list.current).firstOrNull;
    final others = [
      if (list != null)
        for (final one in list.all)
          if (one.db != list.current) one,
    ];
    final name = current == null ? l.appName : vaultLabel(l, current, inBrowser: inBrowser);
    final where = signedIn ? l.wsSynced : (inBrowser ? l.wsInBrowser : root?.path ?? '');
    final count = ref.watch(notesCountProvider).value;
    final ws = WorkspaceScope.of(context);
    // список — ровно по шапке: та же ширина и тот же левый край (хозяин 22.11: «почему
    // ширина не такая же»), поэтому якорь списка — сама шапка, а ширина берётся с неё
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: LayoutBuilder(
        builder: (context, box) => MenuAnchor(
          controller: _menu,
          onOpen: () => setState(() => _open = true),
          onClose: () => setState(() => _open = false),
          alignmentOffset: const Offset(0, 4),
          // без тени: окно списка отделяет тон выше дока
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(Tokens.containerHighest),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            shadowColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(0),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            minimumSize: WidgetStatePropertyAll(Size(box.maxWidth, 0)),
            maximumSize: WidgetStatePropertyAll(Size(box.maxWidth, double.infinity)),
          ),
          menuChildren: [
            // меню берёт ширину по содержимому, пределы стиля ему не указ: ширину шапки
            // получает само содержимое
            Container(
              key: const ValueKey('dock-vault-menu'),
              width: box.maxWidth,
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _VaultOption(icon: 'folder_open', title: name, subtitle: count == null ? null : l.itemsCount(count), selected: true, onTap: () {}),
                  for (final one in others)
                    _VaultOption(
                      key: ValueKey('vault-option-${one.db}'),
                      icon: 'folder',
                      title: vaultLabel(l, one, inBrowser: inBrowser),
                      subtitle: one.notes == null ? null : l.itemsCount(one.notes!),
                      onTap: () => switchVault(context, ref, one),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Container(height: 1, color: Tokens.outline),
                  ),
                  if (ref.watch(manyVaultsProvider)) _VaultOption(icon: 'add', title: l.vaultAdd, onTap: () => addVault(context, ref)),
                  _VaultOption(icon: 'tune', title: l.vaultSection, onTap: () => ws.open(const WsTab.settings('vault'))),
                ],
              ),
            ),
          ],
          builder: (context, menu, _) => Pressable(
          key: const ValueKey('dock-vault'),
          radius: BorderRadius.circular(14),
          lift: 0,
          pressedScale: 0.98,
          onTap: () => menu.isOpen ? menu.close() : menu.open(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(11)),
                  child: Text(name.characters.first.toUpperCase(), style: text.titleMedium!.copyWith(color: Tokens.onAccent, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: signedIn ? FolderPalette.colors['mint'] : Tokens.muted),
                          ),
                          const SizedBox(width: 5),
                          Flexible(child: Text(where, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelSmall!.copyWith(color: Tokens.muted))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // вниз — список закрыт, вверх — открыт
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Motion.medium,
                  curve: Motion.emphasized,
                  child: Icon(symbolIcon('expand_more'), size: 20, color: Tokens.onSurfaceVariant),
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

/// Строка списка хранилищ: значок, имя, под ним число заметок; у открытого — галочка.
class _VaultOption extends StatelessWidget {
  const _VaultOption({super.key, required this.icon, required this.title, this.subtitle, this.selected = false, required this.onTap});

  final String icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MenuItemButton(
      onPressed: onTap,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        // строка с числом заметок выше: соседние хранилища не слипаются; ширину даёт список
        minimumSize: WidgetStatePropertyAll(Size(0, subtitle == null ? 44 : 56)),
      ),
      leadingIcon: Icon(symbolIcon(icon, filled: selected), size: 20, color: selected ? Tokens.onSurface : Tokens.onSurfaceVariant),
      trailingIcon: selected ? Icon(symbolIcon('check'), size: 18, color: Tokens.onSurface) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(color: Tokens.onSurface, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          if (subtitle case final subtitle?) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelSmall!.copyWith(color: Tokens.muted)),
        ],
      ),
    );
  }
}

class _FindButton extends StatelessWidget {
  const _FindButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Material(
        color: Tokens.container,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(symbolIcon('search'), size: 20, color: Tokens.muted),
                const SizedBox(width: 10),
                Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(color: Tokens.muted))),
                const _Keycap('Ctrl K'),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Keycap extends StatelessWidget {
  const _Keycap(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(7)),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: Tokens.onSurfaceVariant)),
    );
  }
}

/// Панель дока. Касание заголовка сворачивает её (содержимое уходит плавно), заголовок
/// тянут мышью в другое место; при наведении — «в другой док» и «убрать».
class _Panel extends StatefulWidget {
  const _Panel({super.key, required this.id, required this.left});

  final String id;
  final bool left;

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ws = WorkspaceScope.of(context);
    final id = widget.id;
    final collapsed = ws.workspace.collapsed.contains(id);
    final text = Theme.of(context).textTheme;
    final (icon, title) = _panelLook(l, id);
    Widget header({required bool feedback}) => Material(
      color: feedback ? Tokens.containerHigh : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ws.update((workspace) => collapsed ? workspace.collapsed.remove(id) : workspace.collapsed.add(id)),
        child: SizedBox(
          height: 34,
          width: feedback ? 240 : null,
          child: Row(
            children: [
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: collapsed ? -0.25 : 0,
                duration: Motion.medium,
                curve: Motion.emphasized,
                child: Icon(symbolIcon('expand_more'), size: 18, color: Tokens.muted),
              ),
              const SizedBox(width: 4),
              Icon(symbolIcon(icon), size: 17, color: Tokens.muted),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium!.copyWith(color: Tokens.muted, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                ),
              ),
              if (!feedback)
                // кнопки панели проявляются при наведении
                AnimatedOpacity(
                  duration: Motion.short,
                  curve: Motion.emphasized,
                  opacity: _hover ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_hover,
                    child: Row(
                      children: [
                        _MiniIcon(
                          icon: widget.left ? 'right_panel_open' : 'left_panel_open',
                          tooltip: widget.left ? l.wsToRight : l.wsToLeft,
                          onTap: () => ws.update((workspace) => workspace.placePanel(id, left: !widget.left, index: 0)),
                        ),
                        _MiniIcon(icon: 'close', tooltip: l.wsHidePanel, onTap: () => ws.update((workspace) => workspace.hidePanel(id))),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Draggable<String>(
            data: id,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: Opacity(opacity: 0.9, child: header(feedback: true)),
            childWhenDragging: Opacity(opacity: 0.35, child: header(feedback: false)),
            child: MouseRegion(cursor: SystemMouseCursors.grab, child: header(feedback: false)),
          ),
          // сворачивается высотой и прозрачностью вместе, без рывка
          AnimatedSize(
            duration: Motion.long,
            curve: Motion.emphasized,
            alignment: Alignment.topCenter,
            child: AnimatedOpacity(
              duration: Motion.medium,
              curve: Motion.emphasized,
              opacity: collapsed ? 0 : 1,
              child: collapsed
                  ? const SizedBox(width: double.infinity)
                  : Padding(padding: const EdgeInsets.only(top: 2, bottom: 8), child: _PanelBody(id: id)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon({required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 14,
        child: Padding(padding: const EdgeInsets.all(5), child: Icon(symbolIcon(icon), size: 16, color: Tokens.muted)),
      ),
    );
  }
}

/// Строка дока: значок, имя, число справа; выбранная — на тоне выше.
class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.selected, required this.onTap, this.count, this.filledIcon = false, this.iconColor});

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final bool filledIcon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.emphasized,
        decoration: BoxDecoration(color: selected ? Tokens.containerHigh : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 36,
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(symbolIcon(icon, filled: filledIcon), size: 19, color: iconColor ?? (selected ? Tokens.onSurface : Tokens.onSurfaceVariant)),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium!.copyWith(
                        color: selected ? Tokens.onSurface : Tokens.onSurfaceVariant,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (count case final count? when count > 0)
                    Text('$count', style: text.labelSmall!.copyWith(color: Tokens.muted, fontFeatures: const [FontFeature.tabularFigures()])),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Порядок папок одного уровня после того, как [dragged] бросили на [target]: выше неё или,
/// с [after], ниже. Остальные соседки сдвигаются.
List<String> folderOrderAfterDrop(List<FolderCard> folders, {required FolderCard dragged, required FolderCard target, required bool after}) {
  final siblings = [for (final one in folders) if (one.parentId == target.parentId && one.id != dragged.id) one.id];
  siblings.insert(siblings.indexOf(target.id) + (after ? 1 : 0), dragged.id);
  return siblings;
}

/// Папку в левой панели зажали — она едет за указателем; над соседкой того же уровня видна
/// черта, куда папка встанет: над ней или под ней (хозяин 22.11: «перетаскивание на любую
/// позицию»). Вложенность перетаскивание не меняет: для этого «Переложить» в меню папки.
class _FolderDrag extends StatefulWidget {
  const _FolderDrag({super.key, required this.folder, required this.onDrop, required this.child});

  final FolderCard folder;
  final void Function(FolderCard dragged, bool after) onDrop;
  final Widget child;

  @override
  State<_FolderDrag> createState() => _FolderDragState();
}

class _FolderDragState extends State<_FolderDrag> {
  /// Куда встанет едущая папка: под этой строкой или над ней; null — над строкой никого.
  bool? _after;

  void _track(DragTargetDetails<FolderCard> details) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    // едущая строка той же высоты: её верх ниже верха этой — середина тоже ниже
    final after = box.globalToLocal(details.offset).dy > 0;
    if (after != _after) setState(() => _after = after);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => DragTarget<FolderCard>(
        onWillAcceptWithDetails: (details) => details.data.id != widget.folder.id && details.data.parentId == widget.folder.parentId,
        onMove: _track,
        onLeave: (_) => setState(() => _after = null),
        onAcceptWithDetails: (details) {
          final after = _after ?? false;
          setState(() => _after = null);
          widget.onDrop(details.data, after);
        },
        builder: (context, candidates, _) {
          final after = candidates.isEmpty ? null : _after;
          return LongPressDraggable<FolderCard>(
            data: widget.folder,
            axis: Axis.vertical,
            // мышью ждать полсекунды долго, а щелчок по папке короче трети секунды
            delay: const Duration(milliseconds: 300),
            feedback: Material(
              color: Tokens.containerHighest,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(width: constraints.maxWidth, child: widget.child),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: widget.child),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                widget.child,
                if (after != null)
                  Positioned(
                    left: 8,
                    right: 8,
                    top: after ? null : -2,
                    // под строкой у неё зазор в две точки: черта ложится в него
                    bottom: after ? 0 : null,
                    child: Container(
                      key: const ValueKey('dock-folder-drop'),
                      height: 2,
                      decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(1)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Папка в дереве: отступ по глубине, значок в цвет папки.
class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.folder, required this.selected, required this.onTap});

  final FolderCard folder;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: (folder.depth - 1) * 18.0),
      child: _NavRow(
        icon: folder.icon,
        label: folder.name,
        count: folder.count,
        selected: selected,
        onTap: onTap,
        filledIcon: true,
        iconColor: FolderPalette.ink(folder.color),
      ),
    );
  }
}

class _LaterRow extends StatelessWidget {
  const _LaterRow({required this.title, required this.video, required this.minutes, required this.onTap});

  final String title;
  final bool video;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(12)),
                child: Icon(symbolIcon(video ? 'smart_display' : 'article'), size: 20, color: Tokens.onSurface),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                    if (minutes > 0) Text(l.minutesShort(minutes), style: text.labelSmall!.copyWith(color: Tokens.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(symbolIcon(icon), size: 20, color: Tokens.onSurfaceVariant),
    );
  }
}
