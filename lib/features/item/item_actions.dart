import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../l10n/app_localizations.dart';
import '../composer/line_dock.dart';
import '../folder/folder_sheets.dart';
import 'item_screen.dart';

enum _Action { open, pin, notice, move, delete }

/// Путь папки от верхней до своей: (id, имя); без папки — «Без папки» с id null. Строка пути
/// в шапке заметки и документа на мониторе.
List<(String?, String)> folderPath(L l, String? folderId, List<FolderCard> folders) {
  final folder = folders.where((one) => one.id == folderId).firstOrNull;
  if (folder == null) return [(null, l.folderNone)];
  final chain = <FolderCard>[];
  for (FolderCard? at = folder; at != null && chain.length < 12; at = folders.where((one) => one.id == at!.parentId).firstOrNull) {
    chain.insert(0, at);
  }
  return [for (final one in chain) (one.id, one.name)];
}

/// Дата заметки: «Сейчас» или выбранные день и время; будущее обрезается до сейчас.
/// Плашка с «Отменить».
Future<void> changeItemDate(BuildContext context, WidgetRef ref, {required String id, required DateTime created}) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final items = ref.read(itemsRepositoryProvider);
  final choice = await showOptionsSheet<String>(
    context,
    title: l.itemDateChange,
    options: [
      SheetChoice(value: 'now', title: l.itemDateNow, icon: 'schedule'),
      SheetChoice(value: 'pick', title: l.itemDatePick, icon: 'calendar_today'),
    ],
  );
  if (choice == null || !context.mounted) return;
  final now = ref.read(clockProvider)();
  final before = created;
  var chosen = now;
  if (choice == 'pick') {
    final start = before.isAfter(now) ? now : before;
    final day = await showDatePicker(context: context, initialDate: start, firstDate: DateTime(1970), lastDate: now);
    if (day == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
    if (time == null) return;
    chosen = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (chosen.isAfter(now)) chosen = now;
  }
  if (chosen == before) return;
  await items.setCreated(id, chosen);
  showUndo(messenger, message: l.itemDateChanged, label: l.undo, overDock: true, onUndo: () => items.setCreated(id, before));
}

/// Закрепить в уведомлениях или убрать оттуда, с «Отменить». Разрешение на уведомления
/// спрашивается тут же, по действию человека.
Future<void> toggleNoticed(BuildContext context, WidgetRef ref, {required String id, required bool noticed, bool overDock = true}) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final items = ref.read(itemsRepositoryProvider);
  await items.setNoticed(id, !noticed);
  if (!noticed) await ref.read(notificationPortProvider).ensurePermission();
  showUndo(messenger, message: noticed ? l.noticeUnpinned : l.noticePinned, label: l.undo, onUndo: () => items.setNoticed(id, noticed), overDock: overDock);
}

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
  Haptics.longPress().ignore();
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final open = itemOpener(context);
  final noticed = await ref.read(itemsRepositoryProvider).isNoticed(card.id);
  if (!context.mounted) return;
  final action = await showOptionsSheet<_Action>(
    context,
    title: card.title,
    options: [
      SheetChoice(value: _Action.open, title: l.actionOpen, icon: 'open_in_new'),
      SheetChoice(value: _Action.pin, title: card.pinned ? l.itemUnpin : l.itemPin, icon: 'keep'),
      SheetChoice(value: _Action.notice, title: noticed ? l.noticeUnpin : l.noticePin, icon: noticed ? 'notifications_off' : 'notifications_active'),
      SheetChoice(value: _Action.move, title: l.itemMove, icon: 'drive_file_move'),
      SheetChoice(value: _Action.delete, title: l.itemDelete, icon: 'delete', danger: true),
    ],
  );
  if (action == null || !context.mounted) return;
  final items = ref.read(itemsRepositoryProvider);
  final now = ref.read(clockProvider)();
  switch (action) {
    case _Action.open:
      open(card.id);
    case _Action.pin:
      await togglePinned(context, ref, id: card.id, pinned: card.pinned);
    case _Action.notice:
      await toggleNoticed(context, ref, id: card.id, noticed: noticed);
    case _Action.move:
      await moveItem(context, ref, card);
    case _Action.delete:
      Haptics.delete().ignore();
      await items.softDelete(card.id, now);
      showUndo(messenger, message: l.itemDeleted, label: l.undo, onUndo: () => items.restore(card.id), overDock: true);
  }
}
