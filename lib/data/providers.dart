import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show BaseAggregate, DriftSqlType, OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/icons/icon_registry.dart';
import '../domain/folder_guess.dart';
import '../domain/models.dart' show FactKind;
import '../domain/place_groups.dart' show guessHomeAndWork;
import '../domain/related.dart';
import '../services/ai_image.dart';
import '../services/ai_worker.dart';
import '../services/auto_sorter.dart';
import '../services/backup_service.dart';
import '../services/background.dart';
import '../services/capture_service.dart';
import '../services/facts/extractors.dart';
import '../services/facts/facts_pipeline.dart';
import '../services/facts/web_extractors.dart';
import '../services/file_keeper.dart';
import '../services/link_preview_service.dart';
import '../services/place_channel.dart';
import '../services/place_service.dart';
import '../services/reminder_service.dart';
import '../services/telegram_service.dart';
import '../services/vault/vault_location.dart';
import '../services/vault/vault_reader.dart';
import '../services/vault/vault_sync.dart';
import '../services/vault/vault_writer.dart';
import 'db/database.dart';
import 'repositories/canvas_repository.dart';
import 'repositories/folders_repository.dart';
import 'repositories/items_repository.dart';
import 'repositories/places_repository.dart';
import 'repositories/return_repository.dart';
import 'repositories/rules_repository.dart';
import 'repositories/tags_repository.dart';
import 'repositories/trash_repository.dart';
import 'settings_repository.dart';

/// База и папка файлов открываются в main и подставляются сюда.
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('база открывается в main'));

/// Корень файлов этого запуска (`VaultLocation.resolve`): хранилище или, до переноса, папка приложения.
final startFilesRootProvider = Provider<Directory>((ref) => throw UnimplementedError('папка файлов задаётся в main'));

/// От этой папки считаются все пути в базе: хранилище, когда оно есть, иначе корень запуска.
/// Перенесли хранилище — корень меняется на ходу.
final filesRootProvider = Provider<Directory>((ref) => ref.watch(vaultRootProvider) ?? ref.watch(startFilesRootProvider));

/// Хранилище недоступно: папку удалили или отозвали разрешение.
final vaultMissingProvider = Provider<bool>((ref) => false);

/// Папка приложения: в ней хранилище «внутри приложения».
final appSupportProvider = Provider<Directory>((ref) => throw UnimplementedError('папка приложения задаётся в main'));

/// Временные файлы приложения: голосовые до сохранения, входящие бота. Всегда во внутренней
/// памяти: в хранилище их увидел бы Obsidian, а Syncthing гонял бы недописанное.
final scratchRootProvider = Provider<Directory>((ref) => ref.watch(appSupportProvider));

/// Разрешение «Доступ ко всем файлам».
final vaultChannelProvider = Provider<VaultChannel>((ref) => const VaultChannel());

/// Выбор папки системным окном; в тестах — готовая папка.
final vaultPickerProvider = Provider<Future<String?> Function()>((ref) => pickVaultFolder);

/// Где хранилище и доступно ли оно.
final vaultLocationProvider = Provider(
  (ref) => VaultLocation(settings: ref.watch(settingsRepositoryProvider), appSupport: ref.watch(appSupportProvider), channel: ref.watch(vaultChannelProvider)),
);

/// Место хранилища уже выбирали на экране первого запуска.
final vaultAskedProvider = Provider<bool>((ref) => ref.watch(settingsRepositoryProvider).vaultAsked);

/// Часы: в тестах подменяются, чтобы «завтра» было предсказуемым.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final itemsRepositoryProvider = Provider((ref) {
  final facts = ref.watch(factsPipelineProvider);
  return ItemsRepository(ref.watch(databaseProvider))..onEdited = (id) => facts.runItem(id).ignore();
});

/// Показывать ли обложки и описания 18+: решает человек в настройках.
final showAdultProvider = StreamProvider((ref) => ref.watch(settingsRepositoryProvider).watchShowAdult());

/// Что и когда возвращать уведомлениями.
final returnSettingsProvider = StreamProvider((ref) => ref.watch(settingsRepositoryProvider).watchReturns());

final returnRepositoryProvider = Provider((ref) => ReturnRepository(ref.watch(databaseProvider)));

/// Карточку «Возвращать сохранённое?» уже показывали.
final returnsAskedProvider = StreamProvider((ref) => ref.watch(settingsRepositoryProvider).watchReturnsAsked());

