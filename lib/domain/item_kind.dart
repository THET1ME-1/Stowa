import 'models.dart';

// адрес со схемой или голый домен с зоной из двух и больше букв; за зоной не «@» — иначе это почта
final _url = RegExp(r'(?<![@\w.])((?:https?://)?(?:[a-z0-9-]+\.)+[a-z]{2,}(?![@\w-])(?:/[^\s]*)?)', caseSensitive: false);

const _videoHosts = ['tiktok.com', 'youtube.com', 'youtu.be', 'rutube.ru', 'vkvideo.ru', 'vimeo.com'];

/// Первая ссылка в тексте. Почта ссылкой не считается.
Uri? firstUrl(String text) {
  for (final match in _url.allMatches(text)) {
    final raw = match.group(1)!;
    final withScheme = raw.contains('://') ? raw : 'https://$raw';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) continue;
    // «1.5» и подобные числа доменом не бывают
    if (RegExp(r'^[\d.]+$').hasMatch(uri.host)) continue;
    return uri;
  }
  return null;
}

const _brands = {
  'tiktok.com': 'TikTok',
  'youtube.com': 'YouTube',
  'youtu.be': 'YouTube',
  'instagram.com': 'Instagram',
  'rutube.ru': 'Rutube',
  'vkvideo.ru': 'VK Видео',
  'vk.com': 'VK',
  'vimeo.com': 'Vimeo',
  'pinterest.com': 'Pinterest',
  't.me': 'Telegram',
};

/// Откуда вещь: известный сервис по имени, остальное — адрес без www.
String sourceName(String host) {
  final bare = host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  for (final MapEntry(key: domain, value: brand) in _brands.entries) {
    if (bare == domain || bare.endsWith('.$domain')) return brand;
  }
  return bare;
}

/// Ссылки в тексте по местам: строка ввода их подчёркивает.
Iterable<Match> urlMatches(String text) => _url.allMatches(text);

bool _isVideoHost(Uri uri) {
  final host = uri.host.toLowerCase();
  final hit = _videoHosts.any((video) => host == video || host.endsWith('.$video'));
  if (hit) return true;
  return (host == 'instagram.com' || host.endsWith('.instagram.com')) && uri.path.startsWith('/reel');
}

/// Картинки, которые приложение умеет показать само. Остальные `image/*` — макет Photoshop,
/// TIFF, SVG, снимки камеры в RAW — остаются файлами: плитка с пустой рамкой вместо картинки
/// хуже, чем честная карточка файла, который откроет программа системы.
/// Список для SQL: `attachments.mime IN ($shownImageMimes)`. Раньше везде стояло
/// `LIKE 'image/%'`, и макет Photoshop попадал в обложки, галерею и разбор картинок.
const shownImageMimes = "'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp', 'image/heic', 'image/heif', 'image/avif', 'image/x-icon', 'image/vnd.microsoft.icon'";

/// Те же типы набором: один источник с [shownImageMimes].
final Set<String> shownImageTypes = {for (final quoted in shownImageMimes.split(', ')) quoted.substring(1, quoted.length - 1)};

bool showsAsImage(String mime) => shownImageTypes.contains(mime.toLowerCase());

/// Вид вещи по содержимому: тип файла главнее текста.
ItemKind detectKind({String text = '', String? mime}) {
  if (mime != null) {
    if (showsAsImage(mime)) return ItemKind.image;
    if (mime.startsWith('audio/')) return ItemKind.voice;
    if (mime.startsWith('video/')) return ItemKind.video;
    return ItemKind.file;
  }
  final url = firstUrl(text);
  if (url == null) return ItemKind.note;
  // ссылка с подписью — ссылка; заметка, где ссылка лишь одна из строк, — заметка
  final words = text.replaceAll(_url, ' ').split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  final lines = text.split('\n').where((line) => line.trim().isNotEmpty).length;
  if (words > 12 || lines > 2) return ItemKind.note;
  return _isVideoHost(url) ? ItemKind.video : ItemKind.link;
}
