import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/sheet_options.dart';
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
  return showOptionsSheet<FolderAction>(
    context,
    options: [
      SheetChoice(value: FolderAction.graph, title: l.graphTitle, icon: 'hub'),
      if (canNest) SheetChoice(value: FolderAction.nest, title: l.folderNewInside, icon: 'create_new_folder'),
      SheetChoice(value: FolderAction.move, title: l.folderMoveTo, icon: 'drive_file_move'),
      SheetChoice(value: FolderAction.rename, title: l.folderRename, icon: 'edit'),
      SheetChoice(value: FolderAction.look, title: l.folderLook, icon: 'palette'),
      hidden
          ? SheetChoice(value: FolderAction.unhide, title: l.folderUnhide, icon: 'visibility')
          : SheetChoice(value: FolderAction.hide, title: l.folderHide, icon: 'visibility_off'),
      SheetChoice(value: FolderAction.delete, title: l.folderDelete, icon: 'delete', danger: true),
    ],
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
