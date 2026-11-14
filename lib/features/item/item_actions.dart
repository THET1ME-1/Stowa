import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../l10n/app_localizations.dart';
import '../composer/line_dock.dart';
import '../folder/folder_sheets.dart';
import 'item_screen.dart';

enum _Action { open, pin, move, delete }

/// Закрепить наверху главной или открепить, с «Отменить». Зовут лист долгого нажатия и «⋮» заметки.
Future<void> togglePinned(BuildContext context, WidgetRef ref, {required String id, required bool pinned, bool overDock = true}) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final items = ref.read(itemsRepositoryProvider);
  final was = await items.pinnedAt(id);
  await items.setPinned(id, pinned ? null : ref.read(clockProvider)());
  showUndo(messenger, message: pinned ? l.itemUnpinned : l.itemPinned, label: l.undo, onUndo: () => items.setPinned(id, was), overDock: overDock);
}

/// Переложить вещь в другую папку или новую, с «Отменить».
Future<void> moveItem(BuildContext context, WidgetRef ref, ItemCard card) => moveItemById(context, ref, id: card.id, from: card.folderId);

/// То же по id: плашка «Положил в …» знает только вещь и папку.
Future<void> moveItemById(BuildContext context, WidgetRef ref, {required String id, required String? from}) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final items = ref.read(itemsRepositoryProvider);
  final clock = ref.read(clockProvider);
  final folders = ref.read(foldersProvider).value ?? const <FolderCard>[];
  final picked = await showOptionsSheetWith<FolderCard>(
    context,
    (sheet) => FolderPickerSheet(
      title: l.folderPickTitle,
      folders: [for (final folder in folders) if (folder.id != from) folder],
      // угадыватель ошибся папкой — заметку можно вынуть совсем, он это запомнит
      allowNone: from != null,
      noneLabel: l.folderNone,
      onNew: () => askNewFolder(sheet, ref),
    ),
  );
  if (picked == null) return;
  final to = picked == FolderPickerSheet.none ? null : picked.id;
  await items.moveToFolder(id, to, clock());
  // перекладывают с главной и из папки, там внизу строка ввода
  showUndo(messenger, message: l.itemMoved(to == null ? l.folderNone : picked.name), label: l.undo, onUndo: () => items.moveToFolder(id, from, clock()), overDock: true);
}

/// Долгое нажатие на вещь в ленте: открыть, закрепить, переложить в другую папку, удалить с «Вернуть».
Future<void> showItemActions(BuildContext context, WidgetRef ref, ItemCard card) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final action = await showOptionsSheet<_Action>(
    context,
    title: card.title,
    options: [
      SheetChoice(value: _Action.open, title: l.actionOpen, icon: 'open_in_new'),
      SheetChoice(value: _Action.pin, title: card.pinned ? l.itemUnpin : l.itemPin, icon: 'keep'),
      SheetChoice(value: _Action.move, title: l.itemMove, icon: 'drive_file_move'),
      SheetChoice(value: _Action.delete, title: l.itemDelete, icon: 'delete', danger: true),
    ],
  );
  if (action == null || !context.mounted) return;
  final items = ref.read(itemsRepositoryProvider);
  final now = ref.read(clockProvider)();
  switch (action) {
    case _Action.open:
      await navigator.push(itemRoute(card.id));
    case _Action.pin:
      await togglePinned(context, ref, id: card.id, pinned: card.pinned);
    case _Action.move:
      await moveItem(context, ref, card);
    case _Action.delete:
      await items.softDelete(card.id, now);
      showUndo(messenger, message: l.itemDeleted, label: l.undo, onUndo: () => items.restore(card.id), overDock: true);
  }
}
