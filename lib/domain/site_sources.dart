/// Сайты, страницы которых не годятся для разбора, а данные взять можно иначе.
///
/// Сайты Lib (MangaLib, YaoiLib, RanobeLib, HentaiLib, AnimeLib) отдают пустую
/// страницу, которую достраивает скрипт, но у них открытый API — из него и
/// берётся тайтл. HDrezka закрыта проверкой на бота, обходить её не будем:
/// название и год сайт сам пишет в адрес.
library;

import 'dart:convert';

import 'word_variants.dart' show toCyrillic;

/// Сайт семейства Lib: номер для API, имя, адреса и зеркала.
class LibSite {
  const LibSite(this.id, this.name, this.hosts, {this.anime = false, this.ranobe = false, this.adult = false});

  final int id;
  final String name;
  final List<String> hosts;
  final bool anime;

  /// Весь сайт для взрослых: каждый тайтл — 18+, какой бы ни была его пометка.
  final bool adult;

  /// Ранобэ — книга, а не манга.
  final bool ranobe;
}

const libSites = [
  LibSite(1, 'MangaLib', ['mangalib.me', 'mangalib.org']),
  LibSite(2, 'YaoiLib', ['slashlib.me', 'shlib.life', 'yaoilib.me', 'yaoilib.net']),
  LibSite(3, 'RanobeLib', ['ranobelib.me', 'ranobelib.org'], ranobe: true),
  LibSite(4, 'HentaiLib', ['hentailib.me', 'hentailib.org'], adult: true),
  LibSite(5, 'AnimeLib', ['animelib.org', 'animelib.me', 'anilib.me'], anime: true),
];

/// Поля тайтла, которые API отдаёт сверх названий и обложки.
const _libFields = ['summary', 'genres', 'tags', 'authors', 'releaseDate', 'rate_avg'];

// разделы сайта, а не тайтлы: голый адрес «mangalib.me/catalog» — не манга
const _libSections = {'catalog', 'user', 'top', 'collections', 'news', 'faq', 'notifications', 'bookmarks', 'search', 'people', 'team', 'publisher', 'media', 'ru', 'en', 'front'};

/// Запрос к API Lib по ссылке на тайтл.
class LibRequest {
  const LibRequest(this.site, this.slug, this.api);

  final LibSite site;

  /// «7965--chainsaw-man»: номер и имя тайтла в адресе.
  final String slug;
  final Uri api;

  /// Номер сайта: без него API не знает, о каком из пяти речь.
  Map<String, String> get headers => {'Site-Id': '${site.id}'};
}

/// Ссылка на тайтл любого сайта Lib — запрос к API. Не тайтл и не Lib — null.
LibRequest? libRequest(Uri page) {
  final host = page.host.toLowerCase();
  final site = libSites.where((one) => one.hosts.any((known) => host == known || host.endsWith('.$known'))).firstOrNull;
  if (site == null) return null;
  var segments = [for (final segment in page.pathSegments) if (segment.isNotEmpty) segment];
  // «/ru/manga/7965--chainsaw-man/read» и старое «/chainsaw-man»
  if (segments.isNotEmpty && RegExp(r'^[a-z]{2}$').hasMatch(segments.first)) segments = segments.skip(1).toList();
  String? slug;
  if (segments.length >= 2 && const {'manga', 'anime', 'book', 'ranobe'}.contains(segments.first)) {
    slug = segments[1];
  } else if (segments.length == 1 && !_libSections.contains(segments.first)) {
    slug = segments.first;
  }
  if (slug == null || !RegExp(r'^[\w-]+$').hasMatch(slug)) return null;
  final model = site.anime ? 'anime' : 'manga';
  return LibRequest(site, slug, Uri.https('api.lib.social', '/api/$model/$slug', {'fields[]': _libFields}));
}

/// Тайтл Lib: то, что пойдёт в превью и в разметку для извлекателей.
class LibTitle {
  const LibTitle({
    required this.site,
    required this.name,
    this.alternative,
    this.summary,
    this.cover,
    this.year,
    this.date,
    this.rating,
    this.authors = const [],
    this.genres = const [],
    this.typeLabel,
    this.adultMark = false,
  });

  /// Пометка тайтла 18+.
  final bool adultMark;

  /// Для взрослых: пометка тайтла или весь сайт такой.
  bool get adult => adultMark || site.adult;

  final LibSite site;
  final String name;

  /// Второе имя: английское или оригинальное.
  final String? alternative;
  final String? summary;
  final Uri? cover;
  final int? year;

