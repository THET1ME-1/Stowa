import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/link_preview.dart';

void main() {
  final page = Uri.parse('https://habr.com/ru/articles/845872/');

  test('og-теги главнее <title>, относительная картинка достраивается до полной', () {
    const html = '''
<html><head>
<title>Запасной заголовок | Хабр</title>
<meta property="og:title" content="Как устроен сборщик мусора в Dart">
<meta property="og:description" content="Разбираем поколения &amp; арены">
<meta property="og:image" content="/share/img.png">
<meta property="og:site_name" content="Хабр">
</head></html>''';
    final preview = parseHtmlPreview(html, page);
    expect(preview.title, 'Как устроен сборщик мусора в Dart');
    expect(preview.description, 'Разбираем поколения & арены');
    expect(preview.imageUrl, Uri.parse('https://habr.com/share/img.png'));
    expect(preview.siteName, 'Хабр');
  });

  test('без тегов: заголовок из <title>, сайт из домена без www', () {
    final preview = parseHtmlPreview('<title>\n  Главная  страница \n</title>', Uri.parse('https://www.example.org/a'));
    expect(preview.title, 'Главная страница');
    expect(preview.siteName, 'example.org');
    expect(preview.imageUrl, isNull);
  });

  test('атрибуты в любом порядке и в одинарных кавычках, name вместо property', () {
    const html = "<meta content='Описание' name='description'><meta content=\"Тв\" name=\"twitter:title\">";
    final preview = parseHtmlPreview(html, page);
    expect(preview.description, 'Описание');
    expect(preview.title, 'Тв');
  });

  test('длина ролика из itemprop duration', () {
    final preview = parseHtmlPreview('<meta itemprop="duration" content="PT3M33S">', page);
    expect(preview.duration, const Duration(minutes: 3, seconds: 33));
  });

  test('oEmbed YouTube и TikTok: адрес запроса', () {
    expect(oembedEndpoint(Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ'))!.host, 'www.youtube.com');
    expect(oembedEndpoint(Uri.parse('https://youtu.be/dQw4w9WgXcQ'))!.queryParameters['url'], 'https://youtu.be/dQw4w9WgXcQ');
    expect(oembedEndpoint(Uri.parse('https://www.tiktok.com/@a/video/1'))!.path, '/oembed');
    expect(oembedEndpoint(page), isNull);
  });

  test('oEmbed даёт заголовок, автора и обложку', () {
    final preview = parseOembed({
      'title': 'Rick Astley - Never Gonna Give You Up',
      'author_name': 'Rick Astley',
      'provider_name': 'YouTube',
      'thumbnail_url': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
    }, Uri.parse('https://youtu.be/dQw4w9WgXcQ'));
    expect(preview.title, 'Rick Astley - Never Gonna Give You Up');
    expect(preview.author, 'Rick Astley');
    expect(preview.siteName, 'YouTube');
    expect(preview.imageUrl.toString(), 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
  });

  test('кодировка windows-1251 из <meta charset> читается', () {
    // «Привет» в cp1251
    final bytes = [...ascii.encode('<meta charset="windows-1251"><title>'), 0xCF, 0xF0, 0xE8, 0xE2, 0xE5, 0xF2, ...ascii.encode('</title>')];
    expect(decodePage(bytes, null), contains('Привет'));
    expect(decodePage(utf8.encode('<title>Ёж</title>'), 'text/html; charset=utf-8'), contains('Ёж'));
  });

  test('числовые и именованные сущности в заголовке', () {
    final preview = parseHtmlPreview('<meta property="og:title" content="A &#8212; B &quot;C&quot; &#x41;&nbsp;D">', page);
    expect(preview.title, 'A — B "C" A D');
  });
}
