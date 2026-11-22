import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file/memory.dart';

import 'web_store.dart';

/// Файлы приложения в браузере. Код по-прежнему пишет `File(путь)`: [WebIOOverrides]
/// отдаёт ему файлы отсюда. Дерево, время и мелкие файлы живут в памяти, крупные
/// вложения — только в хранилище браузера и читаются оттуда. Каждая правка сразу
/// ложится в журнал ([WebWal], синхронно) и чуть позже — в хранилище ([flush]).
///
/// В хранилище идут только пути под [roots]; временные файлы и кэш живут в памяти.
class WebFileSystem extends ForwardingFileSystem {
  WebFileSystem(this.store, {WebWal? wal, this.roots = const ['/vault', '/vaults', '/app'], this.delay = const Duration(milliseconds: 300)})
    : _wal = wal, // ignore: prefer_initializing_formals
      super(MemoryFileSystem(style: FileSystemStyle.posix));

  final WebStore store;
  final WebWal? _wal;
  final List<String> roots;

  /// Сколько ждать после правки, прежде чем писать в хранилище: подряд идущие
  /// правки одного файла уходят одной записью.
  final Duration delay;

  /// Крупнее этого файл (кроме текста) держится только в хранилище.
  static const lazyFrom = 256 * 1024;

  /// Текст хранилища всегда в памяти: его читают синхронно.
  static const _textEndings = ['.md', '.json', '.txt', '.canvas', '.yaml', '.yml', '.csv', '.base'];

  // путь → размер: содержимое только в хранилище, в памяти пустой файл
  final _lazy = <String, int>{};
  // крупный файл перенесли, а хранилище ещё нет: где его содержимое лежит сейчас
  final _storedAt = <String, String>{};
  // путь → время правки, мс: хранилище браузера ставит своё время записи
  final _modified = <String, int>{};
  // путь → номер правки: журнал стирается, только если после записи правок не было
  final _versions = <String, int>{};
  final _ops = <_Op>[];
  bool _metaDirty = false;
  Timer? _timer;
  Future<void>? _running;
  bool _again = false;

  final _failures = StreamController<Object>.broadcast();

  /// Ошибки записи в хранилище (нет места, отозван доступ). Правки остаются в очереди.
  Stream<Object> get failures => _failures.stream;

  /// Правок, ещё не записанных в хранилище.
  int get pending => _ops.length;

  // ——— пути ———

  String normalize(String path) => delegate.path.normalize(delegate.path.absolute(path));

  bool persisted(String path) => roots.any((root) => path == root || path.startsWith('$root/'));

  bool _text(String path) {
    final lower = path.toLowerCase();
    return _textEndings.any(lower.endsWith);
  }

  bool isLazy(String path) => _lazy.containsKey(normalize(path));

  /// Сама память под обёртками: служебные действия, которые не идут в хранилище.
  MemoryFileSystem get memory => delegate as MemoryFileSystem;

  // ——— обёртки ———

  @override
  File file(dynamic path) => _WebFile(this, delegate.file(path));

  @override
  Directory directory(dynamic path) => _WebDirectory(this, delegate.directory(path));

  @override
  Directory get systemTempDirectory => _WebDirectory(this, delegate.systemTempDirectory);

  @override
  Directory get currentDirectory => _WebDirectory(this, delegate.currentDirectory);

  @override
  Future<io.FileStat> stat(String path) async => statSync(path);

  @override
  io.FileStat statSync(String path) {
    final base = delegate.statSync(path);
    final size = _lazy[normalize(path)];
    return size == null ? base : _SizedStat(base, size);
  }

  @override
  bool get isWatchSupported => false;

  // ——— старт ———

  /// Хранилища заметок, кроме открытого: их файлы видны, но в память не читаются.
  static const _vaultRoots = ['/vault', '/vaults'];

