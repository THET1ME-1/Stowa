import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'web_store.dart';

WebStore openBrowserStore() => OpfsWebStore();

WebWal openBrowserWal() => LocalStorageWal();

void onPageHide(void Function() callback) {
  web.window.addEventListener('pagehide', ((web.Event _) => callback()).toJS);
  web.document.addEventListener(
    'visibilitychange',
    ((web.Event _) {
      if (web.document.visibilityState == 'hidden') callback();
    }).toJS,
  );
}

void warnBeforeLeave(bool Function() pending) {
  web.window.addEventListener(
    'beforeunload',
    ((web.BeforeUnloadEvent event) {
      if (pending()) event.preventDefault();
    }).toJS,
  );
}

const _tabLock = 'stowa-vault';
const _tabChannel = 'stowa-tab';
const _leave = 'leave';

// замок Web Locks живёт, пока не завершится обещание из его обработчика: это — никогда
final _held = Completer<void>();

/// Запросить замок хранилища. С [wait] ждёт, пока его отпустит другая вкладка.
Future<bool> _lockVault({required bool wait}) {
  // старый браузер без Web Locks: работаем как раньше, без замка
  if (!web.window.navigator.has('locks')) return Future.value(true);
  final got = Completer<bool>();
  JSPromise<JSAny?>? granted(web.Lock? lock) {
    if (!got.isCompleted) got.complete(lock != null);
    return lock == null ? null : _held.future.toJS;
  }

  web.window.navigator.locks.request(_tabLock, web.LockOptions(ifAvailable: !wait), granted.toJS);
  return got.future;
}

Future<bool> claimTab() => _lockVault(wait: false);

Future<void> waitForTab() => _lockVault(wait: true);

void askTabToLeave() => web.BroadcastChannel(_tabChannel).postMessage(_leave.toJS);

void onTabTakenOver(Future<void> Function() leave) {
  web.BroadcastChannel(_tabChannel).onmessage = ((web.MessageEvent event) {
    if (event.data.dartify() == _leave) leave();
  }).toJS;
}

void reloadPage() => web.window.location.reload();

Future<bool> persistStorage() async {
  try {
    return (await web.window.navigator.storage.persist().toDart).toDart;
  } catch (_) {
    return false;
  }
}

/// Личная папка сайта (OPFS): файлы хранилища лежат в `stowa-files/`, рядом с базой drift.
class OpfsWebStore implements WebStore {
  static const _folder = 'stowa-files';
  static const _metaName = 'stowa-files-meta.json';

  Future<web.FileSystemDirectoryHandle>? _root;

  Future<web.FileSystemDirectoryHandle> _opfs() => web.window.navigator.storage.getDirectory().toDart;

  Future<web.FileSystemDirectoryHandle> get root => _root ??= () async {
    final opfs = await _opfs();
    return opfs.getDirectoryHandle(_folder, web.FileSystemGetDirectoryOptions(create: true)).toDart;
  }();

  List<String> _parts(String path) => path.split('/').where((part) => part.isNotEmpty).toList();

  Future<web.FileSystemDirectoryHandle> _dir(List<String> parts, {required bool create}) async {
    var dir = await root;
    for (final part in parts) {
      dir = await dir.getDirectoryHandle(part, web.FileSystemGetDirectoryOptions(create: create)).toDart;
    }
    return dir;
  }

  Future<web.FileSystemFileHandle> _file(String path, {required bool create}) async {
    final parts = _parts(path);
    final dir = await _dir(parts.sublist(0, parts.length - 1), create: create);
    return dir.getFileHandle(parts.last, web.FileSystemGetFileOptions(create: create)).toDart;
  }

  @override
  Future<List<StoredEntry>> list() async {
    final out = <StoredEntry>[];
    Future<void> walk(web.FileSystemDirectoryHandle dir, String prefix) async {
      for (final handle in await _children(dir)) {
        final path = '$prefix/${handle.name}';
        if (handle.kind == 'directory') {
          out.add(StoredEntry(path, directory: true));
          await walk(handle as web.FileSystemDirectoryHandle, path);
        } else {
          final file = await (handle as web.FileSystemFileHandle).getFile().toDart;
          out.add(StoredEntry(path, directory: false, size: file.size, modified: DateTime.fromMillisecondsSinceEpoch(file.lastModified)));
        }
      }
    }

    await walk(await root, '');
    return out;
  }

