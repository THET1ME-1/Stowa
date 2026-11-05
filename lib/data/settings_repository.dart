import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Показывать обложки и описания страниц 18+. Решает человек; по умолчанию нет — так
  /// хотят магазины. Скачивается всё в любом случае: включил — видно сразу.
  bool get showAdult => _prefs.getBool(_showAdult) ?? false;

  Stream<bool> watchShowAdult() async* {
    yield showAdult;
    yield* _changes.stream.map((_) => showAdult).distinct();
  }

  Future<void> setShowAdult(bool on) => _set(() => _prefs.setBool(_showAdult, on));

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