  /// Прочитать хранилище в память и применить журнал. Зовётся один раз до первого `File(...)`.
  /// [open] — папка открытого хранилища заметок: остальные хранилища (`/vault`, `/vaults/…`)
  /// встают заглушками и читаются из хранилища браузера, только когда понадобятся. Сменили
  /// хранилище — страница перезагружается и поднимает уже его. null — читать всё.
  Future<void> hydrate({String? open}) async {
    bool closed(String path) => open != null && _vaultRoots.any((root) => path.startsWith('$root/')) && !path.startsWith('$open/');
    final metaBytes = await store.readMeta();
    final meta = metaBytes == null ? const <String, dynamic>{} : (jsonDecode(utf8.decode(metaBytes)) as Map<String, dynamic>);
    final entries = await store.list();
    for (final entry in entries.where((entry) => entry.directory)) {
      delegate.directory(entry.path).createSync(recursive: true);
    }
    final files = entries.where((entry) => !entry.directory).toList();
    // мелкие читаются пачками: тысячи заметок по одной шли бы долго, а пачка в 16 ждала
    // предыдущую полторы сотни раз подряд
    for (var start = 0; start < files.length; start += 64) {
      await Future.wait([
        for (final entry in files.skip(start).take(64))
          () async {
            final target = delegate.file(entry.path)..parent.createSync(recursive: true);
            if (closed(entry.path) || (entry.size > lazyFrom && !_text(entry.path))) {
              target.writeAsBytesSync(const []);
              _lazy[entry.path] = entry.size;
            } else {
              target.writeAsBytesSync(await store.read(entry.path));
            }
            final time = (meta[entry.path] as num?)?.toInt() ?? entry.modified?.millisecondsSinceEpoch;
            if (time != null) {
              target.setLastModifiedSync(DateTime.fromMillisecondsSinceEpoch(time));
              _modified[entry.path] = time;
            }
          }(),
      ]);
    }
    _replay();
  }

  // правки, не дошедшие до хранилища в прошлый раз
  void _replay() {
    final journal = _wal?.load() ?? const <String, Uint8List?>{};
    for (final MapEntry(key: path, value: bytes) in journal.entries) {
      final move = _moveFrom(bytes);
      if (bytes == null) {
        if (delegate.typeSync(path) != io.FileSystemEntityType.notFound) _silentDelete(path);
        _queue(_Delete(path));
      } else if (move != null) {
        if (delegate.file(move).existsSync()) {
          delegate.file(path).parent.createSync(recursive: true);
          delegate.file(move).renameSync(path);
          final size = _lazy.remove(move);
          if (size != null) _lazy[path] = size;
          final time = _modified.remove(move);
          if (time != null) _modified[path] = time;
        }
        _queue(_Move(move, path));
      } else {
        final target = delegate.file(path)..parent.createSync(recursive: true);
        target.writeAsBytesSync(bytes);
        _lazy.remove(path);
        _modified[path] = target.lastModifiedSync().millisecondsSinceEpoch;
        _queue(_Write(path));
      }
      _versions[path] = (_versions[path] ?? 0) + 1;
    }
    if (_ops.isNotEmpty) _schedule();
  }

  void _silentDelete(String path) {
    final type = delegate.typeSync(path);
    if (type == io.FileSystemEntityType.directory) {
      delegate.directory(path).deleteSync(recursive: true);
      _lazy.removeWhere((key, _) => key.startsWith('$path/'));
      _modified.removeWhere((key, _) => key.startsWith('$path/'));
    } else if (type == io.FileSystemEntityType.file) {
      delegate.file(path).deleteSync();
    }
    _lazy.remove(path);
    _modified.remove(path);
  }

  // ——— учёт правок ———

  static const _movePrefix = '\u0000stowa-move:';

  static String? _moveFrom(Uint8List? bytes) {
    if (bytes == null || bytes.length < _movePrefix.length) return null;
    final text = utf8.decode(bytes, allowMalformed: true);
    return text.startsWith(_movePrefix) ? text.substring(_movePrefix.length) : null;
  }

  int _bump(String path) => _versions[path] = (_versions[path] ?? 0) + 1;

  void _journal(String path, Uint8List? bytes) {
    final wal = _wal;
    if (wal == null) return;
    // ушедшие в хранилище записи журнала о той же папке больше не нужны
    if (bytes == null) {
      for (final key in wal.load().keys.where((key) => key.startsWith('$path/'))) {
        wal.remove(key);
      }
    }
    wal.put(path, bytes);
  }

  void _queue(_Op op) {
    // новая запись того же файла заменяет старую: содержимое берётся в момент записи
    if (op is _Write) _ops.removeWhere((other) => other is _Write && other.path == op.path);
    _ops.add(op);
  }

