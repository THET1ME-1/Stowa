import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../data/db/database.dart';
import '../domain/link_preview.dart';
import '../domain/video_text.dart' show parseTiktokPage;
import '../domain/models.dart';
import '../domain/site_sources.dart';
import 'page_cache.dart';

/// Ответ сети: код, байты и тип содержимого.
class FetchReply {
  const FetchReply(this.status, this.bytes, this.contentType);

  final int status;
  final List<int> bytes;
  final String? contentType;

  bool get ok => status >= 200 && status < 300;
}

typedef Fetch = Future<FetchReply> Function(Uri uri);

/// Запрос с телом: плеер YouTube отдаёт дорожки субтитров только на POST.
typedef Post = Future<FetchReply> Function(Uri uri, String json);

/// Отправить JSON по-настоящему: со сроком и пределом размера ответа.
Future<FetchReply> httpPost(Uri uri, String json) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final request = await client.postUrl(uri).timeout(const Duration(seconds: 10));
    request.headers.contentType = ContentType.json;
    request.write(json);
    final response = await request.close().timeout(const Duration(seconds: 15));
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 15))) {
      bytes.addAll(chunk);
      if (bytes.length >= _maxImageBytes) break;
    }
    return FetchReply(response.statusCode, bytes, response.headers.value(HttpHeaders.contentTypeHeader));
  } finally {
    client.close(force: true);
  }
}

/// Страницы тяжелее обрезаются: теги превью всегда в начале.
const _maxPageBytes = 1536 * 1024;
const _maxImageBytes = 6 * 1024 * 1024;

/// Запрос со своими заголовками: API сайтов Lib ждёт номер сайта.
typedef FetchWith = Future<FetchReply> Function(Uri uri, Map<String, String> headers);

/// Скачать адрес по-настоящему: с переходами, сроком и пределом размера.
Future<FetchReply> httpFetch(Uri uri) => httpFetchWith(uri, const {});

