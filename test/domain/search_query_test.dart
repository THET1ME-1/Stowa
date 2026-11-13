import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/image_colors.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/search_query.dart';

void main() {
  // среда, 4 ноября 2026, полдень
  final now = DateTime(2026, 11, 4, 12);

  List<String> free(SearchQuery query) => [for (final word in query.words) word.word];

  test('служебные слова 58 языков не ищутся, а обычные слова своих языков — ищутся', () {
    expect(free(parseSearch('recette de la tarte avec les pommes', now)), ['recette', 'tarte', 'pommes']);
    expect(free(parseSearch('ricetta della torta con le fragole', now)), ['ricetta', 'torta', 'fragole']);
    expect(free(parseSearch('recept för äppelkaka och grädde', now)), ['recept', 'äppelkaka', 'grädde']);
    expect(free(parseSearch('resep kue cokelat untuk keluarga', now)), ['resep', 'kue', 'cokelat', 'keluarga']);
    for (final word in ['les', 'och', 'và', 'için', 'een', 'della']) {
      expect(isServiceWord(word), isTrue, reason: word);
    }
    // во французском «pour» служебное, а в английском — «налить»
    for (final word in ['pour', 'man', 'come', 'bank', 'хлеб', 'кофе']) {
      expect(isServiceWord(word), isFalse, reason: word);
    }
  });

  group('даты', () {
    test('вчера на всех языках — весь вчерашний день', () {
      for (final word in ['вчера', 'вчора', 'yesterday', 'gestern', 'ayer', 'ieri', 'wczoraj']) {
        final query = parseSearch('кофе $word', now);
        expect(query.from, DateTime(2026, 11, 3), reason: word);
        expect(query.to, DateTime(2026, 11, 4), reason: word);
        expect(free(query), ['кофе'], reason: word);
        expect(query.understood, [word], reason: word);
      }
    });

    test('сегодня и позавчера', () {
      expect(parseSearch('сегодня', now).from, DateTime(2026, 11, 4));
      expect(parseSearch('heute', now).to, DateTime(2026, 11, 5));
      expect(parseSearch('позавчера', now).from, DateTime(2026, 11, 2));
      expect(parseSearch('anteayer', now).to, DateTime(2026, 11, 3));
    });

    test('на прошлой неделе — с понедельника по воскресенье прошлой недели', () {
      for (final phrase in ['на прошлой неделе', 'минулого тижня', 'last week', 'letzte Woche', 'la semana pasada', 'săptămâna trecută', 'w zeszłym tygodniu']) {
        final query = parseSearch(phrase, now);
        expect(query.from, DateTime(2026, 10, 26), reason: phrase);
        expect(query.to, DateTime(2026, 11, 2), reason: phrase);
        expect(free(query), isEmpty, reason: phrase);
      }
    });

    test('на этой неделе и в этом месяце', () {
      expect(parseSearch('на этой неделе', now).from, DateTime(2026, 11, 2));
      expect(parseSearch('this month', now).from, DateTime(2026, 11));
      expect(parseSearch('в прошлом месяце', now).from, DateTime(2026, 10));
      expect(parseSearch('в прошлом месяце', now).to, DateTime(2026, 11));
    });

    test('месяц словом — последний прошедший такой месяц', () {
      for (final phrase in ['в мае', 'у травні', 'in May', 'im Mai', 'en mayo', 'în mai', 'w maju']) {
        final query = parseSearch('рецепт $phrase', now);
        expect(query.from, DateTime(2026, 5), reason: phrase);
        expect(query.to, DateTime(2026, 6), reason: phrase);
        expect(free(query), ['рецепт'], reason: phrase);
      }
      // декабрь ещё не наступил — значит прошлогодний
      expect(parseSearch('в декабре', now).from, DateTime(2025, 12));
      expect(parseSearch('март 2024', now).from, DateTime(2024, 3));
    });

    test('слово «may» без предлога — просто слово', () {
      final query = parseSearch('you may like', now);
      expect(query.from, isNull);
    });

    test('прошлым летом и зимой', () {
      final summer = parseSearch('прошлым летом', now);
      expect(summer.from, DateTime(2026, 6));
      expect(summer.to, DateTime(2026, 9));
      final winter = parseSearch('зимой', now);
      expect(winter.from, DateTime(2025, 12));
      expect(winter.to, DateTime(2026, 3));
      expect(parseSearch('last summer', now).from, DateTime(2026, 6));
      expect(parseSearch('vara trecută', now).from, DateTime(2026, 6));
    });

    test('год числом и «год назад»', () {
      expect(parseSearch('в 2025 году', now).from, DateTime(2025));
      expect(parseSearch('2025', now).to, DateTime(2026));
      final ago = parseSearch('год назад', now);
      expect(ago.from!.isBefore(DateTime(2025, 11, 4)), isTrue);
      expect(ago.to!.isAfter(DateTime(2025, 11, 4)), isTrue);
      final days = parseSearch('3 дня назад', now);
      expect(days.from, DateTime(2026, 11, 1));
      expect(days.to, DateTime(2026, 11, 2));
      expect(parseSearch('a week ago', now).from, isNotNull);
      expect(parseSearch('vor 2 Tagen', now).from, DateTime(2026, 11, 2));
      expect(parseSearch('hace un mes', now).from, isNotNull);
      expect(parseSearch('rok temu', now).from, isNotNull);
    });
  });

  group('вид вещи', () {
    test('видео, фото, голосовое, ссылки, файлы, заметки', () {
      expect(parseSearch('рецепт видео', now).kinds, {ItemKind.video});
      expect(parseSearch('ролики', now).kinds, {ItemKind.video});
      expect(parseSearch('скрины', now).kinds, {ItemKind.image});
      expect(parseSearch('Fotos', now).kinds, {ItemKind.image});
      expect(parseSearch('zdjęcia', now).kinds, {ItemKind.image});
      expect(parseSearch('голосовые', now).kinds, {ItemKind.voice});
      expect(parseSearch('статьи', now).kinds, {ItemKind.link});
      expect(parseSearch('договор pdf', now).extensions, {'pdf'});
      expect(parseSearch('заметки', now).kinds, {ItemKind.note});
    });

    test('ютуб и тикток — ролик с этого сайта', () {
      final query = parseSearch('паста ютуб', now);
      expect(query.kinds, {ItemKind.video});
      expect(query.hosts, {'youtube'});
      expect(free(query), ['паста']);
      expect(parseSearch('tiktok', now).hosts, {'tiktok'});
    });
  });

  group('длина', () {
    test('до 5 минут, больше 10 минут', () {
      expect(parseSearch('ролики до 5 минут', now).maxSeconds, 300);
      expect(parseSearch('videos under 5 min', now).maxSeconds, 300);
      expect(parseSearch('больше 10 минут', now).minSeconds, 600);
      expect(parseSearch('más de 10 minutos', now).minSeconds, 600);
    });

    test('короткие и длинные', () {
      expect(parseSearch('короткие ролики', now).maxSeconds, 60);
      expect(parseSearch('long videos', now).minSeconds, 600);
    });
  });

  test('срок назад от сегодня: «за неделю», «за последние 3 дня», «last 7 days»', () {
    // сегодня среда, 4 ноября: неделя — с 29 октября по сегодня включительно
    final week = parseSearch('скрины за неделю', now);
    expect((week.from, week.to), (DateTime(2026, 10, 29), DateTime(2026, 11, 5)));
    expect(week.understood, ['скрины', 'за неделю']);
    expect(free(week), isEmpty);
    expect(parseSearch('за последние 3 дня', now).from, DateTime(2026, 11, 2));
    expect(parseSearch('за месяц', now).from, DateTime(2026, 10, 5));
    expect(parseSearch('последний год', now).from, DateTime(2025, 11, 5));
    expect(parseSearch('videos last 7 days', now).from, DateTime(2026, 10, 29));
    // «last week» без числа — прошлая календарная неделя, как было
    expect(parseSearch('last week', now).from, DateTime(2026, 10, 26));
    // голое слово — не время
    expect(free(parseSearch('неделю отпуска', now)), ['неделю', 'отпуска']);
  });

  test('траты: «потратил на ремонт», «spent on», «расходы» — фильтр по цене, папку ищет репозиторий', () {
    final query = parseSearch('потратил на ремонт', now);
    expect(query.spending, isTrue);
    expect(query.understood, ['потратил на']);
    expect(free(query), ['ремонт']);
    expect(parseSearch('spent on renovation', now).spending, isTrue);
    expect(free(parseSearch('расходы машина', now)), ['машина']);
    expect(parseSearch('потратила', now).hasFilters, isTrue);
  });

  test('рядом на всех языках', () {
    for (final phrase in ['кофе рядом', 'кава поруч', 'coffee nearby', 'Kaffee in der Nähe', 'café cerca', 'cafea aproape', 'kawa w pobliżu']) {
      final query = parseSearch(phrase, now);
      expect(query.near, isTrue, reason: phrase);
      expect(query.words, hasLength(1), reason: phrase);
    }
  });

  test('дома и на работе на всех языках', () {
    for (final phrase in ['дома', 'вдома', 'at home', 'zu Hause', 'daheim', 'en casa', 'acasă', 'w domu']) {
      final query = parseSearch('рецепт $phrase', now);
      expect(query.at, PlaceMark.home, reason: phrase);
      expect(free(query), ['рецепт'], reason: phrase);
    }
    for (final phrase in ['на работе', 'на роботі', 'at work', 'auf der Arbeit', 'im Büro', 'en el trabajo', 'la serviciu', 'w pracy']) {
      expect(parseSearch('пароль $phrase', now).at, PlaceMark.work, reason: phrase);
    }
    final created = DateTime(2026, 11, 3, 19);
    final home = parseSearch('дома', now);
    expect(home.admits(createdAt: created, kind: ItemKind.note, marks: {PlaceMark.home}), isTrue);
    expect(home.admits(createdAt: created, kind: ItemKind.note, marks: {PlaceMark.work}), isFalse);
    expect(home.admits(createdAt: created, kind: ItemKind.note), isFalse);
  });

  group('цена', () {
    test('до суммы с валютой на семи языках', () {
      for (final (phrase, amount, currency) in [
        ('диван до 5000 лей', 5000.0, 'MDL'),
        ('диван дешевле 5000', 5000.0, null),
        ('sofa under \$300', 300.0, 'USD'),
        ('Sofa unter 300 €', 300.0, 'EUR'),
        ('sofá menos de 300 €', 300.0, 'EUR'),
        ('canapea sub 5000 lei', 5000.0, 'MDL'),
        ('sofa poniżej 1000 zł', 1000.0, 'PLN'),
        ('диван дешевше 9000 грн', 9000.0, 'UAH'),
      ]) {
        final query = parseSearch(phrase, now);
        expect(query.maxPrice, amount, reason: phrase);
        expect(query.currency, currency, reason: phrase);
        expect(query.words, hasLength(1), reason: phrase);
      }
    });

    test('дороже и от — до', () {
      expect(parseSearch('дороже 1000 лей', now).minPrice, 1000);
      expect(parseSearch('more expensive than 50', now).minPrice, 50);
      final range = parseSearch('от 100 до 500 лей', now);
      expect(range.minPrice, 100);
      expect(range.maxPrice, 500);
      expect(range.currency, 'MDL');
    });

    test('запасной поиск словами без чисел и валюты цены', () {
      final query = parseSearch('мебель до 5000 лей', now);
      expect([for (final word in query.withoutFilters().words) word.word], ['мебель']);
    });

    test('«до 5» без валюты — не цена', () {
      expect(parseSearch('глава до 5', now).maxPrice, isNull);
    });

    test('подпись включает знак валюты', () {
      expect(parseSearch('sofa under \$300', now).understood, [r'under $300']);
    });

    test('подходит ли вещь по цене', () {
      final created = DateTime(2026, 11, 3);
      final query = parseSearch('до 500 лей', now);
      expect(query.admits(createdAt: created, kind: ItemKind.note, prices: [(450, 'MDL')]), isTrue);
      expect(query.admits(createdAt: created, kind: ItemKind.note, prices: [(600, 'MDL')]), isFalse);
      expect(query.admits(createdAt: created, kind: ItemKind.note, prices: [(450, 'EUR')]), isFalse);
      expect(query.admits(createdAt: created, kind: ItemKind.note), isFalse);
      expect(parseSearch('дешевле 500', now).admits(createdAt: created, kind: ItemKind.note, prices: [(450, 'EUR')]), isTrue);
    });
  });

  test('скрины — только скриншоты, а не все картинки', () {
    for (final word in ['скрины', 'скриншоты', 'screenshots', 'Bildschirmfotos', 'capturas', 'zrzuty', 'скріни']) {
      final query = parseSearch(word, now);
      expect(query.screenshots, isTrue, reason: word);
      expect(query.kinds, {ItemKind.image}, reason: word);
    }
    final created = DateTime(2026, 11, 3);
    final query = parseSearch('скрины', now);
    expect(query.admits(createdAt: created, kind: ItemKind.image, screenshot: true), isTrue);
    expect(query.admits(createdAt: created, kind: ItemKind.image), isFalse);
    expect(parseSearch('фото', now).screenshots, isFalse);
  });

  test('слова запроса несут варианты: транслит и раскладку', () {
    final query = parseSearch('rjat', now);
    expect(query.words.single.variants.map((variant) => variant.text), contains('кофе'));
  });

  test('без фильтров — те же слова, фильтры обнулены', () {
    final query = parseSearch('видео вчера', now);
    final plain = query.withoutFilters();
    expect(plain.hasFilters, isFalse);
    expect(free(plain), ['видео', 'вчера']);
  });

  group('на грани', () {
    test('год рядом с другими словами — просто слово', () {
      final query = parseSearch('iphone 2025', now);
      expect(query.from, isNull);
      expect(free(query), ['iphone', '2025']);
    });

    test('«короткий» без роликов — просто слово', () {
      final query = parseSearch('short story', now);
      expect(query.maxSeconds, isNull);
      expect(free(query), ['short', 'story']);
    });

    test('голосовое из двух слов — одно голосовое', () {
      for (final phrase in ['голосовое сообщение', 'voice note', 'mesaj vocal', 'nota de voz', 'notas de voz']) {
        final query = parseSearch(phrase, now);
        expect(query.kinds, {ItemKind.voice}, reason: phrase);
        expect(free(query), isEmpty, reason: phrase);
      }
    });

    test('с мая — до сегодня, до мая — всё раньше', () {
      final since = parseSearch('с мая', now);
      expect(since.from, DateTime(2026, 5));
      expect(since.to, isNull);
      final until = parseSearch('до мая', now);
      expect(until.from, isNull);
      expect(until.to, DateTime(2026, 5));
    });

    test('число и месяц — один день', () {
      for (final phrase in ['5 мая', 'May 5th', '5 de mayo', '5. Mai', '5 maja']) {
        final query = parseSearch(phrase, now);
        expect(query.from, DateTime(2026, 5, 5), reason: phrase);
        expect(query.to, DateTime(2026, 5, 6), reason: phrase);
      }
    });

    test('в мае прошлого года', () {
      expect(parseSearch('в мае прошлого года', now).from, DateTime(2025, 5));
    });

    test('вчера вечером и this morning — день и часы', () {
      final evening = parseSearch('вчера вечером', now);
      expect(evening.from, DateTime(2026, 11, 3));
      expect(evening.fromHour, 17);
      expect(evening.toHour, 24);
      final morning = parseSearch('this morning', now);
      expect(morning.from, DateTime(2026, 11, 4));
      expect(morning.fromHour, 5);
      expect(parseSearch('anoche', now).from, DateTime(2026, 11, 3));
      expect(parseSearch('morning routine', now).fromHour, isNull);
    });

    test('день недели — последний такой день', () {
      expect(parseSearch('в пятницу', now).from, DateTime(2026, 10, 30));
      expect(parseSearch('am Montag', now).from, DateTime(2026, 11, 2));
      expect(parseSearch('в среду', now).from, DateTime(2026, 11, 4));
      expect(parseSearch('в прошлую среду', now).from, DateTime(2026, 10, 28));
      expect(parseSearch('vineri', now).from, DateTime(2026, 10, 30));
      expect(parseSearch('среда разработки', now).from, isNull);
    });

    test('от 2 до 5 минут', () {
      final query = parseSearch('от 2 до 5 минут', now);
      expect(query.minSeconds, 120);
      expect(query.maxSeconds, 300);
    });

    test('украинский апостроф: «п’ятниця» узнаётся', () {
      expect(parseSearch("у п'ятницю", now).from, DateTime(2026, 10, 30));
    });

    test('подпись — фразы как набраны, по порядку', () {
      expect(parseSearch('видео с пастой на прошлой неделе', now).understood, ['видео', 'на прошлой неделе']);
    });
  });

  group('подходит ли вещь', () {
    final created = DateTime(2026, 11, 3, 19);

    test('даты, часы и вид', () {
      final query = parseSearch('видео вчера вечером', now);
      expect(query.admits(createdAt: created, kind: ItemKind.video), isTrue);
      expect(query.admits(createdAt: created, kind: ItemKind.note), isFalse);
      expect(query.admits(createdAt: DateTime(2026, 11, 3, 9), kind: ItemKind.video), isFalse);
      expect(query.admits(createdAt: DateTime(2026, 11, 4, 19), kind: ItemKind.video), isFalse);
    });

    test('сайт главнее вида', () {
      final query = parseSearch('ютуб', now);
      expect(query.admits(createdAt: created, kind: ItemKind.link, url: 'https://youtu.be/abc'), isTrue);
      expect(query.admits(createdAt: created, kind: ItemKind.video, url: 'https://m.youtube.com/watch?v=1'), isTrue);
      expect(query.admits(createdAt: created, kind: ItemKind.video, url: 'https://vimeo.com/1'), isFalse);
    });

    test('расширение файла', () {
      final query = parseSearch('pdf', now);
      expect(query.admits(createdAt: created, kind: ItemKind.file, fileName: 'Договор.PDF'), isTrue);
      expect(query.admits(createdAt: created, kind: ItemKind.link, url: 'https://site.md/a.pdf?x=1'), isTrue);
      expect(query.admits(createdAt: created, kind: ItemKind.file, fileName: 'a.docx'), isFalse);
      expect(parseSearch('doc', now).admits(createdAt: created, kind: ItemKind.file, fileName: 'a.docx'), isTrue);
    });

    test('длина и рядом', () {
      final short = parseSearch('ролики до 5 минут', now);
      expect(short.admits(createdAt: created, kind: ItemKind.video, durationSeconds: 200), isTrue);
      expect(short.admits(createdAt: created, kind: ItemKind.video, durationSeconds: 400), isFalse);
      expect(short.admits(createdAt: created, kind: ItemKind.video), isFalse);
      final near = parseSearch('рядом', now);
      expect(near.admits(createdAt: created, kind: ItemKind.note, metersAway: 300), isTrue);
      expect(near.admits(createdAt: created, kind: ItemKind.note, metersAway: 3000), isFalse);
      expect(near.admits(createdAt: created, kind: ItemKind.note), isFalse);
    });
  });

  test('служебные слова не ищутся', () {
    expect(free(parseSearch('рецепт для пасты и соуса', now)), ['рецепт', 'пасты', 'соуса']);
    expect(free(parseSearch('Rezept für die Pasta', now)), ['rezept', 'pasta']);
  });

  group('цвет', () {
    test('слово цвета в любой форме и на семи языках — фильтр по главному цвету', () {
      final samples = {
        'синее платье': ColorFamily.blue,
        'красная обложка': ColorFamily.red,
        'жёлтые цветы': ColorFamily.yellow,
        'зелёного дивана': ColorFamily.green,
        'голубое небо': ColorFamily.sky,
        'чорна сукня': ColorFamily.black,
        'blue dress': ColorFamily.blue,
        'grey sofa': ColorFamily.gray,
        'rote Jacke': ColorFamily.red,
        'vestido rojo': ColorFamily.red,
        'rochie neagră': ColorFamily.black,
        'różowa sukienka': ColorFamily.pink,
        'бирюзовая ваза': ColorFamily.teal,
        'коричневые ботинки': ColorFamily.brown,
      };
      for (final MapEntry(key: text, value: family) in samples.entries) {
        final query = parseSearch(text, now);
        expect(query.colors, {family}, reason: text);
        expect(query.words, hasLength(1), reason: text);
        expect(query.hasFilters, isTrue, reason: text);
      }
      expect(parseSearch('синее платье', now).understood, ['синее']);
    });

    test('похожие слова — не цвет', () {
      for (final text in ['Красноярск', 'белка', 'сериал', 'синица', 'роток', 'Белград', 'Rotterdam']) {
        expect(parseSearch(text, now).colors, isEmpty, reason: text);
      }
    });

    test('цвет пропускает только вещи с этим главным цветом', () {
      final query = parseSearch('синее', now);
      expect(query.admits(createdAt: now, kind: ItemKind.image, colors: const {'blue', 'white'}), isTrue);
      expect(query.admits(createdAt: now, kind: ItemKind.image, colors: const {'red'}), isFalse);
      expect(query.admits(createdAt: now, kind: ItemKind.note), isFalse);
    });
  });
}