  /// Файл [path] записан или создан.
  void changed(String path) {
    path = normalize(path);
    if (!persisted(path)) return;
    final target = delegate.file(path);
    if (!target.existsSync()) return;
    _lazy.remove(path);
    _modified[path] = target.lastModifiedSync().millisecondsSinceEpoch;
    _metaDirty = true;
    _bump(path);
    // крупное в журнал не влезет: оно уйдёт только в хранилище
    if (target.lengthSync() <= lazyFrom || _text(path)) {
      _journal(path, target.readAsBytesSync());
    } else {
      _wal?.remove(path);
    }
    _queue(_Write(path));
    _schedule();
  }

  /// Время правки файла сменили руками.
  void touched(String path) {
    path = normalize(path);
    if (!persisted(path)) return;
    final target = delegate.file(path);
    if (!target.existsSync()) return;
    _modified[path] = target.lastModifiedSync().millisecondsSinceEpoch;
    _metaDirty = true;
    _schedule();
  }

  /// Файл или папка [path] удалены (папка — со всем содержимым).
  void deleted(String path) {
    path = normalize(path);
    if (!persisted(path)) return;
    _lazy.remove(path);
    _lazy.removeWhere((key, _) => key.startsWith('$path/'));
    _modified.remove(path);
    _modified.removeWhere((key, _) => key.startsWith('$path/'));
    _metaDirty = true;
    _bump(path);
    _journal(path, null);
    _queue(_Delete(path));
    _schedule();
  }

  /// Папка создана.
  void created(String path) {
    path = normalize(path);
    if (!persisted(path)) return;
    _queue(_Mkdir(path));
    _schedule();
  }

  /// Файл перенесён: крупный — переносом в хранилище, мелкий — записью на новом месте.
  void moved(String from, String to) {
    from = normalize(from);
    to = normalize(to);
    final size = _lazy.remove(from);
    final time = _modified.remove(from);
    if (size != null) {
      _lazy[to] = size;
      _storedAt[to] = _storedAt.remove(from) ?? from;
      if (time != null) _modified[to] = time;
      _metaDirty = true;
      if (persisted(from) && persisted(to)) {
        _bump(to);
        _wal?.put(to, Uint8List.fromList(utf8.encode('$_movePrefix$from')));
        _queue(_Move(from, to));
        _schedule();
        return;
      }
    }
    changed(to);
    if (persisted(from)) {
      _bump(from);
      _journal(from, null);
      _queue(_Delete(from));
      _schedule();
    }
  }

  /// Перенос папки: каждый файл по [moved], старая папка — удалением.
  void movedDirectory(String from, String to, List<String> files) {
    from = normalize(from);
    to = normalize(to);
    created(to);
    for (final path in files) {
      moved(path, '$to${path.substring(from.length)}');
    }
    deleted(from);
  }

  /// Пути файлов внутри папки — до переноса или удаления.
  List<String> filesUnder(String path) {
    final dir = delegate.directory(path);
    if (!dir.existsSync()) return const [];
    return [for (final entity in dir.listSync(recursive: true)) if (entity is io.File) normalize(entity.path)];
  }

  // ——— чтение крупного ———

  Future<Uint8List> readLazy(String path) {
    path = normalize(path);
    return store.read(_storedAt[path] ?? path);
  }

  Never notLoaded(String path) => throw io.FileSystemException('Крупный файл в браузере читается только асинхронно', path);

