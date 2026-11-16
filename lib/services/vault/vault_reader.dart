import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;

import 'package:drift/drift.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../data/db/database.dart';
import '../../domain/excalidraw.dart' show isExcalidrawText;
import '../../domain/folder_tree.dart';
import '../../domain/inline_tags.dart';
import '../../domain/note_blocks.dart' show embedNames;
import '../../domain/models.dart';
import '../../domain/tag_name.dart';
import '../../domain/vault_note.dart';
import '../facts/facts_pipeline.dart' show refreshFactsText;
import '../file_keeper.dart' show imageSizeOfFile;
import 'vault_layout.dart';
import 'vault_meta.dart';

/// Что нашёл проход по хранилищу.
class VaultScan {
  int added = 0;
  int changed = 0;
  int removed = 0;
  int conflicts = 0;
}

/// Тег вещи, которую надо разобрать руками: две версии одной заметки.
const conflictTag = 'конфликт';

/// Забирает в базу то, что изменили в файлах снаружи (Obsidian, Syncthing, файловый
/// менеджер), и собирает базу из папки целиком после переустановки. Своё забранное
/// не ставит обратно в очередь записи: правки идут под флагом `importing`.
class VaultReader {
  VaultReader(this._db, {required Directory? root, required DateTime Function() clock}) : _root = root, _clock = clock; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final Directory? _root;
  final DateTime Function() _clock;

  /// Сколько заметок ложится в базу одной транзакцией. На телефоне каждая транзакция —
  /// запись на диск: по одной на заметку тысяча собиралась минутами.
  static const _batch = 100;

  /// Сверить файлы с базой по времени и размеру и забрать изменённое. Сперва читаются
  /// файлы, потом всё прочитанное ложится в базу пачками.
  Future<VaultScan> reconcile({void Function(int done, int total)? progress}) => _exclusively(() => _reconcile(progress: progress));