  @override
  Future<Uint8List> read(String path) async {
    final file = await (await _file(path, create: false)).getFile().toDart;
    final buffer = await file.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  @override
  Future<void> write(String path, Uint8List bytes) async {
    final handle = await _file(path, create: true);
    await _writeHandle(handle, bytes);
  }

  Future<void> _writeHandle(web.FileSystemFileHandle handle, Uint8List bytes) async {
    final stream = await handle.createWritable().toDart;
    try {
      await stream.write(bytes.toJS).toDart;
    } finally {
      await stream.close().toDart;
    }
  }

  @override
  Future<void> move(String from, String to) async {
    // перенос файла умеют не все браузеры: читаем и пишем, по одному файлу за раз
    await write(to, await read(from));
    await delete(from);
  }

  @override
  Future<void> delete(String path) async {
    final parts = _parts(path);
    if (parts.isEmpty) return;
    try {
      final dir = await _dir(parts.sublist(0, parts.length - 1), create: false);
      await dir.removeEntry(parts.last, web.FileSystemRemoveOptions(recursive: true)).toDart;
    } on Object {
      // нет — значит уже удалён
    }
  }

  @override
  Future<void> mkdir(String path) async {
    await _dir(_parts(path), create: true);
  }

  @override
  Future<Uint8List?> readMeta() async {
    try {
      final opfs = await _opfs();
      final handle = await opfs.getFileHandle(_metaName).toDart;
      final buffer = await (await handle.getFile().toDart).arrayBuffer().toDart;
      return buffer.toDart.asUint8List();
    } on Object {
      return null;
    }
  }

  @override
  Future<void> writeMeta(Uint8List bytes) async {
    final opfs = await _opfs();
    await _writeHandle(await opfs.getFileHandle(_metaName, web.FileSystemGetFileOptions(create: true)).toDart, bytes);
  }
}

/// Содержимое папки браузера: перебор асинхронным итератором `values()`,
/// которого нет в package:web.
Future<List<web.FileSystemHandle>> _children(web.FileSystemDirectoryHandle dir) async {
  final iterator = _Iterable(dir).values();
  final out = <web.FileSystemHandle>[];
  while (true) {
    final step = await iterator.next().toDart;
    if (step.done) break;
    out.add(step.value as web.FileSystemHandle);
  }
  return out;
}

extension type _Iterable(JSObject _) implements JSObject {
  external _AsyncIterator values();
}

extension type _AsyncIterator(JSObject _) implements JSObject {
  external JSPromise<_Step> next();
}

extension type _Step(JSObject _) implements JSObject {
  external bool get done;
  external JSObject? get value;
}

/// Журнал в localStorage: запись синхронная и переживает закрытие вкладки сразу
/// после правки. Порядок — по номеру записи.
class LocalStorageWal implements WebWal {
  static const _prefix = 'stowa-wal:';

  web.Storage get _storage => web.window.localStorage;

  int _seq = DateTime.now().microsecondsSinceEpoch;

  @override
  Map<String, Uint8List?> load() {
    final found = <(int, String, Uint8List?)>[];
    for (var i = 0; i < _storage.length; i++) {
      final key = _storage.key(i);
      if (key == null || !key.startsWith(_prefix)) continue;
      final raw = _storage.getItem(key);
      if (raw == null) continue;
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      final data = entry['d'] as String?;
      found.add(((entry['s'] as num).toInt(), key.substring(_prefix.length), data == null ? null : base64Decode(data)));
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    return {for (final (_, path, bytes) in found) path: bytes};
  }

  @override
  bool put(String path, Uint8List? bytes) {
    try {
      _storage.setItem('$_prefix$path', jsonEncode({'s': ++_seq, 'd': bytes == null ? null : base64Encode(bytes)}));
      return true;
    } on Object {
      // места нет: правка уйдёт только в хранилище
      _storage.removeItem('$_prefix$path');
      return false;
    }
  }

  @override
  void remove(String path) => _storage.removeItem('$_prefix$path');
}
