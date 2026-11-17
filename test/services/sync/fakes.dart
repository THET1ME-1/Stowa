import 'dart:convert';
import 'dart:math';

import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_ports.dart';

/// Сбой сети или падение посреди прохода.
class Broken implements Exception {
  const Broken(this.where);

  final String where;

  @override
  String toString() => 'Broken($where)';
}

/// Хранилище в памяти. Время правки идёт по общим часам [clock].
class MemoryVault implements VaultFiles {
  MemoryVault(this.clock);

  final int Function() clock;
  final files = <String, (List<int>, int)>{};
  bool listFails = false;

  void put(String path, List<int> data) => files[path] = (List.of(data), clock());

  void putText(String path, String text) => put(path, _utf8(text));

  String? text(String path) => files[path] == null ? null : _fromUtf8(files[path]!.$1);

  @override
  Future<List<LocalFile>> list() async {
    if (listFails) throw const Broken('обход');
    return [for (final e in files.entries) LocalFile(e.key, size: e.value.$1.length, mtime: e.value.$2)];
  }

  @override
  Future<LocalFile?> stat(String path) async {
    final f = files[path];
    return f == null ? null : LocalFile(path, size: f.$1.length, mtime: f.$2);
  }

  @override
  Future<List<int>> read(String path, int offset, int length) async {
    final data = files[path]!.$1;
    return data.sublist(min(offset, data.length), min(offset + length, data.length));
  }

  @override
  Future<void> write(String path, Stream<List<int>> data) async {
    final all = <int>[];
    await for (final part in data) {
      all.addAll(part);
    }
    files[path] = (all, clock());
  }

  @override
  Future<void> delete(String path) async => files.remove(path);
}

List<int> _utf8(String s) => utf8.encode(s);
String _fromUtf8(List<int> b) => utf8.decode(b);

/// Сервер в памяти: те же правила ревизий и курсора, что у настоящего.
class FakeRemote implements SyncRemote {
  final blobs = <String, List<int>>{};
  final _files = <String, RemoteChange>{};
  final _seq = <String, int>{};
  var _cursor = 0;

  String describe(String file) {
    final f = _files[file];
    return f == null ? 'нет' : 'rev ${f.rev}${f.deleted ? ' удалён' : ''} seq ${_seq[file]}';
  }

  int get lastSeq => _cursor;

  /// Сбой: вызов с этим номером (по счёту всех вызовов) бросает.
  bool Function(String call)? failWhen;
  int putCount = 0;

  void _maybeFail(String call) {
    if (failWhen?.call(call) ?? false) throw Broken(call);
  }

  @override
  Future<ChangePage> changes(int since, {int wait = 0}) async {
    _maybeFail('changes');
    final fresh = [
      for (final e in _seq.entries)
        if (e.value > since) (e.value, _files[e.key]!),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final page = fresh.take(50).toList();
    return ChangePage(cursor: page.isEmpty ? max(since, 0) : page.last.$1, more: fresh.length > page.length, changes: [for (final p in page) p.$2]);
  }

  @override
  Future<bool> hasBlob(String hash) async {
    _maybeFail('hasBlob');
    return blobs.containsKey(hash);
  }

  @override
  Future<void> putBlob(String hash, List<int> data) async {
    _maybeFail('putBlob');
    if (sha256Hex(data) != hash) throw StateError('отпечаток не совпал');
    blobs[hash] = List.of(data);
    putCount++;
  }

  @override
  Future<List<int>> getBlob(String hash) async {
    _maybeFail('getBlob');
    return blobs[hash]!;
  }

  @override
  Future<RemoteChange?> file(String file) async {
    _maybeFail('file');
    return _files[file];
  }

  @override
  Future<CommitResult> commit(String file, {required int baseRev, required String meta, required List<String> blobs, required int size, bool deleted = false}) async {
    _maybeFail('commit');
    final current = _files[file]?.rev ?? 0;
    if (current != baseRev) return Conflict(current);
    for (final b in blobs) {
      if (!this.blobs.containsKey(b)) throw StateError('нет части $b');
    }
    final rev = current + 1;
    _files[file] = RemoteChange(file: file, rev: rev, meta: meta, blobs: blobs, size: size, deleted: deleted);
    _seq[file] = ++_cursor;
    _maybeFail('commitAnswer');
    return Committed(rev);
  }
}

class MemoryState implements SyncState {
  int _cursor = 0;
  final _files = <String, SyncedFile>{};
  final _shadows = <String, String>{};

  @override
  Future<int> cursor() async => _cursor;

  @override
  Future<void> setCursor(int cursor) async => _cursor = cursor;

  @override
  Future<Map<String, SyncedFile>> files() async => Map.of(_files);

  @override
  Future<void> put(SyncedFile file) async => _files[file.file] = file;

  @override
  Future<void> remove(String file) async {
    _files.remove(file);
    _shadows.remove(file);
  }

  @override
  Future<String?> shadow(String file) async => _shadows[file];

  @override
  Future<void> setShadow(String file, String? text) async => text == null ? _shadows.remove(file) : _shadows[file] = text;
}
