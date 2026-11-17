import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/platform.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../domain/return_plan.dart';
import '../../l10n/app_localizations.dart';
import '../../services/return_service.dart' show returnText;
import 'workspace_model.dart';
import 'workspace_shell.dart';

/// Вошёл ли человек в Stowa Sync: подпись под именем хранилища и панель справа.
final _syncSignedInProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    return await ref.watch(syncServiceProvider).account() != null;
  } on Object {
    return false;
  }
});

/// Левый док: хранилище, «Найти или записать», разделы, закреплённое, папки деревом.
class LeftDock extends ConsumerWidget {
  const LeftDock({super.key, required this.onFind, required this.onTheme});

  final VoidCallback onFind;
  final VoidCallback onTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final ws = WorkspaceScope.of(context);
    final folders = ref.watch(foldersProvider).value ?? const <FolderCard>[];
    final pinned = ref.watch(pinnedItemsProvider).value ?? const [];
    final recent = ref.watch(recentItemsProvider).value ?? const [];
    final inbox = {for (final card in [...pinned, ...recent]) if (card.folderId == null) card.id}.length;
    final later = ref.watch(watchLaterProvider).value?.length ?? 0;
    final active = ws.workspace.focusedPane.activeTab;

    Widget nav(String icon, String label, WsTab tab, {int? count}) =>
        _NavRow(icon: icon, label: label, count: count, selected: active == tab, onTap: () => ws.open(tab));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VaultCard(),
        _FindButton(label: l.wsFind, onTap: onFind),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            children: [
              _Panel(
                id: 'sections',
                icon: 'explore',
                title: l.wsSections,
                children: [
                  nav('home', l.wsHome, const WsTab.home()),
                  nav('inbox', l.folderNone, const WsTab.inbox(), count: inbox),
                  nav('schedule', l.returnWatchTitle, const WsTab.later(), count: later),
                  if (!isWeb) nav('map', l.mapTitle, const WsTab.map()),
                  nav('hub', l.graphTitle, const WsTab.graph()),
                ],
              ),
              if (pinned.isNotEmpty)
                _Panel(
                  id: 'pinned',
                  icon: 'keep',
                  title: l.homePinned,
                  children: [
                    for (final card in pinned.take(8))
                      _NavRow(icon: 'keep', label: card.title, selected: active == WsTab.item(card.id), onTap: () => ws.open(WsTab.item(card.id)), filledIcon: true),
                  ],
                ),
              if (folders.isNotEmpty)
                _Panel(
                  id: 'folders',
                  icon: 'folder',
                  title: l.homeFolders,
                  children: [for (final folder in folders) _FolderRow(folder: folder, selected: active == WsTab.folder(folder.id), onTap: () => ws.open(WsTab.folder(folder.id)))],
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          child: Row(
            children: [
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

/// Правый док: «Посмотреть потом», «Год назад», Stowa Sync.
class RightDock extends ConsumerWidget {
  const RightDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final ws = WorkspaceScope.of(context);
    final later = ref.watch(watchLaterProvider).value ?? const [];
    final day = ref.watch(onThisDayProvider).value;
    final signedIn = ref.watch(_syncSignedInProvider).value ?? false;
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      children: [
        _Panel(
          id: 'later',
          icon: 'schedule',
          title: l.returnWatchTitle,
          children: [
            if (later.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                child: Text(l.returnWatchEmpty, style: text.bodySmall!.copyWith(color: Tokens.muted)),
              ),
            for (final entry in later.take(6))
              _LaterRow(title: entry.title, video: entry.isVideo, minutes: entry.minutes, onTap: () => ws.open(WsTab.item(entry.id))),
          ],
        ),
        if (day != null)
          _Panel(
            id: 'yearAgo',
            icon: 'history',
            title: l.wsYearAgo,
            children: [
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
                      child: Text(
                        returnText(l, ReturnPick(ReturnKind.onThisDay, day: day.found)).title,
                        style: text.titleSmall!.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        _Panel(
          id: 'sync',
          icon: 'cloud_sync',
          title: l.syncTitle,
          children: [
            _NavRow(
              icon: signedIn ? 'cloud_done' : 'cloud_off',
              label: signedIn ? l.wsSynced : l.wsSyncOff,
              selected: false,
              onTap: () => ws.open(const WsTab.settings('sync')),
            ),
          ],
        ),
      ],
    );
  }
}

/// Карточка хранилища: буква, имя, где лежит.
class _VaultCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final root = ref.watch(vaultRootProvider);
    final signedIn = ref.watch(_syncSignedInProvider).value ?? false;
    final name = isWeb || root == null ? l.appName : p.basename(root.path);
    final where = signedIn ? l.wsSynced : (isWeb ? l.wsInBrowser : root?.path ?? '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
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

/// Панель дока: заголовок сворачивает её, содержимое уходит плавно.
class _Panel extends StatelessWidget {
  const _Panel({required this.id, required this.icon, required this.title, required this.children});

  final String id;
  final String icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ws = WorkspaceScope.of(context);
    final collapsed = ws.workspace.collapsed.contains(id);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => ws.update((workspace) => collapsed ? workspace.collapsed.remove(id) : workspace.collapsed.add(id)),
              child: SizedBox(
                height: 34,
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
                  ],
                ),
              ),
            ),
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
                  : Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                    ),
            ),
          ),
        ],
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
