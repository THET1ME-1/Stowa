import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../core/user_first.dart';
import '../../data/db/database.dart';
import '../../data/repositories/items_repository.dart' show placeReminderOf;
import '../../domain/folder_tree.dart';
import '../../domain/note_blocks.dart' show embedLine, embedNames, embedPath;
import '../../domain/note_links.dart' show renameCanvasFile, renameLinks;
import '../../domain/vault_note.dart';
import '../privacy/sealed_space.dart';
import '../../domain/models.dart' show ItemKind, documentExtension, isDocumentKind;
import 'vault_layout.dart';
import 'vault_meta.dart';

/// Переносит правки из базы в файлы хранилища. Очередь `vault_queue` ставят
/// триггеры базы; писатель забирает задачу арендой, как хранитель файлов, поэтому
/// главное окно, «Поделиться» и фон не пишут один файл вдвоём.
class VaultWriter {
  VaultWriter(
    this._db, {
    required Directory? root,
    required DateTime Function() clock,
    Future<void> Function(File temp, File target)? commit,
    this.attachmentsDefault,
    UserFirst? gate,
  }) : _root = root, // ignore: prefer_initializing_formals
       _clock = clock, // ignore: prefer_initializing_formals
       _commit = commit ?? _rename,
       _gate = gate ?? userFirst;

  /// Занят ли человек: в браузере факты и история ждут, пока он не освободится.
  final UserFirst _gate;

  /// Имя общей папки вложений, если в хранилище нет ни Obsidian, ни выбора: «Вложения» на
  /// языке приложения. Записывается при первом проходе — хранилище, созданное только что,
  /// сразу кладёт фото туда, а не россыпью рядом с заметками. null — не ставить (тесты).
  final String Function()? attachmentsDefault;
  bool _choiceChecked = false;

  void _ensureAttachmentChoice() {
    final make = attachmentsDefault;
    if (_choiceChecked || make == null) return;
    _choiceChecked = true;
    try {
      final setting = readAttachmentSetting(_root!);
      if (!setting.obsidian && setting.setting == null) writeAttachmentSetting(_root, make());
    } on Object {
      // не записалось — вложения лягут рядом с заметкой, выбрать можно в настройках
    }
  }

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

  // задача занята другим писателем или прошлым запуском: повторить, когда аренда истечёт
  Timer? _retry;