/// Очередь «посмотреть потом», «в этот день», неделя и покупки — живые: экраны и пилюли главной.
final watchLaterProvider = StreamProvider.autoDispose((ref) {
  final returns = ref.watch(returnRepositoryProvider);
  final clock = ref.watch(clockProvider);
  return returns.watch(() => returns.watchLater(clock()), clock: clock);
});
final onThisDayProvider = StreamProvider.autoDispose((ref) {
  final returns = ref.watch(returnRepositoryProvider);
  final clock = ref.watch(clockProvider);
  return returns.watch(() => returns.onThisDay(clock()), clock: clock);
});
final weekReturnProvider = StreamProvider.autoDispose((ref) {
  final returns = ref.watch(returnRepositoryProvider);
  final clock = ref.watch(clockProvider);
  return returns.watch(() => returns.week(clock()), clock: clock);
});
final shoppingProvider = StreamProvider.autoDispose((ref) {
  final returns = ref.watch(returnRepositoryProvider);
  return returns.watch(returns.shopping);
});

/// Карточки этих заметок по порядку.
final cardsProvider = StreamProvider.autoDispose.family<List<ItemCard>, String>((ref, joinedIds) {
  final ids = joinedIds.isEmpty ? const <String>[] : joinedIds.split('\x1f');
  return ref.watch(itemsRepositoryProvider).watchCards(ids);
});

/// Вещи, страницы которых сказали о себе «18+».
final adultItemsProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.facts)..where((t) => t.kind.equals(FactKind.adult.name))).watch().map((rows) => {for (final row in rows) row.itemId});
});

/// Факты одной вещи по порядку: для страницы вещи.
final itemFactsProvider = StreamProvider.autoDispose.family<List<Fact>, String>((ref, itemId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.facts)
        ..where((t) => t.itemId.equals(itemId))
        ..orderBy([(t) => OrderingTerm.asc(t.extractor), (t) => OrderingTerm.asc(t.position)]))
      .watch();
});

/// Конвейер извлекателей: деньги, контакты, текст документов, EXIF, автор и сайт ссылки.
/// Один на окно и зависит только от неизменного, как хранитель файлов.
final factsPipelineProvider = Provider((ref) {
  final fetch = ref.watch(linkFetchProvider);
  return FactsPipeline(
    ref.watch(databaseProvider),
    filesRoot: ref.watch(filesRootProvider),
    clock: ref.watch(clockProvider),
    online: () async => ref.read(onlineProvider).value ?? true,
    extractors: [
      ...defaultExtractors(),
      PageExtractor(),
      ArticleExtractor(),
      PageFetchExtractor(fetch: fetch),
      SubtitlesExtractor(fetch: fetch, post: ref.watch(linkPostProvider), languages: () => subtitleLanguages(ref.read(languageProvider).value?.code)),
    ],
  );
});
final foldersRepositoryProvider = Provider((ref) => FoldersRepository(ref.watch(databaseProvider)));
final tagsRepositoryProvider = Provider((ref) => TagsRepository(ref.watch(databaseProvider), clock: ref.watch(clockProvider)));

/// Кэш приложения: туда кладут файлы выбор файлов, камера и «Поделиться». Задаётся в main.
final cacheRootProvider = Provider<Directory?>((ref) => null);

/// Попросить систему доделать копирование файлов в фоне. Тесты подменяют.
final fileWorkProvider = Provider<Future<void> Function()>((ref) => () => scheduleFileWork().catchError((_) {}));

/// Хранитель файлов — один на окно и зависит только от неизменного. Сервис сохранения
/// пересоздаётся вместе с ИИ и местом; заведи он своего хранителя, старый копировал бы
/// дальше, а лента слушала бы новый, молчащий.
final fileKeeperProvider = Provider((ref) {
  final filesRoot = ref.watch(filesRootProvider);
  final facts = ref.watch(factsPipelineProvider);
  return FileKeeper(
    ref.watch(databaseProvider),
    filesRoot: filesRoot,
    movable: ownTemporaryFolders(ref.watch(scratchRootProvider), ref.watch(cacheRootProvider)),
    clock: ref.watch(clockProvider),
    onLeftover: ref.watch(fileWorkProvider),
  )..onKept = (id) => facts.runItem(id).ignore();
});