  /// Сверка одна на всю базу: окно, «Поделиться» и фоновая задача держат свою очередь,
  /// а читают одни файлы. Две сверки разом читали новый файл без id обе и заводили
  /// заметку и папку дважды. Метка `reading` в базе — аренда: оборвался проход —
  /// метка истекает сама, живой проход её продлевает.
  Future<T> _exclusively<T>(Future<T> Function() work) async {
    final root = _root;
    if (root == null) return work();
    // в одном движке сверки той же папки встают друг за другом, без опроса базы
    final queue = _queues[_db] ??= {};
    final previous = queue[root.path] ?? Future<void>.value();
    final finished = Completer<void>();
    queue[root.path] = finished.future;
    await previous;
    final owner = const Uuid().v4();
    try {
      // метка чужого движка: ждать, пока тот закончит или его метка истечёт
      while (!await _claim(owner)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      _owner = owner;
      _renewed.reset();
      _renewed.start();
      return await work();
    } finally {
      _owner = null;
      await _db.customUpdate('DELETE FROM vault_flags WHERE name = ? AND value LIKE ?', variables: [Variable.withString(_flag), Variable.withString('%|$owner')], updates: {_db.vaultFlags});
      finished.complete();
    }
  }

  /// Хвосты очередей сверок этого движка: своя у каждой базы и папки хранилища.
  static final _queues = Expando<Map<String, Future<void>>>();

  /// Метка в базе — на папку: перенос читает новую папку, пока старая ещё сверяется.
  String get _flag => 'reading:${_root!.path}';

  String? _owner;
  final _renewed = Stopwatch();

  /// Долгий проход (тысяча заметок из Telegram) продлевает метку по ходу, раз в несколько секунд.
  Future<void> _keepLease() async {
    final owner = _owner;
    if (owner == null || _renewed.elapsed < const Duration(seconds: 5)) return;
    _renewed.reset();
    await _claim(owner);
  }

  static const _lease = Duration(seconds: 30);

  // метка «срок|хозяин»: занять свободную, истёкшую или свою
  Future<bool> _claim(String owner) async {
    final now = _clock().millisecondsSinceEpoch;
    final changed = await _db.customUpdate(
      'INSERT INTO vault_flags (name, value) VALUES (?, ?) ON CONFLICT(name) DO UPDATE SET value = excluded.value '
      "WHERE CAST(substr(vault_flags.value, 1, instr(vault_flags.value, '|') - 1) AS INTEGER) < ? OR vault_flags.value LIKE ?",
      variables: [Variable.withString(_flag), Variable.withString('${now + _lease.inMilliseconds}|$owner'), Variable.withInt(now), Variable.withString('%|$owner')],
      updates: {_db.vaultFlags},
    );
    return changed > 0;
  }

  Future<VaultScan> _reconcile({void Function(int done, int total)? progress}) async {
    final scan = VaultScan();
    if (_root == null || !await _root.exists()) return scan;
    // настройка вложений Obsidian и указатель имён — свежие на каждый проход
    _attachmentSetting = readAttachmentSetting(_root);
    _byName = null;
    final known = await _db.select(_db.vaultFiles).get();
    final byPath = {for (final row in known) row.path: row};
    final byId = {for (final row in known) row.itemId: row.path};
    final notes = await _notes(trash: false);
    final pending = {for (final row in await _db.select(_db.vaultQueue).get()) row.target};
    final ids = {for (final row in await (_db.selectOnly(_db.items)..addColumns([_db.items.id])).get()) row.read(_db.items.id)!};
    final seen = notes.toSet();
    final incoming = <_Incoming>[];

    // сперва быстрый проход по времени и размеру: счётчик — только изменённые заметки, «340 из 1000»
    final changed = <(String, FileStat)>[];
    // рисунки Excalidraw, прочитанные прежней Stowa обычной заметкой: перечитать рисунком
    final stale = {
      for (final row in await _db
          .customSelect("SELECT vault_files.path FROM vault_files JOIN items ON items.id = vault_files.item_id WHERE vault_files.path LIKE '%.excalidraw.md' AND items.kind <> 'drawing'")
          .get())
        row.read<String>('path'),
    };
    for (final relative in notes) {
      final stat = await File(_absolute(relative)).stat();
      final before = byPath[relative];
      if (before != null && before.modified == stat.modified.millisecondsSinceEpoch && before.size == stat.size && !stale.contains(relative)) continue;
      changed.add((relative, stat));
    }
    // первая половина хода — чтение файлов, вторая — запись в базу
    final total = changed.length;

    for (final (index, (relative, stat)) in changed.indexed) {
      progress?.call(index ~/ 2, total);
      await _keepLease();
      final file = File(_absolute(relative));
      final before = byPath[relative];

      final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      // холст, база и рисунок Excalidraw — файлом целиком, без шапки Stowa
      final document = isDocumentPath(relative) || isExcalidrawText(text);
      final note = document
          ? readVaultDocument(text, fileName: p.posix.basename(relative), fileModified: stat.modified)
          : readVaultNote(text, fileName: p.posix.basename(relative), fileModified: stat.modified);
      // у холста и базы id в файле нет: своя заметка — та, чей это путь в карте файлов
      var id = document ? before?.itemId ?? note.id : note.id;
      var newId = id.isEmpty;
      // копия файла с тем же id (Syncthing-конфликт, копия руками) — отдельная вещь
      final twin = id.isEmpty ? null : byId[id];
      if (twin != null && twin != relative && await File(_absolute(twin)).exists()) newId = true;
      if (newId) id = const Uuid().v4();
      byId[id] = relative;
      final exists = ids.contains(id);
      incoming.add(
        _Incoming(
          id: id,
          relative: relative,
          place: relative,
          note: note,
          text: text,
          newId: newId,
          exists: exists,
          deleted: false,
          // файл правили снаружи, а в приложении есть незаписанная правка: обе версии остаются
          clash: !newId && before != null && exists && pending.contains('item:$id'),
          conflict: newId && relative.contains('.sync-conflict-'),
          attachments: document ? const [] : await _attachments(relative, note),
        ),
      );
    }

    // версия из базы — отдельной вещью, пока файл её не переписал
    for (final one in incoming.where((one) => one.clash)) {
      await _keepOurs(await (_db.select(_db.items)..where((t) => t.id.equals(one.id))).getSingle());
      scan.conflicts++;
    }
    // в базу идут только изменённые: вторая половина хода — их доля
    await _store(incoming, progress: (done) => progress?.call((total + total * done ~/ incoming.length) ~/ 2, total));

    // id в чужие заметки, карта файлов — одной пачкой
    final mapped = <VaultFilesCompanion>[];
    for (final one in incoming) {
      final file = File(_absolute(one.relative));
      if (one.newId && !isDocumentKind(one.note.kind)) await _writeId(file, one.text, one.id);
      final after = await file.stat();
      mapped.add(VaultFilesCompanion.insert(itemId: one.id, path: one.relative, modified: after.modified.millisecondsSinceEpoch, size: after.size));
      one.exists ? scan.changed++ : scan.added++;
    }
    await _db.batch((batch) => batch.insertAllOnConflictUpdate(_db.vaultFiles, mapped));
    for (final one in incoming.where((one) => one.clash)) {
      await (_db.delete(_db.vaultQueue)..where((t) => t.target.equals('item:${one.id}'))).go();
    }
    progress?.call(total, total);
    final loose = await _looseFiles(byPath, seen, scan);

    // файла нет ни среди заметок, ни на своём месте (корзина, служебное): удалили снаружи
    final gone = [...loose];
    for (final row in known) {
      if (seen.contains(row.path) || await File(_absolute(row.path)).exists()) continue;
      gone.add(row.itemId);
    }
    if (gone.isNotEmpty) {
      await _quietly(() async {
        await (_db.update(_db.items)..where((t) => t.id.isIn(gone) & t.deletedAt.isNull())).write(ItemsCompanion(deletedAt: Value(_clock())));
        await (_db.delete(_db.vaultFiles)..where((t) => t.itemId.isIn(gone))).go();
      });
      scan.removed += gone.length;
    }
    await _dropGhostFolders();

    // [[Заметка]] в тексте связью в таблицу не пишется: связь считается из текста (watchLinked)
    return scan;
  }

  /// Папки-призраки от прежней гонки с писателем: каталог вложений «Фото от 20 августа/» рядом
  /// с «Фото от 20 августа.md» сверка однажды приняла за папку. Без вложенных и стоящая ровно
  /// на месте каталога вложений живой заметки — не папка человека: то, что угадыватель успел
  /// в неё разложить, переезжает в родительскую папку (писатель перенесёт файлы), строка уходит.
  Future<void> _dropGhostFolders() async {
    final keys = await _folderKeys();
    if (keys.isEmpty) return;
    final noteDirs = {
      for (final row in await _db.customSelect("SELECT vault_files.path FROM vault_files JOIN items ON items.id = vault_files.item_id WHERE items.deleted_at IS NULL AND vault_files.path LIKE '%.md'").get())
        attachmentsDir(row.read<String>('path')).toLowerCase(),
    };
    final ghosts = [
      for (final MapEntry(key: path, value: id) in keys.entries)
        if (noteDirs.contains(path)) id,
    ];
    for (final id in ghosts) {
      final nested = await (_db.select(_db.folders)..where((t) => t.parentId.equals(id) & t.deletedAt.isNull())).get();
      if (nested.isNotEmpty) continue;
      final folder = await (_db.select(_db.folders)..where((t) => t.id.equals(id))).getSingle();
      // не под флагом: файлы разложенных заметок писатель уносит из каталога вложений в папку
      await (_db.update(_db.items)..where((t) => t.folderId.equals(id))).write(ItemsCompanion(folderId: Value(folder.parentId)));
      // под флагом: каталог на диске — вложения заметки, писатель его не трогает
      await _quietly(() => (_db.delete(_db.folders)..where((t) => t.id.equals(id))).go());
    }
  }

  /// Собрать базу из папки: служебное из `.stowa/`, заметки, корзину, добытое о вещах.
  Future<VaultScan> rebuild({void Function(int done, int total)? progress}) => _exclusively(() => _rebuild(progress: progress));

  Future<VaultScan> _rebuild({void Function(int done, int total)? progress}) async {
    if (_root == null || !await _root.exists()) return VaultScan();
    // папки, теги и правила — до заметок: заметки ищут свою папку по имени
    for (final name in ['folders', 'tags', 'rules']) {
      await _restoreMeta(name);
    }
    final scan = await _reconcile(progress: progress);
    final ids = {for (final row in await (_db.selectOnly(_db.items)..addColumns([_db.items.id])).get()) row.read(_db.items.id)!};
    final trashed = <_Incoming>[];
    for (final relative in await _notes(trash: true)) {
      await _keepLease();
      final file = File(_absolute(relative));
      final stat = await file.stat();
      final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      final note = isExcalidrawText(text)
          ? readVaultDocument(text, fileName: p.posix.basename(relative), fileModified: stat.modified)
          : readVaultNote(text, fileName: p.posix.basename(relative), fileModified: stat.modified);
      if (note.id.isEmpty) continue;
      trashed.add(
        _Incoming(
          id: note.id,
          relative: relative,
          // папка вещи — по пути без «.trash/»
          place: relative.substring(trashFolder.length + 1),
          note: note,
          text: text,
          newId: false,
          exists: ids.contains(note.id),
          deleted: true,
          clash: false,
          conflict: false,
          attachments: await _attachments(relative, note),
        ),
      );
    }
    await _store(trashed);
    final mapped = <VaultFilesCompanion>[];
    for (final one in trashed) {
      final stat = await File(_absolute(one.relative)).stat();
      mapped.add(VaultFilesCompanion.insert(itemId: one.id, path: one.relative, modified: stat.modified.millisecondsSinceEpoch, size: stat.size));
    }
    await _db.batch((batch) => batch.insertAllOnConflictUpdate(_db.vaultFiles, mapped));
    for (final name in ['links', 'learned', 'canvas']) {
      await _restoreMeta(name);
    }
    await _restoreFacts();
    await _restoreHistory();
    return scan;
  }

  /// Снимки заметок из `.stowa/history/<id>.json`: история переживает переустановку.
  Future<void> _restoreHistory() async {
    final dir = Directory(_absolute('$serviceFolder/history'));
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      await _keepLease();
      final id = p.basenameWithoutExtension(entity.path);
      if (await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull() == null) continue;
      final json = jsonDecode(await entity.readAsString()) as Map<String, Object?>;
      await _quietly(() async {
        await (_db.delete(_db.noteVersions)..where((t) => t.itemId.equals(id))).go();
        for (final row in (json['versions'] as List? ?? const []).whereType<Map<String, Object?>>()) {
          await _insertRow('note_versions', row);
        }
      });
    }
  }

