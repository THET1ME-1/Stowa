import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../domain/note_links.dart';
import '../../l10n/app_localizations.dart';
import '../item/link_sheet.dart' show linkSnippet;
import '../item/related_block.dart' show kindIcon;

/// Подсказка при наборе `[[…`: до пяти заметок по словам набранного, касание ставит заголовок.
/// Строка: значок вида, заголовок, под ним начало текста. Пусто — «Такой заметки нет».
class WikiSuggestions extends StatelessWidget {
  const WikiSuggestions({super.key, required this.query, required this.targets, this.exceptId, required this.onPick});

  final String query;
  final List<LinkTarget> targets;
  final String? exceptId;
  final ValueChanged<LinkTarget> onPick;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final found = rankLinkTargets(query, targets, except: exceptId);
    return Material(
      key: const ValueKey('wiki-suggestions'),
      color: Tokens.containerHigh,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: found.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(L.of(context).linkNone, style: text.bodyMedium!.copyWith(color: Tokens.muted)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final target in found)
                  InkWell(
                    key: ValueKey('wiki-${target.id}'),
                    onTap: () => onPick(target),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: Tokens.graphite, shape: BoxShape.circle),
                            child: Icon(symbolIcon(kindIcon(target.kind)), size: 17, color: Tokens.onSurface),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(target.title.trim().isEmpty ? '…' : target.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Tokens.onSurface)),
                                if (linkSnippet(target) case final snippet?)
                                  Text(snippet, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: Tokens.muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
