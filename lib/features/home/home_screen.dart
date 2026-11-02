import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/shape_badge.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../composer/composer_bar.dart';
import '../composer/line_controller.dart';
import 'folders_grid.dart';
import 'next_reminder_card.dart';
import 'pinned_tags_row.dart';
import 'recent_strip.dart';
import 'saved_toast.dart';
import 'section_header.dart';

const _toastTime = Duration(seconds: 4);

/// Главная: закреплённые теги, ближайшее напоминание, последние вещи, папки
/// и строка снизу. Пока пишешь, лента притихает под тенью.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  late final LineController _line = LineController(clock: ref.read(clockProvider));
  final _focus = FocusNode();
  ({String id, String message})? _saved;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toastTimer?.cancel();
    _line.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _drafting => _focus.hasFocus && (_line.text.isNotEmpty || _line.tags.isNotEmpty);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // «ближайшее» считается от момента подписки, после паузы его надо пересчитать
    if (state == AppLifecycleState.resumed) ref.invalidate(upcomingProvider);
  }

  void _onSaved(String id, DateTime? reminderAt) {
    final l = L.of(context);
    final now = ref.read(clockProvider)();
    _toastTimer?.cancel();
    _toastTimer = Timer(_toastTime, () {
      if (mounted) setState(() => _saved = null);
    });
    setState(() => _saved = (
          id: id,
          message: reminderAt == null ? l.savedToast : l.savedWithReminder(formatReminder(l, reminderAt, now)),
        ));
  }

  Future<void> _undo() async {
    final saved = _saved;
    if (saved == null) return;
    _toastTimer?.cancel();
    setState(() => _saved = null);
    await ref.read(itemsRepositoryProvider).softDelete(saved.id, ref.read(clockProvider)());
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final saved = _saved;
    return Scaffold(
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            const _Feed(),
            // тень только пока пишешь: закинул — лента светлеет, и видно, как въезжает новое
            ListenableBuilder(
              listenable: Listenable.merge([_focus, _line]),
              builder: (context, _) => IgnorePointer(
                ignoring: !_drafting,
                child: AnimatedOpacity(
                  opacity: _drafting ? 1 : 0,
                  duration: Motion.medium,
                  curve: Motion.emphasized,
                  child: GestureDetector(
                    onTap: _focus.unfocus,
                    child: ColoredBox(color: Tokens.background.withValues(alpha: 0.72), child: const SizedBox.expand()),
                  ),
                ),
              ),
            ),
            Positioned(
              left: Space.screen,
              right: Space.screen,
              bottom: 8,
              child: AnimatedSwitcher(
                duration: Motion.medium,
                switchInCurve: Motion.spatial,
                switchOutCurve: Motion.emphasizedAccelerate,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(animation), child: child),
                ),
                child: saved == null
                    ? const SizedBox(key: ValueKey('none'))
                    : SavedToast(key: ValueKey(saved.id), message: saved.message, undoLabel: l.undo, onUndo: _undo),
              ),
            ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: ComposerBar(line: _line, focusNode: _focus, onSaved: _onSaved),
          ),
        ),
      ]),
    );
  }
}

/// Лента главной. Читает базу потоками: закинул — вещь въезжает сама.
class _Feed extends ConsumerWidget {
  const _Feed();

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
          child: Padding(padding: const EdgeInsets.only(bottom: 16), child: PinnedTagsRow(tags: pinned, filesRoot: filesRoot)),
        ),
      if (upcoming.isNotEmpty)
        SliverToBoxAdapter(
          child: NextReminderCard(
            key: ValueKey(upcoming.first.id),
            item: upcoming.first,
            more: upcoming.length - 1,
            now: now,
            onDone: () => items.clearReminder(upcoming.first.id),
          ),
        ),
      if (recent.isNotEmpty) ...[
        SliverToBoxAdapter(child: SectionHeader(title: l.homeRecent)),
        SliverToBoxAdapter(child: RecentStrip(items: recent, filesRoot: filesRoot, now: now)),
      ],
      if (folders.isNotEmpty) ...[
        SliverToBoxAdapter(child: SectionHeader(title: l.homeFolders)),
        SliverToBoxAdapter(child: FoldersGrid(folders: folders, filesRoot: filesRoot)),
      ],
      if (recent.isEmpty && folders.isEmpty)
        SliverFillRemaining(hasScrollBody: false, child: _Empty(message: l.homeEmpty))
      else
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
