import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../core/widgets/voice_player.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/item_kind.dart';
import '../../domain/item_title.dart';
import '../../domain/models.dart';
import '../../domain/note_blocks.dart';
import '../../l10n/app_localizations.dart';
import '../composer/line_dock.dart';
import '../composer/markdown_edit.dart';
import '../composer/panel_text.dart';
import '../composer/picked_files.dart';
import '../folder/folder_sheets.dart';
import '../map/map_screen.dart';
import '../tags/tag_picker.dart';
import 'copying_bar.dart';
import 'item_media.dart';
import 'markdown_controller.dart';
import 'note_body.dart';
import 'photo_viewer.dart';
import 'related_block.dart';

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

/// Высота плавающей панели внизу и её отступ от края.
const _dockHeight = 72.0;
const _dockGap = 16.0;

/// Пробелы и переносы в конце текста: «Дописать» ставит курсор с новой строки,
/// а пустая строка в конце сохраняться не должна.
final _trailingSpace = RegExp(r'\s+$');

enum _MenuAction { copy, delete }

/// Вещь целиком, по образцу поста Togetherly: шапка с пилюлей папки, заголовок,
/// теги и напоминание отдельными блоками, текст своей карточкой, внизу плавающая
/// панель действий и «Дописать». Карандаш или касание по тексту открывают правку
/// на месте, тогда панель становится панелью разметки.
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

  /// Какой снимок стоит крупно, когда их несколько.
  int _cover = 0;

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

  /// Правка на месте. С `append` курсор встаёт с новой строки в конце текста.
  void _startEditing(Item item, {bool append = false}) {
    if (_editing) return;
    final body = _editableBody(item);
    _savedTitle = item.title;
    _savedBody = body.replaceFirst(_trailingSpace, '');
    _title.text = _savedTitle!;
    _body.text = append && body.trim().isNotEmpty && !body.endsWith('\n') ? '$body\n' : body;
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
    final body = _body.text.replaceFirst(_trailingSpace, '');
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

  Future<void> _addTag() async {
    final own = ref.read(itemProvider(_id)).value?.tags.keys.toSet() ?? const <String>{};
    final all = ref.read(allTagsProvider).value ?? const [];
    final name = await showTagPicker(context, tags: [for (final tag in all) if (!own.contains(tag.name)) tag], filesRoot: ref.read(filesRootProvider));
    if (name != null) await ref.read(tagsRepositoryProvider).link(_id, name);
  }

  Future<void> _addPhotos() async {
    // клавиатура под системным окном выбора только мешает
    FocusScope.of(context).unfocus();
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
    final messenger = ScaffoldMessenger.of(context);
    final message = L.of(context).linkOpenFailed;
    final uri = Uri.tryParse(url);
    final opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!opened) showNote(messenger, message, overDock: true);
  }

  /// Текст вещи как есть, а если его нет — заголовок.
  String _plainText(Item item) => item.body.trim().isEmpty ? item.title : item.body;

  Future<void> _share(Item item, List<Attachment> attachments, Directory filesRoot) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: _plainText(item),
      subject: item.title,
      files: [for (final file in attachments) XFile(p.join(filesRoot.path, file.path), mimeType: file.mime)],
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  Future<void> _copy(Item item) async {
    await Clipboard.setData(ClipboardData(text: _plainText(item)));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.of(context).itemCopied)));
  }

  Future<void> _delete() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _autosave?.cancel();
    _editing = false;
    await _items.softDelete(_id, _clock());
    if (mounted) Navigator.pop(context);
    showUndo(messenger, message: l.itemDeleted, label: l.undo, onUndo: () => _items.restore(_id));
  }

  Future<void> _menu(Item item) async {
    final action = await showModalBottomSheet<_MenuAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => _ItemMenu(title: item.title),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _MenuAction.copy:
        await _copy(item);
      case _MenuAction.delete:
        await _delete();
    }
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
    final url = item.url;
    // ссылка и ролик по адресу живут превью; свой ролик — файлом с обложкой и «Смотреть»
    final linkLike = url != null && (item.kind == ItemKind.link || item.kind == ItemKind.video);
    final videoLink = linkLike && item.kind == ItemKind.video;
    final videoFile = !linkLike && item.kind == ItemKind.video ? full.attachments.where((file) => file.mime.startsWith('video/')).firstOrNull : null;
    final voices = full.attachments.where((file) => file.mime.startsWith('audio/')).toList();
    final files = full.attachments.where((file) => !file.mime.startsWith('image/') && !file.mime.startsWith('audio/') && file != videoFile).toList();
    // адрес уже стоит в превью: строкой в тексте он не повторяется
    final shownBody = linkLike ? item.body.split('\n').where((line) => line.trim() != url).join('\n') : item.body;
    final blocks = parseNoteBlocks(shownBody, skipTitle: item.title);
    final source = url == null ? null : sourceName(Uri.tryParse(url)?.host ?? '');
    final duration = item.durationSeconds == null ? null : Duration(seconds: item.durationSeconds!);
    Future<void> openMain() => videoFile != null ? openLocalFile(context, p.join(filesRoot.path, videoFile.path), videoFile.mime) : _openLink(url!);
    final titleStyle = text.headlineSmall!.copyWith(fontSize: 25, height: 1.2, letterSpacing: -0.4);
    final bodyStyle = text.bodyLarge!.copyWith(fontSize: 16, height: 1.5, color: Tokens.onSurface);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final cover = images.isEmpty ? null : images[_cover.clamp(0, images.length - 1)];

    // в шапке вид вещи («заметка», «3 фото»), пока правка — что всё сохраняется; дата и место — строкой под заголовком
    final what = images.isNotEmpty ? l.itemPhotos(images.length) : kindLabel(l, item.kind);
    final subtitle = _editing ? l.itemAutosave : _capitalized(what);

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
              _Header(
                folder: folder,
                folderName: folder?.name ?? l.folderNone,
                subtitle: subtitle,
                editing: _editing,
                onBack: () => Navigator.maybePop(context),
                onFolder: () => _move(item, folders),
                onEdit: () => _startEditing(item),
                onMore: () => _menu(item),
              ),
              Expanded(
                child: Stack(
                  children: [
                    ListView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                      padding: EdgeInsets.fromLTRB(12, 6, 12, _dockHeight + _dockGap * 2 + bottom),
                      children: [
                        // файл ещё ложится: вещь уже правится, а показать его пока нечем
                        if (full.copying > 0) ...[
                          _Copying(itemId: item.id, count: full.copying),
                          const SizedBox(height: 18),
                        ],
                        if (videoLink || videoFile != null) ...[
                          VideoCover(coverPath: item.coverPath ?? cover?.path, filesRoot: filesRoot, onPlay: openMain, source: videoLink ? source : null, duration: duration),
                          const SizedBox(height: 18),
                        ] else if (linkLike) ...[
                          LinkPreviewCard(item: item, filesRoot: filesRoot, onOpen: openMain),
                          const SizedBox(height: 18),
                        ] else if (cover != null) ...[
                          _PhotoCover(
                            image: cover,
                            filesRoot: filesRoot,
                            onOpen: () => PhotoViewer.open(context, [for (final image in images) p.join(filesRoot.path, image.path)], _cover.clamp(0, images.length - 1)),
                          ),
                          if (images.length > 1) ...[
                            const SizedBox(height: 8),
                            _Thumbs(images: images, filesRoot: filesRoot, selected: _cover, onPick: (index) => setState(() => _cover = index)),
                          ],
                          const SizedBox(height: 18),
                        ] else
                          const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _editing
                              ? TextField(
                                  controller: _title,
                                  maxLines: null,
                                  textCapitalization: TextCapitalization.sentences,
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) => _bodyFocus.requestFocus(),
                                  style: titleStyle,
                                  decoration: _bare(l.itemTitleHint),
                                )
                              : GestureDetector(onTap: () => _startEditing(item), child: Text(item.title, style: linkLike ? titleStyle.copyWith(fontSize: 22) : titleStyle)),
                        ),
                        if (videoLink && item.previewAuthor != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                            child: Text(item.previewAuthor!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Tokens.onSurfaceVariant)),
                          ),
                        // когда и где сохранено: место открывает карту
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                          child: _WhenWhere(
                            at: item.createdAt,
                            now: now,
                            place: item.latitude == null ? null : (item.placeName ?? l.mapPlaceUnnamed),
                            onPlace: () => Navigator.of(context).push(mapRoute(focusItemId: _id)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in full.tags.keys)
                                _TagPill(
                                  label: '#$tag',
                                  removeTooltip: l.removeChip,
                                  // снять тег можно в правке, в просмотре пилюля просто называет его
                                  onRemove: _editing ? () => ref.read(tagsRepositoryProvider).unlink(_id, tag) : null,
                                ),
                              _TagPill(label: l.tagAdd, short: l.tagAddShort, add: true, onTap: _addTag),
                            ],
                          ),
                        ),
                        if (item.reminderAt != null) ...[
                          const SizedBox(height: 18),
                          _ReminderBlock(
                            at: item.reminderAt!,
                            now: now,
                            onTap: () => _reminderMenu(item.reminderAt!),
                            onChange: () => _pickReminder(item.reminderAt),
                          ),
                        ],
                        for (final voice in voices) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                            decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
                            child: VoicePlayer(path: p.join(filesRoot.path, voice.path), seedId: voice.id, large: true),
                          ),
                        ],
                        if (_editing || blocks.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          AnimatedContainer(
                            key: const ValueKey('item-body-card'),
                            duration: Motion.medium,
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                            decoration: BoxDecoration(color: _editing ? Tokens.containerHigh : Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
                            child: _editing
                                ? TextField(
                                    controller: _body,
                                    focusNode: _bodyFocus,
                                    maxLines: null,
                                    minLines: 5,
                                    keyboardType: TextInputType.multiline,
                                    inputFormatters: [TextInputFormatter.withFunction(continueLists)],
                                    textCapitalization: TextCapitalization.sentences,
                                    // строка с курсором не прячется под плавающую панель
                                    scrollPadding: const EdgeInsets.only(bottom: _dockHeight + _dockGap * 2 + 24),
                                    style: bodyStyle,
                                    decoration: _bare(l.itemBodyHint),
                                  )
                                : NoteBody(blocks: blocks, onToggle: (index) => _toggle(item, index), onEdit: () => _startEditing(item), onLink: _openLink),
                          ),
                        ],
                        if (item.transcript != null && item.transcript!.isNotEmpty) _DeepBlock(title: l.itemTranscript, text: item.transcript!),
                        // описание от ИИ нужно поиску; читать его стоит только у картинки, у заметки оно пересказ её же текста
                        if (images.isNotEmpty && item.aiDescription != null && item.aiDescription!.isNotEmpty) _DeepBlock(title: l.itemDescription, text: item.aiDescription!),
                        for (final file in files) FileTile(file: file, filesRoot: filesRoot),
                        if (!_editing) RelatedBlock(itemId: _id, onOpen: (id) => Navigator.of(context).push(itemRoute(id))),
                      ],
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: _dockGap + bottom,
                      child: AnimatedSwitcher(
                        duration: Motion.medium,
                        child: _editing
                            ? _Dock(
                                key: const ValueKey('edit-dock'),
                                height: 64,
                                buttons: [
                                  _DockButton(icon: 'format_list_bulleted', tooltip: l.mdBullets, onTap: () => _markdown(MarkdownAction.bullets)),
                                  _DockButton(icon: 'checklist', tooltip: l.mdChecklist, onTap: () => _markdown(MarkdownAction.checklist)),
                                  _DockButton(icon: 'format_bold', tooltip: l.mdBold, onTap: () => _markdown(MarkdownAction.bold)),
                                  _DockButton(icon: 'add_photo_alternate', tooltip: l.itemAddPhoto, onTap: _addPhotos),
                                ],
                                accentIcon: 'check',
                                accentLabel: l.itemEditDone,
                                onAccent: _finish,
                              )
                            : _Dock(
                                key: const ValueKey('view-dock'),
                                height: _dockHeight,
                                buttons: [
                                  _DockButton(
                                    icon: item.reminderAt != null ? 'alarm' : 'add_alarm',
                                    tooltip: l.itemRemind,
                                    active: item.reminderAt != null,
                                    onTap: () => item.reminderAt != null ? _reminderMenu(item.reminderAt!) : _pickReminder(null),
                                  ),
                                  _DockButton(icon: 'tag', tooltip: l.tagAdd, onTap: _addTag),
                                  // у ссылки главное — открыть, поэтому дописать мысль уходит в панель
                                  if (linkLike)
                                    _DockButton(icon: 'edit_note', tooltip: l.itemAppend, onTap: () => _startEditing(item, append: true))
                                  else
                                    _DockButton(icon: 'drive_file_move', tooltip: l.itemMove, onTap: () => _move(item, folders)),
                                  _DockButton(icon: 'share', tooltip: l.itemShare, onTap: () => _share(item, full.attachments, filesRoot)),
                                ],
                                accentIcon: videoLink || videoFile != null ? 'play_arrow' : (linkLike ? 'open_in_new' : 'add'),
                                accentLabel: videoLink || videoFile != null ? l.itemWatch : (linkLike ? l.itemOpenLink : l.itemAppend),
                                onAccent: linkLike || videoFile != null ? openMain : () => _startEditing(item, append: true),
                              ),
                      ),
                    ),
                  ],
                ),
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

