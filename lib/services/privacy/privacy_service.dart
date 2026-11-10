import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../data/db/database.dart';
import '../../data/settings_repository.dart' show KeyStore;
import '../../domain/folder_tree.dart';
import '../vault/vault_layout.dart' show serviceFolder;
import 'hidden_rows.dart';
import 'seal_crypto.dart';
import 'sealed_space.dart';
import 'sealed_store.dart';

/// Через сколько после ухода из приложения закрываются замок и скрытое.
const lockDelays = [Duration.zero, Duration(minutes: 1), Duration(minutes: 5), Duration(minutes: 15)];

/// Замок хранилища: ключи под кодом и настройки замка. Лежит в `.stowa/lock.json`,
/// поэтому код и скрытое переживают переустановку и перенос хранилища.
class PrivacyLock {
  const PrivacyLock({required this.keys, this.appLock = false, this.closeAfter = const Duration(minutes: 1)});

  final LockFile keys;

  /// Код на вход в приложение.
  final bool appLock;
  final Duration closeAfter;

  PrivacyLock copyWith({LockFile? keys, bool? appLock, Duration? closeAfter}) =>
      PrivacyLock(keys: keys ?? this.keys, appLock: appLock ?? this.appLock, closeAfter: closeAfter ?? this.closeAfter);

  Map<String, Object?> toJson() => {'keys': keys.toJson(), 'app_lock': appLock, 'close_after': closeAfter.inSeconds};

  factory PrivacyLock.fromJson(Map<String, Object?> json) => PrivacyLock(
    keys: LockFile.fromJson((json['keys']! as Map).cast<String, Object?>()),
    appLock: json['app_lock'] as bool? ?? false,
    closeAfter: Duration(seconds: json['close_after'] as int? ?? 60),
  );
}

/// Напоминание скрытой заметки, которое звенит и при закрытом скрытом: только время, без текста.
class SealedReminder {
  const SealedReminder(this.itemId, this.at);

  final String itemId;
  final DateTime at;
}

/// Скрытые папки и замок. Пока скрытое закрыто, его строк в базе нет, а файлы лежат
/// запечатанными в `.stowa/sealed/`. Открытое живёт в `<данные приложения>/sealed-open`,
/// метка `sealed-open.state` говорит, кто главнее после обрыва: «unsealed» — копия,
/// «open» с номером процесса — база этого процесса.
class PrivacyService {
  PrivacyService({
    required AppDatabase db,
    required Directory? vault,
    required Directory appData,
    required Future<void> Function() flush,
    required KeyStore fingerprintKey,
    int? processId,
  }) : _db = db, // ignore: prefer_initializing_formals
       _vault = vault, // ignore: prefer_initializing_formals
       _flush = flush, // ignore: prefer_initializing_formals
       _fingerprintKey = fingerprintKey, // ignore: prefer_initializing_formals
       _pid = processId ?? pid,
       openDir = Directory(p.join(appData.path, 'sealed-open')),
       _stateFile = File(p.join(appData.path, 'sealed-open.state')),
       _remindersFile = File(p.join(appData.path, 'sealed-reminders.json')),
       _attemptsFile = File(p.join(appData.path, 'lock-attempts.json'));

  /// Неверные коды подряд и до какого времени ждать.
  final File _attemptsFile;

  final AppDatabase _db;
  final Directory? _vault;
  final Future<void> Function() _flush;
  final KeyStore _fingerprintKey;
  final int _pid;
  final Directory openDir;
  final File _stateFile;

  /// Время напоминаний закрытого скрытого: id и минута, без текста.
  final File _remindersFile;

  SealKeys? _keys;
  SealedManifest? _manifest;
  PrivacyLock? _lock;
  final _changes = StreamController<void>.broadcast();

