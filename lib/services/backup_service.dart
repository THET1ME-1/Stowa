import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../data/db/database.dart';
import '../data/db/raw_open.dart' if (dart.library.js_interop) '../data/db/raw_open_web.dart';
import 'zip_stream.dart';

/// Папки с файлами вещей, обложками ссылок и картинками тегов.
const _fileFolders = ['attachments', 'covers', 'tags', '.stowa/covers', '.stowa/tag-icons', '.stowa/incoming'];

/// Журнал запросов к ИИ в копию не идёт: он для отладки и пухнет.
const _skipTables = {'ai_log'};

enum BackupProblem { notStowa, tooNew }

/// Архив не похож на копию Stowa или сделан более новой версией приложения.
class BackupError implements Exception {
  const BackupError(this.problem);

  final BackupProblem problem;

  @override
  String toString() => 'BackupError: ${problem.name}';
}

/// Что лежит в копии: для вопроса «заменить всё?» перед восстановлением.
class BackupInfo {
  const BackupInfo({required this.createdAt, required this.schema, required this.items, this.hasDatabase = true});

  final DateTime createdAt;
  final int schema;
  final int items;

  /// В копии есть снимок базы. Нет — копию делал браузер (или её восстановили без базы):
  /// в хранилище встали только файлы, и указатель надо пересобрать из них.
  final bool hasDatabase;
}

/// Резервная копия всей Stowa одним zip: снимок базы и файлы. Ключа ИИ и настроек
/// в ней нет — они живут не в базе.
class BackupService {
  BackupService(this._db, {required Directory filesRoot, bool vault = false, required DateTime Function() clock})
    : _filesRoot = filesRoot, // ignore: prefer_initializing_formals
      _vault = vault, // ignore: prefer_initializing_formals
      _clock = clock; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final Directory _filesRoot;

  /// [_filesRoot] — хранилище: в копию идёт оно целиком. Иначе старая установка:
  /// в папке приложения лежит и чужое, берутся только папки файлов.
  final bool _vault;
  final DateTime Function() _clock;

  // копии страниц можно скачать заново, временные файлы — недописанное
  static bool _skipped(String relative) =>
      relative.startsWith('.stowa/pages/') || relative.startsWith('.stowa/cache/') || (p.posix.basename(relative).startsWith('.') && relative.endsWith('.tmp'));

  /// Файлы, которые идут в копию, путями от корня.
  List<File> _files() {
    if (_vault) {
      if (!_filesRoot.existsSync()) return const [];
      return [
        for (final file in _filesRoot.listSync(recursive: true, followLinks: false).whereType<File>())
          if (!_skipped(_relative(file))) file,
      ];
    }
    return [
      for (final name in _fileFolders)
        if (Directory(p.join(_filesRoot.path, name)).existsSync()) ...Directory(p.join(_filesRoot.path, name)).listSync(recursive: true).whereType<File>(),
    ];
  }

