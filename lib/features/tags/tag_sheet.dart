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
import '../../core/widgets/tag_tile.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../data/repositories/tags_repository.dart';
import '../../domain/models.dart';
import '../../domain/tag_name.dart';
import '../../l10n/app_localizations.dart';
import '../folder/folder_sheets.dart';

/// Лист тега, как экран 11 макета: новый или правка старого.
Future<void> showTagSheet(BuildContext context, {TagCard? tag, bool pin = false}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Tokens.containerLow,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      // кнопка внизу не ложится на полоску жестов
      child: SafeArea(top: false, child: TagSheet(tag: tag, pin: pin)),
    ),
  );
}

class TagSheet extends ConsumerStatefulWidget {
  const TagSheet({super.key, this.tag, this.pin = false});

  final TagCard? tag;
  final bool pin;

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
    // своя картинка лежит в папке приложения, путь от неё
    final relative = p.join('tags', '${const Uuid().v4()}${p.extension(picked.path)}');
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

  Future<void> _newFolder() async {
    final name = await showRenameSheet(context, '');
    if (name == null) return;
    final folder = await ref.read(foldersRepositoryProvider).create(name);
    setState(() => _folderId = folder.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final folders = ref.watch(foldersProvider).value ?? const [];
    final filesRoot = ref.watch(filesRootProvider);
    // по-русски («машина», «кофе») и по английским именам
    final icons = _query.trim().isEmpty ? pickableSymbols : searchIcons(_query);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
        children: [
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
          const SizedBox(height: 20),
          _Label(l.tagToFolder),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Choice(label: l.folderNone, on: _folderId == null, onTap: () => setState(() => _folderId = null)),
              for (final folder in folders)
                _Choice(icon: folder.icon, label: folder.name, on: _folderId == folder.id, onTap: () => setState(() => _folderId = folder.id)),
              _Choice(icon: 'add', label: l.shareNewFolder, on: false, onTap: _newFolder),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.tagPin),
            value: _pinned,
            onChanged: (value) => setState(() => _pinned = value),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: normalizeTagName(_name.text).isEmpty ? null : _save,
            child: Text(widget.tag == null ? l.tagCreateButton : l.save),
          ),
          if (widget.tag != null) ...[
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Tokens.error),
              onPressed: _delete,
              child: Text(l.tagDelete),
            ),
          ],
        ],
      ),
    );
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

/// Чип выбора: белый — выбран.
class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.on, required this.onTap, this.icon});

  final String label;
  final String? icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = on ? Tokens.onAccent : Tokens.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.short,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: on ? Tokens.accent : Tokens.containerHigh, borderRadius: BorderRadius.circular(18)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(symbolIcon(icon), size: 18, color: color), const SizedBox(width: 6)],
            Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}
