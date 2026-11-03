import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker;
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion_bits.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/item_title.dart';
import '../../domain/note_blocks.dart';
import '../../l10n/app_localizations.dart';
import '../composer/line_dock.dart';
import '../composer/markdown_edit.dart';
import '../composer/panel_text.dart';
import '../composer/picked_files.dart';
import '../folder/folder_sheets.dart';
import 'markdown_controller.dart';
import 'note_body.dart';

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

/// Пауза в наборе, после которой правка сохраняется сама.
const _autosaveDelay = Duration(milliseconds: 700);

/// Вещь целиком, как страница в Notion (экран 7 макета): папка сверху меняется
/// касанием, теги, напоминание, картинки, текст с галочками, расшифровка и файлы.
/// Карандаш или касание по тексту открывают правку на месте, снизу встаёт панель.
class ItemScreen extends ConsumerStatefulWidget {
  const ItemScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ItemScreen> createState() => _ItemScreenState();
}

class _ItemScreenState extends ConsumerState<ItemScreen> {
  final _title = TextEditingController();
  final _body = MarkdownController();
  final _bodyFocus = FocusNode();
  bool _editing = false;
  Timer? _autosave;
  String? _savedTitle;
  String? _savedBody;

  // берутся в initState: сохранять приходится и в dispose, когда ref уже нельзя трогать
  late final ItemsRepository _items;
  late final DateTime Function() _clock;

  String get _id => widget.id;

  @override
  void initState() {
    super.initState();
    _items = ref.read(itemsRepositoryProvider);
    _clock = ref.read(clockProvider);
    _title.addListener(_changed);
    _body.addListener(_changed);
  }

  @override
  void dispose() {
    _autosave?.cancel();
    // ушли посреди правки — набранное не теряется
    if (_editing) _save();
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  /// Текст для правки без первой строки, если она стоит заголовком: иначе она двоилась бы.
  String _editableBody(Item item) {
    final lines = item.body.split('\n');
    final first = lines.indexWhere((line) => line.trim().isNotEmpty);
    if (first < 0 || checkLine.hasMatch(lines[first]) || !isTitleLine(lines[first], item.title)) return item.body;
    lines.removeAt(first);
    return lines.join('\n').replaceFirst(RegExp(r'^\n+'), '');
  }

  void _startEditing(Item item) {
    if (_editing) return;
    _savedTitle = item.title;
    _savedBody = _editableBody(item);
    _title.text = _savedTitle!;
    _body.text = _savedBody!;
    _body.selection = TextSelection.collapsed(offset: _body.text.length);
    setState(() => _editing = true);
    _bodyFocus.requestFocus();
  }

  void _changed() {
    if (!_editing) return;
    _autosave?.cancel();
    _autosave = Timer(_autosaveDelay, _save);
  }

  Future<void> _save() async {
    final body = _body.text;
    final typed = _title.text.trim();
    // заголовок стёрли — берётся из текста, как при сохранении из строки
    final title = typed.isNotEmpty ? typed : titleFor(body);
    if (title == _savedTitle && body == _savedBody) return;
    _savedTitle = title;
    _savedBody = body;
    await _items.setTitleBody(_id, title: title, body: body, at: _clock());
  }

  Future<void> _finish() async {
    _autosave?.cancel();
    await _save();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() => _editing = false);
  }

  void _markdown(MarkdownAction action) {
    _body.value = applyMarkdown(_body.value, action);
    _bodyFocus.requestFocus();
  }

  Future<void> _toggle(Item item, int index) async {
    final all = item.body.split('\n');
    final match = checkLine.firstMatch(all[index]);
    if (match == null) return;
    all[index] = '- [${match.group(1) == ' ' ? 'x' : ' '}] ${match.group(2)}';
    await _items.setBody(_id, all.join('\n'), _clock());
  }

