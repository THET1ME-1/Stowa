import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:stowa/app.dart';
import 'package:stowa/core/theme/app_theme.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/appearance.dart';
import 'package:stowa/domain/article_text.dart';
import 'package:stowa/domain/return_plan.dart';
import 'package:stowa/features/privacy/privacy_flows.dart';
import 'package:stowa/services/privacy/seal_crypto.dart';
import 'package:stowa/services/link_checker.dart';
import 'package:stowa/services/media_probe.dart';
import 'package:stowa/services/place_channel.dart';
import 'package:stowa/services/place_service.dart';
import 'package:stowa/services/reminder_service.dart';
import 'package:stowa/services/telegram_service.dart';
import 'package:stowa/services/vault/vault_location.dart';
import 'package:stowa/l10n/app_localizations.dart';

/// База в памяти, своя папка файлов и замёрзшие часы — для виджет-тестов.
class TestWorld {
  TestWorld({DateTime? now}) : now = now ?? DateTime(2026, 11, 2, 10);

  final DateTime now;
  final db = AppDatabase.memory();
  final files = Directory.systemTemp.createTempSync('stowa_test');

  /// Сколько раз приложение просило систему доделать файлы в фоне.
  var fileWorkAsked = 0;

  /// Включён ли показ 18+ в настройках.
  var showAdult = false;

  /// Предложения папки, на которые уже ответили.
  var dismissedSuggestions = <String>{};
  final _dismissed = StreamController<Set<String>>.broadcast();

  /// Место хранилища уже выбрано: по умолчанию сразу главная, без экрана первого запуска.
  var vaultAsked = true;

  /// Что открывать при запуске.
  var startScreen = StartScreen.home;

  /// Оформление без настоящих настроек.
  var appearance = const Appearance();

  /// Схемы из обоев; пусто — как Android до 12.
  ({ColorScheme light, ColorScheme dark})? wallpaper;

  /// Папка хранилища пропала или отозвали доступ.
  var vaultMissing = false;

  /// Что вернёт окно выбора папки.
  String? pickedFolder;

  /// Дан ли «Доступ ко всем файлам».
  var allFiles = true;

  /// Android для мест: что разрешено и какие тревоги поставлены.
  final placeChannel = FakePlaceChannel();

  /// Где телефон «сейчас» для «Я сейчас дома».
  PlaceFix? currentPlace;

  /// Уведомления: сколько раз спросили разрешение.
  final notifications = FakeNotificationPort();

  /// Место «пока открыто» разрешено и сколько раз его спросили.
  var placeGranted = true;
  var placeAsked = 0;

  /// Копии страниц для читалки: id заметки → HTML. Разбор без отдельного потока —
  /// у виджет-теста поддельное время, и поток не дождался бы ответа.
  final pages = <String, String>{};

  /// Что ответят адреса проверке ссылок; кого нет — живой.
  final linkReplies = <String, LinkReply>{};

  /// Ключ отпечатка и сам палец: по умолчанию датчика нет.
  final fingerprintKey = MemoryKeyStore();
  final biometrics = FakeBiometrics();

