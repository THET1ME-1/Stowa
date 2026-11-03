import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/db/database.dart';
import '../data/settings_repository.dart';
import '../domain/ai_contract.dart';
import '../domain/models.dart';
import '../domain/related.dart';
import '../domain/tag_name.dart';
import 'ai_client.dart';

/// Итог одного прохода очереди.
class WorkerReport {
  const WorkerReport({this.sorted = 0, this.failed = 0, this.stopped});

  final int sorted;
  final int failed;

  /// Почему проход остановился раньше: пауза, просьба подождать, нет сети.
  final AiFailureKind? stopped;
}

/// Через сколько повторить задачу после неудачи: 2, 4, 8… минут, не дольше 6 часов.
Duration nextTryDelay(int attempts) => Duration(minutes: min(pow(2, attempts).toInt(), 360));

/// Задача разбора вещи в AiJobs.
const aiSortJob = 'sort';

/// Журнал запросов к ИИ хранит столько последних строк.
const _logKeep = 500;

/// Сколько вещей без папки нужно, чтобы предложить из них новые папки.
const _clusterAt = 4;

/// Столько ссылка ждёт превью, а фото — копирования, прежде чем уйти модели без них.
const _readyWait = Duration(minutes: 2);

/// ИИ положил вещь в папку: главная показывает «Положил в …» с «Другая».
class AiSorted {
  const AiSorted({required this.itemId, required this.folderId, required this.folderName});

  final String itemId;
  final String folderId;
  final String folderName;
}

/// Очередь разбора по ключу человека. Берёт вещи, которые не разложили ни
/// человек, ни правила, ни угадыватель, и спрашивает модель. Ручное решение
/// главнее: если человек успел переложить вещь, ответ добавит только описание.
class AiWorker {
  AiWorker(
    this._db, {
    required SettingsRepository settings,
    required http.Client http,
    required DateTime Function() clock,
    required String timeZone,
    Directory? filesRoot,
    this.imageForAi,
    this.isIcon,
  }) : _settings = settings, // ignore: prefer_initializing_formals
       _http = http, // ignore: prefer_initializing_formals
       _clock = clock, // ignore: prefer_initializing_formals
       _timeZone = timeZone, // ignore: prefer_initializing_formals
       _filesRoot = filesRoot; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final SettingsRepository _settings;
  final http.Client _http;
  final DateTime Function() _clock;
  final String _timeZone;
  final Directory? _filesRoot;

  /// Картинка для модели: JPEG base64 не больше 1024 точек. Без неё фото идёт именем файла.
  final Future<String?> Function(String path, {int? width, int? height})? imageForAi;
  final bool Function(String icon)? isIcon;

  final _sorted = StreamController<AiSorted>.broadcast();

  /// Вещи, которые ИИ только что положил в папку.
  Stream<AiSorted> get sorted => _sorted.stream;

  bool _running = false;
  int? _clusterTriedAt;

  /// Поставить вещь в очередь разбора.
  Future<void> enqueue(String itemId) => _db
      .into(_db.aiJobs)
      .insert(AiJobsCompanion.insert(itemId: itemId, kind: aiSortJob, nextTryAt: _clock()), mode: InsertMode.insertOrIgnore);

  /// Вещи, ждущие разбора, у которых почему-то нет задачи: сохранены до ключа.
  Future<void> enqueueMissing() async {
    final ids = await (_db.selectOnly(_db.items)
          ..addColumns([_db.items.id])
          ..where(_db.items.deletedAt.isNull() & _db.items.folderId.isNull() & _db.items.sortedBy.equalsValue(SortedBy.none) & _db.items.sortState.isNotValue(SortState.sorted.name)))
        .map((row) => row.read(_db.items.id)!)
        .get();
    for (final id in ids) {
      await enqueue(id);
    }
  }

  Future<AiClient?> _client() async {
    final ai = _settings.ai;
    if (!ai.active) return null;
    if (ai.retryAt != null && ai.retryAt!.isAfter(_clock())) return null;
    final key = await _settings.readKey();
    if (key == null) return null;
    return AiClient(http: _http, baseUrl: ai.baseUrl, apiKey: key);
  }

