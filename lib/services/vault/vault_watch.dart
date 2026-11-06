import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/db/database.dart';
import 'vault_layout.dart';

/// Пока приложение открыто, следит за папкой хранилища: заметку поправили в Obsidian
/// или её привёз Syncthing — сверка без перезапуска. Слежка без рекурсии (на Android
/// рекурсивной нет): корень и каждая папка верхнего уровня отдельно.
class VaultWatch {
  VaultWatch(this._db, {required Directory? root, required Future<void> Function() onChange, Duration settle = const Duration(milliseconds: 500)})
    : _root = root, // ignore: prefer_initializing_formals
      _onChange = onChange, // ignore: prefer_initializing_formals
      _settle = settle; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final Directory? _root;
  final Future<void> Function() _onChange;

  /// Сколько ждать тишины после событий: редактор пишет файл в несколько приёмов.
  final Duration _settle;

  final _subscriptions = <String, StreamSubscription<FileSystemEvent>>{};
  final _touched = <String>{};
  Timer? _timer;

  void start() {
    final root = _root;
    if (root == null || !root.existsSync() || _subscriptions.isNotEmpty) return;
    _watch(root);
    for (final entity in root.listSync(followLinks: false)) {
      if (entity is Directory && !p.basename(entity.path).startsWith('.')) _watch(entity);
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _touched.clear();
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  void _watch(Directory folder) {
    if (_subscriptions.containsKey(folder.path)) return;
    _subscriptions[folder.path] = folder.watch().listen(_heard, onError: (_) {});
  }

  void _heard(FileSystemEvent event) {
    final relative = p.relative(event.path, from: _root!.path).split(p.separator).join('/');
    if (isServicePath(relative)) return;
    // новая папка верхнего уровня — тоже под слежку
    if (event.isDirectory) {
      if (event.type == FileSystemEvent.create && !relative.contains('/')) _watch(Directory(event.path));
      return;
    }
    if (!relative.endsWith('.md')) return;
    _touched.add(relative);
    _timer?.cancel();
    _timer = Timer(_settle, _check);
  }

  // своя запись совпадает с картой файлов по времени и размеру — сверка не нужна
  Future<void> _check() async {
    final touched = [..._touched];
    _touched.clear();
    for (final relative in touched) {
      final known = await (_db.select(_db.vaultFiles)..where((t) => t.path.equals(relative))).getSingleOrNull();
      final file = File(p.joinAll([_root!.path, ...relative.split('/')]));
      final exists = await file.exists();
      if (known == null && !exists) continue;
      if (known != null && exists) {
        final stat = await file.stat();
        if (stat.modified.millisecondsSinceEpoch == known.modified && stat.size == known.size) continue;
      }
      await _onChange();
      return;
    }
  }
}
