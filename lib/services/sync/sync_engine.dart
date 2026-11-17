/// Движок синхронизации хранилища: забирает с сервера чужие правки, склеивает
/// расхождения и отправляет свои. Работает с файлами, а не со строками базы:
/// пришедший файл потом подхватывает обычная сверка, как правку из Obsidian.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as hash;

import 'merge.dart';
import 'sync_crypto.dart';
import 'sync_ports.dart';

enum SyncError {
  /// Сеть оборвалась или сервер не ответил: проход доделается в следующий раз.
  network,

  /// Папку хранилища не удалось обойти целиком: удаления не отправлены.
  vaultUnreadable,

  /// Пропало слишком много файлов разом: удаления не отправлены.
  massDelete,
}

class SyncReport {
  int pulled = 0;
  int pushed = 0;
  int deleted = 0;
  int merged = 0;

  /// Файлов отложено: изменение пришло, часть не скачалась.
  int waiting = 0;
  SyncError? error;

  @override
  String toString() => 'SyncReport(pulled: $pulled, pushed: $pushed, deleted: $deleted, merged: $merged, waiting: $waiting, error: $error)';
}

/// Синхронизируется ли путь. Обложки, кадры, копии страниц, кэш и входящие
/// пересчитываются на каждом телефоне; раскладка окон Obsidian своя у каждого.
bool syncable(String path) {
  if (path.endsWith('.tmp')) return false;
  const skip = ['.stowa/covers/', '.stowa/frames/', '.stowa/pages/', '.stowa/articles/', '.stowa/cache/', '.stowa/incoming/'];
  for (final prefix in skip) {
    if (path.startsWith(prefix)) return false;
  }
  if (path.startsWith('.obsidian/workspace')) return false;
  return true;
}

bool _isNote(String path) => path.toLowerCase().endsWith('.md');

bool _isMetaJson(String path) => path.startsWith('.stowa/') && !path.startsWith('.stowa/sealed/') && path.endsWith('.json');

/// Тень держим для текстов до этого размера: склейка больших идёт без общей версии.
const _shadowLimit = 20 * 1024 * 1024;

class SyncEngine {
  SyncEngine({
    required this.vault,
    required this.remote,
    required this.state,
    required this.key,
    this.loser,
    this.chunk = syncChunk,
    this.parallel = 6,
    Future<T> Function<T>(Future<T> Function() work)? exclusive,
    this.heartbeat,
  }) : exclusive = exclusive ?? _direct;

  static Future<T> _direct<T>(Future<T> Function() work) => work();

  /// Аренда сверки хранилища: под ней движок кладёт пришедшие файлы.
  final Future<T> Function<T>(Future<T> Function() work) exclusive;

  /// Продлить аренду посреди долгой работы.
  final Future<void> Function()? heartbeat;

  final SyncFiles vault;
  final SyncRemote remote;
  final SyncState state;
  final VaultKey key;

  /// Проигравшая версия заметки, когда одно место правили на двух телефонах.
  final void Function(String path, String text)? loser;

  final int chunk;

  /// Сколько файлов идёт разом. Сервер в Москве, до него ~100 мс: по одному три
  /// тысячи файлов College уходили бы 40 минут. Больше не надо — Hetzner под
  /// большим числом потоков отвечает 400 и 504.
  final int parallel;

  /// Сделать [work] для каждого, по [parallel] разом. Первая ошибка — после того,
  /// как начатые доделались: память о файлах не остаётся наполовину записанной.
  Future<void> _each<T>(List<T> items, Future<void> Function(T item) work) async {
    var next = 0;
    Object? failure;
    StackTrace? trace;
    Future<void> worker() async {
      while (failure == null && next < items.length) {
        final item = items[next++];
        try {
          await work(item);
        } catch (error, stack) {
          failure ??= error;
          trace ??= stack;
        }
      }
    }

    await Future.wait([for (var i = 0; i < min(parallel, items.length); i++) worker()]);
    if (failure case final error?) Error.throwWithStackTrace(error, trace!);
  }

  /// Сколько удалений разом считается пропажей, а не уборкой.
  static const massDeleteCount = 20;
  static const massDeleteShare = 0.3;

