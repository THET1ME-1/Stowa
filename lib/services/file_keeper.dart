import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/db/database.dart';
import '../domain/image_size.dart';
import 'capture_service.dart' show PickedFile;
import 'vault/vault_layout.dart';

/// Дописать [from] в [part] с места [offset]; [onWritten] получает, сколько уже лежит в [part].
typedef CopyWrite = Future<void> Function(String from, String part, int offset, void Function(int written) onWritten);

const _chunk = 1024 * 1024;

/// Оборванная копия продолжается с места обрыва, а не начинается заново.
Future<void> appendCopy(String from, String part, int offset, void Function(int written) onWritten) async {
  final input = await File(from).open();
  final output = await File(part).open(mode: offset > 0 ? FileMode.append : FileMode.write);
  try {
    await input.setPosition(offset);
    final buffer = Uint8List(_chunk);
    var written = offset;
    while (true) {
      final count = await input.readInto(buffer);
      if (count == 0) break;
      await output.writeFrom(buffer, 0, count);
      written += count;
      onWritten(written);
    }
    await output.flush();
  } finally {
    await input.close();
    await output.close();
  }
}

/// Размер картинки по началу файла: EXIF с миниатюрой занимает до 64 КБ.
Future<({int width, int height})?> imageSizeOfFile(String path) async {
  final file = await File(path).open();
  try {
    return imageSizeOf(await file.read(256 * 1024));
  } finally {
    await file.close();
  }
}

/// Сколько файлов вещи не сохранилось и удалена ли из-за этого пустая вещь.
class CopyFailure {
  const CopyFailure({required this.itemId, required this.failed, required this.removed});

  final String itemId;
  final int failed;
  final bool removed;
}

/// Задачу держат столько после последнего знака жизни, потом её может забрать другой.
const _lease = Duration(seconds: 15);
const _renewEvery = Duration(seconds: 2);

/// После стольких неудач подряд (нет места, файл занят) задача снимается.
const _maxAttempts = 20;

/// Хранитель файлов: кладёт присланное во вложения так, что оно не теряется.
///
/// Файл сначала становится задачей в базе, в одной транзакции с вещью. Потом
/// [drain] переносит его: временный файл приложения (голосовое, «Поделиться»,
/// камера) — мгновенным переименованием, чужой (галерея) — копией в `.part`,
/// которая после обрыва продолжается с того же места. Во вложения файл попадает
/// только целиком. Задачу держит один исполнитель: главное окно, окно
/// «Поделиться» и фон друг другу не мешают.
class FileKeeper {
  FileKeeper(
    this._db, {
    required Directory filesRoot,
    required List<Directory> movable,
    required DateTime Function() clock,
    String? runner,
    CopyWrite write = appendCopy,
    this.onLeftover,
  }) : _filesRoot = filesRoot, // ignore: prefer_initializing_formals
       _movable = [for (final folder in movable) p.normalize(folder.absolute.path)],
       _clock = clock, // ignore: prefer_initializing_formals
       _runner = runner ?? const Uuid().v4(),
       _write = write; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final Directory _filesRoot;
  final List<String> _movable;
  final DateTime Function() _clock;
  final String _runner;
  final CopyWrite _write;

  /// Проход кончился, а задачи остались: попросить систему доделать в фоне.
  Future<void> Function()? onLeftover;

  /// Файл вещи лёг во вложения целиком.
  void Function(String itemId)? onKept;

  Future<void>? _running;
  final _failures = StreamController<CopyFailure>.broadcast();
  final _progress = StreamController<Map<String, double>>.broadcast();
  final _shares = <String, Map<String, (int, int)>>{};
  Map<String, double> _current = const {};

  /// Файлы, которые не удалось сохранить: окно «Поделиться» и главная говорят об этом.
  Stream<CopyFailure> get failures => _failures.stream;

  /// Сколько скопировано у каждой вещи, от 0 до 1.
  Stream<Map<String, double>> get progress => _progress.stream;
  Map<String, double> get current => _current;