  /// Пути заметок от корня: без служебного, или только корзина.
  Future<List<String>> _notes({required bool trash}) async {
    final start = trash ? Directory(_absolute(trashFolder)) : _root!;
    if (!await start.exists()) return const [];
    final found = <String>[];
    await for (final entity in start.list(recursive: true, followLinks: false)) {
      if (entity is! File || !(entity.path.endsWith('.md') || isDocumentPath(entity.path))) continue;
      final relative = p.relative(entity.path, from: _root!.path).split(p.separator).join('/');
      if (trash ? relative.split('/').skip(1).any((part) => part.startsWith('.')) : isServicePath(relative)) continue;
      found.add(relative);
    }
    return found..sort();
  }

  /// Прочитанные заметки — в базу пачками, под флагом: вещь уже лежит в файле. Папки и
  /// теги берутся из памяти, новые заводятся по ходу, и их файлы просятся отдельно.
  Future<void> _store(List<_Incoming> incoming, {void Function(int done)? progress}) async {
    if (incoming.isEmpty) return;
    final folders = await _folderKeys();
    final tags = {for (final tag in await _db.select(_db.tags).get()) tag.name: tag.id};
    final created = <String>{};
    for (var start = 0; start < incoming.length; start += _batch) {
      final chunk = incoming.sublist(start, min(start + _batch, incoming.length));
      await _keepLease();
      await _quietly(() async {
        for (final one in chunk) {
          await _storeOne(one, folders, tags, created);
        }
      });
      progress?.call(start + chunk.length);
    }
    for (final target in created) {
      await _db.customStatement("INSERT INTO vault_queue (target) VALUES ('$target') ON CONFLICT(target) DO UPDATE SET version = version + 1, claimed_until = NULL");
    }
  }

