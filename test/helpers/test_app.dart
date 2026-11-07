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
import 'package:stowa/domain/article_text.dart';
import 'package:stowa/domain/return_plan.dart';
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

  /// Место хранилища уже выбрано: по умолчанию сразу главная, без экрана первого запуска.
  var vaultAsked = true;

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

  List<Override> get overrides => [
        notificationPortProvider.overrideWithValue(notifications),
        placeGrantedProvider.overrideWith((ref) async => placeGranted),
        askPlaceProvider.overrideWithValue(() async {
          placeAsked++;
          return placeGranted = true;
        }),
        databaseProvider.overrideWithValue(db),
        articleLoaderProvider.overrideWithValue((id, url) async => pages[id] == null ? null : extractArticle(pages[id]!, Uri.parse(url))),
        startFilesRootProvider.overrideWithValue(files),
        appSupportProvider.overrideWithValue(files),
        vaultAskedProvider.overrideWithValue(vaultAsked),
        vaultMissingProvider.overrideWithValue(vaultMissing),
        vaultPickerProvider.overrideWithValue(() async => pickedFolder),
        vaultChannelProvider.overrideWithValue(_TestChannel(this)),
        clockProvider.overrideWithValue(() => now),
        // превью ссылок в тестах без интернета: сеть «молчит», вещь остаётся как есть
        linkFetchProvider.overrideWithValue((uri) async => throw const SocketException('тест без сети')),
        linkPostProvider.overrideWithValue((uri, body) async => throw const SocketException('тест без сети')),
        linkFetchWithProvider.overrideWithValue((uri, headers) async => throw const SocketException('тест без сети')),
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
          // карточку «Возвращать сохранённое?» в чужих тестах уже закрыли
          returnsAskedProvider.overrideWith((ref) => Stream.value(true)),
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
class _TestChannel implements VaultChannel {
  _TestChannel(this.world);

  final TestWorld world;

  @override
  Future<bool> hasAllFiles() async => world.allFiles;

  @override
  Future<void> askAllFiles() async => world.allFiles = true;
}
