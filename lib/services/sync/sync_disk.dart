import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'sync_crypto.dart' show sha256Hex;
import 'sync_ports.dart';

/// Файлы хранилища на диске для движка синхронизации.
class DiskSyncFiles implements SyncFiles {
  DiskSyncFiles(this.root);

  final Directory root;

  String _relative(String path) => p.split(p.relative(path, from: root.path)).join('/');

  File _file(String path) => File(p.joinAll([root.path, ...path.split('/')]));

  @override
  Future<List<LocalFile>> list() async {
    if (!root.existsSync()) throw FileSystemException('хранилища нет', root.path);
    final out = <LocalFile>[];
    // ссылки не идём: папка-ссылка могла бы увести обход за пределы хранилища
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final stat = entity.statSync();
      out.add(LocalFile(_relative(entity.path), size: stat.size, mtime: stat.modified.millisecondsSinceEpoch));
    }
    return out;
  }

  @override
  Future<LocalFile?> stat(String path) async {
    final file = _file(path);
    final stat = file.statSync();
    if (stat.type != FileSystemEntityType.file) return null;
    return LocalFile(path, size: stat.size, mtime: stat.modified.millisecondsSinceEpoch);
  }

  @override
  Future<List<int>> read(String path, int offset, int length) async {
    final file = await _file(path).open();
    try {
      await file.setPosition(offset);
      return await file.read(max(0, length));
    } finally {
      await file.close();
    }
  }

  @override
  Future<String> stage(String path, Stream<List<int>> data) async {
    final target = _file(path);
    await target.parent.create(recursive: true);
    // временный файл рядом и переименование: сверка и Obsidian видят файл только целым.
    // Имя короткое: «.имя.sync.tmp» у заметки с длинным русским названием выходило за
    // 255 байт (College, семинар по этике — 248 байт)
    final temp = File('${target.parent.path}/.sync-${sha256Hex(utf8.encode(path)).substring(0, 16)}.tmp');
    final sink = temp.openWrite();
    try {
      await sink.addStream(data);
      await sink.flush();
    } catch (_) {
      await sink.close();
      // оборвалось посреди: обрывок не оставляем
      if (temp.existsSync()) await temp.delete();
      rethrow;
    }
    await sink.close();
    return _relative(temp.path);
  }

  @override
  Future<bool> place(String staged, String path, {LocalFile? expect}) async {
    final temp = _file(staged);
    if (!sameFile(await stat(path), expect)) {
      if (temp.existsSync()) await temp.delete();
      return false;
    }
    await temp.rename(_file(path).path);
    return true;
  }

  @override
  Future<bool> delete(String path, {required LocalFile expect}) async {
    if (!sameFile(await stat(path), expect)) return false;
    await _file(path).delete();
    return true;
  }
}
