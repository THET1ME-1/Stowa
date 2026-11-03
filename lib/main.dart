import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/db/database.dart';
import 'data/providers.dart';
import 'features/item/item_screen.dart';
import 'l10n/app_language.dart';
import 'l10n/app_localizations.dart';
import 'services/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // вложения лежат рядом с базой, в базе — пути от этой папки
  final filesRoot = await getApplicationSupportDirectory();
  final language = AppLanguage.resolve(PlatformDispatcher.instance.locales);
  final notifications = LocalNotificationPort(
    channelName: lookupL(language.locale).reminderChannel,
    // тап по уведомлению: открыть вещь, как только навигатор готов
    onOpen: (id) => WidgetsBinding.instance.addPostFrameCallback((_) => appNavigator.currentState?.push(itemRoute(id))),
  );
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(AppDatabase()),
        filesRootProvider.overrideWithValue(filesRoot),
        notificationPortProvider.overrideWithValue(notifications),
      ],
      child: const StowaApp(),
    ),
  );
  unawaited(notifications.start());
}
