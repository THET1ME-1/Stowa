import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/database.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';

/// Минуты чтения статьи, если у ссылки есть её текст; нет — null.
int? articleMinutes(List<Fact> facts) {
  final fact = facts.where((one) => one.kind == FactKind.articleText).firstOrNull;
  return fact == null ? null : int.tryParse(fact.detail ?? '') ?? 1;
}

/// «Читать · 7 мин» под карточкой ссылки.
class ReadButton extends StatelessWidget {
  const ReadButton({super.key, required this.minutes, required this.onTap});

  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(backgroundColor: Tokens.accent, foregroundColor: Tokens.onAccent, shape: const StadiumBorder()),
        icon: Icon(symbolIcon('chrome_reader_mode'), size: 20),
        label: Text(L.of(context).readerOpen(minutes), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Цитаты статьи на странице заметки: подсвеченный текст и пометка под ним.
/// Касание открывает читалку на этой цитате.
class HighlightsBlock extends StatelessWidget {
  const HighlightsBlock({super.key, required this.highlights, required this.onOpen});

  final List<Highlight> highlights;
  final void Function(Highlight highlight) onOpen;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final marker = FolderPalette.colors['lemon']!;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(symbolIcon('format_quote'), size: 20, color: marker),
              const SizedBox(width: 8),
              Text(l.highlightsTitle, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text('${highlights.length}', style: TextStyle(fontSize: 13, color: Tokens.muted)),
            ],
          ),
          const SizedBox(height: 8),
          for (final one in highlights)
            InkWell(
              onTap: () => onOpen(one),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(text: one.quote, style: TextStyle(backgroundColor: marker, color: Tokens.onAccent)),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                    if (one.note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(one.note!, style: TextStyle(fontSize: 14, height: 1.4, color: Tokens.onSurfaceVariant)),
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
