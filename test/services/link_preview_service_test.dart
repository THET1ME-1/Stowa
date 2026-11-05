import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/link_preview.dart' show oembedEndpoint;
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/site_sources.dart';
import 'package:stowa/domain/structured_page.dart';
import 'package:stowa/services/link_preview_service.dart';
import 'package:stowa/services/page_cache.dart';

void main() {
  late AppDatabase db;
  late Directory home;
  final now = DateTime(2026, 11, 3, 12);
  final requests = <Uri>[];

  setUp(() {
    db = AppDatabase.memory();
    home = Directory.systemTemp.createTempSync('stowa_preview');
    requests.clear();
  });
  tearDown(() async {
    await db.close();
    home.deleteSync(recursive: true);
  });

  Future<void> addLink(String url, {String? title, ItemKind kind = ItemKind.link}) => db.into(db.items).insert(ItemsCompanion.insert(
        id: 'a',
        kind: kind,
        title: title ?? url,
        body: Value(url),
        url: Value(url),
        createdAt: now,
        updatedAt: now,
      ));

  Future<Item> item() => db.select(db.items).getSingle();

  LinkPreviewService service(Map<String, FetchReply> replies) => LinkPreviewService(
        db,
        filesRoot: home,
        clock: () => now,
        fetch: (uri) async {
          requests.add(uri);
          final reply = replies[uri.toString()];
          if (reply == null) throw const SocketException('нет сети');
          return reply;
        },
      );

  FetchReply page(String html) => FetchReply(200, utf8.encode(html), 'text/html; charset=utf-8');
  final png = FetchReply(200, base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='), 'image/png');

  group('TikTok', () {
    String tiktokPage(Map<String, Object?> item) =>
        '<html><head><title>TikTok - Make Your Day</title></head><script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">${jsonEncode({
          '__DEFAULT_SCOPE__': {
            'webapp.reflow.video.detail': {'itemInfo': {'itemStruct': item}},
          },
        })}</script></html>';

    test('короткая ссылка: oEmbed пустой, название, автор, обложка и длина — со страницы ролика', () async {
      const url = 'https://vm.tiktok.com/ZMh3Qe4Bk/';
      await addLink(url, kind: ItemKind.video);
      await service({
        // oEmbed TikTok теперь отдаёт только размеры, а короткие ссылки не принимает вовсе
        oembedEndpoint(Uri.parse(url)).toString(): FetchReply(400, utf8.encode('{"message":"Something went wrong","code":400}'), 'application/json'),
        url: page(tiktokPage({
          'desc': 'Сдаю на права с первого раза #автошкола',
          'author': {'nickname': 'Автошкола Майстер'},
          'video': {'duration': 7, 'cover': 'https://p16.tiktokcdn.com/cover.jpg'},
        })),
        'https://p16.tiktokcdn.com/cover.jpg': png,
      }).fetchFor('a');
      final saved = await item();
      expect(saved.title, 'Сдаю на права с первого раза');
      expect(saved.previewSite, 'TikTok');
      expect(saved.previewAuthor, 'Автошкола Майстер');
      expect(saved.previewText, 'Сдаю на права с первого раза #автошкола');
      expect(saved.durationSeconds, 7);
      expect(saved.coverPath, isNotNull);
    });

    test('страница без данных ролика: заглушка «TikTok - Make Your Day» заголовком не становится', () async {
      const url = 'https://vm.tiktok.com/ZMh3Qe4Bk/';
      await addLink(url, kind: ItemKind.video);
      await service({url: page('<html><head><title>TikTok - Make Your Day</title></head></html>')}).fetchFor('a');
      final saved = await item();
      expect(saved.title, url);
      expect(saved.previewSite, 'TikTok');
    });
  });

  group('известные сайты', () {
    final headersSent = <String, Map<String, String>>{};
    LinkPreviewService known(Map<String, FetchReply> replies) => LinkPreviewService(
      db,
      filesRoot: home,
      clock: () => now,
      fetch: (uri) async {
        requests.add(uri);
        final reply = replies[uri.toString()];
        if (reply == null) throw const SocketException('нет сети');
        return reply;
      },
      fetchWith: (uri, headers) async {
        requests.add(uri);
        headersSent[uri.toString()] = headers;
        final reply = replies[uri.toString()];
        if (reply == null) throw const SocketException('нет сети');
        return reply;
      },
    );
    FetchReply json(Object body) => FetchReply(200, utf8.encode(jsonEncode(body)), 'application/json');

    test('MangaLib: тайтл из API с номером сайта — русское имя, описание, обложка, страница для извлекателей', () async {
      const url = 'https://mangalib.me/ru/manga/7965--chainsaw-man';
      await addLink(url);
      final api = libRequest(Uri.parse(url))!.api.toString();
      await known({
        api: json({
          'data': {
            'rus_name': 'Человек-бензопила',
            'eng_name': 'Chainsaw Man',
            'cover': {'default': 'https://cover.imglib.info/c.jpg'},
            'summary': 'Денджи охотится на демонов.',
            'releaseDate': '2018',
            'authors': [{'name': 'Tatsuki Fujimoto'}],
            'genres': [{'name': 'Боевик'}],
          },
        }),
        'https://cover.imglib.info/c.jpg': png,
      }).fetchFor('a');
      final saved = await item();
      expect(saved.title, 'Человек-бензопила');
      expect(saved.previewText, 'Денджи охотится на демонов.');
      expect(saved.previewSite, 'MangaLib');
      expect(saved.previewAuthor, 'Tatsuki Fujimoto');
      expect(saved.coverPath, isNotNull);
      expect(headersSent[api], {'Site-Id': '1'});
      // сервер обложек без адреса страницы отвечает 403, как на чужую вставку картинки
      expect(headersSent['https://cover.imglib.info/c.jpg'], {'Referer': 'https://mangalib.me/'});
      // саму страницу-оболочку не скачивали: в ней только общее описание сайта
      expect(requests.map((uri) => uri.toString()), isNot(contains(url)));
      expect(structuredPage((await readPage(home, 'a'))!)!.type, PageType.comic);
    });

    test('YaoiLib, закрытый тайтл: название из адреса, вид — манга', () async {
      const url = 'https://v2.shlib.life/ru/manga/23435--secret-alliance';
      await addLink(url);
      final api = libRequest(Uri.parse(url))!.api.toString();
      await known({api: FetchReply(404, utf8.encode('{"data":{"toast":{"message":"Not Found"}}}'), 'application/json')}).fetchFor('a');
      final saved = await item();
      expect(saved.title, 'Secret alliance');
      expect(saved.previewSite, 'YaoiLib');
      expect(structuredPage((await readPage(home, 'a'))!)!.type, PageType.comic);
    });

    test('Lib без сети — попробовать позже, ничего не портить', () async {
      await addLink('https://animelib.org/ru/anime/21371--sousou-no-frieren-anime');
      expect(await known({}).fetchFor('a'), isFalse);
      expect((await item()).previewAt, isNull);
    });

    test('HDrezka за проверкой на бота: название и год из адреса, а не «Проверяем, что вы не бот!»', () async {
      const url = 'https://rezka.ag/films/fiction/1171-interstellar-2014.html';
      await addLink(url);
      await known({url: page('<html><head><title>Проверяем, что вы не бот!</title><link href="/.within.website/x/xess/xess.min.css"></head></html>')}).fetchFor('a');
      final saved = await item();
      expect(saved.title, 'Интерстеллар');
      expect(saved.previewSite, 'HDrezka');
      final parsed = structuredPage((await readPage(home, 'a'))!)!;
      expect(parsed.type, PageType.movie);
      expect(parsed.year, 2014);
    });

    test('любой сайт за проверкой на бота: заголовок не трогается, копия не сохраняется', () async {
      const url = 'https://shop.example.com/item/1';
      await addLink(url);
      await known({url: page('<html><head><title>Just a moment...</title></head><body>cf-browser-verification</body></html>')}).fetchFor('a');
      final saved = await item();
      expect(saved.title, url);
      expect(await readPage(home, 'a'), isNull);
      expect(saved.previewAt, now, reason: 'второй раз без толку: проверка никуда не денется');
    });
  });

  test('ссылка получает заголовок страницы, описание, сайт и обложку', () async {
    await addLink('https://habr.com/ru/articles/845872/');
    await service({
      'https://habr.com/ru/articles/845872/': page('<meta property="og:title" content="Сборщик мусора"><meta property="og:description" content="Поколения"><meta property="og:image" content="https://habr.com/i.png"><meta property="og:site_name" content="Хабр">'),
      'https://habr.com/i.png': png,
    }).fetchFor('a');
    final saved = await item();
    expect(saved.title, 'Сборщик мусора');
    expect(saved.previewText, 'Поколения');
    expect(saved.previewSite, 'Хабр');
    expect(saved.previewAt, now);
    expect(File('${home.path}/${saved.coverPath}').existsSync(), isTrue);
  });

  test('заголовок, который человек поменял, остаётся', () async {
    await addLink('https://habr.com/x', title: 'Почитать про GC');
    await service({'https://habr.com/x': page('<title>Чужой</title>')}).fetchFor('a');
    expect((await item()).title, 'Почитать про GC');
  });

  test('ролик YouTube: oEmbed даёт заголовок и автора, обложка крупная, если есть', () async {
    await addLink('https://youtu.be/dQw4w9WgXcQ', kind: ItemKind.video);
    final oembed = Uri.https('www.youtube.com', '/oembed', {'url': 'https://youtu.be/dQw4w9WgXcQ', 'format': 'json'}).toString();
    await service({
      oembed: FetchReply(200, utf8.encode(jsonEncode({'title': 'Never Gonna', 'author_name': 'Rick Astley', 'provider_name': 'YouTube', 'thumbnail_url': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg'})), 'application/json'),
      'https://youtu.be/dQw4w9WgXcQ': page('<meta itemprop="duration" content="PT3M33S">'),
      'https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg': png,
    }).fetchFor('a');
    final saved = await item();
    expect(saved.title, 'Never Gonna');
    expect(saved.previewAuthor, 'Rick Astley');
    expect(saved.durationSeconds, 213);
    expect(saved.coverPath, isNotNull);
    expect(requests.map((uri) => uri.toString()), isNot(contains('https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg')));
  });

  test('нет сети: превью не отмечено, попробуем потом', () async {
    await addLink('https://habr.com/x');
    final done = await service({}).fetchFor('a');
    expect(done, isFalse);
    expect((await item()).previewAt, isNull);
  });

  test('страницы нет (404): больше не спрашиваем, адрес остаётся заголовком', () async {
    await addLink('https://habr.com/gone');
    await service({'https://habr.com/gone': const FetchReply(404, [], 'text/html')}).fetchFor('a');
    final saved = await item();
    expect(saved.previewAt, now);
    expect(saved.title, 'https://habr.com/gone');
  });

  test('обложка не скачалась — превью всё равно записано без неё', () async {
    await addLink('https://habr.com/x');
    await service({'https://habr.com/x': page('<meta property="og:title" content="T"><meta property="og:image" content="https://habr.com/none.png">')}).fetchFor('a');
    final saved = await item();
    expect(saved.title, 'T');
    expect(saved.coverPath, isNull);
  });
}
