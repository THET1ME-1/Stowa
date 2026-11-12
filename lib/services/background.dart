import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

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
import '../l10n/app_language.dart';
import '../l10n/app_localizations.dart';
import 'ai_image.dart';
import 'ai_worker.dart';
import 'capture_service.dart';
import 'crash_reporter.dart';
import 'fact_rules.dart';
import 'facts/extractors.dart';
import 'facts/facts_pipeline.dart';
import 'facts/web_extractors.dart';
import 'link_checker.dart';
import 'link_preview_service.dart' show httpFetch, httpFetchWith, httpPost, onWifi;
import 'file_keeper.dart';
import 'place_alarms.dart';
import 'place_channel.dart';
import 'privacy/privacy_service.dart';
import 'reminder_actions.dart';
import 'return_service.dart';
import 'telegram_service.dart';
import 'vault/vault_location.dart';
import 'vault/vault_reader.dart';
import 'vault/vault_sync.dart';
import 'vault/vault_writer.dart';

const _aiTask = 'stowa-ai-queue';
const _fileTask = 'stowa-files';

/// Вернуть сохранённое: вечернее окно проверяется раз в 15 минут, сеть не нужна.
const _returnTask = 'stowa-return';

/// Битые ссылки: раз в неделю по Wi-Fi.
const _linksTask = 'stowa-links';

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
  // без сети: «посмотреть потом» и «в этот день» решаются по базе на телефоне
  await Workmanager().registerPeriodicTask(_returnTask, _returnTask, frequency: const Duration(minutes: 15), existingWorkPolicy: ExistingPeriodicWorkPolicy.keep);
  // битые ссылки — раз в неделю и только по Wi-Fi: мобильный трафик на это не тратится
  await Workmanager().registerPeriodicTask(
    _linksTask,
    _linksTask,
    frequency: linkCheckInterval,
    constraints: Constraints(networkType: NetworkType.unmetered),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

/// Проход возврата в фоне: решить и, если пора, показать одно тихое уведомление.
Future<void> returnInBackground(AppDatabase db, SharedPreferences prefs, SettingsRepository settings) async {
  final language = settings.language ?? AppLanguage.resolve(PlatformDispatcher.instance.locales);
  final l = lookupL(language.locale);
  final port = reminderPort();
  await ReturnService(db, prefs: prefs, port: port, clock: DateTime.now, settings: () => settings.returns, l: () => l).tick();
  // сработавшее по месту, пока приложение закрыто, снимается в базе; тревоги ставятся заново
  await PlaceAlarmService(db, channel: const MethodPlaceChannel(), settings: () => settings.returns, l: () => l).sync().catchError((_) {});
}

@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsRepository(prefs, const SecureKeyStore());
    // временные файлы (голосовые, входящие бота) и очередь отчётов — во внутренней памяти, не в хранилище
    final scratch = await getApplicationSupportDirectory();
    // сорванная задача молчит: без отчёта о ней никто не узнает
    final crashes = crashReporterFor(scratch, settings, 'background');
    // база общая с открытым приложением, если оно сейчас живо
    final db = AppDatabase();
    // возврат — короткий проход по базе: хранилище, факты и сеть ему не нужны
    if (task == _returnTask) {
      try {
        await returnInBackground(db, prefs, settings);
        return true;
      } catch (error, stack) {
        crashes.record(error, stack);
        return false;
      } finally {
        await db.close();
      }
    }
    // проверка ссылок пишет только в базу: файлы хранилища она не меняет
    if (task == _linksTask) {
      try {
        await LinkChecker(db, clock: DateTime.now).run();
        return true;
      } catch (error, stack) {
        crashes.record(error, stack);
        return false;
      } finally {
        await db.close();
      }
    }
    final client = http.Client();
    // тот же корень, что у приложения: хранилище или, до переноса, папка приложения
    final place = await VaultLocation(settings: settings, appSupport: scratch).resolve(hasData: true);
    final filesRoot = place.files;
    try {
      // скрытое: открыто в живом приложении — знать его заметки; осталось от убитого — запечатать
      await PrivacyService(
        db: db,
        vault: place.vault,
        appData: scratch,
        flush: VaultWriter(db, root: place.vault, clock: DateTime.now).drain,
        fingerprintKey: const SecureKeyStore('sealed_key'),
      ).settle().catchError((_) {});
      // файлы — прежде всего: без сети и без ключа, просто положить на место
      final filesDone = await keepFilesInBackground(db, filesRoot, scratch);
      // и сразу в файлы хранилища: приложение могли закрыть, не дописав очередь
      final vault = VaultSync(reader: VaultReader(db, root: place.vault, clock: DateTime.now), writer: VaultWriter(db, root: place.vault, clock: DateTime.now));
      await vault.run().catchError((_) {});
      // легли файлы или вышла новая версия извлекателей: разобрать, пока приложение закрыто.
      // Правила по фактам — после разбора и по очереди: фоновая задача не ждёт брошенных
      final touched = <String>{};
      final facts = FactsPipeline(
        db,
        filesRoot: filesRoot,
        clock: DateTime.now,
        onFacts: touched.add,
        extractors: [
          ...defaultExtractors(),
          PageExtractor(),
          ArticleExtractor(),
          if (settings.articleImages) ArticleImagesExtractor(fetch: httpFetchWith, onWifi: onWifi),
          PageFetchExtractor(fetch: httpFetch),
          SubtitlesExtractor(fetch: httpFetch, post: httpPost, languages: () => subtitleLanguages(settings.language?.code)),
        ],
      );
      final rules = FactRules(db);
      Future<void> applyRules() async {
        for (final id in [...touched]) {
          await rules.apply(id).catchError((_) {});
        }
        touched.clear();
      }

      await facts.sweep().catchError((_) {});
      await applyRules();
      if (task == _fileTask) return filesDone;
      // страницы и субтитры — только при сети: периодическая задача её и требует; скачанные
      // копии страниц тут же разбираются местным правилом
      await facts.sweepNetwork().catchError((_) {});
      await facts.sweep().catchError((_) {});
      await applyRules();
      // сперва то, что переслали боту, потом разбор: новое сразу разложится
      final capture = CaptureService(
        db,
        tags: TagsRepository(db),
        filesRoot: filesRoot,
        clock: DateTime.now,
        files: FileKeeper(db, filesRoot: filesRoot, movable: ownTemporaryFolders(scratch), clock: DateTime.now, runner: 'background'),
        aiFirst: () => settings.ai.aiFirst,
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
      // сеть есть: заодно уходят накопленные отчёты, и свои, и от окон
      await crashes.send(client);
      return true;
    } catch (error, stack) {
      crashes.record(error, stack);
      return false;
    } finally {
      client.close();
      await db.close();
    }
  });
}