String _capitalized(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// Круглая кнопка на подложке. Связанная группа задаёт свои углы.
/// «Сохраняю файл · 40 %» с полоской: пока не пропадёт, оригинал удалять рано.
class _Copying extends ConsumerWidget {
  const _Copying({required this.itemId, required this.count});

  final String itemId;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final fraction = ref.watch(copyFractionProvider(itemId)).value;
    final label = fraction == null ? l.fileSaving(count) : '${l.fileSaving(count)} · ${(fraction * 100).floor()} %';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(symbolIcon('downloading'), size: 20, color: Tokens.onSurface),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 4),
          Text(l.fileSavingHint, style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant)),
          const SizedBox(height: 12),
          CopyingBar(itemId: itemId),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap, this.radius = const BorderRadius.all(Radius.circular(24))});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Tokens.containerHigh,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(dimension: 48, child: Icon(symbolIcon(icon), size: 22, color: Tokens.onSurface)),
        ),
      ),
    );
  }
}

/// Шапка как у поста Togetherly: «назад», пилюля с папкой и днём, справа
/// сцепленные «править» и «ещё». Касание по пилюле перекладывает вещь.
class _Header extends StatelessWidget {
  const _Header({
    required this.folder,
    required this.folderName,
    required this.subtitle,
    required this.editing,
    required this.onBack,
    required this.onFolder,
    required this.onEdit,
    required this.onMore,
  });