/// То же со своими заголовками.
Future<FetchReply> httpFetchWith(Uri uri, Map<String, String> headers) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    // мобильный браузер: часть сайтов без него отдаёт заглушку вместо страницы
    ..userAgent = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36';
  try {
    final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
    request.headers.set(HttpHeaders.acceptLanguageHeader, 'ru,en;q=0.8');
    headers.forEach(request.headers.set);
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
  LinkPreviewService(this._db, {required Directory filesRoot, required DateTime Function() clock, Fetch fetch = httpFetch, FetchWith? fetchWith, this.onPreviewed})
    : _filesRoot = filesRoot, // ignore: prefer_initializing_formals
      _clock = clock, // ignore: prefer_initializing_formals
      _fetch = fetch, // ignore: prefer_initializing_formals
      _fetchWith = fetchWith ?? ((uri, headers) => fetch(uri));

  final AppDatabase _db;
  final Directory _filesRoot;
  final DateTime Function() _clock;
  final Fetch _fetch;
  final FetchWith _fetchWith;

  /// Превью записано: у вещи появились заголовок и описание страницы.
  final Future<void> Function(String itemId)? onPreviewed;

  /// Вещи, до которых сеть не достучалась: до [retry] (возврат в приложение, появилась сеть)
  /// не пробуем, иначе без интернета очередь крутилась бы по кругу.
  final _failed = <String>{};
  bool _running = false;

  // список, пришедший посреди разбора: раньше он отбрасывался, и новая ссылка
  // ждала следующей правки в базе или перезапуска
  List<String>? _wanted;

  /// Разобрать очередь: вещи со ссылкой без превью, по одной, свежие первыми.
  Future<void> run(List<String> ids) async {
    _wanted = ids;
    if (_running) return;
    _running = true;
    final handled = <String>{};
    try {
      while (_wanted != null) {
        final batch = _wanted!;
        _wanted = null;
        for (final id in batch) {
          // пришёл новый список — начать с него: свежая ссылка не ждёт за старыми
          if (_wanted != null) break;
          if (_failed.contains(id) || !handled.add(id)) continue;
          if (!await fetchFor(id)) _failed.add(id);
        }
      }
    } finally {
      _running = false;
    }
  }

  /// Снова попробовать то, что сорвалось: вернулись в приложение или появилась сеть.
  Future<void> retry(List<String> ids) {
    _failed.removeAll(ids);
    return run(ids);
  }

  /// Загрузить превью одной вещи. Ложь — сеть не ответила, стоит попробовать потом.
  Future<bool> fetchFor(String id) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
    final url = item?.url;
    if (item == null || url == null) return true;
    final page = Uri.tryParse(url);
    if (page == null || !page.hasScheme) return _done(item, null);

    // сайты Lib: страница — пустая оболочка, тайтл отдаёт их API
    final lib = libRequest(page);
    if (lib != null) return _fromLib(item, lib);

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
      final html = reply.ok ? decodePage(reply.bytes, reply.contentType) : '';
      if (reply.ok && isBotCheck(html)) {
        // проверка на бота — не страница: её заголовок вещи не нужен, а ждать, что она пройдёт сама, нечего
        gone = true;
      } else if (reply.ok) {
        fromPage = parseHtmlPreview(html, page);
        // TikTok: oEmbed больше не знает ни названия, ни обложки, а заголовок страницы —
        // заглушка «TikTok - Make Your Day»; сам ролик лежит в данных страницы
        if (page.host == 'tiktok.com' || page.host.endsWith('.tiktok.com')) fromPage = _fromTiktok(html);
        // копия страницы для извлекателей: рецепт, товар, событие читаются из неё без второго похода в сеть
        if ((reply.contentType ?? 'text/html').contains('html')) await savePage(_filesRoot, id, html).catchError((_) {});
      } else if (reply.status >= 400 && reply.status < 500) {
        gone = true;
      }
    } catch (_) {
      // нет сети или сайт молчит
    }
    // HDrezka закрыта проверкой на бота, но название и год сама пишет в адрес
    final rezka = fromPage == null ? rezkaFromUrl(page) : null;
    if (rezka != null && (gone || fromOembed == null)) {
      await savePage(_filesRoot, id, rezkaPage(rezka)).catchError((_) {});
      // год — в карточке фильма, заголовку он не нужен
      return _done(item, LinkPreview(title: rezka.title, siteName: 'HDrezka'));
    }
    final preview = fromOembed != null && fromPage != null ? fromOembed.merge(fromPage) : fromOembed ?? fromPage;
    if (preview == null) return gone ? _done(item, null) : false;
    return _done(item, preview);
  }

  // тайтл Lib из их API: название, описание, обложка, автор; закрытый для гостей — имя из адреса
  Future<bool> _fromLib(Item item, LibRequest lib) async {
    final FetchReply reply;
    try {
      reply = await _fetchWith(lib.api, lib.headers);
    } catch (_) {
      return false;
    }
    LibTitle? title;
    if (reply.ok) {
      try {
        title = parseLibTitle(jsonDecode(utf8.decode(reply.bytes)) as Map<String, Object?>, lib.site);
      } on FormatException {
        title = null;
      }
    } else if (reply.status >= 500) {
      return false;
    }
    title ??= libTitleFromSlug(lib);
    await savePage(_filesRoot, item.id, libPage(title)).catchError((_) {});
    return _done(
      item,
      LinkPreview(title: title.name, description: title.summary, imageUrl: title.cover, siteName: lib.site.name, author: title.authors.isEmpty ? null : title.authors.join(', ')),
    );
  }

  LinkPreview _fromTiktok(String html) {
    final video = parseTiktokPage(html);
    if (video == null) return const LinkPreview(siteName: 'TikTok');
    return LinkPreview(
      title: video.title.isEmpty ? null : video.title,
      description: video.caption.trim().isEmpty ? null : video.caption.trim(),
      imageUrl: video.cover == null ? null : Uri.tryParse(video.cover!),
      siteName: 'TikTok',
      author: video.author,
      duration: video.seconds == null ? null : Duration(seconds: video.seconds!),
    );
  }

  Future<bool> _done(Item item, LinkPreview? preview) async {
    final cover = preview?.imageUrl == null ? null : await _saveCover(item.id, preview!.imageUrl!, page: Uri.tryParse(item.url ?? ''));
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
  /// Адрес страницы идёт в Referer, как у браузера: сервер картинок Lib без него отвечает 403.
  Future<String?> _saveCover(String id, Uri image, {Uri? page}) async {
    final candidates = [
      if (image.host == 'i.ytimg.com' && image.path.endsWith('/hqdefault.jpg')) image.replace(path: image.path.replaceFirst('hqdefault.jpg', 'maxresdefault.jpg')),
      image,
    ];
    final referer = page == null || page.host.isEmpty ? const <String, String>{} : {'Referer': '${page.scheme}://${page.host}/'};
    for (final candidate in candidates) {
      try {
        final reply = await _fetchWith(candidate, referer);
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
