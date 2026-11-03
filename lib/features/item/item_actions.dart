import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../l10n/app_localizations.dart';
import '../composer/line_dock.dart';
import '../folder/folder_sheets.dart';
import 'item_screen.dart';

enum _Action { open, move, delete }

/// Долгое нажатие на вещь в ленте: открыть, переложить в другую папку, удалить с «Вернуть».
Future<void> showItemActions(BuildContext context, WidgetRef ref, ItemCard card) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  Widget row(String icon, String label, _Action action, {bool danger = false}) => Builder(
    builder: (context) => ListTile(
      leading: Icon(symbolIcon(icon), color: danger ? Tokens.error : Tokens.onSurface),
      title: Text(label, style: TextStyle(color: danger ? Tokens.error : Tokens.onSurface)),
      onTap: () => Navigator.pop(context, action),
    ),
  );
  final action = await showModalBottomSheet<_Action>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen + 8, 0, Space.screen, 8),
            child: Text(card.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
          ),
          row('open_in_new', l.actionOpen, _Action.open),
          row('drive_file_move', l.itemMove, _Action.move),
          row('delete', l.itemDelete, _Action.delete, danger: true),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  final items = ref.read(itemsRepositoryProvider);
  final now = ref.read(clockProvider)();
  switch (action) {
    case _Action.open:
      await navigator.push(itemRoute(card.id));
    case _Action.move:
      final folders = ref.read(foldersProvider).value ?? const <FolderCard>[];
      final picked = await showModalBottomSheet<FolderCard>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        builder: (sheet) => FolderPickerSheet(
          title: l.folderPickTitle,
          folders: [for (final folder in folders) if (folder.id != card.folderId) folder],
          onNew: () => askNewFolder(sheet, ref),
        ),
      );
      if (picked == null) return;
      await items.moveToFolder(card.id, picked.id, now);
      messenger.showSnackBar(SnackBar(content: Text(l.itemMoved(picked.name))));
    case _Action.delete:
      await items.softDelete(card.id, now);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.itemDeleted),
          action: SnackBarAction(label: l.undo, onPressed: () => items.restore(card.id)),
        ),
      );
  }
}
