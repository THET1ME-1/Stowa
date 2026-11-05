/// Что можно прочитать в ролике без звука и без ИИ: субтитры со временем, главы
/// из описания, хэштеги автора. YouTube и TikTok отдают это без ключа.
library;

import 'dart:convert';

import 'structured_page.dart' show Chapter;

/// Фраза субтитров и с какой секунды она звучит.
class Phrase {
  const Phrase(this.seconds, this.text);

  final double seconds;
  final String text;
}

/// Дорожка субтитров: язык, адрес, сделана ли она автоматически.
class CaptionTrack {
  const CaptionTrack(this.language, this.url, {this.automatic = false});

  final String language;
  final String url;
  final bool automatic;
}

/// Номер ролика YouTube из любой формы адреса: watch, youtu.be, shorts, live, music.
String? youtubeId(Uri uri) {
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^(www|m|music)\.'), '');
  final id = switch (host) {
    'youtu.be' => uri.pathSegments.firstOrNull,
    'youtube.com' || 'youtube-nocookie.com' => switch (uri.pathSegments) {
      ['watch', ...] => uri.queryParameters['v'],
      [('shorts' || 'live' || 'embed' || 'v'), final id, ...] => id,
      _ => null,
    },
    _ => null,
  };
  return id != null && RegExp(r'^[\w-]{11}$').hasMatch(id) ? id : null;
}

/// Тот же ролик с нужной секунды: касание по фразе субтитров открывает это место.
Uri videoAt(Uri video, int seconds) => video.replace(queryParameters: {...video.queryParameters, 't': '$seconds'});

String _entities(String text) => text
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&apos;', "'")
    .replaceAll('&nbsp;', ' ')
    .replaceAllMapped(RegExp(r'&#(\d+);'), (match) => String.fromCharCode(int.parse(match.group(1)!)));

String _clean(String text) => _entities(_entities(text.replaceAll(RegExp(r'<[^>]*>'), ''))).replaceAll(RegExp(r'\s+'), ' ').trim();

/// Субтитры YouTube: формат srv3 (`<p t="мс">`) и старый (`<text start="с">`).
List<Phrase> parseYoutubeCaptions(String xml) {
  final phrases = <Phrase>[];
  for (final match in RegExp(r'<p\b[^>]*\bt="(\d+)"[^>]*>(.*?)</p>', dotAll: true).allMatches(xml)) {
    final text = _clean(match.group(2)!);
    if (text.isNotEmpty) phrases.add(Phrase(int.parse(match.group(1)!) / 1000, text));
  }
  if (phrases.isNotEmpty) return phrases;
  for (final match in RegExp(r'<text\b[^>]*\bstart="([\d.]+)"[^>]*>(.*?)</text>', dotAll: true).allMatches(xml)) {
    final text = _clean(match.group(2)!);
    if (text.isNotEmpty) phrases.add(Phrase(double.parse(match.group(1)!), text));
  }
  return phrases;
}

final _cueTime = RegExp(r'^(?:(\d+):)?(\d{1,2}):(\d{2})[.,](\d{1,3})\s*-->');

/// Субтитры WebVTT (TikTok и другие): время начала и текст; одинаковые подряд — один раз.
List<Phrase> parseWebVtt(String vtt) {
  final phrases = <Phrase>[];
  for (final block in vtt.replaceAll('\r', '').split(RegExp(r'\n\s*\n'))) {
    final lines = block.split('\n');
    final at = lines.indexWhere((line) => line.contains('-->'));
    if (at < 0) continue;
    final time = _cueTime.firstMatch(lines[at].trim());
    if (time == null) continue;
    final seconds = (int.parse(time.group(1) ?? '0')) * 3600 + int.parse(time.group(2)!) * 60 + int.parse(time.group(3)!) + int.parse(time.group(4)!.padRight(3, '0')) / 1000;
    final text = _clean(lines.skip(at + 1).join(' '));
    if (text.isEmpty || (phrases.isNotEmpty && phrases.last.text == text)) continue;
    phrases.add(Phrase(seconds, text));
  }
  return phrases;
}

final _chapterLine = RegExp(r'^\s*[(\[]?((?:\d{1,2}:)?\d{1,2}:\d{2})[)\]]?\s*[-–—:|.]?\s*(.+?)\s*$');

/// Главы из описания: строки «0:00 Вступление». Как у YouTube: первая с нуля, хотя бы две.
List<Chapter> chaptersFrom(String description) {
  final chapters = <Chapter>[];
  for (final line in description.split('\n')) {
    final match = _chapterLine.firstMatch(line);
    if (match == null) continue;
    final parts = match.group(1)!.split(':').map(int.parse).toList();
    final seconds = parts.length == 3 ? parts[0] * 3600 + parts[1] * 60 + parts[2] : parts[0] * 60 + parts[1];
    if (chapters.isNotEmpty && seconds <= chapters.last.seconds) continue;
    chapters.add(Chapter(seconds, match.group(2)!));
  }
  if (chapters.length < 2 || chapters.first.seconds != 0) return const [];
  return chapters;
}

/// Хэштеги автора: буквы любого языка, цифры и подчёркивание; одни цифры — не хэштег.
List<String> hashtagsIn(String text) {
  final seen = <String>{};
  return [
    for (final match in RegExp(r'(?<![\p{L}\p{N}_])#([\p{L}\p{N}_]+)', unicode: true).allMatches(text))
      if (!RegExp(r'^\d+$').hasMatch(match.group(1)!) && seen.add(match.group(1)!.toLowerCase())) match.group(1)!.toLowerCase(),
  ];
}

