import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../domain/note_links.dart';
import '../../l10n/app_localizations.dart';
import '../item/link_sheet.dart' show linkSnippet;
import '../item/related_block.dart' show kindIcon;

/// Подсказка при наборе `[[…`: до пяти заметок по словам набранного, касание ставит заголовок.
/// Строка: значок вида, заголовок, под ним начало текста. Заметки с набранным названием нет —
/// последней строкой «Создать заметку «…»» ([onCreate]); без него и без найденного — «Такой заметки нет».
/// Выше [maxHeight] не растёт, остальное прокручивается внутри.
class WikiSuggestions extends StatelessWidget {
  const WikiSuggestions({super.key, required this.query, required this.targets, this.exceptId, required this.onPick, this.onCreate, this.maxHeight = double.infinity});

  final String query;
  final List<LinkTarget> targets;
  final String? exceptId;
  final ValueChanged<LinkTarget> onPick;
  final ValueChanged<String>? onCreate;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final found = rankLinkTargets(query, targets, except: exceptId);
    final title = query.trim();
    final exact = targets.any((target) => target.id != exceptId && shownTitle(target.title).trim().toLowerCase() == title.toLowerCase());
    final create = onCreate != null && title.isNotEmpty && !exact;
    return Material(
      key: const ValueKey('wiki-suggestions'),
      // светлее карточки текста, как полоса разметки: видно, что это поверх заметки
      color: Tokens.containerHighest,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: found.isEmpty && !create
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(l.linkNone, style: text.bodyMedium!.copyWith(color: Tokens.muted)),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: Column(
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
                                Text(target.title.trim().isEmpty ? '…' : shownTitle(target.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Tokens.onSurface)),
                                if (linkSnippet(target) case final snippet?)
                                  Text(snippet, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: Tokens.muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // ссылка на то, чего ещё нет: заметка заводится сразу, как в Obsidian
                if (create)
                  InkWell(
                    key: const ValueKey('wiki-create'),
                    onTap: () => onCreate!(title),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: Tokens.accent, shape: BoxShape.circle),
                            child: Icon(symbolIcon('add'), size: 18, color: inkOn(Tokens.accent)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(l.linkCreate(title), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Tokens.onSurface)),
                          ),
                        ],
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