  /// Одно действие за раз: открыть, закрыть, скрыть папку не должны идти вперемешку.
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() work) {
    final result = _tail.then((_) => work());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Stream<void> get changes => _changes.stream;

  File? get _lockFile => _vault == null ? null : File(p.join(_vault.path, serviceFolder, 'lock.json'));

  SealedStore? get _store => _vault == null ? null : SealedStore(_vault);

  /// Скрытое открыто в этом процессе.
  bool get isOpen => _keys != null;

  /// Код заведён.
  bool get hasCode => _lock != null;

  PrivacyLock? get lock => _lock;

  Future<PrivacyLock?> loadLock() async {
    final file = _lockFile;
    if (file == null || !await file.exists()) return _lock = null;
    try {
      return _lock = PrivacyLock.fromJson((jsonDecode(await file.readAsString()) as Map).cast<String, Object?>());
    } on FormatException {
      return _lock = null;
    }
  }

  Future<void> _saveLock(PrivacyLock? lock) async {
    final file = _lockFile;
    if (file == null) return;
    _lock = lock;
    if (lock == null) {
      if (await file.exists()) await file.delete();
    } else {
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(const JsonEncoder.withIndent('  ').convert(lock.toJson()), flush: true);
      await temp.rename(file.path);
    }
    _changes.add(null);
  }

  /// При запуске: разобрать, что осталось от прошлого процесса. Открытое скрытое убитого
  /// приложения запечатывается одним открытым ключом, недооткрытое просто стирается.
  Future<void> settle() => _serial(() async {
    SealedSpace.configure(openDir);
    await loadLock();
    final state = await _state();
    if (state == null && !await openDir.exists() && (await hiddenFolderIds(_db)).isEmpty) return;
    if (state != null && state.startsWith('open ') && state != 'open $_pid') {
      final lock = _lock;
      // ключей нет (lock.json стёрли руками): запечатать нечем, открытое остаётся как есть
      if (lock == null) return;
      await _sealAndForget(lock.keys.publicKey, previous: null);
      return;
    }
    if (state == 'open $_pid') {
      // тот же процесс, другое окно («Поделиться», фон): открытое живёт в главном окне
      await SealedSpace.load(_db);
      return;
    }
    await _forgetOpen();
  });

  /// Открыть скрытое кодом. Неверный код — false.
  Future<bool> openWithCode(String code) async {
    final keys = await checkCode(code);
    if (keys == null) return false;
    await _open(keys);
    return true;
  }

  /// Ключи по коду без открытия скрытого: замок на вход. Неверный — null и счёт ошибок;
  /// пока ждать после череды ошибок, код не проверяется вовсе.
  Future<SealKeys?> checkCode(String code) async {
    final lock = _lock ?? await loadLock();
    if (lock == null) return null;
    if (await waitUntil() != null) return null;
    final keys = await openLock(lock.keys, code);
    await _attempt(ok: keys != null);
    return keys;
  }

  /// После пяти неверных кодов подряд — 30 секунд, дальше вдвое дольше, до 15 минут.
  Future<DateTime?> waitUntil() async {
    final (_, until) = await _attempts();
    return until != null && until.isAfter(DateTime.now()) ? until : null;
  }

  Future<(int, DateTime?)> _attempts() async {
    if (!await _attemptsFile.exists()) return (0, null);
    try {
      final json = (jsonDecode(await _attemptsFile.readAsString()) as Map).cast<String, Object?>();
      final until = json['until'] as int?;
      return (json['failures'] as int? ?? 0, until == null ? null : DateTime.fromMillisecondsSinceEpoch(until));
    } on FormatException {
      return (0, null);
    }
  }

  Future<void> _attempt({required bool ok}) async {
    if (ok) {
      if (await _attemptsFile.exists()) await _attemptsFile.delete();
      return;
    }
    final (failures, _) = await _attempts();
    final count = failures + 1;
    DateTime? until;
    if (count >= 5) {
      final seconds = 30 * (1 << (count - 5).clamp(0, 5));
      until = DateTime.now().add(Duration(seconds: seconds.clamp(30, 15 * 60)));
    }
    await _attemptsFile.parent.create(recursive: true);
    await _attemptsFile.writeAsString(jsonEncode({'failures': count, 'until': until?.millisecondsSinceEpoch}));
  }

  /// Ключ для отпечатка на этом телефоне.
  Future<bool> hasFingerprintKey() async => await _fingerprintKey.read() != null;

  /// Открыть скрытое ключом, сохранённым для отпечатка; сам отпечаток уже проверен.
  Future<bool> openWithFingerprint() async {
    final saved = await _fingerprintKey.read();
    if (saved == null || _lock == null) return false;
    final keys = await keysFromPrivate(base64.decode(saved));
    if (keys.publicKey.join(',') != _lock!.keys.publicKey.join(',')) {
      await _fingerprintKey.write(null);
      return false;
    }
    await _open(keys);
    return true;
  }

  /// Запомнить ключи для отпечатка: переданные или те, которыми скрытое сейчас открыто.
  Future<bool> rememberForFingerprint([SealKeys? keys]) async {
    final chosen = keys ?? _keys;
    if (chosen == null) return false;
    await _fingerprintKey.write(base64.encode(await chosen.privateBytes()));
    _changes.add(null);
    return true;
  }

  Future<void> forgetFingerprint() async {
    await _fingerprintKey.write(null);
    _changes.add(null);
  }

  /// Завести код: новые ключи. Скрытое пустое, но открыто — в него можно класть сразу.
  Future<SealKeys> createCode(String code, {KdfSettings kdf = const KdfSettings()}) => _serial(() async {
    final (file, keys) = await createLock(code, kdf: kdf);
    await _saveLock(PrivacyLock(keys: file));
    _keys = keys;
    _manifest = null;
    return keys;
  });

  /// Сменить код; старый неверный — false.
  Future<bool> changeCode(String old, String code) async {
    final keys = await checkCode(old);
    final lock = _lock;
    if (keys == null || lock == null) return false;
    await _saveLock(lock.copyWith(keys: await rewrapLock(lock.keys, keys, code)));
    return true;
  }

  Future<void> setAppLock(bool on) async {
    final lock = _lock;
    if (lock != null) await _saveLock(lock.copyWith(appLock: on));
  }

  Future<void> setCloseAfter(Duration delay) async {
    final lock = _lock;
    if (lock != null) await _saveLock(lock.copyWith(closeAfter: delay));
  }

  Future<void> _open(SealKeys keys) => _serial(() async {
    if (_keys != null) return;
    final store = _store;
    if (store == null) return;
    await _forgetOpen();
    final manifest = await store.unseal(openDir, keys);
    await _setState('unsealed');
    final rows = File(p.join(openDir.path, 'rows.json'));
    if (await rows.exists()) {
      await restoreHidden(_db, (jsonDecode(await rows.readAsString()) as Map).cast<String, Object?>(), openRoot: openDir.path);
    }
    await _setState('open $_pid');
    // напоминания снова в базе целиком
    if (await _remindersFile.exists()) await _remindersFile.delete();
    _keys = keys;
    _manifest = manifest;
    await SealedSpace.load(_db);
    _changes.add(null);
  });

  /// Закрыть скрытое: строки — в копию, копия — запечатать, строки и открытое — стереть.
  Future<void> close() => _serial(() async {
    final keys = _keys;
    if (keys == null) return;
    await _flush();
    await _sealAndForget(keys.publicKey, previous: _manifest);
    _keys = null;
    _manifest = null;
    _changes.add(null);
  });

  Future<void> _sealAndForget(List<int> publicKey, {required SealedManifest? previous}) async {
    final store = _store;
    if (store == null) return;
    await openDir.create(recursive: true);
    final dump = await dumpHidden(_db, openRoot: openDir.path);
    final rows = File(p.join(openDir.path, 'rows.json'));
    await rows.writeAsString(jsonEncode(dump), flush: true);
    await store.seal(openDir, publicKey, previous: previous);
    // копия записана — теперь главнее она: обрыв дальше ничего не потеряет
    await _setState('unsealed');
    final reminders = await _remindersNow();
    await _remindersFile.writeAsString(jsonEncode([for (final one in reminders) {'id': one.itemId, 'at': one.at.millisecondsSinceEpoch}]), flush: true);
    await _forgetOpen();
  }

  Future<List<SealedReminder>> _remindersNow() async {
    final rows = await _db
        .customSelect(
          'SELECT id, reminder_at FROM items WHERE deleted_at IS NULL AND reminder_at IS NOT NULL AND folder_id IN (SELECT id FROM folders WHERE hidden = 1)',
          readsFrom: {_db.items, _db.folders},
        )
        .get();
    return [for (final row in rows) SealedReminder(row.read<String>('id'), row.read<DateTime>('reminder_at'))];
  }

  /// Напоминания закрытого скрытого после [after]: звенят без текста.
  Future<List<SealedReminder>> sealedReminders(DateTime after) async {
    if (!await _remindersFile.exists()) return const [];
    try {
      final rows = jsonDecode(await _remindersFile.readAsString()) as List;
      return [
        for (final row in rows.cast<Map<String, Object?>>())
          if (DateTime.fromMillisecondsSinceEpoch(row['at']! as int).isAfter(after)) SealedReminder(row['id']! as String, DateTime.fromMillisecondsSinceEpoch(row['at']! as int)),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _forgetOpen() async {
    await deleteHidden(_db);
    if (await openDir.exists()) await openDir.delete(recursive: true);
    if (await _stateFile.exists()) await _stateFile.delete();
    SealedSpace.clear();
  }

  /// Скрыть папку с вложенными. Скрытое должно быть открыто: копия дополняется, а не пишется заново.
  Future<void> hideFolder(String folderId) => _serial(() async {
    if (_keys == null) throw StateError('скрытое закрыто');
    await _setState('open $_pid');
    final subtree = await _subtree(folderId);
    await _markHidden(subtree, hidden: true);
    await SealedSpace.load(_db);
    _changes.add(null);
  });

  /// Вернуть папку из скрытых: её заметки снова файлами в хранилище.
  Future<void> unhideFolder(String folderId) => _serial(() async {
    if (_keys == null) throw StateError('скрытое закрыто');
    await _markHidden(await _subtree(folderId), hidden: false);
    await SealedSpace.load(_db);
    _changes.add(null);
  });

  Future<Set<String>> _subtree(String folderId) async {
    final rows = await _db.select(_db.folders).get();
    final tree = FolderTree([for (final row in rows) FolderNode(id: row.id, name: row.name, parentId: row.parentId)]);
    return {folderId, ...tree.descendants(folderId)};
  }

  Future<void> _markHidden(Set<String> folders, {required bool hidden}) async {
    final marks = List.filled(folders.length, '?').join(', ');
    await _db.transaction(() async {
      await _db.customUpdate('UPDATE folders SET hidden = ? WHERE id IN ($marks)', variables: [Variable.withBool(hidden), for (final id in folders) Variable.withString(id)], updates: {_db.folders});
      // заметки папок переезжают: писатель хранилища уносит или возвращает их файлы
      await _db.customStatement(
        "INSERT INTO vault_queue (target) SELECT 'item:' || id FROM items WHERE folder_id IN ($marks) "
        'ON CONFLICT(target) DO UPDATE SET version = version + 1, claimed_until = NULL',
        [...folders],
      );
    });
    await _flush();
  }

  /// «Забыл код»: замок снимается, скрытое стирается насовсем.
  Future<void> forget() => _serial(() async {
    await _store?.wipe();
    await _forgetOpen();
    if (await _remindersFile.exists()) await _remindersFile.delete();
    if (await _attemptsFile.exists()) await _attemptsFile.delete();
    await _fingerprintKey.write(null);
    await _saveLock(null);
    _keys = null;
    _manifest = null;
  });

  /// Есть ли запечатанное скрытое в хранилище.
  Future<bool> hasSealed() async => await _store?.hasSealed() ?? false;

  Future<String?> _state() async => await _stateFile.exists() ? (await _stateFile.readAsString()).trim() : null;

  Future<void> _setState(String state) async {
    await _stateFile.parent.create(recursive: true);
    await _stateFile.writeAsString(state, flush: true);
  }
}