  String _relative(File file) => p.relative(file.path, from: _filesRoot.path).replaceAll(r'\', '/');

  /// Собрать копию в [folder]. Имя с датой: «Stowa-2026-11-03.zip».
  Future<File> export(Directory folder) async {
    final now = _clock();
    final work = await Directory.systemTemp.createTemp('stowa_export');
    try {
      // VACUUM INTO даёт целый снимок без журнала, даже пока база открыта
      final snapshot = p.join(work.path, 'stowa.sqlite');
      await _db.customStatement('VACUUM INTO ?', [snapshot]);
      final items = await _db.items.count(where: (t) => t.deletedAt.isNull()).getSingle();
      final manifest = File(p.join(work.path, 'manifest.json'))
        ..writeAsStringSync(jsonEncode({'app': 'stowa', 'schema': _db.schemaVersion, 'createdAt': now.toIso8601String(), 'items': items}));

      final zip = File(p.join(folder.path, 'Stowa-${now.toIso8601String().substring(0, 10)}.zip'));
      final encoder = ZipFileEncoder()..create(zip.path);
      await encoder.addFile(manifest, 'manifest.json');
      await encoder.addFile(File(snapshot), 'stowa.sqlite');
      for (final file in _files()) {
        await encoder.addFile(file, 'files/${_relative(file)}');
      }
      await encoder.close();
      return zip;
    } finally {
      await work.delete(recursive: true);
    }
  }

  /// Копия без снимка базы, куском за куском в [zip]: опись и файлы хранилища. Так копию
  /// делает браузер: снимок базы там не снять, а целиком в памяти вкладки архив не удержать.
  /// Заметки лежат файлами, поэтому в файлах есть всё: телефон восстановит указатель из них.
  /// Архив закрывается здесь же.
  Future<void> exportFiles(ZipStreamWriter zip) async {
    final now = _clock();
    final items = await _db.items.count(where: (t) => t.deletedAt.isNull()).getSingle();
    await zip.add(
      'manifest.json',
      utf8.encode(jsonEncode({'app': 'stowa', 'schema': _db.schemaVersion, 'createdAt': now.toIso8601String(), 'items': items, 'database': false})),
      modified: now,
    );
    for (final file in _files()) {
      await zip.add('files/${_relative(file)}', await file.readAsBytes(), modified: now);
    }
    await zip.close();
  }

  /// Имена внутри архива.
  static List<String> entries(File zip) {
    final input = InputFileStream(zip.path);
    try {
      return [for (final file in ZipDecoder().decodeStream(input)) file.name];
    } finally {
      input.closeSync();
    }
  }

  /// Прочитать опись копии. Чужой архив — [BackupError].
  static Future<BackupInfo> inspect(File zip) async {
    final Archive archive;
    final input = InputFileStream(zip.path);
    try {
      try {
        archive = ZipDecoder().decodeStream(input);
      } catch (_) {
        throw const BackupError(BackupProblem.notStowa);
      }
      return _describe(archive);
    } finally {
      input.closeSync();
    }
  }

  /// [inspect] для архива из памяти: так его отдаёт браузер.
  static BackupInfo inspectBytes(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const BackupError(BackupProblem.notStowa);
    }
    return _describe(archive);
  }

  // опись копии; снимка базы может не быть — тогда копия из браузера
  static BackupInfo _describe(Archive archive) {
    final manifest = archive.findFile('manifest.json');
    if (manifest == null) throw const BackupError(BackupProblem.notStowa);
    final Map<String, Object?> json;
    try {
      json = jsonDecode(utf8.decode(manifest.content)) as Map<String, Object?>;
    } catch (_) {
      throw const BackupError(BackupProblem.notStowa);
    }
    if (json['app'] != 'stowa') throw const BackupError(BackupProblem.notStowa);
    final hasDatabase = archive.findFile('stowa.sqlite') != null;
    // копия без базы должна сама об этом говорить: иначе это обрезанный архив
    if (!hasDatabase && json['database'] != false) throw const BackupError(BackupProblem.notStowa);
    return BackupInfo(createdAt: DateTime.parse(json['createdAt']! as String), schema: json['schema']! as int, items: json['items']! as int, hasDatabase: hasDatabase);
  }

  /// Файлы копии встают в хранилище поверх, свои файлы хранилища остаются. Имя с путём
  /// наружу («..», от корня) не пишется: архив мог прийти откуда угодно.
  Future<void> _restoreFiles(Archive archive, {Future<void> Function()? onFile}) async {
    for (final file in archive.files) {
      await onFile?.call();
      if (!file.isFile || !file.name.startsWith('files/')) continue;
      final relative = file.name.substring('files/'.length);
      final parts = relative.split('/');
      if (relative.isEmpty || relative.startsWith('/') || parts.any((part) => part == '..' || part.isEmpty)) continue;
      final target = File(p.joinAll([_filesRoot.path, ...parts]));
      await target.parent.create(recursive: true);
      await target.writeAsBytes(file.content);
    }
  }

