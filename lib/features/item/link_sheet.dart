import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/sheet_options.dart';
import '../../data/providers.dart';
import '../../domain/note_blocks.dart' show renderMarkup;
import '../../domain/note_links.dart';
import '../../l10n/app_localizations.dart';
import 'related_block.dart' show kindIcon;

/// «+ Связь»: лист с поиском заметки по словам из заголовка и текста. Выбранная — или null.
Future<LinkTarget?> pickLinkTarget(BuildContext context, WidgetRef ref, {required String exceptId}) async {
  final targets = await ref.read(itemsRepositoryProvider).linkTargets();
  if (!context.mounted) return null;
  return showOptionsSheetWith<LinkTarget>(context, (sheet) => _LinkSheet(targets: targets, exceptId: exceptId));
}

class _LinkSheet extends StatefulWidget {
  const _LinkSheet({required this.targets, required this.exceptId});

  final List<LinkTarget> targets;
  final String exceptId;

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final found = rankLinkTargets(_query, widget.targets, except: widget.exceptId, limit: 30);
    return KeyedSubtree(
      key: const ValueKey('link-sheet'),
      child: SheetOptionsBody(
        title: l.linkAdd,
        top: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('link-search'),
              autofocus: true,
              decoration: InputDecoration(prefixIcon: Icon(symbolIcon('search')), hintText: l.linkSearchHint),
              onChanged: (value) => setState(() => _query = value),
            ),
            if (found.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: Text(l.linkNone, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Tokens.muted)),
              ),
          ],
        ),
        children: [
          for (final target in found)
            SheetOption(
              key: ValueKey('link-${target.id}'),
              title: target.title.trim().isEmpty ? '…' : target.title,
              subtitle: _snippet(target),
              icon: kindIcon(target.kind),
              onTap: () => Navigator.pop(context, target),
            ),
        ],
      ),
    );
  }
}

/// Начало текста под заголовком: без первой строки, если она и есть заголовок.
String? _snippet(LinkTarget target) {
  final lines = target.text.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
  if (lines.isNotEmpty && lines.first == target.title.trim()) lines.removeAt(0);
  // разметка снимается, как в карточках: галочки знаками, [[ссылки]] названиями
  final text = renderMarkup(lines.join('\n'), const []).text.split('\n').where((line) => line.trim().isNotEmpty).join(' ');
  return text.isEmpty ? null : text;
}

/// То же начало текста — для подсказки при наборе `[[`.
String? linkSnippet(LinkTarget target) => _snippet(target);
