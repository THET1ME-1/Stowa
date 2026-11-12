import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show PlatformDispatcher;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show BaseAggregate, DriftSqlType, OrderingTerm;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart' show Brightness, ColorScheme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/icons/icon_registry.dart';
import '../l10n/app_language.dart';
import '../l10n/app_localizations.dart' show lookupL;
import '../domain/article_text.dart';
import '../domain/models.dart' show FactKind;
import '../domain/place_groups.dart' show guessHomeAndWork;
import '../domain/related.dart';
import '../services/ai_image.dart';
import '../services/ai_worker.dart';
import '../services/auto_sorter.dart';
import '../services/backup_service.dart';
import '../services/background.dart';
import '../services/capture_service.dart';
import '../services/fact_rules.dart';
import '../services/facts/extractors.dart';
import '../services/facts/facts_pipeline.dart';
import '../services/facts/video_extractor.dart';
import '../services/facts/web_extractors.dart';
import '../services/file_keeper.dart';
import '../services/link_checker.dart';
import '../services/link_preview_service.dart';
import '../services/media_probe.dart';
import '../services/page_cache.dart';
import '../services/place_channel.dart';
import '../services/place_service.dart';
import '../services/privacy/privacy_service.dart';
import '../services/reminder_service.dart';
import '../services/telegram_service.dart';
import '../services/vault/vault_location.dart';
import '../services/vault/vault_reader.dart';
import '../services/vault/vault_sync.dart';
import '../services/vault/vault_writer.dart';
import 'db/database.dart';
import 'repositories/canvas_repository.dart';
import 'repositories/folder_suggestions.dart';
import 'repositories/folders_repository.dart';
import 'repositories/highlights_repository.dart';
import 'repositories/history_repository.dart';
import 'repositories/items_repository.dart';
import 'repositories/places_repository.dart';
import 'repositories/return_repository.dart';
import 'repositories/rules_repository.dart';
import 'repositories/smart_folders_repository.dart';
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

/// Что открыть при этом запуске: читается один раз, смена в настройках сработает со следующего.
final startScreenProvider = Provider<StartScreen>((ref) => ref.read(settingsRepositoryProvider).startScreen);

/// Выбор «При запуске» для экрана настроек.
final startScreenChoiceProvider = StreamProvider((ref) => ref.watch(settingsRepositoryProvider).watchStartScreen());

/// Оформление, выбранное в настройках.
final appearanceProvider = StreamProvider((ref) => ref.watch(settingsRepositoryProvider).watchAppearance());

/// Схемы из обоев (Android 12+). Пусто — система цвета не даёт, строки в настройках нет.
final wallpaperProvider = FutureProvider<({ColorScheme light, ColorScheme dark})?>((ref) async {
  try {
    final core = await DynamicColorPlugin.getCorePalette();
    if (core == null) return null;
    return (light: core.toColorScheme(), dark: core.toColorScheme(brightness: Brightness.dark));
  } catch (_) {
    return null;
  }
});

/// Часы: в тестах подменяются, чтобы «завтра» было предсказуемым.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final itemsRepositoryProvider = Provider((ref) {
  final facts = ref.watch(factsPipelineProvider);
  return ItemsRepository(ref.watch(databaseProvider), clock: ref.watch(clockProvider))..onEdited = (id) => facts.runItem(id).ignore();
});

/// Показывать ли обложки и описания 18+: решает человек в настройках.
final showAdultProvider = StreamProvider((ref) => ref.watch(settingsRepositoryProvider).watchShowAdult());

/// Что и когда возвращать уведомлениями.
final returnSettingsProvider = StreamProvider((ref) => ref.watch(settingsRepositoryProvider).watchReturns());

final returnRepositoryProvider = Provider((ref) => ReturnRepository(ref.watch(databaseProvider)));

/// Карточку «Возвращать сохранённое?» уже показывали.
final returnsAskedProvider = StreamProvider((ref) => ref.watch(settingsRepositoryProvider).watchReturnsAsked());

/// Предложения папки, на которые человек уже ответил. Тесты подменяют.
final dismissedSuggestionsProvider = StreamProvider((ref) => ref.watch(settingsRepositoryProvider).watchDismissedSuggestions());

/// Запомнить ответ на предложение папки. Тесты подменяют.
final dismissSuggestionProvider = Provider<Future<void> Function(String key)>((ref) => (key) => ref.read(settingsRepositoryProvider).dismissSuggestion(key));

final folderSuggestionsProvider = Provider((ref) => FolderSuggestions(ref.watch(databaseProvider), clock: ref.watch(clockProvider)));