  final FolderCard? folder;
  final String folderName;
  final String subtitle;
  final bool editing;
  final VoidCallback onBack;
  final VoidCallback onFolder;
  final VoidCallback onEdit;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Row(
        children: [
          _RoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: onBack),
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: l.itemMove,
              child: Material(
                color: Tokens.containerHigh,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onFolder,
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, right: 14),
                      child: Row(
                        children: [
                          // круг с тем же центром, что полукруглый край пилюли: фигура папки
                          // с углами (квадрат, пилюля) выпирала бы из него
                          Container(
                            key: const ValueKey('item-folder-badge'),
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(color: Tokens.graphite, shape: BoxShape.circle),
                            child: Icon(symbolIcon(folder?.icon ?? 'inbox', filled: true), size: 20, color: Tokens.onSurface),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            // подписи шапки растут не больше чем на четверть: иначе на крупном шрифте не влезут в 48 точек
                            child: MediaQuery.withClampedTextScaling(
                              maxScaleFactor: 1.25,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(folderName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2, color: Tokens.onSurface)),
                                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.2, color: Tokens.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (editing)
            _RoundButton(icon: 'more_vert', tooltip: l.itemMore, onTap: onMore)
          else ...[
            _RoundButton(
              icon: 'edit',
              tooltip: l.itemEdit,
              onTap: onEdit,
              radius: const BorderRadius.horizontal(left: Radius.circular(24), right: Radius.circular(8)),
            ),
            const SizedBox(width: 2),
            _RoundButton(
              icon: 'more_vert',
              tooltip: l.itemMore,
              onTap: onMore,
              radius: const BorderRadius.horizontal(left: Radius.circular(8), right: Radius.circular(24)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Пилюля тега. У «добавить» значок плюса и приглушённая подложка.
class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, this.short, this.add = false, this.onTap, this.onRemove, this.removeTooltip});

  final String label;

  /// Подпись «добавить» на пилюле, полное имя уходит в подсказку.
  final String? short;
  final bool add;
  final VoidCallback? onTap;

  /// Крестик: снять тег только у этой вещи.
  final VoidCallback? onRemove;
  final String? removeTooltip;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: add ? Tokens.muted : Tokens.onSurfaceVariant);
    final pill = Material(
      color: add ? Tokens.containerLow : Tokens.containerHigh,
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? onRemove,
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: EdgeInsets.only(left: add ? 8 : 14, right: onRemove != null ? 6 : (add ? 12 : 14)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (add) ...[Icon(symbolIcon('add'), size: 18, color: Tokens.muted), const SizedBox(width: 4)],
              Flexible(child: Text(short ?? label, overflow: TextOverflow.ellipsis, style: style)),
              if (onRemove != null) ...[const SizedBox(width: 2), Icon(symbolIcon('close'), size: 18, color: Tokens.muted)],
            ],
          ),
        ),
      ),
    );
    final tip = onRemove != null ? removeTooltip : (add ? label : null);
    return tip == null ? pill : Tooltip(message: tip, child: pill);
  }
}

