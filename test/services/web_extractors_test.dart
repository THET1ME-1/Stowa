import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/facts/extractors.dart';
import 'package:stowa/services/facts/facts_pipeline.dart';
import 'package:stowa/services/facts/web_extractors.dart';
import 'package:stowa/services/link_preview_service.dart';
import 'package:stowa/services/page_cache.dart';

void main() {
  late AppDatabase db;
  late Directory home;
  var now = DateTime(2026, 11, 5, 12);
  late Map<String, FetchReply> pages;
  late List<String> asked;
  FetchReply? playerReply;

  setUp(() async {
    db = AppDatabase.memory();
    home = await Directory.systemTemp.createTemp('stowa_web');
    now = DateTime(2026, 11, 5, 12);
    pages = {};
    asked = [];
    playerReply = null;
  });

  tearDown(() async {
    await db.close();
    await home.delete(recursive: true);
  });

  Future<FetchReply> fetch(Uri uri) async {
    asked.add('$uri');
    return pages['$uri'] ?? const FetchReply(404, [], 'text/html');
  }

  Future<FetchReply> post(Uri uri, String body) async {
    asked.add('POST $uri');
    return playerReply ?? const FetchReply(500, [], null);
  }

  FactsPipeline pipeline() => FactsPipeline(
    db,
    filesRoot: home,
    clock: () => now,
    extractors: [
      LinkExtractor(),
      PageExtractor(),
      ArticleExtractor(),
      PageFetchExtractor(fetch: fetch),
      SubtitlesExtractor(fetch: fetch, post: post, languages: () => ['ru', 'en']),
    ],
  );

  // статья в 300 с лишним слов: шесть абзацев по ~50
  String articlePage() => '<html><head><meta property="og:title" content="Кофе без турки"></head><body><article>${[
        for (var index = 0; index < 6; index++)
          '<p>Абзац $index о том, как варить кофе дома без турки, если кофемашина дорогая, а вода из-под крана жёсткая, '
              'и почему помол важнее сорта, когда хочется крепкого утреннего кофе с пенкой, как в кофейне у дома, '
              'но без очереди и лишних денег за стакан, крышку и трубочку.</p>',
      ].join()}</article></body></html>';

  Future<void> link(String id, String url, {ItemKind kind = ItemKind.link, String? previewText}) => db
      .into(db.items)
      .insert(ItemsCompanion.insert(id: id, kind: kind, title: url, url: Value(url), previewText: Value(previewText), previewAt: Value(now), createdAt: now, updatedAt: now));

  Future<List<Fact>> factsOf(String id, [FactKind? kind]) async {
    final all = await (db.select(db.facts)..where((t) => t.itemId.equals(id))..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    return [for (final fact in all) if (kind == null || fact.kind == kind) fact];
  }
  Future<Item> item(String id) => (db.select(db.items)..where((t) => t.id.equals(id))).getSingle();

  FetchReply html(String body) => FetchReply(200, utf8.encode(body), 'text/html; charset=utf-8');

  test('рецепт из копии страницы: без второго похода в сеть, ищется по ингредиенту и слову «рецепт»', () async {
    await link('r', 'https://food.md/carbonara');
    await savePage(home, 'r', '<script type="application/ld+json">{"@type":"Recipe","name":"Карбонара","recipeIngredient":["200 г спагетти","гуанчиале"],"totalTime":"PT25M","recipeYield":"2"}</script>');
    await pipeline().runItem('r', network: true);
    expect(asked, isEmpty);
    expect((await factsOf('r', FactKind.pageType)).single.detail, 'recipe');
    expect((await factsOf('r', FactKind.ingredient)).map((fact) => fact.value), ['200 г спагетти', 'гуанчиале']);
    expect((await factsOf('r', FactKind.timeNeeded)).single.number, 25);
    final text = (await item('r')).factsText;
    expect(text, allOf(contains('гуанчиале'), contains('рецепт')));
  });

  test('статья из копии страницы: текст ищется, слова и минуты чтения — у факта', () async {
    await link('a', 'https://blog.example.com/kofe');
    await savePage(home, 'a', articlePage());
    await pipeline().runItem('a', network: true);
    final fact = (await factsOf('a', FactKind.articleText)).single;
    expect(fact.value, contains('помол важнее сорта'));
    expect(fact.number, greaterThan(250));
    expect(fact.detail, '${(fact.number! / 200).ceil()}');
    expect(await db.searchIds('кофемашина'), ['a']);
  });

  group('картинки статьи', () {
    late bool wifi;
    late List<String> referers;
    setUp(() {
      wifi = true;
      referers = [];
    });

    FactsPipeline withImages() => FactsPipeline(
      db,
      filesRoot: home,
      clock: () => now,
      extractors: [
        ArticleExtractor(),
        ArticleImagesExtractor(
          fetch: (uri, headers) async {
            referers.add(headers['Referer'] ?? '');
            return fetch(uri);
          },
          onWifi: () async => wifi,
        ),
      ],
    );

    String withPictures() => articlePage().replaceFirst('</article>', '<img src="/a.jpg" alt="Чашка"><img src="https://cdn.example.com/b.png"></article>');

    test('по Wi-Fi картинки ложатся по порядку; не скачалась — её место пустое', () async {
      await link('a', 'https://blog.example.com/kofe');
      await savePage(home, 'a', withPictures());
      pages['https://blog.example.com/a.jpg'] = const FetchReply(200, [1, 2, 3], 'image/jpeg');
      await withImages().runItem('a');
      await withImages().runItem('a', network: true);
      expect(File('${home.path}/.stowa/articles/a/0.img').readAsBytesSync(), [1, 2, 3]);
      expect(File('${home.path}/.stowa/articles/a/1.img').existsSync(), isFalse);
      expect(referers.first, 'https://blog.example.com/', reason: 'сервер картинок без адреса страницы часто отвечает 403');
    });

    test('без Wi-Fi не качает ничего и пробует потом', () async {
      wifi = false;
      await link('a', 'https://blog.example.com/kofe');
      await savePage(home, 'a', withPictures());
      await withImages().runItem('a');
      await withImages().runItem('a', network: true);
      expect(asked, isEmpty);
      final run = await (db.select(db.extractorRuns)..where((t) => t.extractor.equals('article_images'))).getSingle();
      expect(run.nextTry, isNotNull);
    });
  });

  test('ролик и товар статьёй не становятся', () async {
    await link('v', 'https://youtu.be/abc', kind: ItemKind.video);
    await savePage(home, 'v', articlePage());
    await link('p', 'https://shop.md/kofemolka');
    await savePage(home, 'p', '<html><body><h1>Кофемолка</h1><p>Цена 900 лей</p></body></html>');
    await pipeline().runItem('v');
    await pipeline().runItem('p');
    expect(await factsOf('v', FactKind.articleText), isEmpty);
    expect(await factsOf('p', FactKind.articleText), isEmpty);
  });

  test('старой ссылке скачали копию — и статья разбирается заново, без перезапуска', () async {
    await link('a', 'https://blog.example.com/kofe');
    await pipeline().runItem('a');
    expect(await factsOf('a', FactKind.articleText), isEmpty);
    pages['https://blog.example.com/kofe'] = html(articlePage());
    await pipeline().runItem('a', network: true);
    await pipeline().runItem('a');
    expect(await factsOf('a', FactKind.articleText), hasLength(1));
  });

  test('старая ссылка без копии: страница скачивается один раз, сохраняется и тут же разбирается', () async {
    await link('p', 'https://shop.md/divan');
    pages['https://shop.md/divan'] = html('<script type="application/ld+json">{"@type":"Product","name":"Диван","offers":{"price":"4500","priceCurrency":"MDL","availability":"InStock"}}</script>');
    final facts = pipeline();
    // местный проход без копии ничего не узнал
    await facts.sweep();
    expect(await factsOf('p', FactKind.price), isEmpty);
    await facts.sweepNetwork();
    await facts.sweep();
    await facts.sweepNetwork();
    expect(asked, ['https://shop.md/divan']);
    expect(pageFile(home, 'p').existsSync(), isTrue);
    final price = (await factsOf('p', FactKind.price)).single;
    expect(price.number, 4500);
    expect(price.detail, 'MDL');
    expect(price.value, '4 500 MDL');
    expect((await factsOf('p', FactKind.inStock)).single.number, 1);
  });

  test('событие ставит напоминание за час, а снятое человеком не возвращается', () async {
    await link('e', 'https://afisha.md/concert');
    await savePage(home, 'e', '<script type="application/ld+json">{"@type":"MusicEvent","name":"Концерт","startDate":"2026-11-20T19:00:00","location":{"@type":"Place","name":"Palatul Național","geo":{"latitude":47.02,"longitude":28.83}}}</script>');
    final facts = pipeline();
    await facts.runItem('e', network: true);
    expect((await item('e')).reminderAt, DateTime(2026, 11, 20, 18));
    expect((await factsOf('e', FactKind.venue)).single.value, 'Palatul Național');
    expect((await factsOf('e', FactKind.venuePlace)).single.number, closeTo(47.02, 0.001));

    // человек снял напоминание, превью обновилось — правило разбирает заново, но не перебивает его
    await (db.update(db.items)..where((t) => t.id.equals('e'))).write(ItemsCompanion(reminderAt: const Value(null), previewAt: Value(now.add(const Duration(minutes: 1)))));
    await facts.runItem('e', network: true);
    expect((await item('e')).reminderAt, isNull);
  });

  test('новая версия разбора перечитывает старые страницы без сети', () async {
    await link('e', 'https://afisha.md/run');
    await savePage(home, 'e', '<script type="application/ld+json">{"@type":"Event","name":"Бег","startDate":"2026-11-07","location":{"@type":"Place","name":"Teatrul Verde","address":{"addressLocality":"Chisinau","streetAddress":"Teatrul Verde, Chisinau"}}}</script>');
    // прогон прошлой версии, сделанный когда-то давно
    await db.into(db.extractorRuns).insert(ExtractorRunsCompanion.insert(itemId: 'e', extractor: 'page', version: 1, itemStamp: Value('${now.toIso8601String()}|https://afisha.md/run')));
    await FactsPipeline(db, filesRoot: home, clock: () => now, extractors: [PageExtractor()], online: () async => false).sweep();
    expect((await factsOf('e', FactKind.address)).single.value, 'Teatrul Verde, Chisinau');
    expect(asked, isEmpty);
  });

  test('18+ — по пометке самой страницы или по известному сайту, даже без копии', () async {
    await link('m', 'https://comics.example/title');
    await savePage(home, 'm', '<html><head><meta name="rating" content="RTA-5042-1996-1400-1577-RTA"><title>Тайтл</title></head></html>');
    await link('c', 'https://food.md/soup');
    await savePage(home, 'c', '<html><head><meta name="rating" content="general"><title>Суп</title></head></html>');
    // страница закрыта проверкой возраста, копии нет
    await link('s', 'https://www.xvideos.com/video1/x');
    await pipeline().sweep();
    expect((await factsOf('m', FactKind.adult)).single.value, '18+');
    expect(await factsOf('c', FactKind.adult), isEmpty);
    expect((await factsOf('s', FactKind.adult)).single.value, '18+');
    expect(asked, isEmpty);
  });

  group('папка 18+', () {
    Future<void> folder(String id, String name, {DateTime? deletedAt}) =>
        db.into(db.folders).insert(FoldersCompanion.insert(id: id, name: name, icon: 'folder', shape: 'pill', deletedAt: Value(deletedAt)));
    Future<void> place(String id, String folderId, SortedBy by) =>
        (db.update(db.items)..where((t) => t.id.equals(id))).write(ItemsCompanion(folderId: Value(folderId), sortedBy: Value(by)));
    Future<List<Folder>> adultFolders() => (db.select(db.folders)..where((t) => t.name.equals('18+'))).get();

    test('вещи 18+ уезжают в папку «18+», папка создаётся одна', () async {
      await link('a', 'https://www.xvideos.com/video1/x');
      await link('b', 'https://rt.pornhub.com/view_video.php?viewkey=1');
      await link('c', 'https://food.md/soup');
      await pipeline().sweep();
      final folders = await adultFolders();
      expect(folders, hasLength(1));
      expect(folders.single.icon, 'explicit');
      expect((await item('a')).folderId, folders.single.id);
      expect((await item('b')).folderId, folders.single.id);
      expect((await item('b')).sortedBy, SortedBy.rule);
      expect((await item('c')).folderId, isNull);
    });

    test('угадыватель и ИИ уступают, а разложенное руками и своим правилом остаётся', () async {
      await folder('recipes', 'Рецепты');
      for (final (id, by) in [('similar', SortedBy.similar), ('ai', SortedBy.ai), ('user', SortedBy.user), ('rule', SortedBy.rule)]) {
        await link(id, 'https://www.xvideos.com/$id');
        await place(id, 'recipes', by);
      }
      await pipeline().sweep();
      final adult = (await adultFolders()).single.id;
      expect((await item('similar')).folderId, adult);
      expect((await item('ai')).folderId, adult);
      expect((await item('user')).folderId, 'recipes');
      expect((await item('rule')).folderId, 'recipes');
    });

    test('уже есть своя папка «18+» — вещи туда, вторая не заводится; удалил папку — заново не появляется', () async {
      await folder('mine', '18+');
      await link('a', 'https://www.xvideos.com/a');
      await pipeline().sweep();
      expect((await item('a')).folderId, 'mine');
      expect(await adultFolders(), hasLength(1));

      await (db.update(db.folders)..where((t) => t.id.equals('mine'))).write(FoldersCompanion(deletedAt: Value(now)));
      await link('b', 'https://www.xvideos.com/b');
      await pipeline().sweep();
      expect((await item('b')).folderId, isNull);
      expect(await adultFolders(), hasLength(1));
    });
  });

  test('прошедшее событие напоминания не ставит', () async {
    await link('e', 'https://afisha.md/old');
    await savePage(home, 'e', '<script type="application/ld+json">{"@type":"Event","name":"Было","startDate":"2026-10-01T19:00:00"}</script>');
    await pipeline().runItem('e', network: true);
    expect((await item('e')).reminderAt, isNull);
  });

  test('YouTube: субтитры со временем на нужном языке, главы, хэштеги, длина', () async {
    await link('y', 'https://youtu.be/dQw4w9WgXcQ', kind: ItemKind.video);
    await savePage(home, 'y', '<html></html>');
    playerReply = FetchReply(
      200,
      utf8.encode(
        jsonEncode({
          'playabilityStatus': {'status': 'OK'},
          'videoDetails': {'lengthSeconds': '213', 'author': 'Rick Astley', 'shortDescription': '0:00 Начало\n1:00 Припев\n#nggyu'},
          'captions': {
            'playerCaptionsTracklistRenderer': {
              'captionTracks': [
                {'baseUrl': 'https://www.youtube.com/api/timedtext?lang=en', 'languageCode': 'en'},
                {'baseUrl': 'https://www.youtube.com/api/timedtext?lang=ru', 'languageCode': 'ru'},
              ],
            },
          },
        }),
      ),
      'application/json',
    );
    pages['https://www.youtube.com/api/timedtext?lang=ru'] = FetchReply(200, utf8.encode('<timedtext><body><p t="1360" d="1000">Мы не чужие</p><p t="42000" d="1000">Никогда не брошу</p></body></timedtext>'), 'text/xml');
    await pipeline().runItem('y', network: true);
    final phrases = await factsOf('y', FactKind.subtitle);
    expect(phrases.map((fact) => (fact.number, fact.value)), [(1.36, 'Мы не чужие'), (42.0, 'Никогда не брошу')]);
    expect(phrases.first.detail, 'ru');
    expect((await factsOf('y', FactKind.chapter)).map((fact) => fact.value), ['Начало', 'Припев']);
    expect((await factsOf('y', FactKind.hashtag)).single.value, 'nggyu');
    expect((await item('y')).durationSeconds, 213);
    expect((await item('y')).factsText, contains('Никогда не брошу'));
  });

  test('YouTube не ответил — повтор позже, а не сейчас', () async {
    await link('y', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', kind: ItemKind.video);
    await savePage(home, 'y', '<html></html>');
    final facts = pipeline();
    await facts.runItem('y', network: true);
    await facts.sweepNetwork();
    expect(asked.where((one) => one.startsWith('POST')), hasLength(1));
    final run = await (db.select(db.extractorRuns)..where((t) => t.extractor.equals('subtitles'))).getSingle();
    expect(run.error, contains('500'));
    expect(run.nextTry, isNotNull);
  });

  test('TikTok: подпись, хэштеги, автор и субтитры WebVTT из копии страницы', () async {
    await link('t', 'https://www.tiktok.com/@chef/video/1', kind: ItemKind.video);
    final data = {
      '__DEFAULT_SCOPE__': {
        'webapp.video-detail': {
          'itemInfo': {
            'itemStruct': {
              'desc': 'Паста за 5 минут #рецепт',
              'author': {'nickname': 'Шеф'},
              'challenges': [{'title': 'рецепт'}],
              'video': {
                'duration': 47,
                'subtitleInfos': [{'LanguageCodeName': 'rus-RU', 'Url': 'https://tt/ru.vtt', 'Format': 'webvtt', 'Source': 'ASR'}],
              },
            },
          },
        },
      },
    };
    await savePage(home, 't', '<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">${jsonEncode(data)}</script>');
    pages['https://tt/ru.vtt'] = FetchReply(200, utf8.encode('WEBVTT\n\n00:00:02.000 --> 00:00:04.000\nКидаем пасту в воду\n'), 'text/vtt');
    await pipeline().runItem('t', network: true);
    expect((await factsOf('t', FactKind.subtitle)).single.number, 2);
    expect((await factsOf('t', FactKind.hashtag)).map((fact) => fact.value), ['рецепт']);
    expect((await factsOf('t', FactKind.author)).single.value, 'Шеф');
    expect((await item('t')).durationSeconds, 47);
  });

  test('хэштеги из описания Instagram — предложенные теги', () async {
    await link('i', 'https://www.instagram.com/p/x/', previewText: 'Утро в горах #travel #горы');
    await FactsPipeline(db, filesRoot: home, clock: () => now, extractors: [LinkExtractor()]).runItem('i');
    expect((await factsOf('i', FactKind.hashtag)).map((fact) => fact.value), ['travel', 'горы']);
  });
}
