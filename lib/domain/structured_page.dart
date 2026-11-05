/// Что страница говорит о себе разметкой schema.org (JSON-LD): рецепт, товар,
/// событие, заведение, статья, фильм, книга, видео. Готовые поля, без догадок.
/// Нет разметки — запасные метатеги: цена товара, тип статьи, автор.
library;

import 'dart:convert';

enum PageType { recipe, product, event, place, movie, book, video, article }

class Chapter {
  const Chapter(this.seconds, this.title);

  final int seconds;
  final String title;
}

/// Разобранная страница. Поля, которых у вида нет, пустые.
class StructuredPage {
  const StructuredPage({
    required this.type,
    this.name,
    this.ingredients = const [],
    this.time,
    this.servings,
    this.steps = 0,
    this.price,
    this.currency,
    this.inStock,
    this.shop,
    this.brand,
    this.start,
    this.end,
    this.venue,
    this.address,
    this.latitude,
    this.longitude,
    this.phone,
    this.hours = const [],
    this.authors = const [],
    this.published,
    this.readingMinutes,
    this.year,
    this.rating,
    this.duration,
    this.chapters = const [],
  });

  final PageType type;
  final String? name;
  final List<String> ingredients;

  /// Сколько готовить: всё вместе или подготовка плюс готовка.
  final Duration? time;
  final int? servings;
  final int steps;
  final double? price;
  final String? currency;
  final bool? inStock;
  final String? shop;
  final String? brand;
  final DateTime? start;
  final DateTime? end;

  /// Где событие: название зала или заведения.
  final String? venue;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? phone;

  /// Часы работы строками: «Mo–Fr 10:00–22:00».
  final List<String> hours;

  /// Автор, режиссёр — кто сделал.
  final List<String> authors;
  final DateTime? published;
  final int? readingMinutes;
  final int? year;
  final double? rating;
  final Duration? duration;
  final List<Chapter> chapters;
}

/// Сколько слов в минуту читает человек: и по-русски, и по-английски около двухсот.
const _wordsPerMinute = 200;

/// Короче статьёй не считается: заметка на сайте, а не чтение.
const _articleWords = 300;

// вид важнее, чем ниже в списке: рецепт в блоге — рецепт, а не статья
const _priority = [PageType.recipe, PageType.product, PageType.event, PageType.place, PageType.movie, PageType.book, PageType.video, PageType.article];

const _eventTypes = {'event', 'musicevent', 'theaterevent', 'sportsevent', 'festival', 'comedyevent', 'danceevent', 'educationevent', 'exhibitionevent', 'foodevent', 'literaryevent', 'screeningevent', 'socialevent', 'businessevent', 'childrensevent', 'saleevent'};
const _placeTypes = {
  'place', 'localbusiness', 'restaurant', 'cafeorcoffeeshop', 'barorpub', 'bakery', 'foodestablishment', 'store', 'hotel', 'lodgingbusiness',
  'touristattraction', 'museum', 'park', 'movietheater', 'nightclub', 'healthandbeautybusiness', 'sportsactivitylocation', 'shoppingcenter',
};
const _articleTypes = {'article', 'newsarticle', 'blogposting', 'report', 'techarticle', 'scholarlyarticle', 'posting', 'socialmediaposting'};
const _movieTypes = {'movie', 'tvseries', 'tvseason', 'episode', 'tvepisode', 'musicalbum', 'musicrecording'};

PageType? _typeOf(Set<String> types) {
  if (types.contains('recipe')) return PageType.recipe;
  if (types.contains('product') || types.contains('productgroup')) return PageType.product;
  if (types.any(_eventTypes.contains)) return PageType.event;
  if (types.any(_placeTypes.contains)) return PageType.place;
  if (types.any(_movieTypes.contains)) return PageType.movie;
  if (types.contains('book')) return PageType.book;
  if (types.contains('videoobject')) return PageType.video;
  if (types.any(_articleTypes.contains)) return PageType.article;
  return null;
}