/// «Вторник, 3 ноября, 20:14 · Ботаника, Кишинёв». Год — только если не нынешний.
class _WhenWhere extends StatelessWidget {
  const _WhenWhere({required this.at, required this.now, required this.place, required this.onPlace});

  final DateTime at;
  final DateTime now;
  final String? place;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final day = at.year == now.year ? DateFormat.MMMMEEEEd(l.localeName).format(at) : DateFormat.yMMMMEEEEd(l.localeName).format(at);
    final when = '${_capitalized(day)}, ${DateFormat.jm(l.localeName).format(at)}';
    const style = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3, color: Tokens.onSurfaceVariant);
    Widget part(String icon, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(symbolIcon(icon), size: 17, color: Tokens.muted),
        const SizedBox(width: 6),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        part('calendar_today', when),
        if (place != null)
          GestureDetector(
            key: const ValueKey('item-place'),
            onTap: onPlace,
            child: part('location_on', place!),
          ),
      ],
    );
  }
}

/// Напоминание светлой плашкой: заметно сразу и не путается с тегами.
class _ReminderBlock extends StatelessWidget {
  const _ReminderBlock({required this.at, required this.now, required this.onTap, required this.onChange});

  final DateTime at;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final date = _capitalized(DateFormat('EEEE, d MMMM', l.localeName).format(at));
    return Material(
      key: const ValueKey('item-reminder'),
      color: Tokens.accent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Icon(symbolIcon('alarm', filled: true), size: 24, color: Tokens.onAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_capitalized(formatReminder(l, at, now)), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Tokens.onAccent)),
                    Text(date, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Tokens.onAccentVariant)),
                  ],
                ),
              ),
              Tooltip(
                message: l.itemReminderChange,
                child: Material(
                  color: Tokens.onAccent.withValues(alpha: 0.08),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onChange,
                    child: SizedBox.square(dimension: 44, child: Icon(symbolIcon('edit_calendar'), size: 20, color: Tokens.onAccent)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Снимок на странице вещи в своих пропорциях: обрезаются только очень вытянутые.
/// Касание открывает его во весь экран.
class _PhotoCover extends StatelessWidget {
  const _PhotoCover({required this.image, required this.filesRoot, required this.onOpen});

  final Attachment image;
  final Directory filesRoot;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final path = p.join(filesRoot.path, image.path);
    final width = image.width;
    final height = image.height;
    final ratio = width != null && height != null && width > 0 ? height / width : 0.75;
    return GestureDetector(
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: AspectRatio(
          // высота к ширине от 9:16 до 5:4: длинный скриншот не съедает весь экран
          aspectRatio: 1 / ratio.clamp(0.5625, 1.25),
          child: Hero(
            tag: photoHeroTag(path),
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
              errorBuilder: (_, _, _) => const ColoredBox(color: Tokens.containerHigh),
            ),
          ),
        ),
      ),
    );
  }
}

