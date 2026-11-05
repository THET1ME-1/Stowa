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
      PageExtractor(fetch: fetch),
      SubtitlesExtractor(fetch: fetch, post: post, languages: () => ['ru', 'en']),
    ],
  );

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

  test('старая ссылка без копии: страница скачивается один раз и сохраняется', () async {
    await link('p', 'https://shop.md/divan');
    pages['https://shop.md/divan'] = html('<script type="application/ld+json">{"@type":"Product","name":"Диван","offers":{"price":"4500","priceCurrency":"MDL","availability":"InStock"}}</script>');
    await pipeline().sweepNetwork();
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