  List<Override> get overrides => [
        notificationPortProvider.overrideWithValue(notifications),
        placeGrantedProvider.overrideWith((ref) async => placeGranted),
        askPlaceProvider.overrideWithValue(() async {
          placeAsked++;
          return placeGranted = true;
        }),
        databaseProvider.overrideWithValue(db),
        articleLoaderProvider.overrideWithValue((id, url) async => pages[id] == null ? null : extractArticle(pages[id]!, Uri.parse(url))),
        linkCheckProvider.overrideWithValue((uri) async => linkReplies['$uri'] ?? LinkReply.alive),
        startFilesRootProvider.overrideWithValue(files),
        appSupportProvider.overrideWithValue(files),
        fingerprintKeyProvider.overrideWithValue(fingerprintKey),
        biometricsProvider.overrideWithValue(biometrics),
        kdfSettingsProvider.overrideWithValue(const KdfSettings(memoryKib: 256, passes: 1)),
        vaultAskedProvider.overrideWithValue(vaultAsked),
        vaultMissingProvider.overrideWithValue(vaultMissing),
        vaultPickerProvider.overrideWithValue(() async => pickedFolder),
        vaultChannelProvider.overrideWithValue(_TestChannel(this)),
        clockProvider.overrideWithValue(() => now),
        // обоев в тестах нет: как Android до 12
        wallpaperProvider.overrideWith((ref) async => wallpaper),
        // превью ссылок в тестах без интернета: сеть «молчит», вещь остаётся как есть
        linkFetchProvider.overrideWithValue((uri) async => throw const SocketException('тест без сети')),
        linkPostProvider.overrideWithValue((uri, body) async => throw const SocketException('тест без сети')),
        linkFetchWithProvider.overrideWithValue((uri, headers) async => throw const SocketException('тест без сети')),
        // Android нет: система роликов не читает, кадров нет
        mediaProbeProvider.overrideWithValue(const _NoMedia()),
        // очередь ИИ в тестах не ходит в сеть сама, плашек разбора не бывает
        aiDrainProvider.overrideWithValue(() async {}),
        aiSortedProvider.overrideWith((ref) => const Stream.empty()),
        aiBusyProvider.overrideWith((ref) => const Stream.empty()),
        // GPS в тестах нет: место не ставится
        placeStampProvider.overrideWithValue((id) async {}),
        whereAmIProvider.overrideWithValue(() async => null),
        // Android нет: место «всегда», Wi-Fi и тревоги — из полей мира
        placeChannelProvider.overrideWithValue(placeChannel),
        currentPlaceProvider.overrideWithValue(() async => currentPlace),
        // бота Telegram в тестах нет
        telegramPullProvider.overrideWithValue(() async => 0),
        telegramStateProvider.overrideWith((ref) => Stream.value(const TelegramState())),
        onlineProvider.overrideWith((ref) => const Stream.empty()),
        // фоновой работы системы в тестах нет: сколько раз её просили, видно по счётчику
        fileWorkProvider.overrideWithValue(() async => fileWorkAsked++),
        if (settings case final settings?)
          settingsRepositoryProvider.overrideWithValue(settings)
        else ...[
          aiSettingsProvider.overrideWith((ref) => Stream.value(aiSettings)),
          languageProvider.overrideWith((ref) => Stream.value(null)),
          placeEnabledProvider.overrideWith((ref) => Stream.value(true)),
          showAdultProvider.overrideWith((ref) => Stream.value(showAdult)),
          articleImagesProvider.overrideWith((ref) => Stream.value(false)),
          startScreenProvider.overrideWithValue(startScreen),
          appearanceProvider.overrideWith((ref) => Stream.value(appearance)),
          startScreenChoiceProvider.overrideWith((ref) => Stream.value(startScreen)),
          titleByShotProvider.overrideWithValue(() => true),
          aiFirstProvider.overrideWithValue(() => settings?.ai.aiFirst ?? false),
          workEndProvider.overrideWithValue(() => 18 * 60),
          workEndChoiceProvider.overrideWith((ref) => Stream.value(18 * 60)),
          titleDateProvider.overrideWith((ref) => Stream.value(TitleDate.shot)),
          // карточку «Возвращать сохранённое?» в чужих тестах уже закрыли
          returnsAskedProvider.overrideWith((ref) => Stream.value(true)),
          dismissedSuggestionsProvider.overrideWith((ref) async* {
            yield dismissedSuggestions;
            yield* _dismissed.stream;
          }),
          dismissSuggestionProvider.overrideWithValue((key) async {
            dismissedSuggestions = {...dismissedSuggestions, key};
            _dismissed.add(dismissedSuggestions);
          }),
          returnSettingsProvider.overrideWith((ref) => Stream.value(const ReturnSettings())),
        ],
        if (aiHttp case final aiHttp?) aiHttpProvider.overrideWithValue(aiHttp),
      ];

  /// Без настоящих настроек: ключа нет. Тест плашки паузы подставляет сюда настройки на паузе.
  AiSettings aiSettings = const AiSettings();

  /// Настоящие настройки для тестов экрана настроек.
  SettingsRepository? settings;

  /// Поддельный поставщик ИИ.
  http.Client? aiHttp;

  /// [locale] null — язык из настроек, как в приложении.
  Widget app({Locale? locale = const Locale('ru')}) => ProviderScope(overrides: overrides, child: StowaApp(locale: locale));

  /// Один виджет на теме и словарях приложения.
  Widget wrap(Widget child, {Locale locale = const Locale('ru')}) => ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: locale,
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  Future<void> dispose() async {
    await _dismissed.close();
    await db.close();
    if (files.existsSync()) files.deleteSync(recursive: true);
  }
}

/// Android мест в тестах: разрешение, сеть и тревоги — поля, которые тест читает и ставит.
class FakeNotificationPort implements NotificationPort {
  var asked = 0;

  @override
  Future<void> ensurePermission() async => asked++;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule({required int id, required String title, required String body, required DateTime at, required String payload}) async {}

  @override
  Future<void> show({required int id, required String title, required String body, required String payload}) async {}
}

class FakePlaceChannel implements PlaceChannel {
  var background = false;
  var asked = 0;
  String? wifi;
  List<PlaceAlarm> alarms = const [];
  final fired = <String>[];

  @override
  Future<bool> hasBackground() async => background;

  @override
  Future<void> askBackground() async {
    asked++;
    background = true;
  }

  @override
  Future<String?> currentWifi() async => wifi;

  @override
  Future<void> sync(List<PlaceAlarm> alarms, {String channelName = ''}) async => this.alarms = List.of(alarms);

  @override
  Future<List<String>> takeFired() async {
    final taken = List.of(fired);
    fired.clear();
    return taken;
  }
}

/// Разрешение «Доступ ко всем файлам» из [TestWorld.allFiles]; просьба его сразу даёт.
class _NoMedia implements MediaProbe {
  const _NoMedia();

  @override
  Future<VideoInfo?> probe(String path) async => null;

  @override
  Future<List<bool>> frames(String path, List<Duration> at, List<String> outs, {int maxSide = 720}) async => [for (final _ in at) false];
}

class _TestChannel implements VaultChannel {
  _TestChannel(this.world);

  final TestWorld world;

  @override
  Future<bool> hasAllFiles() async => world.allFiles;

  @override
  Future<void> askAllFiles() async => world.allFiles = true;
}

/// Палец в тестах: есть ли датчик и что он ответит.
class FakeBiometrics implements Biometrics {
  bool present = false;
  bool answer = true;
  int asked = 0;

  @override
  Future<bool> available() async => present;

  @override
  Future<bool> confirm(String reason) async {
    asked++;
    return present && answer;
  }
}
