import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme/tokens.dart';
import 'data/db/database.dart';
import 'data/providers.dart';
import 'data/settings_repository.dart';
import 'domain/appearance.dart';
import 'features/returns/return_screen.dart';
import 'features/share/share_receiver.dart';
import 'services/background.dart';
import 'services/reminder_actions.dart';
import 'services/reminder_service.dart';
import 'services/vault/vault_location.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = reminderPort(
    // тап по уведомлению: открыть заметку или экран возврата, как только навигатор готов
    onOpen: (payload) => WidgetsBinding.instance.addPostFrameCallback((_) {
      if (notificationRoute(payload) case final route?) appNavigator.currentState?.push(route);
    }),
  );
  await _run(const StowaApp(), notifications);
}

/// Окно «Поделиться»: его запускает ShareActivity, прозрачное поверх чужого приложения.
@pragma('vm:entry-point')
Future<void> shareMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _run(const StowaApp(home: ShareHost()), reminderPort());
}

Future<void> _run(StowaApp app, LocalNotificationPort notifications) async {
  // сюда выбор файлов, камера и «Поделиться» кладут свои копии: их можно переносить, а не копировать
  final cache = await getTemporaryDirectory();
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsRepository(prefs, const SecureKeyStore());
  // палитра до первого кадра: выбравший светлую тему не видит вспышку тёмной; обои подъедут следом
  final appearance = settings.appearance;
  Tokens.use(paletteFor(appearance, brightnessFor(appearance, PlatformDispatcher.instance.platformBrightness, DateTime.now())));
  final timeZone = await FlutterTimezone.getLocalTimezone().then((zone) => zone.identifier, onError: (_) => DateTime.now().timeZoneName);
  final db = AppDatabase();
  final appSupport = await getApplicationSupportDirectory();
  // хранилище файлами: в базе — пути от его корня; старая установка до переноса — от папки приложения
  final place = await VaultLocation(settings: settings, appSupport: appSupport).resolve(hasData: await hasSavedItems(db));
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        startFilesRootProvider.overrideWithValue(place.files),
        vaultRootProvider.overrideWith(() => VaultRootNotifier(place.vault)),
        vaultMissingProvider.overrideWithValue(!place.reachable),
        appSupportProvider.overrideWithValue(appSupport),
        cacheRootProvider.overrideWithValue(cache),
        notificationPortProvider.overrideWithValue(notifications),
        settingsRepositoryProvider.overrideWithValue(settings),
        preferencesProvider.overrideWithValue(prefs),
        timeZoneProvider.overrideWithValue(timeZone),
      ],
      child: app,
    ),
  );
  unawaited(notifications.start());
  unawaited(scheduleBackgroundWork().catchError((_) {}));
}
