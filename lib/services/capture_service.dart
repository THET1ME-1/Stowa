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
import '../domain/inline_tags.dart';
import '../domain/item_kind.dart';
import '../domain/item_title.dart';
import '../domain/models.dart';
import '../domain/photo_facts.dart' show photoFactsOf;
import '../domain/place_cue.dart';
import '../domain/reminder_parser.dart';
import '../domain/shot_date.dart';
import '../domain/sort_rules.dart';
import '../domain/tag_name.dart';
import 'ai_worker.dart' show aiSortJob;
import 'file_keeper.dart';

export 'file_keeper.dart' show CopyFailure;

/// Сколько читать с начала JPEG ради даты съёмки: сегмент EXIF не длиннее 64 КБ,
/// перед ним бывает JFIF и XMP — с запасом вдвое, это доли миллисекунды.
const _exifHead = 128 * 1024;

/// Когда снят файл: дата из EXIF у JPEG, иначе из имени («VID_20261012_154510.mp4»).
/// Не узнать — null, подпись тогда по дню сохранения.
Future<DateTime?> shotDateOf(PickedFile? file) async {
  if (file == null) return null;
  if (file.mime == 'image/jpeg') {
    try {
      final handle = await File(file.path).open();
      try {
        final taken = photoFactsOf(await handle.read(_exifHead))?.takenAt;
        if (taken != null) return taken;
      } finally {
        await handle.close();
      }
    } on FileSystemException {
      // файл не читается: остаётся дата из имени
    }
  }
  return shotDateFromName(file.name ?? p.basename(file.path));
}

/// Временные папки самого приложения: файл оттуда переносится во вложения, а не копируется.
/// Голосовые пишутся в `tmp`, файлы бота — в `telegram_inbox`; кэш выбора и «Поделиться» добавляет main.
List<Directory> ownTemporaryFolders(Directory filesRoot, [Directory? cache]) => [
  Directory(p.join(filesRoot.path, 'tmp')),
  Directory(p.join(filesRoot.path, 'telegram_inbox')),
  ?cache,
];

class PickedFile {
  const PickedFile({required this.path, required this.mime, required this.size, this.seconds, this.name});

  final String path;
  final String mime;
  final int size;

  /// Под каким именем файл ляжет к заметке; null — как назван у источника.
  /// Фото, вставленное в текст, получает своё: на него ссылается строка `![[имя]]`.
  final String? name;

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
    this.at,
    this.detectPlace = true,
    this.forcedPlace,
  });

  /// Искать место в тексте: «напомни дома». Человек снял чип места — не ищем.
  final bool detectPlace;

  /// Место, выбранное руками: главнее найденного в тексте.
  final PlaceReminder? forcedPlace;

  /// Когда заметка написана, если не сейчас: перенос из Telegram ставит дату сообщения.
  final DateTime? at;

  /// Вещь сохранена тут и сейчас: ей ставится место. Пересланное боту — нет,
  /// его могли написать где угодно и давно.
  final bool here;

  /// Свой заголовок, когда из текста его не взять: «Голосовое».
  final String? title;

  /// Подпись, если ни текст, ни имя файла заголовка не дали: «Фото от 3 ноября».
  /// День — когда снято (EXIF, имя файла), а не когда сохранено: фото июля — «от 15 июля».
  final String Function(DateTime at)? untitled;

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
/// файлы становятся задачами [FileKeeper] в той же транзакции и докладываются
/// после возврата: вещь видна сразу, вложение дорисуется и не потеряется.
class CaptureService {
  CaptureService(
    this._db, {
    required TagsRepository tags,
    required Directory filesRoot,
    DateTime Function()? clock,
    Uuid? uuid,
    FileKeeper? files,
    bool Function()? titleByShot,
    int Function()? workEnd,
  }) : _tags = tags, // ignore: prefer_initializing_formals
       _workEnd = workEnd ?? (() => defaultWorkEnd),
       _filesRoot = filesRoot, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now,
       _uuid = uuid ?? const Uuid(),
       _titleByShot = titleByShot ?? (() => true),
       files = files ?? FileKeeper(_db, filesRoot: filesRoot, movable: ownTemporaryFolders(filesRoot), clock: clock ?? DateTime.now);

  final AppDatabase _db;
  final TagsRepository _tags;

  /// Подпись «Фото от …» по дню съёмки (по умолчанию) или по дню сохранения — выбор в настройках.
  final bool Function() _titleByShot;

  /// Конец рабочего дня для «после работы», в минутах от полуночи.
  final int Function() _workEnd;

  // заметки с «напомни тут» из текущей пачки: им нужна точка с телефона
  final _wantsHere = <String>{};
  final Directory _filesRoot;
  final DateTime Function() _clock;
  final Uuid _uuid;

  /// Очередь файлов: её же разбирают окно «Поделиться» и фон.
  final FileKeeper files;

  /// Что сделать после сохранения: правила, напоминание, очередь ИИ.
  void Function(String itemId)? afterCapture;