  // ключ — путь каталога папки в нижнем регистре: «дом/ремонт» и «дача/ремонт» — разные папки
  Future<Map<String, String>> _folderKeys() async {
    final rows = await (_db.select(_db.folders)..where((t) => t.deletedAt.isNull())).get();
    final tree = FolderTree([for (final row in rows) FolderNode(id: row.id, name: row.name, parentId: row.parentId)]);
    return {
      for (final row in rows) [for (final name in tree.path(row.id)) vaultFileName(name)].join('/').toLowerCase(): row.id,
    };
  }

  /// Файлы сами по себе: картинка, PDF, запись в папке хранилища без заметки. Каждый —
  /// заметка без текста с этим файлом вложением; файл остаётся, где лежит. Не берутся
  /// вложения заметок (по пути и по имени: Obsidian ссылается коротким именем на файл в
  /// любой папке), папки вложений и служебное. Отдаёт заметки, чей файл стал вложением
  /// другой заметки: они уходят в корзину, файл не трогается.
  Future<List<String>> _looseFiles(Map<String, VaultFile> byPath, Set<String> notes, VaultScan scan) async {
    final attached = <String>{};
    final names = <String>{};
    final owners = <String, String>{};
    for (final row in await _db.select(_db.attachments).get()) {
      attached.add(row.path);
      // имя своего файла заметки-файла не в счёт: другой «фото.jpg» в другой папке — тоже заметка.
      // Во входящих файл лежит с номером порядка («0_IMG.jpg»), к заметке писатель кладёт его без
      // номера, а путь в базе меняет следом: сверка в этот миг видит «IMG.jpg» и сверяет без номера
      if (!byPath.containsKey(row.path)) names.add(p.posix.basename(row.path).replaceFirst(RegExp(r'^\d+_'), '').toLowerCase());
      // хозяин файла — живая заметка, у которой он вложение, а не заметка-файл на нём же
      if (byPath[row.path]?.itemId != row.itemId) owners[row.path] = row.itemId;
    }
    // каталоги вложений: «Дом/Плитка/» рядом с «Дом/Плитка.md»
    final noteDirs = {for (final note in notes) if (note.endsWith('.md')) attachmentsDir(note).toLowerCase()};
    final found = <String>[];
    await for (final entity in _root!.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: _root.path).split(p.separator).join('/');
      if (!isLoosePath(relative) || isServicePath(relative) || relative.endsWith('.part')) continue;
      final lower = p.posix.basename(relative).toLowerCase();
      if (const {'thumbs.db', 'desktop.ini'}.contains(lower)) continue;
      // готовая картинка рисунка Excalidraw («Схема.excalidraw.svg») — часть рисунка
      if (lower.contains('.excalidraw.')) continue;
      found.add(relative);
    }
    found.sort();

