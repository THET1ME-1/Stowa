import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../data/db/database.dart';
import '../../data/settings_repository.dart' show KeyStore;
import '../../domain/vault_note.dart';
import '../vault/vault_reader.dart';
import 'cloud_history.dart';
import 'key_lock.dart';
import 'sync_crypto.dart';
import 'sync_db_state.dart';
import 'sync_disk.dart';
import 'sync_engine.dart';
import 'sync_http.dart';
import 'sync_progress.dart';

/// Имя телефона: «Xiaomi 14», «iPhone 15». Не узнали — пусто, письмо обойдётся без него.
Future<String> phoneName() async {
  try {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      final brand = android.manufacturer.isEmpty ? '' : '${android.manufacturer[0].toUpperCase()}${android.manufacturer.substring(1)} ';
      return android.model.toLowerCase().startsWith(android.manufacturer.toLowerCase()) ? android.model : '$brand${android.model}';
    }
    if (Platform.isIOS) return (await info.iosInfo).name;
  } on Object {
    // нет плагина (тесты) или телефон не ответил
  }
  return '';
}

/// Чем кончился ввод кода с почты.
enum SignInStep {
  signedIn,
  wrongCode,

  /// Код принят, но ключ закрыт своим паролем шифрования: нужен пароль ([SyncService.unlock]).
  needsPassword,
}

/// Аккаунт синхронизации на телефоне. Лежит в защищённом хранилище телефона.
class SyncAccount {
  const SyncAccount({required this.email, required this.token, required this.key, required this.vaultDb});

  final String email;
  final String token;
  final List<int> key;

  /// База хранилища, которое синхронизируется. Другое хранилище не синхронизируется:
  /// иначе переключение хранилищ слило бы два в одно.
  final String vaultDb;

  String toJson() => jsonEncode({'email': email, 'token': token, 'key': base64.encode(key), 'vault_db': vaultDb});

  static SyncAccount? fromJson(String? text) {
    if (text == null) return null;
    try {
      final json = jsonDecode(text) as Map<String, Object?>;
      return SyncAccount(email: json['email'] as String, token: json['token'] as String, key: base64.decode(json['key'] as String), vaultDb: json['vault_db'] as String);
    } on Object {
      return null;
    }
  }
}

/// Что показывает экран синхронизации.
@immutable
class SyncStatus {
  const SyncStatus({this.email, this.running = false, this.lastAt, this.error, this.inactive = false, this.received = 0, this.sent = 0, this.otherVault = false});

  /// Аккаунт возит другое хранилище, а не открытое: это лежит только на устройстве.
  final bool otherVault;

  /// Почта аккаунта; null — не вошли.
  final String? email;
  final bool running;
  final DateTime? lastAt;
  final SyncError? error;

  /// Подписка не действует: сервер не принимает файлы.
  final bool inactive;

  /// Сколько файлов последний проход положил или убрал на диске и сколько отправил.
  final int received;
  final int sent;

  SyncStatus copyWith({String? email, bool? running, DateTime? lastAt, SyncError? error, bool clearError = false, bool? inactive, int? received, int? sent, bool? otherVault}) => SyncStatus(
    otherVault: otherVault ?? this.otherVault,
    email: email ?? this.email,
    running: running ?? this.running,
    lastAt: lastAt ?? this.lastAt,
    error: clearError ? null : error ?? this.error,
    inactive: inactive ?? this.inactive,
    received: received ?? this.received,
    sent: sent ?? this.sent,
  );
}

/// Синхронизация хранилища через sync.stowa.work.
class SyncService {
  SyncService({
    required AppDatabase db,
    required Directory? root,
    required String Function() vaultDb,
    required VaultReader reader,
    required KeyStore store,
    http.Client? client,
    this.deviceName = phoneName,
  }) : _db = db, // ignore: prefer_initializing_formals
       _root = root, // ignore: prefer_initializing_formals
       _currentVaultDb = vaultDb,
       _reader = reader, // ignore: prefer_initializing_formals
       _store = store, // ignore: prefer_initializing_formals
       _client = client ?? http.Client();

  final AppDatabase _db;
  final Directory? _root;

  /// Имя базы открытого хранилища: читается при каждом проходе.
  final String Function() _currentVaultDb;
  String get _vaultDb => _currentVaultDb();

