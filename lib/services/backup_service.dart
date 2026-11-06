import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../data/db/database.dart';

/// Папки с файлами вещей, обложками ссылок и картинками тегов.
const _fileFolders = ['attachments', 'covers', 'tags', '.stowa/covers', '.stowa/tag-icons'];

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
  const BackupInfo({required this.createdAt, required this.schema, required this.items});

  final DateTime createdAt;
  final int schema;
  final int items;
}

/// Резервная копия всей Stowa одним zip: снимок базы и файлы. Ключа ИИ и настроек
/// в ней нет — они живут не в базе.
class BackupService {
  BackupService(this._db, {required Directory filesRoot, required DateTime Function() clock})
    : _filesRoot = filesRoot, // ignore: prefer_initializing_formals
      _clock = clock; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final Directory _filesRoot;
  final DateTime Function() _clock;

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
      for (final name in _fileFolders) {
        final dir = Directory(p.join(_filesRoot.path, name));
        if (!dir.existsSync()) continue;
        for (final file in dir.listSync(recursive: true).whereType<File>()) {
          await encoder.addFile(file, 'files/${p.relative(file.path, from: _filesRoot.path).replaceAll(r'\', '/')}');
        }
      }
      await encoder.close();
      return zip;
    } finally {
      await work.delete(recursive: true);
    }
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
      final manifest = archive.findFile('manifest.json');
      if (manifest == null || archive.findFile('stowa.sqlite') == null) throw const BackupError(BackupProblem.notStowa);
      final json = jsonDecode(utf8.decode(manifest.content)) as Map<String, Object?>;
      if (json['app'] != 'stowa') throw const BackupError(BackupProblem.notStowa);
      return BackupInfo(createdAt: DateTime.parse(json['createdAt']! as String), schema: json['schema']! as int, items: json['items']! as int);
    } finally {
      input.closeSync();
    }
  }

  /// Заменить всё нынешнее содержимым копии. Сперва копия проверяется и доводится
  /// до нынешней схемы отдельно, и только потом живая база переписывается одной транзакцией.
  Future<void> restore(File zip) async {
    final info = await inspect(zip);
    if (info.schema > _db.schemaVersion) throw const BackupError(BackupProblem.tooNew);

    final work = await Directory.systemTemp.createTemp('stowa_restore');
    try {
      await extractFileToDisk(zip.path, work.path);
      final copy = File(p.join(work.path, 'stowa.sqlite'));
      // старая копия проходит те же миграции, что и база в приложении
      final upgraded = AppDatabase(NativeDatabase(copy));
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

      // файлы: прежние папки уходят, на их место встают из копии
      for (final name in _fileFolders) {
        final current = Directory(p.join(_filesRoot.path, name));
        if (current.existsSync()) await current.delete(recursive: true);
        final restored = Directory(p.join(work.path, 'files', name));
        if (restored.existsSync()) await _copyFolder(restored, current);
      }
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