  // ——— запись в хранилище ———

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(flush().catchError((Object _) {})));
  }

  /// Записать накопленное в хранилище. Подряд идущие вызовы ждут друг друга.
  Future<void> flush() async {
    _timer?.cancel();
    if (_running != null) {
      _again = true;
      return _running;
    }
    final done = Completer<void>();
    _running = done.future;
    try {
      do {
        _again = false;
        await _drain();
      } while (_again || _ops.isNotEmpty);
      done.complete();
    } catch (error, stack) {
      _failures.add(error);
      done.completeError(error, stack);
    } finally {
      _running = null;
    }
    return done.future;
  }

  Future<void> _drain() async {
    while (_ops.isNotEmpty) {
      final op = _ops.first;
      await _apply(op);
      _ops.remove(op);
    }
    if (_metaDirty) {
      _metaDirty = false;
      await store.writeMeta(Uint8List.fromList(utf8.encode(jsonEncode(_modified))));
    }
  }

  Future<void> _apply(_Op op) async {
    switch (op) {
      case _Write(:final path):
        final target = delegate.file(path);
        if (!target.existsSync() || _lazy.containsKey(path)) return;
        final version = _versions[path];
        final bytes = target.readAsBytesSync();
        await store.write(path, bytes);
        if (_versions[path] == version) _wal?.remove(path);
        // крупное, уже лежащее в хранилище, из памяти уходит
        if (bytes.length > lazyFrom && !_text(path) && _versions[path] == version) {
          final time = target.lastModifiedSync();
          target.writeAsBytesSync(const []);
          target.setLastModifiedSync(time);
          _lazy[path] = bytes.length;
        }
      case _Move(:final from, :final to):
        final version = _versions[to];
        try {
          await store.move(from, to);
        } on Object {
          // в хранилище файла уже нет (перенесли раньше): если он в памяти целиком — записать
          if (delegate.file(to).existsSync() && !_lazy.containsKey(to)) await store.write(to, delegate.file(to).readAsBytesSync());
        }
        if (_versions[to] == version) _wal?.remove(to);
        // содержимое теперь лежит на новом месте
        for (final key in [..._storedAt.keys]) {
          if (_storedAt[key] == from) _storedAt[key] = to;
          if (_storedAt[key] == key) _storedAt.remove(key);
        }
      case _Delete(:final path):
        final version = _versions[path];
        await store.delete(path);
        if (_versions[path] == version) _wal?.remove(path);
      case _Mkdir(:final path):
        if (delegate.directory(path).existsSync()) await store.mkdir(path);
    }
  }
}

sealed class _Op {}

final class _Write extends _Op {
  _Write(this.path);
  final String path;
}

final class _Move extends _Op {
  _Move(this.from, this.to);
  final String from;
  final String to;
}

final class _Delete extends _Op {
  _Delete(this.path);
  final String path;
}

final class _Mkdir extends _Op {
  _Mkdir(this.path);
  final String path;
}

/// Сведения о крупном файле: размер — настоящий, а не пустой заглушки в памяти.
class _SizedStat implements io.FileStat {
  _SizedStat(this._base, this.size);

  final io.FileStat _base;

  @override
  final int size;

  @override
  DateTime get accessed => _base.accessed;

  @override
  DateTime get changed => _base.changed;

  @override
  DateTime get modified => _base.modified;

  @override
  int get mode => _base.mode;

  @override
  io.FileSystemEntityType get type => _base.type;

  @override
  String modeString() => _base.modeString();
}

abstract class _WebEntity<T extends FileSystemEntity, D extends io.FileSystemEntity> extends ForwardingFileSystemEntity<T, D> {
  _WebEntity(this.fileSystem, this.delegate);

  @override
  final WebFileSystem fileSystem;

  @override
  final D delegate;

  @override
  Directory wrapDirectory(io.Directory delegate) => _WebDirectory(fileSystem, delegate);

  @override
  File wrapFile(io.File delegate) => _WebFile(fileSystem, delegate);

  @override
  Link wrapLink(io.Link delegate) => throw UnsupportedError('Ссылок в браузере нет');
}

class _WebFile extends _WebEntity<File, io.File> with ForwardingFile {
  _WebFile(super.fileSystem, super.delegate);

  bool get _lazy => fileSystem.isLazy(path);

