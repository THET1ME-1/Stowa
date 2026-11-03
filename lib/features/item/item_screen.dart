import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../domain/item_title.dart';
import '../../l10n/app_localizations.dart';
import '../composer/line_dock.dart';
import '../composer/panel_text.dart';
import '../folder/folder_sheets.dart';

/// Страница въезжает справа, как в макете.
Route<void> itemRoute(String id) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => ItemScreen(id: id),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

final _checkLine = RegExp(r'^- \[([ xX])\] (.*)$');

/// Вещь целиком: папка сверху меняется касанием, теги, дата, напоминание,
/// картинки, текст с галочками, расшифровка и файлы.
class ItemScreen extends ConsumerWidget {
  const ItemScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final full = ref.watch(itemProvider(id)).value;
    final folders = ref.watch(foldersProvider).value ?? const [];
    final filesRoot = ref.watch(filesRootProvider);
    final now = ref.read(clockProvider)();
    if (full == null) return const Scaffold();
    final item = full.item;
    final folder = folders.where((one) => one.id == item.folderId).firstOrNull;
    final images = full.attachments.where((file) => file.mime.startsWith('image/')).toList();
    final files = full.attachments.where((file) => !file.mime.startsWith('image/')).toList();
    final lines = _bodyLines(item.body, item.title);

    Future<void> move() async {
      final target = await showModalBottomSheet<FolderCard>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        builder: (sheet) => FolderPickerSheet(title: l.folderPickTitle, folders: folders, onNew: () => askNewFolder(sheet, ref)),
      );
      if (target == null || !context.mounted) return;
      final items = ref.read(itemsRepositoryProvider);
      final clock = ref.read(clockProvider);
      final from = item.folderId;
      await items.moveToFolder(id, target.id, clock());
      if (!context.mounted) return;
      showUndo(ScaffoldMessenger.of(context), message: l.itemMoved(target.name), label: l.undo, onUndo: () => items.moveToFolder(id, from, clock()));
    }

    Future<void> toggle(int index) async {
      final all = item.body.split('\n');
      final match = _checkLine.firstMatch(all[index]);
      if (match == null) return;
      all[index] = '- [${match.group(1) == ' ' ? 'x' : ' '}] ${match.group(2)}';
      await ref.read(itemsRepositoryProvider).setBody(id, all.join('\n'), ref.read(clockProvider)());
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(symbolIcon('arrow_back'))),
                  const SizedBox(width: 4),
                  // чип занимает своё место целиком, а не половину ряда пополам с пустотой
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ActionChip(
                        onPressed: move,
                        avatar: Icon(symbolIcon(folder?.icon ?? 'inbox'), size: 18),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: Text(folder?.name ?? l.folderNone, overflow: TextOverflow.ellipsis)),
                            Icon(symbolIcon('expand_more'), size: 18),
                          ],
                        ),
                        backgroundColor: Tokens.containerHigh,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.itemCopy,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: item.body.isEmpty ? item.title : item.body));
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.itemCopied)));
                    },
                    icon: Icon(symbolIcon('content_copy')),
                  ),
                  IconButton(
                    tooltip: l.itemDelete,
                    onPressed: () async {
                      final repository = ref.read(itemsRepositoryProvider);
                      final messenger = ScaffoldMessenger.of(context);
                      await repository.softDelete(id, ref.read(clockProvider)());
                      if (context.mounted) Navigator.pop(context);
                      showUndo(messenger, message: l.itemDeleted, label: l.undo, onUndo: () => repository.restore(id));
                    },
                    icon: Icon(symbolIcon('delete')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.screen, 12, Space.screen, 40),
                children: [
                  Text(item.title, style: text.headlineSmall),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in full.tags.keys)
                        _MetaChip(label: '#$tag', removeTooltip: l.removeChip, onRemove: () => ref.read(tagsRepositoryProvider).unlink(id, tag)),
                      _MetaChip(
                        label: l.tagAdd,
                        icon: 'add',
                        onTap: () async {
                          final name = await _askTag(context);
                          if (name != null) await ref.read(tagsRepositoryProvider).link(id, name);
                        },
                      ),
                      // когда сохранено — со значком истории, чтобы не путать с напоминанием «сегодня в 16:41»
                      _MetaChip(label: shortDate(l, item.createdAt, now), icon: 'history'),
                      if (item.reminderAt != null) _MetaChip(label: formatReminder(l, item.reminderAt!, now), icon: 'alarm'),
                    ],
                  ),
                  for (final image in images) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.photo),
                      child: Image.file(
                        File(p.join(filesRoot.path, image.path)),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(height: 120, child: ColoredBox(color: Tokens.containerHigh)),
                      ),
                    ),
                  ],
                  if (lines.isNotEmpty) const SizedBox(height: 16),
                  for (final (index, line) in lines) _BodyLine(line: line, onToggle: () => toggle(index)),
                  if (item.transcript != null && item.transcript!.isNotEmpty) _DeepBlock(title: l.itemTranscript, text: item.transcript!),
                  if (item.aiDescription != null && item.aiDescription!.isNotEmpty) _DeepBlock(title: l.itemDescription, text: item.aiDescription!),
                  if (files.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(l.itemFiles, style: text.titleSmall!.copyWith(color: Tokens.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    for (final file in files) _FileRow(file: file),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // первая строка уже стоит заголовком: если она совпала, не повторяем её в тексте
  List<(int, String)> _bodyLines(String body, String title) {
    final all = body.split('\n');
    final lines = <(int, String)>[for (final (index, line) in all.indexed) (index, line)];
    final first = lines.indexWhere((entry) => entry.$2.trim().isNotEmpty);
    // строку с галочкой оставляем: без неё задачу не отметить
    if (first >= 0 && !_checkLine.hasMatch(lines[first].$2) && titleFor(lines[first].$2) == title) lines.removeAt(first);
    while (lines.isNotEmpty && lines.first.$2.trim().isEmpty) {
      lines.removeAt(0);
    }
    return lines;
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.icon, this.onRemove, this.removeTooltip, this.onTap});

  final String label;
  final String? icon;

  /// Крестик: снять тег только у этой вещи.
  final VoidCallback? onRemove;
  final String? removeTooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: EdgeInsets.only(left: 10, right: onRemove == null ? 10 : 2),
        decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(symbolIcon(icon), size: 15, color: Tokens.onSurfaceVariant), const SizedBox(width: 4)],
            Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 13, color: Tokens.onSurface)),
            if (onRemove != null)
              IconButton(
                tooltip: removeTooltip,
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 26, height: 26),
                iconSize: 15,
                icon: Icon(symbolIcon('close'), color: Tokens.muted),
              ),
          ],
        ),
      ),
    );
  }
}

