import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../data/db/database.dart';
import '../../domain/inline_tags.dart';
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

// [[Заметка]] и [[Заметка|подпись]], но не вставка ![[фото.jpg]]
final _wikiLink = RegExp(r'(?<!!)\[\[([^\]|#]+)(?:[#|][^\]]*)?\]\]');

/// Забирает в базу то, что изменили в файлах снаружи (Obsidian, Syncthing, файловый
/// менеджер), и собирает базу из папки целиком после переустановки. Своё забранное
/// не ставит обратно в очередь записи: правки идут под флагом `importing`.
class VaultReader {
  VaultReader(this._db, {required Directory? root, required DateTime Function() clock}) : _root = root, _clock = clock; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final Directory? _root;
  final DateTime Function() _clock;

  /// Сверить файлы с базой по времени и размеру и забрать изменённое.
  Future<VaultScan> reconcile({void Function(int done, int total)? progress}) async {
    final scan = VaultScan();
    if (_root == null || !await _root.exists()) return scan;
    final known = await _db.select(_db.vaultFiles).get();
    final byPath = {for (final row in known) row.path: row};
    final byId = {for (final row in known) row.itemId: row};
    final notes = await _notes(trash: false);
    final pending = {for (final row in await _db.select(_db.vaultQueue).get()) row.target};
    final links = <String, List<String>>{};
    final seen = <String>{};

    for (final (index, relative) in notes.indexed) {
      progress?.call(index, notes.length);
      seen.add(relative);
      final file = File(_absolute(relative));
      final stat = await file.stat();
      final before = byPath[relative];
      if (before != null && before.modified == stat.modified.millisecondsSinceEpoch && before.size == stat.size) continue;

      final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      final note = readVaultNote(text, fileName: p.posix.basename(relative), fileModified: stat.modified);
      var id = note.id;
      var newId = id.isEmpty;
      // копия файла с тем же id (Syncthing-конфликт, копия руками) — отдельная вещь
      final twin = id.isEmpty ? null : byId[id];
      if (twin != null && twin.path != relative && await File(_absolute(twin.path)).exists()) newId = true;
      if (newId) id = const Uuid().v4();
      final existing = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull();

      // файл правили снаружи, а в приложении есть незаписанная правка: обе версии остаются
      final clash = !newId && before != null && existing != null && pending.contains('item:$id');
      if (clash) {
        await _keepOurs(existing);
        scan.conflicts++;
      }

      await _import(id, relative, note, deleted: false, conflict: newId && relative.contains('.sync-conflict-'));
      if (newId) await _writeId(file, text, id);
      final after = await file.stat();
      await _db.into(_db.vaultFiles).insertOnConflictUpdate(VaultFilesCompanion.insert(itemId: id, path: relative, modified: after.modified.millisecondsSinceEpoch, size: after.size));
      byId[id] = VaultFile(itemId: id, path: relative, modified: after.modified.millisecondsSinceEpoch, size: after.size);
      if (clash) await (_db.delete(_db.vaultQueue)..where((t) => t.target.equals('item:$id'))).go();
      existing == null ? scan.added++ : scan.changed++;
      final targets = [for (final match in _wikiLink.allMatches(note.body)) match.group(1)!.trim()];
      if (targets.isNotEmpty) links[id] = targets;
    }
    progress?.call(notes.length, notes.length);

    // файла нет ни среди заметок, ни на своём месте (корзина, служебное): удалили снаружи
    for (final row in known) {
      if (seen.contains(row.path) || await File(_absolute(row.path)).exists()) continue;
      await _quietly(() async {
        await (_db.update(_db.items)..where((t) => t.id.equals(row.itemId) & t.deletedAt.isNull())).write(ItemsCompanion(deletedAt: Value(_clock())));
        await (_db.delete(_db.vaultFiles)..where((t) => t.itemId.equals(row.itemId))).go();
      });
      scan.removed++;
    }

    await _link(links);
    return scan;
  }

  /// Собрать базу из папки: служебное из `.stowa/`, заметки, корзину, добытое о вещах.
  Future<VaultScan> rebuild({void Function(int done, int total)? progress}) async {
    if (_root == null || !await _root.exists()) return VaultScan();
    // папки, теги и правила — до заметок: заметки ищут свою папку по имени
    for (final name in ['folders', 'tags', 'rules']) {
      await _restoreMeta(name);
    }
    final scan = await reconcile(progress: progress);
    for (final relative in await _notes(trash: true)) {
      final file = File(_absolute(relative));
      final stat = await file.stat();
      final note = readVaultNote(utf8.decode(await file.readAsBytes(), allowMalformed: true), fileName: p.posix.basename(relative), fileModified: stat.modified);
      if (note.id.isEmpty) continue;
      await _import(note.id, relative.substring(trashFolder.length + 1), note, deleted: true, conflict: false);
      await _db.into(_db.vaultFiles).insertOnConflictUpdate(VaultFilesCompanion.insert(itemId: note.id, path: relative, modified: stat.modified.millisecondsSinceEpoch, size: stat.size));
    }
    for (final name in ['links', 'learned', 'canvas']) {
      await _restoreMeta(name);
    }
    await _restoreFacts();
    return scan;
  }

