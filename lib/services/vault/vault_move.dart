import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../data/db/database.dart';
import '../../data/settings_repository.dart';
import '../../domain/models.dart';
import 'vault_layout.dart';
import 'vault_writer.dart';

/// Чем кончился перенос. Не сошлось — старое на месте, настройка не переключена.
class VaultMoveReport {
  const VaultMoveReport({required this.ok, required this.notes, required this.files, this.missing = const []});

  final bool ok;
  final int notes;
  final int files;

  /// Что не нашлось на новом месте после переноса.
  final List<String> missing;
}

/// Перенос хранилища в другую папку; им же старая установка переходит на хранилище.
/// Файлы копируются, заметки пишутся заново, всё сверяется — и только потом
/// переключается настройка и стирается старое.
class VaultMove {
  VaultMove(this._db, {required this.settings, required Directory from, required bool fromInsideApp, required DateTime Function() clock, Future<void> Function(File source, File target)? copy})
    : _from = from, // ignore: prefer_initializing_formals
      _fromInsideApp = fromInsideApp, // ignore: prefer_initializing_formals
      _clock = clock, // ignore: prefer_initializing_formals
      _copy = copy ?? _plainCopy;

  final AppDatabase _db;
  final SettingsRepository settings;
  final Directory _from;

  /// Старый корень внутри приложения: после переноса его можно стереть. Папку человека — нельзя.
  final bool _fromInsideApp;
  final DateTime Function() _clock;
  final Future<void> Function(File source, File target) _copy;

  static Future<void> _plainCopy(File source, File target) async {
    await target.parent.create(recursive: true);
    await source.copy(target.path);
  }

  Future<VaultMoveReport> moveTo(Directory target, VaultMode mode, {void Function(int done, int total)? progress}) async {
    await target.create(recursive: true);
    if (p.equals(p.normalize(_from.absolute.path), p.normalize(target.absolute.path))) {
      await settings.setVault(target.path, mode);
      return const VaultMoveReport(ok: true, notes: 0, files: 0);
    }

    // что куда копировать: старые места — в новую раскладку, уже разложенное — как было
    final copies = <_Copy>[];
    for (final row in await _db.select(_db.attachments).get()) {
      final legacy = row.path.startsWith('attachments/') || row.path.startsWith('$serviceFolder/incoming/');
      copies.add(_Copy(_Kind.attachment, row.id, row.path, legacy ? incomingFile(row.itemId, p.posix.basename(row.path)) : row.path));
    }
    for (final item in await (_db.select(_db.items)..where((t) => t.coverPath.isNotNull())).get()) {
      final path = item.coverPath!;
      copies.add(_Copy(_Kind.cover, item.id, path, path.startsWith('covers/') ? coverFile(item.id, p.posix.extension(path).replaceFirst('.', '')) : path));
    }
    for (final tag in await (_db.select(_db.tags)..where((t) => t.iconKind.equalsValue(TagIconKind.image))).get()) {
      final path = tag.iconValue;
      copies.add(_Copy(_Kind.tagIcon, tag.id, path, path.startsWith('tags/') ? tagIconFile(p.posix.basename(path)) : path));
    }
    final links = await (_db.select(_db.items)..where((t) => t.url.isNotNull())).get();
    for (final item in links) {
      for (final page in ['pages/${item.id}.html.gz', pageCopyFile(item.id)]) {
        if (await File(_at(_from, page)).exists()) copies.add(_Copy(_Kind.page, item.id, page, pageCopyFile(item.id)));
      }
    }

    final items = await _db.select(_db.items).get();
    final total = copies.length + items.length;
    var done = 0;
    final sizes = <String, int>{};
    for (final copy in copies) {
      final source = File(_at(_from, copy.from));
      // файл пропал ещё до переноса: переносить нечего, это не провал переноса
      if (await source.exists()) {
        sizes[copy.to] = await source.length();
        await _copy(source, File(_at(target, copy.to)));
      }
      progress?.call(++done, total);
    }

    // пути в базе — на новое место; прежние запомнены на случай отката
    final oldFiles = await _db.select(_db.vaultFiles).get();
    await _repoint(copies, (copy) => copy.to);
    await _db.delete(_db.vaultFiles).go();
    await _enqueueAll();
    final writer = VaultWriter(_db, root: target, clock: _clock);
    await writer.drain();
    await writer.drain();
    progress?.call(total, total);

    final missing = await _check(target, copies, sizes);
    if (missing.isNotEmpty) {
      await _repoint(copies, (copy) => copy.from);
      await _db.delete(_db.vaultFiles).go();
      await _db.batch((batch) => batch.insertAll(_db.vaultFiles, [for (final row in oldFiles) row]));
      await _enqueueAll();
      return VaultMoveReport(ok: false, notes: items.length, files: copies.length, missing: missing);
    }

    await settings.setVault(target.path, mode);
    if (_fromInsideApp) await _clearOld(oldFiles);
    return VaultMoveReport(ok: true, notes: items.length, files: copies.length);
  }