  /// Сколько скопировано у вещи, кто бы ни копировал: свой ход из памяти, чужой
  /// (фон, окно «Поделиться») — по длине недописанного файла. Задач нет — null.
  Future<double?> fractionOf(String itemId) async {
    final own = _current[itemId];
    if (own != null) return own;
    final jobs = await (_db.select(_db.fileJobs)..where((t) => t.itemId.equals(itemId))).get();
    if (jobs.isEmpty) return null;
    var done = 0;
    var all = 0;
    for (final job in jobs) {
      final target = File(p.join(_filesRoot.path, job.target));
      final part = File('${target.path}.part');
      all += job.size;
      if (await target.exists()) {
        done += job.size;
      } else if (await part.exists()) {
        done += await part.length();
      }
    }
    return all <= 0 ? 0 : (done / all).clamp(0.0, 1.0);
  }

  /// Записать файлы вещи задачами. Зовётся внутри транзакции сохранения.
  Future<void> enqueue(String itemId, List<PickedFile> files, {int from = 0}) async {
    final now = _clock();
    for (final (offset, file) in files.indexed) {
      final index = from + offset;
      await _db
          .into(_db.fileJobs)
          .insert(
            FileJobsCompanion.insert(
              id: const Uuid().v4(),
              itemId: itemId,
              position: index,
              source: file.path,
              // папку заметки при сохранении ещё не знаешь: файл ждёт во входящих, писатель хранилища
              // переносит его к заметке под настоящим именем
              target: incomingFile(itemId, '${index}_${p.basename(file.path)}'),
              mime: file.mime,
              size: file.size,
              createdAt: now,
            ),
          );
    }
  }

  /// Разобрать очередь. Идущий проход не дублируется: новый вызов ждёт его же,
  /// а задачи, добавленные по ходу, проход подберёт сам.
  Future<void> drain() => _running ??= _drainAll().whenComplete(() => _running = null);