  /// Полная дата выхода, если есть: «2023-09-29».
  final String? date;
  final double? rating;
  final List<String> authors;
  final List<String> genres;

  /// Тип по сайту: «Манга», «Манхва», «TV Сериал», «Фильм».
  final String? typeLabel;
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

// описание приходит деревом редактора: абзацы с кусками текста внутри
String? _summary(Object? value) {
  if (value is String) return _text(value);
  if (value is! Map) return null;
  final paragraphs = <String>[];
  for (final block in (value['content'] as List? ?? const [])) {
    if (block is! Map) continue;
    final text = [
      for (final piece in (block['content'] as List? ?? const []))
        if (piece is Map && piece['text'] is String) piece['text'] as String,
    ].join().trim();
    if (text.isNotEmpty) paragraphs.add(text);
  }
  return paragraphs.isEmpty ? null : paragraphs.join('\n');
}

List<String> _names(Object? list) => [
  for (final one in (list is List ? list : const []))
    if (one is Map) ?(_text(one['rus_name']) ?? _text(one['name'])),
];

/// Ответ API — тайтл. Не тайтл (ошибка, «не найдено») — null.
LibTitle? parseLibTitle(Map<String, Object?> json, LibSite site) {
  final data = json['data'];
  if (data is! Map) return null;
  final name = _text(data['rus_name']) ?? _text(data['eng_name']) ?? _text(data['name']);
  if (name == null) return null;
  final alternative = _text(data['eng_name']) ?? _text(data['name']);
  final cover = data['cover'] is Map ? data['cover'] as Map : const {};
  final released = '${data['releaseDate'] ?? ''}';
  final year = int.tryParse(RegExp(r'^\d{4}').firstMatch(released)?.group(0) ?? '');
  final rating = data['rating'] is Map ? double.tryParse('${(data['rating'] as Map)['average']}') : null;
  return LibTitle(
    site: site,
    name: name,
    alternative: alternative == name ? null : alternative,
    summary: _summary(data['summary']),
    cover: Uri.tryParse(_text(cover['default']) ?? _text(cover['md']) ?? _text(cover['thumbnail']) ?? ''),
    year: year,
    date: RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(released) ? released : null,
    rating: rating == null || rating == 0 ? null : rating,
    authors: _names(data['authors']),
    genres: [..._names(data['genres']), ..._names(data['tags'])].take(8).toList(),
    typeLabel: data['type'] is Map ? _text((data['type'] as Map)['label']) : null,
    adultMark: data['ageRestriction'] is Map && '${(data['ageRestriction'] as Map)['label']}'.contains('18'),
  );
}

/// Закрытый тайтл (на YaoiLib 16+ видны только после входа): имя из адреса.
LibTitle libTitleFromSlug(LibRequest request) {
  final words = request.slug.replaceFirst(RegExp(r'^\d+--'), '').replaceAll('-', ' ').trim();
  return LibTitle(site: request.site, name: words.isEmpty ? request.slug : '${words[0].toUpperCase()}${words.substring(1)}');
}

String _escape(String text) => const HtmlEscape(HtmlEscapeMode.attribute).convert(text);

// страница с разметкой schema.org: её разбирает тот же извлекатель, что и любую другую
String _page({required String title, required String site, String? description, Uri? image, required Map<String, Object?> node}) {
  final meta = {'og:title': title, 'og:site_name': site, 'og:description': ?description, 'og:image': ?image?.toString()};
  return '<html><head><title>${_escape(title)}</title>'
      '${[for (final entry in meta.entries) '<meta property="${entry.key}" content="${_escape(entry.value)}">'].join()}'
      '<script type="application/ld+json">${jsonEncode({'@context': 'https://schema.org', ...node})}</script></head><body></body></html>';
}

/// Тайтл Lib страницей с разметкой: манга — ComicSeries, ранобэ — Book, аниме — сериал или фильм.
String libPage(LibTitle title) {
  final movie = title.typeLabel?.toLowerCase().contains('фильм') ?? false;
  final type = title.site.anime ? (movie ? 'Movie' : 'TVSeries') : (title.site.ranobe ? 'Book' : 'ComicSeries');
  return _page(
    title: title.name,
    site: title.site.name,
    description: title.summary,
    image: title.cover,
    node: {
      '@type': type,
      'name': title.name,
      'alternateName': ?title.alternative,
      'description': ?title.summary,
      'image': ?title.cover?.toString(),
      'datePublished': ?(title.date ?? title.year?.toString()),
      if (title.authors.isNotEmpty) 'author': [for (final author in title.authors) {'@type': 'Person', 'name': author}],
      if (title.genres.isNotEmpty) 'genre': title.genres,
      if (title.rating != null) 'aggregateRating': {'@type': 'AggregateRating', 'ratingValue': title.rating},
      // тот же знак 18+, что ставят о себе обычные сайты: дальше его читает общее правило
      if (title.adult) ...{'contentRating': '18+', 'isFamilyFriendly': false},
    },
  );
}

/// Фильм или сериал HDrezka, как его записал адрес.
class RezkaTitle {
  const RezkaTitle(this.title, this.year, {required this.series});