    final trashed = <String>[];
    final fresh = <String>[];
    for (final relative in found) {
      final before = byPath[relative];
      if (before != null) {
        // файл стал вложением другой заметки: отдельная заметка больше не нужна
        final owner = owners[relative];
        if (owner != null && owner != before.itemId) {
          trashed.add(before.itemId);
          continue;
        }
        final stat = await File(_absolute(relative)).stat();
        if (before.modified == stat.modified.millisecondsSinceEpoch && before.size == stat.size) continue;
        await _quietly(() async {
          await (_db.update(_db.vaultFiles)..where((t) => t.itemId.equals(before.itemId))).write(
            VaultFilesCompanion(modified: Value(stat.modified.millisecondsSinceEpoch), size: Value(stat.size)),
          );
          await (_db.update(_db.attachments)..where((t) => t.itemId.equals(before.itemId) & t.path.equals(relative))).write(AttachmentsCompanion(size: Value(stat.size)));
        });
        continue;
      }
      if (attached.contains(relative)) continue;
      final name = p.posix.basename(relative);
      if (names.contains(name.toLowerCase()) || noteDirs.contains(p.posix.dirname(relative).toLowerCase())) continue;
      // на файл ссылается текст заметки (`![[фото.jpg]]`, `![](Вложения/фото.jpg)`), которую читатель не нашёл
      // рядом, карточка холста или картинка рисунка Excalidraw
      final mentioned = await _db
          .customSelect('SELECT 1 FROM items WHERE instr(body, ?1) > 0 OR instr(coalesce(document, \'\'), ?1) > 0 LIMIT 1', variables: [Variable.withString(name)])
          .getSingleOrNull();
      if (mentioned != null) continue;
      fresh.add(relative);
    }
    if (fresh.isEmpty) return trashed;