final captureServiceProvider = Provider((ref) {
  final sorter = ref.watch(autoSorterProvider);
  final drain = ref.watch(aiDrainProvider);
  final stamp = ref.watch(placeStampProvider);
  final facts = ref.watch(factsPipelineProvider);
  return CaptureService(
    ref.watch(databaseProvider),
    tags: ref.watch(tagsRepositoryProvider),
    filesRoot: ref.watch(filesRootProvider),
    clock: ref.watch(clockProvider),
    files: ref.watch(fileKeeperProvider),
  )
    // теги соседей и разбор ИИ идут после сохранения: строка не ждёт ни того, ни другого
    ..afterCapture = (id) {
      sorter.tagItem(id).ignore();
      drain().ignore();
      // деньги, телефоны и ссылки из текста — сразу; из файлов — когда они лягут
      facts.runItem(id).ignore();
    }
    // перенос пачками: теги соседей одним индексом, факты одним проходом по всем, кому нужно
    ..afterBatch = (ids) {
      sorter.tagItems(ids).ignore();
      drain().ignore();
      facts.sweep().ignore();
    }
    ..stampPlace = (id) => stamp(id).ignore();
});

/// Поставить вещи место. Тесты подменяют пустышкой: GPS там нет.
final placeStampProvider = Provider<Future<void> Function(String itemId)>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  final service = PlaceService(
    ref.watch(databaseProvider),
    source: DevicePlaceSource(client: ref.watch(aiHttpProvider), language: () => settings.language?.code ?? PlatformDispatcher.instance.locale.languageCode),
    clock: ref.watch(clockProvider),
    enabled: () => settings.placeEnabled,
  );
  return service.stamp;
});

/// Вещи с местом: точки карты.
final placedItemsProvider = StreamProvider((ref) => ref.watch(itemsRepositoryProvider).watchPlaced());

/// Где человек сейчас: кнопка «где я» на карте. Тесты подменяют.
final whereAmIProvider = Provider<Future<(double, double)?> Function()>(
  (ref) => () async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(accuracy: LocationAccuracy.high, forceLocationManager: true, timeLimit: const Duration(seconds: 15)),
      );
      return (position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  },
);

/// Отмеченные места: дом, работа, магазины.
final placesRepositoryProvider = Provider((ref) => PlacesRepository(ref.watch(databaseProvider), clock: ref.watch(clockProvider)));
final placesProvider = StreamProvider((ref) => ref.watch(placesRepositoryProvider).watchAll());

/// Android: место «всегда», имя Wi-Fi, тревоги по месту. Тесты подменяют.
final placeChannelProvider = Provider<PlaceChannel>((ref) => const MethodPlaceChannel());

/// Где телефон сейчас, с названием: «Я сейчас дома», «Я в магазине», «Напомнить здесь».
/// Точка отмечается надолго, поэтому свежая (до 30 с) и точная. Тесты подменяют.
final currentPlaceProvider = Provider<Future<PlaceFix?> Function()>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  final source = DevicePlaceSource(
    client: ref.watch(aiHttpProvider),
    language: () => settings.language?.code ?? PlatformDispatcher.instance.locale.languageCode,
    maxAge: const Duration(seconds: 30),
    accuracy: LocationAccuracy.high,
  );
  return source.current;
});

/// Тронули заметки, теги или места — тревоги по месту, может быть, пора переставить.
final placeChangesProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.customSelect('SELECT 1', readsFrom: {db.items, db.places, db.itemTags, db.tags}).watch();
});

/// Место «пока открыто» разрешено. Тесты подменяют.
final placeGrantedProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  } catch (_) {
    return false;
  }
});