  /// Память о синхронизированном на время прохода: копия [state], пишется в обе стороны.
  Map<String, SyncedFile> _known = {};

  /// Файлы, на которых сервер отказал по ревизии в этом проходе.
  final _conflicts = <String>{};

  Future<void> _put(SyncedFile file) async {
    _known[file.file] = file;
    await state.put(file);
  }

  Future<SyncReport> sync() async {
    final report = SyncReport();
    _known = await state.files();
    final Map<String, LocalFile> local;
    try {
      local = {};
      for (final file in await vault.list()) {
        if (syncable(file.path)) local[key.fileId(file.path)] = file;
      }
    } on Object {
      report.error = SyncError.vaultUnreadable;
      return report;
    }
    try {
      // сперва забрать, потом отправить; сервер отказал по ревизии — забрать и повторить
      for (var round = 0; round < 3; round++) {
        // файлы на диск кладутся только при приёме: аренда сверки нужна только ему
        await exclusive(() async {
          await _pull(local, report);
          // ревизию, которую курсор уже прошёл, спрашиваем у сервера по одному файлу
          for (final file in _conflicts.toList()) {
            final current = await remote.file(file);
            if (current != null) await _apply(current, local, report);
            _conflicts.remove(file);
          }
        });
        if (!await _push(local, report)) break;
      }
    } on _MassDelete {
      report.error = SyncError.massDelete;
    } on Object {
      report.error = SyncError.network;
    }
    // часть файлов отложена: проход не полный, следующий их дочитает
    if (report.waiting > 0) report.error ??= SyncError.network;
    return report;
  }

  // ── приём ──

  Future<void> _pull(Map<String, LocalFile> local, SyncReport report) async {
    // отложенные с прошлых проходов дочитываются по одному файлу
    final waiting = await state.pending();
    await _each(waiting.toList(), (file) async {
      try {
        final current = await remote.file(file);
        if (current != null) await _apply(current, local, report);
        await state.setPending(file, false);
      } on Object {
        report.waiting++;
      }
    });
    var cursor = await state.cursor();
    while (true) {
      final page = await remote.changes(cursor);
      // в странице каждый файл один раз: файлы приходят параллельно. Застрял в бакете
      // (Hetzner отдаёт отдельные объекты по две минуты) — файл откладывается, курсор
      // идёт дальше: иначе один файл держал бы все остальные
      await _each(page.changes, (change) async {
        await heartbeat?.call();
        try {
          await _apply(change, local, report);
          if (waiting.contains(change.file)) await state.setPending(change.file, false);
        } on Object {
          await state.setPending(change.file, true);
          report.waiting++;
        }
      });
      cursor = page.cursor;
      await state.setCursor(cursor);
      if (!page.more) break;
    }
  }