  /// То же для пачки [captureAll] разом: индекс соседей и разбор строятся один раз на пачку,
  /// а не на каждую заметку. Нет — пачка идёт через [afterCapture] по одной.
  void Function(List<String> itemIds)? afterBatch;

  /// Поставить вещи место, где её сохранили. Сохранение не ждёт.
  void Function(String itemId)? stampPlace;

  Future<String> capture(CaptureInput input) async => (await captureAll([input])).single;

  /// Пачка заметок одной транзакцией: на телефоне каждая транзакция — запись на диск, перенос
  /// тысячи сообщений по одной шёл бы минутами. Хранитель файлов, разбор и место запускаются
  /// после неё: изнутри они работали бы с транзакцией, которая уже закрылась.
  Future<List<String>> captureAll(List<CaptureInput> inputs) async {
    if (inputs.any((input) => input.text.trim().isEmpty && input.files.isEmpty)) throw ArgumentError('пустую вещь сохранять нечего');
    final ids = <String>[];
    await _db.transaction(() async {
      final rules = await RulesRepository(_db).enabled();
      FolderIndex? index;
      Future<FolderIndex> folders() async => index ??= FolderIndex(await ItemsRepository(_db).folderDocs());
      for (final input in inputs) {
        ids.add(await _insert(input, rules, folders));
      }
    });

    if (inputs.any((input) => input.files.isNotEmpty)) files.drain().ignore();
    final batch = afterBatch;
    if (batch != null && ids.length > 1) batch(ids);
    for (final (index, id) in ids.indexed) {
      if (batch == null || ids.length == 1) afterCapture?.call(id);
      // «напомни тут» нужна точка, даже если заметку прислали издалека
      if (inputs[index].here || _wantsHere.remove(id)) stampPlace?.call(id);
    }
    return ids;
  }

  // одна заметка внутри транзакции [captureAll]
  Future<String> _insert(CaptureInput input, List<SortRule> enabledRules, Future<FolderIndex> Function() folders) async {
    final text = input.text.trim();
    final id = _uuid.v4();
    final now = _clock();
    final firstFile = input.files.isEmpty ? null : input.files.first;
    final byHand = input.forcedFolderId != null || input.asIs;
    final found = input.forcedReminder == null && input.detectReminder ? parseReminder(text, now, workEnd: _workEnd()) : null;
    // дата уходит из заголовка, если без неё что-то осталось: «23 декабря 13:00 зубной» → «Зубной»
    final rest = found?.restOf(text) ?? '';
    var titleSource = rest.isNotEmpty ? rest : text;
    // и место: «напомни дома купить хлеб» → «Купить хлеб»
    final cue = input.forcedPlace == null && input.detectPlace ? parsePlaceCue(titleSource) : null;
    final place = input.forcedPlace ?? (cue == null ? null : PlaceReminder(cue.kind));
    if (cue != null && cue.restOf(titleSource).isNotEmpty) titleSource = cue.restOf(titleSource);
    final fromContent = titleFor(titleSource, fileName: firstFile == null ? null : p.basename(firstFile.path));
    final untitled = input.untitled;
    final shot = fromContent.isEmpty && untitled != null && _titleByShot() ? await shotDateOf(firstFile) : null;
    final title = fromContent.isNotEmpty || untitled == null ? fromContent : untitled(shot ?? input.at ?? now);
    final kind = detectKind(text: text, mime: firstFile?.mime);
    final url = firstUrl(text);
    final ownTags = [...input.forcedTagNames.map(normalizeTagName), ...extractInlineTags(text)];

    // правила раньше ИИ: разложили — вещь в очередь ИИ не встаёт
    final rules = byHand ? const RuleOutcome() : applyRules(enabledRules, text: text, tags: ownTags, host: url?.host, kind: kind);
    final byRule = rules.folderId != null;
    // правила молчат — угадыватель смотрит, в какой папке уже живут слова заметки,
    // ссылки с того же сайта и такие же фото и файлы
    final signals = itemSignals(kind: kind, url: url?.toString(), fileName: firstFile == null ? null : p.basename(firstFile.path));
    final guess = byHand || byRule ? null : (await folders()).guess(text, signals: signals);
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
            remindPlace: Value(place?.kind),
            remindLatitude: Value(place?.latitude),
            remindLongitude: Value(place?.longitude),
            remindPlaceName: Value(place?.name),
            durationSeconds: Value(input.files.map((file) => file.seconds).nonNulls.firstOrNull),
            createdAt: input.at ?? now,
            updatedAt: input.at ?? now,
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
    // файлы — задачами в той же транзакции: вещь без своего файла не останется
    await files.enqueue(id, input.files);
    if (place?.kind == PlaceReminderKind.point && place?.latitude == null) _wantsHere.add(id);
    return id;
  }

  /// Очередь файлов разобрана: всё, что можно было положить, лежит.
  Future<void> settled() => files.drain();

