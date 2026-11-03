import 'dart:convert';

/// Что известно о странице по ссылке: заголовок, описание, картинка, сайт.
class LinkPreview {
  const LinkPreview({this.title, this.description, this.imageUrl, required this.siteName, this.author, this.duration});

  final String? title;
  final String? description;
  final Uri? imageUrl;
  final String siteName;

  /// Автор ролика: канал на YouTube, ник в TikTok.
  final String? author;
  final Duration? duration;

  /// Чего нет здесь, берётся из [other]: oEmbed знает автора, страница — описание и длину.
  LinkPreview merge(LinkPreview other) => LinkPreview(
    title: title ?? other.title,
    description: description ?? other.description,
    imageUrl: imageUrl ?? other.imageUrl,
    siteName: siteName,
    author: author ?? other.author,
    duration: duration ?? other.duration,
  );
}

/// Сайт без «www.»: «habr.com».
String siteOf(Uri page) => page.host.replaceFirst(RegExp(r'^www\.'), '');

final _metaTag = RegExp(r'<meta\b[^>]*>', caseSensitive: false);
final _attribute = RegExp(r'''([\w:-]+)\s*=\s*("([^"]*)"|'([^']*)')''');
final _titleTag = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false);
final _isoDuration = RegExp(r'^P(?:T)?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$');

/// Превью из разметки страницы. og-теги главнее твиттерных, те главнее `<title>`.
LinkPreview parseHtmlPreview(String html, Uri page) {
  final meta = <String, String>{};
  for (final tag in _metaTag.allMatches(html)) {
    final attributes = <String, String>{
      for (final one in _attribute.allMatches(tag.group(0)!)) one.group(1)!.toLowerCase(): one.group(3) ?? one.group(4)!,
    };
    final key = attributes['property'] ?? attributes['name'] ?? attributes['itemprop'];
    final content = attributes['content'];
    if (key == null || content == null) continue;
    // первое значение главнее: страницы повторяют теги, и первое — основное
    meta.putIfAbsent(key.toLowerCase(), () => content);
  }
  String? pick(List<String> keys) {
    for (final key in keys) {
      final value = _clean(meta[key]);
      if (value != null) return value;
    }
    return null;
  }

  final image = pick(['og:image', 'og:image:url', 'twitter:image', 'twitter:image:src']);
  final seconds = int.tryParse(meta['og:video:duration'] ?? meta['video:duration'] ?? '');
  return LinkPreview(
    title: pick(['og:title', 'twitter:title']) ?? _clean(_titleTag.firstMatch(html)?.group(1)),
    description: pick(['og:description', 'twitter:description', 'description']),
    imageUrl: image == null ? null : page.resolve(image),
    siteName: pick(['og:site_name']) ?? siteOf(page),
    duration: seconds != null ? Duration(seconds: seconds) : _parseIsoDuration(meta['duration']),
  );
}

Duration? _parseIsoDuration(String? text) {
  final match = _isoDuration.firstMatch(text?.trim() ?? '');
  if (match == null || match.group(0)!.length < 3) return null;
  int part(int index) => int.tryParse(match.group(index) ?? '') ?? 0;
  return Duration(hours: part(1), minutes: part(2), seconds: part(3));
}

/// Куда спрашивать готовое описание ролика: у YouTube и TikTok есть открытый oEmbed.
Uri? oembedEndpoint(Uri page) {
  final host = siteOf(page);
  final url = page.toString();
  if (host == 'youtube.com' || host == 'm.youtube.com' || host == 'youtu.be' || host == 'music.youtube.com') {
    return Uri.https('www.youtube.com', '/oembed', {'url': url, 'format': 'json'});
  }
  if (host == 'tiktok.com' || host.endsWith('.tiktok.com')) return Uri.https('www.tiktok.com', '/oembed', {'url': url});
  return null;
}

LinkPreview parseOembed(Map<String, Object?> json, Uri page) {
  final image = _clean(json['thumbnail_url'] as String?);
  return LinkPreview(
    title: _clean(json['title'] as String?),
    author: _clean(json['author_name'] as String?),
    imageUrl: image == null ? null : page.resolve(image),
    siteName: _clean(json['provider_name'] as String?) ?? siteOf(page),
  );
}

/// Текст страницы из байтов. Кодировка из заголовка ответа, иначе из `<meta charset>`, иначе UTF-8.
String decodePage(List<int> bytes, String? contentType) {
  var charset = RegExp(r'charset=([\w-]+)', caseSensitive: false).firstMatch(contentType ?? '')?.group(1);
  if (charset == null) {
    final head = latin1.decode(bytes.take(4096).toList(), allowInvalid: true);
    charset = RegExp(r'''<meta[^>]+charset=["']?([\w-]+)''', caseSensitive: false).firstMatch(head)?.group(1);
  }
  switch (charset?.toLowerCase()) {
    case 'windows-1251' || 'cp1251':
      return String.fromCharCodes(bytes.map((byte) => byte < 0x80 ? byte : _cp1251[byte - 0x80]));
    case 'iso-8859-1' || 'latin1' || 'windows-1252':
      return latin1.decode(bytes, allowInvalid: true);
    default:
      return utf8.decode(bytes, allowMalformed: true);
  }
}

String? _clean(String? text) {
  if (text == null) return null;
  final cleaned = _unescape(text).replaceAll(RegExp(r'\s+'), ' ').trim();
  return cleaned.isEmpty ? null : cleaned;
}

const _entities = {'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' ', 'mdash': '—', 'ndash': '–', 'laquo': '«', 'raquo': '»', 'hellip': '…'};

String _unescape(String text) => text.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#\d+|\w+);'), (match) {
  final code = match.group(1)!;
  if (code.startsWith('#x')) return String.fromCharCode(int.parse(code.substring(2), radix: 16));
  if (code.startsWith('#')) return String.fromCharCode(int.parse(code.substring(1)));
  return _entities[code] ?? match.group(0)!;
});

// вторая половина windows-1251, байты 0x80–0xFF
final _cp1251 = [
  0x0402, 0x0403, 0x201A, 0x0453, 0x201E, 0x2026, 0x2020, 0x2021, 0x20AC, 0x2030, 0x0409, 0x2039, 0x040A, 0x040C, 0x040B, 0x040F,
  0x0452, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0xFFFD, 0x2122, 0x0459, 0x203A, 0x045A, 0x045C, 0x045B, 0x045F,
  0x00A0, 0x040E, 0x045E, 0x0408, 0x00A4, 0x0490, 0x00A6, 0x00A7, 0x0401, 0x00A9, 0x0404, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x0407,
  0x00B0, 0x00B1, 0x0406, 0x0456, 0x0491, 0x00B5, 0x00B6, 0x00B7, 0x0451, 0x2116, 0x0454, 0x00BB, 0x0458, 0x0405, 0x0455, 0x0457,
  for (var code = 0x0410; code <= 0x044F; code++) code,
];
