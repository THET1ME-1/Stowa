import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/structured_page.dart';

String page(String json, {String head = '', String body = ''}) => '<html><head>$head<script type="application/ld+json">$json</script></head><body>$body</body></html>';

void main() {
  test('длительность ISO 8601', () {
    expect(isoDuration('PT45M'), const Duration(minutes: 45));
    expect(isoDuration('PT1H30M'), const Duration(hours: 1, minutes: 30));
    expect(isoDuration('P1DT2H'), const Duration(days: 1, hours: 2));
    expect(isoDuration('PT90S'), const Duration(seconds: 90));
    expect(isoDuration('сорок минут'), isNull);
  });

  test('рецепт из @graph, как его пишет Yoast: ингредиенты, время, порции, шаги', () {
    final parsed = structuredPage(
      page('''{"@context":"https://schema.org","@graph":[
        {"@type":"WebPage","name":"Блог"},
        {"@type":"Recipe","name":"Паста карбонара","recipeIngredient":["200 г спагетти","100 г гуанчиале","2 желтка","50 г пекорино"],
         "prepTime":"PT10M","cookTime":"PT15M","recipeYield":["2","2 порции"],
         "recipeInstructions":[{"@type":"HowToStep","text":"Отварить пасту"},{"@type":"HowToStep","text":"Смешать с соусом"}],
         "author":{"@type":"Person","name":"Анна"},"aggregateRating":{"@type":"AggregateRating","ratingValue":"4.8"}}]}'''),
    )!;
    expect(parsed.type, PageType.recipe);
    expect(parsed.name, 'Паста карбонара');
    expect(parsed.ingredients, hasLength(4));
    expect(parsed.time, const Duration(minutes: 25));
    expect(parsed.servings, 2);
    expect(parsed.steps, 2);
    expect(parsed.authors, ['Анна']);
    expect(parsed.rating, 4.8);
  });

  test('товар: цена из предложения или диапазона, валюта, наличие, магазин', () {
    final single = structuredPage(
      page('{"@type":"Product","name":"Диван Oslo","brand":{"@type":"Brand","name":"Mobila"},"offers":{"@type":"Offer","price":"4500.00","priceCurrency":"MDL","availability":"https://schema.org/InStock","seller":{"name":"Mobila.md"}}}'),
    )!;
    expect(single.type, PageType.product);
    expect(single.price, 4500);
    expect(single.currency, 'MDL');
    expect(single.inStock, isTrue);
    expect(single.shop, 'Mobila.md');
    expect(single.brand, 'Mobila');

    final range = structuredPage(page('{"@type":"Product","name":"Кресло","offers":{"@type":"AggregateOffer","lowPrice":1200,"highPrice":1900,"priceCurrency":"EUR","availability":"OutOfStock"}}'))!;
    expect(range.price, 1200);
    expect(range.inStock, isFalse);
  });

  test('событие: начало, конец, место с адресом и координатами', () {
    final parsed = structuredPage(
      page('''[{"@type":"MusicEvent","name":"Концерт Zdob și Zdub","startDate":"2026-11-20T19:00:00+02:00","endDate":"2026-11-20T22:00:00+02:00",
        "location":{"@type":"Place","name":"Palatul Național","address":{"@type":"PostalAddress","streetAddress":"bd. Ștefan cel Mare 81","addressLocality":"Chișinău"},
        "geo":{"@type":"GeoCoordinates","latitude":47.0245,"longitude":"28.8323"}}}]'''),
    )!;
    expect(parsed.type, PageType.event);
    expect(parsed.start, DateTime.utc(2026, 11, 20, 17).toLocal());
    expect(parsed.end, DateTime.utc(2026, 11, 20, 20).toLocal());
    expect(parsed.venue, 'Palatul Național');
    expect(parsed.address, 'bd. Ștefan cel Mare 81, Chișinău');
    expect(parsed.latitude, closeTo(47.0245, 0.0001));
    expect(parsed.longitude, closeTo(28.8323, 0.0001));
  });

  test('одинаковые город и регион в адресе — один раз', () {
    final parsed = structuredPage(page('{"@type":"Event","name":"Бег","startDate":"2026-11-07","location":{"@type":"Place","name":"Teatrul Verde","address":{"addressLocality":"Chisinau","addressRegion":"Chisinau","streetAddress":"Teatrul Verde"}}}'))!;
    expect(parsed.address, 'Teatrul Verde, Chisinau');
    // Meetup: город уже в улице и ещё раз отдельно
    final meetup = structuredPage(page('{"@type":"Event","name":"Бег","startDate":"2026-11-07","location":{"@type":"Place","name":"Teatrul Verde","address":{"addressLocality":"Chisinau","addressRegion":"","streetAddress":"Teatrul Verde, Chisinau"}}}'))!;
    expect(meetup.address, 'Teatrul Verde, Chisinau');
  });

  test('заведение: адрес, телефон, часы работы', () {
    final parsed = structuredPage(
      page('''{"@type":["Restaurant","LocalBusiness"],"name":"Gastrobar","telephone":"+373 22 123 456","address":"str. București 67, Chișinău",
        "openingHoursSpecification":[{"dayOfWeek":["Monday","Tuesday"],"opens":"10:00","closes":"23:00"}],"geo":{"latitude":47.02,"longitude":28.83}}'''),
    )!;
    expect(parsed.type, PageType.place);
    expect(parsed.phone, '+373 22 123 456');
    expect(parsed.address, 'str. București 67, Chișinău');
    expect(parsed.hours, ['Mo–Tu 10:00–23:00']);
  });

  test('статья: авторы, дата, время чтения по тексту', () {
    final words = List.filled(1400, 'слово').join(' ');
    final parsed = structuredPage(
      page('{"@type":"NewsArticle","headline":"Как устроен поиск","author":[{"@type":"Person","name":"Иван"},{"name":"Мария"}],"datePublished":"2026-10-01"}', body: '<article><p>$words</p></article>'),
    )!;
    expect(parsed.type, PageType.article);
    expect(parsed.authors, ['Иван', 'Мария']);
    expect(parsed.published, DateTime(2026, 10, 1));
    expect(parsed.readingMinutes, 7);
  });

  test('фильм и книга: год, режиссёр или автор, рейтинг', () {
    final movie = structuredPage(page('{"@type":"Movie","name":"Паразиты","datePublished":"2019-05-30","director":{"@type":"Person","name":"Пон Джун-хо"},"aggregateRating":{"ratingValue":8.5}}'))!;
    expect(movie.type, PageType.movie);
    expect(movie.year, 2019);
    expect(movie.authors, ['Пон Джун-хо']);
    final book = structuredPage(page('{"@type":"Book","name":"Мастер и Маргарита","author":"Михаил Булгаков","datePublished":"1967"}'))!;
    expect(book.type, PageType.book);
    expect(book.year, 1967);
  });

  test('видео: длина и главы', () {
    final parsed = structuredPage(
      page('{"@type":"VideoObject","name":"Ремонт","duration":"PT12M30S","hasPart":[{"@type":"Clip","name":"Вступление","startOffset":0},{"@type":"Clip","name":"Плитка","startOffset":95}]}'),
    )!;
    expect(parsed.type, PageType.video);
    expect(parsed.duration, const Duration(minutes: 12, seconds: 30));
    expect(parsed.chapters.map((chapter) => (chapter.seconds, chapter.title)), [(0, 'Вступление'), (95, 'Плитка')]);
  });

  test('страница-список событий — не событие: напоминание на первое из списка было бы враньём', () {
    final listing = structuredPage(
      page('{"@type":"ItemList","itemListElement":[{"@type":"ListItem","position":1,"item":{"@type":"Event","name":"Первое","startDate":"2026-11-20"}},{"@type":"ListItem","position":2,"item":{"@type":"Event","name":"Второе","startDate":"2026-11-21"}}]}'),
    );
    expect(listing?.type, isNot(PageType.event));
    final array = structuredPage(page('[{"@type":"Event","name":"Бег","startDate":"2026-11-07"},{"@type":"Event","name":"Лекция","startDate":"2026-11-08"}]'));
    expect(array?.type, isNot(PageType.event));
    // один и тот же рецепт в двух блоках разметки — по-прежнему рецепт
    expect(structuredPage('${page('{"@type":"Recipe","name":"Борщ"}')}${page('{"@type":"Recipe","name":"Борщ"}')}')!.type, PageType.recipe);
  });

  test('год фильма — выход, а не дата записи на сайте', () {
    final movie = structuredPage(page('{"@type":"Movie","name":"Parasite","dateCreated":"2018-01-04T04:51:09Z","releasedEvent":{"@type":"PublicationEvent","startDate":"2019-05-30"}}'))!;
    expect(movie.year, 2019);
    // TMDB кладёт выход массивом
    final listed = structuredPage(page('{"@type":"Movie","name":"Parasite","dateCreated":"2018-01-04","releasedEvent":[{"@type":"PublicationEvent","startDate":"2019-05-30"}]}'))!;
    expect(listed.year, 2019);
  });

  test('разметка в CDATA с пробелами', () {
    expect(structuredPage(page('/* <![CDATA[ */ {"@type":"Movie","name":"Паразиты","datePublished":"2019-05-30"} /* ]]> */'))!.year, 2019);
  });

  test('рецепт главнее статьи и страницы', () {
    final parsed = structuredPage('${page('{"@type":"Article","headline":"Блог"}')}${page('{"@type":"Recipe","name":"Борщ","recipeIngredient":["свёкла"]}')}')!;
    expect(parsed.type, PageType.recipe);
  });

  test('без разметки: цена из метатегов товара, статья по og:type и длине текста', () {
    final product = structuredPage('<html><head><meta property="product:price:amount" content="99.90"><meta property="product:price:currency" content="EUR"></head></html>')!;
    expect(product.type, PageType.product);
    expect(product.price, 99.9);
    final words = List.filled(600, 'word').join(' ');
    final article = structuredPage('<html><head><meta property="og:type" content="article"><meta name="author" content="Ion"></head><body><p>$words</p></body></html>')!;
    expect(article.type, PageType.article);
    expect(article.readingMinutes, 3);
    expect(article.authors, ['Ion']);
  });

  test('битая разметка и сырые переводы строк внутри строк не роняют разбор', () {
    expect(structuredPage(page('{"@type":"Recipe", "name":"Плов", "description":"строка\nс переводом", }')), isNotNull);
    expect(structuredPage(page('{не json')), isNull);
    expect(structuredPage('<html><body>просто страница</body></html>'), isNull);
  });
}
