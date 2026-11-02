import 'models.dart';

// адрес со схемой или голый домен с зоной из двух и больше букв
final _url = RegExp(
  r'(?<![@\w.])((?:https?://)?(?:[a-z0-9-]+\.)+[a-z]{2,}(?:/[^\s]*)?)',
  caseSensitive: false,
);

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

/// Ссылки в тексте по местам: строка ввода их подчёркивает.
Iterable<Match> urlMatches(String text) => _url.allMatches(text);

bool _isVideoHost(Uri uri) {
  final host = uri.host.toLowerCase();
  final hit = _videoHosts.any((video) => host == video || host.endsWith('.$video'));
  if (hit) return true;
  return (host == 'instagram.com' || host.endsWith('.instagram.com')) && uri.path.startsWith('/reel');
}

/// Вид вещи по содержимому: тип файла главнее текста.
ItemKind detectKind({String text = '', String? mime}) {
  if (mime != null) {
    if (mime.startsWith('image/')) return ItemKind.image;
    if (mime.startsWith('audio/')) return ItemKind.voice;
    if (mime.startsWith('video/')) return ItemKind.video;
    return ItemKind.file;
  }
  final url = firstUrl(text);
  if (url == null) return ItemKind.note;
  return _isVideoHost(url) ? ItemKind.video : ItemKind.link;
}