  // ——— запись ———

  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) async {
    final existed = delegate.existsSync();
    final made = await super.create(recursive: recursive, exclusive: exclusive);
    if (!existed) fileSystem.changed(path);
    return made;
  }

  @override
  void createSync({bool recursive = false, bool exclusive = false}) {
    final existed = delegate.existsSync();
    super.createSync(recursive: recursive, exclusive: exclusive);
    if (!existed) fileSystem.changed(path);
  }

  @override
  Future<File> writeAsBytes(List<int> bytes, {io.FileMode mode = io.FileMode.write, bool flush = false}) async {
    final written = await super.writeAsBytes(bytes, mode: _appendLoaded(mode), flush: flush);
    fileSystem.changed(path);
    return written;
  }

  @override
  void writeAsBytesSync(List<int> bytes, {io.FileMode mode = io.FileMode.write, bool flush = false}) {
    super.writeAsBytesSync(bytes, mode: _appendLoaded(mode), flush: flush);
    fileSystem.changed(path);
  }

  @override
  Future<File> writeAsString(String contents, {io.FileMode mode = io.FileMode.write, Encoding encoding = utf8, bool flush = false}) async {
    final written = await super.writeAsString(contents, mode: _appendLoaded(mode), encoding: encoding, flush: flush);
    fileSystem.changed(path);
    return written;
  }

  @override
  void writeAsStringSync(String contents, {io.FileMode mode = io.FileMode.write, Encoding encoding = utf8, bool flush = false}) {
    super.writeAsStringSync(contents, mode: _appendLoaded(mode), encoding: encoding, flush: flush);
    fileSystem.changed(path);
  }

  // дописать в крупный файл, которого нет в памяти, нельзя: потерялось бы начало
  io.FileMode _appendLoaded(io.FileMode mode) {
    if (_lazy && (mode == io.FileMode.append || mode == io.FileMode.writeOnlyAppend)) fileSystem.notLoaded(path);
    return mode;
  }

  @override
  io.IOSink openWrite({io.FileMode mode = io.FileMode.write, Encoding encoding = utf8}) {
    _appendLoaded(mode);
    return _WatchedSink(super.openWrite(mode: mode, encoding: encoding), () => fileSystem.changed(path));
  }

  @override
  Future<io.RandomAccessFile> open({io.FileMode mode = io.FileMode.read}) async {
    if (_lazy) {
      if (mode != io.FileMode.read) fileSystem.notLoaded(path);
      // крупный файл читается через временную копию в памяти: она живёт, пока файл открыт
      final folder = fileSystem.memory.systemTempDirectory.createTempSync('lazy');
      final scratch = folder.childFile('file')..writeAsBytesSync(await fileSystem.readLazy(path));
      return _ClosingFile(await scratch.open(), () => folder.deleteSync(recursive: true));
    }
    final opened = await super.open(mode: mode);
    return mode == io.FileMode.read ? opened : _ClosingFile(opened, () => fileSystem.changed(path));
  }

  @override
  io.RandomAccessFile openSync({io.FileMode mode = io.FileMode.read}) {
    if (_lazy) fileSystem.notLoaded(path);
    final opened = super.openSync(mode: mode);
    return mode == io.FileMode.read ? opened : _ClosingFile(opened, () => fileSystem.changed(path));
  }

  @override
  Future<dynamic> setLastModified(DateTime time) async {
    await super.setLastModified(time);
    fileSystem.touched(path);
  }

  @override
  void setLastModifiedSync(DateTime time) {
    super.setLastModifiedSync(time);
    fileSystem.touched(path);
  }

  @override
  Future<File> rename(String newPath) async => renameSync(newPath);

  @override
  File renameSync(String newPath) {
    final from = path;
    final moved = super.renameSync(newPath);
    fileSystem.moved(from, moved.path);
    return moved;
  }

  @override
  Future<File> copy(String newPath) async {
    if (!_lazy) return copySync(newPath);
    final target = fileSystem.file(newPath);
    await target.writeAsBytes(await fileSystem.readLazy(path));
    return target;
  }

  @override
  File copySync(String newPath) {
    if (_lazy) fileSystem.notLoaded(path);
    final copied = super.copySync(newPath);
    fileSystem.changed(copied.path);
    return copied;
  }

  @override
  Future<File> delete({bool recursive = false}) async {
    deleteSync(recursive: recursive);
    return this;
  }

  @override
  void deleteSync({bool recursive = false}) {
    super.deleteSync(recursive: recursive);
    fileSystem.deleted(path);
  }

  // ——— чтение ———

  @override
  Future<int> length() async => lengthSync();

  @override
  int lengthSync() => fileSystem._lazy[fileSystem.normalize(path)] ?? super.lengthSync();

  @override
  Future<io.FileStat> stat() => fileSystem.stat(path);

  @override
  io.FileStat statSync() => fileSystem.statSync(path);

  @override
  Future<Uint8List> readAsBytes() => _lazy ? fileSystem.readLazy(path) : super.readAsBytes();

  @override
  Uint8List readAsBytesSync() => _lazy ? fileSystem.notLoaded(path) : super.readAsBytesSync();

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async => _lazy ? encoding.decode(await fileSystem.readLazy(path)) : super.readAsString(encoding: encoding);

  @override
  String readAsStringSync({Encoding encoding = utf8}) => _lazy ? fileSystem.notLoaded(path) : super.readAsStringSync(encoding: encoding);

  @override
  Future<List<String>> readAsLines({Encoding encoding = utf8}) async => const LineSplitter().convert(await readAsString(encoding: encoding));

  @override
  List<String> readAsLinesSync({Encoding encoding = utf8}) => _lazy ? fileSystem.notLoaded(path) : super.readAsLinesSync(encoding: encoding);

  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    if (!_lazy) return super.openRead(start, end);
    return Stream.fromFuture(fileSystem.readLazy(path).then((bytes) => bytes.sublist(start ?? 0, end ?? bytes.length)));
  }
}

