import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/db/database.dart';
import '../data/repositories/rules_repository.dart';
import '../data/repositories/tags_repository.dart';
import '../domain/inline_tags.dart';
import '../domain/item_kind.dart';
import '../domain/item_title.dart';
import '../domain/models.dart';
import '../domain/reminder_parser.dart';
import '../domain/sort_rules.dart';
import '../domain/tag_name.dart';

class PickedFile {
  const PickedFile({required this.path, required this.mime, required this.size});

  final String path;
  final String mime;
  final int size;
}

/// Что закинули в строку.
class CaptureInput {
  const CaptureInput({
    this.text = '',
    this.files = const [],
    this.forcedFolderId,
    this.forcedTagNames = const [],
    this.forcedReminder,
    this.detectReminder = true,
    this.asIs = false,
    this.title,
  });

  /// Свой заголовок, когда из текста его не взять: «Голосовое».
  final String? title;

  final String text;
  final List<PickedFile> files;

  /// Папка и теги, выбранные человеком чипами: решение человека главнее.
  final String? forcedFolderId;
  final List<String> forcedTagNames;
  final DateTime? forcedReminder;

  /// Искать дату в тексте. Человек снял чип напоминания — не ищем.
  final bool detectReminder;

  /// «Во Входящие как есть»: без папки, правила и ИИ вещь не трогают.
  final bool asIs;
}

/// Единая точка «сохранить вещь». Запись идёт одной транзакцией без сети,
/// файлы докладываются после возврата: вещь видна сразу, вложение дорисуется.
class CaptureService {
  CaptureService(
    this._db, {
    required TagsRepository tags,
    required Directory filesRoot,
    DateTime Function()? clock,
    Uuid? uuid,
  })  : _tags = tags, // ignore: prefer_initializing_formals
        _filesRoot = filesRoot, // ignore: prefer_initializing_formals
        _clock = clock ?? DateTime.now,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final TagsRepository _tags;
  final Directory _filesRoot;
  final DateTime Function() _clock;
  final Uuid _uuid;
  final _copies = <Future<void>>[];

  /// Что сделать после сохранения: правила, напоминание, очередь ИИ.
  void Function(String itemId)? afterCapture;

  Future<String> capture(CaptureInput input) async {
    final text = input.text.trim();
    if (text.isEmpty && input.files.isEmpty) throw ArgumentError('пустую вещь сохранять нечего');

    final id = _uuid.v4();
    final now = _clock();
    final firstFile = input.files.isEmpty ? null : input.files.first;
    final byHand = input.forcedFolderId != null || input.asIs;
    final found = input.forcedReminder == null && input.detectReminder ? parseReminder(text, now) : null;
    // дата уходит из заголовка, если без неё что-то осталось: «23 декабря 13:00 зубной» → «Зубной»
    final rest = found?.restOf(text) ?? '';
    final titleSource = rest.isNotEmpty ? rest : text;
    final kind = detectKind(text: text, mime: firstFile?.mime);
    final url = firstUrl(text);
    final ownTags = [...input.forcedTagNames.map(normalizeTagName), ...extractInlineTags(text)];

    await _db.transaction(() async {
      // правила раньше ИИ: разложили — вещь в очередь ИИ не встаёт
      final rules = byHand ? const RuleOutcome() : applyRules(await RulesRepository(_db).enabled(), text: text, tags: ownTags, host: url?.host, kind: kind);
      final byRule = rules.folderId != null;
      await _db.into(_db.items).insert(ItemsCompanion.insert(
            id: id,
            kind: kind,
            title: input.title ?? titleFor(titleSource, fileName: firstFile == null ? null : p.basename(firstFile.path)),
            body: Value(text),
            url: Value(url?.toString()),
            folderId: Value(input.forcedFolderId ?? rules.folderId),
            sortedBy: Value(byHand ? SortedBy.user : byRule ? SortedBy.rule : SortedBy.none),
            sortState: Value(byHand || byRule ? SortState.sorted : SortState.pending),
            reminderAt: Value(input.forcedReminder ?? found?.at),
            createdAt: now,
            updatedAt: now,
          ));
      // выбранные руками ставятся первыми, тег из текста их источник не перебьёт
      for (final raw in input.forcedTagNames) {
        await _linkTag(id, raw, TagSource.user);
      }
      for (final name in extractInlineTags(text)) {
        await _linkTag(id, name, TagSource.inline);
      }
      for (final name in rules.tags) {
        await _linkTag(id, name, TagSource.rule);
      }
    });

    if (input.files.isNotEmpty) _copies.add(_copyFiles(id, input.files));
    afterCapture?.call(id);
    return id;
  }

  /// Все начатые копирования файлов закончились.
  Future<void> settled() async {
    while (_copies.isNotEmpty) {
      final batch = List.of(_copies);
      _copies.clear();
      await Future.wait(batch);
    }
  }

  Future<void> _linkTag(String itemId, String raw, TagSource source) async {
    final tag = await _tags.ensure(raw);
    await _db.into(_db.itemTags).insert(
          ItemTagsCompanion.insert(itemId: itemId, tagId: tag.id, source: source),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _copyFiles(String itemId, List<PickedFile> files) async {
    final folder = p.join('attachments', itemId);
    await Directory(p.join(_filesRoot.path, folder)).create(recursive: true);
    for (final (index, file) in files.indexed) {
      final relative = p.join(folder, '${index}_${p.basename(file.path)}');
      await File(file.path).copy(p.join(_filesRoot.path, relative));
      await _db.into(_db.attachments).insert(AttachmentsCompanion.insert(
            id: _uuid.v4(),
            itemId: itemId,
            path: relative,
            mime: file.mime,
            size: file.size,
            position: Value(index),
          ));
    }
  }
}
