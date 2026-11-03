import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../core/icons/icon_registry.dart';
import '../data/db/database.dart';
import '../data/repositories/tags_repository.dart';
import '../data/settings_repository.dart';
import 'ai_image.dart';
import 'ai_worker.dart';
import 'capture_service.dart';
import 'telegram_service.dart';

const _aiTask = 'stowa-ai-queue';

/// Раз в 15 минут при наличии сети система будит приложение: забирает сообщения бота и разбирает очередь ИИ,
/// даже если его давно не открывали.
Future<void> scheduleBackgroundWork() async {
  await Workmanager().initialize(backgroundDispatcher);
  await Workmanager().registerPeriodicTask(
    _aiTask,
    _aiTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsRepository(prefs, const SecureKeyStore());
    // база общая с открытым приложением, если оно сейчас живо
    final db = AppDatabase();
    final client = http.Client();
    final filesRoot = await getApplicationSupportDirectory();
    try {
      // сперва то, что переслали боту, потом разбор: новое сразу разложится
      final capture = CaptureService(db, tags: TagsRepository(db), filesRoot: filesRoot, clock: DateTime.now);
      await TelegramService(capture: capture, prefs: prefs, tokens: const SecureKeyStore('tg_token'), http: client, inbox: Directory(p.join(filesRoot.path, 'telegram_inbox')))
          .pull()
          .catchError((_) => 0);
      await capture.settled();
      if (settings.ai.active) {
        await AiWorker(
          db,
          settings: settings,
          http: client,
          clock: DateTime.now,
          timeZone: (await FlutterTimezone.getLocalTimezone()).identifier,
          filesRoot: filesRoot,
          imageForAi: imageForAi,
          isIcon: hasSymbol,
        ).drain();
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close();
      await db.close();
    }
  });
}
