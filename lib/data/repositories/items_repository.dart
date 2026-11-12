import 'package:drift/drift.dart';

import 'package:flutter/painting.dart' show Color;

import '../../core/theme/folder_palette.dart';
import '../../domain/folder_guess.dart';
import '../../domain/image_fingerprint.dart';
import '../../domain/item_kind.dart';
import '../../domain/line_query.dart' show searchWords;
import '../../domain/models.dart';
import '../../domain/money.dart' show sumByCurrency;
import '../../domain/place_groups.dart';
import '../../domain/qr.dart' show QrKind, parseQr;
import '../../domain/related.dart';
import '../../domain/search_query.dart';
import '../../domain/search_rank.dart';
import '../../domain/url_key.dart';
import '../../domain/vault_note.dart' show packVaultProperties;
import '../../domain/word_forms.dart';
import '../../services/reminder_service.dart' show Reminder, hiddenReminderPayload, reminderText;
import '../db/database.dart';

/// Вещь целиком: запись, теги с источником и вложения по порядку.
class ItemFull {
  const ItemFull({required this.item, required this.tags, required this.attachments, this.copying = 0});

  final Item item;
  final Map<String, TagSource> tags;
  final List<Attachment> attachments;

  /// Сколько файлов ещё ложится во вложения.
  final int copying;
}

/// Карточка для лент: то, что нужно, чтобы нарисовать вещь в списке.
class ItemCard {
  const ItemCard({
    required this.id,
    required this.title,
    required this.kind,
    required this.folderId,
    required this.sortState,
    required this.createdAt,
    this.body = '',
    this.url,
    this.folderName,
    this.folderIcon,
    this.folderColor,
    this.reminderAt,
    this.thumbPath,
    this.thumbRatio,
    this.tags = const [],
    this.filePath,
    this.fileMime,
    this.fileSize = 0,
    this.transcript,
    this.durationSeconds,
    this.latitude,
    this.longitude,
    this.placeName,
    this.copying = 0,
    this.gone = false,
    this.hasCopy = false,
    this.mainColor,
  });

  /// Главный цвет картинки или обложки «#1E3CC8»: доска «по цвету». Нет картинки — null.
  final String? mainColor;

  /// Сколько файлов вещи ещё ложится во вложения.
  final int copying;

  /// Ссылка больше не открывается; [hasCopy] — текст статьи сохранён в Stowa.
  final bool gone;
  final bool hasCopy;

  /// Та же карточка в другом месте: событие и заведение стоят на карте там, где они есть.
  /// Та же карточка в другой точке. [name] null — имя места не известно: прежнее имя
  /// места сохранения к новой точке не относится и тоже снимается.
  ItemCard placedAt(double latitude, double longitude, String? name) => ItemCard(
    id: id,
    title: title,
    kind: kind,
    folderId: folderId,
    sortState: sortState,
    createdAt: createdAt,
    body: body,
    url: url,
    folderName: folderName,
    folderIcon: folderIcon,
    folderColor: folderColor,
    reminderAt: reminderAt,
    thumbPath: thumbPath,
    thumbRatio: thumbRatio,
    tags: tags,
    filePath: filePath,
    fileMime: fileMime,
    fileSize: fileSize,
    transcript: transcript,
    durationSeconds: durationSeconds,
    latitude: latitude,
    longitude: longitude,
    placeName: name,
    copying: copying,
    gone: gone,
    hasCopy: hasCopy,
    mainColor: mainColor,
  );

  /// Где вещь сохранена. Пусто — место не снималось.
  final double? latitude;
  final double? longitude;
  final String? placeName;

  final String id;
  final String title;
  final ItemKind kind;
  final String? folderId;
  final SortState sortState;
  final DateTime createdAt;
  final String body;
  final String? url;
  final String? folderName;
  final String? folderIcon;

  /// Цвет папки из палитры: метка заметки в ленте того же цвета, что и папка.
  final Color? folderColor;
  final DateTime? reminderAt;

  /// Первая картинка вещи, путь от папки приложения.
  final String? thumbPath;

  /// Высота к ширине первой картинки; неизвестна у сохранённых до учёта размеров.
  final double? thumbRatio;
  final List<String> tags;

  /// Первое вложение любого вида: голосовое, ролик, файл.
  final String? filePath;
  final String? fileMime;
  final int fileSize;
  final String? transcript;

  /// Длина ролика по ссылке, если страница её назвала.
  final int? durationSeconds;
}

/// Вещи и связи между ними для графа.
class GraphData {
  const GraphData({required this.nodes, required this.edges});

  final List<ItemCard> nodes;
  final List<(String, String)> edges;
}

/// Другая заметка с той же ссылкой или той же картинкой.
class RepeatNote {
  const RepeatNote({required this.id, required this.title, required this.folderName, required this.createdAt});

  final String id;
  final String title;
  final String? folderName;
  final DateTime createdAt;
}

/// Вещь сохранена дома или на работе, если не дальше этого от их середины: двор и офисное здание.
const _markMeters = 250.0;

/// Куда переложили, если в «Без папки»: в исправлениях это пустая строка, а не id папки.
const noFolder = '';

/// Что нашёл поиск и каким запросом: с фильтрами или, если они ничего не дали, простыми словами.
class SearchFound {
  const SearchFound(this.results, this.query, {this.spentFolder, this.total = const []});

  static const none = SearchFound([], SearchQuery());

  final List<SearchResult> results;
  final SearchQuery query;

  /// «Потратил на ремонт»: папка, которую узнал поиск, и итог по валютам всех её заметок с ценой.
  final String? spentFolder;
  final List<(double, String)> total;
}

/// Найденная вещь: карточка и что в ней совпало.
class SearchResult {
  const SearchResult({required this.card, required this.hit});

  final ItemCard card;
  final SearchHit hit;
}

