import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pill_segments.dart';
import '../../core/icons/icon_words.dart';
import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/tag_tile.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/tags_repository.dart';
import '../../domain/models.dart';
import '../../domain/tag_name.dart';
import '../../l10n/app_localizations.dart';
import '../../services/vault/vault_layout.dart';
import '../composer/line_dock.dart' show FolderPickerSheet;
import '../folder/folder_sheets.dart';
import '../graph/graph_screen.dart';
import '../settings/settings_blocks.dart';
import 'rule_sheet.dart' show SheetDeleteButton;
import 'tag_search.dart';

/// Лист тега, как экран 11 макета: новый или правка старого.
Future<void> showTagSheet(BuildContext context, {TagCard? tag, bool pin = false}) {
  // «Заметки с #тег» уходит от экрана, открывшего лист: окно на мониторе вкладок не видит
  void notes(String name) => showTagNotes(context, name);
  // кнопка внизу не ложится на полоску жестов: шторка сама держит безопасную зону
  return showStowaSheet<void>(context, backgroundColor: Tokens.containerLow, maxHeightFactor: null, builder: (context) => TagSheet(tag: tag, pin: pin, onNotes: notes));
}

class TagSheet extends ConsumerStatefulWidget {
  const TagSheet({super.key, this.tag, this.pin = false, this.onNotes});

  final TagCard? tag;
  final bool pin;

  /// Показать заметки с тегом на главной; лист перед этим закрывается.
  final ValueChanged<String>? onNotes;