/// Спросить место — по действию человека (включил «Запоминать, где сохранено»), не при сохранении.
final askPlaceProvider = Provider<Future<bool> Function()>(
  (ref) => () async {
    try {
      final permission = await Geolocator.requestPermission();
      return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  },
);

/// Есть напоминание по месту, а места «всегда» нет: оно молча не сработает. Карточка на главной.
/// Разрешение меняют в системных настройках — главная пересчитывает при возврате в приложение.
final placeNeedsAlwaysProvider = StreamProvider.autoDispose<bool>((ref) {
  final db = ref.watch(databaseProvider);
  final channel = ref.watch(placeChannelProvider);
  final waiting = db.customSelect('SELECT count(*) AS n FROM items WHERE remind_place IS NOT NULL AND deleted_at IS NULL', readsFrom: {db.items}).watchSingle();
  return waiting.asyncMap((row) async => row.read<int>('n') > 0 && !await channel.hasBackground());
});

/// «Похоже, дом — Ботаника»: где сохраняют ночью и в будни днём.
final placeGuessProvider = FutureProvider.autoDispose((ref) async => guessHomeAndWork(await ref.watch(placesRepositoryProvider).savedPoints()));

/// Где телефон для «рядом» в поиске: последнее известное место сразу, без него — свежее.
final searchHereProvider = Provider<Future<(double, double)?> Function()>((ref) {
  final whereAmI = ref.watch(whereAmIProvider);
  return () async {
    try {
      final known = await Geolocator.getLastKnownPosition(forceAndroidLocationManager: true);
      if (known != null) return (known.latitude, known.longitude);
    } catch (_) {
      // нет разрешения или плагина: спросит whereAmI
    }
    return whereAmI();
  };
});

/// Запоминать ли место: переключатель в настройках.
final placeEnabledProvider = StreamProvider((ref) => ref.watch(settingsRepositoryProvider).watchPlaceEnabled());

/// Файлы, которые не скопировались при сохранении.
final copyFailuresProvider = StreamProvider((ref) => ref.watch(fileKeeperProvider).failures);

/// Сколько скопировано у вещей, чьи файлы ещё ложатся: от 0 до 1.
/// Ход одной вещи для полоски: свой — сразу по событиям, чужой — раз в секунду по
/// недописанному файлу. Живёт, только пока полоска на экране.
final copyFractionProvider = StreamProvider.autoDispose.family<double?, String>((ref, itemId) {
  final files = ref.watch(fileKeeperProvider);
  final controller = StreamController<double?>();
  Future<void> poll() async {
    final fraction = await files.fractionOf(itemId);
    if (!controller.isClosed) controller.add(fraction);
  }

  final own = files.progress.listen((all) {
    final fraction = all[itemId];
    if (fraction != null && !controller.isClosed) controller.add(fraction);
  });
  final timer = Timer.periodic(const Duration(seconds: 1), (_) => poll().ignore());
  poll().ignore();
  ref.onDispose(() {
    own.cancel();
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Новый подписчик сразу получает то, что уже скопировано, а не ждёт следующего процента.
final fileProgressProvider = StreamProvider<Map<String, double>>((ref) async* {
  final files = ref.watch(fileKeeperProvider);
  yield files.current;
  yield* files.progress;
});

/// Настройки и ключ ИИ. SharedPreferences открываются в main.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => throw UnimplementedError('настройки открываются в main'));
final aiSettingsProvider = StreamProvider((ref) => ref.watch(settingsRepositoryProvider).watchAi());

/// Пояс устройства для напоминаний от ИИ: main подставляет имя вроде Europe/Chisinau.
final timeZoneProvider = Provider<String>((ref) => DateTime.now().timeZoneName);

/// Сеть до поставщика ИИ. Тесты подставляют поддельного поставщика.
final aiHttpProvider = Provider<http.Client>((ref) => http.Client());

final aiWorkerProvider = Provider(
  (ref) => AiWorker(
    ref.watch(databaseProvider),
    settings: ref.watch(settingsRepositoryProvider),
    http: ref.watch(aiHttpProvider),
    clock: ref.watch(clockProvider),
    timeZone: ref.watch(timeZoneProvider),
    filesRoot: ref.watch(filesRootProvider),
    imageForAi: imageForAi,
    isIcon: hasSymbol,
  ),
);

/// Разобрать всё, что ждёт ИИ. Тесты подменяют пустышкой: ключа и сети там нет.
final aiDrainProvider = Provider<Future<void> Function()>((ref) => ref.watch(aiWorkerProvider).drain);

/// Вещи, которые ИИ только что положил в папку: плашка «Положил в …».
final aiSortedProvider = StreamProvider((ref) => ref.watch(aiWorkerProvider).sorted);

/// Последние 50 запросов к поставщику с названием вещи: экран журнала в настройках.
final aiLogProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT ai_log.at, ai_log.error, items.title FROM ai_log LEFT JOIN items ON items.id = ai_log.item_id ORDER BY ai_log.id DESC LIMIT 50',
        readsFrom: {db.aiLog, db.items},
      )
      .watch()
      .map(
        (rows) => [
          for (final row in rows)
            (at: db.typeMapping.read(DriftSqlType.dateTime, row.data['at'])!, error: row.readNullable<String>('error'), title: row.readNullable<String>('title')),
        ],
      );
});

/// Разбор идёт прямо сейчас.
final aiBusyProvider = StreamProvider((ref) => ref.watch(aiWorkerProvider).busy);

/// Сколько вещей ждёт ИИ: в настройках рядом с «Разобрать сейчас».
final aiQueueProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  final count = db.aiJobs.itemId.count();
  return (db.selectOnly(db.aiJobs)..addColumns([count])).map((row) => row.read(count) ?? 0).watchSingle();
});