  /// Один проход: задачи, чей срок пришёл, по одной.
  Future<WorkerReport> runOnce({int maxJobs = 10}) async {
    if (_running) return const WorkerReport();
    _running = true;
    try {
      final client = await _client();
      if (client == null) return const WorkerReport();
      final jobs = await (_db.select(_db.aiJobs)
            ..where((t) => t.nextTryAt.isSmallerOrEqualValue(_clock()) & t.kind.equals(aiSortJob))
            ..orderBy([(t) => OrderingTerm.asc(t.nextTryAt)])
            ..limit(maxJobs))
          .get();
      var sorted = 0;
      var failed = 0;
      for (final job in jobs) {
        final item = await (_db.select(_db.items)..where((t) => t.id.equals(job.itemId))).getSingleOrNull();
        if (item == null || item.deletedAt != null) {
          await _dropJob(job.itemId);
          continue;
        }
        if (await _notReady(item)) {
          await (_db.update(_db.aiJobs)..where((t) => t.itemId.equals(item.id))).write(AiJobsCompanion(nextTryAt: Value(_clock().add(const Duration(seconds: 20)))));
          continue;
        }
        final context = await _context(item);
        final messages = buildSortMessages(context);
        String content;
        try {
          content = await client.chat(model: _settings.ai.sortModel, messages: messages, responseFormat: sortResponseFormat());
          await _log(item.id, messages, content, null);
        } on AiFailure catch (failure) {
          await _log(item.id, messages, null, failure.toString());
          switch (failure.kind) {
            case AiFailureKind.auth || AiFailureKind.payment:
              await _settings.pause(failure.kind.name);
              return WorkerReport(sorted: sorted, failed: failed, stopped: failure.kind);
            case AiFailureKind.rateLimit:
              await _settings.retryAfter(_clock().add(failure.retryAfter ?? const Duration(minutes: 1)));
              return WorkerReport(sorted: sorted, failed: failed, stopped: failure.kind);
            case AiFailureKind.network:
              return WorkerReport(sorted: sorted, failed: failed, stopped: failure.kind);
            case AiFailureKind.server || AiFailureKind.badResponse:
              await _fail(job, failure.message);
              failed++;
              continue;
          }
        }
        final decision = parseSortDecision(content, context, isIcon: isIcon);
        if (decision == null) {
          await _fail(job, 'ответ не разобрался');
          failed++;
          continue;
        }
        await _apply(item, decision);
        await _dropJob(item.id);
        sorted++;
      }
      return WorkerReport(sorted: sorted, failed: failed);
    } finally {
      _running = false;
    }
  }

  /// Всё, что ждёт: забытые задачи, очередь до конца, потом новые папки из «Без папки».
  /// Зовут после сохранения, при открытии, при возврате сети и из фона раз в 15 минут.
  Future<void> drain() async {
    // фоновая очередь могла поставить паузу, пока приложение спало
    await _settings.reload();
    await enqueueMissing();
    while (true) {
      final report = await runOnce();
      if (report.stopped != null) return;
      if (report.sorted + report.failed == 0) break;
    }
    await runCluster();
  }

  /// В «Без папки» набралось несколько вещей: спросить, не собрать ли их в новые папки.
  Future<int> runCluster() async {
    final client = await _client();
    if (client == null) return 0;
    final rows = await (_db.select(_db.items)
          ..where((t) => t.deletedAt.isNull() & t.folderId.isNull() & t.sortedBy.equalsValue(SortedBy.none))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(40))
        .get();
    if (rows.length < _clusterAt || rows.length == _clusterTriedAt) return 0;
    _clusterTriedAt = rows.length;
    final folders = await _foldersForAi();
    final messages = buildClusterMessages([for (final row in rows) _itemForAi(row, null)], folders);
    final String content;
    try {
      content = await client.chat(model: _settings.ai.sortModel, messages: messages, responseFormat: const {'type': 'json_object'});
      await _log(null, messages, content, null);
    } on AiFailure catch (failure) {
      await _log(null, messages, null, failure.toString());
      if (failure.kind == AiFailureKind.auth || failure.kind == AiFailureKind.payment) await _settings.pause(failure.kind.name);
      return 0;
    }
    final decision = parseClusterDecision(content, {for (final row in rows) row.id});
    if (decision == null) return 0;
    for (final proposed in decision.folders) {
      final folderId = await _createFolder(proposed.name, proposed.icon);
      await (_db.update(_db.items)..where((t) => t.id.isIn(proposed.itemIds) & t.folderId.isNull() & t.sortedBy.equalsValue(SortedBy.none))).write(
        ItemsCompanion(folderId: Value(folderId), sortedBy: const Value(SortedBy.ai), sortState: const Value(SortState.sorted), updatedAt: Value(_clock())),
      );
      await (_db.delete(_db.aiJobs)..where((t) => t.itemId.isIn(proposed.itemIds))).go();
    }
    return decision.folders.length;
  }