// карточка целиком: вещь, её папка, первая картинка и теги одним запросом
const _cardSelect = '''
SELECT items.*, folders.name AS folder_name, folders.icon AS folder_icon, folders.color AS folder_color, folders.sort_order AS folder_order,
  -- своя картинка главнее, у ссылки и ролика без неё — обложка превью
  coalesce((SELECT attachments.path FROM attachments
    WHERE attachments.item_id = items.id AND attachments.mime LIKE 'image/%'
    ORDER BY attachments.position LIMIT 1), items.cover_path) AS thumb_path,
  -- пропорция того, что на плитке: своей картинки, а без неё — кадра своего ролика
  coalesce((SELECT CAST(attachments.height AS REAL) / attachments.width FROM attachments
    WHERE attachments.item_id = items.id AND attachments.mime LIKE 'image/%' AND attachments.width > 0
    ORDER BY attachments.position LIMIT 1),
  (SELECT CAST(attachments.height AS REAL) / attachments.width FROM attachments
    WHERE attachments.item_id = items.id AND attachments.mime LIKE 'video/%' AND attachments.width > 0
      AND NOT EXISTS (SELECT 1 FROM attachments AS pictures WHERE pictures.item_id = items.id AND pictures.mime LIKE 'image/%')
    ORDER BY attachments.position LIMIT 1)) AS thumb_ratio,
  (SELECT group_concat(tags.name, char(31)) FROM item_tags JOIN tags ON tags.id = item_tags.tag_id
    WHERE item_tags.item_id = items.id) AS tag_names,
  (SELECT attachments.path || char(31) || attachments.mime || char(31) || attachments.size FROM attachments
    WHERE attachments.item_id = items.id ORDER BY attachments.position LIMIT 1) AS first_file,
  (SELECT count(*) FROM file_jobs WHERE file_jobs.item_id = items.id) AS copying,
  -- у мёртвой ссылки — сохранён ли текст статьи; у живой не важно, лишнего запроса нет
  CASE WHEN items.gone_at IS NULL THEN 0
    ELSE EXISTS (SELECT 1 FROM facts WHERE facts.item_id = items.id AND facts.kind = 'articleText') END AS has_copy,
  (SELECT facts.detail FROM facts WHERE facts.item_id = items.id AND facts.extractor = 'colors'
    ORDER BY facts.position LIMIT 1) AS main_color
FROM items LEFT JOIN folders ON folders.id = items.folder_id AND folders.deleted_at IS NULL
WHERE items.deleted_at IS NULL''';

class ItemsRepository {
  ItemsRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Сейчас: догадка угадывателя становится образцом через неделю ([folderDocs]).
  final DateTime Function() _clock;

  final AppDatabase _db;

  /// Текст вещи поправили: факты из него пересчитываются, не дожидаясь запуска.
  void Function(String itemId)? onEdited;

  // таблицы карточки: лента перерисуется, когда изменится любая
  Set<ResultSetImplementation<dynamic, dynamic>> get _cardTables => {_db.items, _db.folders, _db.attachments, _db.fileJobs, _db.itemTags, _db.tags};

  /// Лежит ли уже в заметках картинка из галереи: то же имя файла и тот же размер в точках.
  /// Путь бывает во входящих с номером порядка («0_имя») и у заметки без него.
  Future<bool> hasPicture(String name, int width, int height) async {
    final rows = await _db
        .customSelect(
          'SELECT attachments.path AS path FROM attachments JOIN items ON items.id = attachments.item_id '
          'WHERE items.deleted_at IS NULL AND attachments.width = ? AND attachments.height = ? AND attachments.path LIKE ?',
          variables: [Variable.withInt(width), Variable.withInt(height), Variable.withString('%$name')],
          readsFrom: {_db.attachments, _db.items},
        )
        .get();
    return rows.any((row) => row.read<String>('path').split('/').last.replaceFirst(RegExp(r'^\d+_'), '') == name);
  }