  Future<void> _move(Item item, List<FolderCard> folders) async {
    final l = L.of(context);
    final target = await showModalBottomSheet<FolderCard>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => FolderPickerSheet(title: l.folderPickTitle, folders: folders, onNew: () => askNewFolder(sheet, ref)),
    );
    if (target == null || !mounted) return;
    final from = item.folderId;
    await _items.moveToFolder(_id, target.id, _clock());
    if (!mounted) return;
    showUndo(ScaffoldMessenger.of(context), message: l.itemMoved(target.name), label: l.undo, onUndo: () => _items.moveToFolder(_id, from, _clock()));
  }

  Future<void> _pickReminder(DateTime? current) async {
    final now = _clock();
    final start = current ?? DateTime(now.year, now.month, now.day + 1, 9);
    final day = await showDatePicker(context: context, initialDate: start.isBefore(now) ? now : start, firstDate: now, lastDate: DateTime(now.year + 5));
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
    if (time == null) return;
    await _items.setReminder(_id, DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  Future<void> _reminderMenu(DateTime current) async {
    final l = L.of(context);
    final remove = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Icon(symbolIcon('edit_calendar')), title: Text(l.itemReminderChange), onTap: () => Navigator.pop(sheet, false)),
            ListTile(
              leading: Icon(symbolIcon('notifications_off'), color: Tokens.error),
              title: Text(l.itemReminderRemove, style: const TextStyle(color: Tokens.error)),
              onTap: () => Navigator.pop(sheet, true),
            ),
          ],
        ),
      ),
    );
    if (remove == null || !mounted) return;
    if (remove) {
      await _items.setReminder(_id, null);
      if (mounted) showUndo(ScaffoldMessenger.of(context), message: l.reminderCleared, label: l.undo, onUndo: () => _items.setReminder(_id, current));
    } else {
      await _pickReminder(current);
    }
  }

  Future<void> _addPhotos() async {
    try {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty) return;
      final files = [for (final file in picked) await pickedFrom(file.path, hint: file.mimeType)];
      await ref.read(captureServiceProvider).attach(_id, files);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.of(context).attachFailed)));
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final full = ref.watch(itemProvider(_id)).value;
    final folders = ref.watch(foldersProvider).value ?? const <FolderCard>[];
    final filesRoot = ref.watch(filesRootProvider);
    final now = _clock();
    if (full == null) return const Scaffold();
    final item = full.item;
    final folder = folders.where((one) => one.id == item.folderId).firstOrNull;
    final images = full.attachments.where((file) => file.mime.startsWith('image/')).toList();
    final files = full.attachments.where((file) => !file.mime.startsWith('image/')).toList();
    final blocks = parseNoteBlocks(item.body, skipTitle: item.title);
    final titleStyle = text.headlineSmall!.copyWith(fontSize: 26, height: 1.2, letterSpacing: -0.4);
    final bodyStyle = text.bodyLarge!.copyWith(fontSize: 16, height: 1.55, color: Tokens.onSurface);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      // «назад» посреди правки сначала закрывает правку, сохранив текст
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Row(
                  children: [
                    IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: () => Navigator.maybePop(context), icon: Icon(symbolIcon('arrow_back'))),
                    const SizedBox(width: 4),
                    // чип занимает своё место целиком, а не половину ряда пополам с пустотой
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ActionChip(
                          onPressed: () => _move(item, folders),
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
                    if (!_editing) IconButton(tooltip: l.itemEdit, onPressed: () => _startEditing(item), icon: Icon(symbolIcon('edit'))),
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
                        final messenger = ScaffoldMessenger.of(context);
                        _autosave?.cancel();
                        _editing = false;
                        await _items.softDelete(_id, _clock());
                        if (context.mounted) Navigator.pop(context);
                        showUndo(messenger, message: l.itemDeleted, label: l.undo, onUndo: () => _items.restore(_id));
                      },
                      icon: Icon(symbolIcon('delete')),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                  padding: EdgeInsets.fromLTRB(Space.screen, 12, Space.screen, _editing ? 24 : 40 + bottom),
                  children: [
                    if (_editing)
                      TextField(
                        controller: _title,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _bodyFocus.requestFocus(),
                        style: titleStyle,
                        decoration: _bare(l.itemTitleHint),
                      )
                    else
                      GestureDetector(
                        onTap: () => _startEditing(item),
                        child: Text(item.title, style: titleStyle),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in full.tags.keys) _MetaChip(label: '#$tag', removeTooltip: l.removeChip, onRemove: () => ref.read(tagsRepositoryProvider).unlink(_id, tag)),
                        _MetaChip(
                          label: l.tagAdd,
                          icon: 'add',
                          onTap: () async {
                            final name = await _askTag(context);
                            if (name != null) await ref.read(tagsRepositoryProvider).link(_id, name);
                          },
                        ),
                        if (item.reminderAt != null) _MetaChip(label: formatReminder(l, item.reminderAt!, now), icon: 'alarm', onTap: () => _reminderMenu(item.reminderAt!)),
                        // когда сохранено — со значком истории, чтобы не путать с напоминанием «сегодня в 16:41»
                        _MetaChip(label: shortDate(l, item.createdAt, now), icon: 'history'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_editing)
                      TextField(
                        controller: _body,
                        focusNode: _bodyFocus,
                        maxLines: null,
                        minLines: 6,
                        keyboardType: TextInputType.multiline,
                        inputFormatters: [TextInputFormatter.withFunction(continueLists)],
                        textCapitalization: TextCapitalization.sentences,
                        style: bodyStyle,
                        decoration: _bare(l.itemBodyHint),
                      )
                    else if (blocks.isNotEmpty)
                      NoteBody(blocks: blocks, onToggle: (index) => _toggle(item, index), onEdit: () => _startEditing(item), onLink: _openLink),
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
              // панель правки, как на экране 7: список, чек-лист, фото, напоминание и «Готово».
              // Стоит под текстом, а не поверх: строка с курсором всегда видна над ней
              AnimatedSize(
                duration: const Duration(milliseconds: 380),
                curve: Motion.spatial,
                alignment: Alignment.topCenter,
                child: _editing
                    ? RiseIn(
                        child: _EditBar(
                          onBullets: () => _markdown(MarkdownAction.bullets),
                          onChecklist: () => _markdown(MarkdownAction.checklist),
                          onPhoto: _addPhotos,
                          onRemind: () => _pickReminder(item.reminderAt),
                          onDone: _finish,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _bare(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Tokens.muted),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    filled: false,
    isCollapsed: true,
    contentPadding: EdgeInsets.zero,
  );
}

/// Плавающая панель правки: группа кнопок в пилюле и круглая «Готово» справа.
class _EditBar extends StatelessWidget {
  const _EditBar({required this.onBullets, required this.onChecklist, required this.onPhoto, required this.onRemind, required this.onDone});

  final VoidCallback onBullets;
  final VoidCallback onChecklist;
  final VoidCallback onPhoto;
  final VoidCallback onRemind;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    Widget button(String icon, String tooltip, VoidCallback onTap) => IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(fixedSize: const Size.square(48)),
      icon: Icon(symbolIcon(icon), color: Tokens.onSurface),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, 8, Space.screen, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(32)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  button('format_list_bulleted', l.mdBullets, onBullets),
                  button('check_box', l.mdChecklist, onChecklist),
                  button('image', l.itemAddPhoto, onPhoto),
                  button('alarm', l.itemRemind, onRemind),
                ],
              ),
            ),
            const Spacer(),
            Tooltip(
              message: l.itemEditDone,
              child: Material(
                color: Tokens.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: InkWell(
                  onTap: onDone,
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox.square(dimension: 60, child: Icon(symbolIcon('done'), size: 28, color: Tokens.onAccent)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        height: 32,
        padding: EdgeInsets.only(left: 12, right: onRemove == null ? 12 : 2),
        decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(symbolIcon(icon), size: 16, color: Tokens.onSurfaceVariant), const SizedBox(width: 5)],
            Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 13, color: Tokens.onSurface)),
            if (onRemove != null)
              IconButton(
                tooltip: removeTooltip,
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 28, height: 28),
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