/// Разметка страницы. Ни разметки, ни метатегов — null.
StructuredPage? structuredPage(String html) {
  final nodes = <Map<String, Object?>>[];
  for (final match in RegExp(r'<script[^>]*type\s*=\s*"?\x27?application/ld\+json[^>]*>(.*?)</script>', caseSensitive: false, dotAll: true).allMatches(html)) {
    final json = _lenientJson(match.group(1)!);
    if (json != null) _collect(json, nodes);
  }
  // несколько разных событий или товаров — страница-список: ни одно из них не «эта страница»
  final names = <PageType, Set<String>>{};
  for (final node in nodes) {
    final type = _typeOf(_types(node));
    if (type != null) names.putIfAbsent(type, () => {}).add(_string(node['name']) ?? _string(node['headline']) ?? '');
  }
  ({PageType type, Map<String, Object?> node})? best;
  for (final node in nodes) {
    final type = _typeOf(_types(node));
    if (type == null || names[type]!.length > 1) continue;
    if (best == null || _priority.indexOf(type) < _priority.indexOf(best.type)) best = (type: type, node: node);
  }
  final text = _readableText(html);
  if (best != null) return _fromNode(best.type, best.node, html, text);
  return _fromMeta(html, text);
}

// JSON со страниц бывает кривым: комментарии, сырые переводы строк в строках, запятая в конце
Object? _lenientJson(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'^<!--|-->$|/\*\s*<!\[CDATA\[\s*\*/|/\*\s*\]\]>\s*\*/'), '').trim();
  final repaired = cleaned.replaceAll(RegExp(r'[\r\n\t]'), ' ').replaceAllMapped(RegExp(r',\s*([}\]])'), (match) => match.group(1)!);
  for (final attempt in [cleaned, repaired]) {
    try {
      return jsonDecode(attempt);
    } on FormatException {
      continue;
    }
  }
  return null;
}

// узлы с типом: верхние, из @graph и главная сущность страницы. Элементы списков
// (itemListElement) не берутся: страница со списком событий или товаров — не одно событие
void _collect(Object? json, List<Map<String, Object?>> nodes, [int depth = 0]) {
  if (depth > 6) return;
  if (json is List) {
    for (final item in json) {
      _collect(item, nodes, depth + 1);
    }
  } else if (json is Map) {
    final node = json.cast<String, Object?>();
    if (node.containsKey('@type')) nodes.add(node);
    for (final key in ['@graph', 'mainEntity', 'mainEntityOfPage', 'about']) {
      if (node[key] is List || node[key] is Map) _collect(node[key], nodes, depth + 1);
    }
  }
}

Set<String> _types(Map<String, Object?> node) {
  final raw = node['@type'];
  final list = raw is List ? raw : [raw];
  return {
    for (final type in list)
      if (type is String) type.split('/').last.split(':').last.toLowerCase(),
  };
}

String? _string(Object? value) {
  if (value is String) {
    final cleaned = _plain(value);
    return cleaned.isEmpty ? null : cleaned;
  }
  if (value is num) return '$value';
  if (value is Map) return _string(value['name'] ?? value['@value'] ?? value['text']);
  if (value is List && value.isNotEmpty) return _string(value.first);
  return null;
}

// текст из разметки бывает с тегами и сущностями
String _plain(String value) => _entities(value.replaceAll(RegExp(r'<[^>]*>'), ' ')).replaceAll(RegExp(r'\s+'), ' ').trim();

String _entities(String text) => text
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAllMapped(RegExp(r'&#(\d+);'), (match) => String.fromCharCode(int.parse(match.group(1)!)));

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), ''));
  if (value is Map) return _number(value['@value'] ?? value['value']);
  if (value is List && value.isNotEmpty) return _number(value.first);
  return null;
}

/// Длительность ISO 8601: «PT1H30M». Не она — null.
Duration? isoDuration(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^P(?:(\d+)D)?(?:T(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?)?$').firstMatch(value.trim().toUpperCase());
  if (match == null || value.trim().length < 3) return null;
  double part(int index) => double.tryParse(match.group(index) ?? '') ?? 0;
  final seconds = part(1) * 86400 + part(2) * 3600 + part(3) * 60 + part(4);
  return seconds <= 0 ? null : Duration(seconds: seconds.round());
}

DateTime? _date(Object? value) {
  final text = _string(value);
  if (text == null) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed != null) return parsed.isUtc ? parsed.toLocal() : parsed;
  final year = RegExp(r'^\d{4}$').firstMatch(text);
  return year == null ? null : DateTime(int.parse(text));
}