/// Появилась сеть: очередь ИИ и превью идут сразу, не дожидаясь фона.
final onlineProvider = StreamProvider<bool>(
  (ref) => Connectivity().onConnectivityChanged.map((kinds) => kinds.any((kind) => kind != ConnectivityResult.none)).distinct(),
);

/// Удалённое: лежит 30 дней, потом стирается вместе с файлами.
final trashRepositoryProvider = Provider((ref) => TrashRepository(ref.watch(databaseProvider), filesRoot: ref.watch(filesRootProvider)));
final trashProvider = StreamProvider((ref) => ref.watch(trashRepositoryProvider).watch());

/// SharedPreferences открываются в main.
final preferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('настройки открываются в main'));

/// Свой бот Telegram: токен в защищённом хранилище, скачанное ждёт копирования в папке бота.
final telegramServiceProvider = Provider(
  (ref) => TelegramService(
    capture: ref.watch(captureServiceProvider),
    prefs: ref.watch(preferencesProvider),
    tokens: const SecureKeyStore('tg_token'),
    http: ref.watch(aiHttpProvider),
    inbox: Directory('${ref.watch(scratchRootProvider).path}/telegram_inbox'),
  ),
);
final telegramStateProvider = StreamProvider((ref) => ref.watch(telegramServiceProvider).watch());

/// Забрать сообщения бота. Тесты подменяют пустышкой.
final telegramPullProvider = Provider<Future<int> Function()>((ref) => ref.watch(telegramServiceProvider).pull);

final backupServiceProvider = Provider(
  (ref) => BackupService(ref.watch(databaseProvider), filesRoot: ref.watch(filesRootProvider), vault: ref.watch(vaultRootProvider) != null, clock: ref.watch(clockProvider)),
);

/// Язык, выбранный в настройках; null — язык устройства.
final languageProvider = StreamProvider((ref) => ref.watch(settingsRepositoryProvider).watchLanguage());

/// Сеть для превью. Тесты подставляют свою, без интернета.
final linkFetchProvider = Provider<Fetch>((ref) => httpFetch);

/// Запрос со своими заголовками: API сайтов Lib. Тесты подставляют свой.
final linkFetchWithProvider = Provider<FetchWith>((ref) => httpFetchWith);

/// Запрос с телом: плеер YouTube за дорожками субтитров. Тесты подставляют свой.
final linkPostProvider = Provider<Post>((ref) => httpPost);

/// Разбор без ИИ после сохранения: «Без папки» заново и теги соседей.
final autoSorterProvider = Provider((ref) => AutoSorter(ref.watch(databaseProvider)));

final linkPreviewServiceProvider = Provider((ref) {
  final sorter = ref.watch(autoSorterProvider);
  return LinkPreviewService(
    ref.watch(databaseProvider),
    filesRoot: ref.watch(filesRootProvider),
    clock: ref.watch(clockProvider),
    fetch: ref.watch(linkFetchProvider),
    fetchWith: ref.watch(linkFetchWithProvider),
    // у ссылки появились заголовок и описание страницы — по ним уже есть что угадывать
    onPreviewed: (id) async {
      // автор и описание сразу ищутся; рецепт, товар, событие — из только что сохранённой копии страницы,
      // субтитры ролика — пока сеть есть
      await ref.read(factsPipelineProvider).runItem(id, network: true);
      await sorter.sortInbox(onlyId: id);
      await sorter.tagItem(id);
      // ссылку, ждавшую превью, ИИ теперь видит с заголовком страницы
      await ref.read(aiDrainProvider)();
    },
  );
});

/// Сколько раз человек перекладывал вещи сам: после каждого раза «Без папки» разбирается заново.
final manualMovesProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  final count = db.corrections.id.count();
  return (db.selectOnly(db.corrections)..addColumns([count])).map((row) => row.read(count) ?? 0).watchSingle();
});

/// Ссылки и ролики без превью: их разбирает фоновая очередь главной.
final pendingPreviewsProvider = StreamProvider((ref) => watchPendingPreviews(ref.watch(databaseProvider)));

/// Корень хранилища файлами; null — хранилище ещё не выбрано, правки копятся в очереди.
final vaultRootProvider = NotifierProvider<VaultRootNotifier, Directory?>(VaultRootNotifier.new);

class VaultRootNotifier extends Notifier<Directory?> {
  VaultRootNotifier([this._start]);