  Future<void> _apply(RemoteChange change, Map<String, LocalFile> local, SyncReport report) async {
    final known = _known[change.file];
    if (known != null && change.rev <= known.rev) return;
    final meta = await key.openMeta(change.meta);
    final mine = local[change.file];
    final mineHash = mine == null ? null : await _hashOf(mine, known);
    final mineChanged = mine != null && (known == null || mineHash != known.hash);

    if (change.deleted) {
      if (mine != null && !mineChanged) {
        await vault.delete(mine.path);
        local.remove(change.file);
        report.deleted++;
      }
      // надгробие: ревизия удаления. Правка здесь уйдёт поверх него, новый файл с тем же
      // именем — тоже, а не упрётся в отказ по ревизии
      await _put(SyncedFile(file: change.file, path: mine?.path ?? meta.path, rev: change.rev, hash: '', size: -1, mtime: -1));
      await state.setShadow(change.file, null);
      return;
    }

    final path = mine?.path ?? meta.path;
    if (!mineChanged) {
      // здесь не правили или файл удалён здесь: правка оттуда побеждает удаление
      await _download(change, meta, path, local, report);
      return;
    }
    if (mineHash == meta.hash) {
      await _remember(change.file, path, change.rev, meta.hash, local);
      return;
    }
    if (_isNote(path) || _isMetaJson(path)) {
      final theirs = utf8.decode(await _fetch(change), allowMalformed: true);
      final ours = utf8.decode(await vault.read(path, 0, mine.size), allowMalformed: true);
      final base = await state.shadow(change.file) ?? '';
      final oursNewer = mine.mtime > meta.mtime;
      String text;
      if (_isNote(path)) {
        final result = mergeText(base, ours, theirs, oursNewer: oursNewer);
        text = result.text;
        if (result.loser != null) loser?.call(path, result.loser!);
      } else {
        text = mergeJsonTables(base, ours, theirs, oursNewer: oursNewer);
      }
      if (text != ours) await vault.write(path, Stream.value(utf8.encode(text)));
      // запоминаем пришедшую ревизию: склеенный текст отличается от неё и уйдёт при отправке
      await _remember(change.file, path, change.rev, meta.hash, local, differs: text != theirs);
      await state.setShadow(change.file, theirs.length <= _shadowLimit ? theirs : null);
      report.merged++;
      return;
    }
    // фото и прочее: побеждает свежее, прежнее остаётся ревизией на сервере
    if (meta.mtime >= mine.mtime) {
      await _download(change, meta, path, local, report);
    } else {
      await _put(SyncedFile(file: change.file, path: path, rev: change.rev, hash: meta.hash, size: -1, mtime: -1));
    }
  }

  Future<List<int>> _fetch(RemoteChange change) async {
    final out = <int>[];
    for (final blob in change.blobs) {
      out.addAll(await key.openChunk(await remote.getBlob(blob)));
    }
    return out;
  }

  Future<void> _download(RemoteChange change, FileMeta meta, String path, Map<String, LocalFile> local, SyncReport report) async {
    // части скачиваются и открываются по одной: весь файл в памяти не держим
    Stream<List<int>> parts() async* {
      for (final blob in change.blobs) {
        await heartbeat?.call();
        yield await key.openChunk(await remote.getBlob(blob));
      }
    }

    await vault.write(path, parts());
    final written = await _remember(change.file, path, change.rev, meta.hash, local);
    if (written != null && (_isNote(path) || _isMetaJson(path)) && written.size <= _shadowLimit) {
      await state.setShadow(change.file, utf8.decode(await vault.read(path, 0, written.size), allowMalformed: true));
    }
    report.pulled++;
  }

  /// Запомнить, что файл на диске совпадает с ревизией [rev]. [differs] — на диске другой
  /// текст (склейка): тогда размер и время не запоминаем, файл уйдёт при отправке.
  Future<LocalFile?> _remember(String file, String path, int rev, String contentHash, Map<String, LocalFile> local, {bool differs = false}) async {
    final now = await vault.stat(path);
    if (now != null) local[file] = now;
    final same = !differs && now != null;
    await _put(SyncedFile(file: file, path: path, rev: rev, hash: contentHash, size: same ? now.size : -1, mtime: same ? now.mtime : -1));
    return now;
  }

  // ── отправка ──

  /// Отправить свои правки. true — сервер отказал по ревизии, нужен ещё круг приёма.
  Future<bool> _push(Map<String, LocalFile> local, SyncReport report) async {
    final known = Map.of(_known);
    var conflict = false;
    final changed = [
      for (final MapEntry(key: file, value: seen) in local.entries)
        if (known[file] case final was when was != null && was.size == seen.size && was.mtime == seen.mtime) ...[] else (file, seen),
    ];
    await _each(changed, (pair) async {
      final (file, seen) = pair;
      final result = await _upload(file, seen, known[file]);
      if (result == null) return;
      if (result is Conflict) {
        conflict = true;
        _conflicts.add(file);
      } else {
        report.pushed++;
      }
    });

    // удаления: файл был синхронизирован, а на диске его нет; надгробия не в счёт
    final alive = known.values.where((was) => was.hash.isNotEmpty).toList();
    final gone = [
      for (final was in alive)
        if (!local.containsKey(was.file)) was,
    ];
    if (gone.length > massDeleteCount && gone.length > alive.length * massDeleteShare) throw const _MassDelete();
    for (final was in gone) {
      final meta = FileMeta(path: was.path, mtime: DateTime.now().millisecondsSinceEpoch, size: 0, hash: '', deleted: true);
      final result = await remote.commit(was.file, baseRev: was.rev, meta: await key.sealMeta(meta), blobs: const [], size: 0, deleted: true);
      if (result is Conflict) {
        conflict = true;
        _conflicts.add(was.file);
        continue;
      }
      await _put(SyncedFile(file: was.file, path: was.path, rev: (result as Committed).rev, hash: '', size: -1, mtime: -1));
      await state.setShadow(was.file, null);
      report.deleted++;
    }
    return conflict;
  }

