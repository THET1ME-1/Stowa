import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/platform.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/above_system_bar.dart';
import '../../core/widgets/hint_banner.dart';
import '../../core/widgets/shape_badge.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart' show AppDatabase;
import '../../data/providers.dart';
import '../../domain/hints.dart' show Tip, visibleStep;
import '../../domain/return_plan.dart';
import '../../l10n/app_localizations.dart';
import '../../domain/item_title.dart' show linesUnderTitle;
import '../../domain/note_links.dart' show shownTitle;
import '../../domain/search_query.dart' show parseSearch;
import '../../services/capture_service.dart' show CaptureInput, PickedFile;
import '../../services/panel_bridge.dart';
import '../../services/panel_db.dart';
import '../../services/panel_writes.dart';
import '../../services/launch_actions.dart';
import '../../services/notice_service.dart' show noticePrivatePref;
import '../../services/place_alarms.dart';
import '../../services/share_intake.dart';
import '../../services/vault/vault_watch.dart';
import '../catalog/catalog_screen.dart';
import '../composer/line_dock.dart';
import '../composer/panel_text.dart';
import '../workspace/workspace_shell.dart';
import '../composer/picked_files.dart' show pickCameraPhoto;
import '../folder/folder_screen.dart';
import '../smart/smart_folder_screen.dart';
import 'folder_suggest_card.dart';
import '../item/item_actions.dart';
import '../item/item_screen.dart';
import '../tags/tag_sheet.dart';
import '../map/map_screen.dart';
import '../settings/settings_screen.dart';
import '../web/copy_nudge.dart';
import '../share/share_inbox.dart';
import '../share/share_receiver.dart';
import '../../domain/note_blocks.dart';
import 'folder_shelf.dart';
import 'reminder_carousel.dart';
import 'note_timeline.dart';
import 'pinned_tags_row.dart';
import '../tags/tag_search.dart';
import '../returns/return_screen.dart' show notificationRoute, notificationTarget;
import '../../app.dart' show appNavigator;
import '../../l10n/app_language.dart';
import '../../services/billing/copy_warning.dart' show syncCopyPayload;
import '../../services/reminder_actions.dart' show handleReminderAction;
import '../../services/reminder_service.dart' show NotificationTap, notificationOpen, reminderItemId;
import '../../services/return_service.dart' show ReturnService;
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
    // корешки «Под рукой» включены — служба на месте и при первом открытии, а не только при
    // возврате: HyperOS убивает их вместе с процессом, и открывать Stowa приходилось дважды
    ref.read(edgeControlProvider).resumed().ignore();
    // браузер: эта вкладка держит хранилище и отвечает боковой панели (STOWA-9)
    if (isWeb) _panel = _panelBridge()..start();
    // виджеты читают заметки из файла (iPhone — в папке группы, Android — в папке
    // приложения, STOWA-8): держать его свежим, замок — сразу
    if (isIOS || isAndroid) {
      ref.read(widgetSyncProvider).start();
      ref.listenManual(privacyLockProvider, (previous, next) => ref.read(widgetSyncProvider).refresh(now: true));
    }
    // закрепили, убрали, поправили текст закреплённой — уведомления следом; замок — тоже
    ref.listenManual(noticesProvider, (previous, next) => _syncNotices().ignore(), fireImmediately: true);
    ref.listenManual(privacyLockProvider, (previous, next) {
      _syncNotices(force: true).ignore();
      // включили код — строка телефона в панели браузера теряет базу
      _panel?.lockChanged();
    });
    // любая правка напоминаний в базе переставляет будильники системы
    ref.listenManual(remindersProvider, (previous, next) {
      final reminders = next.value;
      if (reminders != null) ref.read(reminderServiceProvider).sync(reminders, ref.read(clockProvider)());
    }, fireImmediately: true);
    // подписка кончилась или её продлили: предупреждение о стирании копии встаёт или снимается
    ref.listenManual(subscriptionProvider, (previous, next) {
      if (next.value == null || previous?.value == next.value) return;
      ref.read(reminderServiceProvider).refresh(ref.read(clockProvider)()).ignore();
    });
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
        // правка легла в файлы: отправить на другие телефоны, когда правки утихнут
        ref.read(syncServiceProvider).poke();
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
      // открыли касанием уведомления по месту или заметки в окне виджета
      initialLaunch().then(_onRawLaunch).ignore();
      listenLaunches(_onRawLaunch);
      // на iPhone «Поделиться» открывает само приложение: присланное приходит сюда
      _shared = ref.read(sharedInboxProvider).listen((pieces) {
        if (mounted) receiveShared(context, ref, pieces).ignore();
      }, onError: (_) {});
      // касания и кнопки уведомлений браузера: выполняет эта вкладка, фонового процесса там нет
      _taps = ref.read(notificationTapsProvider).listen((tap) => _onNotificationTap(tap).ignore());
      // вечерний возврат и смахнутые закреплённые — как фоновая задача телефона раз в 15 минут,
      // пока сайт открыт
      if (isWeb) {
        _browserTick().ignore();
        _browserTimer = Timer.periodic(const Duration(minutes: 15), (_) => _browserTick().ignore());
      }
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
    _shared?.cancel().ignore();
    _taps?.cancel().ignore();
    _browserTimer?.cancel();
    _panel?.stop();
    super.dispose();
  }

  PanelBridge? _panel;

  /// Ответы боковой панели браузера: запись тем же сервисом, что строка, поиск тем же
  /// поиском. Под «Кодом на вход» панель только записывает: папку и найденное не видит.
  PanelBridge _panelBridge() {
    bool locked() => (ref.read(privacyLockProvider).value ?? ref.read(startLockProvider))?.appLock ?? false;
    return PanelBridge(
      link: PanelLink(),
      locked: locked,
      capture: (text) async {
        final id = await ref.read(captureServiceProvider).capture(CaptureInput(text: text));
        final saved = await ref.read(itemsRepositoryProvider).get(id);
        final folders = ref.read(foldersProvider).value ?? const [];
        return (id: id, folder: folders.where((one) => one.id == saved?.item.folderId).firstOrNull?.name);
      },
      undo: (id) => ref.read(itemsRepositoryProvider).softDelete(id, ref.read(clockProvider)()),
      search: (query) async {
        final now = ref.read(clockProvider)();
        final found = await ref.read(itemsRepositoryProvider).search(query: parseSearch(query, now), now: now, limit: 8);
        return [
          for (final result in found.results)
            PanelNote(id: result.card.id, title: shownTitle(result.card.title), line: linesUnderTitle(result.card.body, result.card.title).firstOrNull, folder: result.card.folderName),
        ];
      },
      // строка главной живёт и во вкладке рабочего места: от неё заметка откроется своей вкладкой
      open: (id) {
        final from = _dock.currentContext ?? context;
        if (from.mounted) openItem(from, id).ignore();
      },
      // строке телефона в панели — база на чтение, её записи выполняют те же службы
      database: PanelDbServer(ref.read(databaseProvider)),
      schema: AppDatabase.schema,
      writes: PanelWrites(
        captureAll: (inputs) => ref.read(captureServiceProvider).captureAll(inputs),
        append: (id, text) => ref.read(itemsRepositoryProvider).append(id, text, ref.read(clockProvider)()),
        makeFolder: (name, parentId) => ref.read(foldersRepositoryProvider).create(name, parentId: parentId),
        makeSmartFolder: (name, query) => ref.read(smartFoldersRepositoryProvider).create(name: name, query: query),
        makeDocument: (kind, title, folderId) => ref.read(documentsRepositoryProvider).create(kind, title: title, folderId: folderId),
        placeFile: (name, bytes) async {
          // вложение из панели — во временную папку вкладки: хранитель файлов перенесёт его в хранилище
          final Directory root = ref.read(cacheRootProvider) ?? ref.read(scratchRootProvider);
          final file = File(p.join(root.path, 'panel', '${DateTime.now().microsecondsSinceEpoch}-$name'));
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes);
          return file.path;
        },
      ),
    );
  }

  Timer? _placeTimer;
  StreamSubscription<List<SharedPiece>>? _shared;
  StreamSubscription<NotificationTap>? _taps;
  Timer? _browserTimer;

  /// Касание уведомления открывает заметку (на мониторе — вкладкой) или экран; кнопка
  /// выполняется так же, как фоновым процессом телефона, и база сама переставит будильники.
  Future<void> _onNotificationTap(NotificationTap tap) async {
    if (tap.action != notificationOpen) {
      await handleReminderAction(ref.read(itemsRepositoryProvider), actionId: tap.action, itemId: reminderItemId(tap.payload), now: ref.read(clockProvider)());
      return;
    }
    if (!mounted) return;
    final target = notificationTarget(tap.payload);
    final plain = target.kind == null && !tap.payload.startsWith('hidden:') && tap.payload != syncCopyPayload;
    if (plain && target.itemId != null) {
      // строка главной живёт и во вкладке рабочего места: от неё заметка откроется своей вкладкой
      final from = _dock.currentContext ?? context;
      if (from.mounted) openItem(from, target.itemId!).ignore();
      return;
    }
    if (notificationRoute(tap.payload) case final route?) appNavigator.currentState?.push(route);
  }

  /// Раз в 15 минут на сайте: решить вечерний возврат и вернуть смахнутые закреплённые.
  Future<void> _browserTick() async {
    if (!mounted) return;
    final language = ref.read(languageProvider).value ?? AppLanguage.resolve(WidgetsBinding.instance.platformDispatcher.locales);
    final l = lookupL(language.locale);
    await ReturnService(
      ref.read(databaseProvider),
      prefs: ref.read(preferencesProvider),
      port: ref.read(notificationPortProvider),
      clock: ref.read(clockProvider),
      settings: () => ref.read(returnSettingsProvider).value ?? const ReturnSettings(),
      l: () => l,
    ).tick().catchError((_) => null);
    await _syncNotices(force: true);
  }

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
    // пока приложение на экране, правка с другого телефона приходит сразу
    ref.read(syncServiceProvider).listen().ignore();
  }

  /// Запуск снаружи: уведомление по месту или заметка из окна виджета открывают заметку или экран
  /// возврата. Кнопки виджета iPhone (строка, микрофон, камера) выполняет строка главной: на
  /// Android у них своё окно, сюда они не приходят.
  void _onRawLaunch(String? raw) {
    if (!mounted) return;
    if (launchActionOf(raw) case final action?) {
      if (defaultTargetPlatform == TargetPlatform.iOS) _dockAction(action).ignore();
      return;
    }
    final payload = openPayloadOf(raw);
    if (payload == null) return;
    if (notificationRoute(payload) case final route?) Navigator.of(context).push(route);
  }

  Future<void> _dockAction(LaunchAction action) async {
    // приложение открылось на заметке или листе: кнопка виджета — про строку главной
    Navigator.of(context).popUntil((route) => route.isFirst);
    final dock = _dock.currentState;
    if (dock == null) return;
    switch (action) {
      case LaunchAction.compose:
        dock.focusLine();
      case LaunchAction.voice:
        await dock.startVoice();
      case LaunchAction.attach:
        dock.openTray();
      case LaunchAction.camera:
        var photos = const <PickedFile>[];
        try {
          photos = await pickCameraPhoto();
        } on PlatformException {
          // камеры нет или её не дали: снимка нет
        }
        if (!mounted || photos.isEmpty) return;
        _dock.currentState?.attach(photos);
        _dock.currentState?.focusLine();
    }
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
      // снимок виджета ждал конца набора — пишется сейчас, пока процесс жив
      ref.read(widgetSyncProvider).flush();
      _handOverFiles().ignore();
      _watch?.stop().ignore();
      _watch = null;
      ref.read(syncServiceProvider).stopListening();
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
    ref.invalidate(upcomingProvider);
    // вернулся в приложение: то, что фон не успел, разбирается сейчас
    ref.read(aiDrainProvider)().ignore();
    // корешки «Под рукой» включены — служба на месте; вернулся с правом — включаются
    ref.read(edgeControlProvider).resumed().ignore();
    ref.read(telegramPullProvider)().ignore();
    // смахнутые закреплённые (Android 14+ даёт смахнуть) встают обратно
    _syncNotices(force: true).ignore();
  }

  /// Уведомления заметок, закреплённых в уведомлениях. Под «Кодом на вход» на экране
  /// блокировки без текста; выбор записывается и для фонового прохода.
  Future<void> _syncNotices({bool force = false}) async {
    final notices = ref.read(noticesProvider).value;
    if (notices == null) return;
    final private = (ref.read(privacyLockProvider).value ?? ref.read(startLockProvider))?.appLock ?? false;
    try {
      await ref.read(preferencesProvider).setBool(noticePrivatePref, private);
    } on Object {
      // окна и тесты без настроек: фон возьмёт прежний выбор
    }
    if (!mounted) return;
    await ref.read(noticeServiceProvider).sync(notices, private: private, force: force);
  }

  final _dock = GlobalKey<LineDockState>();

  void _open(String id) => Navigator.of(context).push(itemRoute(id));

  @override
  Widget build(BuildContext context) {
    // касание тега где угодно (STOWA-10): строка главной ищет по нему. После кадра — экран
    // заметки ещё закрывается, и фокус строке до этого не отдать
    ref.listen(tagSearchProvider, (_, request) {
      if (request == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _dock.currentState?.searchTag(request.tag));
    });
    // оба вида собираются здесь, а не в LayoutBuilder: клавиатура меняет высоту тела каждый кадр
    // своего выезда, и LayoutBuilder пересобирал бы на каждом кадре всю ленту и строку (телефон:
    // «дёргается, 10 FPS»). Одни и те же виджеты Flutter второй раз не строит
    final wide = WorkspaceShell(
      onFind: () => _dock.currentState?.focusLine(),
      composer: (open) => LineDock(key: _dock, onOpenItem: open, onboarding: true, maxWidth: 760),
    );
    final phone = Stack(
      children: [
        _Feed(onOpen: _open, onTag: (name) => _dock.currentState?.searchTag(name)),
        Positioned.fill(
          child: LineDock(key: _dock, onOpenItem: _open, onboarding: true),
        ),
      ],
    );
    return Scaffold(
      // широкое окно (браузер, компьютер) — рабочее пространство с доками и вкладками;
      // обходы, слежка за хранилищем и синхронизация остаются здесь, при любой ширине
      body: LayoutBuilder(builder: (context, constraints) => constraints.maxWidth >= workspaceFrom ? wide : phone),
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
    final pinnedNotes = ref.watch(pinnedItemsProvider).value ?? const [];
    final inbox = [...pinnedNotes, ...recent].any((card) => card.folderId == null);
    final folders = ref.watch(foldersProvider).value ?? const [];
    final smart = ref.watch(smartFoldersProvider).value ?? const [];
    final items = ref.read(itemsRepositoryProvider);
    // карточка шага знакомства стоит над строкой: лента оставляет и под неё место, низ не прячется
    final hints = ref.watch(hintsProvider).value;
    // системную полосу снизу добавляют сами отступы ленты (AboveSystemBar) и точки: от неё лента
    // пересобиралась целиком на первых кадрах выезда клавиатуры, когда полоса уходит под неё
    final lift = _dockSpace + (hints != null && visibleStep(hints) != null ? 130 : 0);

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
                  // «Год назад», «Неделю назад»: круглой кнопкой, только когда есть что вспомнить
                  const OnThisDayButton(),
                  // сцепленные кнопки, как «править» и «ещё» на странице заметки
                  _HeaderGroup(
                    buttons: [
                      // скрытое открыто: замок закрывает его сразу
                      if (ref.watch(hiddenOpenProvider).value ?? false)
                        (icon: 'lock_open', tooltip: l.hiddenCloseRow, onTap: () => ref.read(privacyServiceProvider).close()),
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
        if (ref.watch(aiSettingsProvider).value case final ai? when ai.stalled)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 16),
              // плашка ведёт прямо к ключу, а не в общий список настроек
              child: AiPausedBanner(settings: ai, onTap: () => Navigator.of(context).push(aiRoute())),
            ),
          ),
        // папки первыми: куда что лежит, видно сразу при открытии
        if (folders.isNotEmpty || smart.isNotEmpty || inbox)
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
                onInbox: inbox ? () => Navigator.of(context).push(folderRoute(null)) : null,
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
            child: ReminderCarousel(
              items: upcoming,
              now: now,
              onDone: (next) async {
                final messenger = ScaffoldMessenger.of(context);
                await items.clearReminder(next.id);
                // случайный тап не стирает напоминание насовсем
                showUndo(messenger, message: l.reminderCleared, label: l.undo, onUndo: () => items.snoozeReminder(next.id, next.reminderAt!), overDock: true);
              },
              onOpen: (next) => onOpen(next.id),
            ),
          ),
        // спросить про уведомления один раз, когда уже есть что возвращать
        if (recent.isNotEmpty && ref.watch(returnsAskedProvider).value == false)
          const SliverToBoxAdapter(child: ReturnsAskCard()),
        // «12 ссылок с habr.com без папки — сделать папку?»
        if (ref.watch(folderSuggestionProvider).value case final suggestion?) SliverToBoxAdapter(child: FolderSuggestCard(suggestion: suggestion)),
        // напоминание по месту поставлено, а без места «всегда» оно не сработает
        const SliverToBoxAdapter(child: PlaceAlwaysCard()),
        const SliverToBoxAdapter(child: ReturnPills()),
        // снаружи пришло много заметок (Syncthing, компьютер): видно, что приложение их забирает
        SliverToBoxAdapter(child: VaultSyncBar(sync: ref.watch(vaultSyncProvider))),
        // в браузере на узком окне: заметки лежат только в нём, напоминание о копии
        const SliverToBoxAdapter(child: CopyNudgeHost(padding: EdgeInsets.fromLTRB(Space.screen, 4, Space.screen, 8))),
        // меню долгого нажатия не видно, пока не нажмёшь: сказать, когда заметок уже несколько
        SliverToBoxAdapter(
          child: HintBanner(tip: Tip.longPress, when: recent.length + pinnedNotes.length >= 5, padding: const EdgeInsets.fromLTRB(Space.screen, 4, Space.screen, 8)),
        ),
        if (recent.isNotEmpty || pinnedNotes.isNotEmpty)
          SliverToBoxAdapter(
            child: NoteTimeline(
              // точки заметок держатся над строкой ввода, как аватарки в чате
              bottomInset: lift,
              items: recent,
              pinned: pinnedNotes,
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
        if (recent.isEmpty && pinnedNotes.isEmpty && folders.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AboveSystemBar(lift: lift, child: _Empty(message: l.homeEmpty)),
          )
        else
          SliverToBoxAdapter(child: AboveSystemBar(lift: lift)),
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