  final Directory? _start;

  @override
  Directory? build() => _start;

  /// Хранилище выбрали или перенесли.
  void change(Directory? root) => state = root;
}

/// Переносит правки из базы в файлы хранилища.
final vaultWriterProvider = Provider((ref) => VaultWriter(ref.watch(databaseProvider), root: ref.watch(vaultRootProvider), clock: ref.watch(clockProvider)));

/// Забирает в базу правки, сделанные в файлах снаружи.
final vaultReaderProvider = Provider((ref) => VaultReader(ref.watch(databaseProvider), root: ref.watch(vaultRootProvider), clock: ref.watch(clockProvider)));

/// Сверка хранилища: сперва чужие правки, потом свои.
final vaultSyncProvider = Provider((ref) => VaultSync(reader: ref.watch(vaultReaderProvider), writer: ref.watch(vaultWriterProvider)));

/// Сколько задач ждёт записи в хранилище: изменилось — главная разбирает очередь.
/// Очередь записи хранилища: (задач, сумма версий) — меняется и от новой правки поверх старой.
final vaultQueueProvider = StreamProvider((ref) => ref.watch(databaseProvider).watchVaultQueue());

final recentItemsProvider = StreamProvider((ref) => ref.watch(itemsRepositoryProvider).watchRecent());

/// Сколько всего живых заметок: подпись под именем приложения на главной.
final notesCountProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.customSelect('SELECT count(*) AS n FROM items WHERE deleted_at IS NULL', readsFrom: {db.items}).watchSingle().map((row) => row.read<int>('n'));
});

/// Ближайшие напоминания с момента подписки. Главная перечитывает их,
/// когда приложение возвращается на экран.
final upcomingProvider = StreamProvider((ref) => ref.watch(itemsRepositoryProvider).watchUpcoming(ref.watch(clockProvider)()));

final foldersProvider = StreamProvider((ref) => ref.watch(foldersRepositoryProvider).watchAll());
final pinnedTagsProvider = StreamProvider((ref) => ref.watch(tagsRepositoryProvider).watchPinned());
final allTagsProvider = StreamProvider((ref) => ref.watch(tagsRepositoryProvider).watchAll());

/// Угадыватель папки по тому, что уже разложено. Пересобирается вместе с базой.
final folderIndexProvider = StreamProvider((ref) => ref.watch(itemsRepositoryProvider).watchFolderDocs().map(FolderIndex.new));

final rulesRepositoryProvider = Provider((ref) => RulesRepository(ref.watch(databaseProvider)));
final rulesProvider = StreamProvider((ref) => ref.watch(rulesRepositoryProvider).watchEnabled());

/// Все правила вместе с выключенными: экран правил.
final allRulesProvider = StreamProvider((ref) => ref.watch(rulesRepositoryProvider).watchAll());

/// Вещи, связанные с открытой, с причиной: общие редкие слова или сайт.
final relatedProvider = StreamProvider.family<List<({ItemCard card, Related why})>, String>((ref, id) => ref.watch(itemsRepositoryProvider).watchRelated(id));

/// Одна вещь целиком для её страницы, обновляется вместе с базой.
final itemProvider = StreamProvider.family<ItemFull?, String>((ref, id) => ref.watch(itemsRepositoryProvider).watchItem(id));

/// Другая заметка с той же ссылкой или картинкой: строка на странице заметки.
final repeatProvider = StreamProvider.autoDispose.family<RepeatNote?, String>((ref, id) => ref.watch(itemsRepositoryProvider).watchRepeatOf(id));

/// Система уведомлений: настоящая подставляется в main, в тестах — тишина.
final notificationPortProvider = Provider<NotificationPort>((ref) => const SilentNotificationPort());
final reminderServiceProvider = Provider((ref) => ReminderService(ref.watch(notificationPortProvider)));
final remindersProvider = StreamProvider((ref) => ref.watch(itemsRepositoryProvider).watchReminders());

final canvasRepositoryProvider = Provider((ref) => CanvasRepository(ref.watch(databaseProvider)));

/// Раскладка холста папки.
final canvasSpotsProvider = StreamProvider.family<Map<String, CanvasSpot>, String>((ref, folderId) => ref.watch(canvasRepositoryProvider).watch(folderId));

/// Вещи папки; null — всё, что лежит без папки.
final folderItemsProvider = StreamProvider.family<List<ItemCard>, String?>((ref, folderId) => ref.watch(itemsRepositoryProvider).watchFolder(folderId));
