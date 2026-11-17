/// Порты движка синхронизации: диск, сервер, память о синхронизированном.
/// Движок не знает ни Flutter, ни drift, ни http: один и тот же код работает
/// в приложении, в фоне и в симуляции с поддельным сервером.
library;

/// Файл хранилища на диске. Путь — от корня, через «/».
class LocalFile {
  const LocalFile(this.path, {required this.size, required this.mtime});

  final String path;
  final int size;

  /// Время правки, мс.
  final int mtime;
}

abstract interface class SyncFiles {
  /// Все файлы хранилища. Не удалось обойти папку — бросает: без полного списка
  /// пропавший файл не отличить от непрочитанного, и удаления не отправляются.
  Future<List<LocalFile>> list();

  Future<LocalFile?> stat(String path);

  Future<List<int>> read(String path, int offset, int length);

  /// Записать содержимое во временный файл рядом с [path]; отдаёт его путь.
  Future<String> stage(String path, Stream<List<int>> data);

  /// Поставить временный файл на место [path], если там всё тот же файл, что [expect]
  /// (null — файла не было). Иначе временный удаляется и ответ false: файл поправили,
  /// пока качали, — затирать нельзя.
  Future<bool> place(String staged, String path, {LocalFile? expect});

  /// Удалить [path], если там всё тот же файл, что [expect]. Иначе false.
  Future<bool> delete(String path, {required LocalFile expect});
}

/// Тот же файл: оба нет или совпали размер и время.
bool sameFile(LocalFile? a, LocalFile? b) => a == null || b == null ? a == b : a.size == b.size && a.mtime == b.mtime;

/// Изменение на сервере: текущая ревизия файла.
class RemoteChange {
  const RemoteChange({required this.file, required this.rev, required this.meta, required this.blobs, required this.size, this.deleted = false});

  final String file;
  final int rev;
  final bool deleted;

  /// Зашифрованный заголовок.
  final String meta;
  final List<String> blobs;
  final int size;
}

class ChangePage {
  const ChangePage({required this.cursor, required this.changes, this.more = false});

  final int cursor;
  final bool more;
  final List<RemoteChange> changes;
}

sealed class CommitResult {
  const CommitResult();
}

class Committed extends CommitResult {
  const Committed(this.rev);

  final int rev;
}

/// На сервере уже другая ревизия: сперва забрать её и склеить.
class Conflict extends CommitResult {
  const Conflict(this.rev);

  final int rev;
}

abstract interface class SyncRemote {
  /// Изменения после курсора [since]; [wait] — сколько сервер ждёт нового, если пусто.
  Future<ChangePage> changes(int since, {int wait = 0});

  Future<bool> hasBlob(String hash);

  Future<void> putBlob(String hash, List<int> data);

  Future<List<int>> getBlob(String hash);

  Future<CommitResult> commit(String file, {required int baseRev, required String meta, required List<String> blobs, required int size, bool deleted = false});

  /// Текущая ревизия одного файла: после отказа по ревизии, когда курсор её уже прошёл.
  Future<RemoteChange?> file(String file);
}

/// Что телефон помнит о файле после последней синхронизации.
class SyncedFile {
  const SyncedFile({required this.file, required this.path, required this.rev, required this.hash, required this.size, required this.mtime});

  final String file;
  final String path;

  /// Ревизия на сервере, с которой совпадает [hash].
  final int rev;

  /// Отпечаток содержимого этой ревизии; пустой — на сервере файл удалён, а у нас остался.
  final String hash;

  /// Размер и время файла на диске, когда он совпадал с ревизией: быстрая проверка без чтения.
  final int size;
  final int mtime;
}

abstract interface class SyncState {
  Future<int> cursor();

  Future<void> setCursor(int cursor);

  Future<Map<String, SyncedFile>> files();

  Future<void> put(SyncedFile file);

  Future<void> remove(String file);

  /// Отложенные файлы: изменение пришло, а часть не скачалась. Курсор ушёл дальше,
  /// файл дочитывается по одному в следующих проходах.
  Future<Set<String>> pending();

  Future<void> setPending(String file, bool waiting);

  /// Тень: текст последней синхронизированной версии для склейки по трём версиям.
  Future<String?> shadow(String file);

  Future<void> setShadow(String file, String? text);
}
