import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_session.dart';
import 'core/theme/tokens.dart';
import 'data/db/database.dart';
import 'data/providers.dart';
import 'data/settings_repository.dart';
import 'domain/appearance.dart';
import 'domain/reminder_parser.dart' show warmUpReminders;
import 'features/edge/edge_probe.dart';
import 'features/quick/quick_host.dart';
import 'features/returns/return_screen.dart';
import 'features/share/share_receiver.dart';
import 'services/background.dart';
import 'services/crash_reporter.dart';
import 'services/privacy/privacy_service.dart';
import 'services/reminder_actions.dart';
import 'services/reminder_service.dart';
import 'services/vault/vault_location.dart';
import 'services/vault/vault_writer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
/// Пока пробная (этап 1 плана), без базы и хранилища.
@pragma('vm:entry-point')
Future<void> edgeMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EdgeProbe());
}

/// [window] — какое окно запущено: с ним ошибка уходит в отчёт.
Future<void> _run(StowaApp app, LocalNotificationPort notifications, String window) async {
  // сюда выбор файлов, камера и «Поделиться» кладут свои копии: их можно переносить, а не копировать
  final cache = await getTemporaryDirectory();
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsRepository(prefs, const SecureKeyStore());
  final appSupport = await getApplicationSupportDirectory();
  // ошибки ловятся как можно раньше: база и хранилище ниже тоже могут упасть
  final crashes = crashReporterFor(appSupport, settings, window);
  if (!kDebugMode) {
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
      flush: VaultWriter(db, root: place.vault, clock: DateTime.now).drain,
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
          notificationPortProvider.overrideWithValue(notifications),
          settingsRepositoryProvider.overrideWithValue(settings),
          preferencesProvider.overrideWithValue(prefs),
          timeZoneProvider.overrideWithValue(timeZone),
        ],
        child: app,
      ),
    ),
  );
  unawaited(notifications.start());
  unawaited(scheduleBackgroundWork().catchError((_) {}));
  // накопленное с прошлого раза, в том числе падение, после которого приложение открыли заново
  unawaited(crashes.send());
  // таблицы времени ~100 языков собираются при первом разборе: пусть не на первой набранной букве
  WidgetsBinding.instance.addPostFrameCallback((_) => Timer(const Duration(milliseconds: 300), warmUpReminders));
  // проверка сбора на эмуляторе: сборка с --dart-define=CRASH_PROBE=true роняет ошибку сама
  if (_crashProbe) unawaited(Future<void>.delayed(const Duration(seconds: 3), () => throw StateError('crash probe')));
}

const _crashProbe = bool.fromEnvironment('CRASH_PROBE');
