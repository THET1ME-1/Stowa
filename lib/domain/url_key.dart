// метки рекламы и пересылки: страница от них не меняется
final _tracking = RegExp(r'^(utm_\w+|fbclid|gclid|yclid|si|igsh|igshid|feature|ref|ref_src|share_id|_t|_r)$');

/// Адрес, по которому две ссылки — одна страница: без схемы, `www.`, `m.`, хвостового `/`,
/// якоря и меток рекламы; параметры по алфавиту. Ролик YouTube сводится к его номеру.
String urlKey(String url) {
  final uri = Uri.tryParse(url.trim().contains('://') ? url.trim() : 'https://${url.trim()}');
  if (uri == null || uri.host.isEmpty) return url.trim().toLowerCase();
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^(www|m)\.'), '');
  if (_youtubeId(host, uri) case final id?) return 'youtube.com/watch?v=$id';
  final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
  final params = [
    for (final entry in uri.queryParametersAll.entries)
      if (!_tracking.hasMatch(entry.key)) for (final value in entry.value) '${entry.key}=$value',
  ]..sort();
  return params.isEmpty ? '$host$path' : '$host$path?${params.join('&')}';
}

String? _youtubeId(String host, Uri uri) {
  if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) return uri.pathSegments.first;
  if (host != 'youtube.com') return null;
  if (uri.queryParameters['v'] case final id?) return id;
  final segments = uri.pathSegments;
  if (segments.length >= 2 && (segments.first == 'shorts' || segments.first == 'live')) return segments[1];
  return null;
}