  /// Отправить файл. null — содержимое уже на сервере или файл меняется прямо сейчас.
  Future<CommitResult?> _upload(String file, LocalFile seen, SyncedFile? was) async {
    final blobs = <String>[];
    final whole = _Digest();
    final sink = hash.sha256.startChunkedConversion(whole);
    var offset = 0;
    final parts = <List<int>>[];
    // сперва отпечаток: совпал с ревизией — отправлять нечего
    while (offset < seen.size || (offset == 0 && seen.size == 0)) {
      final plain = await vault.read(seen.path, offset, min(chunk, seen.size - offset));
      sink.add(plain);
      if (seen.size <= chunk) parts.add(plain);
      offset += plain.length;
      if (plain.isEmpty) break;
    }
    sink.close();
    final contentHash = whole.value.toString();
    if (was != null && was.hash == contentHash) {
      await _put(SyncedFile(file: file, path: seen.path, rev: was.rev, hash: was.hash, size: seen.size, mtime: seen.mtime));
      return null;
    }
    offset = 0;
    var index = 0;
    while (offset < seen.size) {
      final plain = parts.length > index ? parts[index] : await vault.read(seen.path, offset, min(chunk, seen.size - offset));
      final box = await key.sealChunk(plain);
      final name = sha256Hex(box);
      // большую часть сперва ищем на сервере (докачка после обрыва), мелкую дешевле просто отправить
      if (box.length < min(_askFirst, chunk ~/ 2) || !await remote.hasBlob(name)) await remote.putBlob(name, box);
      blobs.add(name);
      offset += plain.length;
      index++;
    }
    // файл поменялся, пока читали: отправим целым в следующий раз
    final after = await vault.stat(seen.path);
    if (after == null || after.size != seen.size || after.mtime != seen.mtime) return null;

    final meta = FileMeta(path: seen.path, mtime: seen.mtime, size: seen.size, hash: contentHash);
    final result = await remote.commit(file, baseRev: was?.rev ?? 0, meta: await key.sealMeta(meta), blobs: blobs, size: seen.size);
    if (result is Committed) {
      await _put(SyncedFile(file: file, path: seen.path, rev: result.rev, hash: contentHash, size: seen.size, mtime: seen.mtime));
      if ((_isNote(seen.path) || _isMetaJson(seen.path)) && seen.size <= _shadowLimit) {
        await state.setShadow(file, utf8.decode(await vault.read(seen.path, 0, seen.size), allowMalformed: true));
      }
    }
    return result;
  }

  /// Отпечаток файла на диске; совпали размер и время с запомненными — не читаем.
  Future<String> _hashOf(LocalFile file, SyncedFile? known) async {
    if (known != null && known.size == file.size && known.mtime == file.mtime) return known.hash;
    final whole = _Digest();
    final sink = hash.sha256.startChunkedConversion(whole);
    var offset = 0;
    while (offset < file.size) {
      final plain = await vault.read(file.path, offset, min(chunk, file.size - offset));
      if (plain.isEmpty) break;
      sink.add(plain);
      offset += plain.length;
    }
    sink.close();
    return whole.value.toString();
  }
}

/// С какого размера часть сперва ищется на сервере, а не отправляется сразу.
const _askFirst = 256 * 1024;

class _MassDelete implements Exception {
  const _MassDelete();
}

class _Digest implements Sink<hash.Digest> {
  late hash.Digest value;

  @override
  void add(hash.Digest data) => value = data;

  @override
  void close() {}
}
