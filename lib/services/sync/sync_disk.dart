import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

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
  Future<void> write(String path, Stream<List<int>> data) async {
    final target = _file(path);
    await target.parent.create(recursive: true);
    // временный файл рядом и переименование: сверка и Obsidian видят файл только целым
    final temp = File('${target.parent.path}/.${p.basename(target.path)}.sync.tmp');
    final sink = temp.openWrite();
    try {
      await sink.addStream(data);
      await sink.flush();
    } finally {
      await sink.close();
    }
    await temp.rename(target.path);
  }

  @override
  Future<void> delete(String path) async {
    final file = _file(path);
    if (file.existsSync()) await file.delete();
  }
}
