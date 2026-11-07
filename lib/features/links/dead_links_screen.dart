import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/item_kind.dart' show sourceName;
import '../../l10n/app_localizations.dart';
import '../item/item_screen.dart';

Route<void> deadLinksRoute() => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => const DeadLinksScreen(),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

/// Битые ссылки: сайт удалил страницу или закрылся. Решить по каждой —
/// оставить заметку с копией или удалить в корзину. «Проверить сейчас» не ждёт недели.
class DeadLinksScreen extends ConsumerStatefulWidget {
  const DeadLinksScreen({super.key});

  @override
  ConsumerState<DeadLinksScreen> createState() => _DeadLinksScreenState();
}

class _DeadLinksScreenState extends ConsumerState<DeadLinksScreen> {
  var _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      await ref.read(linkCheckerProvider).run(force: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _delete(ItemCard card) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final items = ref.read(itemsRepositoryProvider);
    await items.softDelete(card.id, ref.read(clockProvider)());
    showUndo(messenger, message: l.deadLinksDeleted, label: l.undo, onUndo: () => items.restore(card.id));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final links = ref.watch(deadLinksProvider).value ?? const <ItemCard>[];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: Tokens.containerHigh, fixedSize: const Size.square(48)),
                  icon: Icon(symbolIcon('arrow_back'), size: 22, color: Tokens.onSurface),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(l.deadLinksTitle, style: text.titleLarge!.copyWith(fontSize: 18))),
              ],
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(l.deadLinksAbout, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                onPressed: _checking ? null : _check,
                icon: _checking
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Tokens.onSurfaceVariant))
                    : Icon(symbolIcon('refresh'), size: 18),
                label: Text(_checking ? l.deadLinksChecking : l.deadLinksCheck),
              ),
            ),
            const SizedBox(height: 18),
            if (links.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
                      child: Icon(symbolIcon('link'), size: 32, color: Tokens.muted),
                    ),
                    const SizedBox(height: 16),
                    Text(l.deadLinksEmpty, style: text.titleMedium!.copyWith(color: Tokens.onSurfaceVariant)),
                  ],
                ),
              ),
            for (final card in links)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DeadRow(
                  card: card,
                  onOpen: () => Navigator.of(context).push(itemRoute(card.id)),
                  onKeep: () => ref.read(itemsRepositoryProvider).keepDeadLink(card.id),
                  onDelete: () => _delete(card),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeadRow extends StatelessWidget {
  const _DeadRow({required this.card, required this.onOpen, required this.onKeep, required this.onDelete});

  final ItemCard card;
  final VoidCallback onOpen;
  final VoidCallback onKeep;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final host = Uri.tryParse(card.url ?? '')?.host ?? '';
    return Material(
      color: Tokens.container,
      borderRadius: BorderRadius.circular(Radii.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
              const SizedBox(height: 4),
              Text(sourceName(host), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: Tokens.muted)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(symbolIcon('link_off'), size: 16, color: Tokens.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(child: Text(card.hasCopy ? l.readerGone : l.linkGone, style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant))),
                  TextButton(onPressed: onKeep, child: Text(l.deadLinksKeep)),
                  TextButton(onPressed: onDelete, style: TextButton.styleFrom(foregroundColor: Tokens.error), child: Text(l.deadLinksDelete)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
