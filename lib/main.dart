import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/db/database.dart';
import 'data/providers.dart';
import 'data/settings_repository.dart';
import 'features/item/item_screen.dart';
import 'features/share/share_receiver.dart';
import 'services/background.dart';
import 'services/reminder_actions.dart';
import 'services/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = reminderPort(
    // тап по уведомлению: открыть вещь, как только навигатор готов
    onOpen: (id) => WidgetsBinding.instance.addPostFrameCallback((_) => appNavigator.currentState?.push(itemRoute(id))),
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
  // вложения лежат рядом с базой, в базе — пути от этой папки
  final filesRoot = await getApplicationSupportDirectory();
  final settings = SettingsRepository(await SharedPreferences.getInstance(), const SecureKeyStore());
  final timeZone = await FlutterTimezone.getLocalTimezone().then((zone) => zone.identifier, onError: (_) => DateTime.now().timeZoneName);
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(AppDatabase()),
        filesRootProvider.overrideWithValue(filesRoot),
        notificationPortProvider.overrideWithValue(notifications),
        settingsRepositoryProvider.overrideWithValue(settings),
        timeZoneProvider.overrideWithValue(timeZone),
      ],
      child: app,
    ),
  );
  unawaited(notifications.start());
  unawaited(scheduleBackgroundWork().catchError((_) {}));
}
