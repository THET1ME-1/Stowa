import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_session.dart';
import 'core/fs/web_files.dart';
import 'core/motion/unfold/unfold_touch.dart';
import 'core/platform.dart';
import 'core/theme/tokens.dart';
import 'data/db/database.dart';
import 'data/hints_repository.dart';
import 'data/providers.dart';
import 'data/settings_repository.dart';
import 'domain/appearance.dart';
import 'domain/reminder_parser.dart' show warmUpReminders;
import 'features/edge/edge_host.dart';
import 'features/edge/sticker_host.dart';
import 'features/quick/quick_host.dart';
import 'features/returns/return_screen.dart';
import 'features/share/share_receiver.dart';
import 'features/web/panel_screen.dart';
import 'features/web/tab_busy_screen.dart';
import 'services/panel_bridge.dart';
import 'services/background.dart';
import 'services/crash_reporter.dart';
import 'services/privacy/privacy_service.dart';
import 'services/reminder_actions.dart';
import 'services/reminder_service.dart';
import 'services/vault/vault_layout.dart' show attachmentsDefaultFor;
import 'services/vault/vault_location.dart';
import 'services/vault/vault_writer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isWeb) {
    // одна вкладка на хранилище: две разом испортили бы файлы и базу
    if (!await claimTab()) await _waitForTab();
    // в браузере файлы — свои, поверх личной папки сайта: ставятся до первого File(...)
    await startWebFiles();
    leaveWhenAsked();
    // просим браузер не стирать заметки, когда на диске мало места
    unawaited(persistStorage());
    await _run(const StowaApp(), null, 'web');
    return;
  }
  final notifications = reminderPort(
    // тап по уведомлению: открыть заметку или экран возврата, как только навигатор готов
    onOpen: (payload) => WidgetsBinding.instance.addPostFrameCallback((_) {
      if (notificationRoute(payload) case final route?) appNavigator.currentState?.push(route);
    }),
  );
  await _run(const StowaApp(), notifications, 'main');
}

/// Окно «Поделиться»: его запускает ShareActivity, прозрачное поверх чужого приложения.
@pragma('vm:entry-point')
Future<void> shareMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _run(const StowaApp(home: ShareHost(), lockable: false), reminderPort(), 'share');
}

/// Окно виджета: его запускает QuickActivity, одна строка поверх рабочего стола.
@pragma('vm:entry-point')
Future<void> quickMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _run(const StowaApp(home: QuickHost(), lockable: false), reminderPort(), 'quick');
}

/// Полка «Под рукой»: её запускает EdgeService в окне поверх других приложений.
/// Движок живёт всё время службы: полку открывают и закрывают, а он остаётся тёплым.
@pragma('vm:entry-point')
Future<void> edgeMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _run(const StowaApp(home: EdgeHost(), lockable: false), reminderPort(), 'edge');
}

/// Стикер поверх приложений: его заводит EdgeService из общей группы движков,
/// аргумент — id заметки. Окон до трёх, у каждого свой движок.
@pragma('vm:entry-point')
Future<void> stickerMain(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await _run(StowaApp(home: StickerHost(noteId: args.first), lockable: false), reminderPort(), 'sticker');
}

/// Хранилище занято другой вкладкой: экран об этом, пока та вкладка не закроется сама или
/// по просьбе «Открыть здесь». Возвращается, когда хранилище наше.
Future<void> _waitForTab() async {
  final prefs = await SharedPreferences.getInstance();
  final appearance = SettingsRepository(prefs, const SecureKeyStore()).appearance;
  Tokens.use(paletteFor(appearance, brightnessFor(appearance, PlatformDispatcher.instance.platformBrightness, DateTime.now())));
  final ours = waitForTab();
  Future<void> openHere() {
    askTabToLeave();
    return ours;
  }

  // боковая панель браузера (STOWA-9): базу не открывает, пишет и ищет через вкладку.
  // Вкладку закрыли — хранилище наше, и панель становится полным приложением
  if (isPanelPage()) {
    runApp(PanelApp(client: PanelClient(PanelLink()), onOpenHere: openHere));
    await ours;
    return;
  }
  // хранилище держит панель — обычная вкладка забирает его сама, без «Открыть здесь»:
  // панель дописывает файлы и перезагружается в лёгкий режим
  if (await holderIsPanel()) askTabToLeave();
  runApp(TabBusyApp(onOpenHere: openHere));
  await ours;
}

