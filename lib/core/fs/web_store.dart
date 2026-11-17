import 'dart:typed_data';

/// Что лежит в хранилище браузера: файл или папка, размер и время записи.
class StoredEntry {
  const StoredEntry(this.path, {required this.directory, this.size = 0, this.modified});

  /// Путь от корня, с косой в начале: `/vault/Идеи.md`.
  final String path;
  final bool directory;
  final int size;
  final DateTime? modified;
}

/// Долгое хранилище файлов браузера (личная папка сайта, потом папка на компьютере).
/// Всё асинхронно: браузер не умеет иначе. Пути — с косой в начале.
abstract class WebStore {
  Future<List<StoredEntry>> list();

  Future<Uint8List> read(String path);

  /// Записать файл целиком; недостающие папки создаются.
  Future<void> write(String path, Uint8List bytes);

  /// Перенести файл без чтения в память.
  Future<void> move(String from, String to);

  /// Удалить файл или папку со всем содержимым; нет — не ошибка.
  Future<void> delete(String path);

  Future<void> mkdir(String path);

  /// Служебная запись файловой системы (время правки файлов): хранилище браузера
  /// время ставит само, а синхронизация сверяет по нему.
  Future<Uint8List?> readMeta();

  Future<void> writeMeta(Uint8List bytes);
}

/// Журнал правок, ещё не дошедших до хранилища. Пишется сразу и синхронно
/// (localStorage): закрытая сразу после правки вкладка её не теряет.
abstract class WebWal {
  /// Путь → содержимое; null — файл удалён.
  Map<String, Uint8List?> load();

  /// false — места нет, правка уйдёт только в хранилище.
  bool put(String path, Uint8List? bytes);

  void remove(String path);
}

/// Хранилище в памяти: тесты и запасной случай, когда браузер не дал папку.
class MemoryWebStore implements WebStore {
  final _files = <String, Uint8List>{};
  final _modified = <String, DateTime>{};
  final _directories = <String>{};
  Uint8List? _meta;

  Iterable<String> get paths => [..._directories, ..._files.keys];

  @override
  Future<List<StoredEntry>> list() async => [
    for (final path in _directories) StoredEntry(path, directory: true),
    for (final MapEntry(:key, :value) in _files.entries) StoredEntry(key, directory: false, size: value.length, modified: _modified[key]),
  ];

  @override
  Future<Uint8List> read(String path) async {
    final found = _files[path];
    if (found == null) throw StateError('нет файла $path');
    return Uint8List.fromList(found);
  }

  void _parents(String path) {
    var parent = path.substring(0, path.lastIndexOf('/'));
    while (parent.isNotEmpty) {
      _directories.add(parent);
      parent = parent.substring(0, parent.lastIndexOf('/'));
    }
  }

  @override
  Future<void> write(String path, Uint8List bytes) async {
    _parents(path);
    _files[path] = Uint8List.fromList(bytes);
    _modified[path] = DateTime.now();
  }

  @override
  Future<void> move(String from, String to) async {
    final found = _files.remove(from);
    if (found == null) throw StateError('нет файла $from');
    _modified.remove(from);
    await write(to, found);
  }

  @override
  Future<void> delete(String path) async {
    bool inside(String other) => other == path || other.startsWith('$path/');
    _files.removeWhere((key, _) => inside(key));
    _modified.removeWhere((key, _) => inside(key));
    _directories.removeWhere(inside);
  }

  @override
  Future<void> mkdir(String path) async {
    _parents('$path/x');
  }

  @override
  Future<Uint8List?> readMeta() async => _meta;

  @override
  Future<void> writeMeta(Uint8List bytes) async => _meta = Uint8List.fromList(bytes);
}

/// Журнал в памяти для тестов: переживает «закрытие вкладки», пока жив объект.
class MemoryWebWal implements WebWal {
  final entries = <String, Uint8List?>{};

  @override
  Map<String, Uint8List?> load() => Map.of(entries);

  @override
  bool put(String path, Uint8List? bytes) {
    // в конец: порядок журнала — порядок правок
    entries.remove(path);
    entries[path] = bytes == null ? null : Uint8List.fromList(bytes);
    return true;
  }

  @override
  void remove(String path) => entries.remove(path);
}