  /// Аккаунт синхронизирует открытое сейчас хранилище, а не другое.
  bool syncsOpenVault(SyncAccount account) => account.vaultDb == _vaultDb;
  final VaultReader _reader;
  final KeyStore _store;
  final http.Client _client;

  /// Имя телефона для письма с кодом: «Xiaomi 14».
  final Future<String> Function() deviceName;

  final status = ValueNotifier(const SyncStatus());

  /// Ход полного прохода для экрана; null — прохода нет.
  final progress = ValueNotifier<SyncProgress?>(null);
  SyncProgress? _latest;
  Timer? _publish;

  /// Ход прохода от сверки хранилища и движка. Новый этап — сразу, ход внутри этапа — не
  /// чаще десяти раз в секунду: шесть потоков приёма в браузере делят один главный поток.
  void track(SyncProgress? next) {
    _latest = next;
    if (next == null || progress.value?.stage != next.stage) {
      _publish?.cancel();
      _publish = null;
      progress.value = next;
      return;
    }
    _publish ??= Timer(const Duration(milliseconds: 100), () {
      _publish = null;
      progress.value = _latest;
    });
  }

  /// Запустить общую сверку хранилища (её ставит приложение): пришедшее ложится в базу.
  Future<void> Function()? trigger;

  SyncAccountApi get _api => SyncAccountApi(_client);

  SyncAccount? _account;
  bool _loaded = false;

  Future<SyncAccount?> account() async {
    if (!_loaded) {
      _account = SyncAccount.fromJson(await _store.read());
      _loaded = true;
      status.value = status.value.copyWith(email: _account?.email, otherVault: _account != null && _account!.vaultDb != _vaultDb);
    }
    return _account;
  }

  // ── вход ──

  Future<CodeRequest> requestCode(String email, {required String lang}) async =>
      _api.requestCode(email.trim(), lang: lang, device: await deviceName(), tzOffset: DateTime.now().timeZoneOffset.inMinutes);

  /// Вход, который ждёт своего пароля шифрования: код принят, ключ закрыт паролем.
  ({SignedIn signed, Map<String, Object?> lock})? _pending;

  /// Код верный — вошли, ключ хранилища на месте; ключ закрыт своим паролем — [SignInStep.needsPassword],
  /// дальше [unlock]. Неверный код — [SignInStep.wrongCode]. Сеть — бросает.
  Future<SignInStep> verify(String email, String code) async {
    final signed = await _api.verify(email.trim(), code.trim(), device: await deviceName());
    if (signed == null) return SignInStep.wrongCode;
    // ключ один на аккаунт: первый телефон кладёт, остальные забирают
    var state = await _api.keyState(signed.token);
    if (state.key == null && state.lock == null) {
      final fresh = VaultKey.generate().bytes;
      state = await _api.putKey(signed.token, fresh) ? (key: fresh, lock: null) : await _api.keyState(signed.token);
    }
    final lock = state.lock;
    if (state.key == null && lock != null) {
      _pending = (signed: signed, lock: lock);
      return SignInStep.needsPassword;
    }
    await _finishSignIn(signed, state.key!);
    return SignInStep.signedIn;
  }

  /// Открыть ключ своим паролем после кода. false — пароль не тот.
  Future<bool> unlock(String password) async {
    final pending = _pending;
    if (pending == null) return false;
    final key = await KeyLock.open(pending.lock, password);
    if (key == null) return false;
    _pending = null;
    await _finishSignIn(pending.signed, key);
    return true;
  }

  /// Включён ли свой пароль шифрования; null — сервер не ответил.
  Future<bool?> passwordOn() async {
    final account = await this.account();
    if (account == null) return false;
    try {
      return (await _api.keyState(account.token)).lock != null;
    } on Object {
      return null;
    }
  }

  /// Включить или сменить свой пароль: ключ закрывается паролем, своя копия сервера стирается.
  Future<bool> setPassword(String password, {KeyLockCost cost = const KeyLockCost()}) async {
    final account = await this.account();
    if (account == null) return false;
    final lock = await KeyLock.close(account.key, password, cost: cost);
    return _api.putLock(account.token, lock, KeyLock.check(account.key));
  }

  /// Выключить свой пароль: ключ снова хранит сервер, вход на новом устройстве — только код.
  Future<bool> removePassword() async {
    final account = await this.account();
    if (account == null) return false;
    return _api.dropLock(account.token, account.key);
  }

