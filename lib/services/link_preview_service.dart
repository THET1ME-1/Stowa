import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../data/db/database.dart';
import '../domain/link_preview.dart';
import '../domain/models.dart';

/// Ответ сети: код, байты и тип содержимого.
class FetchReply {
  const FetchReply(this.status, this.bytes, this.contentType);

  final int status;
  final List<int> bytes;
  final String? contentType;

  bool get ok => status >= 200 && status < 300;
}

typedef Fetch = Future<FetchReply> Function(Uri uri);

/// Страницы тяжелее обрезаются: теги превью всегда в начале.
const _maxPageBytes = 1536 * 1024;
const _maxImageBytes = 6 * 1024 * 1024;

/// Скачать адрес по-настоящему: с переходами, сроком и пределом размера.
Future<FetchReply> httpFetch(Uri uri) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    // мобильный браузер: часть сайтов без него отдаёт заглушку вместо страницы
    ..userAgent = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36';
  try {
    final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
    request.headers.set(HttpHeaders.acceptLanguageHeader, 'ru,en;q=0.8');
    final response = await request.close().timeout(const Duration(seconds: 15));
    final limit = (response.headers.contentType?.primaryType == 'image') ? _maxImageBytes : _maxPageBytes;
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 15))) {
      bytes.addAll(chunk);
      if (bytes.length >= limit) break;
    }
    return FetchReply(response.statusCode, bytes, response.headers.value(HttpHeaders.contentTypeHeader));
  } finally {
    client.close(force: true);
  }
}

/// Превью ссылок и роликов: заголовок, описание, обложка. Сеть только здесь и
/// только в фоне — сохранение вещи её не ждёт.
class LinkPreviewService {
  LinkPreviewService(this._db, {required Directory filesRoot, required DateTime Function() clock, Fetch fetch = httpFetch, this.onPreviewed})
    : _filesRoot = filesRoot, // ignore: prefer_initializing_formals
      _clock = clock, // ignore: prefer_initializing_formals
      _fetch = fetch; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final Directory _filesRoot;
  final DateTime Function() _clock;
  final Fetch _fetch;

  /// Превью записано: у вещи появились заголовок и описание страницы.
  final Future<void> Function(String itemId)? onPreviewed;

  /// Вещи, до которых в этом запуске сеть не достучалась: второй раз не пробуем,
  /// иначе без интернета очередь крутилась бы по кругу.
  final _failed = <String>{};
  bool _running = false;

  /// Разобрать очередь: вещи со ссылкой без превью, по одной.
  Future<void> run(List<String> ids) async {
    if (_running) return;
    _running = true;
    try {
      for (final id in ids) {
        if (_failed.contains(id)) continue;
        if (!await fetchFor(id)) _failed.add(id);
      }
    } finally {
      _running = false;
    }
  }

  /// Загрузить превью одной вещи. Ложь — сеть не ответила, стоит попробовать потом.
  Future<bool> fetchFor(String id) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
    final url = item?.url;
    if (item == null || url == null) return true;
    final page = Uri.tryParse(url);
    if (page == null || !page.hasScheme) return _done(item, null);

    LinkPreview? fromOembed;
    final endpoint = oembedEndpoint(page);
    if (endpoint != null) {
      try {
        final reply = await _fetch(endpoint);
        if (reply.ok) fromOembed = parseOembed(jsonDecode(utf8.decode(reply.bytes)) as Map<String, Object?>, page);
      } catch (_) {
        // страница ниже может знать то же самое
      }
    }
    LinkPreview? fromPage;
    var gone = false;
    try {
      final reply = await _fetch(page);
      if (reply.ok) {
        fromPage = parseHtmlPreview(decodePage(reply.bytes, reply.contentType), page);
      } else if (reply.status >= 400 && reply.status < 500) {
        gone = true;
      }
    } catch (_) {
      // нет сети или сайт молчит
    }
    final preview = fromOembed != null && fromPage != null ? fromOembed.merge(fromPage) : fromOembed ?? fromPage;
    if (preview == null) return gone ? _done(item, null) : false;
    return _done(item, preview);
  }

  Future<bool> _done(Item item, LinkPreview? preview) async {
    final cover = preview?.imageUrl == null ? null : await _saveCover(item.id, preview!.imageUrl!);
    final title = preview?.title;
    await (_db.update(_db.items)..where((t) => t.id.equals(item.id))).write(
      ItemsCompanion(
        // заголовок, который человек поменял, страница не трогает
        title: title != null && _autoTitle(item) ? Value(title) : const Value.absent(),
        coverPath: cover != null ? Value(cover) : const Value.absent(),
        previewText: Value(preview?.description),
        previewSite: Value(preview?.siteName),
        previewAuthor: Value(preview?.author),
        durationSeconds: Value(preview?.duration?.inSeconds),
        previewAt: Value(_clock()),
      ),
    );
    if (preview != null) await onPreviewed?.call(item.id);
    return true;
  }

  /// Заголовок сам собой: пустой или сам адрес.
  bool _autoTitle(Item item) {
    final title = item.title.trim();
    return title.isEmpty || title == item.url || title.startsWith('http://') || title.startsWith('https://');
  }

  /// Обложка в папку приложения. У YouTube сперва крупная: в oEmbed она с чёрными полосами.
  Future<String?> _saveCover(String id, Uri image) async {
    final candidates = [
      if (image.host == 'i.ytimg.com' && image.path.endsWith('/hqdefault.jpg')) image.replace(path: image.path.replaceFirst('hqdefault.jpg', 'maxresdefault.jpg')),
      image,
    ];
    for (final candidate in candidates) {
      try {
        final reply = await _fetch(candidate);
        if (!reply.ok || reply.bytes.isEmpty || !(reply.contentType ?? 'image/').startsWith('image/')) continue;
        final extension = switch (reply.contentType?.split(';').first.trim()) {
          'image/png' => 'png',
          'image/webp' => 'webp',
          'image/gif' => 'gif',
          _ => 'jpg',
        };
        final relative = p.join('covers', '$id.$extension');
        final file = File(p.join(_filesRoot.path, relative));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(reply.bytes, flush: true);
        return relative;
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

/// Вещи, которым ещё нужно превью: ссылки и ролики по адресу.
Stream<List<String>> watchPendingPreviews(AppDatabase db) {
  final query = db.select(db.items)
    ..where((t) => t.url.isNotNull() & t.previewAt.isNull() & t.deletedAt.isNull() & t.kind.isIn([ItemKind.link.name, ItemKind.video.name]))
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
    ..limit(30);
  return query.watch().map((rows) => [for (final row in rows) row.id]);
}