  /// Файлы, которые не удалось сохранить.
  Stream<CopyFailure> get copyFailures => files.failures;

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
    final waiting = await (_db.select(_db.fileJobs)..where((t) => t.itemId.equals(itemId))).get().then((rows) => rows.length);
    await this.files.enqueue(itemId, files, from: count + waiting);
    await this.files.drain();
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

  /// Подписи «Фото от …» — по выбранному дню: [byShot] — съёмки (EXIF, факт `takenAt`,
  /// или имя файла), иначе сохранения. Трогается только подпись, которую дало приложение
  /// (по одному из двух дней): название, которое человек поменял, остаётся как есть.
  Future<void> retitleUntitled(String Function({required String mime, required String fileName, required DateTime at}) untitled, {required bool byShot}) async {
    final rows = await _db.customSelect('''
SELECT items.id AS id, items.title AS title, items.created_at AS created_at, attachments.path AS path, attachments.mime AS mime,
  (SELECT facts.value FROM facts WHERE facts.item_id = items.id AND facts.kind = 'takenAt' LIMIT 1) AS taken
FROM items JOIN attachments ON attachments.item_id = items.id AND attachments.position = 0
WHERE items.deleted_at IS NULL AND trim(items.body) = ''
''', readsFrom: {_db.items, _db.attachments, _db.facts}).get();
    for (final row in rows) {
      final fileName = p.basename(row.read<String>('path')).replaceFirst(RegExp(r'^\d+_'), '');
      final mime = row.read<String>('mime');
      final shot = DateTime.tryParse(row.readNullable<String>('taken') ?? '') ?? shotDateFromName(fileName);
      if (shot == null) continue;
      final createdAt = _db.typeMapping.read(DriftSqlType.dateTime, row.data['created_at'])!;
      final title = row.read<String>('title');
      final bySaved = untitled(mime: mime, fileName: fileName, at: createdAt);
      final byShotTitle = untitled(mime: mime, fileName: fileName, at: shot);
      if (title != bySaved && title != byShotTitle) continue;
      final wanted = byShot ? byShotTitle : bySaved;
      if (wanted == title) continue;
      await (_db.update(_db.items)..where((t) => t.id.equals(row.read<String>('id')))).write(ItemsCompanion(title: Value(wanted)));
    }
  }

  /// Заметки, которые раньше записались ссылкой из-за адреса внутри текста, — снова заметки.
  /// И наоборот: ссылка с превью, которую правка сделала заметкой из-за длинного заголовка, — снова ссылка.
  Future<void> reclassifyNotes() async {
    final previewed = await (_db.select(_db.items)..where((t) => t.kind.equals(ItemKind.note.name) & t.previewAt.isNotNull() & t.url.isNotNull() & t.deletedAt.isNull())).get();
    for (final item in previewed) {
      final kind = detectKind(text: item.body);
      if (kind == ItemKind.note) continue;
      await (_db.update(_db.items)..where((t) => t.id.equals(item.id))).write(ItemsCompanion(kind: Value(kind)));
    }
    final rows = await (_db.select(_db.items)..where((t) => t.kind.isIn([ItemKind.link.name, ItemKind.video.name]) & t.deletedAt.isNull())).get();
    for (final item in rows) {
      final files = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(item.id))).get();
      // адрес только в своём поле, а в тексте подпись: это ссылка, судить по тексту нечего
      if (files.isNotEmpty || firstUrl(item.body) == null || detectKind(text: item.body) != ItemKind.note) continue;
      await (_db.update(_db.items)..where((t) => t.id.equals(item.id))).write(const ItemsCompanion(kind: Value(ItemKind.note)));
    }
  }

  /// Названия мест, записанные до `streetOf`, — «улица, город, страна, город»: оставить улицу и город.
  Future<void> shortenPlaceNames() async {
    String? short(String? name) {
      final parts = name?.split(',').map((part) => part.trim()).toList();
      if (parts == null || parts.length < 3) return null;
      return '${parts.first}, ${parts.last}';
    }

    final rows = await (_db.select(_db.items)..where((t) => t.placeName.like('%,%,%') | t.remindPlaceName.like('%,%,%'))).get();
    for (final item in rows) {
      final place = short(item.placeName);
      final remind = short(item.remindPlaceName);
      await (_db.update(_db.items)..where((t) => t.id.equals(item.id))).write(
        ItemsCompanion(
          placeName: place == null ? const Value.absent() : Value(place),
          remindPlaceName: remind == null ? const Value.absent() : Value(remind),
        ),
      );
    }
  }

  /// Картинкам, сохранённым до учёта размеров, дописать размер. Пропавший файл пропускается.
  Future<void> fillImageSizes() async {
    final missing = await (_db.select(_db.attachments)..where((t) => t.mime.like('image/%') & t.width.isNull())).get();
    for (final file in missing) {
      final full = p.join(_filesRoot.path, file.path);
      if (!await File(full).exists()) continue;
      final size = await imageSizeOfFile(full);
      if (size == null) continue;
      await (_db.update(_db.attachments)..where((t) => t.id.equals(file.id))).write(AttachmentsCompanion(width: Value(size.width), height: Value(size.height)));
    }
  }
}
