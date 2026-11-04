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
import 'file_keeper.dart';
import 'telegram_service.dart';

const _aiTask = 'stowa-ai-queue';
const _fileTask = 'stowa-files';

/// Чужая задача держится столько после последнего знака жизни: фон ждёт её и забирает.
const _abandoned = Duration(seconds: 16);

/// Файлы ещё копируются, а приложение уходит: система доделает сама, без сети,
/// даже если Stowa выгрузят или телефон перезагрузят.
Future<void> scheduleFileWork() async {
  await Workmanager().initialize(backgroundDispatcher);
  await Workmanager().registerOneOffTask(_fileTask, _fileTask, existingWorkPolicy: ExistingWorkPolicy.keep, backoffPolicy: BackoffPolicy.linear, backoffPolicyDelay: const Duration(minutes: 1));
}

/// Разобрать очередь файлов в фоне. Задачу, брошенную закрытым окном, фон дожидается
/// и забирает; не вышло — система повторит позже.
Future<bool> keepFilesInBackground(AppDatabase db, Directory filesRoot) async {
  final files = FileKeeper(db, filesRoot: filesRoot, movable: ownTemporaryFolders(filesRoot, await getTemporaryDirectory()), clock: DateTime.now, runner: 'background');
  for (var round = 0; round < 4; round++) {
    await files.drain();
    final waiting = await db.select(db.fileJobs).get();
    if (waiting.isEmpty) return true;
    await Future<void>.delayed(_abandoned);
  }
  return false;
}

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
      // файлы — прежде всего: без сети и без ключа, просто положить на место
      final filesDone = await keepFilesInBackground(db, filesRoot);
      if (task == _fileTask) return filesDone;
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