  final String title;
  final int? year;
  final bool series;
}

final _rezkaFile = RegExp(r'^\d+-(.+?)(?:-(\d{4}))?\.html$');

/// «…/films/fiction/1171-interstellar-2014.html» → «Интерстеллар», 2014. Не HDrezka — null.
RezkaTitle? rezkaFromUrl(Uri page) {
  if (!page.host.toLowerCase().contains('rezka')) return null;
  final segments = [for (final segment in page.pathSegments) if (segment.isNotEmpty) segment];
  if (segments.length < 2 || !const {'films', 'series', 'cartoons', 'animation'}.contains(segments.first)) return null;
  final file = _rezkaFile.firstMatch(segments.last);
  if (file == null) return null;
  final words = [for (final word in file.group(1)!.split('-')) if (word.isNotEmpty) toCyrillic(word)].join(' ');
  if (words.isEmpty) return null;
  return RezkaTitle('${words[0].toUpperCase()}${words.substring(1)}', int.tryParse(file.group(2) ?? ''), series: segments.first == 'series' || segments.first == 'animation');
}

/// Фильм HDrezka страницей с разметкой: вид и год ищутся, как у любого фильма.
String rezkaPage(RezkaTitle title) => _page(
  title: title.title,
  site: 'HDrezka',
  node: {'@type': title.series ? 'TVSeries' : 'Movie', 'name': title.title, 'datePublished': ?title.year?.toString()},
);

// крупные сайты для взрослых: их страница часто закрыта проверкой возраста,
// и пометку rating из неё не прочесть
const _adultHosts = {
  'pornhub.com', 'pornhub.org', 'xvideos.com', 'xvideos.red', 'xnxx.com', 'xhamster.com', 'xhamster.desi',
  'redtube.com', 'youporn.com', 'tube8.com', 'spankbang.com', 'eporner.com', 'tnaflix.com', 'porntrex.com',
  'chaturbate.com', 'stripchat.com', 'bongacams.com', 'cam4.com', 'livejasmin.com', 'myfreecams.com',
  'onlyfans.com', 'fansly.com', 'manyvids.com', 'clips4sale.com', 'iwara.tv', 'motherless.com',
  'nhentai.net', 'e-hentai.org', 'exhentai.org', 'hentai2read.com', 'hitomi.la', 'rule34.xxx', 'rule34.paheal.net',
  'gelbooru.com', 'hanime.tv', 'f95zone.to', 'literotica.com', 'brazzers.com', 'erome.com', 'porn.com',
};

/// Сайт целиком для взрослых — по адресу, вместе с поддоменами (rt.pornhub.com) и
/// HentaiLib. Страница с пометкой 18+ узнаётся и без списка — [adultPage].
bool adultSite(Uri page) {
  final host = page.host.toLowerCase();
  bool under(String domain) => host == domain || host.endsWith('.$domain');
  if (host.endsWith('.xxx') || host.endsWith('.porn') || host.endsWith('.adult') || host.endsWith('.sex')) return true;
  return _adultHosts.any(under) || libSites.any((site) => site.adult && site.hosts.any(under));
}

final _botTitle = RegExp(r'проверяем, что вы не бот|just a moment|attention required|ddos-guard|checking your browser|verifying you are human|один момент', caseSensitive: false);
final _botMarker = RegExp(r'/\.within\.website/|cf-browser-verification|challenge-platform|__cf_chl_|ddos-guard\.net/', caseSensitive: false);

/// Страница проверки на бота (Anubis, Cloudflare, DDoS-Guard), а не содержимое:
/// её заголовок вещи не нужен, а разбирать в ней нечего.
bool isBotCheck(String html) {
  final head = html.length > 20000 ? html.substring(0, 20000) : html;
  final title = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false).firstMatch(head)?.group(1) ?? '';
  return _botTitle.hasMatch(title) || _botMarker.hasMatch(head);
}
