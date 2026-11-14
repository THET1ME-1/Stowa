import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../data/db/database.dart';
import '../data/repositories/folders_repository.dart';
import '../data/repositories/items_repository.dart';
import '../domain/bookmarks_export.dart';
import '../domain/imported_note.dart';
import '../domain/keep_export.dart';
import '../domain/mymind_export.dart';
import '../domain/vault_note.dart';
import 'capture_service.dart';

/// Откуда переносятся заметки. Telegram — свой перенос (`TelegramImport`).
enum ImportSource { keep, bookmarks, markdown, mymind }

// заметок в одной транзакции: на телефоне каждая — запись на диск
const _batch = 50;

// картинка в тексте Obsidian: ![[имя.png|300]] и ![подпись](папка/имя.png)
final _wikiEmbed = RegExp(r'!\[\[([^\]|#]+)(?:[|#][^\]]*)?\]\]');
final _markdownEmbed = RegExp(r'!\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)');

// Takeout пишет в заметке .jpeg, а кладёт файл .jpg (и наоборот)
const _imageTwins = {'.jpeg': '.jpg', '.jpg': '.jpeg'};

/// Итог переноса: сколько заметок появилось, сколько уже было, сколько файлов не нашлось.
class ImportReport {
  const ImportReport({required this.added, required this.repeated, required this.filesMissing});

  final int added;
  final int repeated;
  final int filesMissing;
}

/// Выбранная папка или файл — не выгрузка этого источника.
class NotesImportError implements Exception {
  const NotesImportError(this.reason);
  final String reason;

  @override
  String toString() => 'NotesImportError: $reason';
}

/// Перенос из Google Keep, закладок браузера, папки Obsidian и mymind. Каждая заметка
/// сохраняется как обычная: правила, угадыватель папки, ИИ, файлы и хранилище работают как всегда.
class NotesImport {
  NotesImport(this._db, this._capture);

  final AppDatabase _db;
  final CaptureService _capture;

  /// [path] — файл закладок или папка выгрузки остальных.
  Future<ImportReport> run(ImportSource source, String path, {void Function(int done, int total)? progress}) async {
    final root = source == ImportSource.bookmarks ? File(path).parent.path : path;
    final notes = switch (source) {
      ImportSource.keep => await _keep(Directory(path)),
      ImportSource.bookmarks => await _bookmarks(File(path)),
      ImportSource.markdown => await _markdown(Directory(path)),
      ImportSource.mymind => await _mymind(Directory(path)),
    };
    if (notes.isEmpty && source != ImportSource.bookmarks) throw NotesImportError('нет заметок: ${source.name}');

    var added = 0;
    var repeated = 0;
    var missing = 0;
    final folders = <String, String>{};
    final index = <String, File>{};
    progress?.call(0, notes.length);
    for (var start = 0; start < notes.length; start += _batch) {
      final batch = notes.sublist(start, (start + _batch).clamp(0, notes.length));
      final inputs = <CaptureInput>[];
      final pinned = <bool>[];
      for (final note in batch) {
        final files = <PickedFile>[];
        for (final exported in note.files) {
          final file = await _find(root, exported.path, index);
          if (file == null) {
            missing++;
            continue;
          }
          files.add(PickedFile(path: file.path, mime: exported.mime, size: await file.length()));
        }
        // заметка Obsidian из одного заголовка: текстом становится он
        final text = note.text.trim().isEmpty && files.isEmpty ? (note.title ?? '') : note.text.trim();
        if (text.isEmpty && files.isEmpty) continue;
        if (await _already(note.at, text)) {
          repeated++;
          continue;
        }
        final folderId = note.folder.isEmpty ? null : await _folder(note.folder, folders);
        // старая заметка «напомни дома» не оживает: ни времени, ни места
        inputs.add(CaptureInput(text: text, title: note.title, files: files, at: note.at, forcedTagNames: note.tags, forcedFolderId: folderId, here: false, detectReminder: false, detectPlace: false));
        pinned.add(note.pinned);
      }
      if (inputs.isNotEmpty) {
        final ids = await _capture.captureAll(inputs);
        final items = ItemsRepository(_db);
        for (final (index, id) in ids.indexed) {
          if (pinned[index]) await items.setPinned(id, DateTime.now());
        }
      }
      added += inputs.length;
      progress?.call((start + batch.length).clamp(0, notes.length), notes.length);
    }
    return ImportReport(added: added, repeated: repeated, filesMissing: missing);
  }

  // Takeout: заметка — .json рядом с её картинками; .html той же заметки и Labels.txt мимо
  Future<List<ImportedNote>> _keep(Directory folder) async {
    if (!await folder.exists()) throw const NotesImportError('нет папки');
    final notes = <ImportedNote>[];
    await for (final file in _files(folder, '.json')) {
      final Object? json;
      try {
        json = jsonDecode(await file.readAsString());
      } on FormatException {
        continue;
      }
      if (json is! Map) continue;
      final note = parseKeepNote(json);
      if (note == null) continue;
      // путь картинки — от папки самой заметки
      final here = p.relative(file.parent.path, from: folder.path);
      notes.add(
        ImportedNote(
          text: note.text,
          files: [for (final exported in note.files) ExportedFile(path: p.normalize(p.join(here, exported.path)), mime: exported.mime)],
          at: note.at,
          tags: note.tags,
          pinned: note.pinned,
        ),
      );
    }
    notes.sort((a, b) => a.at.compareTo(b.at));
    return notes;
  }

