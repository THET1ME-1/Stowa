import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/appearance.dart';
import '../domain/reminder_parser.dart' show defaultWorkEnd;
import '../domain/return_plan.dart';
import '../l10n/app_language.dart';
import '../services/ai_client.dart';

/// Где лежит ключ ИИ. На телефоне — защищённое хранилище системы, в тестах — память.
abstract interface class KeyStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class SecureKeyStore implements KeyStore {
  /// [_name] — под каким именем лежит секрет: ключ ИИ или токен бота.
  const SecureKeyStore([this._name = 'ai_key']);

  static const _storage = FlutterSecureStorage();
  final String _name;

  @override
  Future<String?> read() => _storage.read(key: _name);

  @override
  Future<void> write(String? value) => value == null ? _storage.delete(key: _name) : _storage.write(key: _name, value: value);
}

class MemoryKeyStore implements KeyStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? value) async => this.value = value;
}

/// Настройки разбора по ключу ИИ. Самого ключа здесь нет: только есть ли он.
/// Где хранилище: в памяти устройства (обычная папка, переживает удаление приложения)
/// или внутри приложения (без разрешений, удаляется вместе с ним).
enum VaultMode { device, app }

/// Что открывается при запуске: главная, последняя открытая заметка или случайная.
enum StartScreen { home, last, random }

/// По какому дню подпись фото и ролика без названия: «Фото от 15 июля» — когда снято
/// или когда сохранено.
enum TitleDate { shot, saved }

class AiSettings {
  const AiSettings({
    this.baseUrl = defaultAiBaseUrl,
    this.sortModel = defaultSortModel,
    this.speechModel,
    this.hasKey = false,
    this.paused = false,
    this.pauseReason,
    this.retryAt,
  });

  final String baseUrl;
  final String sortModel;

  /// Пусто — голосовые не расшифровываются.
  final String? speechModel;
  final bool hasKey;

  /// Ключ не принят или кончились деньги: очередь ждёт смены ключа.
  final bool paused;
  final String? pauseReason;

  /// Поставщик попросил подождать до этого времени (429).
  final DateTime? retryAt;

  /// Разбор идёт: ключ есть и очередь не на паузе.
  bool get active => hasKey && !paused;
}

/// Настройки приложения: ключ ИИ, поставщик, модели, пауза очереди и язык.
class SettingsRepository {
  SettingsRepository(this._prefs, this._keys);

  final SharedPreferences _prefs;
  final KeyStore _keys;
  final _changes = StreamController<void>.broadcast();

  static const _baseUrl = 'ai_base_url';
  static const _sortModel = 'ai_sort_model';
  static const _speechModel = 'ai_speech_model';
  static const _hasKey = 'ai_has_key';
  static const _paused = 'ai_paused';
  static const _pauseReason = 'ai_pause_reason';
  static const _retryAt = 'ai_retry_at';
  static const _language = 'language';
  static const _placeEnabled = 'place_enabled';
  static const _showAdult = 'show_adult';
  static const _vaultPath = 'vault_path';
  static const _vaultMode = 'vault_mode';
  static const _vaultAsked = 'vault_asked';

  /// Папка хранилища файлами; null — старая установка, хранилище ещё не перенесено.
  String? get vaultPath => _prefs.getString(_vaultPath);

  VaultMode get vaultMode => VaultMode.values.asNameMap()[_prefs.getString(_vaultMode)] ?? VaultMode.app;

  /// Человек уже выбрал место на экране первого запуска.
  bool get vaultAsked => _prefs.getBool(_vaultAsked) ?? false;

  Stream<String?> watchVaultPath() async* {
    yield vaultPath;
    yield* _changes.stream.map((_) => vaultPath).distinct();
  }

  Future<void> setVault(String path, VaultMode mode, {bool asked = true}) => _set(() async {
    await _prefs.setString(_vaultPath, path);
    await _prefs.setString(_vaultMode, mode.name);
    return _prefs.setBool(_vaultAsked, asked);
  });

  AiSettings get ai {
    final retry = _prefs.getInt(_retryAt);
    return AiSettings(
      baseUrl: _prefs.getString(_baseUrl) ?? defaultAiBaseUrl,
      sortModel: _prefs.getString(_sortModel) ?? defaultSortModel,
      speechModel: _prefs.getString(_speechModel),
      hasKey: _prefs.getBool(_hasKey) ?? false,
      paused: _prefs.getBool(_paused) ?? false,
      pauseReason: _prefs.getString(_pauseReason),
      retryAt: retry == null ? null : DateTime.fromMillisecondsSinceEpoch(retry),
    );
  }

