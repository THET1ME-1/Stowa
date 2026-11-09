import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/shape_badge.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../domain/return_plan.dart';
import '../../l10n/app_localizations.dart';
import '../../services/launch_actions.dart';
import '../../services/place_alarms.dart';
import '../../services/vault/vault_watch.dart';
import '../catalog/catalog_screen.dart';
import '../composer/line_dock.dart';
import '../composer/panel_text.dart';
import '../folder/folder_screen.dart';
import '../smart/smart_folder_screen.dart';
import 'folder_suggest_card.dart';
import '../item/item_actions.dart';
import '../item/item_screen.dart';
import '../tags/tag_sheet.dart';
import '../map/map_screen.dart';
import '../settings/settings_screen.dart';
import '../../domain/note_blocks.dart';
import 'folder_shelf.dart';
import 'next_reminder_card.dart';
import 'note_timeline.dart';
import 'pinned_tags_row.dart';
import '../returns/return_screen.dart' show notificationRoute;
import '../places/place_always_card.dart';
import 'return_pills.dart';
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
    // включили картинки статей — качать сразу, а не при следующем открытии приложения
    ref.listenManual(articleImagesProvider, (previous, next) {
      if (next.value == true && previous?.value == false) _sweepFacts().ignore();
    });
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
    // заметки, теги или места поменялись: тревоги по месту переставляются, когда правки утихнут
    ref.listenManual(placeChangesProvider, (previous, next) {
      _placeTimer?.cancel();
      _placeTimer = Timer(const Duration(seconds: 1), () => _syncPlaces().ignore());
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
      initialLaunch().then(_onRawLaunch).ignore();
      listenLaunches(_onRawLaunch);
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
      capture.shortenPlaceNames().ignore();
      // сперва подпись вместо имени файла, потом её день — съёмки или сохранения, как выбрано
      String untitled({required String mime, required String fileName, required DateTime at}) => untitledFor(l, mime: mime, fileName: fileName, at: at);
      final byShot = ref.read(titleByShotProvider)();
      capture.retitleFileNames(untitled).then((_) => capture.retitleUntitled(untitled, byShot: byShot)).ignore();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watch?.stop().ignore();
    _placeTimer?.cancel();
    super.dispose();
  }

  LaunchAction? _pendingLaunch;

  Timer? _placeTimer;

  /// Сработавшее по месту снять, тревоги поставить заново. Без Android (тесты) канал молчит.
  Future<void> _syncPlaces() async {
    if (!mounted) return;
    final l = L.of(context);
    await PlaceAlarmService(
      ref.read(databaseProvider),
      channel: ref.read(placeChannelProvider),
      settings: () => ref.read(returnSettingsProvider).value ?? const ReturnSettings(),
      l: () => l,
    ).sync();
  }

  /// Слежка за папкой хранилища, пока приложение на экране.
  VaultWatch? _watch;

  void _watchVault() {
    _watch?.stop().ignore();
    _watch = VaultWatch(ref.read(databaseProvider), root: ref.read(vaultRootProvider), onChange: () => ref.read(vaultSyncProvider).run())..start();
  }

  /// Запуск снаружи: уведомление по месту открывает заметку или экран возврата, виджет — строку.
  void _onRawLaunch(String? raw) {
    if (!mounted) return;
    if (openPayloadOf(raw) case final payload?) {
      if (notificationRoute(payload) case final route?) Navigator.of(context).push(route);
      return;
    }
    _onLaunch(launchActionOf(raw));
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
    // пока приложение было свёрнуто, могло сработать напоминание по месту — снять его
    _syncPlaces().ignore();
    // вернулся из системных настроек — место «всегда» могли разрешить
    ref.invalidate(placeNeedsAlwaysProvider);
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
    final smart = ref.watch(smartFoldersProvider).value ?? const [];
    final items = ref.read(itemsRepositoryProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 12, Space.screen, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.appName, style: text.headlineSmall!.copyWith(fontSize: 24, height: 1.1)),
                        // итог под именем: сколько всего накопилось
                        if (ref.watch(notesCountProvider).value case final notes? when notes > 0) ...[
                          const SizedBox(height: 3),
                          Text(
                            [l.itemsCount(notes), if (folders.isNotEmpty) l.foldersCount(folders.length)].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall!.copyWith(color: Tokens.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // сцепленные кнопки, как «править» и «ещё» на странице заметки
                  _HeaderGroup(
                    buttons: [
                      // все папки и заметки деревом, отдельным экраном
                      (icon: 'account_tree', tooltip: l.catalogTitle, onTap: () => Navigator.of(context).push(catalogRoute())),
                      // где что сохранено
                      (icon: 'map', tooltip: l.mapTitle, onTap: () => Navigator.of(context).push(mapRoute())),
                      // ключ ИИ, теги, папки и правила, язык
                      (icon: 'tune', tooltip: l.settingsTitle, onTap: () => Navigator.of(context).push(settingsRoute())),
                    ],
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
        // папки первыми: куда что лежит, видно сразу при открытии
        if (folders.isNotEmpty || smart.isNotEmpty || recent.any((card) => card.folderId == null))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 16),
              child: FolderShelf(
                // только верхние: вложенные видны внутри своей папки
                folders: [for (final folder in folders) if (folder.parentId == null) folder],
                onOpen: (folder) => Navigator.of(context).push(folderRoute(folder.id)),
                smart: smart,
                onSmart: (one) => Navigator.of(context).push(smartFolderRoute(one.id)),
                // всё, что ещё не разложено, одной лентой
                onInbox: recent.any((card) => card.folderId == null) ? () => Navigator.of(context).push(folderRoute(null)) : null,
              ),
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
        // спросить про уведомления один раз, когда уже есть что возвращать
        if (recent.isNotEmpty && ref.watch(returnsAskedProvider).value == false) const SliverToBoxAdapter(child: ReturnsAskCard()),
        // «12 ссылок с habr.com без папки — сделать папку?»
        if (ref.watch(folderSuggestionProvider).value case final suggestion?) SliverToBoxAdapter(child: FolderSuggestCard(suggestion: suggestion)),
        // напоминание по месту поставлено, а без места «всегда» оно не сработает
        const SliverToBoxAdapter(child: PlaceAlwaysCard()),
        const SliverToBoxAdapter(child: ReturnPills()),
        // снаружи пришло много заметок (Syncthing, компьютер): видно, что приложение их забирает
        SliverToBoxAdapter(child: VaultSyncBar(sync: ref.watch(vaultSyncProvider))),
        if (recent.isNotEmpty)
          SliverToBoxAdapter(
            child: NoteTimeline(
              items: recent,
              filesRoot: filesRoot,
              now: now,
              aiSorting: ref.watch(aiSettingsProvider).value?.active ?? false,
              onOpen: (card) => onOpen(card.id),
              onMove: (card) => moveItem(context, ref, card),
              onAct: (card) => showItemActions(context, ref, card),
              // галочка пункта ставится прямо в ленте, заметку открывать не нужно
              onToggle: (card, line) {
                final body = toggleCheckLine(card.body, line);
                if (body != card.body) items.setBody(card.id, body, ref.read(clockProvider)()).ignore();
              },
            ),
          ),
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

/// Кнопки шапки одной группой: крупные углы только снаружи, между кнопками узкий зазор.
class _HeaderGroup extends StatelessWidget {
  const _HeaderGroup({required this.buttons});

  final List<({String icon, String tooltip, VoidCallback onTap})> buttons;

  @override
  Widget build(BuildContext context) {
    const outer = Radius.circular(24);
    const inner = Radius.circular(8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, button) in buttons.indexed) ...[
          if (index > 0) const SizedBox(width: 2),
          Tooltip(
            message: button.tooltip,
            child: Material(
              color: Tokens.containerHigh,
              borderRadius: BorderRadius.horizontal(left: index == 0 ? outer : inner, right: index == buttons.length - 1 ? outer : inner),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: button.onTap,
                child: SizedBox(
                  width: 50,
                  height: 48,
                  child: Icon(symbolIcon(button.icon), size: 21, color: Tokens.onSurface),
                ),
              ),
            ),
          ),
        ],
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
