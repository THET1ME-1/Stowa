import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../data/db/database.dart';
import '../../domain/folder_tree.dart';
import '../../domain/models.dart';
import '../../domain/vault_note.dart';
import 'vault_layout.dart';
import 'vault_meta.dart';

/// Переносит правки из базы в файлы хранилища. Очередь `vault_queue` ставят
/// триггеры базы; писатель забирает задачу арендой, как хранитель файлов, поэтому
/// главное окно, «Поделиться» и фон не пишут один файл вдвоём.
class VaultWriter {
  VaultWriter(this._db, {required Directory? root, required DateTime Function() clock, Future<void> Function(File temp, File target)? commit})
    : _root = root, // ignore: prefer_initializing_formals
      _clock = clock, // ignore: prefer_initializing_formals
      _commit = commit ?? _rename;

  final AppDatabase _db;

  /// Корень хранилища; null — хранилище ещё не выбрано, очередь ждёт.
  final Directory? _root;
  final DateTime Function() _clock;

  /// Последний шаг записи: временный файл встаёт на место. В тестах — обрыв.
  final Future<void> Function(File temp, File target) _commit;

  static Future<void> _rename(File temp, File target) => temp.rename(target.path);

  static const _lease = Duration(seconds: 15);

  bool _running = false;
  bool _again = false;

  /// В последнем проходе нашёлся файл, который правили снаружи после нашей записи:
  /// писатель его не тронул, сперва нужна сверка читателем.
  bool sawExternalEdit = false;

  /// Разобрать очередь. Возвращает, сколько задач сделано.
  Future<int> drain() async {
    if (_root == null) return 0;
    if (_running) {
      _again = true;
      return 0;
    }
    _running = true;
    sawExternalEdit = false;
    var done = 0;
    try {
      do {
        _again = false;
        final now = _clock().millisecondsSinceEpoch;
        final tasks = await (_db.select(_db.vaultQueue)..where((t) => t.claimedUntil.isNull() | t.claimedUntil.isSmallerThanValue(now))).get();
        // сперва вещи, потом их факты, служебное последним
        tasks.sort((a, b) => _order(a.target).compareTo(_order(b.target)));
        for (final task in tasks) {
          if (!await _claim(task)) continue;
          try {
            await _run(task.target);
          } on _ExternalEdit {
            // правку снаружи не затираем: задача ждёт, пока читатель её заберёт
            sawExternalEdit = true;
            await (_db.update(_db.vaultQueue)..where((t) => t.target.equals(task.target) & t.version.equals(task.version))).write(const VaultQueueCompanion(claimedUntil: Value(null)));
            continue;
          } catch (_) {
            // диск не пишет: задача остаётся, остальное подождёт следующего прохода
            await (_db.update(_db.vaultQueue)..where((t) => t.target.equals(task.target) & t.version.equals(task.version))).write(const VaultQueueCompanion(claimedUntil: Value(null)));
            return done;
          }
          // за время записи пришла новая просьба — версия выросла, задача остаётся
          await (_db.delete(_db.vaultQueue)..where((t) => t.target.equals(task.target) & t.version.equals(task.version))).go();
          done++;
        }
      } while (_again);
    } finally {
      _running = false;
    }
    return done;
  }

  static int _order(String target) => target.startsWith('item:') ? 0 : (target.startsWith('facts:') ? 1 : 2);

  Future<bool> _claim(VaultQueueData task) async {
    final now = _clock().millisecondsSinceEpoch;
    final taken = await _db.customUpdate(
      'UPDATE vault_queue SET claimed_until = ? WHERE target = ? AND version = ? AND (claimed_until IS NULL OR claimed_until < ?)',
      variables: [Variable.withInt(now + _lease.inMilliseconds), Variable.withString(task.target), Variable.withInt(task.version), Variable.withInt(now)],
      updates: {_db.vaultQueue},
    );
    return taken == 1;
  }

  Future<void> _run(String target) async {
    final colon = target.indexOf(':');
    final kind = target.substring(0, colon);
    final name = target.substring(colon + 1);
    switch (kind) {
      case 'item':
        await _writeItem(name);
      case 'facts':
        final text = await factsJson(_db, name);
        text == null ? await _remove(factsFile(name)) : await _write(factsFile(name), text);
      case 'meta':
        if (vaultMetaTables.containsKey(name)) await _write(metaFile(name), await metaJson(_db, name));
    }
  }

  Future<void> _writeItem(String id) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
    final known = await (_db.select(_db.vaultFiles)..where((t) => t.itemId.equals(id))).getSingleOrNull();
    if (item == null) {
      // вещь стёрта насовсем: файл, вложения и добытое уходят следом
      if (known != null) {
        await _remove(known.path);
        final attachments = Directory(_absolute(attachmentsDir(known.path)));
        if (await attachments.exists()) await attachments.delete(recursive: true);
        await _prune(p.posix.dirname(known.path));
        await (_db.delete(_db.vaultFiles)..where((t) => t.itemId.equals(id))).go();
      }
      await _remove(factsFile(id));
      return;
    }
    if (known != null) {
      final current = File(_absolute(known.path));
      if (await current.exists()) {
        final stat = await current.stat();
        if (stat.modified.millisecondsSinceEpoch != known.modified || stat.size != known.size) throw const _ExternalEdit();
      }
    }