  @override
  ConsumerState<TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends ConsumerState<TagSheet> {
  late final _name = TextEditingController(text: widget.tag?.name ?? '');
  late TagIconKind _kind = widget.tag?.iconKind ?? TagIconKind.symbol;
  late String _value = widget.tag?.iconValue ?? 'label';
  late bool _pinned = widget.tag?.pinned ?? widget.pin;
  String? _folderId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final tag = widget.tag;
    if (tag != null) {
      ref.read(rulesRepositoryProvider).tagFolder(tag.name).then((folderId) {
        if (mounted) setState(() => _folderId = folderId);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 256, maxHeight: 256);
    if (picked == null) return;
    // своя картинка лежит в служебной папке хранилища, путь от корня
    final relative = tagIconFile('${const Uuid().v4()}${p.extension(picked.path)}');
    final target = File(p.join(ref.read(filesRootProvider).path, relative));
    await target.parent.create(recursive: true);
    await File(picked.path).copy(target.path);
    if (mounted) {
      setState(() {
        _kind = TagIconKind.image;
        _value = relative;
      });
    }
  }

  Future<void> _save() async {
    final name = normalizeTagName(_name.text);
    if (name.isEmpty) return;
    final tags = ref.read(tagsRepositoryProvider);
    final old = widget.tag;
    if (old == null) {
      await tags.create(name: name, iconKind: _kind, iconValue: _value, pinned: _pinned);
    } else {
      await tags.update(old.id, name: name, iconKind: _kind, iconValue: _value, pinned: _pinned);
    }
    await ref.read(rulesRepositoryProvider).setTagFolder(name, _folderId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final tag = widget.tag!;
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tags = ref.read(tagsRepositoryProvider);
    final snapshot = await tags.delete(tag.id);
    if (mounted) Navigator.pop(context);
    showUndo(messenger, message: l.tagDeleted(tag.name), label: l.restoreAction, onUndo: () => tags.restore(snapshot));
  }

  /// «Класть в папку» — тем же окном, что «Переложить»: «Не класть» первой строкой, «Новая папка» внизу.
  Future<void> _pickFolder() async {
    final l = L.of(context);
    final folders = ref.read(foldersProvider).value ?? const <FolderCard>[];
    final picked = await showOptionsSheetWith<FolderCard>(
      context,
      (sheet) => FolderPickerSheet(title: l.tagFolderRow, folders: folders, allowNone: true, noneLabel: l.tagFolderNone, onNew: () => askNewFolder(sheet, ref)),
    );
    if (picked == null || !mounted) return;
    setState(() => _folderId = identical(picked, FolderPickerSheet.none) ? null : picked.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 12),
              children: _fields(l),
            ),
          ),
          // кнопка всегда на виду: раньше она была под сеткой значков, до неё листали
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, 4, Space.screen, Space.screen),
            child: Row(
              children: [
                if (widget.tag != null) ...[
                  SheetDeleteButton(tooltip: l.tagDelete, onTap: _delete),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: normalizeTagName(_name.text).isEmpty ? null : _save,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: Text(widget.tag == null ? l.tagCreateButton : l.save),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Имя, значок, папка, закрепление и граф — всё, что листается над кнопкой.
  List<Widget> _fields(L l) {
    final text = Theme.of(context).textTheme;
    final folders = ref.watch(foldersProvider).value ?? const <FolderCard>[];
    final folder = folders.where((one) => one.id == _folderId).firstOrNull;
    final filesRoot = ref.watch(filesRootProvider);
    // по-русски («машина», «кофе») и по английским именам
    final icons = _query.trim().isEmpty ? pickableSymbols : searchIcons(_query);
    return [
      Row(
        children: [
          TagTile(kind: _kind, value: _value, filesRoot: filesRoot, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.tag == null ? l.tagNew : l.tagEdit, style: text.labelMedium!.copyWith(color: Tokens.muted)),
                TextField(
                  controller: _name,
                  autofocus: widget.tag == null,
                  style: text.titleLarge!.copyWith(fontFamily: 'Unbounded', fontWeight: FontWeight.w700, fontSize: 22),
                  decoration: InputDecoration.collapsed(hintText: l.tagNameHint),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      // папка тега — это правило «есть тег → в папку»: так и сказано под строкой
      SettingsGroup(
        tint: Tokens.onSurface,
        children: [
          SettingsRow(key: const ValueKey('tag-folder'), icon: folder?.icon ?? 'folder_off', title: l.tagFolderRow, value: folder?.name ?? l.tagFolderNone, onTap: _pickFolder),
          SettingsSwitchRow(icon: 'keep', title: l.tagPin, subtitle: l.tagPinHint, value: _pinned, onChanged: (value) => setState(() => _pinned = value)),
        ],
      ),
      if (folder != null) SettingsHint(l.tagFolderHint),
      // заметки с тегом — на главной поиском по нему (STOWA-10)
      if ((widget.tag, widget.onNotes) case (final tag?, final notes?) when tag.count > 0) ...[
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          key: const ValueKey('tag-notes'),
          onPressed: () {
            Navigator.pop(context);
            notes(tag.name);
          },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: Tokens.containerHigh, foregroundColor: Tokens.onSurface),
          icon: Icon(symbolIcon('search')),
          label: Text(l.tagShowNotes(tag.name)),
        ),
      ],
      if (widget.tag case final tag? when tag.count > 1) ...[
        const SizedBox(height: 8),
        // все вещи с тегом и как они связаны
        OutlinedButton.icon(
          onPressed: () {
            final navigator = Navigator.of(context)..pop();
            navigator.push(graphRoute(tag: tag.name, title: '#${tag.name}'));
          },
          icon: Icon(symbolIcon('hub')),
          label: Text(l.graphTitle),
        ),
      ],
      const SizedBox(height: 20),
      _Label(l.lookIcon),
      PillSegments<TagIconKind>(
        height: 36,
        options: [
          (value: TagIconKind.symbol, label: l.iconSymbols, icon: null),
          (value: TagIconKind.emoji, label: l.iconEmoji, icon: null),
          (value: TagIconKind.image, label: l.iconImage, icon: null),
        ],
        selected: _kind,
        onChanged: (kind) {
          setState(() {
            _kind = kind;
            _value = switch (kind) {
              TagIconKind.symbol => hasSymbol(_value) ? _value : 'label',
              TagIconKind.emoji => '🏷️',
              TagIconKind.image => _value,
            };
          });
          if (kind == TagIconKind.image) _pickImage();
        },
      ),
      const SizedBox(height: 12),
      if (_kind == TagIconKind.symbol) ...[
        TextField(
          decoration: InputDecoration(prefixIcon: Icon(symbolIcon('search')), hintText: l.iconSearch),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (final name in icons)
              GestureDetector(
                onTap: () => setState(() => _value = name),
                child: AnimatedContainer(
                  duration: Motion.short,
                  decoration: BoxDecoration(color: name == _value ? Tokens.accent : Tokens.containerHigh, borderRadius: BorderRadius.circular(14)),
                  child: Icon(symbolIcon(name, filled: name == _value), color: name == _value ? Tokens.onAccent : Tokens.onSurface),
                ),
              ),
          ],
        ),
      ] else if (_kind == TagIconKind.emoji)
        TextField(
          decoration: InputDecoration(hintText: l.emojiHint),
          style: const TextStyle(fontSize: 28),
          onChanged: (value) {
            final emoji = value.characters.isEmpty ? '' : value.characters.last;
            if (emoji.isNotEmpty) setState(() => _value = emoji);
          },
        )
      else
        OutlinedButton.icon(onPressed: _pickImage, icon: Icon(symbolIcon('image')), label: Text(l.iconPickImage)),
    ];
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: Tokens.muted)),
    );
  }
}
