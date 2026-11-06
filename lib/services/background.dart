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
import 'facts/extractors.dart';
import 'facts/facts_pipeline.dart';
import 'facts/web_extractors.dart';
import 'link_preview_service.dart' show httpFetch, httpPost;
import 'file_keeper.dart';
import 'telegram_service.dart';
import 'vault/vault_location.dart';
import 'vault/vault_reader.dart';
import 'vault/vault_sync.dart';
import 'vault/vault_writer.dart';

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
Future<bool> keepFilesInBackground(AppDatabase db, Directory filesRoot, Directory scratch) async {
  final files = FileKeeper(db, filesRoot: filesRoot, movable: ownTemporaryFolders(scratch, await getTemporaryDirectory()), clock: DateTime.now, runner: 'background');
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
    // тот же корень, что у приложения: хранилище или, до переноса, папка приложения
    // временные файлы (голосовые, входящие бота) — во внутренней памяти, не в хранилище
    final scratch = await getApplicationSupportDirectory();
    final place = await VaultLocation(settings: settings, appSupport: scratch).resolve(hasData: true);
    final filesRoot = place.files;
    try {
      // файлы — прежде всего: без сети и без ключа, просто положить на место
      final filesDone = await keepFilesInBackground(db, filesRoot, scratch);
      // и сразу в файлы хранилища: приложение могли закрыть, не дописав очередь
      final vault = VaultSync(reader: VaultReader(db, root: place.vault, clock: DateTime.now), writer: VaultWriter(db, root: place.vault, clock: DateTime.now));
      await vault.run().catchError((_) {});
      // легли файлы или вышла новая версия извлекателей: разобрать, пока приложение закрыто
      final facts = FactsPipeline(
        db,
        filesRoot: filesRoot,
        clock: DateTime.now,
        extractors: [
          ...defaultExtractors(),
          PageExtractor(),
          PageFetchExtractor(fetch: httpFetch),
          SubtitlesExtractor(fetch: httpFetch, post: httpPost, languages: () => subtitleLanguages(settings.language?.code)),
        ],
      );
      await facts.sweep().catchError((_) {});
      if (task == _fileTask) return filesDone;
      // страницы и субтитры — только при сети: периодическая задача её и требует; скачанные
      // копии страниц тут же разбираются местным правилом
      await facts.sweepNetwork().catchError((_) {});
      await facts.sweep().catchError((_) {});
      // сперва то, что переслали боту, потом разбор: новое сразу разложится
      final capture = CaptureService(
        db,
        tags: TagsRepository(db),
        filesRoot: filesRoot,
        clock: DateTime.now,
        files: FileKeeper(db, filesRoot: filesRoot, movable: ownTemporaryFolders(scratch), clock: DateTime.now, runner: 'background'),
      );
      await TelegramService(capture: capture, prefs: prefs, tokens: const SecureKeyStore('tg_token'), http: client, inbox: Directory(p.join(scratch.path, 'telegram_inbox')))
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
      // бот и ИИ поменяли вещи — в файлы
      await vault.run().catchError((_) {});
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close();
      await db.close();
    }
  });
}