  void dispose() => _retry?.cancel();

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
    _ensureAttachmentChoice();
    sawExternalEdit = false;
    var done = 0;
    var postponed = false;
    try {
      do {
        _again = false;
        final now = _clock().millisecondsSinceEpoch;
        final tasks = await (_db.select(_db.vaultQueue)..where((t) => t.claimedUntil.isNull() | t.claimedUntil.isSmallerThanValue(now))).get();
        // сперва вещи, потом их факты, служебное последним
        tasks.sort((a, b) => _order(a.target).compareTo(_order(b.target)));
        for (final task in tasks) {
          // в браузере база одна на всё: заметки и служебное (имена и порядок папок) пишутся
          // в файлы сразу, а факты и история ждут, пока человек набирает или листает.
          // Отложенное остаётся в очереди
          if (_gate.busy && _order(task.target) == 1) {
            postponed = true;
            continue;
          }
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
      if (postponed) {
        // человек занят: вернёмся к отложенному, когда он отпустит клавиши
        _retry?.cancel();
        _retry = Timer(_gate.hold, () => drain().ignore());
      } else {
        await _retryClaimed();
      }
    } finally {
      _running = false;
    }
    return done;
  }

  /// Остались задачи под чужой арендой. Аренда прошлого запуска (вкладку перезагрузили,
  /// приложение убили посреди записи) никем не снимется, а новой правки может не быть:
  /// писатель сам возвращается к ним, когда аренда истечёт.
  Future<void> _retryClaimed() async {
    final now = _clock().millisecondsSinceEpoch;
    final soonest = await (_db.selectOnly(_db.vaultQueue)
          ..addColumns([_db.vaultQueue.claimedUntil.min()])
          ..where(_db.vaultQueue.claimedUntil.isBiggerOrEqualValue(now)))
        .map((row) => row.read(_db.vaultQueue.claimedUntil.min()))
        .getSingleOrNull();
    if (soonest == null) return;
    _retry?.cancel();
    _retry = Timer(Duration(milliseconds: soonest - now + 50), () => drain().ignore());
  }

  static int _order(String target) => target.startsWith('item:') ? 0 : (target.startsWith('facts:') || target.startsWith('history:') ? 1 : 2);

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
      // добытое и история скрытой заметки уходят в запечатанную копию вместе со строками базы
      case 'facts':
        final text = await _hiddenItem(name) ? null : await factsJson(_db, name);
        text == null ? await _remove(factsFile(name)) : await _write(factsFile(name), text);
      case 'history':
        final text = await _hiddenItem(name) ? null : await historyJson(_db, name);
        text == null ? await _remove(historyFile(name)) : await _write(historyFile(name), text);
      case 'meta':
        if (vaultMetaTables.containsKey(name)) await _write(metaFile(name), await metaJson(_db, name));
    }
  }

  Future<void> _writeItem(String id) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
    var known = await (_db.select(_db.vaultFiles)..where((t) => t.itemId.equals(id))).getSingleOrNull();
    if (item != null && known != null && isLoosePath(known.path)) {
      // заметка-файл без своего — сам файл: переименовать и переложить, ничего не дописывая
      if (await _bare(item) && !(SealedSpace.root != null && await _hiddenFolder(item.folderId))) {
        await _writeLoose(item, known);
        return;
      }
      // у файла появилось своё (текст, метка, напоминание…) или его убрали в скрытое: рядом
      // пишется заметка со вставкой, а сам файл остаётся на месте
      await (_db.delete(_db.vaultFiles)..where((t) => t.itemId.equals(id))).go();
      known = null;
    }
    // заметка без текста, чей файл ещё копируется: пишется вместе с файлом, иначе на миг
    // появилась бы пустая «Фото от ….md» рядом с будущим голым файлом
    if (item != null && known == null && _textOf(item.body).isEmpty && await _copying(id)) return;
    if (item == null) {
      // вещь стёрта насовсем: файл, вложения и добытое уходят следом
      if (known != null) {
        await _remove(known.path);
        await _dropAttachments(attachmentsDir(known.path));
        await _prune(p.posix.dirname(known.path));
        await (_db.delete(_db.vaultFiles)..where((t) => t.itemId.equals(id))).go();
      }
      await _remove(factsFile(id));
      await _remove(historyFile(id));
      // у скрытой — её файлы в открытой папке
      final open = SealedSpace.root;
      if (open != null) {
        for (final relative in ['files/$id', ...derivedPaths(id)]) {
          await _drop('${open.path}/$relative');
        }
        await _dropCovers(open.path, id);
      }
      SealedSpace.release(id);
      return;
    }
    if (SealedSpace.root != null && await _hiddenFolder(item.folderId)) {
      await _seal(item, known);
      return;
    }
    await _unseal(item);
    if (known != null) {
      final current = File(_absolute(known.path));
      if (await current.exists()) {
        final stat = await current.stat();
        if (stat.modified.millisecondsSinceEpoch != known.modified || stat.size != known.size) throw const _ExternalEdit();
      }
    }

    // холст и база — свой файл .canvas/.base: исходный текст как есть, без шапки и вложений
    final document = isDocumentKind(item.kind);
    // рисунок, названный просто «Схема.md», так и остаётся «.md»: имя файла выбирал человек
    final plainDrawing = item.kind == ItemKind.drawing && known != null && !known.path.toLowerCase().endsWith('.excalidraw.md');
    final extension = !document || plainDrawing ? 'md' : documentExtension(item.kind);
    final folders = await _folderPath(item.folderId);
    // одно фото или файл без своего в настоящей папке — сам файл, без заметки рядом. Только
    // с подписью от приложения («Фото от …»): название, данное человеком, или старая заметка
    // до 16.11 голым файлом не становятся — их имя и вид остаются, как были
    if (known == null && !document && item.titleAuto && item.deletedAt == null && folders.isNotEmpty && await _bare(item)) {
      final files = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(id))).get();
      if (files.length == 1 && _outside(files.single.path)) {
        await _placeLoose(item, files.single, folders);
        return;
      }
    }
    final live = notePath(folders: folders, fileName: '${vaultFileName(item.title)}.$extension');
    var wanted = live;
    if (item.deletedAt != null) wanted = trashPath(wanted);
    // название не меняли в Stowa — файл не переименовывается, даже если имя из названия вышло
    // бы другим: длинное имя обрезается до 200 байт, а свойство `title:` из Obsidian расходится
    // с именем файла. Переименование ломало бы ссылки [[…]] на эту заметку в Obsidian
    if (known != null && !_sameName(known.path, wanted) && await _titleOnDisk(known.path, document: document) == item.title) {
      final dir = p.posix.dirname(wanted);
      wanted = dir == '.' ? p.posix.basename(known.path) : '$dir/${p.posix.basename(known.path)}';
    }
    // «Купить молоко 2.md» остаётся «2», пока заголовок тот же: файл не прыгает между именами.
    // Свой холст по id не узнать: id в JSON не пишется, его файл знает только карта файлов
    final path = known != null && _sameName(known.path, wanted)
        ? known.path
        : (known == null && !document ? await _ownFile(wanted, id) : null) ?? await _free(wanted, id);

    if (known != null && known.path != path) {
      await _move(id, known.path, path);
      await _followLinks(id, known.path, path);
    }
    if (document) {
      final file = await _write(path, item.document ?? '');
      final stat = await file.stat();
      await _db.into(_db.vaultFiles).insertOnConflictUpdate(VaultFilesCompanion.insert(itemId: id, path: path, modified: stat.modified.millisecondsSinceEpoch, size: stat.size));
      return;
    }
    // новые файлы — из входящих в папку вложений по настройке (как в Obsidian); то, что уже
    // лежит в хранилище, не двигается: картинки Obsidian из «Изображений» и старые «Заметка/»
    final setting = readAttachmentSetting(_root!);
    final renamed = await _gather(id, attachmentFolderFor(live, obsidian: setting.obsidian, setting: setting.setting));
    final legacy = attachmentsDir(path);
    await _trashAttachments(item, legacy: legacy);
    // картинка в тексте ссылается на имя файла: занятое имя получило номер — текст следом
    var body = item.body;
    for (final MapEntry(key: before, value: after) in renamed.entries) {
      body = body.replaceAll('![[$before]]', '![[$after]]');
    }
    final attachments = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(id))..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    // вложение без вставки в тексте (кроме старого хвоста в «Заметка/») встаёт вставкой в конец
    // текста: место картинки задаёт текст, а не галерея сверху
    final paths = [for (final attachment in attachments) attachment.path];
    final inline = {for (final name in embedNames(body)) ?embedPath(name, paths)};
    final missing = [
      for (final path in paths)
        if (!inline.contains(path) && !path.startsWith('$legacy/') && !p.isAbsolute(path)) '![[${await _embedName(path)}]]',
    ];
    if (missing.isNotEmpty) body = [if (body.trim().isNotEmpty) body.trimRight(), missing.join('\n')].join('\n\n');
    if (body != item.body) {
      final fixed = body;
      await _quietly(() => (_db.update(_db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(body: Value(fixed))));
    }

    final note = await vaultNoteOf(_db, item.copyWith(body: body), attachments: [for (final attachment in attachments) attachment.path]);
    // нынешний файл: его шапка правится на месте, а не пишется заново
    final current = File(_absolute(path));
    final previous = await current.exists() ? utf8.decode(await current.readAsBytes(), allowMalformed: true) : null;
    final file = await _write(path, writeVaultNote(note, fileName: p.posix.basename(path), previous: previous));
    final stat = await file.stat();
    await _db.into(_db.vaultFiles).insertOnConflictUpdate(VaultFilesCompanion.insert(itemId: id, path: path, modified: stat.modified.millisecondsSinceEpoch, size: stat.size));
    if (SealedSpace.root case final open?) await _dropIfEmpty('${open.path}/files/$id');
  }

  /// Заметка-файл: имя файла — заголовок с прежним расширением, каталог — папка заметки,
  /// удалённая — в корзину. Путь вложения и карта файлов идут следом.
  Future<void> _writeLoose(Item item, VaultFile known) async {
    final id = item.id;
    final current = File(_absolute(known.path));
    if (!await current.exists()) return;
    // тот же файл — вложение живой заметки (дубль от прежней гонки сверки): заметка-файл уходит,
    // а файл остаётся у хозяина; иначе её корзина уносила чужую картинку и плитка серела
    final shared = await (_db.select(_db.attachments).join([innerJoin(_db.items, _db.items.id.equalsExp(_db.attachments.itemId))])
          ..where(_db.attachments.path.equals(known.path) & _db.attachments.itemId.equals(id).not() & _db.items.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    if (shared != null) {
      if (item.deletedAt != null) await _quietly(() => (_db.delete(_db.vaultFiles)..where((t) => t.itemId.equals(id))).go());
      return;
    }
    final stat = await current.stat();
    if (stat.modified.millisecondsSinceEpoch != known.modified || stat.size != known.size) throw const _ExternalEdit();
    // имя на диске меняет только своё название человека; подпись от приложения — нет
    final title = item.title.trim().isEmpty || item.titleAuto ? p.posix.basenameWithoutExtension(known.path) : item.title;
    var wanted = notePath(folders: await _folderPath(item.folderId), fileName: '${vaultFileName(title)}${p.posix.extension(known.path)}');
    if (item.deletedAt != null) wanted = trashPath(wanted);
    if (_sameName(known.path, wanted)) return;
    final path = await _free(wanted, id);
    await Directory(p.dirname(_absolute(path))).create(recursive: true);
    await current.rename(_absolute(path));
    await _prune(p.posix.dirname(known.path));
    final after = await File(_absolute(path)).stat();
    await _quietly(() async {
      await (_db.update(_db.attachments)..where((t) => t.itemId.equals(id) & t.path.equals(known.path))).write(AttachmentsCompanion(path: Value(path)));
      await _db.into(_db.vaultFiles).insertOnConflictUpdate(VaultFilesCompanion.insert(itemId: id, path: path, modified: after.modified.millisecondsSinceEpoch, size: after.size));
    });
  }

  Future<bool> _hiddenFolder(String? folderId) async {
    if (folderId == null) return false;
    final row = await _db.customSelect('SELECT 1 FROM folders WHERE id = ? AND hidden = 1', variables: [Variable.withString(folderId)]).getSingleOrNull();
    return row != null;
  }

  Future<bool> _hiddenItem(String id) async {
    final row = await _db
        .customSelect('SELECT 1 FROM items JOIN folders ON folders.id = items.folder_id WHERE items.id = ? AND folders.hidden = 1', variables: [Variable.withString(id)])
        .getSingleOrNull();
    return row != null;
  }

  /// Заметка скрытой папки: файла в хранилище у неё нет (текст в базе до закрытия, потом
  /// в запечатанной копии), вложения и производное — в открытой папке скрытого.
  Future<void> _seal(Item item, VaultFile? known) async {
    final open = SealedSpace.root!.path;
    final id = item.id;
    SealedSpace.take(id);
    if (known != null) {
      await _remove(known.path);
      await (_db.delete(_db.vaultFiles)..where((t) => t.itemId.equals(id))).go();
    }
    // в скрытое уходит всё: и лежавшее в хранилище, текст скрытого не должен оставаться открытым
    final renamed = await _gather(id, '$open/files/$id', all: true);
    var body = item.body;
    for (final MapEntry(key: before, value: after) in renamed.entries) {
      body = body.replaceAll('![[$before]]', '![[$after]]');
    }
    if (known != null) {
      await _prune(attachmentsDir(known.path));
      await _prune(p.posix.dirname(known.path));
    }
    final cover = item.coverPath;
    final newCover = cover != null && !p.isAbsolute(cover) ? '$open/$cover' : cover;
    if (cover != newCover) await _relocate(_absolute(cover!), newCover!);
    for (final relative in derivedPaths(id)) {
      await _relocate(_absolute(relative), '$open/$relative');
    }
    await _remove(factsFile(id));
    await _remove(historyFile(id));
    await _quietly(() async {
      if (body != item.body || cover != newCover) {
        await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(body: Value(body), coverPath: Value(newCover)));
      }
      // кадры ролика записаны в фактах путём
      await _db.customStatement("UPDATE facts SET value = ? || '/' || value WHERE item_id = ? AND kind = 'frame' AND value NOT LIKE '/%'", [open, id]);
    });
  }

  /// Заметку вынули из скрытой папки: её файлы из открытой папки возвращаются в хранилище.
  /// Вложения переносит `_gather` следом, добытое и история пишутся заново.
  Future<void> _unseal(Item item) async {
    final id = item.id;
    SealedSpace.release(id);
    final open = SealedSpace.root;
    if (open == null) return;
    final prefix = '${open.path}/';
    var back = (await (_db.select(_db.attachments)..where((t) => t.itemId.equals(id))).get()).any((attachment) => attachment.path.startsWith(prefix));
    final cover = item.coverPath;
    final newCover = cover != null && cover.startsWith(prefix) ? cover.substring(prefix.length) : cover;
    if (cover != newCover) {
      await _relocate(cover!, _absolute(newCover!));
      back = true;
    }
    for (final relative in derivedPaths(id)) {
      if (await _relocate('$prefix$relative', _absolute(relative))) back = true;
    }
    if (!back) return;
    await _quietly(() async {
      if (cover != newCover) await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(coverPath: Value(newCover)));
      await _db.customStatement('UPDATE facts SET value = substr(value, ?) WHERE item_id = ? AND substr(value, 1, ?) = ?', [prefix.length + 1, id, prefix.length, prefix]);
    });
    for (final target in ['facts:$id', 'history:$id']) {
      await _db.customStatement('INSERT INTO vault_queue (target) VALUES (?) ON CONFLICT(target) DO UPDATE SET version = version + 1, claimed_until = NULL', [target]);
    }
    _again = true;
  }

  /// Перенос файла или папки; между памятью приложения и общей памятью переименование
  /// не работает — тогда копия и стирание. Источника нет — false.
  Future<bool> _relocate(String from, String to) async {
    final type = await FileSystemEntity.type(from, followLinks: false);
    if (type == FileSystemEntityType.notFound) return false;
    await Directory(p.dirname(to)).create(recursive: true);
    await _drop(to);
    try {
      type == FileSystemEntityType.directory ? await Directory(from).rename(to) : await File(from).rename(to);
    } on FileSystemException {
      await _copy(from, to, type);
      await _drop(from);
    }
    return true;
  }

  Future<void> _copy(String from, String to, FileSystemEntityType type) async {
    if (type != FileSystemEntityType.directory) {
      await File(from).copy(to);
      return;
    }
    await Directory(to).create(recursive: true);
    await for (final entity in Directory(from).list(followLinks: false)) {
      await _copy(entity.path, p.join(to, p.basename(entity.path)), entity is Directory ? FileSystemEntityType.directory : FileSystemEntityType.file);
    }
  }

  Future<void> _drop(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.directory) await Directory(path).delete(recursive: true);
    if (type == FileSystemEntityType.file) await File(path).delete();
  }

  Future<void> _dropIfEmpty(String path) async {
    final dir = Directory(path);
    if (await dir.exists() && await dir.list().isEmpty) await dir.delete();
  }

  Future<void> _dropCovers(String open, String id) async {
    final dir = Directory('$open/$serviceFolder/covers');
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (p.basenameWithoutExtension(entity.path) == id) await entity.delete();
    }
  }

  /// Имена папок от верхней до папки вещи. Удалённая папка — как будто её нет.
  Future<List<String>> _folderPath(String? folderId) async {
    if (folderId == null) return const [];
    final rows = await (_db.select(_db.folders)..where((t) => t.deletedAt.isNull())).get();
    return FolderTree([for (final row in rows) FolderNode(id: row.id, name: row.name, parentId: row.parentId)]).path(folderId);
  }

  /// Файл заметки переименовали или переложили — ссылки на него во всех остальных заметках и
  /// холстах следуют за ним, как в Obsidian с «Всегда обновлять ссылки». Корзина ссылок не
  /// трогает: удалённая заметка вернётся под тем же именем. Правка идёт обычной очередью, файлы
  /// этих заметок перепишутся следом; время правки не двигается — человек их не правил.
  Future<void> _followLinks(String id, String from, String to) async {
    if (from.startsWith('$trashFolder/') || to.startsWith('$trashFolder/')) return;
    final name = p.posix.basenameWithoutExtension(from);
    final rows = await (_db.select(_db.items)
          ..where((t) => t.id.equals(id).not() & t.deletedAt.isNull() & (t.body.like('%$name%') | t.document.like('%$name%') | t.properties.like('%$name%'))))
        .get();
    // ссылки стоят и в свойствах шапки («Предмет: "[[Курсы/Военка|Военка]]"»): строки внутри
    // списков и словарей тоже
    Object? follow(Object? value) => switch (value) {
      final String text => renameLinks(text, from: from, to: to),
      final List<Object?> list => [for (final one in list) follow(one)],
      final Map<String, Object?> map => {for (final MapEntry(:key, :value) in map.entries) key: follow(value)},
      _ => value,
    };
    for (final row in rows) {
      final body = renameLinks(row.body, from: from, to: to);
      final document = switch ((row.kind, row.document)) {
        (ItemKind.canvas, final String text) => renameCanvasFile(text, from: from, to: to),
        _ => row.document,
      };
      final extra = unpackVaultProperties(row.properties);
      final followed = follow(extra) as Map<String, Object?>;
      final properties = jsonEncode(followed) == jsonEncode(extra) ? row.properties : packVaultProperties(followed);
      if (body == row.body && document == row.document && properties == row.properties) continue;
      await (_db.update(_db.items)..where((t) => t.id.equals(row.id))).write(ItemsCompanion(body: Value(body), document: Value(document), properties: Value(properties)));
      // их задачи встали в очередь после снимка этого прохода — пройти ещё раз
      _again = true;
    }
  }

  /// Название заметки так, как его прочтёт сверка из файла сейчас; файла нет — null.
  Future<String?> _titleOnDisk(String relative, {required bool document}) async {
    final file = File(_absolute(relative));
    if (!await file.exists()) return null;
    try {
      final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      final name = p.posix.basename(relative);
      final modified = await file.lastModified();
      return (document ? readVaultDocument(text, fileName: name, fileModified: modified) : readVaultNote(text, fileName: name, fileModified: modified)).title;
    } on Object {
      return null;
    }
  }

  bool _sameName(String current, String wanted) {
    if (p.posix.dirname(current).toLowerCase() != p.posix.dirname(wanted).toLowerCase()) return false;
    if (p.posix.extension(current).toLowerCase() != p.posix.extension(wanted).toLowerCase()) return false;
    final stem = p.posix.basenameWithoutExtension(current).toLowerCase();
    final want = p.posix.basenameWithoutExtension(wanted).toLowerCase();
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
      // переезжают только свои вложения: папка рядом с заметкой бывает обычной папкой
      // Obsidian («Рецепты.md» и «Рецепты/» с другими заметками), её содержимое не наше
      final moved = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(id))).get();
      for (final attachment in moved) {
        if (!attachment.path.startsWith('$oldDir/')) continue;
        final source = File(_absolute(attachment.path));
        if (!await source.exists()) continue;
        final target = File(_absolute('$newDir${attachment.path.substring(oldDir.length)}'));
        await target.parent.create(recursive: true);
        await source.rename(target.path);
      }
      await _pruneTree(oldDir);
      await _quietly(() async {
        for (final attachment in moved) {
          if (!attachment.path.startsWith('$oldDir/')) continue;
          await (_db.update(_db.attachments)..where((t) => t.id.equals(attachment.id))).write(AttachmentsCompanion(path: Value('$newDir${attachment.path.substring(oldDir.length)}')));
        }
      });
    }
    await _prune(p.posix.dirname(from));
  }

  /// Вложения, которые лежат вне хранилища (входящие, старое место `attachments/`, открытая папка
  /// скрытого), переезжают в [dir] ('' — корень) под своим именем без номера порядка. Имя свободно
  /// по всему хранилищу: короткая вставка `![[фото.jpg]]` должна вести ровно к одному файлу —
  /// занятое получает «фото 2.jpg». Лежащее в хранилище не двигается; [all] — двигается и оно
  /// (уход в скрытое). Отдаёт имена, которые пришлось сменить: старое → новое.
  Future<Map<String, String>> _gather(String id, String dir, {bool all = false}) async {
    final attachments = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(id))..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    String inDir(String name) => dir.isEmpty ? name : '$dir/$name';
    final used = {
      for (final row in await (_db.select(_db.attachments)..where((t) => t.itemId.equals(id).not())).get()) p.posix.basename(row.path).toLowerCase(),
      for (final row in await (_db.select(_db.vaultFiles)..where((t) => t.itemId.equals(id).not())).get()) p.posix.basename(row.path).toLowerCase(),
      for (final attachment in attachments) if (!all && !_outside(attachment.path)) p.posix.basename(attachment.path).toLowerCase(),
    };
    // файл, который числится и за другой живой заметкой (дубль от прежней гонки сверки), — её:
    // забрать его к себе значило бы оставить ей серую плитку
    final shared = {
      for (final row in await (_db.select(_db.attachments).join([innerJoin(_db.items, _db.items.id.equalsExp(_db.attachments.itemId))])
            ..where(_db.attachments.path.isIn([for (final attachment in attachments) attachment.path]) & _db.attachments.itemId.equals(id).not() & _db.items.deletedAt.isNull()))
          .get())
        row.readTable(_db.attachments).path,
    };
    final moved = <String, String>{};
    final renamed = <String, String>{};
    for (final attachment in attachments) {
      if (attachment.path.startsWith('$dir/') || shared.contains(attachment.path)) continue;
      if (!all && !_outside(attachment.path)) continue;
      final source = File(_absolute(attachment.path));
      if (!await source.exists()) continue;
      final name = p.posix.basename(attachment.path).replaceFirst(RegExp(r'^\d+_'), '');
      var target = inDir(name);
      for (var number = 2; used.contains(p.posix.basename(target).toLowerCase()) || File(_absolute(target)).existsSync(); number++) {
        target = inDir('${p.posix.basenameWithoutExtension(name)} $number${p.posix.extension(name)}');
      }
      used.add(p.posix.basename(target).toLowerCase());
      await _relocate(source.path, _absolute(target));
      moved[attachment.id] = target;
      if (p.posix.basename(target) != name) renamed[name] = p.posix.basename(target);
      await _prune(p.posix.dirname(attachment.path));
    }
    if (moved.isEmpty) return renamed;
    await _quietly(() async {
      for (final MapEntry(key: attachmentId, value: path) in moved.entries) {
        await (_db.update(_db.attachments)..where((t) => t.id.equals(attachmentId))).write(AttachmentsCompanion(path: Value(path)));
      }
    });
    return renamed;
  }

  /// Файл ещё вне хранилища: входящие, старое место `attachments/`, открытая папка скрытого.
  static bool _outside(String path) => p.isAbsolute(path) || path.startsWith('$serviceFolder/incoming/') || path.startsWith('attachments/');

  /// Текст без строк-вставок `![[…]]`: то, что написал человек.
  static String _textOf(String body) => body.split('\n').where((line) => !embedLine.hasMatch(line)).join('\n').trim();

  Future<bool> _copying(String id) async => (await (_db.select(_db.fileJobs)..where((t) => t.itemId.equals(id))..limit(1)).get()).isNotEmpty;

  /// У вещи нет ничего, кроме файла: ни текста, ни меток, ни напоминаний, ни закрепления, ни
  /// своих свойств, ни ссылки, ни ручных связей, ни цитат. Такую вещь хранит сам файл; как
  /// только что-то появится — рядом пишется заметка (в jpg свойств не запишешь, а тайник в
  /// `.stowa` осиротел бы при первом переименовании снаружи).
  Future<bool> _bare(Item item) async {
    if (_textOf(item.body).isNotEmpty || item.url != null || isDocumentKind(item.kind)) return false;
    if (item.reminderAt != null || item.remindPlace != null || item.pinnedAt != null) return false;
    if (unpackVaultProperties(item.properties).isNotEmpty) return false;
    final id = Variable.withString(item.id);
    final own = await _db
        .customSelect(
          'SELECT 1 FROM item_tags WHERE item_id = ?1 '
          "UNION ALL SELECT 1 FROM links WHERE (from_id = ?1 OR to_id = ?1) AND source = 'manual' AND rejected = 0 "
          'UNION ALL SELECT 1 FROM highlights WHERE item_id = ?1 LIMIT 1',
          variables: [id],
        )
        .getSingleOrNull();
    return own == null;
  }

  /// Голый файл: из входящих прямо в каталог папки под своим именем (камеры или человека),
  /// строка карты файлов — на сам файл. Заметки `.md` рядом нет.
  Future<void> _placeLoose(Item item, Attachment file, List<String> folders) async {
    final name = p.posix.basename(file.path).replaceFirst(RegExp(r'^\d+_'), '');
    final path = await _free(notePath(folders: folders, fileName: name), item.id);
    final source = File(_absolute(file.path));
    if (!await source.exists()) return;
    await _relocate(source.path, _absolute(path));
    await _prune(p.posix.dirname(file.path));
    final stat = await File(_absolute(path)).stat();
    await _quietly(() async {
      await (_db.update(_db.attachments)..where((t) => t.id.equals(file.id))).write(AttachmentsCompanion(path: Value(path)));
      await _db.into(_db.vaultFiles).insertOnConflictUpdate(VaultFilesCompanion.insert(itemId: item.id, path: path, modified: stat.modified.millisecondsSinceEpoch, size: stat.size));
    });
  }

  /// Как вставить файл в текст: коротким именем, если оно одно на хранилище (как пишет
  /// Obsidian), иначе путём от корня.
  Future<String> _embedName(String path) async {
    final name = p.posix.basename(path);
    final lower = name.toLowerCase();
    final others = [
      for (final row in await _db.select(_db.attachments).get()) if (row.path != path) row.path,
      for (final row in await _db.select(_db.vaultFiles).get()) if (row.path != path) row.path,
    ];
    return others.any((other) => p.posix.basename(other).toLowerCase() == lower) ? path : name;
  }

  /// Удалённая заметка уносит в корзину свои вложения, на которые больше никто не ссылается,
  /// и возвращает их при восстановлении. Общие остаются на месте; старые «Заметка/» переезжают
  /// вместе с файлом заметки в [_move].
  Future<void> _trashAttachments(Item item, {required String legacy}) async {
    final deleted = item.deletedAt != null;
    final rows = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(item.id))).get();
    final moved = <String, String>{};
    for (final row in rows) {
      final path = row.path;
      if (_outside(path) || path.startsWith('$legacy/')) continue;
      final inTrash = path.startsWith('$trashFolder/');
      if (deleted == inTrash) continue;
      if (deleted) {
        final shared = await (_db.select(_db.attachments).join([innerJoin(_db.items, _db.items.id.equalsExp(_db.attachments.itemId))])
              ..where(_db.attachments.path.equals(path) & _db.attachments.itemId.equals(item.id).not() & _db.items.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
        if (shared != null) continue;
      }
      var target = deleted ? trashPath(path) : path.substring(trashFolder.length + 1);
      if (!deleted && File(_absolute(target)).existsSync()) target = uniqueNotePath(target, (candidate) => File(_absolute(candidate)).existsSync());
      if (!await _relocate(_absolute(path), _absolute(target))) continue;
      await _prune(p.posix.dirname(path));
      moved[row.id] = target;
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

  /// Папка вложений стёртой заметки. Строки вложений к этому времени уже стёрты, поэтому
  /// папка удаляется, только если похожа на вложения Stowa: без подпапок, заметок, холстов
  /// и баз Obsidian. Иначе это обычная папка человека, и она остаётся как есть.
  Future<void> _dropAttachments(String relativeDir) async {
    final dir = Directory(_absolute(relativeDir));
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File || const {'.md', '.canvas', '.base'}.contains(p.extension(entity.path).toLowerCase())) return;
    }
    await dir.delete(recursive: true);
  }

  /// Пустые подпапки бывшей папки вложений и она сама — снизу вверх; с чужими файлами остаются.
  Future<void> _pruneTree(String relativeDir) async {
    final dir = Directory(_absolute(relativeDir));
    if (!await dir.exists()) return;
    final nested = await dir.list(recursive: true, followLinks: false).where((entity) => entity is Directory).cast<Directory>().toList()
      ..sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final folder in nested) {
      if (await folder.list().isEmpty) await folder.delete();
    }
    if (await dir.list().isEmpty) await dir.delete();
  }

  // пустые папки, оставшиеся после переезда, убираются до корня
  Future<void> _prune(String relativeDir) async {
    // открытая папка скрытого чистится сама, до корня телефона подниматься нельзя
    if (p.isAbsolute(relativeDir)) return;
    var dir = relativeDir;
    while (dir != '.' && dir.isNotEmpty) {
      final folder = Directory(_absolute(dir));
      if (!await folder.exists() || !await folder.list().isEmpty) return;
      await folder.delete();
      dir = p.posix.dirname(dir);
    }
  }

  String _absolute(String relative) => vaultAbsolute(_root!.path, relative);
}