List<String> _names(Object? value) {
  final list = value is List ? value : [value];
  return [
    for (final one in list)
      if (_string(one) case final name?) name,
  ];
}

String? _address(Object? value) {
  if (value is String) return _string(value);
  if (value is List && value.isNotEmpty) return _address(value.first);
  if (value is! Map) return null;
  final parts = [
    for (final key in ['streetAddress', 'addressLocality', 'addressRegion'])
      if (_string(value[key]) case final part?) part,
  ];
  return parts.isEmpty ? _string(value['name']) : parts.join(', ');
}

({double latitude, double longitude})? _geo(Object? value) {
  if (value is List && value.isNotEmpty) return _geo(value.first);
  if (value is! Map) return null;
  final latitude = _number(value['latitude']);
  final longitude = _number(value['longitude']);
  if (latitude == null || longitude == null || (latitude == 0 && longitude == 0)) return null;
  return (latitude: latitude, longitude: longitude);
}

int? _servings(Object? value) {
  final text = _string(value is List ? value.first : value);
  final number = RegExp(r'\d+').firstMatch(text ?? '');
  return number == null ? null : int.parse(number.group(0)!);
}

int _steps(Object? value) {
  if (value is String) return value.split(RegExp(r'\n+|(?<=\.)\s+(?=\p{Lu})', unicode: true)).where((step) => step.trim().isNotEmpty).length;
  if (value is! List) return 0;
  var count = 0;
  for (final step in value) {
    // разделы рецепта: шаги внутри itemListElement
    if (step is Map && step['itemListElement'] is List) {
      count += _steps(step['itemListElement']);
    } else {
      count++;
    }
  }
  return count;
}

const _days = {'monday': 'Mo', 'tuesday': 'Tu', 'wednesday': 'We', 'thursday': 'Th', 'friday': 'Fr', 'saturday': 'Sa', 'sunday': 'Su'};

List<String> _hours(Map<String, Object?> node) {
  final plain = node['openingHours'];
  if (plain != null) return _names(plain);
  final specification = node['openingHoursSpecification'];
  final list = specification is List ? specification : [specification];
  final hours = <String>[];
  for (final one in list) {
    if (one is! Map) continue;
    final days = [
      for (final day in (one['dayOfWeek'] is List ? one['dayOfWeek'] as List : [one['dayOfWeek']]))
        if (day is String) _days[day.split('/').last.toLowerCase()] ?? day,
    ];
    final opens = _string(one['opens']);
    final closes = _string(one['closes']);
    if (opens == null || closes == null) continue;
    final span = days.isEmpty ? '' : (days.length > 2 ? '${days.first}–${days.last} ' : days.length == 2 ? '${days.first}–${days.last} ' : '${days.first} ');
    hours.add('$span${opens.substring(0, opens.length.clamp(0, 5))}–${closes.substring(0, closes.length.clamp(0, 5))}');
  }
  return hours;
}

({double? price, String? currency, bool? inStock, String? shop}) _offer(Object? value) {
  final offer = value is List && value.isNotEmpty ? value.first : value;
  if (offer is! Map) return (price: null, currency: null, inStock: null, shop: null);
  final availability = _string(offer['availability'])?.toLowerCase();
  return (
    price: _number(offer['price']) ?? _number(offer['lowPrice']) ?? _number((offer['priceSpecification'] as Map?)?['price']),
    currency: _string(offer['priceCurrency'])?.toUpperCase(),
    inStock: availability == null ? null : availability.contains('instock') || availability.contains('limitedavailability'),
    shop: _string(offer['seller']),
  );
}