  Future<void> _repoint(List<_Copy> copies, String Function(_Copy copy) pick) async {
    // вложения писатель уже переложил к заметкам: откат возвращает их к исходным путям
    for (final copy in copies) {
      final path = pick(copy);
      switch (copy.kind) {
        case _Kind.attachment:
          await (_db.update(_db.attachments)..where((t) => t.id.equals(copy.id))).write(AttachmentsCompanion(path: Value(path)));
        case _Kind.cover:
          await (_db.update(_db.items)..where((t) => t.id.equals(copy.id))).write(ItemsCompanion(coverPath: Value(path)));
        case _Kind.tagIcon:
          await (_db.update(_db.tags)..where((t) => t.id.equals(copy.id))).write(TagsCompanion(iconValue: Value(path)));
        case _Kind.page:
          break;
      }
    }
  }

  Future<void> _enqueueAll() => _db.enqueueWholeVault();

  /// Каждая вещь — файлом, каждый скопированный файл — на месте и той же длины.
  Future<List<String>> _check(Directory target, List<_Copy> copies, Map<String, int> sizes) async {
    final missing = <String>[];
    final written = {for (final row in await _db.select(_db.vaultFiles).get()) row.itemId: row.path};
    for (final item in await _db.select(_db.items).get()) {
      final path = written[item.id];
      if (path == null || !await File(_at(target, path)).exists()) missing.add(item.title);
    }
    final attachments = {for (final row in await _db.select(_db.attachments).get()) row.id: row};
    for (final copy in copies) {
      final expected = sizes[copy.to];
      if (expected == null) continue;
      // вложение писатель переложил из входящих к заметке — сверяется новое место
      final path = copy.kind == _Kind.attachment ? (attachments[copy.id]?.path ?? copy.to) : copy.to;
      final file = File(_at(target, path));
      if (!await file.exists() || await file.length() != expected) missing.add(path);
    }
    return missing;
  }

  /// Старое внутри приложения: прежние папки файлов и всё, что писало хранилище.
  Future<void> _clearOld(List<VaultFile> oldFiles) async {
    final tops = {'attachments', 'covers', 'tags', 'pages', serviceFolder, trashFolder, for (final row in oldFiles) row.path.split('/').first};
    for (final top in tops) {
      final entity = FileSystemEntity.typeSync(_at(_from, top));
      if (entity == FileSystemEntityType.directory) await Directory(_at(_from, top)).delete(recursive: true);
      if (entity == FileSystemEntityType.file) await File(_at(_from, top)).delete();
    }
  }

  String _at(Directory root, String relative) => p.joinAll([root.path, ...relative.split('/')]);
}

enum _Kind { attachment, cover, tagIcon, page }

class _Copy {
  const _Copy(this.kind, this.id, this.from, this.to);

  final _Kind kind;
  final String id;
  final String from;
  final String to;
}
