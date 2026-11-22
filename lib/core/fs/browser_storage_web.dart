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

const _yieldKey = 'stowa-panel-yield';

void markPanelYield() {
  try {
    web.window.sessionStorage.setItem(_yieldKey, '${DateTime.now().millisecondsSinceEpoch}');
  } catch (_) {
    // хранилище страницы закрыто: панель просто не подождёт
  }
}

bool panelJustYielded() {
  try {
    final at = int.tryParse(web.window.sessionStorage.getItem(_yieldKey) ?? '');
    web.window.sessionStorage.removeItem(_yieldKey);
    return at != null && DateTime.now().millisecondsSinceEpoch - at < 15000;
  } catch (_) {
    return false;
  }
}

void Function() watchAutofill(String hint, void Function(String value) onFill) {
  // слушает весь документ: поле подстановки Flutter заводит и убирает сам
  final listener = ((web.Event event) {
    final target = event.target;
    if (target == null || !target.isA<web.HTMLInputElement>()) return;
    final input = target as web.HTMLInputElement;
    if ((input.getAttribute('autocomplete') ?? '').contains(hint)) onFill(input.value);
  }).toJS;
  web.document.addEventListener('input', listener, true.toJS);
  web.document.addEventListener('change', listener, true.toJS);
  return () {
    web.document.removeEventListener('input', listener, true.toJS);
    web.document.removeEventListener('change', listener, true.toJS);
  };
}

Future<bool> persistStorage() async {
  try {
    return (await web.window.navigator.storage.persist().toDart).toDart;
  } catch (_) {
    return false;
  }
}

/// Файл, который браузер скачает человеку.
abstract class BrowserDownload {
  void add(Uint8List chunk);

  void save(String name);
}

BrowserDownload startDownload() => _BlobDownload();

class _BlobDownload implements BrowserDownload {
  // Blob браузер держит у себя и большие сбрасывает на диск; куски копим пачками по
  // несколько мегабайт, чтобы не плодить тысячи вложенных Blob
  static const _batch = 4 * 1024 * 1024;

  web.Blob _blob = web.Blob();
  final _parts = <JSUint8Array>[];
  var _size = 0;

  @override
  void add(Uint8List chunk) {
    if (chunk.isEmpty) return;
    // копия: архив переиспользует свои буферы
    _parts.add(Uint8List.fromList(chunk).toJS);
    _size += chunk.length;
    if (_size >= _batch) _fold();
  }

  void _fold() {
    if (_parts.isEmpty) return;
    _blob = web.Blob(<JSAny>[_blob, ..._parts].toJS);
    _parts.clear();
    _size = 0;
  }

  @override
  void save(String name) {
    _fold();
    final file = web.Blob(<JSAny>[_blob].toJS, web.BlobPropertyBag(type: 'application/zip'));
    final url = web.URL.createObjectURL(file);
    final link = web.HTMLAnchorElement()
      ..href = url
      ..download = name
      ..style.display = 'none';
    web.document.body!.append(link);
    link.click();
    link.remove();
    // ссылку держим минуту: браузеру нужно время начать скачивание
    Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  }
}

/// Отдать файл заметки браузеру. С [view] он открывается в новой вкладке (PDF, картинка,
/// ролик, звук, текст — браузер показывает их сам), иначе скачивается под именем [name]:
/// программ системы, которые открыли бы архив или макет, у страницы нет.
void openInBrowser(Uint8List bytes, {required String name, required String mime, required bool view}) {
  final file = web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(file);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..style.display = 'none';
  if (view) {
    link
      ..target = '_blank'
      ..rel = 'noopener';
  } else {
    link.download = name;
  }
  web.document.body!.append(link);
  link.click();
  link.remove();
  // открытой вкладке ссылка нужна, пока файл читают; скачиванию — пока оно начнётся
  Timer(Duration(minutes: view ? 30 : 1), () => web.URL.revokeObjectURL(url));
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

  // файлы, найденные обходом: чтение сразу после него не ищет их заново от корня папка за
  // папкой. Каждый читается один раз и забывается; запись и удаление забывают его сразу
  final _found = <String, web.File>{};

  void _forget(String path) => _found.removeWhere((key, _) => key == path || key.startsWith('$path/'));

  @override
  Future<List<StoredEntry>> list() async {
    final out = <StoredEntry>[];
    _found.clear();
    // содержимое папки — разом, а не по файлу: тысяча заметок по очереди — это секунды до
    // первого кадра
    Future<void> walk(web.FileSystemDirectoryHandle dir, String prefix) async {
      await Future.wait([
        for (final handle in await _children(dir))
          () async {
            final path = '$prefix/${handle.name}';
            if (handle.kind == 'directory') {
              out.add(StoredEntry(path, directory: true));
              await walk(handle as web.FileSystemDirectoryHandle, path);
            } else {
              final file = await (handle as web.FileSystemFileHandle).getFile().toDart;
              _found[path] = file;
              out.add(StoredEntry(path, directory: false, size: file.size, modified: DateTime.fromMillisecondsSinceEpoch(file.lastModified)));
            }
          }(),
      ]);
    }

    await walk(await root, '');
    return out;
  }

  @override
  Future<Uint8List> read(String path) async {
    final file = _found.remove(path) ?? await (await _file(path, create: false)).getFile().toDart;
    final buffer = await file.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  @override
  Future<void> write(String path, Uint8List bytes) async {
    _forget(path);
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
    _forget(path);
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