StructuredPage _fromNode(PageType type, Map<String, Object?> node, String html, String text) {
  final name = _string(node['name']) ?? _string(node['headline']);
  final location = node['location'] is List ? (node['location'] as List).firstOrNull : node['location'];
  final geo = _geo(node['geo']) ?? (location is Map ? _geo(location['geo']) : null);
  final offer = _offer(node['offers']);
  final authors = _names(node['author'] ?? node['director'] ?? node['creator']);
  // у фильма и книги dateCreated — когда завели запись в базе сайта, а не когда вышло
  final releasedEvent = node['releasedEvent'] is List ? (node['releasedEvent'] as List).firstOrNull : node['releasedEvent'];
  final released = releasedEvent is Map ? releasedEvent['startDate'] : null;
  final work = type == PageType.movie || type == PageType.book;
  final published = _date(node['datePublished'] ?? released ?? node['copyrightYear'] ?? (work ? null : node['dateCreated']) ?? node['startDate']);
  final words = RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(text).length;
  final total = isoDuration(node['totalTime']);
  final parts = [isoDuration(node['prepTime']), isoDuration(node['cookTime'])].nonNulls;
  return StructuredPage(
    type: type,
    name: name,
    ingredients: _names(node['recipeIngredient'] ?? node['ingredients']),
    time: total ?? (parts.isEmpty ? null : parts.reduce((a, b) => a + b)),
    servings: _servings(node['recipeYield']),
    steps: _steps(node['recipeInstructions']),
    price: offer.price,
    currency: offer.currency,
    inStock: offer.inStock,
    shop: offer.shop,
    brand: _string(node['brand']),
    start: type == PageType.event ? _date(node['startDate']) : null,
    end: type == PageType.event ? _date(node['endDate']) : null,
    venue: location is Map ? _string(location['name']) : (location is String ? _string(location) : null),
    address: _address(node['address']) ?? (location is Map ? _address(location['address']) : null),
    latitude: geo?.latitude,
    longitude: geo?.longitude,
    phone: _string(node['telephone']),
    hours: type == PageType.place ? _hours(node) : const [],
    authors: authors.isEmpty ? _metaAuthors(html) : authors,
    published: published,
    readingMinutes: type == PageType.article && words >= _articleWords ? (words / _wordsPerMinute).ceil() : null,
    year: type == PageType.movie || type == PageType.book ? published?.year : null,
    rating: _number(node['aggregateRating'] is Map ? (node['aggregateRating'] as Map)['ratingValue'] : null),
    duration: isoDuration(node['duration']),
    chapters: [
      for (final part in (node['hasPart'] is List ? node['hasPart'] as List : const []))
        if (part is Map && _string(part['name']) != null) Chapter(_number(part['startOffset'])?.round() ?? 0, _string(part['name'])!),
    ],
  );
}

String? _meta(String html, String name) {
  final match =
      RegExp('<meta[^>]+(?:property|name)\\s*=\\s*["\']$name["\'][^>]*content\\s*=\\s*["\']([^"\']*)["\']', caseSensitive: false).firstMatch(html) ??
      RegExp('<meta[^>]+content\\s*=\\s*["\']([^"\']*)["\'][^>]*(?:property|name)\\s*=\\s*["\']$name["\']', caseSensitive: false).firstMatch(html);
  final value = match == null ? null : _plain(match.group(1)!);
  return value == null || value.isEmpty ? null : value;
}

List<String> _metaAuthors(String html) => [?_meta(html, 'author'), if (_meta(html, 'author') == null) ?_meta(html, 'article:author')];

StructuredPage? _fromMeta(String html, String text) {
  final price = _number(_meta(html, 'product:price:amount') ?? _meta(html, 'og:price:amount'));
  if (price != null) {
    return StructuredPage(
      type: PageType.product,
      name: _meta(html, 'og:title'),
      price: price,
      currency: (_meta(html, 'product:price:currency') ?? _meta(html, 'og:price:currency'))?.toUpperCase(),
    );
  }
  final words = RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(text).length;
  if (_meta(html, 'og:type')?.toLowerCase() == 'article' && words >= _articleWords) {
    return StructuredPage(
      type: PageType.article,
      name: _meta(html, 'og:title'),
      authors: _metaAuthors(html),
      published: _date(_meta(html, 'article:published_time')),
      readingMinutes: (words / _wordsPerMinute).ceil(),
    );
  }
  return null;
}

// текст для чтения: внутри <article>, иначе все абзацы; без скриптов и стилей
String _readableText(String html) {
  final cleaned = html.replaceAll(RegExp(r'<(script|style|noscript|nav|header|footer)\b.*?</\1>', caseSensitive: false, dotAll: true), ' ');
  final article = RegExp(r'<article\b[^>]*>(.*?)</article>', caseSensitive: false, dotAll: true).firstMatch(cleaned)?.group(1);
  final source = article ?? [for (final match in RegExp(r'<p\b[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).allMatches(cleaned)) match.group(1)!].join(' ');
  return _plain(source);
}