  Stream<AiSettings> watchAi() async* {
    yield ai;
    yield* _changes.stream.map((_) => ai);
  }

  Future<String?> readKey() => _keys.read();

  /// Перечитать с диска: фоновая очередь могла поставить паузу, пока приложение спало.
  Future<void> reload() => _set(_prefs.reload);

  /// Новый ключ снимает паузу: ошибку вызывал прежний.
  Future<void> saveKey(String? key) async {
    final cleaned = key?.trim();
    final value = cleaned == null || cleaned.isEmpty ? null : cleaned;
    await _keys.write(value);
    await _prefs.setBool(_hasKey, value != null);
    await _prefs.remove(_paused);
    await _prefs.remove(_pauseReason);
    await _prefs.remove(_retryAt);
    _changes.add(null);
  }

  Future<void> setBaseUrl(String url) => _set(() => _prefs.setString(_baseUrl, url.trim().isEmpty ? defaultAiBaseUrl : url.trim()));

  Future<void> setSortModel(String model) => _set(() => _prefs.setString(_sortModel, model));

  Future<void> setSpeechModel(String? model) => _set(() => model == null || model.isEmpty ? _prefs.remove(_speechModel) : _prefs.setString(_speechModel, model));

  Future<void> pause(String reason) => _set(() async {
    await _prefs.setBool(_paused, true);
    return _prefs.setString(_pauseReason, reason);
  });

  Future<void> retryAfter(DateTime at) => _set(() => _prefs.setInt(_retryAt, at.millisecondsSinceEpoch));

  /// Запоминать, где сохранена вещь. По умолчанию да: без этого нет карты.
  bool get placeEnabled => _prefs.getBool(_placeEnabled) ?? true;

  Stream<bool> watchPlaceEnabled() async* {
    yield placeEnabled;
    yield* _changes.stream.map((_) => placeEnabled).distinct();
  }

  Future<void> setPlaceEnabled(bool on) => _set(() => _prefs.setBool(_placeEnabled, on));

  /// Что и когда возвращать: виды, час вечера, тихие часы, день сводки.
  ReturnSettings get returns => ReturnSettings(
    watchLater: _prefs.getBool('return_watch_later') ?? true,
    onThisDay: _prefs.getBool('return_on_this_day') ?? true,
    week: _prefs.getBool('return_week') ?? true,
    shopping: _prefs.getBool('return_shopping') ?? true,
    evening: _prefs.getInt('return_evening') ?? 20 * 60,
    quietStart: _prefs.getInt('return_quiet_start') ?? 22 * 60,
    quietEnd: _prefs.getInt('return_quiet_end') ?? 8 * 60,
    weekDay: _prefs.getInt('return_week_day') ?? DateTime.sunday,
  );

  Stream<ReturnSettings> watchReturns() async* {
    yield returns;
    yield* _changes.stream.map((_) => returns).distinct();
  }

  Future<void> setReturns(ReturnSettings value) => _set(() async {
    await _prefs.setBool('return_watch_later', value.watchLater);
    await _prefs.setBool('return_on_this_day', value.onThisDay);
    await _prefs.setBool('return_week', value.week);
    await _prefs.setBool('return_shopping', value.shopping);
    await _prefs.setInt('return_evening', value.evening);
    await _prefs.setInt('return_quiet_start', value.quietStart);
    await _prefs.setInt('return_quiet_end', value.quietEnd);
    return _prefs.setInt('return_week_day', value.weekDay);
  });

  /// Карточка «Включить уведомления» на главной уже была: показывается один раз.
  bool get returnsAsked => _prefs.getBool('returns_asked') ?? false;

  Stream<bool> watchReturnsAsked() async* {
    yield returnsAsked;
    yield* _changes.stream.map((_) => returnsAsked).distinct();
  }

  Future<void> setReturnsAsked() => _set(() => _prefs.setBool('returns_asked', true));

  /// Показывать обложки и описания страниц 18+. Решает человек; по умолчанию нет — так
  /// хотят магазины. Скачивается всё в любом случае: включил — видно сразу.
  bool get showAdult => _prefs.getBool(_showAdult) ?? false;

  Stream<bool> watchShowAdult() async* {
    yield showAdult;
    yield* _changes.stream.map((_) => showAdult).distinct();
  }