/// [window] — какое окно запущено: с ним ошибка уходит в отчёт. [notifications] нет
/// в браузере: там напоминания молчат.
Future<void> _run(StowaApp app, LocalNotificationPort? notifications, String window) async {
  // запоминает, по чему нажали: из этого места вырастет следующий экран
  UnfoldTouch.install();
  // сюда выбор файлов, камера и «Поделиться» кладут свои копии: их можно переносить, а не копировать
  final cache = isWeb ? webCacheDirectory : await getTemporaryDirectory();
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsRepository(prefs, const SecureKeyStore());
  // знакомство: кто выбрал место хранилища до этой версии, шагов и подсказок не увидит
  final hints = HintsRepository(prefs);
  await hints.settleOldInstall(vaultAskedBefore: settings.vaultAsked);
  final appSupport = isWeb ? webAppDirectory : await getApplicationSupportDirectory();
  // ошибки ловятся как можно раньше: база и хранилище ниже тоже могут упасть
  final crashes = crashReporterFor(appSupport, settings, window);
  if (!kDebugMode && !isWeb) {
    crashes.attach();
    AppLifecycleListener(onResume: crashes.send);
    // выключили отчёты — накопленное стирается сразу
    settings.watchCrashReports().listen((on) => on ? null : crashes.clear());
  }
  // палитра до первого кадра: выбравший светлую тему не видит вспышку тёмной; обои подъедут следом
  final appearance = settings.appearance;
  Tokens.use(paletteFor(appearance, brightnessFor(appearance, PlatformDispatcher.instance.platformBrightness, DateTime.now())));
  final timeZone = await FlutterTimezone.getLocalTimezone().then((zone) => zone.identifier, onError: (_) => DateTime.now().timeZoneName);
  final home = await vaultHome();

  // открытое хранилище: своя база, место файлов и замок; другое хранилище — новая сессия
  Future<VaultSession> open(AppDatabase? prepared) async {
    final db = prepared ?? AppDatabase.named(settings.vaultDb);
    // хранилище файлами: в базе — пути от его корня; старая установка до переноса — от папки приложения
    final place = await VaultLocation(settings: settings, appSupport: appSupport, home: home).resolve(hasData: await hasSavedItems(db));
    // скрытое, оставшееся открытым от убитого приложения, запечатывается до первого кадра;
    // там же читается замок, чтобы запереть приложение до того, как что-то покажется
    final privacy = PrivacyService(
      db: db,
      vault: place.vault,
      appData: appSupport,
      flush: VaultWriter(db, root: place.vault, clock: DateTime.now, attachmentsDefault: attachmentsDefaultFor(settings.language?.code)).drain,
      fingerprintKey: const SecureKeyStore('sealed_key'),
    );
    await privacy.settle().catchError((_) {});
    return VaultSession(db: db, place: place, lock: privacy.lock);
  }

  final first = await open(null);
  runApp(
    SessionHost(
      first: first,
      open: open,
      app: (session, reopen) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(session.db),
          reopenSessionProvider.overrideWithValue(reopen),
          startFilesRootProvider.overrideWithValue(session.place.files),
          vaultRootProvider.overrideWith(() => VaultRootNotifier(session.place.vault)),
          vaultMissingProvider.overrideWithValue(!session.place.reachable),
          appSupportProvider.overrideWithValue(appSupport),
          vaultHomeProvider.overrideWithValue(home),
          startLockProvider.overrideWithValue(session.lock),
          cacheRootProvider.overrideWithValue(cache),
          notificationPortProvider.overrideWithValue(notifications ?? const SilentNotificationPort()),
          settingsRepositoryProvider.overrideWithValue(settings),
          hintsRepositoryProvider.overrideWithValue(hints),
          preferencesProvider.overrideWithValue(prefs),
          timeZoneProvider.overrideWithValue(timeZone),
        ],
        child: app,
      ),
    ),
  );
  if (notifications != null) unawaited(notifications.start());
  if (!isWeb) {
    unawaited(scheduleBackgroundWork().catchError((_) {}));
    // накопленное с прошлого раза, в том числе падение, после которого приложение открыли заново
    unawaited(crashes.send());
  }
  // таблицы времени ~100 языков собираются при первом разборе: пусть не на первой набранной букве
  WidgetsBinding.instance.addPostFrameCallback((_) => Timer(const Duration(milliseconds: 300), warmUpReminders));
  // проверка сбора на эмуляторе: сборка с --dart-define=CRASH_PROBE=true роняет ошибку сама
  if (_crashProbe) unawaited(Future<void>.delayed(const Duration(seconds: 3), () => throw StateError('crash probe')));
}

const _crashProbe = bool.fromEnvironment('CRASH_PROBE');
