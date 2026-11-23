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
import 'sync_progress.dart';

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

  /// Файлов отложено: изменение пришло, часть не скачалась или файл правили.
  int waiting = 0;

  /// Пути, которые проход положил или удалил на диске: их забирает сверка.
  final received = <String>[];

  /// Пути, ушедшие на сервер.
  final sent = <String>[];
  SyncError? error;

  @override
  String toString() => 'SyncReport(pulled: $pulled, pushed: $pushed, deleted: $deleted, merged: $merged, waiting: $waiting, error: $error)';
}

/// Синхронизируется ли путь. Кадры, копии страниц, кэш и входящие пересчитываются на
/// каждом телефоне; раскладка окон Obsidian своя у каждого. Обложки ссылок ездят (21.11):
/// пришедшая заметка уже с превью, второй телефон его не качает, а браузер не может вовсе.
bool syncable(String path) {
  if (path.endsWith('.tmp')) return false;
  const skip = ['.stowa/frames/', '.stowa/pages/', '.stowa/articles/', '.stowa/cache/', '.stowa/incoming/'];
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
    this.onProgress,
    Future<T> Function<T>(Future<T> Function() work)? exclusive,
  }) : exclusive = exclusive ?? _direct;

  /// Ход приёма и отправки для экрана: зовётся на каждый файл и каждую часть.
  final void Function(SyncProgress progress)? onProgress;

  static Future<T> _direct<T>(Future<T> Function() work) => work();

  /// Аренда сверки хранилища: под ней движок ставит на место один пришедший файл.
  final Future<T> Function<T>(Future<T> Function() work) exclusive;

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

  // ── ход для экрана ──

  SyncStage? _stage;
  int _done = 0;
  int _total = 0;
  int _bytesDone = 0;
  int _bytesTotal = 0;
  String? _file;

  /// Файл → байты, уже пришедшие или ушедшие: большой файл двигает ход частями.
  final _flight = <String, int>{};

  /// Этап начат или к нему прибавилось: [files] и [bytes] — к итогу. Новый этап считается
  /// с нуля; приём после отправки (сервер отказал по ревизии) — тоже.
  void _expect(SyncStage stage, {required int files, int bytes = 0}) {
    if (_stage != stage) {
      _stage = stage;
      _done = 0;
      _total = 0;
      _bytesDone = 0;
      _bytesTotal = 0;
      _file = null;
      _flight.clear();
    }
    _total += files;
    _bytesTotal += bytes;
    _tell();
  }

  void _tell() {
    final tell = onProgress;
    final stage = _stage;
    if (tell == null || stage == null) return;
    var flying = 0;
    for (final bytes in _flight.values) {
      flying += bytes;
    }
    tell(SyncProgress(stage, done: _done, total: _total, bytesDone: _bytesDone + flying, bytesTotal: _bytesTotal, file: _file));
  }

  /// Часть файла [file] пришла или ушла.
  void _part(String file, int bytes, {required String path}) {
    _flight[file] = (_flight[file] ?? 0) + bytes;
    _file = path;
    _tell();
  }

  /// Файл [file] доделан — лёг, ушёл, совпал или отложен до следующего прохода: его [size] — в счёт.
  void _settled(String file, int size) {
    _flight.remove(file);
    _done++;
    _bytesDone += size;
    _tell();
  }

  Future<void> _put(SyncedFile file) async {
    _known[file.file] = file;
    await state.put(file);
  }

  Future<SyncReport> sync() async {
    final report = SyncReport();
    _stage = null;
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
        await _pull(local, report);
        // ревизию, которую курсор уже прошёл, спрашиваем у сервера по одному файлу
        _expect(SyncStage.receive, files: _conflicts.length);
        for (final file in _conflicts.toList()) {
          final current = await remote.file(file);
          if (current != null) {
            _expect(SyncStage.receive, files: 0, bytes: current.size);
            await _apply(current, local, report);
          }
          _conflicts.remove(file);
          _settled(file, current?.size ?? 0);
        }
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
    final waiting = await state.pending();
    // сперва все страницы, потом файлы: сколько придёт файлов и байт, экран знает до первого
    // файла. Страница — только заголовки, тысяча весит сотни килобайт
    final pages = <ChangePage>[];
    var cursor = await state.cursor();
    while (true) {
      final page = await remote.changes(cursor);
      pages.add(page);
      cursor = page.cursor;
      if (!page.more) break;
    }
    // в счёт только то, что ляжет: свои же правки, вернувшиеся с сервера, пропускаются сразу
    final due = [
      for (final page in pages)
        for (final change in page.changes)
          if (change.rev > (_known[change.file]?.rev ?? 0) && !waiting.contains(change.file)) change,
    ];
    final counted = {for (final change in due) change.file};
    _expect(SyncStage.receive, files: waiting.length + due.length, bytes: due.fold<int>(0, (sum, change) => sum + change.size));

    // отложенные с прошлых проходов дочитываются по одному файлу
    await _each(waiting.toList(), (file) async {
      var size = 0;
      try {
        final current = await remote.file(file);
        if (current != null) {
          size = current.size;
          _expect(SyncStage.receive, files: 0, bytes: size);
          await _apply(current, local, report);
        }
        await state.setPending(file, false);
      } on Object {
        report.waiting++;
      }
      _settled(file, size);
    });
    for (final page in pages) {
      // в странице каждый файл один раз: файлы приходят параллельно. Застрял в бакете
      // (Hetzner отдаёт отдельные объекты по две минуты) — файл откладывается, курсор
      // идёт дальше: иначе один файл держал бы все остальные
      await _each(page.changes, (change) async {
        try {
          await _apply(change, local, report);
          if (waiting.contains(change.file)) await state.setPending(change.file, false);
        } on Object {
          await state.setPending(change.file, true);
          report.waiting++;
        }
        if (counted.contains(change.file)) _settled(change.file, change.size);
      });
      await state.setCursor(page.cursor);
    }
  }

  Future<void> _apply(RemoteChange change, Map<String, LocalFile> local, SyncReport report) async {
    final known = _known[change.file];
    if (known != null && change.rev <= known.rev) return;
    final meta = await key.openMeta(change.meta);
    // свежий взгляд на диск, а не снимок начала прохода: проход идёт минуты, а писатель
    // за это время мог положить правку
    final mine = await vault.stat(local[change.file]?.path ?? meta.path);
    final mineHash = mine == null ? null : await _hashOf(mine, known);
    final mineChanged = mine != null && (known == null || mineHash != known.hash);

    if (change.deleted) {
      if (mine != null && !mineChanged) {
        if (!await exclusive(() => vault.delete(mine.path, expect: mine))) throw const _Moved();
        local.remove(change.file);
        report.deleted++;
        report.received.add(mine.path);
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
      await _download(change, meta, path, mine, local, report);
      return;
    }
    if (mineHash == meta.hash) {
      await _remember(change.file, path, change.rev, meta.hash, local);
      return;
    }
    if (_isNote(path) || _isMetaJson(path)) {
      final theirs = utf8.decode(await _fetch(change, path), allowMalformed: true);
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
      if (text != ours) {
        final staged = await vault.stage(path, Stream.value(utf8.encode(text)));
        if (!await exclusive(() => vault.place(staged, path, expect: mine))) throw const _Moved();
        report.received.add(path);
      }
      // запоминаем пришедшую ревизию: склеенный текст отличается от неё и уйдёт при отправке
      await _remember(change.file, path, change.rev, meta.hash, local, differs: text != theirs);
      await state.setShadow(change.file, theirs.length <= _shadowLimit ? theirs : null);
      report.merged++;
      return;
    }
    // фото и прочее: побеждает свежее, прежнее остаётся ревизией на сервере
    if (meta.mtime >= mine.mtime) {
      await _download(change, meta, path, mine, local, report);
    } else {
      await _put(SyncedFile(file: change.file, path: path, rev: change.rev, hash: meta.hash, size: -1, mtime: -1));
    }
  }

  Future<List<int>> _fetch(RemoteChange change, String path) async {
    final out = <int>[];
    for (final blob in change.blobs) {
      final plain = await key.openChunk(await remote.getBlob(blob));
      out.addAll(plain);
      _part(change.file, plain.length, path: path);
    }
    return out;
  }

  /// Скачать ревизию и поставить на место [path], если там всё ещё [mine].
  Future<void> _download(RemoteChange change, FileMeta meta, String path, LocalFile? mine, Map<String, LocalFile> local, SyncReport report) async {
    // части скачиваются и открываются по одной: весь файл в памяти не держим
    Stream<List<int>> parts() async* {
      for (final blob in change.blobs) {
        final plain = await key.openChunk(await remote.getBlob(blob));
        _part(change.file, plain.length, path: path);
        yield plain;
      }
    }

    // качаем без аренды, ставим на место под арендой: сверка ждёт одно переименование
    final staged = await vault.stage(path, parts());
    if (!await exclusive(() => vault.place(staged, path, expect: mine))) throw const _Moved();
    report.received.add(path);
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
    final changed = <(String, LocalFile)>[
      for (final MapEntry(key: file, value: seen) in local.entries)
        if (known[file] case final was when was != null && was.size == seen.size && was.mtime == seen.mtime) ...[] else (file, seen),
    ];
    // удаления: файл был синхронизирован, а на диске его нет; надгробия не в счёт
    final alive = known.values.where((was) => was.hash.isNotEmpty).toList();
    final gone = [
      for (final was in alive)
        if (!local.containsKey(was.file)) was,
    ];
    // переезд: пропавший файл и новый — один и тот же. Заметка узнаётся по id в шапке (у
    // пропавшей — по тени), остальное — по содержимому. Связь едет в заголовках, и история
    // идёт через переименование дальше назад
    final moves = await _Moves.of(gone, state);

    // на втором телефоне с той же копией почти все файлы только сверяются: экран зовёт
    // этап «сверяю и отправляю», а в счёт идут и совпавшие
    _expect(SyncStage.send, files: changed.length + gone.length, bytes: changed.fold(0, (sum, pair) => sum + pair.$2.size));
    await _each(changed, (pair) async {
      final (file, seen) = pair;
      _file = seen.path;
      final was = known[file];
      final result = await _upload(file, seen, was, moves: was == null || was.hash.isEmpty ? moves : null);
      _settled(file, seen.size);
      if (result == null) return;
      if (result is Conflict) {
        conflict = true;
        _conflicts.add(file);
      } else {
        report.pushed++;
        report.sent.add(seen.path);
      }
    });

    if (gone.length > massDeleteCount && gone.length > alive.length * massDeleteShare) throw const _MassDelete();
    for (final was in gone) {
      // переехавший файл ещё не дошёл до сервера: надгробие подождёт, иначе связь потеряется
      if (moves.waiting(was.file)) continue;
      _file = was.path;
      final meta = FileMeta(path: was.path, mtime: DateTime.now().millisecondsSinceEpoch, size: 0, hash: '', deleted: true, to: moves.movedTo[was.file]);
      final result = await remote.commit(was.file, baseRev: was.rev, meta: await key.sealMeta(meta), blobs: const [], size: 0, deleted: true);
      _settled(was.file, 0);
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
  /// [moves] — для файла, которого на этом пути ещё не было: вдруг он сюда переехал.
  Future<CommitResult?> _upload(String file, LocalFile seen, SyncedFile? was, {_Moves? moves}) async {
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
      _part(file, plain.length, path: seen.path);
      blobs.add(name);
      offset += plain.length;
      index++;
    }
    // файл поменялся, пока читали: отправим целым в следующий раз
    final after = await vault.stat(seen.path);
    if (after == null || after.size != seen.size || after.mtime != seen.mtime) return null;

    final noteId = moves == null || !_isNote(seen.path) ? null : noteIdIn(utf8.decode(await vault.read(seen.path, 0, min(1024, seen.size)), allowMalformed: true));
    final prev = moves?.claim(file, noteId: noteId, hash: contentHash);
    final meta = FileMeta(path: seen.path, mtime: seen.mtime, size: seen.size, hash: contentHash, prev: prev);
    final result = await remote.commit(file, baseRev: was?.rev ?? 0, meta: await key.sealMeta(meta), blobs: blobs, size: seen.size);
    if (prev != null) moves!.settle(prev, file, committed: result is Committed);
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

/// `id` заметки из её шапки: первые строки файла в формате Obsidian.
String? noteIdIn(String head) {
  if (!head.startsWith('---')) return null;
  final end = head.indexOf('\n---', 3);
  final header = end < 0 ? head : head.substring(0, end);
  return RegExp(r'^id:\s*"?([^"\n]+?)"?\s*$', multiLine: true).firstMatch(header)?.group(1)?.trim();
}

/// Переезды одного прохода: какой пропавший файл стал каким новым. Пропавший достаётся
/// одному новому — копия с тем же содержимым переезд не крадёт.
class _Moves {
  _Moves(this._byId, this._byHash);

  static Future<_Moves> of(List<SyncedFile> gone, SyncState state) async {
    final byId = <String, SyncedFile>{}, byHash = <String, SyncedFile>{};
    for (final was in gone) {
      byHash.putIfAbsent(was.hash, () => was);
      if (!_isNote(was.path)) continue;
      final id = noteIdIn(await state.shadow(was.file) ?? '');
      if (id != null) byId.putIfAbsent(id, () => was);
    }
    return _Moves(byId, byHash);
  }

  final Map<String, SyncedFile> _byId;
  final Map<String, SyncedFile> _byHash;

  /// Занятые пропавшие: номер пропавшего → номер нового, ещё не отправленного.
  final _claimed = <String, String>{};

  /// Пропавший → новый, уже на сервере: номер нового ляжет в надгробие.
  final movedTo = <String, String>{};

  /// Новый файл [file] — переезд? Номер прежнего пути или null. Заметка ищется по id,
  /// всё остальное — по содержимому.
  String? claim(String file, {String? noteId, required String hash}) {
    final was = (noteId == null ? null : _byId[noteId]) ?? _byHash[hash];
    if (was == null || _claimed.containsKey(was.file) || movedTo.containsKey(was.file)) return null;
    _claimed[was.file] = file;
    return was.file;
  }

  /// Новый файл ушёл на сервер или нет. Не ушёл — пропавший снова свободен, и его надгробие
  /// в этом проходе не уходит: следующий проход свяжет их заново.
  void settle(String prev, String file, {required bool committed}) {
    if (committed) {
      _claimed.remove(prev);
      movedTo[prev] = file;
    } else {
      _held.add(prev);
      _claimed.remove(prev);
    }
  }

  final _held = <String>{};

  /// Надгробию пропавшего ждать следующего прохода.
  bool waiting(String file) => _held.contains(file) || _claimed.containsKey(file);
}

/// Файл поправили, пока качали: изменение откладывается, следующий проход склеит.
class _Moved implements Exception {
  const _Moved();
}

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