/// Карточка «12 ссылок с habr.com без папки — сделать папку?»: самая большая группа,
/// пересчитывается при правках заметок и ответах человека.
final folderSuggestionProvider = StreamProvider<FolderSuggestion?>((ref) {
  final dismissed = ref.watch(dismissedSuggestionsProvider).value;
  if (dismissed == null) return const Stream.empty();
  final db = ref.watch(databaseProvider);
  final suggestions = ref.watch(folderSuggestionsProvider);
  return db
      .customSelect(
        'SELECT (SELECT count(*) FROM items WHERE folder_id IS NULL AND deleted_at IS NULL) AS loose, '
        "(SELECT count(*) FROM facts WHERE kind = 'screenshot') AS shots, (SELECT max(updated_at) FROM items) AS edited",
        readsFrom: {db.items, db.facts},
      )
      .watch()
      .asyncMap((_) => suggestions.find(dismissed: dismissed));
});

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

/// Длина и кадры своего ролика: в тестах подменяется.
final mediaProbeProvider = Provider<MediaProbe>((ref) => const ChannelMediaProbe());

/// Конвейер извлекателей: деньги, контакты, текст документов, EXIF, автор и сайт ссылки.
/// Один на окно и зависит только от неизменного, как хранитель файлов.
final factsPipelineProvider = Provider((ref) {
  final fetch = ref.watch(linkFetchProvider);
  final rules = FactRules(ref.watch(databaseProvider), clock: ref.watch(clockProvider));
  return FactsPipeline(
    ref.watch(databaseProvider),
    filesRoot: ref.watch(filesRootProvider),
    clock: ref.watch(clockProvider),
    online: () async => ref.read(onlineProvider).value ?? true,
    // «рецепт → в „Рецепты“»: правила по фактам — когда факты появились
    onFacts: (id) => rules.apply(id).ignore(),
    extractors: [
      ...defaultExtractors(),
      // кадры своего ролика достаёт система через канал окна: в фоновом движке правила нет
      VideoExtractor(probe: ref.watch(mediaProbeProvider)),
      PageExtractor(),
      ArticleExtractor(),
      // выключены картинки статей — правила нет вовсе: ни прогонов, ни ошибок в очереди
      if (ref.watch(articleImagesProvider).value ?? false) ArticleImagesExtractor(fetch: ref.watch(linkFetchWithProvider), onWifi: onWifi),
      PageFetchExtractor(fetch: fetch),
      SubtitlesExtractor(fetch: fetch, post: ref.watch(linkPostProvider), languages: () => subtitleLanguages(ref.read(languageProvider).value?.code)),
    ],
  );
});
final foldersRepositoryProvider = Provider((ref) => FoldersRepository(ref.watch(databaseProvider)));

/// Скачивать ли картинки статей по Wi-Fi.
final articleImagesProvider = StreamProvider((ref) => ref.watch(settingsRepositoryProvider).watchArticleImages());

/// Как спросить адрес, жив ли он: в тестах — без сети.
final linkCheckProvider = Provider<LinkCheck>((ref) => httpLinkReply);
final linkCheckerProvider = Provider((ref) => LinkChecker(ref.watch(databaseProvider), clock: ref.watch(clockProvider), check: ref.watch(linkCheckProvider)));

/// Битые ссылки, которые ещё не решены: «Настройки → Битые ссылки».
final deadLinksProvider = StreamProvider.autoDispose((ref) => ref.watch(itemsRepositoryProvider).watchDeadLinks());

final highlightsRepositoryProvider = Provider((ref) => HighlightsRepository(ref.watch(databaseProvider), clock: ref.watch(clockProvider)));

/// Цитаты статьи по порядку в тексте.
final highlightsProvider = StreamProvider.autoDispose.family<List<Highlight>, String>((ref, itemId) => ref.watch(highlightsRepositoryProvider).watch(itemId));

final historyRepositoryProvider = Provider((ref) => HistoryRepository(ref.watch(databaseProvider), ref.watch(itemsRepositoryProvider)));

/// Снимки заметки, новый первым: «История» в меню заметки.
final noteVersionsProvider = StreamProvider.autoDispose.family<List<NoteVersion>, String>((ref, itemId) => ref.watch(historyRepositoryProvider).watch(itemId));

/// Статья из копии страницы для читалки. Разбор — в отдельном потоке: длинная статья не подвешивает экран.
final articleLoaderProvider = Provider<Future<Article?> Function(String itemId, String url)>((ref) {
  final root = ref.watch(filesRootProvider);
  return (itemId, url) async {
    final html = await readPage(root, itemId);
    final page = Uri.tryParse(url);
    if (html == null || page == null) return null;
    return Isolate.run(() => extractArticle(html, page));
  };
});
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
    titleByShot: ref.watch(titleByShotProvider),
    workEnd: ref.watch(workEndProvider),
    aiFirst: ref.watch(aiFirstProvider),
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

/// Подпись «Фото от …» по дню съёмки: читается в момент сохранения, смена в настройках
/// действует сразу. Тесты подменяют: настоящих настроек там нет.
final titleByShotProvider = Provider<bool Function()>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return () => settings.titleDate == TitleDate.shot;
});