class _WebDirectory extends _WebEntity<Directory, io.Directory> with ForwardingDirectory<Directory> {
  _WebDirectory(super.fileSystem, super.delegate);

  @override
  Directory childDirectory(String basename) => fileSystem.directory(fileSystem.path.join(path, basename));

  @override
  File childFile(String basename) => fileSystem.file(fileSystem.path.join(path, basename));

  @override
  Link childLink(String basename) => throw UnsupportedError('Ссылок в браузере нет');

  @override
  Future<Directory> create({bool recursive = false}) async {
    createSync(recursive: recursive);
    return this;
  }

  @override
  void createSync({bool recursive = false}) {
    // недостающие родители тоже новые: каждая папка уходит в хранилище
    final missing = <String>[];
    for (var dir = delegate; !dir.existsSync() && dir.path != dir.parent.path; dir = dir.parent) {
      missing.add(dir.path);
      if (!recursive) break;
    }
    super.createSync(recursive: recursive);
    for (final path in missing.reversed) {
      fileSystem.created(path);
    }
  }

  @override
  Future<Directory> rename(String newPath) async => renameSync(newPath);

  @override
  Directory renameSync(String newPath) {
    final from = fileSystem.normalize(path);
    final files = fileSystem.filesUnder(from);
    final moved = super.renameSync(newPath);
    fileSystem.movedDirectory(from, moved.path, files);
    return moved;
  }

  @override
  Future<Directory> delete({bool recursive = false}) async {
    deleteSync(recursive: recursive);
    return this;
  }

  @override
  void deleteSync({bool recursive = false}) {
    super.deleteSync(recursive: recursive);
    fileSystem.deleted(path);
  }
}

/// Поток записи: файл считается записанным, когда поток закрыт.
class _WatchedSink implements io.IOSink {
  _WatchedSink(this._inner, this._closed);

  final io.IOSink _inner;
  final void Function() _closed;

  @override
  Encoding get encoding => _inner.encoding;

  @override
  set encoding(Encoding value) => _inner.encoding = value;

  @override
  void add(List<int> data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) => _inner.addStream(stream);

  @override
  Future<void> close() async {
    await _inner.close();
    _closed();
  }

  @override
  Future<void> get done => _inner.done;

  @override
  Future<void> flush() => _inner.flush();

  @override
  void write(Object? object) => _inner.write(object);

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) => _inner.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _inner.writeCharCode(charCode);

  @override
  void writeln([Object? object = '']) => _inner.writeln(object);
}

/// Открытый файл: по закрытии — [_closed] (записать в хранилище или стереть временную копию).
class _ClosingFile with ForwardingRandomAccessFile {
  _ClosingFile(this.delegate, this._closed);

  @override
  final io.RandomAccessFile delegate;

  final void Function() _closed;

  @override
  Future<void> close() async {
    await delegate.close();
    _closed();
  }

  @override
  void closeSync() {
    delegate.closeSync();
    _closed();
  }
}

/// Подмена `File`, `Directory` и сведений о файлах `dart:io` на [WebFileSystem].
/// Ставится в браузере через `IOOverrides.global` до первого обращения к файлам.
final class WebIOOverrides extends io.IOOverrides {
  WebIOOverrides(this.fs);

  final WebFileSystem fs;

  @override
  io.File createFile(String path) => fs.file(path);

  @override
  io.Directory createDirectory(String path) => fs.directory(path);

  @override
  io.Directory getSystemTempDirectory() => fs.systemTempDirectory;

  @override
  io.Directory getCurrentDirectory() => fs.currentDirectory;

  @override
  Future<io.FileSystemEntityType> fseGetType(String path, bool followLinks) => fs.type(path, followLinks: followLinks);

  @override
  io.FileSystemEntityType fseGetTypeSync(String path, bool followLinks) => fs.typeSync(path, followLinks: followLinks);

  @override
  Future<io.FileStat> stat(String path) => fs.stat(path);

  @override
  io.FileStat statSync(String path) => fs.statSync(path);

  @override
  bool fsWatchIsSupported() => false;
}