  Future<void> _finishSignIn(SignedIn signed, List<int> key) async {
    final account = SyncAccount(email: signed.email, token: signed.token, key: key, vaultDb: _vaultDb);
    // прежняя память о синхронизации — от другого аккаунта или до выхода: первый проход только объединяет
    await DbSyncState(_db).clear();
    await _store.write(account.toJson());
    _account = account;
    _loaded = true;
    status.value = SyncStatus(email: account.email, inactive: !signed.active);
    unawaited(trigger?.call());
  }

  /// Токен входа; null — не вошли.
  Future<String?> token() async => (await account())?.token;

  CloudHistory? _history;
  String? _historyToken;

  /// История версий в облаке для открытого хранилища; null — не вошли или аккаунт возит
  /// другое хранилище. Подписку проверяет сервер: без неё запросы истории отвечают 402.
  Future<CloudHistory?> cloudHistory() async {
    final account = await this.account();
    if (account == null || account.vaultDb != _vaultDb) return null;
    if (_historyToken != account.token) {
      _history = CloudHistory(remote: HttpSyncRemote(_client, account.token), key: VaultKey(account.key));
      _historyToken = account.token;
    }
    return _history;
  }

  /// Положить версию из облака в хранилище по пути [path], если он свободен: возврат удалённого.
  /// Файл качается частями во временный и встаёт на место под арендой сверки; дальше его
  /// забирает обычная сверка, как файл снаружи. false — путь занят или хранилища нет.
  Future<bool> placeVersion(CloudHistory history, CloudVersion version, String path) async {
    final root = _root;
    if (root == null) return false;
    final files = DiskSyncFiles(root);
    if (await files.stat(path) != null) return false;
    final staged = await files.stage(path, history.parts(version));
    final placed = await _reader.exclusively(() => files.place(staged, path));
    if (placed) unawaited(trigger?.call());
    return placed;
  }

  /// Подписка появилась: снять запрет, сразу пройти и, если приложение на экране, ждать правок
  /// с других устройств (ожидание прошлое закончилось само, пока подписки не было).
  void activate() {
    status.value = status.value.copyWith(inactive: false);
    _retries = 0;
    unawaited(trigger?.call());
    if (_foreground) unawaited(listen());
  }

  /// Подписка кончилась: сервер файлы не примет, проходы и ожидание правок — впустую.
  void deactivate() {
    if (!status.value.inactive) status.value = status.value.copyWith(inactive: true);
    _retry?.cancel();
    // ожидание закончится само на следующем круге; на экране ли приложение — помним
    _listening = false;
    _sleep?.cancel();
    if (_woken case final woken? when !woken.isCompleted) woken.complete();
  }

  Future<void> signOut() async {
    final account = await this.account();
    if (account != null) {
      try {
        await _api.signOut(account.token);
      } on Object {
        // нет сети — токен на сервере доживёт, на телефоне его уже нет
      }
    }
    stopListening();
    _retry?.cancel();
    await _store.write(null);
    await DbSyncState(_db).clear();
    _account = null;
    status.value = const SyncStatus();
  }

  // ── проход ──

  Future<List<String>>? _running;

  /// Один проход: забрать чужое, склеить, отправить своё. Отдаёт пути файлов, которые
  /// легли на диск или ушли с него, — их забирает сверка. Новый вызов ждёт текущий.
  Future<List<String>> run() {
    final running = _running;
    if (running != null) return running;
    return _running = _run().whenComplete(() => _running = null);
  }

  Timer? _retry;
  var _retries = 0;

