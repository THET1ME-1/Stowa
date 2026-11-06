import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/shape_badge.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/launch_actions.dart';
import '../../services/vault/vault_watch.dart';
import '../composer/line_dock.dart';
import '../composer/panel_text.dart';
import '../folder/folder_screen.dart';
import '../item/item_actions.dart';
import '../item/item_screen.dart';
import '../tags/tag_sheet.dart';
import '../map/map_screen.dart';
import '../settings/settings_screen.dart';
import 'folders_grid.dart';
import 'next_reminder_card.dart';
import 'pinned_tags_row.dart';
import 'recent_strip.dart';
import 'section_header.dart';
import 'vault_sync_bar.dart';

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
    // любая правка напоминаний в базе переставляет будильники системы
    ref.listenManual(remindersProvider, (previous, next) {
      final reminders = next.value;
      if (reminders != null) ref.read(reminderServiceProvider).sync(reminders, ref.read(clockProvider)());
    }, fireImmediately: true);
    // человек переложил вещь сам (и при запуске): похожее из «Без папки» ложится следом
    ref.listenManual(manualMovesProvider, (previous, next) {
      if (next.value == null || previous?.value == next.value) return;
      _sortInbox();
    }, fireImmediately: true);
    // ссылки без превью, свежие и старые: заголовок страницы и обложка грузятся в фоне
    ref.listenManual(pendingPreviewsProvider, (previous, next) {
      final ids = next.value;
      if (ids != null && ids.isNotEmpty) ref.read(linkPreviewServiceProvider).run(ids).ignore();
    }, fireImmediately: true);
    // правки ждут записи в файлы хранилища: писатель забирает их, пока приложение открыто;
    // наткнулся на файл, поправленный снаружи, — полная сверка, чтобы его не затереть
    ref.listenManual(vaultQueueProvider, (previous, next) {
      if ((next.value?.$1 ?? 0) == 0) return;
      final writer = ref.read(vaultWriterProvider);
      writer.drain().then((_) {
        if (writer.sawExternalEdit) ref.read(vaultSyncProvider).run().ignore();
      }).ignore();
    });
    // ИИ положил вещь в папку, пока приложение открыто: сказать куда и дать переложить
    ref.listenManual(aiSortedProvider, (previous, next) {
      final sorted = next.value;
      if (sorted == null || !mounted) return;
      final l = L.of(context);
      showUndo(
        ScaffoldMessenger.of(context),
        message: l.aiSortedInto(sorted.folderName),
        label: l.aiOtherFolder,
        onUndo: () => moveItemById(context, ref, id: sorted.itemId, from: sorted.folderId),
        duration: const Duration(seconds: 3),
        overDock: true,
      );
    });
    // файл не скопировался: человек должен узнать сразу, а не найти пустую вещь потом
    ref.listenManual(copyFailuresProvider, (previous, next) {
      final failure = next.value;
      if (failure == null || !mounted) return;
      final l = L.of(context);
      showNote(ScaffoldMessenger.of(context), failure.removed ? l.shareFailed : l.copyPartlyFailed(failure.failed), overDock: true);
    });
    // сеть вернулась: всё, что ждало ИИ без связи, уходит сразу
    ref.listenManual(onlineProvider, (previous, next) {
      if (next.value != true || previous?.value == true) return;
      ref.read(aiDrainProvider)().ignore();
      ref.read(telegramPullProvider)().ignore();
      _retryPreviews();
    });
    // старые вещи под нынешние правила: размеры картинок для доски и заголовки вместо имён файлов
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // открыли с виджета: строка с клавиатурой или сразу запись голоса
      initialLaunchAction().then(_onLaunch).ignore();
      listenLaunchActions(_onLaunch);
      // при открытии: файлы, которые не успели лечь до закрытия или выключения телефона
      ref.read(captureServiceProvider).files.drain().ignore();
      // вещи, которые ещё не разобраны извлекателями или разобраны старой их версией
      _sweepFacts().ignore();
      // хранилище: сперва правки снаружи, сделанные, пока приложение было закрыто, потом свои
      ref.read(vaultSyncProvider).run().ignore();
      _watchVault();
      // всё, что накопилось без сети или без ключа, и что переслали боту
      ref.read(aiDrainProvider)().ignore();
      ref.read(telegramPullProvider)().ignore();
      // корзина держит удалённое 30 дней, дальше стирает вместе с файлами
      ref.read(trashRepositoryProvider).purgeExpired(ref.read(clockProvider)()).ignore();
      final l = L.of(context);
      final capture = ref.read(captureServiceProvider);
      capture.fillImageSizes().ignore();
      capture.reclassifyNotes().ignore();
      capture.retitleFileNames(({required mime, required fileName, required at}) => untitledFor(l, mime: mime, fileName: fileName, at: at)).ignore();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watch?.stop().ignore();
    super.dispose();
  }

  LaunchAction? _pendingLaunch;

  /// Слежка за папкой хранилища, пока приложение на экране.
  VaultWatch? _watch;

  void _watchVault() {
    _watch?.stop().ignore();
    _watch = VaultWatch(ref.read(databaseProvider), root: ref.read(vaultRootProvider), onChange: () => ref.read(vaultSyncProvider).run())..start();
  }

  void _onLaunch(LaunchAction? action) {
    if (action == null || !mounted) return;
    // касание виджета приходит, пока окно ещё за рабочим столом: клавиатура тогда не встаёт.
    // действие ждёт, пока приложение выйдет вперёд
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) {
      _pendingLaunch = action;
      return;
    }
    // виджет нажали поверх другого экрана: сперва назад на главную
    Navigator.of(context).popUntil((route) => route.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (action) {
        case LaunchAction.compose:
          _dock.currentState?.focusLine();
          // на холодном старте окно получает фокус позже первого кадра, и первый
          // запрос клавиатуры Android молча пропускает: просим ещё раз
          Future.delayed(const Duration(milliseconds: 450), () => SystemChannels.textInput.invokeMethod<void>('TextInput.show')).ignore();
        case LaunchAction.voice:
          _dock.currentState?.startVoice();
      }
    });
  }

  Future<void> _sweepFacts() async {
    final facts = ref.read(factsPipelineProvider);
    await facts.sweep();
    await facts.sweepNetwork();
    // сеть докачала копии страниц старых ссылок — разобрать их сразу
    await facts.sweep();
  }

  Future<void> _handOverFiles() async {
    final db = ref.read(databaseProvider);
    final waiting = await db.select(db.fileJobs).get();
    if (waiting.isNotEmpty) await ref.read(fileWorkProvider)();
  }

  /// Разобрать «Без папки» заново и сказать, сколько разложено, с «Отменить».
  Future<void> _sortInbox() async {
    final sorter = ref.read(autoSorterProvider);
    final moved = await sorter.sortInbox();
    if (moved.isEmpty || !mounted) return;
    final l = L.of(context);
    showUndo(ScaffoldMessenger.of(context), message: l.autoSorted(moved.length), label: l.undo, onUndo: () => sorter.undoSort(moved), overDock: true);
  }

  /// Ссылки, превью которых сорвалось (сеть оборвалась, телефон уснул), — ещё раз.
  void _retryPreviews() {
    final ids = ref.read(pendingPreviewsProvider).value;
    if (ids != null && ids.isNotEmpty) ref.read(linkPreviewServiceProvider).retry(ids).ignore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ушёл из приложения, а файл ещё ложится: система доделает, даже если Stowa выгрузят
    if (state == AppLifecycleState.paused) {
      _handOverFiles().ignore();
      _watch?.stop().ignore();
      _watch = null;
      return;
    }
    // «ближайшее» считается от момента подписки, после паузы его надо пересчитать
    if (state != AppLifecycleState.resumed) return;
    ref.read(captureServiceProvider).files.drain().ignore();
    _sweepFacts().ignore();
    _retryPreviews();
    // пока приложение было свёрнуто, файлы могли поправить снаружи (Obsidian, Syncthing)
    ref.read(vaultSyncProvider).run().ignore();
    _watchVault();
    final launch = _pendingLaunch;
    _pendingLaunch = null;
    _onLaunch(launch);
    ref.invalidate(upcomingProvider);
    // вернулся в приложение: то, что фон не успел, разбирается сейчас
    ref.read(aiDrainProvider)().ignore();
    ref.read(telegramPullProvider)().ignore();
  }

  final _dock = GlobalKey<LineDockState>();

  void _open(String id) => Navigator.of(context).push(itemRoute(id));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _Feed(onOpen: _open, onTag: (name) => _dock.currentState?.searchTag(name)),
          Positioned.fill(
            child: LineDock(key: _dock, onOpenItem: _open),
          ),
        ],
      ),
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

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 10, Space.screen - 4, 10),
              child: Row(
                children: [
                  Expanded(child: Text(l.appName, style: text.headlineSmall)),
                  // где что сохранено
                  IconButton(
                    tooltip: l.mapTitle,
                    onPressed: () => Navigator.of(context).push(mapRoute()),
                    style: IconButton.styleFrom(backgroundColor: Tokens.containerHigh, fixedSize: const Size.square(44)),
                    icon: Icon(symbolIcon('map'), size: 20, color: Tokens.onSurface),
                  ),
                  const SizedBox(width: 8),
                  // ключ ИИ, теги, папки и правила, язык — как кнопка tune на главной в макете
                  IconButton(
                    tooltip: l.settingsTitle,
                    onPressed: () => Navigator.of(context).push(settingsRoute()),
                    style: IconButton.styleFrom(backgroundColor: Tokens.containerHigh, fixedSize: const Size.square(44)),
                    icon: Icon(symbolIcon('tune'), size: 20, color: Tokens.onSurface),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (ref.watch(aiSettingsProvider).value case final ai? when ai.paused)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 16),
              child: AiPausedBanner(settings: ai, onTap: () => Navigator.of(context).push(settingsRoute())),
            ),
          ),
        if (pinned.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PinnedTagsRow(
                tags: pinned,
                filesRoot: filesRoot,
                onTap: (tag) => onTag(tag.name),
                onAdd: () => showTagSheet(context, pin: true),
                addTooltip: l.tagAdd,
              ),
            ),
          ),
        if (upcoming.isNotEmpty)
          SliverToBoxAdapter(
            child: NextReminderCard(
              key: ValueKey(upcoming.first.id),
              item: upcoming.first,
              more: upcoming.length - 1,
              now: now,
              onDone: () async {
                final next = upcoming.first;
                final messenger = ScaffoldMessenger.of(context);
                await items.clearReminder(next.id);
                // случайный тап не стирает напоминание насовсем
                showUndo(messenger, message: l.reminderCleared, label: l.undo, onUndo: () => items.snoozeReminder(next.id, next.reminderAt!), overDock: true);
              },
              onTap: () => onOpen(upcoming.first.id),
            ),
          ),
        // снаружи пришло много заметок (Syncthing, компьютер): видно, что приложение их забирает
        SliverToBoxAdapter(child: VaultSyncBar(sync: ref.watch(vaultSyncProvider))),
        if (recent.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader(
              title: l.homeRecent,
              // всё, что ещё не разложено, одной лентой
              action: recent.any((card) => card.folderId == null) ? l.folderNone : null,
              onAction: () => Navigator.of(context).push(folderRoute(null)),
            ),
          ),
          SliverToBoxAdapter(
            child: RecentStrip(
              items: recent,
              filesRoot: filesRoot,
              now: now,
              aiSorting: ref.watch(aiSettingsProvider).value?.active ?? false,
              onOpen: (card) => onOpen(card.id),
              onMove: (card) => moveItem(context, ref, card),
              onAct: (card) => showItemActions(context, ref, card),
            ),
          ),
        ],
        if (folders.isNotEmpty) ...[
          SliverToBoxAdapter(child: SectionHeader(title: l.homeFolders)),
          SliverToBoxAdapter(
            child: FoldersGrid(folders: folders, filesRoot: filesRoot, onOpen: (folder) => Navigator.of(context).push(folderRoute(folder.id))),
          ),
        ],
        if (recent.isEmpty && folders.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: _dockSpace + bottom),
              child: _Empty(message: l.homeEmpty),
            ),
          )
        else
          SliverToBoxAdapter(child: SizedBox(height: _dockSpace + bottom)),
      ],
    );
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          ],
        ),
      ),
    );
  }
}