  Future<void> setShowAdult(bool on) => _set(() => _prefs.setBool(_showAdult, on));

  /// Скачивать картинки статей по Wi-Fi. По умолчанию нет: картинки весят в десятки раз больше текста.
  bool get articleImages => _prefs.getBool('article_images') ?? false;

  Stream<bool> watchArticleImages() async* {
    yield articleImages;
    yield* _changes.stream.map((_) => articleImages).distinct();
  }

  Future<void> setArticleImages(bool on) => _set(() => _prefs.setBool('article_images', on));

  /// Предложения папки, на которые ответили («Не надо» или «Сделать»): «site:habr.com», «kind:screenshot».
  Set<String> get dismissedSuggestions => (_prefs.getStringList('folder_suggest_dismissed') ?? const []).toSet();

  Stream<Set<String>> watchDismissedSuggestions() async* {
    yield dismissedSuggestions;
    yield* _changes.stream.map((_) => dismissedSuggestions).distinct((a, b) => a.length == b.length && a.containsAll(b));
  }

  Future<void> dismissSuggestion(String key) => _set(() => _prefs.setStringList('folder_suggest_dismissed', [...dismissedSuggestions, key]));

  /// Конец рабочего дня для «после работы», в минутах от полуночи. По умолчанию 18:00.
  int get workEnd => _prefs.getInt('work_end') ?? defaultWorkEnd;

  Stream<int> watchWorkEnd() async* {
    yield workEnd;
    yield* _changes.stream.map((_) => workEnd).distinct();
  }

  Future<void> setWorkEnd(int minutes) => _set(() => _prefs.setInt('work_end', minutes));

  /// Подпись фото и ролика — по дню съёмки (по умолчанию) или сохранения.
  TitleDate get titleDate => TitleDate.values.asNameMap()[_prefs.getString('title_date')] ?? TitleDate.shot;

  Stream<TitleDate> watchTitleDate() async* {
    yield titleDate;
    yield* _changes.stream.map((_) => titleDate).distinct();
  }

  Future<void> setTitleDate(TitleDate value) => _set(() => _prefs.setString('title_date', value.name));

  /// Что открывать при запуске. По умолчанию главная.
  StartScreen get startScreen => StartScreen.values.asNameMap()[_prefs.getString('start_screen')] ?? StartScreen.home;

  Stream<StartScreen> watchStartScreen() async* {
    yield startScreen;
    yield* _changes.stream.map((_) => startScreen).distinct();
  }

  Future<void> setStartScreen(StartScreen value) => _set(() => _prefs.setString('start_screen', value.name));

  /// Оформление: режим темы, цвет, насыщенность, обои, AMOLED. Живёт на телефоне.
  Appearance get appearance {
    final seed = _prefs.getInt('appearance_seed');
    return Appearance(
      choice: ThemeChoice.values.asNameMap()[_prefs.getString('appearance_choice')] ?? ThemeChoice.dark,
      seed: seed,
      vibrant: _prefs.getBool('appearance_vibrant') ?? true,
      wallpaper: _prefs.getBool('appearance_wallpaper') ?? false,
      amoled: _prefs.getBool('appearance_amoled') ?? false,
    );
  }

  Stream<Appearance> watchAppearance() async* {
    yield appearance;
    yield* _changes.stream.map((_) => appearance).distinct();
  }

  Future<void> setAppearance(Appearance value) => _set(() async {
    await _prefs.setString('appearance_choice', value.choice.name);
    final seed = value.seed;
    if (seed == null) {
      await _prefs.remove('appearance_seed');
    } else {
      await _prefs.setInt('appearance_seed', seed);
    }
    await _prefs.setBool('appearance_vibrant', value.vibrant);
    await _prefs.setBool('appearance_wallpaper', value.wallpaper);
    return _prefs.setBool('appearance_amoled', value.amoled);
  });

  /// Язык, выбранный руками. Пусто — язык устройства.
  AppLanguage? get language => switch (_prefs.getString(_language)) {
    final code? => AppLanguage.values.where((language) => language.code == code).firstOrNull,
    null => null,
  };

  Stream<AppLanguage?> watchLanguage() async* {
    yield language;
    yield* _changes.stream.map((_) => language).distinct();
  }

  Future<void> setLanguage(AppLanguage? language) => _set(() => language == null ? _prefs.remove(_language) : _prefs.setString(_language, language.code));

  Future<void> _set(Future<Object?> Function() write) async {
    await write();
    _changes.add(null);
  }
}