    final folders = await _folderKeys();
    final created = <String>{};
    for (var start = 0; start < fresh.length; start += _batch) {
      final chunk = fresh.sublist(start, min(start + _batch, fresh.length));
      await _keepLease();
      final mapped = <VaultFilesCompanion>[];
      await _quietly(() async {
        for (final relative in chunk) {
          final full = _absolute(relative);
          final stat = await File(full).stat();
          final mime = lookupMimeType(full) ?? 'application/octet-stream';
          final size = mime.startsWith('image/') ? await imageSizeOfFile(full).catchError((_) => null) : null;
          final id = const Uuid().v4();
          final folderId = await _folderFor(relative, folders, created);
          await _db.into(_db.items).insert(
            ItemsCompanion.insert(
              id: id,
              kind: _looseKind(mime),
              title: p.posix.basenameWithoutExtension(relative),
              folderId: Value(folderId),
              // где лежит файл, решил человек: раскладка его не перекладывает
              sortedBy: const Value(SortedBy.user),
              sortState: const Value(SortState.sorted),
              createdAt: stat.modified,
              updatedAt: stat.modified,
            ),
          );
          await _db.into(_db.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Uuid().v4(),
              itemId: id,
              path: relative,
              mime: mime,
              size: stat.size,
              width: Value(size?.width),
              height: Value(size?.height),
            ),
          );
          mapped.add(VaultFilesCompanion.insert(itemId: id, path: relative, modified: stat.modified.millisecondsSinceEpoch, size: stat.size));
        }
        await _db.batch((batch) => batch.insertAllOnConflictUpdate(_db.vaultFiles, mapped));
      });
      scan.added += chunk.length;
    }
    for (final target in created) {
      await _db.customStatement("INSERT INTO vault_queue (target) VALUES ('$target') ON CONFLICT(target) DO UPDATE SET version = version + 1, claimed_until = NULL");
    }
    return trashed;
  }

  Future<void> _storeOne(_Incoming one, Map<String, String> folders, Map<String, String> tags, Set<String> created) async {
    final id = one.id;
    final note = one.note;
    final attachments = one.attachments;
    final deleted = one.deleted;
    final exists = one.exists;
    final folderId = await _folderFor(one.place, folders, created);
    final inline = extractInlineTags(note.body);
    final tagIds = <String, String>{};
    for (final raw in [...note.tags, if (one.conflict) conflictTag]) {
      final name = normalizeTagName(raw);
      if (name.isEmpty) continue;
      tagIds[name] = tags[name] ??= await _newTag(name, created);
    }
    final now = _clock();
    // Obsidian свойство updated не трогает: правленный снаружи текст получает время файла,
    // иначе заметка выглядела бы старой и история не сняла бы прежнюю версию
    var updated = note.updated;
    if (exists && !deleted) {
      final current = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (current != null && (current.body != note.body || current.title != note.title)) {
        final modified = (await File(_absolute(one.relative)).stat()).modified;
        if (modified.isAfter(updated) && modified.isAfter(current.updatedAt)) updated = modified;
      }
    }
    {
      final fields = ItemsCompanion(
        kind: Value(note.kind),
        title: Value(note.title),
        body: Value(note.body),
        url: Value(note.url),
        folderId: Value(folderId),
        sortedBy: Value(note.sortedBy ?? (folderId == null && !one.newId ? SortedBy.none : SortedBy.user)),
        coverPath: Value(note.cover),
        previewText: Value(note.previewText),
        previewSite: Value(note.previewSite),
        previewAuthor: Value(note.previewAuthor),
        durationSeconds: Value(note.durationSeconds),
        latitude: Value(note.latitude),
        longitude: Value(note.longitude),
        placeName: Value(note.placeName),
        reminderAt: Value(note.reminder),
        remindPlace: Value(note.remindPlace?.kind),
        remindLatitude: Value(note.remindPlace?.latitude),
        remindLongitude: Value(note.remindPlace?.longitude),
        remindPlaceName: Value(note.remindPlace?.name),
        remindPlaceRef: Value(note.remindPlace?.ref),
        remindPlaceDay: Value(note.remindPlace?.day),
        properties: Value(packVaultProperties(note.extra)),
        pinnedAt: Value(note.pinned),
        document: Value(isDocumentKind(note.kind) ? one.text : null),
        createdAt: Value(note.created),
        updatedAt: Value(updated),
        deletedAt: Value(deleted ? now : null),
      );
      if (exists) {
        await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(fields);
      } else {
        await _db.into(_db.items).insert(
          fields.copyWith(
            id: Value(id),
            // у ссылки с превью из файла заново качать нечего
            previewAt: Value(note.previewSite != null || note.cover != null ? now : null),
            // заметку без id Stowa написал человек снаружи (Obsidian): где она лежит, решил он,
            // раскладка её не перекладывает и «разбираю» не показывается
            sortState: Value(folderId == null && !one.newId ? SortState.pending : SortState.sorted),
          ),
        );
      }

      await (_db.delete(_db.itemTags)..where((t) => t.itemId.equals(id))).go();
      for (final MapEntry(key: name, value: tagId) in tagIds.entries) {
        await _db.into(_db.itemTags).insertOnConflictUpdate(ItemTagsCompanion.insert(itemId: id, tagId: tagId, source: inline.contains(name) ? TagSource.inline : TagSource.user));
      }

      // цитаты статьи — целиком из файла, и сразу в поиск: файла фактов у них нет
      await (_db.delete(_db.highlights)..where((t) => t.itemId.equals(id))).go();
      for (final one in note.highlights) {
        await _db.into(_db.highlights).insert(
          HighlightsCompanion.insert(id: const Uuid().v4(), itemId: id, quote: one.quote, note: Value(one.note), position: Value(one.position), createdAt: one.at),
        );
      }
      await refreshFactsText(_db, id);

      final rows = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(id))).get();
      final byPath = {for (final row in rows) row.path: row};
      for (final row in rows) {
        if (!attachments.contains(row.path)) await (_db.delete(_db.attachments)..where((t) => t.id.equals(row.id))).go();
      }
      for (final (position, path) in attachments.indexed) {
        final row = byPath[path];
        if (row != null) {
          await (_db.update(_db.attachments)..where((t) => t.id.equals(row.id))).write(AttachmentsCompanion(position: Value(position)));
          continue;
        }
        final full = _absolute(path);
        final mime = lookupMimeType(full) ?? 'application/octet-stream';
        final size = mime.startsWith('image/') ? await imageSizeOfFile(full).catchError((_) => null) : null;
        await _db.into(_db.attachments).insert(
          AttachmentsCompanion.insert(
            id: const Uuid().v4(),
            itemId: id,
            path: path,
            mime: mime,
            size: await File(full).length(),
            position: Value(position),
            width: Value(size?.width),
            height: Value(size?.height),
          ),
        );
      }
    }
  }

  ({bool obsidian, String? setting}) _attachmentSetting = (obsidian: false, setting: null);

  /// Файлы хранилища по имени в нижнем регистре, без служебного и корзины: короткое имя
  /// `![[закат.jpg]]` Obsidian ищет по всему хранилищу. Строится один раз за проход, по нужде.
  Map<String, List<String>>? _byName;

  Future<String?> _anywhere(String name) async {
    final index = _byName ??= await () async {
      final found = <String, List<String>>{};
      await for (final entity in _root!.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final relative = p.relative(entity.path, from: _root.path).split(p.separator).join('/');
        if (isServicePath(relative) || relative.split('/').any((part) => part.startsWith('.'))) continue;
        found.putIfAbsent(p.posix.basename(relative).toLowerCase(), () => []).add(relative);
      }
      return found;
    }();
    final hits = index[p.posix.basename(name).toLowerCase()];
    if (hits == null || hits.isEmpty) return null;
    // имя с частью пути («Где-то/d.jpg») — тот, чей путь им кончается; иначе самый короткий путь, как у Obsidian
    final suffix = name.toLowerCase();
    final fitting = hits.where((path) => path.toLowerCase().endsWith(suffix)).toList()..sort((a, b) => a.length.compareTo(b.length));
    return fitting.firstOrNull;
  }

  /// Вложения: строки `![[…]]` из хвоста (путь от корня, как пишет Stowa, или короткое
  /// имя, как пишет Obsidian) и файлы из папки вещи, которых в строках нет. Короткое имя
  /// ищется рядом, в своём каталоге, в папке вложений по настройке Obsidian и по всему хранилищу.
  Future<List<String>> _attachments(String relative, VaultNote note) async {
    final dir = attachmentsDir(relative);
    final near = p.posix.dirname(relative);
    final shared = attachmentFolderFor(relative, obsidian: _attachmentSetting.obsidian, setting: _attachmentSetting.setting);
    final found = <String>[];
    // хвост и картинки из текста: и те, и другие — вложения заметки
    for (final link in [...note.attachments, ...embedNames(note.body)]) {
      String? hit;
      for (final candidate in [link, '$dir/$link', if (near != '.') '$near/$link', if (shared.isNotEmpty) '$shared/$link']) {
        if (await File(_absolute(candidate)).exists()) {
          hit = candidate;
          break;
        }
      }
      hit ??= await _anywhere(link);
      if (hit != null && !found.contains(hit)) found.add(hit);
    }
    final folder = Directory(_absolute(dir));
    if (await folder.exists()) {
      final extra = [
        for (final entity in await folder.list().toList())
          if (entity is File && !p.basename(entity.path).startsWith('.')) '$dir/${p.basename(entity.path)}',
      ]..sort();
      for (final path in extra) {
        if (!found.contains(path)) found.add(path);
      }
    }
    return found;
  }

  /// Папка Stowa по каталогу заметки: каждый каталог пути — папка, подкаталог — вложенная.
  /// Нет такой — заводится вся цепочка. Глубина из файлов любая: чужое не перекладываем.
  Future<String?> _folderFor(String relative, Map<String, String> folders, Set<String> created) async {
    final parts = relative.split('/');
    String? parent;
    for (var level = 1; level < parts.length; level++) {
      final key = parts.sublist(0, level).join('/').toLowerCase();
      final known = folders[key];
      if (known != null) {
        parent = known;
        continue;
      }
      final id = const Uuid().v4();
      final count = await _db.folders.count().getSingle();
      const shapes = ['cookie9', 'squircle', 'gem', 'pill', 'cookie6'];
      await _db.into(_db.folders).insert(
        FoldersCompanion.insert(id: id, name: parts[level - 1], icon: 'folder', shape: shapes[count % shapes.length], sortOrder: Value(count), parentId: Value(parent)),
      );
      folders[key] = id;
      created.add('meta:folders');
      parent = id;
    }
    return parent;
  }

  Future<String> _newTag(String name, Set<String> created) async {
    final id = const Uuid().v4();
    await _db.into(_db.tags).insert(TagsCompanion.insert(id: id, name: name, createdAt: _clock()));
    created.add('meta:tags');
    return id;
  }

  Future<String> _tagFor(String raw) async {
    final name = normalizeTagName(raw);
    final tag = await (_db.select(_db.tags)..where((t) => t.name.equals(name))).getSingleOrNull();
    if (tag != null) return tag.id;
    final id = const Uuid().v4();
    await _db.into(_db.tags).insert(TagsCompanion.insert(id: id, name: name, createdAt: _clock()));
    return id;
  }

  /// Версия из базы при конфликте — новой вещью рядом, с тегом «конфликт»: её запишет писатель.
  Future<void> _keepOurs(Item ours) async {
    final id = const Uuid().v4();
    await _db.into(_db.items).insert(
      ItemsCompanion.insert(
        id: id,
        kind: ours.kind,
        title: '${ours.title} (Stowa)',
        body: Value(ours.body),
        url: Value(ours.url),
        folderId: Value(ours.folderId),
        sortedBy: Value(ours.sortedBy),
        sortState: Value(ours.sortState),
        createdAt: ours.createdAt,
        updatedAt: _clock(),
      ),
    );
    final tags = await (_db.select(_db.itemTags)..where((t) => t.itemId.equals(ours.id))).get();
    for (final tag in tags) {
      await _db.into(_db.itemTags).insertOnConflictUpdate(ItemTagsCompanion.insert(itemId: id, tagId: tag.tagId, source: tag.source));
    }
    await _db.into(_db.itemTags).insertOnConflictUpdate(ItemTagsCompanion.insert(itemId: id, tagId: await _tagFor(conflictTag), source: TagSource.user));
  }

  /// `id` в свойства чужой заметки — единственная правка её файла.
  Future<void> _writeId(File file, String text, String id) async {
    final line = vaultProperty('id', id).single;
    final normalized = text.replaceAll('\r\n', '\n');
    final String updated;
    if (normalized.startsWith('---\n')) {
      final rest = normalized.substring(4);
      final withoutOld = rest.replaceFirst(RegExp(r'^id:.*\n', multiLine: true), '');
      updated = '---\n$line\n$withoutOld';
    } else {
      updated = '---\n$line\n---\n$normalized';
    }
    final temp = File(p.join(file.parent.path, '.${p.basename(file.path)}.tmp'));
    await temp.writeAsString(updated, flush: true);
    await temp.rename(file.path);
  }

  Future<void> _restoreMeta(String name) async {
    final file = File(_absolute(metaFile(name)));
    if (!await file.exists()) return;
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    await _quietly(() async {
      for (final table in vaultMetaTables[name]!) {
        for (final row in (json[table] as List? ?? const []).whereType<Map<String, Object?>>()) {
          await _insertRow(table, row);
        }
      }
    });
  }

  Future<void> _restoreFacts() async {
    final dir = Directory(_absolute('$serviceFolder/facts'));
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      await _keepLease();
      final id = p.basenameWithoutExtension(entity.path);
      if (await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull() == null) continue;
      final json = jsonDecode(await entity.readAsString()) as Map<String, Object?>;
      await _quietly(() async {
        await (_db.delete(_db.facts)..where((t) => t.itemId.equals(id))).go();
        await (_db.delete(_db.extractorRuns)..where((t) => t.itemId.equals(id))).go();
        for (final row in (json['facts'] as List? ?? const []).whereType<Map<String, Object?>>()) {
          await _insertRow('facts', row);
        }
        for (final row in (json['runs'] as List? ?? const []).whereType<Map<String, Object?>>()) {
          await _insertRow('extractor_runs', row);
        }
        await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
          ItemsCompanion(transcript: Value(json['transcript'] as String?), aiDescription: Value(json['ai_description'] as String?)),
        );
        await refreshFactsText(_db, id);
      });
    }
  }

  // строка таблицы как её записал писатель: поля как есть
  Future<void> _insertRow(String table, Map<String, Object?> row) async {
    final columns = row.keys.toList();
    await _db.customStatement(
      'INSERT OR REPLACE INTO $table (${columns.join(', ')}) VALUES (${List.filled(columns.length, '?').join(', ')})',
      [for (final column in columns) row[column]],
    );
  }

  /// Своя правка базы, которую не надо писать обратно в файлы: флаг глушит триггеры.
  Future<void> _quietly(Future<void> Function() change) => _db.transaction(() async {
    await _db.into(_db.vaultFlags).insertOnConflictUpdate(VaultFlagsCompanion.insert(name: 'importing'));
    try {
      await change();
    } finally {
      await (_db.delete(_db.vaultFlags)..where((t) => t.name.equals('importing'))).go();
    }
  });

  String _absolute(String relative) => vaultAbsolute(_root!.path, relative);
}

/// Прочитанная заметка, которая ждёт записи в базу.
// вид заметки-файла по типу файла
ItemKind _looseKind(String mime) => switch (mime.split('/').first) {
  'image' => ItemKind.image,
  'video' => ItemKind.video,
  'audio' => ItemKind.voice,
  _ => ItemKind.file,
};

class _Incoming {
  const _Incoming({
    required this.id,
    required this.relative,
    required this.place,
    required this.note,
    required this.text,
    required this.newId,
    required this.exists,
    required this.deleted,
    required this.clash,
    required this.conflict,
    required this.attachments,
  });

  final String id;

  /// Где лежит файл.
  final String relative;

  /// Путь, по которому ищется папка: у корзины — без «.trash/».
  final String place;
  final VaultNote note;
  final String text;

  /// Заметка без своего id (Obsidian) или копия: id выдан здесь и дописывается в файл.
  final bool newId;
  final bool exists;
  final bool deleted;
  final bool clash;
  final bool conflict;
  final List<String> attachments;
}