class _ExternalEdit implements Exception {
  const _ExternalEdit();
}

/// Заметка файлом: свойства, теги, цитаты, вложения хвостом. [attachments] — пути вложений
/// по порядку, как их запишет файл; картинки из текста в хвосте не повторяются.
Future<VaultNote> vaultNoteOf(AppDatabase db, Item item, {required List<String> attachments}) async {
  final tags = await db
      .customSelect(
        'SELECT tags.name AS name FROM item_tags JOIN tags ON tags.id = item_tags.tag_id WHERE item_tags.item_id = ? ORDER BY tags.name',
        variables: [Variable.withString(item.id)],
      )
      .get();
  final highlights = await (db.select(db.highlights)
        ..where((t) => t.itemId.equals(item.id))
        ..orderBy([(t) => OrderingTerm.asc(t.position), (t) => OrderingTerm.asc(t.createdAt)]))
      .get();
  final inline = {for (final name in embedNames(item.body)) ?embedPath(name, attachments)};
  return VaultNote(
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
    remindPlace: placeReminderOf(item),
    sortedBy: item.sortedBy,
    pinned: item.pinnedAt,
    attachments: [for (final path in attachments) if (!inline.contains(path)) path],
    highlights: [for (final one in highlights) VaultHighlight(quote: one.quote, note: one.note, at: one.createdAt, position: one.position)],
    extra: unpackVaultProperties(item.properties),
  );
}