/// Конец рабочего дня для «после работы»: строка и сохранение читают его в момент разбора.
/// Тесты подменяют: настоящих настроек там нет.
/// ИИ в приоритете: сохранение читает выбор при каждой заметке, тесты подменяют.
final aiFirstProvider = Provider<bool Function()>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return () => settings.ai.aiFirst;
});

final workEndProvider = Provider<int Function()>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return () => settings.workEnd;
});

/// Конец рабочего дня для экрана настроек.
final workEndChoiceProvider = StreamProvider((ref) => ref.watch(settingsRepositoryProvider).watchWorkEnd());

/// Выбор дня подписи для экрана настроек.
final titleDateProvider = StreamProvider((ref) => ref.watch(settingsRepositoryProvider).watchTitleDate());

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

final smartFoldersRepositoryProvider = Provider((ref) => SmartFoldersRepository(ref.watch(databaseProvider), clock: ref.watch(clockProvider)));

/// Умные папки по порядку: пилюли на главной после обычных.
final smartFoldersProvider = StreamProvider((ref) => ref.watch(smartFoldersRepositoryProvider).watchAll());

/// Найденное по запросу умной папки на сегодня; пересчитывается, когда меняются заметки.
final smartResultsProvider = StreamProvider.family<SearchFound, String>(
  (ref, query) => ref.watch(itemsRepositoryProvider).watchSearch(query, ref.watch(clockProvider)),
);

/// Деньги в заметках папки и вложенных по валютам: строка «Всего …» на экране папки.
final folderTotalProvider = StreamProvider.family<List<(double, String)>, String>((ref, folderId) => ref.watch(itemsRepositoryProvider).watchFolderTotal(folderId));

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
final autoSorterProvider = Provider((ref) => AutoSorter(ref.watch(databaseProvider), clock: ref.watch(clockProvider)));

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

/// Замок и скрытые папки. Ключ для отпечатка — в Keystore телефона, код и копия — в хранилище.
final privacyServiceProvider = Provider(
  (ref) => PrivacyService(
    db: ref.watch(databaseProvider),
    vault: ref.watch(vaultRootProvider),
    appData: ref.watch(appSupportProvider),
    flush: ref.watch(vaultWriterProvider).drain,
    fingerprintKey: ref.watch(fingerprintKeyProvider),
  ),
);

/// Где лежит ключ для отпечатка: Keystore телефона, в тестах — память.
final fingerprintKeyProvider = Provider<KeyStore>((ref) => const SecureKeyStore('sealed_key'));

/// Замок, прочитанный в main до первого кадра: запереть приложение сразу, без мелькания.
final startLockProvider = Provider<PrivacyLock?>((ref) => null);

/// Открыто ли скрытое сейчас.
final hiddenOpenProvider = StreamProvider<bool>((ref) async* {
  final privacy = ref.watch(privacyServiceProvider);
  yield privacy.isOpen;
  yield* privacy.changes.map((_) => privacy.isOpen);
});

/// Замок хранилища: код, замок на вход, через сколько закрывать. null — кода нет.
final privacyLockProvider = StreamProvider<PrivacyLock?>((ref) async* {
  final privacy = ref.watch(privacyServiceProvider);
  yield await privacy.loadLock();
  yield* privacy.changes.map((_) => privacy.lock);
});

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
final folderIndexProvider = StreamProvider((ref) => ref.watch(itemsRepositoryProvider).watchFolderIndex());

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
/// Напоминания для будильников. Скрытые — без текста; закрытого скрытого в базе нет,
/// его время берётся из списка, который служба приватности оставляет при закрытии.
final remindersProvider = StreamProvider((ref) {
  final language = ref.watch(languageProvider).value ?? AppLanguage.resolve(PlatformDispatcher.instance.locales);
  final title = lookupL(language.locale).hiddenReminder;
  final privacy = ref.watch(privacyServiceProvider);
  final now = ref.watch(clockProvider);
  return ref
      .watch(itemsRepositoryProvider)
      .watchReminders(hiddenTitle: title)
      .asyncMap(
        (list) async => [
          ...list,
          for (final one in await privacy.sealedReminders(now())) (id: hiddenReminderPayload(one.itemId), title: title, body: '', at: one.at),
        ],
      );
});

final canvasRepositoryProvider = Provider((ref) => CanvasRepository(ref.watch(databaseProvider)));

/// Раскладка холста папки.
final canvasSpotsProvider = StreamProvider.family<Map<String, CanvasSpot>, String>((ref, folderId) => ref.watch(canvasRepositoryProvider).watch(folderId));

/// Вещи папки; null — всё, что лежит без папки.
final folderItemsProvider = StreamProvider.family<List<ItemCard>, String?>((ref, folderId) => ref.watch(itemsRepositoryProvider).watchFolder(folderId));