  ItemForAi _itemForAi(Item item, String? image) {
    final previewed = item.previewAt != null;
    final text = [if (!previewed) item.title, item.body, ?item.transcript].where((part) => part.trim().isNotEmpty).join('\n');
    return ItemForAi(
      id: item.id,
      kind: item.kind,
      text: text.isEmpty ? item.title : text,
      url: item.url,
      pageTitle: previewed ? item.title : null,
      pageDescription: item.previewText,
      imageBase64Jpeg: image,
    );
  }

  Future<List<FolderForAi>> _foldersForAi() async {
    final rows = await _db
        .customSelect(
          'SELECT folders.id, folders.name, '
          '(SELECT group_concat(name, char(31)) FROM (SELECT tags.name AS name FROM item_tags JOIN tags ON tags.id = item_tags.tag_id '
          'JOIN items ON items.id = item_tags.item_id WHERE items.folder_id = folders.id AND items.deleted_at IS NULL '
          'GROUP BY tags.name ORDER BY count(*) DESC LIMIT 3)) AS top_tags '
          'FROM folders WHERE folders.deleted_at IS NULL ORDER BY folders.sort_order',
        )
        .get();
    return [
      for (final row in rows)
        FolderForAi(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          topTags: (row.readNullable<String>('top_tags') ?? '').split('\x1f').where((tag) => tag.isNotEmpty).toList(),
        ),
    ];
  }

  Future<SortContext> _context(Item item) async {
    final tagRows = await _db
        .customSelect(
          'SELECT tags.name, count(item_tags.item_id) AS uses FROM tags LEFT JOIN item_tags ON item_tags.tag_id = tags.id '
          'GROUP BY tags.id ORDER BY uses DESC LIMIT 60',
        )
        .get();
    final examples = await _db
        .customSelect(
          'SELECT items.title, items.body, folders.name AS folder FROM corrections '
          'JOIN items ON items.id = corrections.item_id JOIN folders ON folders.id = corrections.to_folder_id '
          'ORDER BY corrections."at" DESC LIMIT 20',
        )
        .get();
    // кандидаты для связей — тем же поиском похожего, что и «Связано», только щедрее
    final docRows = await _db.customSelect("SELECT id, title, title || ' ' || body AS text FROM items WHERE deleted_at IS NULL").get();
    final docs = [for (final row in docRows) RelatedDoc(id: row.read<String>('id'), text: row.read<String>('text'))];
    final titles = {for (final row in docRows) row.read<String>('id'): (row.read<String>('title'), row.read<String>('text'))};
    final candidates = findRelated(item.id, docs, limit: 25, minScore: 0.5);

    String? image;
    final root = _filesRoot;
    final picture = await (_db.select(_db.attachments)
          ..where((t) => t.itemId.equals(item.id) & t.mime.like('image/%'))
          ..orderBy([(t) => OrderingTerm.asc(t.position)])
          ..limit(1))
        .getSingleOrNull();
    if (picture != null && root != null && imageForAi != null) {
      image = await imageForAi!(p.join(root.path, picture.path), width: picture.width, height: picture.height);
    }

    return SortContext(
      item: _itemForAi(item, image),
      folders: await _foldersForAi(),
      tags: [for (final row in tagRows) TagForAi(name: row.read<String>('name'), count: row.read<int>('uses'))],
      examples: [for (final row in examples) CorrectionExample(text: '${row.read<String>('title')} ${row.read<String>('body')}', folderName: row.read<String>('folder'))],
      candidates: [
        for (final one in candidates) LinkCandidate(id: one.id, title: titles[one.id]!.$1, snippet: titles[one.id]!.$2),
      ],
      now: _clock(),
      timeZone: _timeZone,
    );
  }