// трёхбуквенные коды TikTok («rus-RU») к двухбуквенным
const _iso3 = {'rus': 'ru', 'eng': 'en', 'ukr': 'uk', 'ron': 'ro', 'rum': 'ro', 'pol': 'pl', 'deu': 'de', 'ger': 'de', 'spa': 'es'};

String _language(String code) {
  final head = code.toLowerCase().split(RegExp('[-_]')).first;
  return _iso3[head] ?? head;
}

/// Дорожка на нужном языке: сперва сделанная людьми, потом автоматическая, потом любая.
CaptionTrack? pickTrack(List<CaptionTrack> tracks, List<String> languages) {
  if (tracks.isEmpty) return null;
  final wanted = [for (final language in languages) _language(language)];
  for (final automatic in [false, true]) {
    for (final language in wanted) {
      for (final track in tracks) {
        if (track.automatic == automatic && _language(track.language) == language) return track;
      }
    }
  }
  return tracks.firstWhere((track) => !track.automatic, orElse: () => tracks.first);
}

/// Что YouTube рассказал о ролике.
class YoutubePlayer {
  const YoutubePlayer({required this.tracks, this.seconds, this.author, this.description = '', this.chapters = const [], this.hashtags = const []});

  final List<CaptionTrack> tracks;
  final int? seconds;
  final String? author;
  final String description;
  final List<Chapter> chapters;
  final List<String> hashtags;
}

/// Ответ плеера YouTube (клиент ANDROID). Ролик недоступен — null.
YoutubePlayer? parseYoutubePlayer(Map<String, Object?> json) {
  final status = (json['playabilityStatus'] as Map?)?['status'];
  final details = json['videoDetails'];
  if (status != 'OK' || details is! Map) return null;
  final renderer = ((json['captions'] as Map?)?['playerCaptionsTracklistRenderer'] as Map?)?['captionTracks'];
  final description = details['shortDescription'] as String? ?? '';
  return YoutubePlayer(
    tracks: [
      for (final track in (renderer is List ? renderer : const []))
        if (track is Map && track['baseUrl'] is String) CaptionTrack(track['languageCode'] as String? ?? '', track['baseUrl'] as String, automatic: track['kind'] == 'asr'),
    ],
    seconds: int.tryParse('${details['lengthSeconds']}'),
    author: details['author'] as String?,
    description: description,
    chapters: chaptersFrom(description),
    hashtags: hashtagsIn(description),
  );
}

/// Что TikTok положил в страницу ролика.
class TiktokVideo {
  const TiktokVideo({required this.caption, this.author, this.hashtags = const [], this.seconds, this.cover, this.tracks = const []});

  final String caption;
  final String? author;
  final List<String> hashtags;
  final int? seconds;
  final String? cover;
  final List<CaptionTrack> tracks;

  /// Заголовок вещи: подпись без хэштегов, а из одних хэштегов — автор.
  String get title {
    final words = caption.replaceAll(RegExp(r'#[^\s#]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (words.isNotEmpty) return words;
    return author ?? caption.trim();
  }
}

/// Данные страницы TikTok (`__UNIVERSAL_DATA_FOR_REHYDRATION__`). Нет ролика — null.
TiktokVideo? parseTiktokPage(String html) {
  final script = RegExp(r'<script[^>]*id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>(.*?)</script>', dotAll: true).firstMatch(html);
  if (script == null) return null;
  try {
    final data = jsonDecode(script.group(1)!) as Map<String, Object?>;
    final scope = data['__DEFAULT_SCOPE__'] as Map? ?? const {};
    // браузеру с компьютера ролик лежит под video-detail, телефону — под reflow.video.detail
    final detail = (scope['webapp.video-detail'] ?? scope['webapp.reflow.video.detail']) as Map? ?? const {};
    final item = ((detail['itemInfo'] as Map?)?['itemStruct'] as Map?) ?? const {};
    if (item.isEmpty) return null;
    final caption = item['desc'] as String? ?? '';
    final video = item['video'] as Map? ?? const {};
    final author = item['author'] as Map?;
    final challenges = [
      for (final challenge in (item['challenges'] as List? ?? const []))
        if (challenge is Map && challenge['title'] is String && (challenge['title'] as String).isNotEmpty) (challenge['title'] as String).toLowerCase(),
    ];
    return TiktokVideo(
      caption: caption,
      author: (author?['nickname'] ?? author?['uniqueId']) as String?,
      hashtags: challenges.isEmpty ? hashtagsIn(caption) : challenges,
      seconds: video['duration'] is num ? (video['duration'] as num).round() : null,
      cover: [video['cover'], video['originCover'], video['dynamicCover']].whereType<String>().where((url) => url.isNotEmpty).firstOrNull,
      tracks: [
        for (final track in (video['subtitleInfos'] as List? ?? const []))
          if (track is Map && track['Url'] is String && (track['Format'] == null || '${track['Format']}'.toLowerCase().contains('vtt')))
            CaptionTrack('${track['LanguageCodeName'] ?? ''}', track['Url'] as String, automatic: track['Source'] != 'MANUAL'),
      ],
    );
  } on FormatException {
    return null;
  }
}
