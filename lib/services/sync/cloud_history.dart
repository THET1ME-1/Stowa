/// История версий в облаке: ревизии файлов со всех устройств. Сервер отдаёт зашифрованные
/// заголовки и номера частей, а имена, время правки и связь переездов знает только телефон:
/// он открывает заголовки сам.
library;

import 'dart:convert';

import 'sync_crypto.dart';
import 'sync_engine.dart' show syncable;
import 'sync_ports.dart';

/// Версия файла: открытый заголовок одной ревизии.
class CloudVersion {
  const CloudVersion({
    required this.file,
    required this.path,
    required this.rev,
    required this.at,
    required this.sentAt,
    required this.size,
    required this.hash,
    required this.blobs,
    this.device,
    this.deleted = false,
  });

  /// Номер файла на сервере (от пути).
  final String file;

  /// Путь в хранилище, каким он был у этой версии.
  final String path;
  final int rev;

  /// Когда файл так поправили — время правки на устройстве.
  final DateTime at;

  /// Когда ревизию отправили — время сервера.
  final DateTime sentAt;

  /// С какого устройства; у ревизий до истории версий — неизвестно.
  final String? device;
  final int size;

  /// sha256 открытого содержимого: одинаковое содержимое у разных ревизий узнаётся по нему.
  final String hash;
  final List<String> blobs;
  final bool deleted;
}

/// Сеанс правки: подряд идущие версии одного устройства без долгих перерывов.
class VersionSession {
  const VersionSession(this.versions);

  /// Новые первыми.
  final List<CloudVersion> versions;

  /// Чем сеанс кончился.
  CloudVersion get last => versions.first;
  DateTime get from => versions.last.at;
  DateTime get to => versions.first.at;
}

/// Версии ([versions] новые первыми) — в сеансы: то же устройство и перерыв меньше [gap].
List<VersionSession> sessionsOf(List<CloudVersion> versions, {Duration gap = const Duration(minutes: 10)}) {
  final sessions = <List<CloudVersion>>[];
  for (final version in versions) {
    final open = sessions.isEmpty ? null : sessions.last;
    if (open != null && open.last.device == version.device && open.last.at.difference(version.at) < gap) {
      open.add(version);
    } else {
      sessions.add([version]);
    }
  }
  return [for (final group in sessions) VersionSession(group)];
}

/// Удалённый файл, который можно вернуть: его последняя живая версия.
class DeletedFile {
  const DeletedFile({required this.last, required this.deletedAt, required this.tomb, this.device, this.attachments = const []});

  final CloudVersion last;
  final DateTime deletedAt;

  /// Номер файла надгробия: по нему стирается история навсегда.
  final String tomb;

  /// С какого устройства удалили.
  final String? device;

  /// Удалённые вместе с заметкой вложения из её папки: возвращаются вместе с ней.
  final List<DeletedFile> attachments;

  /// Где файл лежал до удаления. Стёртое из корзины лежало в `.trash/` — показывается и
  /// возвращается на прежнее место.
  String get path => last.path.startsWith(_trash) ? last.path.substring(_trash.length) : last.path;
}

/// Корзина хранилища (`trashFolder`): удалённое в Stowa лежит там, пока корзину не очистят.
const _trash = '.trash/';

/// Папка вложений заметки — та же, что у раскладки хранилища (`attachmentsDir`).
String _attachmentsOf(String notePath) => notePath.endsWith('.md') ? notePath.substring(0, notePath.length - 3) : notePath;

/// Строка журнала правок: что и откуда поменялось. Содержимого в ней нет.
class LogEntry {
  const LogEntry(this.version);

  final CloudVersion version;
}

/// Видит ли человек этот путь в списках: служебное Stowa и Obsidian живёт само по себе.
bool shownInHistory(String path) => syncable(path) && !path.startsWith('.stowa/') && !path.startsWith('.obsidian/') && !path.startsWith('.trash/');

/// Сколько переездов подряд обходит история: защита от петли и от бесконечного хвоста.
const _maxHops = 30;

class CloudHistory {
  CloudHistory({required this.remote, required this.key, this.cacheBytes = 32 * 1024 * 1024});

  final SyncRemote remote;
  final VaultKey key;

  /// Сколько расшифрованного держать в памяти. На диск старое не кладётся: хранилище — папка
  /// человека, и открытый старый текст лёг бы туда, где его видят Obsidian и проводник.
  final int cacheBytes;

  final _cache = <String, List<int>>{};
  var _cached = 0;

  /// Открыть заголовок ревизии; битый — null (версия просто не показывается).
  Future<({FileMeta meta, CloudVersion version})?> _open(RemoteRevision revision) async {
    try {
      final meta = await key.openMeta(revision.meta);
      return (
        meta: meta,
        version: CloudVersion(
          file: revision.file,
          path: meta.path,
          rev: revision.rev,
          at: DateTime.fromMillisecondsSinceEpoch(meta.mtime),
          sentAt: revision.at,
          device: revision.device,
          size: revision.size,
          hash: meta.hash,
          blobs: revision.blobs,
          deleted: revision.deleted,
        ),
      );
    } on SyncSealBroken {
      return null;
    }
  }