  Future<void> _apply(Item asked, SortDecision decision) async {
    String? folderId;
    String? folderName;
    await _db.transaction(() async {
      // пока модель думала, человек мог переложить вещь сам: читаем её заново
      final item = await (_db.select(_db.items)..where((t) => t.id.equals(asked.id))).getSingle();
      // человек или правило успели разложить: ответ даёт только описание для поиска
      if (item.sortedBy == SortedBy.user || item.folderId != null) {
        await (_db.update(_db.items)..where((t) => t.id.equals(item.id))).write(ItemsCompanion(aiDescription: Value(decision.description)));
        return;
      }
      folderId = decision.folderId;
      if (folderId == null && decision.newFolder != null) folderId = await _createFolder(decision.newFolder!.name, decision.newFolder!.icon);
      if (folderId != null) {
        folderName = (await (_db.select(_db.folders)..where((t) => t.id.equals(folderId!))).getSingle()).name;
      }
      final autoTitle = item.title.trim().isEmpty || item.title.startsWith('http') || item.title == item.url;
      await (_db.update(_db.items)..where((t) => t.id.equals(item.id))).write(
        ItemsCompanion(
          folderId: Value(folderId),
          sortedBy: Value(folderId == null ? SortedBy.none : SortedBy.ai),
          sortState: const Value(SortState.sorted),
          aiDescription: Value(decision.description),
          title: decision.title != null && autoTitle ? Value(decision.title!) : const Value.absent(),
          reminderAt: item.reminderAt == null && decision.reminder != null ? Value(decision.reminder) : const Value.absent(),
        ),
      );
      final icons = {for (final tag in decision.newTags) tag.name: tag.icon};
      for (final name in {...decision.tagNames, ...icons.keys}) {
        final tagId = await _ensureTag(name, icons[name]);
        await _db.into(_db.itemTags).insert(ItemTagsCompanion.insert(itemId: item.id, tagId: tagId, source: TagSource.ai), mode: InsertMode.insertOrIgnore);
      }
      for (final link in decision.links) {
        await _db
            .into(_db.links)
            .insert(LinksCompanion.insert(fromId: item.id, toId: link.id, source: LinkSource.ai, reason: Value(link.reason)), mode: InsertMode.insertOrIgnore);
      }
    });
    if (folderName != null) _sorted.add(AiSorted(itemId: asked.id, folderId: folderId!, folderName: folderName!));
  }

  /// Ссылка ещё ждёт превью, фото ещё копируется: подождать, иначе модель увидит голый адрес или имя файла.
  Future<bool> _notReady(Item item) async {
    if (_clock().difference(item.createdAt) > _readyWait) return false;
    if (item.url != null && item.previewAt == null) return true;
    if (item.kind != ItemKind.image) return false;
    final pictures = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(item.id))).get();
    return pictures.isEmpty;
  }

  Future<String> _ensureTag(String rawName, String? icon) async {
    final name = normalizeTagName(rawName);
    final existing = await (_db.select(_db.tags)..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.id;
    final id = const Uuid().v4();
    await _db.into(_db.tags).insert(TagsCompanion.insert(id: id, name: name, createdAt: _clock(), iconValue: icon == null ? const Value.absent() : Value(icon)));
    return id;
  }

  Future<String> _createFolder(String rawName, String icon) async {
    final name = rawName.trim()[0].toUpperCase() + rawName.trim().substring(1);
    final same = await (_db.select(_db.folders)..where((t) => t.name.lower().equals(name.toLowerCase()) & t.deletedAt.isNull())).getSingleOrNull();
    if (same != null) return same.id;
    final count = await _db.folders.count().getSingle();
    const shapes = ['cookie9', 'squircle', 'gem', 'pill', 'cookie6'];
    final id = const Uuid().v4();
    await _db
        .into(_db.folders)
        .insert(FoldersCompanion.insert(id: id, name: name, icon: icon, shape: shapes[count % shapes.length], sortOrder: Value(count), createdByAi: const Value(true)));
    return id;
  }

  Future<void> _fail(AiJob job, String error) async {
    final attempts = job.attempts + 1;
    await (_db.update(_db.aiJobs)..where((t) => t.itemId.equals(job.itemId))).write(
      AiJobsCompanion(attempts: Value(attempts), nextTryAt: Value(_clock().add(nextTryDelay(attempts))), lastError: Value(error)),
    );
    await (_db.update(_db.items)..where((t) => t.id.equals(job.itemId) & t.sortedBy.equalsValue(SortedBy.none))).write(const ItemsCompanion(sortState: Value(SortState.failed)));
  }

  Future<void> _dropJob(String itemId) => (_db.delete(_db.aiJobs)..where((t) => t.itemId.equals(itemId))).go();

  Future<void> _log(String? itemId, List<Map<String, Object?>> messages, String? response, String? error) async {
    String cut(String text) => text.length > 4000 ? text.substring(0, 4000) : text;
    // картинку в журнал не кладём: base64 раздувал бы базу
    final request = cut(jsonEncode(messages).replaceAll(RegExp(r'data:image/jpeg;base64,[A-Za-z0-9+/=]+'), 'data:image/jpeg;base64,…'));
    await _db
        .into(_db.aiLog)
        .insert(AiLogCompanion.insert(at: _clock(), itemId: Value(itemId), request: request, response: Value(response == null ? null : cut(response)), error: Value(error)));
    await _db.customStatement('DELETE FROM ai_log WHERE id NOT IN (SELECT id FROM ai_log ORDER BY id DESC LIMIT $_logKeep)');
  }
}