  Future<List<String>> _run() async {
    final account = await this.account();
    final root = _root;
    if (account == null || root == null || account.vaultDb != _vaultDb) return const [];
    status.value = status.value.copyWith(running: true);
    final engine = SyncEngine(
      vault: DiskSyncFiles(root),
      remote: HttpSyncRemote(_client, account.token),
      state: DbSyncState(_db),
      key: VaultKey(account.key),
      loser: (path, text) => unawaited(_keepLoser(path, text)),
      exclusive: _reader.exclusively,
      onProgress: track,
    );
    final report = await engine.sync();
    var inactive = status.value.inactive;
    if (report.error == SyncError.network) {
      // сеть или сервер: узнать, не кончилась ли подписка и не погасили ли вход
      try {
        inactive = !await _api.active(account.token);
      } on SyncHttpError catch (error) {
        if (error.status == 401) {
          await signOut();
          return const [];
        }
      } on Object {
        // сети нет — подождём
      }
    } else if (report.error == null) {
      inactive = false;
    }
    // служебное (.stowa, .obsidian) человек не считает: «получено 3» за одну заметку сбивало бы
    final received = report.received.where(_visible).length;
    final sent = report.sent.where(_visible).length;
    // пустой проход итог прошлого не стирает: за отправкой сразу идёт проход по своим же
    // вернувшимся правкам, и «Отправлено: 3» гасло через секунду
    final moved = received > 0 || sent > 0;
    status.value = status.value.copyWith(
      running: false,
      lastAt: report.error == null ? DateTime.now() : null,
      error: report.error,
      clearError: report.error == null,
      inactive: inactive,
      received: moved ? received : null,
      sent: moved ? sent : null,
    );
    // проход не полный (сеть, отложенные файлы): повторить самим, с растущей паузой до
    // 10 минут, — ожидание правок будит только новая правка, а отложенные курсор уже прошёл
    _retry?.cancel();
    if (report.error == SyncError.network && !inactive) {
      _retries++;
      _retry = Timer(Duration(seconds: (15 * _retries * _retries).clamp(15, 600)), () => unawaited(trigger?.call()));
    } else {
      _retries = 0;
    }
    return report.received;
  }

  static bool _visible(String path) => !path.split('/').any((part) => part.startsWith('.'));

  /// Проигравшая версия заметки — в её историю: её видно на экране версий.
  Future<void> _keepLoser(String path, String text) async {
    final link = await (_db.select(_db.vaultFiles)..where((f) => f.path.equals(path))).getSingleOrNull();
    if (link == null) return;
    final note = readVaultNote(text, fileName: path.split('/').last, fileModified: DateTime.now());
    await _db.into(_db.noteVersions).insert(NoteVersionsCompanion.insert(id: const Uuid().v4(), itemId: link.itemId, title: note.title, body: note.body, savedAt: DateTime.now()));
  }

  // ── своя правка и чужая ──

  Timer? _poke;

  /// Своя правка легла в файлы: отправить, когда правки утихнут.
  void poke() => unawaited(_pokeIfSignedIn());

  Future<void> _pokeIfSignedIn() async {
    // не вошли — ждать нечего, таймер не нужен
    if (await account() == null) return;
    _poke?.cancel();
    _poke = Timer(const Duration(seconds: 2), () => unawaited(trigger?.call()));
  }

  void dispose() {
    stopListening();
    _poke?.cancel();
    _retry?.cancel();
    _publish?.cancel();
  }

  bool _listening = false;

  /// Приложение на экране и просило ждать правок: включённая подписка продолжит ожидание.
  bool _foreground = false;

  /// Пока приложение открыто: сервер держит запрос до 25 секунд и отвечает, как только
  /// появилась правка с другого телефона.
  Future<void> listen() async {
    _foreground = true;
    if (_listening) return;
    _listening = true;
    var failures = 0;
    while (_listening) {
      final account = await this.account();
      if (account == null || account.vaultDb != _vaultDb || status.value.inactive) {
        _listening = false;
        return;
      }
      try {
        final cursor = await DbSyncState(_db).cursor();
        final page = await HttpSyncRemote(_client, account.token).changes(cursor, wait: 25);
        failures = 0;
        if (page.changes.isNotEmpty && _listening) {
          await trigger?.call();
          // проход не сдвинул курсор (сбой): не долбить сервер тем же ответом
          if (await DbSyncState(_db).cursor() == cursor) await _pause(const Duration(seconds: 15));
        }
      } on Object {
        // сеть пропала: ждать дольше с каждым сбоем, до минуты
        failures++;
        await _pause(Duration(seconds: (5 * failures).clamp(5, 60)));
      }
    }
  }

  Timer? _sleep;
  Completer<void>? _woken;

  /// Пауза, которую [stopListening] обрывает сразу: свёрнутое приложение не держит таймер.
  Future<void> _pause(Duration duration) {
    final woken = _woken = Completer<void>();
    _sleep = Timer(duration, () {
      if (!woken.isCompleted) woken.complete();
    });
    return woken.future;
  }

  void stopListening() {
    _listening = false;
    _foreground = false;
    _sleep?.cancel();
    if (_woken case final woken? when !woken.isCompleted) woken.complete();
  }
}