  /// Восстановить из архива в памяти: так его отдаёт браузер. Берутся только файлы, даже
  /// если копию делал телефон и в ней есть снимок базы: открыть его браузер не может.
  /// Указатель после этого пересобирают из файлов ([BackupInfo.hasDatabase] — false).
  ///
  /// [onFile] зовётся перед каждым файлом: по нему вызывающий держит сверку хранилища
  /// стоящей, пока запись идёт.
  Future<BackupInfo> restoreBytes(Uint8List bytes, {Future<void> Function()? onFile}) async {
    final info = inspectBytes(bytes);
    if (info.schema > _db.schemaVersion) throw const BackupError(BackupProblem.tooNew);
    await _restoreFiles(ZipDecoder().decodeBytes(bytes), onFile: onFile);
    return BackupInfo(createdAt: info.createdAt, schema: info.schema, items: info.items, hasDatabase: false);
  }

  /// Заменить всё нынешнее содержимым копии. Сперва копия проверяется и доводится
  /// до нынешней схемы отдельно, и только потом живая база переписывается одной транзакцией.
  /// Копия без снимка базы (из браузера) кладёт в хранилище только файлы, базу не трогает:
  /// по [BackupInfo.hasDatabase] вызывающий пересобирает указатель из файлов.
  Future<BackupInfo> restore(File zip, {Future<void> Function()? onFile}) async {
    final info = await inspect(zip);
    if (info.schema > _db.schemaVersion) throw const BackupError(BackupProblem.tooNew);
    if (!info.hasDatabase) {
      final input = InputFileStream(zip.path);
      try {
        await _restoreFiles(ZipDecoder().decodeStream(input), onFile: onFile);
      } finally {
        input.closeSync();
      }
      return info;
    }

    final work = await Directory.systemTemp.createTemp('stowa_restore');
    try {
      await extractFileToDisk(zip.path, work.path);
      final copy = File(p.join(work.path, 'stowa.sqlite'));
      // старая копия проходит те же миграции, что и база в приложении
      final upgraded = AppDatabase(fileExecutor(copy));
      await upgraded.customSelect('SELECT 1').get();
      await upgraded.close();

      await _db.customStatement('PRAGMA foreign_keys = OFF');
      await _db.customStatement('ATTACH DATABASE ? AS backup', [copy.path]);
      try {
        await _db.transaction(() async {
          for (final table in _db.allTables) {
            final name = table.actualTableName;
            if (_skipTables.contains(name)) continue;
            final columns = table.$columns.map((column) => '"${column.name}"').join(', ');
            await _db.customStatement('DELETE FROM main."$name"');
            await _db.customStatement('INSERT INTO main."$name" ($columns) SELECT $columns FROM backup."$name"');
          }
          // поиск строится заново по восстановленным вещам
          await _db.customStatement("INSERT INTO items_fts(items_fts) VALUES ('rebuild')");
        });
      } finally {
        await _db.customStatement('DETACH DATABASE backup');
        await _db.customStatement('PRAGMA foreign_keys = ON');
      }
      _db.markTablesUpdated(_db.allTables);

      if (_vault) {
        // файлы копии встают в хранилище поверх, чужие файлы хранилища остаются; карта файлов
        // прежнего телефона не годится — заметки пишутся заново из восстановленной базы
        final restored = Directory(p.join(work.path, 'files'));
        if (restored.existsSync()) await _copyFolder(restored, _filesRoot);
        await _db.delete(_db.vaultFiles).go();
        await _db.delete(_db.vaultFlags).go();
        await _db.enqueueWholeVault();
        return info;
      }

      // файлы: прежние папки уходят, на их место встают из копии
      for (final name in _fileFolders) {
        final current = Directory(p.join(_filesRoot.path, name));
        if (current.existsSync()) await current.delete(recursive: true);
        final restored = Directory(p.join(work.path, 'files', name));
        if (restored.existsSync()) await _copyFolder(restored, current);
      }
      return info;
    } finally {
      await work.delete(recursive: true);
    }
  }

  Future<void> _copyFolder(Directory from, Directory to) async {
    for (final entity in from.listSync(recursive: true).whereType<File>()) {
      final target = File(p.join(to.path, p.relative(entity.path, from: from.path)));
      await target.parent.create(recursive: true);
      await entity.copy(target.path);
    }
  }
}
