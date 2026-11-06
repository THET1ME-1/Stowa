import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../data/db/database.dart';
import '../domain/telegram_export.dart';
import 'capture_service.dart';

// сообщений в одной транзакции: на телефоне каждая — запись на диск
const _batch = 50;

// страница выгрузки в HTML: messages.html — первая, messages2.html — вторая
final _page = RegExp(r'^messages(\d*)\.html$');

/// Итог переноса: сколько заметок появилось, сколько уже было, сколько файлов не нашлось.
class TelegramImportReport {
  const TelegramImportReport({required this.added, required this.repeated, required this.filesMissing, this.filled = 0});

  final int added;
  final int repeated;
  final int filesMissing;

  /// Уже перенесённые заметки, к которым легли файлы: прошлая выгрузка была без них.
  final int filled;
}

/// В папке нет выгрузки Telegram или она не читается.
class TelegramImportError implements Exception {
  const TelegramImportError(this.reason);
  final String reason;

  @override
  String toString() => 'TelegramImportError: $reason';
}

/// Перенос «Избранного» из папки выгрузки Telegram Desktop. Каждое сообщение сохраняется
/// как обычная заметка: правила, угадыватель папки, ИИ, файлы и хранилище работают как всегда.
class TelegramImport {
  TelegramImport(this._db, this._capture, {this.untitled});

  final AppDatabase _db;
  final CaptureService _capture;

  /// Подпись фото или файла без текста: «Фото от 12 мая». Её знает экран, а не перенос.
  final String Function({required String mime, required String fileName, required DateTime at})? untitled;

  Future<TelegramImportReport> run(Directory folder, {void Function(int done, int total)? progress}) async {
    final List<ExportedNote> notes;
    try {
      notes = await _read(folder);
    } on FormatException catch (error) {
      throw TelegramImportError(error.message);
    }

    var added = 0;
    var repeated = 0;
    var missing = 0;
    var filled = 0;
    // в ходе — только будущие заметки: сообщение из невыгруженного файла заметкой не станет
    bool real(ExportedNote note) => note.text.isNotEmpty || note.files.isNotEmpty;
    final total = notes.where(real).length;
    var done = 0;
    progress?.call(0, total);
    for (var start = 0; start < notes.length; start += _batch) {
      final batch = notes.sublist(start, (start + _batch).clamp(0, notes.length));
      final inputs = <CaptureInput>[];
      for (final note in batch) {
        missing += note.filesMissing;
        final files = <PickedFile>[];
        for (final exported in note.files) {
          final source = File(p.join(folder.path, exported.path));
          if (!await source.exists()) {
            missing++;
            continue;
          }
          files.add(PickedFile(path: source.path, mime: exported.mime, size: await source.length(), seconds: exported.seconds));
        }
        // ни текста, ни файла: переносить нечего
        if (note.text.isEmpty && files.isEmpty) continue;
        if (await _already(note) case final existing?) {
          repeated++;
          // прошлая выгрузка была без файлов, эта с ними: файлы ложатся к той же заметке
          if (files.isNotEmpty && !await _hasFiles(existing)) {
            await _capture.files.enqueue(existing, files);
            filled++;
          }
          continue;
        }
        final first = files.firstOrNull;
        final label = first == null ? null : untitled?.call(mime: first.mime, fileName: p.basename(first.path), at: note.at);
        inputs.add(CaptureInput(text: note.text, files: files, at: note.at, here: false, detectReminder: false, untitled: label));
      }
      if (filled > 0) _capture.files.drain().ignore();
      if (inputs.isNotEmpty) await _capture.captureAll(inputs);
      added += inputs.length;
      done += batch.where(real).length;
      progress?.call(done, total);
    }
    return TelegramImportReport(added: added, repeated: repeated, filesMissing: missing, filled: filled);
  }

  // выгрузка в JSON — result.json; в HTML (по умолчанию) — messages.html, messages2.html … по номерам
  Future<List<ExportedNote>> _read(Directory folder) async {
    final json = File(p.join(folder.path, 'result.json'));
    if (await json.exists()) return parseTelegramExport(jsonDecode(await json.readAsString()));
    final pages = <(int, File)>[
      await for (final entity in folder.list())
        if (entity is File)
          if (_page.firstMatch(p.basename(entity.path)) case final match?) (int.tryParse(match.group(1)!) ?? 1, entity),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    if (pages.isEmpty) throw const TelegramImportError('нет result.json и messages.html');
    return parseTelegramHtml([for (final (_, page) in pages) await page.readAsString()]);
  }

  // та же дата до секунды и тот же текст — это сообщение уже переносили
  Future<String?> _already(ExportedNote note) async {
    final same = await (_db.select(_db.items)
          ..where((t) => t.createdAt.equals(note.at) & t.body.equals(note.text))
          ..limit(1))
        .get();
    return same.firstOrNull?.id;
  }

  // файлы у заметки есть или уже ложатся
  Future<bool> _hasFiles(String itemId) async {
    final kept = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(itemId))..limit(1)).get();
    if (kept.isNotEmpty) return true;
    final waiting = await (_db.select(_db.fileJobs)..where((t) => t.itemId.equals(itemId))..limit(1)).get();
    return waiting.isNotEmpty;
  }
}
