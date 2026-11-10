import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../data/db/database.dart';
import '../../domain/folder_tree.dart';
import '../../domain/vault_note.dart';
import '../vault/vault_layout.dart';
import '../vault/vault_meta.dart';
import '../vault/vault_writer.dart' show vaultNoteOf;
import 'hidden_rows.dart' show hiddenItemIds;

/// Выгрузка в Markdown: копия хранилища в `Stowa-ГГГГ-ММ-ДД/` выбранной папки. Это то же
/// хранилище — его открывает Obsidian и сама Stowa. Без запечатанного и без замка;
/// с [includeHidden] открытое скрытое ложится обычными файлами в свои папки.
class MarkdownExport {
  MarkdownExport(this._db, {required Directory vault, required DateTime Function() clock}) : _vault = vault, _clock = clock; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final Directory _vault;
  final DateTime Function() _clock;

  Future<Directory> export(Directory target, {bool includeHidden = false}) async {
    final day = _clock().toIso8601String().substring(0, 10);
    var out = Directory(p.join(target.path, 'Stowa-$day'));
    for (var number = 2; await out.exists(); number++) {
      out = Directory(p.join(target.path, 'Stowa-$day $number'));
    }
    await out.create(recursive: true);
    await _copyVault(_vault, out);
    if (includeHidden) await _writeHidden(out);
    return out;
  }

  // всё хранилище, кроме шифра скрытого, замка и недописанных временных файлов
  Future<void> _copyVault(Directory from, Directory to) async {
    await for (final entity in from.list(recursive: true, followLinks: false)) {
      final relative = p.relative(entity.path, from: from.path).split(p.separator).join('/');
      if (relative == '$serviceFolder/sealed' || relative.startsWith('$serviceFolder/sealed/') || relative == '$serviceFolder/lock.json') continue;
      if (p.basename(relative).endsWith('.tmp')) continue;
      final dest = p.joinAll([to.path, ...relative.split('/')]);
      if (entity is Directory) {
        await Directory(dest).create(recursive: true);
      } else if (entity is File) {
        await Directory(p.dirname(dest)).create(recursive: true);
        await entity.copy(dest);
      }
    }
  }

  /// Скрытые заметки как писатель хранилища написал бы их, будь папки обычными.
  Future<void> _writeHidden(Directory out) async {
    final ids = await hiddenItemIds(_db);
    if (ids.isEmpty) return;
    final rows = await (_db.select(_db.folders)).get();
    final tree = FolderTree([for (final row in rows) FolderNode(id: row.id, name: row.name, parentId: row.parentId)]);
    final items = await (_db.select(_db.items)..where((t) => t.id.isIn(ids))).get();
    final taken = <String>{};
    for (final item in items) {
      var path = notePath(folders: item.folderId == null ? const [] : tree.path(item.folderId!), fileName: '${vaultFileName(item.title)}.md');
      if (item.deletedAt != null) path = trashPath(path);
      path = uniqueNotePath(path, (candidate) => taken.contains(candidate.toLowerCase()) || File(p.join(out.path, candidate)).existsSync());
      taken.add(path.toLowerCase());
      final dir = attachmentsDir(path);
      final attachments = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(item.id))..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
      final copied = <String>[];
      for (final attachment in attachments) {
        final source = File(vaultAbsolute(_vault.path, attachment.path));
        if (!await source.exists()) continue;
        final relative = '$dir/${p.basename(attachment.path)}';
        await _copy(source, out, relative);
        copied.add(relative);
      }
      var cover = item.coverPath;
      if (cover != null && p.isAbsolute(cover)) {
        final relative = plainCoverFile(item.id, p.extension(cover).replaceFirst('.', ''));
        if (await File(cover).exists()) await _copy(File(cover), out, relative);
        cover = relative;
      }
      final note = await vaultNoteOf(_db, item.copyWith(coverPath: Value(cover)), attachments: copied);
      await _write(out, path, writeVaultNote(note, fileName: p.posix.basename(path)));
      if (await factsJson(_db, item.id) case final facts?) await _write(out, factsFile(item.id), facts);
      if (await historyJson(_db, item.id) case final history?) await _write(out, historyFile(item.id), history);
    }
  }

  Future<void> _copy(File source, Directory out, String relative) async {
    final dest = File(p.joinAll([out.path, ...relative.split('/')]));
    await dest.parent.create(recursive: true);
    await source.copy(dest.path);
  }

  Future<void> _write(Directory out, String relative, String text) async {
    final dest = File(p.joinAll([out.path, ...relative.split('/')]));
    await dest.parent.create(recursive: true);
    await dest.writeAsString(text);
  }
}
