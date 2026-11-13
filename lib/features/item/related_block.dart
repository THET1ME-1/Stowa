import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/models.dart';
import '../../domain/related.dart';
import '../../l10n/app_localizations.dart';
import 'adult_veil.dart';

/// Значок вещи без картинки по её виду.
String kindIcon(ItemKind kind) => switch (kind) {
  ItemKind.note => 'notes',
  ItemKind.link => 'link',
  ItemKind.video => 'play_arrow',
  ItemKind.image => 'image',
  ItemKind.file => 'description',
  ItemKind.voice => 'graphic_eq',
};

/// «Связано» внизу страницы вещи: из текста (`[[…]]`), обратные, ручные, от ИИ и похожие
/// по редким словам или сайту — с причиной. Крестик у ручной убирает связь, у ИИ и похожих
/// говорит «не связаны», и пара больше не предлагается. У связи из текста крестика нет: её держит текст.
class RelatedBlock extends ConsumerWidget {
  const RelatedBlock({super.key, required this.itemId, required this.onOpen});

  final String itemId;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final related = ref.watch(relatedProvider(itemId)).value ?? const [];
    if (related.isEmpty) return const SizedBox.shrink();
    final filesRoot = ref.watch(filesRootProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(l.relatedTitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Tokens.muted)),
          ),
          for (final (index, linked) in related.indexed) ...[
            if (index > 0) const SizedBox(height: 3),
            _RelatedRow(
              card: linked.card,
              reason: _reason(l, linked),
              filesRoot: filesRoot,
              // блоки сцеплены: крупные углы только снаружи группы
              radius: BorderRadius.vertical(
                top: Radius.circular(index == 0 ? 24 : 8),
                bottom: Radius.circular(index == related.length - 1 ? 24 : 8),
              ),
              onOpen: () => onOpen(linked.card.id),
              hideTooltip: linked.kind == LinkKind.manual ? l.relatedUnlink : l.relatedHide,
              onHide: switch (linked.kind) {
                LinkKind.text || LinkKind.backlink => null,
                LinkKind.manual => () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final items = ref.read(itemsRepositoryProvider);
                  await items.unlink(itemId, linked.card.id);
                  showUndo(messenger, message: l.relatedUnlinked, label: l.undo, onUndo: () => items.link(itemId, linked.card.id), overDock: true);
                },
                LinkKind.ai || LinkKind.similar => () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final items = ref.read(itemsRepositoryProvider);
                  await items.rejectRelated(itemId, linked.card.id);
                  showUndo(messenger, message: l.relatedHidden, label: l.undo, onUndo: () => items.restoreRelated(itemId, linked.card.id), overDock: true);
                },
              },
            ),
          ],
        ],
      ),
    );
  }
}

// почему связано: одной строкой под заголовком
String _reason(L l, LinkedNote linked) {
  final card = linked.card;
  return switch (linked.kind) {
    LinkKind.text => l.relatedInText,
    LinkKind.backlink => l.relatedBacklink,
    LinkKind.manual => l.relatedManual,
    LinkKind.ai => linked.reason == null || linked.reason!.trim().isEmpty ? l.relatedAiPlain : l.relatedAi(linked.reason!.trim()),
    LinkKind.similar => switch (linked.why) {
      Related(:final words) when words.isNotEmpty => l.relatedWords(words.join(', ')),
      _ => l.relatedSite(card.url == null ? '' : (Uri.tryParse(card.url!)?.host ?? '').replaceFirst(RegExp(r'^www\.'), '')),
    },
  };
}

class _RelatedRow extends StatelessWidget {
  const _RelatedRow({required this.card, required this.reason, required this.filesRoot, required this.radius, required this.onOpen, required this.hideTooltip, required this.onHide});

  final ItemCard card;
  final String reason;
  final Directory filesRoot;
  final BorderRadius radius;
  final VoidCallback onOpen;
  final String hideTooltip;

  /// null — связь держит текст, крестика нет.
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    final thumb = card.thumbPath;
    return Material(
      color: Tokens.container,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox.square(
                  dimension: 44,
                  child: thumb != null
                      ? AdultVeil(
                          itemId: card.id,
                          compact: true,
                          child: Image.file(
                            File(p.join(filesRoot.path, thumb)),
                            fit: BoxFit.cover,
                            cacheWidth: (44 * MediaQuery.devicePixelRatioOf(context)).round(),
                            errorBuilder: (_, _, _) => ColoredBox(color: Tokens.containerHighest),
                          ),
                        )
                      : ColoredBox(color: Tokens.containerHighest, child: Icon(symbolIcon(kindIcon(card.kind)), size: 22, color: Tokens.onSurface)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Tokens.onSurface)),
                    const SizedBox(height: 2),
                    Text(reason, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Tokens.onSurfaceVariant)),
                  ],
                ),
              ),
              if (onHide != null)
                Tooltip(
                  message: hideTooltip,
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onHide,
                      child: SizedBox.square(dimension: 44, child: Icon(symbolIcon('close'), size: 20, color: Tokens.muted)),
                    ),
                  ),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