  Future<void> _drainAll() async {
    // страховка до начала: убьют на середине — система доделает сама, не дожидаясь открытия
    final queued = await _db.select(_db.fileJobs).get();
    if (queued.isNotEmpty) await onLeftover?.call();
    // задачи, которые в этот проход не вышли: держит другой исполнитель или нет места
    final skipped = <String>{};
    final failed = <String, int>{};
    var leftover = false;
    while (true) {
      final pending = await (_db.select(_db.fileJobs)..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.position)])).get();
      final next = [for (final job in pending) if (!skipped.contains(job.id)) job];
      if (next.isEmpty) {
        leftover = pending.isNotEmpty;
        break;
      }
      for (final job in next) {
        if (!await _claim(job)) {
          skipped.add(job.id);
          continue;
        }
        switch (await _keep(job)) {
          case _Outcome.kept:
            break;
          case _Outcome.later:
            skipped.add(job.id);
          case _Outcome.lost:
            failed[job.itemId] = (failed[job.itemId] ?? 0) + 1;
        }
      }
    }
    for (final entry in failed.entries) {
      _failures.add(CopyFailure(itemId: entry.key, failed: entry.value, removed: await _dropIfEmpty(entry.key)));
    }
    if (leftover) await onLeftover?.call();
  }

  Future<bool> _claim(FileJob job) async {
    final now = _clock().millisecondsSinceEpoch;
    final taken =
        await (_db.update(_db.fileJobs)..where(
              (t) => t.id.equals(job.id) & (t.claimedUntil.isNull() | t.claimedUntil.isSmallerThanValue(now) | t.claimedBy.equals(_runner)),
            ))
            .write(FileJobsCompanion(claimedBy: Value(_runner), claimedUntil: Value(now + _lease.inMilliseconds)));
    return taken == 1;
  }

  Future<_Outcome> _keep(FileJob job) async {
    final target = File(p.join(_filesRoot.path, job.target));
    final part = File('${target.path}.part');
    // вещь стёрли, пока файл ждал: копировать некуда
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(job.itemId))).getSingleOrNull();
    if (item == null) {
      await (_db.delete(_db.fileJobs)..where((t) => t.id.equals(job.id))).go();
      return _Outcome.kept;
    }
    // ход считается по всем файлам вещи сразу, а не по одному
    if (!_shares.containsKey(job.itemId)) {
      final siblings = await (_db.select(_db.fileJobs)..where((t) => t.itemId.equals(job.itemId))).get();
      _shares[job.itemId] = {for (final sibling in siblings) sibling.id: (0, sibling.size)};
    }
    try {
      await target.parent.create(recursive: true);
      // файл уже лёг, а база не успела записать: только запись
      final already = await target.exists() && (job.size <= 0 || await target.length() == job.size);
      if (!already) {
        final source = File(job.source);
        if (!await source.exists()) {
          await (_db.delete(_db.fileJobs)..where((t) => t.id.equals(job.id))).go();
          return _Outcome.lost;
        }
        final ours = _isMovable(job.source);
        if (!(ours && await _rename(source, target))) {
          final total = await source.length();
          var offset = await part.exists() ? await part.length() : 0;
          if (offset > total) offset = 0;
          var renewed = _clock();
          await _write(job.source, part.path, offset, (written) {
            _report(job, written, total);
            if (_clock().difference(renewed) > _renewEvery) {
              renewed = _clock();
              unawaited(_claim(job).catchError((_) => false));
            }
          });
          await part.rename(target.path);
          // временный файл приложения на другом диске: скопирован, оригинал больше не нужен
          if (ours) await source.delete().catchError((_) => source);
        }
      }
      await _finish(job, target);
      return _Outcome.kept;
    } on FileSystemException {
      // нет места или файл занят: попробовать в следующий проход
      final attempts = job.attempts + 1;
      if (attempts >= _maxAttempts) {
        await (_db.delete(_db.fileJobs)..where((t) => t.id.equals(job.id))).go();
        return _Outcome.lost;
      }
      await (_db.update(_db.fileJobs)..where((t) => t.id.equals(job.id))).write(FileJobsCompanion(attempts: Value(attempts), claimedUntil: const Value(null)));
      return _Outcome.later;
    }
  }

  bool _isMovable(String path) {
    final full = p.normalize(File(path).absolute.path);
    return _movable.any((folder) => p.isWithin(folder, full));
  }

  // переименование мгновенное, но только в пределах одного диска
  Future<bool> _rename(File source, File target) async {
    try {
      await source.rename(target.path);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  Future<void> _finish(FileJob job, File target) async {
    final size = job.mime.startsWith('image/') ? await imageSizeOfFile(target.path).catchError((_) => null) : null;
    final length = await target.length();
    final kept = await _db.transaction(() async {
      final removed = await (_db.delete(_db.fileJobs)..where((t) => t.id.equals(job.id))).go();
      if (removed == 0) return false;
      final item = await (_db.select(_db.items)..where((t) => t.id.equals(job.itemId))).getSingleOrNull();
      if (item == null) return false;
      await _db
          .into(_db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: const Uuid().v4(),
              itemId: job.itemId,
              path: job.target,
              mime: job.mime,
              size: length,
              position: Value(job.position),
              width: Value(size?.width),
              height: Value(size?.height),
            ),
          );
      return true;
    });
    // вещь стёрли, пока копировалось: файл никому не нужен
    if (!kept) await target.delete().catchError((_) => target);
    _report(job, length, length);
    // файл на месте: из него уже можно достать текст, дату съёмки, камеру
    if (kept) onKept?.call(job.itemId);
  }

  // ход по вещи: доля скопированного из всех её файлов в этом проходе
  void _report(FileJob job, int written, int total) {
    final shares = _shares.putIfAbsent(job.itemId, () => {});
    final before = _current[job.itemId];
    shares[job.id] = (written, total);
    final done = shares.values.fold(0, (sum, share) => sum + share.$1);
    final all = shares.values.fold(0, (sum, share) => sum + share.$2);
    final fraction = all == 0 ? 1.0 : (done / all).clamp(0.0, 1.0);
    final finished = fraction >= 1.0;
    // каждый процент, не каждый мегабайт: лента не перерисовывается зря
    if (!finished && before != null && (fraction - before) < 0.01) return;
    _current = {..._current, job.itemId: fraction};
    _progress.add(_current);
    if (finished) {
      _shares.remove(job.itemId);
      _current = {..._current}..remove(job.itemId);
    }
  }

  // ни файла, ни слов: пустая вещь в ленте только путала бы
  Future<bool> _dropIfEmpty(String itemId) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (item == null || item.body.trim().isNotEmpty) return false;
    final files = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(itemId))).get();
    final waiting = await (_db.select(_db.fileJobs)..where((t) => t.itemId.equals(itemId))).get();
    if (files.isNotEmpty || waiting.isNotEmpty) return false;
    await _db.transaction(() async {
      await (_db.delete(_db.aiJobs)..where((t) => t.itemId.equals(itemId))).go();
      await (_db.delete(_db.itemTags)..where((t) => t.itemId.equals(itemId))).go();
      await (_db.delete(_db.items)..where((t) => t.id.equals(itemId))).go();
    });
    return true;
  }
}

enum _Outcome { kept, later, lost }
