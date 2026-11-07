import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../data/repositories/trash_repository.dart';
import '../../l10n/app_localizations.dart';
import '../composer/panel_text.dart';
import '../item/adult_veil.dart';

Route<void> trashRoute() => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => const TrashScreen(),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

/// Корзина: удалённое лежит 30 дней. Вернуть одним касанием, стереть — смахнуть влево.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  Future<void> _purgeAll(BuildContext context, WidgetRef ref, int count) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.trashPurgeAllAsk(count), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Tokens.error, foregroundColor: Tokens.onError),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.trashPurgeAll),
              ),
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
            ],
          ),
        ),
      ),
    );
    if (yes != true) return;
    await ref.read(trashRepositoryProvider).purgeAll();
    showNote(messenger, l.trashPurged);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final entries = ref.watch(trashProvider).value ?? const <TrashEntry>[];
    final filesRoot = ref.watch(filesRootProvider);
    final now = ref.read(clockProvider)();
    final trash = ref.read(trashRepositoryProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            Row(
              children: [
                _RoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Expanded(child: Text(l.trashTitle, style: text.titleLarge!.copyWith(fontSize: 18))),
                if (entries.isNotEmpty) _RoundButton(icon: 'delete_sweep', tooltip: l.trashPurgeAll, onTap: () => _purgeAll(context, ref, entries.length)),
              ],
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(l.trashHint, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
                      child: Icon(symbolIcon('delete'), size: 32, color: Tokens.muted),
                    ),
                    const SizedBox(height: 16),
                    Text(l.trashEmpty, style: text.titleMedium!.copyWith(color: Tokens.onSurfaceVariant)),
                  ],
                ),
              ),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Dismissible(
                  key: ValueKey('trash-${entry.id}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) async {
                    final messenger = ScaffoldMessenger.of(context);
                    await trash.purge(entry.id);
                    showNote(messenger, l.trashPurged);
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(color: Tokens.error, borderRadius: BorderRadius.circular(Radii.tile)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.trashPurge, style: text.labelLarge!.copyWith(color: Tokens.onError)),
                        const SizedBox(width: 8),
                        Icon(symbolIcon('delete_forever'), color: Tokens.onError),
                      ],
                    ),
                  ),
                  child: _TrashRow(
                    entry: entry,
                    filesRoot: filesRoot,
                    daysLeft: trashKeep.inDays - now.difference(entry.deletedAt).inDays,
                    onRestore: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await trash.restore(entry.id);
                      showNote(messenger, l.trashRestored(entry.title));
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrashRow extends StatelessWidget {
  const _TrashRow({required this.entry, required this.filesRoot, required this.daysLeft, required this.onRestore});

  final TrashEntry entry;
  final Directory filesRoot;
  final int daysLeft;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final thumb = entry.thumbPath;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.tile)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox.square(
              dimension: 52,
              child: thumb != null
                  ? AdultVeil(
                      itemId: entry.id,
                      compact: true,
                      child: Image.file(File(p.join(filesRoot.path, thumb)), fit: BoxFit.cover, cacheWidth: 156, errorBuilder: (_, _, _) => _KindMark(entry: entry)),
                    )
                  : _KindMark(entry: entry),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title.isEmpty ? '…' : entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  [if (entry.folderName != null) l.trashFrom(entry.folderName!), l.trashDaysLeft(daysLeft.clamp(0, 30))].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(color: Tokens.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: l.restoreAction,
            child: Pressable(
              onTap: onRestore,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(100)),
                child: Text(l.restoreAction, style: text.labelLarge!.copyWith(color: Tokens.onAccent)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KindMark extends StatelessWidget {
  const _KindMark({required this.entry});

  final TrashEntry entry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Tokens.graphite,
      child: Icon(symbolIcon(kindIcon(entry.kind)), color: Tokens.onSurfaceVariant),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        pressedScale: 0.9,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
          child: Icon(symbolIcon(icon), color: Tokens.onSurface),
        ),
      ),
    );
  }
}
