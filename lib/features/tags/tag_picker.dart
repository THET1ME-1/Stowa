import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/tag_tile.dart';
import '../../data/repositories/tags_repository.dart';
import '../../domain/tag_name.dart';
import '../../l10n/app_localizations.dart';

/// Выбрать тег: готовые пилюлями, частые первыми, поле сверху ищет среди них.
/// Своё имя в поле — новый тег, если [allowNew]. Снимать теги новым именем
/// бессмысленно, поэтому там поле только ищет.
Future<String?> showTagPicker(BuildContext context, {required List<TagCard> tags, required Directory filesRoot, bool allowNew = true}) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(top: false, child: _TagPicker(tags: tags, filesRoot: filesRoot, allowNew: allowNew)),
    ),
  );
}

class _TagPicker extends StatefulWidget {
  const _TagPicker({required this.tags, required this.filesRoot, required this.allowNew});

  final List<TagCard> tags;
  final Directory filesRoot;
  final bool allowNew;

  @override
  State<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<_TagPicker> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final name = normalizeTagName(_field.text);
    if (name.isEmpty) return;
    final known = widget.tags.any((tag) => tag.name == name);
    if (known || widget.allowNew) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final query = normalizeTagName(_field.text);
    final shown = [for (final tag in widget.tags) if (query.isEmpty || tag.name.contains(query)) tag];

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.tagPickTitle, style: text.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _field,
            // клавиатура закрыла бы пилюли, а чаще всего тег уже есть
            autofocus: widget.tags.isEmpty,
            decoration: InputDecoration(prefixText: '#', hintText: l.tagNameHint),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in shown)
                    Pressable(
                      onTap: () => Navigator.pop(context, tag.name),
                      child: AnimatedContainer(
                        duration: Motion.short,
                        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                        decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(100)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TagTile(kind: tag.iconKind, value: tag.iconValue, filesRoot: widget.filesRoot, size: 28),
                            const SizedBox(width: 8),
                            Text(tag.name, style: text.labelLarge!.copyWith(fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.allowNew && query.isNotEmpty && !widget.tags.any((tag) => tag.name == query)) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: _submit, child: Text(l.tagCreate(query))),
          ],
        ],
      ),
    );
  }
}
