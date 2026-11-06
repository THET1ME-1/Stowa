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

  List<Override> get overrides => [
        databaseProvider.overrideWithValue(db),
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

/// Разрешение «Доступ ко всем файлам» из [TestWorld.allFiles]; просьба его сразу даёт.
class _TestChannel implements VaultChannel {
  _TestChannel(this.world);

  final TestWorld world;

  @override
  Future<bool> hasAllFiles() async => world.allFiles;

  @override
  Future<void> askAllFiles() async => world.allFiles = true;
}
