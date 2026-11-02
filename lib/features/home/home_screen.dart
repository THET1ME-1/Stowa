import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/shape_badge.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../composer/line_dock.dart';
import '../item/item_screen.dart';
import 'folders_grid.dart';
import 'next_reminder_card.dart';
import 'pinned_tags_row.dart';
import 'recent_strip.dart';
import 'section_header.dart';

/// Место под свёрнутую строку внизу ленты, чтобы последняя плитка не пряталась.
const _dockSpace = 150.0;

/// Главная: закреплённые теги, ближайшее напоминание, последние вещи, папки
/// и живая строка поверх ленты.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // «ближайшее» считается от момента подписки, после паузы его надо пересчитать
    if (state == AppLifecycleState.resumed) ref.invalidate(upcomingProvider);
  }

  final _dock = GlobalKey<LineDockState>();

  void _open(String id) => Navigator.of(context).push(itemRoute(id));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        _Feed(onOpen: _open, onTag: (name) => _dock.currentState?.searchTag(name)),
        Positioned.fill(child: LineDock(key: _dock, onOpenItem: _open)),
      ]),
    );
  }
}

/// Лента главной. Читает базу потоками: закинул — вещь въезжает сама.
class _Feed extends ConsumerWidget {
  const _Feed({required this.onOpen, required this.onTag});

  final ValueChanged<String> onOpen;
  final ValueChanged<String> onTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final filesRoot = ref.watch(filesRootProvider);
    final now = ref.read(clockProvider)();
    final pinned = ref.watch(pinnedTagsProvider).value ?? const [];
    final upcoming = ref.watch(upcomingProvider).value ?? const [];
    final recent = ref.watch(recentItemsProvider).value ?? const [];
    final folders = ref.watch(foldersProvider).value ?? const [];
    final items = ref.read(itemsRepositoryProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(slivers: [
      SliverSafeArea(
        bottom: false,
        sliver: SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, 16, Space.screen, 16),
            child: Text(l.appName, style: text.headlineSmall),
          ),
        ),
      ),
      if (pinned.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.only(bottom: 16), child: PinnedTagsRow(tags: pinned, filesRoot: filesRoot, onTap: (tag) => onTag(tag.name))),
        ),
      if (upcoming.isNotEmpty)
        SliverToBoxAdapter(
          child: NextReminderCard(
            key: ValueKey(upcoming.first.id),
            item: upcoming.first,
            more: upcoming.length - 1,
            now: now,
            onDone: () => items.clearReminder(upcoming.first.id),
            onTap: () => onOpen(upcoming.first.id),
          ),
        ),
      if (recent.isNotEmpty) ...[
        SliverToBoxAdapter(child: SectionHeader(title: l.homeRecent)),
        SliverToBoxAdapter(child: RecentStrip(items: recent, filesRoot: filesRoot, now: now, onOpen: (card) => onOpen(card.id))),
      ],
      if (folders.isNotEmpty) ...[
        SliverToBoxAdapter(child: SectionHeader(title: l.homeFolders)),
        SliverToBoxAdapter(child: FoldersGrid(folders: folders, filesRoot: filesRoot)),
      ],
      if (recent.isEmpty && folders.isEmpty)
        SliverFillRemaining(hasScrollBody: false, child: Padding(padding: EdgeInsets.only(bottom: _dockSpace + bottom), child: _Empty(message: l.homeEmpty)))
      else
        SliverToBoxAdapter(child: SizedBox(height: _dockSpace + bottom)),
    ]);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ShapeBadge(
            shape: BadgeShape.cookie9,
            size: 72,
            color: Tokens.containerHigh,
            child: Icon(symbolIcon('inbox'), size: 32, color: Tokens.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Tokens.muted),
            ),
          ),
        ]),
      ),
    );
  }
}