    var wanted = notePath(folders: await _folderPath(item.folderId), fileName: '${vaultFileName(item.title)}.md');
    if (item.deletedAt != null) wanted = trashPath(wanted);
    // «Купить молоко 2.md» остаётся «2», пока заголовок тот же: файл не прыгает между именами
    final path = known != null && _sameName(known.path, wanted) ? known.path : (known == null ? await _ownFile(wanted, id) : null) ?? await _free(wanted, id);

    if (known != null && known.path != path) await _move(id, known.path, path);
    await _gather(id, attachmentsDir(path));

    final tags = await _db
        .customSelect(
          'SELECT tags.name AS name FROM item_tags JOIN tags ON tags.id = item_tags.tag_id WHERE item_tags.item_id = ? ORDER BY tags.name',
          variables: [Variable.withString(id)],
        )
        .get();
    final attachments = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(id))..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    final highlights = await (_db.select(_db.highlights)
          ..where((t) => t.itemId.equals(id))
          ..orderBy([(t) => OrderingTerm.asc(t.position), (t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    final note = VaultNote(
      id: item.id,
      kind: item.kind,
      title: item.title,
      body: item.body,
      created: item.createdAt,
      updated: item.updatedAt,
      tags: [for (final row in tags) row.read<String>('name')],
      url: item.url,
      previewSite: item.previewSite,
      previewAuthor: item.previewAuthor,
      previewText: item.previewText,
      cover: item.coverPath,
      durationSeconds: item.durationSeconds,
      reminder: item.reminderAt,
      latitude: item.latitude,
      longitude: item.longitude,
      placeName: item.placeName,
      remindPlace: item.remindPlace == null
          ? null
          : PlaceReminder(item.remindPlace!, latitude: item.remindLatitude, longitude: item.remindLongitude, name: item.remindPlaceName),
      sortedBy: item.sortedBy,
      attachments: [for (final attachment in attachments) attachment.path],
      highlights: [for (final one in highlights) VaultHighlight(quote: one.quote, note: one.note, at: one.createdAt, position: one.position)],
    );
    final file = await _write(path, writeVaultNote(note, fileName: p.posix.basename(path)));
    final stat = await file.stat();
    await _db.into(_db.vaultFiles).insertOnConflictUpdate(VaultFilesCompanion.insert(itemId: id, path: path, modified: stat.modified.millisecondsSinceEpoch, size: stat.size));
  }

  /// Имена папок от верхней до папки вещи. Удалённая папка — как будто её нет.
  Future<List<String>> _folderPath(String? folderId) async {
    if (folderId == null) return const [];
    final rows = await (_db.select(_db.folders)..where((t) => t.deletedAt.isNull())).get();
    return FolderTree([for (final row in rows) FolderNode(id: row.id, name: row.name, parentId: row.parentId)]).path(folderId);
  }

  bool _sameName(String current, String wanted) {
    if (p.posix.dirname(current).toLowerCase() != p.posix.dirname(wanted).toLowerCase()) return false;
    final stem = attachmentsDir(p.posix.basename(current)).toLowerCase();
    final want = attachmentsDir(p.posix.basename(wanted)).toLowerCase();
    return stem == want || RegExp('^${RegExp.escape(want)} \\d+\$').hasMatch(stem);
  }

  /// Карты файлов нет (восстановили копию, открыли готовое хранилище), а заметка уже лежит
  /// на диске: свой файл узнаётся по id среди «Карбонара.md», «Карбонара 2.md»… Иначе
  /// писатель счёл бы своё имя занятым и записал копию рядом.
  Future<String?> _ownFile(String wanted, String id) async {
    final folder = p.posix.dirname(wanted);
    final dir = Directory(_absolute(folder));
    if (!await dir.exists()) return null;
    final stem = attachmentsDir(p.posix.basename(wanted)).toLowerCase();
    final numbered = RegExp('^${RegExp.escape(stem)} \\d+\$');
    await for (final entity in dir.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (entity is! File || !name.endsWith('.md')) continue;
      final base = attachmentsDir(name).toLowerCase();
      if (base != stem && !numbered.hasMatch(base)) continue;
      if (await _idOf(entity) == id) return folder == '.' ? name : '$folder/$name';
    }
    return null;
  }

  // id из свойств: только начало файла, тексту заметки разбор не нужен
  static Future<String?> _idOf(File file) async {
    final head = await file.openRead(0, 1024).fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
    final text = utf8.decode(head, allowMalformed: true);
    if (!text.startsWith('---')) return null;
    return RegExp(r'^id:\s*"?([^"\n]+)"?\s*$', multiLine: true).firstMatch(text)?.group(1)?.trim();
  }

  // имя занято файлом на диске (может, заметкой Obsidian, ещё не прочитанной) или другой вещью
  Future<String> _free(String wanted, String id) async {
    final others = {
      for (final row in await (_db.select(_db.vaultFiles)..where((t) => t.itemId.equals(id).not())).get()) row.path.toLowerCase(),
    };
    return uniqueNotePath(wanted, (candidate) => others.contains(candidate.toLowerCase()) || File(_absolute(candidate)).existsSync());
  }

  /// Файл и папка вложений переезжают переименованием, пути вложений в базе — следом.
  Future<void> _move(String id, String from, String to) async {
    final oldFile = File(_absolute(from));
    if (await oldFile.exists()) {
      await Directory(p.dirname(_absolute(to))).create(recursive: true);
      await oldFile.rename(_absolute(to));
    }
    final oldDir = attachmentsDir(from);
    final newDir = attachmentsDir(to);
    final folder = Directory(_absolute(oldDir));
    if (await folder.exists()) {
      await Directory(p.dirname(_absolute(newDir))).create(recursive: true);
      await folder.rename(_absolute(newDir));
      final moved = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(id))).get();
      await _quietly(() async {
        for (final attachment in moved) {
          if (!attachment.path.startsWith('$oldDir/')) continue;
          await (_db.update(_db.attachments)..where((t) => t.id.equals(attachment.id))).write(AttachmentsCompanion(path: Value('$newDir${attachment.path.substring(oldDir.length)}')));
        }
      });
    }
    await _prune(p.posix.dirname(from));
  }

  /// Вложения, которые лежат не у заметки (входящие, старое место `attachments/`), переезжают
  /// в её папку под своим именем без номера порядка; одинаковые имена — «фото 2.jpg».
  Future<void> _gather(String id, String dir) async {
    final attachments = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(id))..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    final used = {for (final attachment in attachments) if (attachment.path.startsWith('$dir/')) p.posix.basename(attachment.path).toLowerCase()};
    final moved = <String, String>{};
    for (final attachment in attachments) {
      if (attachment.path.startsWith('$dir/')) continue;
      final source = File(_absolute(attachment.path));
      if (!await source.exists()) continue;
      final name = p.posix.basename(attachment.path).replaceFirst(RegExp(r'^\d+_'), '');
      var target = '$dir/$name';
      for (var number = 2; used.contains(p.posix.basename(target).toLowerCase()) || File(_absolute(target)).existsSync(); number++) {
        target = '$dir/${p.posix.basenameWithoutExtension(name)} $number${p.posix.extension(name)}';
      }
      used.add(p.posix.basename(target).toLowerCase());
      await Directory(p.dirname(_absolute(target))).create(recursive: true);
      await source.rename(_absolute(target));
      moved[attachment.id] = target;
      await _prune(p.posix.dirname(attachment.path));
    }
    if (moved.isEmpty) return;
    await _quietly(() async {
      for (final MapEntry(key: attachmentId, value: path) in moved.entries) {
        await (_db.update(_db.attachments)..where((t) => t.id.equals(attachmentId))).write(AttachmentsCompanion(path: Value(path)));
      }
    });
  }

  /// Своя правка базы, которую не надо писать обратно в файлы: флаг глушит триггеры.
  /// В транзакции: другие окна в эту долю секунды пишут после неё, а не мимо очереди.
  Future<void> _quietly(Future<void> Function() change) => _db.transaction(() async {
    await _db.into(_db.vaultFlags).insertOnConflictUpdate(VaultFlagsCompanion.insert(name: 'importing'));
    try {
      await change();
    } finally {
      await (_db.delete(_db.vaultFlags)..where((t) => t.name.equals('importing'))).go();
    }
  });

  /// Запись целиком или никак: временный файл рядом, потом на место.
  Future<File> _write(String relative, String text) async {
    final target = File(_absolute(relative));
    await target.parent.create(recursive: true);
    final temp = File(p.join(target.parent.path, '.${p.basename(target.path)}.tmp'));
    await temp.writeAsString(text, flush: true);
    await _commit(temp, target);
    return target;
  }

  Future<void> _remove(String relative) async {
    final file = File(_absolute(relative));
    if (await file.exists()) await file.delete();
  }

  // пустые папки, оставшиеся после переезда, убираются до корня
  Future<void> _prune(String relativeDir) async {
    var dir = relativeDir;
    while (dir != '.' && dir.isNotEmpty) {
      final folder = Directory(_absolute(dir));
      if (!await folder.exists() || !await folder.list().isEmpty) return;
      await folder.delete();
      dir = p.posix.dirname(dir);
    }
  }

  String _absolute(String relative) => p.joinAll([_root!.path, ...relative.split('/')]);
}

class _ExternalEdit implements Exception {
  const _ExternalEdit();
}
