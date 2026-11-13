import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../l10n/app_localizations.dart';

enum FolderAction { graph, nest, move, rename, look, hide, unhide, delete }

/// Спросить имя и завести папку, с [parentId] — внутри той. Отказался — null.
Future<FolderCard?> askNewFolder(BuildContext context, WidgetRef ref, {String? parentId}) async {
  final name = await showRenameSheet(context, '');
  if (name == null) return null;
  return ref.read(foldersRepositoryProvider).create(name, parentId: parentId);
}

Future<T?> _sheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => Padding(
    // лист поднимается над клавиатурой
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(top: false, child: child),
  ),
);

/// Меню папки снизу: связи, папка внутри, переложить, переименовать, иконка и форма, удалить.
/// [canNest] — папка не на третьем уровне, внутрь неё можно завести ещё одну.
/// [hidden] — папка скрыта: вместо «Скрыть» — «Не скрывать».
Future<FolderAction?> showFolderMenu(BuildContext context, {bool canNest = true, bool hidden = false}) {
  final l = L.of(context);
  Widget row(String icon, String label, FolderAction action, {bool danger = false}) => ListTile(
    leading: Icon(symbolIcon(icon), color: danger ? Tokens.error : Tokens.onSurface),
    title: Text(label, style: TextStyle(color: danger ? Tokens.error : Tokens.onSurface)),
    onTap: () => Navigator.pop(context, action),
  );
  return _sheet(
    context,
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row('hub', l.graphTitle, FolderAction.graph),
          if (canNest) row('create_new_folder', l.folderNewInside, FolderAction.nest),
          row('drive_file_move', l.folderMoveTo, FolderAction.move),
          row('edit', l.folderRename, FolderAction.rename),
          row('palette', l.folderLook, FolderAction.look),
          hidden ? row('visibility', l.folderUnhide, FolderAction.unhide) : row('visibility_off', l.folderHide, FolderAction.hide),
          row('delete', l.folderDelete, FolderAction.delete, danger: true),
        ],
      ),
    ),
  );
}

/// Новое имя папки или null, если передумал.
Future<String?> showRenameSheet(BuildContext context, String current) {
  final l = L.of(context);
  final field = TextEditingController(text: current)..selection = TextSelection(baseOffset: 0, extentOffset: current.length);
  return _sheet<String>(
    context,
    Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: field,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.folderNameLabel),
            onSubmitted: (value) => Navigator.pop(context, value.trim().isEmpty ? null : value),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text.trim().isEmpty ? null : field.text),
            child: Text(l.save),
          ),
        ],
      ),
    ),
  );
}

/// Спросить перед удалением: вещи останутся без папки.
Future<bool> confirmFolderDelete(BuildContext context, String name) async {
  final l = L.of(context);
  final yes = await _sheet<bool>(
    context,
    Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.folderDeleteAsk(name), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Tokens.error, foregroundColor: Tokens.onError),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.folderDelete),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
        ],
      ),
    ),
  );
  return yes ?? false;
}
