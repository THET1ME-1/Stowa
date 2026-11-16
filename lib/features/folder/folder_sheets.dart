import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/sheet_options.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../domain/models.dart' show ItemKind;
import '../../l10n/app_localizations.dart';
import '../item/item_screen.dart' show itemRoute;

enum FolderAction { graph, newCanvas, newBase, nest, move, edit, hide, unhide, delete }

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

/// Меню папки снизу. Сверху одной строкой плитки «Создать внутри»: папку, холст, базу;
/// ниже строки: название и вид (имя, цвет, значок на одном экране), переложить, связи,
/// скрыть, удалить. Восемь строк столбиком листались и путали похожими пунктами.
/// [canNest] — папка не на третьем уровне, внутрь неё можно завести ещё одну.
/// [hidden] — папка скрыта: вместо «Скрыть» — «Не скрывать».
Future<FolderAction?> showFolderMenu(BuildContext context, {bool canNest = true, bool hidden = false}) {
  final l = L.of(context);
  return showOptionsSheetWith<FolderAction>(
    context,
    // имя папки уже крупно на экране под листом: второй бледный заголовок над «Создать внутри» лишний
    (sheet) => SheetOptionsBody(
      top: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: SheetTitle(l.folderCreateInside)),
          SheetTiles(
            children: [
              if (canNest) SheetTile(key: const ValueKey('folder-new-folder'), title: l.folderTileFolder, icon: 'create_new_folder', onTap: () => Navigator.pop(sheet, FolderAction.nest)),
              SheetTile(key: const ValueKey('folder-new-canvas'), title: l.folderTileCanvas, icon: 'dashboard', onTap: () => Navigator.pop(sheet, FolderAction.newCanvas)),
              SheetTile(key: const ValueKey('folder-new-base'), title: l.folderTileBase, icon: 'table_view', onTap: () => Navigator.pop(sheet, FolderAction.newBase)),
            ],
          ),
        ],
      ),
      children: [
        for (final (action, title, icon) in [
          (FolderAction.edit, l.folderEdit, 'edit'),
          (FolderAction.move, l.folderMoveTo, 'drive_file_move'),
          (FolderAction.graph, l.graphTitle, 'hub'),
          hidden ? (FolderAction.unhide, l.folderUnhide, 'visibility') : (FolderAction.hide, l.folderHide, 'visibility_off'),
        ])
          SheetOption(title: title, icon: icon, onTap: () => Navigator.pop(sheet, action)),
        SheetOption(title: l.folderDelete, icon: 'delete', danger: true, onTap: () => Navigator.pop(sheet, FolderAction.delete)),
      ],
    ),
  );
}

/// Холст или база: лист из двух, потом имя. Передумал — ничего.
Future<void> pickNewDocument(BuildContext context, WidgetRef ref, {String? folderId}) async {
  final l = L.of(context);
  final kind = await showOptionsSheet<ItemKind>(
    context,
    options: [
      SheetChoice(value: ItemKind.canvas, title: l.canvasNew, icon: 'dashboard'),
      SheetChoice(value: ItemKind.base, title: l.baseNew, icon: 'table_view'),
    ],
  );
  if (kind != null && context.mounted) await askNewDocument(context, ref, kind, folderId: folderId);
}

/// Спросить имя и завести холст или базу в папке; сразу открыть. Передумал — ничего.
Future<void> askNewDocument(BuildContext context, WidgetRef ref, ItemKind kind, {String? folderId}) async {
  final l = L.of(context);
  final name = await showRenameSheet(context, kind == ItemKind.base ? l.baseDefaultName : l.canvasDefaultName, label: l.baseColName, action: l.actionCreate);
  if (name == null || name.trim().isEmpty || !context.mounted) return;
  final id = await ref.read(documentsRepositoryProvider).create(kind, title: name.trim(), folderId: folderId);
  if (context.mounted) await Navigator.of(context).push(itemRoute(id));
}

/// Новое имя папки или null, если передумал. [label] и [action] — подпись поля и кнопки
/// для всего, что не папка: холст, база, рисунок.
Future<String?> showRenameSheet(BuildContext context, String current, {String? label, String? action}) {
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
            decoration: InputDecoration(labelText: label ?? l.folderNameLabel),
            onSubmitted: (value) => Navigator.pop(context, value.trim().isEmpty ? null : value),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text.trim().isEmpty ? null : field.text),
            child: Text(action ?? l.save),
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
