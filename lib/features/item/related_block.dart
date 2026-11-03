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

/// Значок вещи без картинки по её виду.
String kindIcon(ItemKind kind) => switch (kind) {
  ItemKind.note => 'notes',
  ItemKind.link => 'link',
  ItemKind.video => 'play_arrow',
  ItemKind.image => 'image',
  ItemKind.file => 'description',
  ItemKind.voice => 'graphic_eq',
};

/// «Связано» внизу страницы вещи: похожие по редким словам или сайту, с причиной.
/// Крестик говорит «не связаны», и пара больше не предлагается.
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
            child: Text(l.relatedTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Tokens.muted)),
          ),
          for (final (index, (:card, :why)) in related.indexed) ...[
            if (index > 0) const SizedBox(height: 3),
            _RelatedRow(
              card: card,
              why: why,
              filesRoot: filesRoot,
              // блоки сцеплены: крупные углы только снаружи группы
              radius: BorderRadius.vertical(
                top: Radius.circular(index == 0 ? 24 : 8),
                bottom: Radius.circular(index == related.length - 1 ? 24 : 8),
              ),
              onOpen: () => onOpen(card.id),
              onHide: () async {
                final messenger = ScaffoldMessenger.of(context);
                final items = ref.read(itemsRepositoryProvider);
                await items.rejectRelated(itemId, card.id);
                showUndo(messenger, message: l.relatedHidden, label: l.undo, onUndo: () => items.restoreRelated(itemId, card.id), overDock: true);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RelatedRow extends StatelessWidget {
  const _RelatedRow({required this.card, required this.why, required this.filesRoot, required this.radius, required this.onOpen, required this.onHide});

  final ItemCard card;
  final Related why;
  final Directory filesRoot;
  final BorderRadius radius;
  final VoidCallback onOpen;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final thumb = card.thumbPath;
    final site = card.url == null ? '' : (Uri.tryParse(card.url!)?.host ?? '').replaceFirst(RegExp(r'^www\.'), '');
    final reason = why.words.isNotEmpty ? l.relatedWords(why.words.join(', ')) : l.relatedSite(site);
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
                      ? Image.file(
                          File(p.join(filesRoot.path, thumb)),
                          fit: BoxFit.cover,
                          cacheWidth: (44 * MediaQuery.devicePixelRatioOf(context)).round(),
                          errorBuilder: (_, _, _) => const ColoredBox(color: Tokens.containerHighest),
                        )
                      : ColoredBox(color: Tokens.containerHighest, child: Icon(symbolIcon(kindIcon(card.kind)), size: 22, color: Tokens.onSurface)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Tokens.onSurface)),
                    const SizedBox(height: 2),
                    Text(reason, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Tokens.onSurfaceVariant)),
                  ],
                ),
              ),
              Tooltip(
                message: l.relatedHide,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onHide,
                    child: SizedBox.square(dimension: 44, child: Icon(symbolIcon('close'), size: 20, color: Tokens.muted)),
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