  /// Пути заметок от корня: без служебного, или только корзина.
  Future<List<String>> _notes({required bool trash}) async {
    final start = trash ? Directory(_absolute(trashFolder)) : _root!;
    if (!await start.exists()) return const [];
    final found = <String>[];
    await for (final entity in start.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      final relative = p.relative(entity.path, from: _root!.path).split(p.separator).join('/');
      if (trash ? relative.split('/').skip(1).any((part) => part.startsWith('.')) : isServicePath(relative)) continue;
      found.add(relative);
    }
    return found..sort();
  }

  /// Вещь из заметки. Папки и теги заводятся обычной записью (их файлы обновятся),
  /// сама вещь — под флагом: она уже лежит в файле.
  Future<void> _import(String id, String relative, VaultNote note, {required bool deleted, required bool conflict}) async {
    final folderId = await _folderFor(relative);
    final inline = extractInlineTags(note.body);
    final tagIds = <String, String>{};
    for (final name in [...note.tags, if (conflict) conflictTag]) {
      tagIds[name] = await _tagFor(name);
    }
    final attachments = await _attachments(relative, note);
    final now = _clock();
    await _quietly(() async {
      final exists = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull() != null;
      final fields = ItemsCompanion(
        kind: Value(note.kind),
        title: Value(note.title),
        body: Value(note.body),
        url: Value(note.url),
        folderId: Value(folderId),
        sortedBy: Value(note.sortedBy ?? (folderId == null ? SortedBy.none : SortedBy.user)),
        coverPath: Value(note.cover),
        previewText: Value(note.previewText),
        previewSite: Value(note.previewSite),
        previewAuthor: Value(note.previewAuthor),
        durationSeconds: Value(note.durationSeconds),
        latitude: Value(note.latitude),
        longitude: Value(note.longitude),
        placeName: Value(note.placeName),
        reminderAt: Value(note.reminder),
        createdAt: Value(note.created),
        updatedAt: Value(note.updated),
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
            sortState: Value(folderId == null ? SortState.pending : SortState.sorted),
          ),
        );
      }

      await (_db.delete(_db.itemTags)..where((t) => t.itemId.equals(id))).go();
      for (final MapEntry(key: name, value: tagId) in tagIds.entries) {
        await _db.into(_db.itemTags).insertOnConflictUpdate(ItemTagsCompanion.insert(itemId: id, tagId: tagId, source: inline.contains(name) ? TagSource.inline : TagSource.user));
      }

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
    });
  }

  /// Вложения: строки `![[…]]` из хвоста (путь от корня, как пишет Stowa, или короткое
  /// имя, как пишет Obsidian) и файлы из папки вещи, которых в строках нет.
  Future<List<String>> _attachments(String relative, VaultNote note) async {
    final dir = attachmentsDir(relative);
    final near = p.posix.dirname(relative);
    final found = <String>[];
    for (final link in note.attachments) {
      for (final candidate in [link, '$dir/$link', if (near != '.') '$near/$link']) {
        if (await File(_absolute(candidate)).exists()) {
          if (!found.contains(candidate)) found.add(candidate);
          break;
        }
      }
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

  /// Папка Stowa по каталогу верхнего уровня; нет такой — заводится.
  Future<String?> _folderFor(String relative) async {
    final parts = relative.split('/');
    if (parts.length < 2) return null;
    final name = parts.first;
    final folders = await (_db.select(_db.folders)..where((t) => t.deletedAt.isNull())).get();
    for (final folder in folders) {
      if (vaultFileName(folder.name).toLowerCase() == name.toLowerCase()) return folder.id;
    }
    final id = const Uuid().v4();
    final count = await _db.folders.count().getSingle();
    const shapes = ['cookie9', 'squircle', 'gem', 'pill', 'cookie6'];
    await _db.into(_db.folders).insert(FoldersCompanion.insert(id: id, name: name, icon: 'folder', shape: shapes[count % shapes.length], sortOrder: Value(count)));
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

  /// `[[Заметка]]` — ручная связь с вещью того же заголовка.
  Future<void> _link(Map<String, List<String>> links) async {
    if (links.isEmpty) return;
    final titles = <String, String>{};
    for (final item in await (_db.select(_db.items)..where((t) => t.deletedAt.isNull())).get()) {
      titles.putIfAbsent(item.title.toLowerCase(), () => item.id);
    }
    await _quietly(() async {
      for (final MapEntry(key: from, value: targets) in links.entries) {
        for (final target in targets) {
          final to = titles[target.toLowerCase()];
          if (to == null || to == from) continue;
          await _db.into(_db.links).insert(LinksCompanion.insert(fromId: from, toId: to, source: LinkSource.manual), mode: InsertMode.insertOrIgnore);
        }
      }
    });
  }

  /// `id` в свойства чужой заметки — единственная правка её файла.
  Future<void> _writeId(File file, String text, String id) async {
    final line = 'id: ${jsonEncode(id)}';
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

  String _absolute(String relative) => p.joinAll([_root!.path, ...relative.split('/')]);
}
