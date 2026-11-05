import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/video_text.dart';

void main() {
  test('номер ролика YouTube из любой формы адреса', () {
    for (final url in [
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42',
      'https://youtu.be/dQw4w9WgXcQ?si=abc',
      'https://m.youtube.com/watch?v=dQw4w9WgXcQ',
      'https://www.youtube.com/shorts/dQw4w9WgXcQ',
      'https://youtube.com/live/dQw4w9WgXcQ',
      'https://music.youtube.com/watch?v=dQw4w9WgXcQ&list=x',
    ]) {
      expect(youtubeId(Uri.parse(url)), 'dQw4w9WgXcQ', reason: url);
    }
    expect(youtubeId(Uri.parse('https://www.youtube.com/@channel')), isNull);
    expect(youtubeId(Uri.parse('https://vimeo.com/1')), isNull);
  });

  test('адрес ролика с нужной секунды', () {
    expect(videoAt(Uri.parse('https://youtu.be/dQw4w9WgXcQ?si=a'), 42).toString(), 'https://youtu.be/dQw4w9WgXcQ?si=a&t=42');
    expect(videoAt(Uri.parse('https://www.youtube.com/watch?v=x&t=10'), 95).queryParameters['t'], '95');
  });

  test('фразы YouTube srv3 и старого вида', () {
    const srv3 = '<timedtext format="3"><body><p t="1360" d="1680">♪ We&#39;re no strangers ♪</p><p t="18800" d="1200"><s>Never</s><s t="300"> gonna</s></p><p t="20000" d="10"></p></body></timedtext>';
    final phrases = parseYoutubeCaptions(srv3);
    expect(phrases.map((phrase) => (phrase.seconds, phrase.text)), [(1.36, "♪ We're no strangers ♪"), (18.8, 'Never gonna')]);
    const old = '<transcript><text start="3.5" dur="2">Привет &amp;amp; пока</text></transcript>';
    expect(parseYoutubeCaptions(old).single.text, 'Привет & пока');
  });

  test('субтитры WebVTT: время, теги и повторы', () {
    const vtt = 'WEBVTT\n\n1\n00:00:01.000 --> 00:00:03.500\nСегодня готовим <c.yellow>пасту</c>\n\n00:01:02.250 --> 00:01:04.000\nДобавляем сыр\nи перец\n\n00:01:04.000 --> 00:01:05.000\nДобавляем сыр\nи перец\n';
    final phrases = parseWebVtt(vtt);
    expect(phrases.map((phrase) => (phrase.seconds, phrase.text)), [(1.0, 'Сегодня готовим пасту'), (62.25, 'Добавляем сыр и перец')]);
  });

  test('главы из описания ролика: с нуля и хотя бы две', () {
    const description = 'Ремонт кухни своими руками\n\n0:00 Вступление\n1:35 - Плитка\n(12:04) Затирка\n1:02:03 Итоги\nПодписывайтесь!';
    expect(chaptersFrom(description).map((chapter) => (chapter.seconds, chapter.title)), [(0, 'Вступление'), (95, 'Плитка'), (724, 'Затирка'), (3723, 'Итоги')]);
    expect(chaptersFrom('В 2:30 начинается самое интересное'), isEmpty);
    expect(chaptersFrom('0:00 Только одна'), isEmpty);
  });

  test('хэштеги на любом языке, без повторов', () {
    expect(hashtagsIn('Паста за 10 минут #рецепт #pasta #Рецепт #ужин_быстро, #2024 и #'), ['рецепт', 'pasta', 'ужин_быстро']);
  });

  test('выбор дорожки: своя на нужном языке, потом автоматическая, потом любая', () {
    const tracks = [
      CaptionTrack('en', 'https://a/en', automatic: true),
      CaptionTrack('ru', 'https://a/ru-auto', automatic: true),
      CaptionTrack('de', 'https://a/de'),
    ];
    expect(pickTrack(tracks, ['ru', 'en'])!.url, 'https://a/ru-auto');
    expect(pickTrack([...tracks, const CaptionTrack('ru-RU', 'https://a/ru')], ['ru', 'en'])!.url, 'https://a/ru');
    expect(pickTrack(tracks, ['pl'])!.url, 'https://a/de');
    expect(pickTrack(const [], ['ru']), isNull);
  });

  test('ответ плеера YouTube: дорожки, длина, автор, описание', () {
    final player = parseYoutubePlayer({
      'playabilityStatus': {'status': 'OK'},
      'videoDetails': {'lengthSeconds': '213', 'author': 'Rick Astley', 'shortDescription': '0:00 Начало\n1:00 Припев #nggyu', 'keywords': ['rick astley']},
      'captions': {
        'playerCaptionsTracklistRenderer': {
          'captionTracks': [
            {'baseUrl': 'https://www.youtube.com/api/timedtext?v=1&lang=en', 'languageCode': 'en'},
            {'baseUrl': 'https://www.youtube.com/api/timedtext?v=1&lang=en&kind=asr', 'languageCode': 'en', 'kind': 'asr'},
          ],
        },
      },
    })!;
    expect(player.seconds, 213);
    expect(player.author, 'Rick Astley');
    expect(player.tracks.map((track) => track.automatic), [false, true]);
    expect(player.chapters, hasLength(2));
    expect(player.hashtags, ['nggyu']);
  });

  test('данные страницы TikTok: подпись, хэштеги, длина, субтитры', () {
    final data = {
      '__DEFAULT_SCOPE__': {
        'webapp.video-detail': {
          'statusCode': 0,
          'itemInfo': {
            'itemStruct': {
              'desc': 'Паста за 5 минут #рецепт #паста',
              'author': {'uniqueId': 'chef', 'nickname': 'Шеф'},
              'challenges': [{'title': 'рецепт'}, {'title': 'паста'}],
              'video': {
                'duration': 47,
                'subtitleInfos': [
                  {'LanguageCodeName': 'eng-US', 'Url': 'https://tt/en.vtt', 'Format': 'webvtt', 'Source': 'ASR'},
                  {'LanguageCodeName': 'rus-RU', 'Url': 'https://tt/ru.vtt', 'Format': 'webvtt', 'Source': 'MT'},
                ],
              },
            },
          },
        },
      },
    };
    final html = '<html><script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">${jsonEncode(data)}</script></html>';
    final tiktok = parseTiktokPage(html)!;
    expect(tiktok.caption, 'Паста за 5 минут #рецепт #паста');
    expect(tiktok.author, 'Шеф');
    expect(tiktok.hashtags, ['рецепт', 'паста']);
    expect(tiktok.seconds, 47);
    expect(pickTrack(tiktok.tracks, ['ru'])!.url, 'https://tt/ru.vtt');
    expect(parseTiktokPage('<html>нет данных</html>'), isNull);
  });
}
