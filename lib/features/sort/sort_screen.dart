import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion_bits.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/shape_badge.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../l10n/app_localizations.dart';
import '../folder/folder_cards.dart';
import '../item/item_screen.dart';

Route<void> sortRoute() => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => const SortScreen(),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

/// «Разобрать»: всё, что без папки, по одной карточке. Касание папки кладёт туда,
/// свайп вниз пропускает. Первые три папки — подсказки по словам.
class SortScreen extends ConsumerStatefulWidget {
  const SortScreen({super.key});

  @override
  ConsumerState<SortScreen> createState() => _SortScreenState();
}

class _SortScreenState extends ConsumerState<SortScreen> {
  final _skipped = <String>{};

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final cards = (ref.watch(folderItemsProvider(null)).value ?? const []).where((card) => !_skipped.contains(card.id)).toList();
    final folders = ref.watch(foldersProvider).value ?? const [];
    final index = ref.watch(folderIndexProvider).value;
    final filesRoot = ref.watch(filesRootProvider);
    final now = ref.read(clockProvider)();
    final card = cards.firstOrNull;

    // подсказки первыми, потом остальные папки
    final hints = card == null || index == null ? const <String>[] : index.rank('${card.title} ${card.body} ${card.tags.join(' ')}').take(3).toList();
    final ordered = [
      for (final id in hints) ?folders.where((folder) => folder.id == id).firstOrNull,
      ...folders.where((folder) => !hints.contains(folder.id)),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(backgroundColor: Tokens.containerHigh, fixedSize: const Size.square(44)),
                    icon: Icon(symbolIcon('close'), color: Tokens.onSurface),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(card == null ? l.sortDone : l.sortLeft(cards.length), style: text.titleLarge!.copyWith(fontFamily: 'Unbounded', fontWeight: FontWeight.w700, fontSize: 20)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: card == null
                  ? Center(child: Icon(symbolIcon('task_alt'), size: 64, color: Tokens.muted))
                  : Padding(
                      padding: const EdgeInsets.all(Space.screen),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        reverseDuration: const Duration(milliseconds: 180),
                        switchInCurve: Motion.spatial,
                        switchOutCurve: Motion.emphasizedAccelerate.flipped,
                        transitionBuilder: riseTransition,
                        child: Dismissible(
                          key: ValueKey(card.id),
                          direction: DismissDirection.down,
                          onDismissed: (_) => setState(() => _skipped.add(card.id)),
                          child: Center(
                            child: SingleChildScrollView(
                              child: FolderItemCard(card: card, filesRoot: filesRoot, now: now, onTap: () => Navigator.of(context).push(itemRoute(card.id))),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            if (card != null) ...[
              Text(l.sortHint, textAlign: TextAlign.center, style: text.bodySmall!.copyWith(color: Tokens.muted)),
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                  itemCount: ordered.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, position) => _FolderButton(
                    folder: ordered[position],
                    hinted: position < hints.length,
                    onTap: () => ref.read(itemsRepositoryProvider).moveToFolder(card.id, ordered[position].id, ref.read(clockProvider)()),
                  ),
                ),
              ),
              TextButton(onPressed: () => setState(() => _skipped.add(card.id)), child: Text(l.sortSkip)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Кнопка папки внизу: значок и имя; подсказка — белая.
class _FolderButton extends StatelessWidget {
  const _FolderButton({required this.folder, required this.hinted, required this.onTap});

  final FolderCard folder;
  final bool hinted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = hinted ? Tokens.onAccent : Tokens.onSurface;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.92,
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: hinted ? Tokens.accent : Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.tile)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShapeBadge(
              shape: BadgeShape.values.asNameMap()[folder.shape] ?? BadgeShape.squircle,
              size: 36,
              color: hinted ? Tokens.graphite : Tokens.containerHighest,
              child: Icon(symbolIcon(folder.icon), size: 18, color: Tokens.onSurface),
            ),
            const SizedBox(height: 6),
            Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