  /// Версии файла по пути [path], новые первыми, через все его переезды. Надгробий в списке
  /// нет. Не больше [limit] версий.
  Future<List<CloudVersion>> versions(String path, {int limit = 1000}) async {
    final out = <CloudVersion>[];
    final seen = <(String, int)>{};
    String? file = key.fileId(path);
    // ревизии прежнего пути — только старше переезда: у пути могла быть и жизнь после
    DateTime? before;
    for (var hop = 0; file != null && hop < _maxHops && out.length < limit; hop++) {
      final current = file;
      String? next;
      DateTime? nextBefore;
      int? page;
      scan:
      while (out.length < limit) {
        final batch = await remote.revisions(current, before: page, limit: 200);
        for (final revision in batch.revisions) {
          page = revision.rev;
          if (!seen.add((current, revision.rev))) continue;
          if (before != null && revision.at.isAfter(before)) continue;
          final opened = await _open(revision);
          if (opened == null || revision.deleted) continue;
          out.add(opened.version);
          if (out.length >= limit) break scan;
          // начало жизни на этом пути: дальше назад — прежний путь
          if (opened.meta.prev case final prev?) {
            next = prev;
            nextBefore = revision.at;
            break scan;
          }
        }
        if (!batch.more) break;
      }
      file = next;
      before = nextBefore;
    }
    return out;
  }

  /// Содержимое версии целиком. Второй раз — из памяти.
  Future<List<int>> content(CloudVersion version) async {
    if (_cache.remove(version.hash) case final hit?) {
      // свежее — в конец: вытесняется самое давнее
      _cache[version.hash] = hit;
      return hit;
    }
    final out = <int>[];
    await for (final part in parts(version)) {
      out.addAll(part);
    }
    if (out.length <= cacheBytes ~/ 4) {
      _cache[version.hash] = out;
      _cached += out.length;
      while (_cached > cacheBytes && _cache.isNotEmpty) {
        final oldest = _cache.keys.first;
        _cached -= _cache.remove(oldest)!.length;
      }
    }
    return out;
  }

  /// Содержимое по частям: большой файл возвращается на место, не собираясь в памяти.
  Stream<List<int>> parts(CloudVersion version) async* {
    for (final blob in version.blobs) {
      yield await key.openChunk(await remote.getBlob(blob));
    }
  }

  Future<String> text(CloudVersion version) async => utf8.decode(await content(version), allowMalformed: true);

  /// Удалённое, что можно вернуть, свежее первым. Переезды удалением не считаются (в корзину
  /// Stowa заметка переезжает, и её там видно), служебное не показывается. Вложения из папки
  /// удалённой заметки идут вместе с ней, отдельными строками их нет.
  Future<List<DeletedFile>> deleted() async {
    final all = <DeletedFile>[];
    String? after;
    do {
      final page = await remote.deleted(after: after, limit: 200);
      for (final one in page.files) {
        final tomb = await _open(one.tomb);
        final last = await _open(one.last);
        if (tomb == null || last == null || tomb.meta.to != null) continue;
        final path = last.meta.path;
        if (!syncable(path) || path.startsWith('.stowa/') || path.startsWith('.obsidian/')) continue;
        all.add(DeletedFile(last: last.version, deletedAt: tomb.version.at, tomb: one.tomb.file, device: one.tomb.device));
      }
      after = page.next;
    } while (after != null);
    final notes = {for (final file in all) if (file.path.toLowerCase().endsWith('.md')) '${_attachmentsOf(file.path)}/': file};
    final attached = <DeletedFile, List<DeletedFile>>{};
    final out = <DeletedFile>[];
    for (final file in all) {
      final owner = notes.entries.where((note) => note.value != file && file.path.startsWith(note.key)).firstOrNull?.value;
      if (owner != null) {
        attached.putIfAbsent(owner, () => []).add(file);
      } else {
        out.add(file);
      }
    }
    return [
      for (final file in out) DeletedFile(last: file.last, deletedAt: file.deletedAt, tomb: file.tomb, device: file.device, attachments: attached[file] ?? const []),
    ];
  }

  /// Журнал правок хранилища, свежее первым: страница и курсор следующей.
  Future<(List<LogEntry>, String?)> log({String? after, int limit = 200}) async {
    final page = await remote.log(after: after, limit: limit);
    final out = <LogEntry>[];
    for (final revision in page.entries) {
      final opened = await _open(revision);
      if (opened == null || !shownInHistory(opened.meta.path)) continue;
      // переезд — одна строка, у нового пути: надгробие прежнего не показываем
      if (opened.meta.to != null) continue;
      out.add(LogEntry(opened.version));
    }
    return (out, page.next);
  }

  /// Стереть навсегда удалённый файл: историю его пути и всех прежних путей, если на них
  /// сейчас тоже ничего не живёт. Живой файл, занявший прежний путь, не трогается.
  Future<void> purge(DeletedFile file) async {
    final ids = <String>{file.tomb, for (final attachment in file.attachments) attachment.tomb};
    for (final version in await versions(file.last.path)) {
      ids.add(version.file);
    }
    for (final id in ids) {
      final now = await remote.file(id);
      if (now == null || now.deleted) await remote.purgeHistory(id);
    }
    _cache.clear();
    _cached = 0;
  }
}
