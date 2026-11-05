import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/site_sources.dart';
import 'package:stowa/domain/structured_page.dart';

void main() {
  group('сайты Lib', () {
    test('все пять сайтов и их зеркала: номер сайта, вид тайтла, адрес API', () {
      for (final (url, site, model, slug) in [
        ('https://mangalib.me/ru/manga/7965--chainsaw-man', 1, 'manga', '7965--chainsaw-man'),
        ('https://mangalib.org/ru/manga/7965--chainsaw-man?section=info', 1, 'manga', '7965--chainsaw-man'),
        ('https://mangalib.me/chainsaw-man', 1, 'manga', 'chainsaw-man'),
        ('https://slashlib.me/ru/manga/24394--wolf-and-dog', 2, 'manga', '24394--wolf-and-dog'),
        ('https://v2.shlib.life/ru/manga/24394--wolf-and-dog', 2, 'manga', '24394--wolf-and-dog'),
        ('https://ranobelib.me/ru/book/20818--lord-of-the-mysteries', 3, 'manga', '20818--lord-of-the-mysteries'),
        ('https://hentailib.me/ru/manga/566--toukyou-kushu/read/v1/c1', 4, 'manga', '566--toukyou-kushu'),
        ('https://animelib.org/ru/anime/21371--sousou-no-frieren-anime/watch', 5, 'anime', '21371--sousou-no-frieren-anime'),
        ('https://anilib.me/ru/anime/21371--sousou-no-frieren-anime', 5, 'anime', '21371--sousou-no-frieren-anime'),
      ]) {
        final request = libRequest(Uri.parse(url))!;
        expect(request.site.id, site, reason: url);
        expect(request.api.host, 'api.lib.social', reason: url);
        expect(request.api.path, '/api/$model/$slug', reason: url);
        expect(request.headers['Site-Id'], '$site', reason: url);
        expect(request.api.queryParametersAll['fields[]'], containsAll(['summary', 'genres', 'authors', 'releaseDate']), reason: url);
      }
      expect(libRequest(Uri.parse('https://mangalib.org/')), isNull);
      expect(libRequest(Uri.parse('https://mangalib.org/ru/catalog')), isNull);
      expect(libRequest(Uri.parse('https://example.com/ru/manga/x')), isNull);
    });

    test('имя сайта для подписи', () {
      expect(libRequest(Uri.parse('https://v2.shlib.life/ru/manga/1--a'))!.site.name, 'YaoiLib');
      expect(libRequest(Uri.parse('https://ranobelib.me/ru/book/1--a'))!.site.name, 'RanobeLib');
    });

    final manga = {
      'data': {
        'name': 'Chainsaw Man',
        'rus_name': 'Человек-бензопила',
        'eng_name': 'Chainsaw Man',
        'model': 'manga',
        'cover': {'default': 'https://cover.imglib.info/c.jpg', 'thumbnail': 'https://cover.imglib.info/c_thumb.jpg'},
        'type': {'label': 'Манга'},
        'status': {'label': 'Завершён'},
        'ageRestriction': {'label': '18+'},
        'summary': {
          'type': 'doc',
          'content': [
            {'type': 'paragraph', 'content': [{'type': 'text', 'text': '«Я всегда мечтал жить обычной жизнью».'}]},
            {'type': 'paragraph', 'content': [{'type': 'text', 'text': 'Денджи '}, {'type': 'text', 'text': 'охотится на демонов.'}]},
          ],
        },
        'releaseDate': '2018',
        'rating': {'average': '9.42'},
        'authors': [{'name': 'Tatsuki Fujimoto', 'rus_name': null}],
        'genres': [{'name': 'Боевик'}, {'name': 'Комедия'}],
        'tags': [{'name': 'Монстры'}, {'name': 'Зомби'}],
      },
    };
    LibSite site(int id) => libRequest(Uri.parse(switch (id) {
      1 => 'https://mangalib.me/ru/manga/1--a',
      3 => 'https://ranobelib.me/ru/book/1--a',
      _ => 'https://animelib.org/ru/anime/1--a',
    }))!.site;

    test('тайтл из ответа: русское имя, описание абзацами, обложка, год, рейтинг, жанры', () {
      final title = parseLibTitle(manga, site(1))!;
      expect(title.name, 'Человек-бензопила');
      expect(title.alternative, 'Chainsaw Man');
      expect(title.summary, '«Я всегда мечтал жить обычной жизнью».\nДенджи охотится на демонов.');
      expect(title.cover.toString(), 'https://cover.imglib.info/c.jpg');
      expect(title.year, 2018);
      expect(title.rating, 9.42);
      expect(title.authors, ['Tatsuki Fujimoto']);
      expect(title.genres, ['Боевик', 'Комедия', 'Монстры', 'Зомби']);
    });

    test('страница из ответа: манга — манга, ранобэ — книга, аниме-сериал — сериал, аниме-фильм — фильм', () {
      final comic = structuredPage(libPage(parseLibTitle(manga, site(1))!))!;
      expect(comic.type, PageType.comic);
      expect(comic.name, 'Человек-бензопила');
      expect(comic.year, 2018);
      expect(comic.authors, ['Tatsuki Fujimoto']);
      expect(comic.rating, 9.42);
      expect(comic.genres, containsAll(['Боевик', 'Монстры']));
      expect(structuredPage(libPage(parseLibTitle({'data': {'rus_name': 'Повелитель тайн', 'releaseDate': '2018'}}, site(3))!))!.type, PageType.book);
      final series = parseLibTitle({'data': {'rus_name': 'Фрирен', 'type': {'label': 'TV Сериал'}, 'releaseDate': '2023-09-29'}}, site(5))!;
      expect(structuredPage(libPage(series))!.type, PageType.series);
      expect(structuredPage(libPage(series))!.year, 2023);
      final movie = parseLibTitle({'data': {'rus_name': 'Унесённые призраками', 'type': {'label': 'Фильм'}}}, site(5))!;
      expect(structuredPage(libPage(movie))!.type, PageType.movie);
    });

    test('закрытый тайтл (16+ без входа): название из адреса', () {
      final request = libRequest(Uri.parse('https://v2.shlib.life/ru/manga/23435--secret-alliance'))!;
      final title = libTitleFromSlug(request);
      expect(title.name, 'Secret alliance');
      expect(structuredPage(libPage(title))!.type, PageType.comic);
    });

    test('18+ по пометке тайтла, HentaiLib — целиком; 6+ и 16+ — нет', () {
      expect(adultPage(libPage(parseLibTitle(manga, site(1))!)), isTrue, reason: 'у тайтла пометка 18+');
      final calm = parseLibTitle({'data': {'rus_name': 'Волк и пёс', 'ageRestriction': {'label': '6+'}}}, site(1))!;
      expect(adultPage(libPage(calm)), isFalse);
      final hentai = libRequest(Uri.parse('https://hentailib.me/ru/manga/566--toukyou-kushu'))!;
      expect(adultPage(libPage(parseLibTitle({'data': {'rus_name': 'Тайтл', 'ageRestriction': {'label': '16+'}}}, hentai.site)!)), isTrue);
      expect(adultPage(libPage(libTitleFromSlug(hentai))), isTrue);
    });

    test('пустой или чужой ответ — null', () {
      expect(parseLibTitle({'data': {'toast': {'message': 'Not Found'}}}, site(1)), isNull);
      expect(parseLibTitle({'x': 1}, site(1)), isNull);
    });
  });

  group('HDrezka', () {
    test('название и год из адреса: сайт пишет их туда транслитом', () {
      final film = rezkaFromUrl(Uri.parse('https://rezka.ag/films/fiction/1171-interstellar-2014.html'))!;
      expect(film.title, 'Интерстеллар');
      expect(film.year, 2014);
      expect(film.series, isFalse);
      final series = rezkaFromUrl(Uri.parse('https://hdrezka.ag/series/thriller/646-vo-vse-tyazhkie-2008.html'))!;
      expect(series.title, 'Во все тяжкие');
      expect(series.year, 2008);
      expect(series.series, isTrue);
      expect(rezkaFromUrl(Uri.parse('https://hdrezka-home.tv/animation/adventures/49020-provozhayuschaya-v-posledniy-put-friren-2023.html'))!.series, isTrue);
      expect(rezkaFromUrl(Uri.parse('https://rezka.ag/')), isNull);
      expect(rezkaFromUrl(Uri.parse('https://example.com/films/x/1-a-2014.html')), isNull);
    });

    test('страница из адреса разбирается как фильм с годом', () {
      final page = structuredPage(rezkaPage(rezkaFromUrl(Uri.parse('https://rezka.ag/films/fiction/1171-interstellar-2014.html'))!))!;
      expect(page.type, PageType.movie);
      expect(page.year, 2014);
    });
  });

  test('страница проверки на бота — не содержимое', () {
    expect(isBotCheck('<html><head><title>Проверяем, что вы не бот!</title><link href="/.within.website/x/xess/xess.min.css"></head></html>'), isTrue);
    expect(isBotCheck('<html><head><title>Just a moment...</title></head><body>cf-browser-verification</body></html>'), isTrue);
    expect(isBotCheck('<title>DDoS-Guard</title>'), isTrue);
    expect(isBotCheck('<html><head><title>Рецепт карбонары</title></head><body>…</body></html>'), isFalse);
  });

  test('известные сайты 18+ узнаются по адресу, с поддоменом и зеркалом языка', () {
    expect(adultSite(Uri.parse('https://www.pornhub.com/view_video.php?viewkey=1')), isTrue);
    expect(adultSite(Uri.parse('https://rt.pornhub.com/')), isTrue);
    expect(adultSite(Uri.parse('https://onlyfans.com/someone')), isTrue);
    expect(adultSite(Uri.parse('https://nhentai.net/g/1/')), isTrue);
    expect(adultSite(Uri.parse('https://hentailib.me/ru/manga/x')), isTrue, reason: 'весь HentaiLib — 18+');
    expect(adultSite(Uri.parse('https://mangalib.me/ru/manga/x')), isFalse);
    expect(adultSite(Uri.parse('https://notpornhub.com.md/')), isFalse, reason: 'чужой домен, только похожий');
    expect(adultSite(Uri.parse('https://youtube.com/watch?v=1')), isFalse);
  });
}