/// Остальные снимки рядом под крупным: касание ставит снимок крупно.
class _Thumbs extends StatelessWidget {
  const _Thumbs({required this.images, required this.filesRoot, required this.selected, required this.onPick});

  final List<Attachment> images;
  final Directory filesRoot;
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => onPick(index),
          child: AnimatedOpacity(
            duration: Motion.short,
            opacity: index == selected ? 1 : 0.5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.photo),
              child: Image.file(
                File(p.join(filesRoot.path, images[index].path)),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                cacheWidth: 168,
                errorBuilder: (_, _, _) => const SizedBox.square(dimension: 56, child: ColoredBox(color: Tokens.containerHigh)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockButton {
  const _DockButton({required this.icon, required this.tooltip, required this.onTap, this.active = false});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
}

/// Плавающая панель внизу: пилюля с действиями и светлая кнопка главного шага.
/// На узком экране главная кнопка остаётся значком, подпись уходит в подсказку.
class _Dock extends StatelessWidget {
  const _Dock({super.key, required this.height, required this.buttons, required this.accentIcon, required this.accentLabel, required this.onAccent});

  final double height;
  final List<_DockButton> buttons;
  final String accentIcon;
  final String accentLabel;
  final VoidCallback onAccent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 340;
        final radius = BorderRadius.circular(height / 2);
        return Row(
          children: [
            Expanded(
              child: Container(
                height: height,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: radius),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final button in buttons)
                      Flexible(
                        child: Tooltip(
                          message: button.tooltip,
                          child: Material(
                            color: button.active ? Tokens.onSurface.withValues(alpha: 0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(28),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: button.onTap,
                              child: SizedBox(
                                width: 52,
                                height: height - 16,
                                child: Icon(symbolIcon(button.icon, filled: button.active), size: 24, color: Tokens.onSurface),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: accentLabel,
              excludeFromSemantics: wide,
              child: Material(
                color: Tokens.accent,
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onAccent,
                  child: SizedBox(
                    height: height,
                    width: wide ? null : height,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: wide ? 20 : 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(symbolIcon(accentIcon), size: 22, color: Tokens.onAccent),
                          if (wide) ...[
                            const SizedBox(width: 8),
                            MediaQuery.withClampedTextScaling(
                              maxScaleFactor: 1.2,
                              child: Text(accentLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Tokens.onAccent)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Лист «⋮»: скопировать текст и удалить. Блоки сцеплены, как в настройках.
class _ItemMenu extends StatelessWidget {
  const _ItemMenu({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    Widget row(_MenuAction action, String icon, String label, BorderRadius radius, {bool danger = false}) {
      final color = danger ? Tokens.error : Tokens.onSurface;
      return Material(
        color: Tokens.containerHigh,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.pop(context, action),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: danger ? Tokens.error.withValues(alpha: 0.14) : Tokens.graphite, shape: BoxShape.circle),
                  child: Icon(symbolIcon(icon), size: 20, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color))),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Tokens.muted)),
            ),
            row(_MenuAction.copy, 'content_copy', l.itemCopy, const BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(8))),
            const SizedBox(height: 4),
            row(_MenuAction.delete, 'delete', l.itemDelete, const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(24)), danger: true),
          ],
        ),
      ),
    );
  }
}

/// Тег одной вещи руками: имя без решётки.
class _DeepBlock extends StatelessWidget {
  const _DeepBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
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