  /// Самая ранняя другая заметка с той же ссылкой или той же картинкой, иначе null.
  /// Ссылки сравниваются по [urlKey], картинки — отпечатком не дальше [repeatDistance] бит.
  Future<RepeatNote?> repeatOf(String id) async {
    final self = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (self == null) return null;
    final repeats = <String>{};
    if (self.url case final url?) {
      final key = urlKey(url);
      final linked = await (_db.select(_db.items)..where((t) => t.url.isNotNull() & t.deletedAt.isNull() & t.id.equals(id).not())).get();
      repeats.addAll([for (final other in linked) if (urlKey(other.url!) == key) other.id]);
    }
    final prints = await (_db.select(_db.facts)..where((t) => t.kind.equals(FactKind.fingerprint.name))).get();
    final mine = [for (final fact in prints) if (fact.itemId == id) parseFingerprint(fact.value)];
    if (mine.isNotEmpty) {
      for (final fact in prints) {
        if (fact.itemId == id) continue;
        final other = parseFingerprint(fact.value);
        if (mine.any((print) => fingerprintDistance(print, other) <= repeatDistance)) repeats.add(fact.itemId);
      }
    }
    if (repeats.isEmpty) return null;
    final query = _db.select(_db.items).join([leftOuterJoin(_db.folders, _db.folders.id.equalsExp(_db.items.folderId) & _db.folders.deletedAt.isNull())])
      ..where(_db.items.id.isIn(repeats) & _db.items.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(_db.items.createdAt)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    final item = row.readTable(_db.items);
    return RepeatNote(id: item.id, title: item.title, folderName: row.readTableOrNull(_db.folders)?.name, createdAt: item.createdAt);
  }

  /// Повтор, который обновляется, когда меняются заметки или их факты: отпечаток картинки приходит позже.
  Stream<RepeatNote?> watchRepeatOf(String id) =>
      _db.customSelect('SELECT 1', readsFrom: {_db.items, _db.facts, _db.folders}).watch().asyncMap((_) => repeatOf(id));

  Future<ItemFull?> get(String id) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (item == null) return null;
    final tagRows = await (_db.select(_db.itemTags).join([
      innerJoin(_db.tags, _db.tags.id.equalsExp(_db.itemTags.tagId)),
    ])..where(_db.itemTags.itemId.equals(id))).get();
    final attachments =
        await (_db.select(_db.attachments)
              ..where((t) => t.itemId.equals(id))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    final copying = await (_db.select(_db.fileJobs)..where((t) => t.itemId.equals(id))).get();
    return ItemFull(
      item: item,
      tags: {for (final row in tagRows) row.readTable(_db.tags).name: row.readTable(_db.itemTags).source},
      attachments: attachments,
      copying: copying.length,
    );
  }

  /// Последние живые вещи, новые первыми. Ничья разрешается по id, иначе
  /// SQLite отдаёт равные строки в любом порядке, и лента тасуется сама.
  Stream<List<ItemCard>> watchRecent({int limit = 20}) {
    return _db
        .customSelect(
          '$_cardSelect ORDER BY items.created_at DESC, items.id DESC LIMIT ?',
          variables: [Variable.withInt(limit)],
          readsFrom: _cardTables,
        )
        .watch()
        .map((rows) => [for (final row in rows) _card(row)]);
  }

  /// Карточки этих заметок в том же порядке: экраны возврата получают список id, а рисуют ленту.
  Stream<List<ItemCard>> watchCards(List<String> ids) {
    if (ids.isEmpty) return Stream.value(const []);
    return _db
        .customSelect('$_cardSelect AND items.id IN (${List.filled(ids.length, '?').join(', ')})', variables: [for (final id in ids) Variable.withString(id)], readsFrom: _cardTables)
        .watch()
        .map((rows) {
          final cards = {for (final row in rows) row.read<String>('id'): _card(row)};
          return [for (final id in ids) ?cards[id]];
        });
  }

  /// Ближайшие напоминания с этого момента, по времени. Их мало, поэтому
  /// отбор идёт в Dart: время хранится текстом, сравнивать строки ненадёжно.
  Stream<List<ItemCard>> watchUpcoming(DateTime now, {int limit = 3}) {
    return _db
        .customSelect('$_cardSelect AND items.reminder_at IS NOT NULL', readsFrom: _cardTables)
        .watch()
        .map((rows) {
      final cards = [for (final row in rows) _card(row)].where((card) => !card.reminderAt!.isBefore(now)).toList()
        ..sort((a, b) => a.reminderAt!.compareTo(b.reminderAt!));
      return cards.take(limit).toList();
    });
  }

  static const _folderDocsSql = '''
SELECT items.folder_id AS folder_id, items.kind AS kind, items.url AS url,
  items.title || ' ' || items.body || ' ' || coalesce(items.ai_description, '') || ' ' || coalesce(items.transcript, '') || ' ' ||
  coalesce(items.preview_text, '') || ' ' ||
  coalesce((SELECT group_concat(tags.name, ' ') FROM item_tags JOIN tags ON tags.id = item_tags.tag_id
    WHERE item_tags.item_id = items.id), '') AS text,
  (SELECT attachments.path FROM attachments WHERE attachments.item_id = items.id ORDER BY attachments.position LIMIT 1) AS file_path,
  -- кто разложил и подтвердил ли человек: догадки угадывателя образцом идут не сразу
  items.sorted_by AS sorted_by, items.opened_at AS opened_at, items.created_at AS created_at
FROM items JOIN folders ON folders.id = items.folder_id AND folders.deleted_at IS NULL
WHERE items.deleted_at IS NULL''';

  /// Догадка угадывателя (`similar`) становится образцом папки, когда человек её подтвердил:
  /// открыл заметку и оставил там или неделю не перекладывал. Неподтверждённая — не образец:
  /// одна ошибка («смета» к статьям) иначе тянет следующие по тем же приметам, и так по кругу.
  static const _confirmAfter = Duration(days: 7);

  bool _isSample(QueryRow row, DateTime now) {
    if (row.read<String>('sorted_by') != SortedBy.similar.name) return true;
    if (row.data['opened_at'] != null) return true;
    final created = _db.typeMapping.read(DriftSqlType.dateTime, row.data['created_at'])!;
    return now.difference(created) >= _confirmAfter;
  }

  FolderDoc _folderDoc(QueryRow row) => FolderDoc(
    folderId: row.read<String>('folder_id'),
    text: row.read<String>('text'),
    signals: itemSignals(kind: ItemKind.values.byName(row.read<String>('kind')), url: row.readNullable<String>('url'), fileName: row.readNullable<String>('file_path')),
  );

  /// Имена живых папок: по ним угадыватель видит тему ещё пустой папки.
  Future<List<FolderLabel>> folderLabels() async => [
    for (final folder in await (_db.select(_db.folders)..where((t) => t.deletedAt.isNull())).get()) FolderLabel(folder.id, folder.name),
  ];

  // заметки, которые человек вынул из папки и не вернул: их слова от неё отталкивают
  static const _rejectedSql = '''
SELECT corrections.from_folder_id AS folder_id, items.title || ' ' || items.body AS text
FROM corrections JOIN items ON items.id = corrections.item_id
WHERE corrections.from_folder_id IS NOT NULL AND items.deleted_at IS NULL
  AND items.folder_id IS NOT corrections.from_folder_id''';

  Future<List<FolderDoc>> rejectedDocs() async => [
    for (final row in await _db.customSelect(_rejectedSql).get()) FolderDoc(folderId: row.read<String>('folder_id'), text: row.read<String>('text')),
  ];

  /// Угадыватель целиком: заметки папок, их имена и вынутое человеком.
  Future<FolderIndex> folderIndex() async => FolderIndex(await folderDocs(), labels: await folderLabels(), rejected: await rejectedDocs());

  /// [folderIndex], пересобранный при правке заметок, папок и исправлениях: строка ввода
  /// показывает, куда ляжет заметка, ещё до «Закинуть». Поток смотрит на сами строки
  /// всех трёх источников: одинаковый результат drift не повторяет.
  Stream<FolderIndex> watchFolderIndex() => _db
      .customSelect(
        'SELECT (SELECT count(*) FROM items WHERE deleted_at IS NULL) AS alive, (SELECT max(updated_at) FROM items) AS edited, '
        '(SELECT group_concat(id || name || coalesce(deleted_at, \'\')) FROM folders) AS folders, (SELECT count(*) FROM corrections) AS corrected',
        readsFrom: {_db.items, _db.folders, _db.corrections, _db.itemTags},
      )
      .watch()
      .asyncMap((_) => folderIndex());

  /// Всё, что уже разложено по живым папкам: из этого учится угадыватель папки.
  Future<List<FolderDoc>> folderDocs() async {
    final now = _clock();
    return [for (final row in await _db.customSelect(_folderDocsSql).get()) if (_isSample(row, now)) _folderDoc(row)];
  }

  Stream<List<FolderDoc>> watchFolderDocs() => _db
      .customSelect(_folderDocsSql, readsFrom: {_db.items, _db.folders, _db.itemTags, _db.tags})
      .watch()
      .map((rows) {
        final now = _clock();
        return [for (final row in rows) if (_isSample(row, now)) _folderDoc(row)];
      });

  /// Вещи, связанные с [id] общими редкими словами или сайтом, с причиной.
  /// Пересчитываются, когда меняются вещи или человек отклонил связь.
  Stream<List<({ItemCard card, Related why})>> watchRelated(String id) {
    return _db.customSelect('SELECT 1', readsFrom: {_db.items, _db.links}).watch().asyncMap((_) async {
      final rows = await _db
          .customSelect(
            "SELECT items.id, items.url, items.title || ' ' || items.body || ' ' || coalesce(items.transcript, '') || ' ' || "
            "coalesce(items.preview_text, '') AS text FROM items WHERE items.deleted_at IS NULL",
          )
          .get();
      final docs = [
        for (final row in rows)
          RelatedDoc(
            id: row.read<String>('id'),
            text: row.read<String>('text'),
            site: switch (row.readNullable<String>('url')) {
              final url? => Uri.tryParse(url)?.host.replaceFirst(RegExp(r'^www\.'), ''),
              null => null,
            },
          ),
      ];
      final refused = await (_db.select(_db.links)..where((t) => t.rejected.equals(true) & (t.fromId.equals(id) | t.toId.equals(id)))).get();
      final related = findRelated(id, docs, rejected: {for (final link in refused) link.fromId == id ? link.toId : link.fromId});
      if (related.isEmpty) return const <({ItemCard card, Related why})>[];
      final cards = await _db
          .customSelect(
            '$_cardSelect AND items.id IN (${List.filled(related.length, '?').join(',')})',
            variables: [for (final one in related) Variable.withString(one.id)],
          )
          .get();
      final byId = {for (final row in cards) row.read<String>('id'): _card(row)};
      return [
        for (final one in related)
          if (byId[one.id] case final card?) (card: card, why: one),
      ];
    });
  }

  /// Граф папки или тега: вещи точками, связи — от ИИ, ручные и похожие по словам,
  /// как в «Связано». Отклонённые человеком не рисуются.
  Future<GraphData> graph({String? folderId, String? tag}) async {
    final scope = await _db
        .customSelect(
          folderId != null
              ? '$_cardSelect AND items.folder_id = ?'
              : '$_cardSelect AND items.id IN (SELECT item_tags.item_id FROM item_tags JOIN tags ON tags.id = item_tags.tag_id WHERE tags.name = ?)',
          variables: [Variable.withString(folderId ?? tag!)],
        )
        .get();
    final cards = [for (final row in scope) _card(row)];
    final inside = {for (final card in cards) card.id};

    final links = await (_db.select(_db.links)..where((t) => t.fromId.isIn(inside) | t.toId.isIn(inside))).get();
    final refused = {for (final link in links) if (link.rejected) _pair(link.fromId, link.toId)};
    final edges = <String>{
      for (final link in links)
        if (!link.rejected && inside.contains(link.fromId) && inside.contains(link.toId)) _pair(link.fromId, link.toId),
    };

    // похожие считаются по всей базе: редкость слова меряется на всех вещах
    final rows = await _db
        .customSelect(
          "SELECT items.id, items.url, items.title || ' ' || items.body || ' ' || coalesce(items.transcript, '') || ' ' || "
          "coalesce(items.preview_text, '') AS text FROM items WHERE items.deleted_at IS NULL",
        )
        .get();
    final docs = [
      for (final row in rows)
        RelatedDoc(
          id: row.read<String>('id'),
          text: row.read<String>('text'),
          site: switch (row.readNullable<String>('url')) {
            final url? => Uri.tryParse(url)?.host.replaceFirst(RegExp(r'^www\.'), ''),
            null => null,
          },
        ),
    ];
    for (final card in cards) {
      for (final one in findRelated(card.id, docs, limit: 3)) {
        final pair = _pair(card.id, one.id);
        if (inside.contains(one.id) && !refused.contains(pair)) edges.add(pair);
      }
    }
    return GraphData(
      nodes: cards,
      edges: [
        for (final pair in edges)
          if (pair.split('|') case [final a, final b]) (a, b),
      ],
    );
  }

  /// Связь без направления: A—B и B—A одна и та же.
  String _pair(String a, String b) => a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

  /// Человек сказал, что вещи не связаны: больше не предлагать.
  Future<void> rejectRelated(String id, String otherId) {
    return _db
        .into(_db.links)
        .insert(LinksCompanion.insert(fromId: id, toId: otherId, source: LinkSource.similar, rejected: const Value(true)), mode: InsertMode.insertOrReplace);
  }

  /// Вернуть отклонённую связь: «Отменить» сразу после.
  Future<void> restoreRelated(String id, String otherId) {
    return (_db.delete(_db.links)..where((t) => t.fromId.equals(id) & t.toId.equals(otherId) & t.rejected.equals(true))).go();
  }

  /// Все живые напоминания: по ним ставятся будильники системы.
  /// Напоминания живых заметок. У скрытой — [hiddenTitle] без текста: уведомление видно
  /// на экране блокировки, а скрытое должно оставаться скрытым.
  Stream<List<Reminder>> watchReminders({String hiddenTitle = ''}) {
    return _db
        .customSelect(
          'SELECT items.*, coalesce(folders.hidden, 0) AS in_hidden FROM items LEFT JOIN folders ON folders.id = items.folder_id '
          'WHERE items.reminder_at IS NOT NULL AND items.deleted_at IS NULL',
          readsFrom: {_db.items, _db.folders},
        )
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              row.read<bool>('in_hidden')
                  ? (id: hiddenReminderPayload(row.read<String>('id')), title: hiddenTitle, body: '', at: row.read<DateTime>('reminder_at'))
                  : _reminder(_db.items.map(row.data)),
          ],
        );
  }

  Reminder _reminder(Item row) => (id: row.id, title: row.title, body: reminderText(row.title, row.body), at: row.reminderAt!);

  /// «Через час» на уведомлении: то же напоминание позже. Вернёт его, чтобы сразу поставить будильник.
  Future<Reminder?> snoozeReminder(String id, DateTime at) async {
    await (_db.update(_db.items)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(ItemsCompanion(reminderAt: Value(at)));
    final row = await (_db.select(_db.items)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _reminder(row);
  }

  /// Вещи папки, новые первыми; без id — всё, что лежит без папки.
  Stream<List<ItemCard>> watchFolder(String? folderId) {
    return _db
        .customSelect(
          '$_cardSelect AND ${folderId == null ? 'items.folder_id IS NULL' : 'items.folder_id = ?'} ORDER BY items.created_at DESC, items.id DESC',
          variables: [if (folderId != null) Variable.withString(folderId)],
          readsFrom: _cardTables,
        )
        .watch()
        .map((rows) => [for (final row in rows) _card(row)]);
  }

  /// Вещь целиком и дальше при каждой правке.
  Stream<ItemFull?> watchItem(String id) {
    return _db.customSelect('SELECT 1', readsFrom: {_db.items, _db.itemTags, _db.tags, _db.attachments, _db.fileJobs}).watch().asyncMap((_) => get(id));
  }

  /// Человек переложил вещь сам: ИИ её больше не трогает, а пример запоминается.
  Future<void> moveToFolder(String id, String? folderId, DateTime at) async {
    await _db.transaction(() async {
      final item = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingle();
      await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
        ItemsCompanion(folderId: Value(folderId), sortedBy: const Value(SortedBy.user), sortState: const Value(SortState.sorted), updatedAt: Value(at)),
      );
      // и «вынул в „Без папки“» — тоже урок: эта заметка не для той папки ([noFolder])
      if (folderId != item.folderId) {
        await _db
            .into(_db.corrections)
            .insert(
              CorrectionsCompanion.insert(id: '$id-${at.microsecondsSinceEpoch}', itemId: id, fromFolderId: Value(item.folderId), toFolderId: folderId ?? noFolder, at: at),
              // «Отменить» сразу после переноса приходит в тот же миг: последнее решение и есть пример
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  /// Правка на странице вещи: заголовок и текст разом. Без файлов вид и адрес
  /// считаются по новому тексту: дописал к ссылке заметку — стала заметкой.
  Future<void> setTitleBody(String id, {required String title, required String body, required DateTime at}) async {
    final files = await (_db.select(_db.attachments)..where((t) => t.itemId.equals(id))).get();
    // вид решает текст: заголовок от сайта длинный и сделал бы ссылку заметкой, а свой — не часть текста
    final text = body.trim().isEmpty ? title : body;
    final url = firstUrl(text);
    await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
      ItemsCompanion(
        title: Value(title),
        body: Value(body),
        updatedAt: Value(at),
        kind: files.isEmpty ? Value(detectKind(text: text)) : const Value.absent(),
        url: files.isEmpty ? Value(url?.toString()) : const Value.absent(),
      ),
    );
    onEdited?.call(id);
  }

  /// Напоминание руками со страницы вещи; null снимает.
  /// Заметку открыли: «ни разу не открыто» больше не про неё. Время правки и файл не трогаются.
  Future<void> markOpened(String id, DateTime at) => (_db.update(_db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(openedAt: Value(at)));

  /// Последняя открытая заметка не из корзины: с неё продолжается работа при запуске.
  Future<String?> lastOpenedId() async {
    final query = _db.select(_db.items)
      ..where((t) => t.openedAt.isNotNull() & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.openedAt)])
      ..limit(1);
    return (await query.getSingleOrNull())?.id;
  }

  /// Любая заметка не из корзины: запуск напоминает что-то из сохранённого.
  Future<String?> randomId() async {
    final row = await _db.customSelect('SELECT id FROM items WHERE deleted_at IS NULL ORDER BY RANDOM() LIMIT 1', readsFrom: {_db.items}).getSingleOrNull();
    return row?.read<String>('id');
  }

  /// Битые ссылки, которые человек ещё не решил: свежие смерти сверху.
  Stream<List<ItemCard>> watchDeadLinks() => _db
      .customSelect('$_cardSelect AND items.gone_at IS NOT NULL AND items.gone_kept = 0 ORDER BY items.gone_at DESC', readsFrom: _cardTables)
      .watch()
      .map((rows) => [for (final row in rows) _card(row)]);

  /// Оставить заметку с мёртвой ссылкой: из «Битых ссылок» она уходит, пометка на карточке остаётся.
  Future<void> keepDeadLink(String id) => (_db.update(_db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(goneKept: Value(true)));

  /// Где остановился в читалке: доля прокрутки. В файл хранилища не идёт.
  Future<void> setReadPosition(String id, double position) =>
      (_db.update(_db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(readPosition: Value(position.clamp(0, 1).toDouble())));

  Future<void> setReminder(String id, DateTime? at) {
    return (_db.update(_db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(reminderAt: Value(at)));
  }

  /// Когда заметка записана: человек переносит её на другой день или на «сейчас».
  Future<void> setCreated(String id, DateTime at) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingle();
    // правка не может быть старше самой заметки
    final updated = item.updatedAt.isBefore(at) ? at : item.updatedAt;
    await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(createdAt: Value(at), updatedAt: Value(updated)));
  }

  /// Свойства заметки, которых Stowa не знает: набор целиком, как он ляжет в файл.
  Future<void> setProperties(String id, Map<String, Object?> properties, DateTime at) {
    return (_db.update(_db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(properties: Value(packVaultProperties(properties)), updatedAt: Value(at)));
  }

  Future<void> setBody(String id, String body, DateTime at) async {
    await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(body: Value(body), updatedAt: Value(at)));
    onEdited?.call(id);
  }

  /// «Дописать»: новая мысль ложится в конец старой заметки, второй заметки нет.
  Future<void> append(String id, String text, DateTime at) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingle();
    final body = item.body.trim().isEmpty ? text : '${item.body.trimRight()}\n\n$text';
    await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(body: Value(body), updatedAt: Value(at)));
    onEdited?.call(id);
  }

  /// «Готово» у напоминания: вещь остаётся, напоминание снимается.
  /// Напоминание по месту со страницы заметки; null снимает.
  Future<void> setPlaceReminder(String id, PlaceReminder? place) => (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
    ItemsCompanion(
      remindPlace: Value(place?.kind),
      remindLatitude: Value(place?.latitude),
      remindLongitude: Value(place?.longitude),
      remindPlaceName: Value(place?.name),
    ),
  );

  Future<void> clearReminder(String id) {
    return (_db.update(_db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(reminderAt: Value(null)));
  }

  /// Мягкое удаление: вещь пропадает из лент и поиска, чистка — через 30 дней.
  Future<void> softDelete(String id, DateTime at) {
    return (_db.update(_db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(deletedAt: Value(at)));
  }

  /// Вернуть удалённое, пока человек жмёт «Отменить».
  Future<void> restore(String id) {
    return (_db.update(_db.items)..where((t) => t.id.equals(id))).write(const ItemsCompanion(deletedAt: Value(null)));
  }

  /// Поиск строки ввода. Фильтры запроса (дата, вид, сайт, длина, «рядом»)
  /// отбирают вещи сами; не нашли ничего — запрос ищется простыми словами.
  /// [here] — где сейчас телефон, для «рядом».
  Future<SearchFound> search({required SearchQuery query, List<String> tags = const [], String? folderId, required DateTime now, (double, double)? here, int limit = 6}) async {
    if (query.spending) {
      final spent = await _searchSpent(query, tags: tags, folderId: folderId, now: now, here: here, limit: limit);
      if (spent.results.isNotEmpty) return spent;
      final plain = query.withoutFilters();
      return SearchFound(await _searchOnce(plain, tags: tags, folderId: folderId, now: now, here: here, limit: limit), plain);
    }
    if (query.hasFilters) {
      final results = await _searchOnce(query, tags: tags, folderId: folderId, now: now, here: here, limit: limit);
      if (results.isNotEmpty) return SearchFound(results, query);
      final plain = query.withoutFilters();
      return SearchFound(await _searchOnce(plain, tags: tags, folderId: folderId, now: now, here: here, limit: limit), plain);
    }
    return SearchFound(await _searchOnce(query, tags: tags, folderId: folderId, now: now, here: here, limit: limit), query);
  }

  /// Поиск умной папки: запрос разбирается заново на сегодня при каждой правке заметок,
  /// их фактов и папок. Поток смотрит на счётчики, которые меняет любая правка.
  Stream<SearchFound> watchSearch(String text, DateTime Function() clock) => _db
      .customSelect(
        'SELECT (SELECT count(*) FROM items WHERE deleted_at IS NULL) AS alive, (SELECT max(updated_at) FROM items) AS edited, '
        '(SELECT count(*) FROM facts) AS facts, (SELECT group_concat(folder_id) FROM items) AS placed',
        readsFrom: {_db.items, _db.facts, _db.folders},
      )
      .watch()
      .asyncMap((_) {
        final now = clock();
        return search(query: parseSearch(text, now), now: now, limit: 500);
      });

  // «потратил на ремонт»: слово с именем папки становится папкой (с вложенными), итог — по всем
  // подходящим заметкам, а не по тем, что влезли в панель. Без папки итог только у голого «потратил»
  Future<SearchFound> _searchSpent(SearchQuery query, {required List<String> tags, String? folderId, required DateTime now, (double, double)? here, required int limit}) async {
    final match = await _spentFolder(query.words);
    final restricted = match == null ? query : query.withWords([for (final word in query.words) if (word != match.word) word]);
    final inFolders = match == null ? null : await _folderTree(match.folder.id);
    final results = await _searchOnce(restricted, tags: tags, folderId: folderId, now: now, here: here, limit: limit, inFolders: inFolders);
    final counted = match != null || restricted.words.isEmpty;
    final total = counted ? await _priceTotal(await _admitted(restricted, here, inFolders: inFolders)) : const <(double, String)>[];
    return SearchFound(results, restricted, spentFolder: match?.folder.name, total: total);
  }

  // папка, чьё имя — одно из слов запроса в любой форме: «ремонт», «ремонте» — папка «Ремонт»
  Future<({Folder folder, QueryWord word})?> _spentFolder(List<QueryWord> words) async {
    if (words.isEmpty) return null;
    final folders = await (_db.select(_db.folders)..where((t) => t.deletedAt.isNull())).get();
    for (final word in words) {
      final stems = {for (final variant in word.variants) stemOf(variant.text)};
      for (final folder in folders) {
        final name = searchWords(folder.name);
        if (name.isNotEmpty && stems.contains(stemOf(name.first))) return (folder: folder, word: word);
      }
    }
    return null;
  }

  /// Папка и все вложенные в неё на любой глубине.
  Future<Set<String>> _folderTree(String folderId) async {
    final rows = await _db
        .customSelect(
          'WITH RECURSIVE tree(id) AS (SELECT ? UNION SELECT folders.id FROM folders JOIN tree ON folders.parent_id = tree.id) SELECT id FROM tree',
          variables: [Variable.withString(folderId)],
          readsFrom: {_db.folders},
        )
        .get();
    return {for (final row in rows) row.read<String>('id')};
  }

  // все цены заметок, сложенные по валютам
  Future<List<(double, String)>> _priceTotal(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return const [];
    final facts = await (_db.select(_db.facts)..where((t) => t.kind.equals(FactKind.price.name) & t.itemId.isIn(list) & t.number.isNotNull())).get();
    return sumByCurrency([for (final fact in facts) (fact.number!, fact.detail ?? '')]);
  }

  // цены заметок папки и вложенных, сложенные по валютам прямо в базе: поток смотрит на сам итог
  Selectable<(double, String)> _folderTotalQuery(String folderId) => _db
      .customSelect(
        'WITH RECURSIVE tree(id) AS (SELECT ? UNION SELECT folders.id FROM folders JOIN tree ON folders.parent_id = tree.id) '
        'SELECT coalesce(facts.detail, \'\') AS currency, sum(facts.number) AS amount FROM facts JOIN items ON items.id = facts.item_id '
        "WHERE facts.kind = 'price' AND facts.number IS NOT NULL AND items.deleted_at IS NULL AND items.folder_id IN (SELECT id FROM tree) "
        'GROUP BY coalesce(facts.detail, \'\') ORDER BY amount DESC',
        variables: [Variable.withString(folderId)],
        readsFrom: {_db.items, _db.facts, _db.folders},
      )
      .map((row) => (row.read<double>('amount'), row.read<String>('currency')));

  /// Сколько денег в заметках папки и вложенных: «Всего 23 150 лей · €40» на её экране.
  Future<List<(double, String)>> folderTotal(String folderId) => _folderTotalQuery(folderId).get();

  /// [folderTotal], пересчитанный при любой правке заметок, фактов и папок.
  Stream<List<(double, String)>> watchFolderTotal(String folderId) => _folderTotalQuery(folderId).watch();

  // кандидаты: с фильтрами — все подходящие под них, без фильтров — из индекса по основам
  // всех вариантов слов и последние вещи (там ловятся опечатки и имена папок); порядок решает [rankSearch]
  Future<List<SearchResult>> _searchOnce(
    SearchQuery query, {
    required List<String> tags,
    String? folderId,
    required DateTime now,
    (double, double)? here,
    required int limit,
    Set<String>? inFolders,
  }) async {
    final words = query.words;
    if (query.isEmpty && tags.isEmpty && folderId == null) return const [];
    final ids = <String>{};
    if (query.hasFilters) {
      ids.addAll(await _admitted(query, here, inFolders: inFolders));
    } else {
      if (words.isNotEmpty) {
        final stems = {for (final word in words) for (final variant in word.variants) stemOf(variant.text)};
        ids.addAll(await _db.searchIds(stems.map((stem) => '"$stem"*').join(' OR ')));
      }
      final recent = await _db
          .customSelect('SELECT items.id FROM items WHERE items.deleted_at IS NULL ORDER BY items.created_at DESC LIMIT 500', readsFrom: {_db.items})
          .get();
      ids.addAll(recent.map((row) => row.read<String>('id')));
    }
    if (!query.hasFilters && (tags.isNotEmpty || folderId != null)) {
      final filtered = await _db
          .customSelect(
            'SELECT DISTINCT items.id FROM items LEFT JOIN item_tags ON item_tags.item_id = items.id '
            'LEFT JOIN tags ON tags.id = item_tags.tag_id WHERE items.deleted_at IS NULL '
            '${folderId != null ? 'AND items.folder_id = ?' : ''} ${tags.isNotEmpty ? 'AND tags.name LIKE ?' : ''} LIMIT 500',
            variables: [if (folderId != null) Variable.withString(folderId), if (tags.isNotEmpty) Variable.withString('${tags.first}%')],
            readsFrom: {_db.items, _db.itemTags, _db.tags},
          )
          .get();
      ids.addAll(filtered.map((row) => row.read<String>('id')));
    }
    if (ids.isEmpty) return const [];

    final rows = await _db
        .customSelect(
          '$_cardSelect AND items.id IN (${List.filled(ids.length, '?').join(',')})',
          variables: [for (final id in ids) Variable.withString(id)],
          readsFrom: _cardTables,
        )
        .get();
    final cards = <String, ItemCard>{};
    final docs = <SearchDoc>[];
    final factParts = await _factParts(ids);
    for (final row in rows) {
      final card = _card(row);
      final item = _db.items.map(row.data);
      final tagNames = row.readNullable<String>('tag_names');
      cards[card.id] = card;
      docs.add(
        SearchDoc(
          id: card.id,
          title: card.title,
          body: card.body,
          tags: tagNames == null || tagNames.isEmpty ? const [] : tagNames.split('\x1f'),
          folderName: card.folderName,
          folderId: card.folderId,
          deep: [item.aiDescription, item.transcript].nonNulls.join('\n'),
          place: card.placeName ?? '',
          facts: factParts[card.id] ?? const [],
          url: card.url ?? '',
          ageDays: now.difference(item.updatedAt).inDays,
        ),
      );
    }
    return [
      for (final hit in rankSearch(docs, words, tagFilters: tags, folderFilter: folderId, filtered: query.hasFilters, limit: limit))
        SearchResult(card: cards[hit.doc.id]!, hit: hit),
    ];
  }

  // факты, по которым ищут: текст документов, страница ссылки, субтитры и главы ролика. Деньги,
  // телефоны и ссылки и так лежат в тексте вещи — в поле фактов они продублировали бы совпадения
  Future<Map<String, List<FactPart>>> _factParts(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    const kinds = [
      FactKind.fileText,
      FactKind.ingredient,
      FactKind.subtitle,
      FactKind.chapter,
      FactKind.venue,
      FactKind.address,
      FactKind.shop,
      FactKind.author,
      FactKind.site,
      FactKind.description,
      FactKind.hashtag,
      FactKind.year,
      FactKind.camera,
      FactKind.pageType,
      FactKind.articleText,
      FactKind.qr,
    ];
    final rows =
        await (_db.select(_db.facts)
              ..where((t) => t.itemId.isIn(ids) & t.kind.isIn([for (final kind in kinds) kind.name]))
              ..orderBy([(t) => OrderingTerm.asc(t.extractor), (t) => OrderingTerm.asc(t.position)]))
            .get();
    final parts = <String, List<FactPart>>{};
    // цитаты статьи с пометками — первыми: их выделил сам человек
    final highlights = await (_db.select(_db.highlights)..where((t) => t.itemId.isIn(ids))).get();
    for (final one in highlights) {
      parts.putIfAbsent(one.itemId, () => []).add(FactPart(FactKind.highlight, [one.quote, ?one.note].join('\n')));
    }
    for (final fact in rows) {
      final timed = fact.kind == FactKind.subtitle || fact.kind == FactKind.chapter;
      parts.putIfAbsent(fact.itemId, () => []).add(FactPart(fact.kind, _shownFact(fact), place: fact.kind == FactKind.fileText ? fact.detail : null, seconds: timed ? fact.number : null));
    }
    return parts;
  }

  // как факт виден под найденным: Wi-Fi из QR — именем сети, как на кнопке, без пароля
  String _shownFact(Fact fact) {
    if (fact.kind != FactKind.qr) return fact.value;
    final payload = parseQr(fact.value);
    return payload.kind == QrKind.wifi ? 'WiFi «${payload.network}»' : fact.value;
  }

  // вещи под фильтры запроса, свежие первыми; полей мало, поэтому проход по всем дешёвый
  // [inFolders] — только эти папки: траты по папке вместе с вложенными
  Future<List<String>> _admitted(SearchQuery query, (double, double)? here, {Set<String>? inFolders}) async {
    final rows = await _db
        .customSelect(
          'SELECT items.*, (SELECT attachments.path FROM attachments WHERE attachments.item_id = items.id '
          'ORDER BY attachments.position LIMIT 1) AS first_path FROM items WHERE items.deleted_at IS NULL '
          '${inFolders == null ? '' : 'AND items.folder_id IN (${List.filled(inFolders.length, '?').join(',')}) '}'
          'ORDER BY items.created_at DESC',
          variables: [for (final id in inFolders ?? const <String>{}) Variable.withString(id)],
          readsFrom: {_db.items, _db.attachments},
        )
        .get();
    final items = [for (final row in rows) (item: _db.items.map(row.data), file: row.readNullable<String>('first_path'))];
    // дом и работа — по тому, где человек сохраняет ночью и в будни днём
    final places = query.at == null
        ? (home: null, work: null)
        : homeAndWork([
            for (final (:item, file: _) in items)
              if (item.latitude != null && item.longitude != null) (latitude: item.latitude!, longitude: item.longitude!, at: item.createdAt),
          ]);
    // суммы, скриншоты и время чтения знают извлекатели: читаются, только когда о них спросили
    final prices = <String, List<(double, String)>>{};
    final screenshots = <String>{};
    final reading = <String, int>{};
    final colors = <String, Set<String>>{};
    final byLength = query.minSeconds != null || query.maxSeconds != null;
    if (query.minPrice != null || query.maxPrice != null || query.spending || query.screenshots || byLength || query.colors.isNotEmpty) {
      final kinds = [FactKind.price, FactKind.screenshot, if (byLength) FactKind.readingTime, if (query.colors.isNotEmpty) FactKind.color];
      final facts = await (_db.select(_db.facts)..where((t) => t.kind.isIn([for (final kind in kinds) kind.name]))).get();
      for (final fact in facts) {
        if (fact.kind == FactKind.color) {
          colors.putIfAbsent(fact.itemId, () => {}).add(fact.value);
        } else if (fact.kind == FactKind.screenshot) {
          screenshots.add(fact.itemId);
        } else if (fact.kind == FactKind.readingTime && fact.number != null) {
          reading[fact.itemId] = (fact.number! * 60).round();
        } else if (fact.number != null) {
          prices.putIfAbsent(fact.itemId, () => []).add((fact.number!, fact.detail ?? ''));
        }
      }
    }
    final ids = <String>[];
    for (final (:item, :file) in items) {
      final placed = item.latitude != null && item.longitude != null;
      final away = here == null || !placed ? null : metersBetween(here.$1, here.$2, item.latitude!, item.longitude!);
      final marks = {
        for (final (mark, place) in [(PlaceMark.home, places.home), (PlaceMark.work, places.work)])
          if (place != null && placed && metersBetween(place.latitude, place.longitude, item.latitude!, item.longitude!) <= _markMeters) mark,
      };
      final admitted = query.admits(
        createdAt: item.createdAt,
        kind: item.kind,
        url: item.url ?? '',
        fileName: '${item.title} ${file ?? ''}',
        // у статьи длина — сколько её читать: «статьи до 10 минут»
        durationSeconds: item.durationSeconds ?? reading[item.id],
        metersAway: away,
        marks: marks,
        prices: prices[item.id] ?? const [],
        screenshot: screenshots.contains(item.id),
        colors: colors[item.id] ?? const {},
      );
      if (admitted) ids.add(item.id);
      if (ids.length >= 500) break;
    }
    return ids;
  }

  ItemCard _card(QueryRow row) {
    final item = _db.items.map(row.data);
    final tagNames = row.readNullable<String>('tag_names');
    final file = row.readNullable<String>('first_file')?.split('\x1f');
    return ItemCard(
      tags: tagNames == null || tagNames.isEmpty ? const [] : tagNames.split('\x1f'),
      filePath: file?[0],
      fileMime: file != null && file.length > 1 ? file[1] : null,
      fileSize: file != null && file.length > 2 ? int.tryParse(file[2]) ?? 0 : 0,
      transcript: item.transcript,
      id: item.id,
      title: item.title,
      kind: item.kind,
      folderId: item.folderId,
      sortState: item.sortState,
      createdAt: item.createdAt,
      body: item.body,
      url: item.url,
      folderName: row.readNullable<String>('folder_name'),
      folderIcon: row.readNullable<String>('folder_icon'),
      folderColor: item.folderId == null ? null : FolderPalette.of(row.readNullable<String>('folder_color'), row.readNullable<int>('folder_order') ?? 0),
      reminderAt: item.reminderAt,
      thumbPath: row.readNullable<String>('thumb_path'),
      thumbRatio: row.readNullable<double>('thumb_ratio'),
      durationSeconds: item.durationSeconds,
      latitude: item.latitude,
      longitude: item.longitude,
      placeName: item.placeName,
      copying: row.readNullable<int>('copying') ?? 0,
      gone: item.goneAt != null,
      hasCopy: (row.readNullable<int>('has_copy') ?? 0) == 1,
      mainColor: row.data.containsKey('main_color') ? row.readNullable<String>('main_color') : null,
    );
  }

  /// Всё, у чего есть место: точки карты заметок.
  /// Вещи на карте. Ссылка на событие или заведение стоит там, где оно, а не где её сохранили;
  /// фото — там, где снято (место из EXIF).
  Stream<List<ItemCard>> watchPlaced() => _db
      .customSelect(
        "$_cardSelect AND (items.latitude IS NOT NULL OR EXISTS (SELECT 1 FROM facts WHERE facts.item_id = items.id AND facts.kind IN ('venuePlace', 'takenPlace'))) "
        'ORDER BY items.created_at DESC',
        readsFrom: {..._cardTables, _db.facts},
      )
      .watch()
      .asyncMap((rows) async {
        final cards = [for (final row in rows) _card(row)];
        final ids = [for (final card in cards) card.id];
        final venues =
            await (_db.select(_db.facts)..where((t) => t.itemId.isIn(ids) & t.kind.isIn([FactKind.venuePlace.name, FactKind.venue.name, FactKind.takenPlace.name]))).get();
        final points = <String, (double, double)>{};
        final names = <String, String>{};
        // событие главнее места съёмки: афиша с фото зала стоит у зала
        for (final fact in venues.where((fact) => fact.kind == FactKind.takenPlace).followedBy(venues.where((fact) => fact.kind != FactKind.takenPlace))) {
          if (fact.kind == FactKind.venue) names[fact.itemId] = fact.value;
          final longitude = double.tryParse(fact.detail ?? '');
          if (fact.kind != FactKind.venue && fact.number != null && longitude != null) points[fact.itemId] = (fact.number!, longitude);
        }
        return [
          for (final card in cards)
            if (points[card.id] case final point?) card.placedAt(point.$1, point.$2, names[card.id]) else card,
        ];
      });
}
