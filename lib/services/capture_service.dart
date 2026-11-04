import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/db/database.dart';
import '../data/repositories/items_repository.dart';
import '../data/repositories/rules_repository.dart';
import '../data/repositories/tags_repository.dart';
import '../domain/folder_guess.dart';
import '../domain/image_size.dart';
import '../domain/inline_tags.dart';
import '../domain/item_kind.dart';
import '../domain/item_title.dart';
import '../domain/models.dart';
import '../domain/reminder_parser.dart';
import '../domain/sort_rules.dart';
import '../domain/tag_name.dart';
import 'ai_worker.dart' show aiSortJob;

class PickedFile {
  const PickedFile({required this.path, required this.mime, required this.size, this.seconds});

  final String path;
  final String mime;
  final int size;

  /// Длина записи, если её знает тот, кто записывал: голосовое строки.
  final int? seconds;
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
    this.untitled,
    this.here = true,
  });

  /// Вещь сохранена тут и сейчас: ей ставится место. Пересланное боту — нет,
  /// его могли написать где угодно и давно.
  final bool here;

  /// Свой заголовок, когда из текста его не взять: «Голосовое».
  final String? title;

  /// Подпись, если ни текст, ни имя файла заголовка не дали: «Фото от 3 ноября».
  final String? untitled;

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
  CaptureService(this._db, {required TagsRepository tags, required Directory filesRoot, DateTime Function()? clock, Uuid? uuid})
    : _tags = tags, // ignore: prefer_initializing_formals
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

  /// Поставить вещи место, где её сохранили. Сохранение не ждёт.
  void Function(String itemId)? stampPlace;

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
    final fromContent = titleFor(titleSource, fileName: firstFile == null ? null : p.basename(firstFile.path));
    final title = fromContent.isEmpty ? (input.untitled ?? '') : fromContent;
    final kind = detectKind(text: text, mime: firstFile?.mime);
    final url = firstUrl(text);
    final ownTags = [...input.forcedTagNames.map(normalizeTagName), ...extractInlineTags(text)];

    await _db.transaction(() async {
      // правила раньше ИИ: разложили — вещь в очередь ИИ не встаёт
      final rules = byHand ? const RuleOutcome() : applyRules(await RulesRepository(_db).enabled(), text: text, tags: ownTags, host: url?.host, kind: kind);
      final byRule = rules.folderId != null;
      // правила молчат — угадыватель смотрит, в какой папке уже живут слова заметки,
      // ссылки с того же сайта и такие же фото и файлы
      final signals = itemSignals(kind: kind, url: url?.toString(), fileName: firstFile == null ? null : p.basename(firstFile.path));
      final guess = byHand || byRule ? null : FolderIndex(await ItemsRepository(_db).folderDocs()).guess(text, signals: signals);
      final sorted = byHand || byRule || guess != null;
      await _db
          .into(_db.items)
          .insert(
            ItemsCompanion.insert(
              id: id,
              kind: kind,
              title: input.title ?? title,
              body: Value(text),
              url: Value(url?.toString()),
              folderId: Value(input.forcedFolderId ?? rules.folderId ?? guess?.folderId),
              sortedBy: Value(
                byHand
                    ? SortedBy.user
                    : byRule
                    ? SortedBy.rule
                    : guess != null
                    ? SortedBy.similar
                    : SortedBy.none,
              ),
              sortState: Value(sorted ? SortState.sorted : SortState.pending),
              reminderAt: Value(input.forcedReminder ?? found?.at),
              durationSeconds: Value(input.files.map((file) => file.seconds).nonNulls.firstOrNull),
              createdAt: now,
              updatedAt: now,
            ),
          );
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
      // папки так и нет — вещь ждёт ключ ИИ; без ключа или сети задача просто лежит.
      // голосовое ждёт всегда: его расшифрует модель речи, если она выбрана
      if (!sorted || kind == ItemKind.voice) await _db.into(_db.aiJobs).insert(AiJobsCompanion.insert(itemId: id, kind: aiSortJob, nextTryAt: now));
    });

    if (input.files.isNotEmpty) _copies.add(_copyFiles(id, input.files));
    afterCapture?.call(id);
    if (input.here) stampPlace?.call(id);
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
    await _db
        .into(_db.itemTags)
        .insert(
          ItemTagsCompanion.insert(itemId: itemId, tagId: tag.id, source: source),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Дописать файлы к готовой вещи со страницы правки: встают после уже приложенных.
  Future<void> attach(String itemId, List<PickedFile> files) async {
    final count = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(itemId))).get().then((rows) => rows.length);
    await _copyFiles(itemId, files, from: count);
  }

  /// Вещам без текста, которым раньше в заголовок шло имя файла, дать заголовок по
  /// нынешнему правилу: человеческое имя без расширения, машинное — подпись [untitled].
  /// Заголовок, который человек поменял, не трогается: он уже не совпадает с именем.
  Future<void> retitleFileNames(String Function({required String mime, required String fileName, required DateTime at}) untitled) async {
    final rows = await _db.customSelect('''
SELECT items.id AS id, items.title AS title, items.created_at AS created_at, attachments.path AS path, attachments.mime AS mime
FROM items JOIN attachments ON attachments.item_id = items.id AND attachments.position = 0
WHERE items.deleted_at IS NULL AND trim(items.body) = ''
''', readsFrom: {_db.items, _db.attachments}).get();
    for (final row in rows) {
      // файл хранится как «номер_имя»: имя — то, что было в заголовке
      final stored = p.basename(row.read<String>('path'));
      final fileName = stored.substring(stored.indexOf('_') + 1);
      if (row.read<String>('title') != fileName) continue;
      final fromName = titleFor('', fileName: fileName);
      final createdAt = _db.typeMapping.read(DriftSqlType.dateTime, row.data['created_at'])!;
      final title = fromName.isNotEmpty ? fromName : untitled(mime: row.read<String>('mime'), fileName: fileName, at: createdAt);
      await (_db.update(_db.items)..where((t) => t.id.equals(row.read<String>('id')))).write(ItemsCompanion(title: Value(title)));
    }
  }

  /// Заметки, которые раньше записались ссылкой из-за адреса внутри текста, — снова заметки.
  Future<void> reclassifyNotes() async {
    final rows = await (_db.select(_db.items)..where((t) => t.kind.isIn([ItemKind.link.name, ItemKind.video.name]) & t.deletedAt.isNull())).get();
    for (final item in rows) {
      final files = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(item.id))).get();
      // адрес только в своём поле, а в тексте подпись: это ссылка, судить по тексту нечего
      if (files.isNotEmpty || firstUrl(item.body) == null || detectKind(text: item.body) != ItemKind.note) continue;
      await (_db.update(_db.items)..where((t) => t.id.equals(item.id))).write(const ItemsCompanion(kind: Value(ItemKind.note)));
    }
  }

  /// Картинкам, сохранённым до учёта размеров, дописать размер. Пропавший файл пропускается.
  Future<void> fillImageSizes() async {
    final missing = await (_db.select(_db.attachments)..where((t) => t.mime.like('image/%') & t.width.isNull())).get();
    for (final file in missing) {
      final full = p.join(_filesRoot.path, file.path);
      if (!await File(full).exists()) continue;
      final size = await _imageSize(full);
      if (size == null) continue;
      await (_db.update(_db.attachments)..where((t) => t.id.equals(file.id))).write(AttachmentsCompanion(width: Value(size.width), height: Value(size.height)));
    }
  }

  // хватает начала файла: EXIF с миниатюрой занимает до 64 КБ
  Future<({int width, int height})?> _imageSize(String path) async {
    final file = await File(path).open();
    try {
      return imageSizeOf(await file.read(256 * 1024));
    } finally {
      await file.close();
    }
  }

  Future<void> _copyFiles(String itemId, List<PickedFile> files, {int from = 0}) async {
    final folder = p.join('attachments', itemId);
    await Directory(p.join(_filesRoot.path, folder)).create(recursive: true);
    var failed = 0;
    for (final (offset, file) in files.indexed) {
      final index = from + offset;
      final relative = p.join(folder, '${index}_${p.basename(file.path)}');
      try {
        await File(file.path).copy(p.join(_filesRoot.path, relative));
      } on FileSystemException {
        // источник не дал прочитать файл: остальные всё равно копируем
        failed++;
        continue;
      }
      final size = file.mime.startsWith('image/') ? await _imageSize(file.path) : null;
      await _db
          .into(_db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: _uuid.v4(),
              itemId: itemId,
              path: relative,
              mime: file.mime,
              size: file.size,
              position: Value(index),
              width: Value(size?.width),
              height: Value(size?.height),
            ),
          );
    }
    if (failed == 0) return;
    // ни файла, ни слов: пустая вещь в ленте только путала бы
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
    final empty = failed == files.length && from == 0 && (item?.body.trim().isEmpty ?? true);
    if (empty) {
      await _db.transaction(() async {
        await (_db.delete(_db.aiJobs)..where((t) => t.itemId.equals(itemId))).go();
        await (_db.delete(_db.itemTags)..where((t) => t.itemId.equals(itemId))).go();
        await (_db.delete(_db.items)..where((t) => t.id.equals(itemId))).go();
      });
    }
    _failures.add(CopyFailure(itemId: itemId, failed: failed, removed: empty));
  }

  final _failures = StreamController<CopyFailure>.broadcast();

  /// Файлы, которые не удалось скопировать: окно «Поделиться» и главная говорят об этом.
  Stream<CopyFailure> get copyFailures => _failures.stream;
}

/// Сколько файлов вещи не скопировалось и удалена ли из-за этого пустая вещь.
class CopyFailure {
  const CopyFailure({required this.itemId, required this.failed, required this.removed});

  final String itemId;
  final int failed;
  final bool removed;
}