/// Тег одной вещи руками: имя без решётки.
Future<String?> _askTag(BuildContext context) {
  final l = L.of(context);
  final field = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: field,
                autofocus: true,
                decoration: InputDecoration(prefixText: '#', hintText: l.tagNameHint),
                onSubmitted: (value) => Navigator.pop(context, value.trim().isEmpty ? null : value),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(context, field.text.trim().isEmpty ? null : field.text), child: Text(l.save)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Строка текста: галочка, заголовок, цитата, пункт или обычный абзац.
class _BodyLine extends StatelessWidget {
  const _BodyLine({required this.line, required this.onToggle});

  final String line;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final body = text.bodyLarge!.copyWith(fontSize: 16, height: 1.5, color: Tokens.onSurface);
    final check = _checkLine.firstMatch(line);
    if (check != null) {
      final done = check.group(1) != ' ';
      return InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(symbolIcon(done ? 'check_box' : 'check_box_outline_blank', filled: done), color: done ? Tokens.accent : Tokens.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  check.group(2)!,
                  style: body.copyWith(
                    color: done ? Tokens.muted : Tokens.onSurface,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: Tokens.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (line.trim().isEmpty) return const SizedBox(height: 10);
    final heading = RegExp(r'^(#{1,3}) (.*)$').firstMatch(line);
    if (heading != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(heading.group(2)!, style: text.titleLarge),
      );
    }
    if (line.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
        decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(12)),
        child: Text(line.substring(2), style: body.copyWith(color: Tokens.onSurfaceVariant)),
      );
    }
    if (line.startsWith('- ')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 10, left: 6),
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(color: Tokens.onSurfaceVariant, shape: BoxShape.circle),
              ),
            ),
            Expanded(child: Text(line.substring(2), style: body)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SelectableText(line, style: body),
    );
  }
}

class _DeepBlock extends StatelessWidget {
  const _DeepBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.tile)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: style.labelMedium!.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: Tokens.muted),
          ),
          const SizedBox(height: 4),
          SelectableText(text, style: style.bodyLarge!.copyWith(fontSize: 15, height: 1.45, color: Tokens.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file});

  final Attachment file;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final icon = switch (file.mime.split('/').first) {
      'video' => 'movie',
      'audio' => 'graphic_eq',
      'text' => 'notes',
      _ => 'description',
    };
    final name = p.basename(file.path).replaceFirst(RegExp(r'^\d+_'), '');
    final size = file.size < 1024 * 1024 ? '${(file.size / 1024).ceil()} KB' : '${(file.size / 1024 / 1024).toStringAsFixed(1)} MB';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.tile)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: BorderRadius.circular(12)),
            child: Icon(symbolIcon(icon), color: Tokens.onSurface),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                Text(size, style: text.bodySmall!.copyWith(color: Tokens.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
