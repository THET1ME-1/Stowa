import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/money.dart' show formatTotal;
import '../../l10n/app_localizations.dart';
import '../folder/folder_cards.dart';
import '../folder/folder_sheets.dart' show showRenameSheet;
import '../item/item_screen.dart' show itemRoute;

Route<void> smartFolderRoute(String id) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => SmartFolderScreen(id: id),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

enum _SmartAction { rename, delete }

/// Умная папка: имя, её запрос и всё, что он находит сегодня. Заметки не лежат
/// в ней — запрос разбирается заново, поэтому «за неделю» всегда последняя неделя.
class SmartFolderScreen extends ConsumerWidget {
  const SmartFolderScreen({super.key, required this.id});

  final String id;

  Future<void> _menu(BuildContext context, WidgetRef ref, SmartFolder folder) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    Widget row(String icon, String label, _SmartAction action, {bool danger = false}) => ListTile(
      leading: Icon(symbolIcon(icon), color: danger ? Tokens.error : Tokens.onSurface),
      title: Text(label, style: TextStyle(color: danger ? Tokens.error : Tokens.onSurface)),
      onTap: () => Navigator.pop(context, action),
    );
    final action = await showModalBottomSheet<_SmartAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row('edit', l.folderRename, _SmartAction.rename),
              row('delete', l.smartDelete, _SmartAction.delete, danger: true),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final repository = ref.read(smartFoldersRepositoryProvider);
    switch (action) {
      case _SmartAction.rename:
        final name = await showRenameSheet(context, folder.name);
        if (name != null) await repository.rename(folder.id, name);
      case _SmartAction.delete:
        final removed = await repository.remove(folder.id);
        navigator.pop();
        if (removed != null) showUndo(messenger, message: l.smartDeleted(folder.name), label: l.undo, onUndo: () => repository.restore(removed));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final folder = (ref.watch(smartFoldersProvider).value ?? const <SmartFolder>[]).where((one) => one.id == id).firstOrNull;
    if (folder == null) return Scaffold(backgroundColor: Tokens.background);
    final found = ref.watch(smartResultsProvider(folder.query)).value;
    final cards = [for (final result in found?.results ?? const []) result.card];
    final filesRoot = ref.watch(filesRootProvider);
    final now = ref.watch(clockProvider)();
    return Scaffold(
      backgroundColor: Tokens.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 0),
                child: Row(
                  children: [
                    _RoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.pop(context)),
                    const Spacer(),
                    _RoundButton(icon: 'more_vert', tooltip: l.folderMore, onTap: () => _menu(context, ref, folder)),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 16, Space.screen, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: Text(folder.name, style: text.headlineMedium!.copyWith(fontSize: 26, height: 1.1, letterSpacing: -0.6))),
                    const SizedBox(width: 12),
                    if (found != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('${cards.length}', style: text.titleSmall!.copyWith(fontFamily: 'Unbounded', fontSize: 15, fontWeight: FontWeight.w600, color: Tokens.muted)),
                      ),
                  ],
                ),
              ),
            ),
            // сам запрос: видно, по какому правилу собрано
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 8, Space.screen, 18),
                child: Row(
                  children: [
                    Icon(symbolIcon('manage_search'), size: 18, color: Tokens.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Flexible(child: Text(folder.query, style: text.bodyMedium!.copyWith(fontSize: 15, color: Tokens.onSurfaceVariant))),
                  ],
                ),
              ),
            ),
            // запрос трат: «Всего 23 150 лей · €40», как на экране папки
            if (found != null && found.total.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  key: const ValueKey('smart-total'),
                  padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 16),
                  child: Text(l.folderTotal(formatTotal(found.total, l.localeName)), style: text.bodyMedium!.copyWith(fontSize: 15, color: Tokens.onSurface)),
                ),
              ),
            if (found != null && cards.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.screen, 40, Space.screen, 0),
                  child: Text(l.smartEmpty, textAlign: TextAlign.center, style: text.bodyLarge!.copyWith(color: Tokens.muted)),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 40),
              sliver: SliverList.separated(
                itemCount: cards.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    FolderItemCard(card: cards[index], filesRoot: filesRoot, now: now, onTap: () => Navigator.of(context).push(itemRoute(cards[index].id))),
              ),
            ),
          ],
        ),
      ),
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