  Future<List<ImportedNote>> _bookmarks(File file) async {
    if (!await file.exists()) throw const NotesImportError('нет файла');
    try {
      return parseBookmarks(await file.readAsString());
    } on FormatException catch (error) {
      throw NotesImportError(error.message);
    } on FileSystemException catch (error) {
      throw NotesImportError(error.message);
    }
  }

  // папка Obsidian: заметка — .md, подпапка — папка Stowa, картинки ищутся по имени по всей папке
  Future<List<ImportedNote>> _markdown(Directory folder) async {
    if (!await folder.exists()) throw const NotesImportError('нет папки');
    final notes = <ImportedNote>[];
    await for (final file in _files(folder, '.md')) {
      final vault = readVaultNote(await file.readAsString(), fileName: p.basename(file.path), fileModified: await file.lastModified());
      final names = {
        ...vault.attachments,
        for (final match in _wikiEmbed.allMatches(vault.body)) match.group(1)!.trim(),
        for (final match in _markdownEmbed.allMatches(vault.body))
          if (!match.group(1)!.contains('://')) Uri.decodeFull(match.group(1)!),
      };
      final relative = p.relative(file.parent.path, from: folder.path);
      notes.add(
        ImportedNote(
          text: vault.body,
          title: vault.title,
          files: [for (final name in names) ExportedFile(path: name, mime: lookupMimeType(name) ?? 'application/octet-stream')],
          at: vault.created,
          tags: vault.tags,
          folder: relative == '.' ? const [] : p.split(relative),
        ),
      );
    }
    notes.sort((a, b) => a.at.compareTo(b.at));
    return notes;
  }

  Future<List<ImportedNote>> _mymind(Directory folder) async {
    final csv = File(p.join(folder.path, 'cards.csv'));
    if (!await csv.exists()) throw const NotesImportError('нет cards.csv');
    final names = {
      await for (final entity in folder.list())
        if (entity is File) p.basename(entity.path),
    };
    try {
      return parseMymindCsv(await csv.readAsString(), files: names)..sort((a, b) => a.at.compareTo(b.at));
    } on FormatException catch (error) {
      throw NotesImportError(error.message);
    }
  }

  /// Файлы с расширением [extension] вглубь, кроме папок с точкой (`.obsidian`, `.trash`).
  Stream<File> _files(Directory folder, String extension) async* {
    await for (final entity in folder.list(recursive: true, followLinks: false)) {
      if (entity is! File || p.extension(entity.path).toLowerCase() != extension) continue;
      final parts = p.split(p.relative(entity.path, from: folder.path));
      if (parts.any((part) => part.startsWith('.'))) continue;
      yield entity;
    }
  }

  // файл по пути от корня выгрузки; нет — по имени где угодно в ней (так ищет Obsidian).
  // Указатель имён собирается один раз за перенос, при первом промахе
  Future<File?> _find(String root, String relative, Map<String, File> index) async {
    final candidates = [relative, if (_imageTwins[p.extension(relative).toLowerCase()] case final twin?) p.setExtension(relative, twin)];
    for (final candidate in candidates) {
      final direct = File(p.join(root, candidate));
      if (await direct.exists()) return direct;
    }
    if (index.isEmpty) {
      await for (final entity in Directory(root).list(recursive: true, followLinks: false)) {
        if (entity is File) index.putIfAbsent(p.basename(entity.path), () => entity);
      }
    }
    return [for (final candidate in candidates) index[p.basename(candidate)]].nonNulls.firstOrNull;
  }

  // та же дата до секунды и тот же текст — эту заметку уже переносили
  Future<bool> _already(DateTime at, String text) async {
    final same =
        await (_db.select(_db.items)
              ..where((t) => t.createdAt.equals(at) & t.body.equals(text))
              ..limit(1))
            .get();
    return same.isNotEmpty;
  }

  /// Папка Stowa по пути Obsidian: есть с таким именем у того же родителя — она, иначе новая.
  Future<String> _folder(List<String> path, Map<String, String> known) async {
    String? parent;
    for (final (index, name) in path.indexed) {
      final key = path.take(index + 1).join('/');
      final cached = known[key];
      if (cached != null) {
        parent = cached;
        continue;
      }
      final named = name[0].toUpperCase() + name.substring(1);
      final query = _db.select(_db.folders)..where((t) => t.name.equals(named) & (parent == null ? t.parentId.isNull() : t.parentId.equals(parent)));
      final existing = await (query..limit(1)).getSingleOrNull();
      final id = existing?.id ?? (await FoldersRepository(_db).create(name, parentId: parent)).id;
      known[key] = id;
      parent = id;
    }
    return parent!;
  }
}
