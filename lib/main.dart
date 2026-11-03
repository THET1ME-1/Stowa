import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/db/database.dart';
import 'data/providers.dart';
import 'features/item/item_screen.dart';
import 'services/reminder_actions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // вложения лежат рядом с базой, в базе — пути от этой папки
  final filesRoot = await getApplicationSupportDirectory();
  final notifications = reminderPort(
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
