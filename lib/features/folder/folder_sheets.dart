import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/shape_badge.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../l10n/app_localizations.dart';

enum FolderAction { rename, look, delete }

/// Спросить имя и завести папку. Отказался — null.
Future<FolderCard?> askNewFolder(BuildContext context, WidgetRef ref) async {
  final name = await showRenameSheet(context, '');
  if (name == null) return null;
  return ref.read(foldersRepositoryProvider).create(name);
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

/// Меню папки снизу: переименовать, иконка и форма, удалить.
Future<FolderAction?> showFolderMenu(BuildContext context) {
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
          row('edit', l.folderRename, FolderAction.rename),
          row('palette', l.folderLook, FolderAction.look),
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

/// Иконка и форма значка папки. Сверху ходовые иконки, поиск по всему набору.
Future<({String icon, String shape})?> showLookSheet(BuildContext context, FolderCard folder) {
  return _sheet(context, _LookSheet(folder: folder));
}

class _LookSheet extends StatefulWidget {
  const _LookSheet({required this.folder});

  final FolderCard folder;

  @override
  State<_LookSheet> createState() => _LookSheetState();
}

class _LookSheetState extends State<_LookSheet> {
  late String _icon = widget.folder.icon;
  late String _shape = widget.folder.shape;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final query = _query.trim().toLowerCase().replaceAll(' ', '_');
    final icons = query.isEmpty ? pickableSymbols : symbolNames.where((name) => name.contains(query)).take(60).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ShapeBadge(
                shape: BadgeShape.values.asNameMap()[_shape] ?? BadgeShape.squircle,
                size: 72,
                color: Tokens.accent,
                child: Icon(symbolIcon(_icon), size: 34, color: Tokens.onAccent),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.lookShape, style: text.titleSmall!.copyWith(color: Tokens.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final shape in BadgeShape.values)
                  GestureDetector(
                    onTap: () => setState(() => _shape = shape.name),
                    child: ShapeBadge(
                      shape: shape,
                      size: 48,
                      color: shape.name == _shape ? Tokens.accent : Tokens.containerHighest,
                      child: Icon(symbolIcon(_icon), size: 22, color: shape.name == _shape ? Tokens.onAccent : Tokens.onSurface),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l.lookIcon, style: text.titleSmall!.copyWith(color: Tokens.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(prefixIcon: Icon(symbolIcon('search')), hintText: l.iconSearch),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 56, mainAxisSpacing: 6, crossAxisSpacing: 6),
                itemCount: icons.length,
                itemBuilder: (context, index) {
                  final name = icons[index];
                  final on = name == _icon;
                  return GestureDetector(
                    onTap: () => setState(() => _icon = name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(color: on ? Tokens.accent : Tokens.containerHighest, borderRadius: BorderRadius.circular(16)),
                      child: Icon(symbolIcon(name), color: on ? Tokens.onAccent : Tokens.onSurface),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.pop(context, (icon: _icon, shape: _shape)), child: Text(l.save)),
          ],
        ),
      ),
    );
  }
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
