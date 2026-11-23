import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../folder/folder_sheets.dart' show showRenameSheet;
import '../workspace/workspace_model.dart';
import '../workspace/workspace_shell.dart' show WorkspaceScope;
import 'history_screen.dart';
import 'item_actions.dart';

enum _DocAction { rename, move, pin, notice, date, history, delete }

/// Шапка холста, базы и рисунка — как у заметки (хозяин 22.11: «Почему шапка холста не такая
/// как шапка заметки», «Как мне папку выбрать, как название поменять?»).
///
/// На мониторе — строка, как у заметки: путь папки (часть открывает свою папку), название
/// (касание — переименовать), значки «Переложить в папку», «Переименовать», «Ещё». На
/// телефоне — «назад», название с видом и папкой, «Ещё»; в «Ещё» те же действия.
/// [detail] — подробность экрана («3 карточки»), [trailing] — свои кнопки экрана.
class DocumentHeader extends ConsumerWidget {
  const DocumentHeader({super.key, required this.item, required this.kindLabel, this.detail, this.trailing = const []});

  final Item item;
  final String kindLabel;
  final String? detail;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final folders = ref.watch(foldersProvider).value ?? const [];
    // вошли в Stowa Sync этого хранилища — у документа есть история на сервере
    ref.watch(syncSignedInProvider);
    final path = folderPath(l, item.folderId, folders);
    final workspace = WorkspaceScope.maybeOf(context);
    if (workspace != null) {
      final crumb = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Tokens.muted);
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        child: SizedBox(
          key: const ValueKey('document-bar'),
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (final (id, name) in path) ...[
                      Flexible(child: _Crumb(label: name, style: crumb, onTap: () => workspace.open(id == null ? const WsTab.inbox() : WsTab.folder(id)))),
                      Icon(symbolIcon('chevron_right'), size: 16, color: Tokens.muted),
                    ],
                    // название — последняя часть пути, крупнее; касание переименовывает
                    Flexible(
                      flex: 2,
                      child: Tooltip(
                        message: l.folderRename,
                        child: _Crumb(
                          key: const ValueKey('document-title'),
                          label: item.title,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Tokens.onSurface),
                          onTap: () => renameDocument(context, ref, item),
                        ),
                      ),
                    ),
                    if (detail case final detail?) ...[
                      const SizedBox(width: 6),
                      Flexible(child: Text('$kindLabel · $detail', maxLines: 1, overflow: TextOverflow.ellipsis, style: crumb)),
                    ],
                  ],
                ),
              ),
              ...trailing,
              _Icon(icon: 'drive_file_move', tooltip: l.itemMove, onTap: () => moveItemById(context, ref, id: item.id, from: item.folderId)),
              _Icon(icon: 'edit', tooltip: l.folderRename, onTap: () => renameDocument(context, ref, item)),
              _Icon(icon: 'more_vert', tooltip: l.itemMore, onTap: () => _menu(context, ref)),
            ],
          ),
        ),
      );
    }
    final folder = path.last.$2;
    return Padding(
      key: const ValueKey('document-bar'),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Row(
        children: [
          if (Navigator.canPop(context)) ...[
            _Round(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.maybePop(context)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Tooltip(
              message: l.folderRename,
              child: InkWell(
                key: const ValueKey('document-title'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => renameDocument(context, ref, item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        [kindLabel, ?detail, folder].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Tokens.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          for (final widget in trailing) ...[widget, const SizedBox(width: 6)],
          _Round(icon: 'more_vert', tooltip: l.itemMore, onTap: () => _menu(context, ref)),
        ],
      ),
    );
  }

  /// «Ещё»: то же, что у заметки, что имеет смысл у холста и базы.
  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final action = await showOptionsSheet<_DocAction>(
      context,
      title: item.title,
      options: [
        SheetChoice(value: _DocAction.rename, title: l.folderRename, icon: 'edit'),
        SheetChoice(value: _DocAction.move, title: l.itemMove, icon: 'drive_file_move'),
        SheetChoice(value: _DocAction.pin, title: item.pinnedAt == null ? l.itemPin : l.itemUnpin, icon: 'keep'),
        SheetChoice(
          value: _DocAction.notice,
          title: item.noticeAt == null ? l.noticePin : l.noticeUnpin,
          icon: item.noticeAt == null ? 'notifications_active' : 'notifications_off',
        ),
        SheetChoice(value: _DocAction.date, title: l.itemDateChange, icon: 'calendar_today'),
        if (ref.read(syncSignedInProvider).value ?? false) SheetChoice(value: _DocAction.history, title: l.historyTitle, icon: 'history'),
        SheetChoice(value: _DocAction.delete, title: l.itemDelete, icon: 'delete', danger: true),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _DocAction.rename:
        await renameDocument(context, ref, item);
      case _DocAction.move:
        await moveItemById(context, ref, id: item.id, from: item.folderId);
      case _DocAction.pin:
        await togglePinned(context, ref, id: item.id, pinned: item.pinnedAt != null, overDock: false);
      case _DocAction.notice:
        await toggleNoticed(context, ref, id: item.id, noticed: item.noticeAt != null, overDock: false);
      case _DocAction.date:
        await changeItemDate(context, ref, id: item.id, created: item.createdAt);
      case _DocAction.history:
        // «Отменить» после возврата показывает сам экран версии: прежний файл знает только он
        await Navigator.of(context).push(historyRoute(item.id, document: true));
      case _DocAction.delete:
        final messenger = ScaffoldMessenger.of(context);
        final items = ref.read(itemsRepositoryProvider);
        Haptics.delete().ignore();
        await items.softDelete(item.id, ref.read(clockProvider)());
        // во вкладке сайта документ — единственный экран: её закрывает вкладка, увидев удаление
        if (context.mounted) Navigator.maybePop(context).ignore();
        showUndo(messenger, message: l.itemDeleted, label: l.undo, onUndo: () => items.restore(item.id));
    }
  }
}

/// Переименовать холст, базу или рисунок: файл в хранилище переименует писатель, ссылки на
/// него в заметках и холстах поправит он же.
Future<void> renameDocument(BuildContext context, WidgetRef ref, Item item) async {
  final l = L.of(context);
  final name = await showRenameSheet(context, item.title, label: l.baseColName);
  if (name == null || name.trim().isEmpty || name.trim() == item.title) return;
  await ref.read(documentsRepositoryProvider).rename(item.id, name.trim());
}

/// Часть пути: подсвечивается под мышью, нажатие открывает папку.
class _Crumb extends StatelessWidget {
  const _Crumb({super.key, required this.label, required this.style, required this.onTap});

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      hoverColor: Tokens.container,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      ),
    );
  }
}

/// Значок действия на мониторе: без подложки, под мышью — мягкая подложка.
class _Icon extends StatelessWidget {
  const _Icon({required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: Tokens.containerHigh,
        child: SizedBox.square(dimension: 36, child: Icon(symbolIcon(icon), size: 20, color: Tokens.onSurfaceVariant)),
      ),
    );
  }
}

/// Круглая кнопка телефонной шапки.
class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Tokens.containerHigh,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: SizedBox.square(dimension: 44, child: Icon(symbolIcon(icon), size: 22, color: Tokens.onSurface))),
      ),
    );
  }
}
