/// Что человек ищет, словами на любом из семи языков Stowa: «рецепт пасты
/// видео вчера», «coffee nearby», «Fotos im Mai», «ролики до 5 минут».
///
/// Без ИИ и без сети: фразы времени, вида, сайта, длины и места узнаются по
/// спискам слов каждого языка. Что узналось, уходит в фильтры и в подпись
/// «Ищу: …», остальное ищется как слова, со своими формами, транслитом и
/// чужой раскладкой.
library;

import 'dart:math';

import 'image_colors.dart';
import 'models.dart';
import 'money.dart';
import 'word_forms.dart';
import 'word_variants.dart';

/// «Рядом» — не дальше километра от того места, где сейчас телефон.
const nearMeters = 1000.0;

/// Отметка места, которую телефон угадывает сам: дом и работа.
enum PlaceMark { home, work }

/// Слово запроса и как ещё его могли написать.
class QueryWord {
  const QueryWord(this.word, this.variants);

  /// Слово в нижнем регистре, как набрано.
  final String word;
  final List<WordVariant> variants;
}

/// Разобранный запрос: слова и фильтры.
class SearchQuery {
  const SearchQuery({
    this.words = const [],
    this.from,
    this.to,
    this.fromHour,
    this.toHour,
    this.kinds = const {},
    this.extensions = const {},
    this.hosts = const {},
    this.minSeconds,
    this.maxSeconds,
    this.near = false,
    this.minPrice,
    this.maxPrice,
    this.currency,
    this.screenshots = false,
    this.spending = false,
    this.colors = const {},
    this.at,
    this.understood = const [],
    this.plainWords = const [],
  });

  /// «Потратил на ремонт»: только заметки с ценой; папку по слову находит репозиторий.
  final bool spending;

  /// «синее», «red»: главный цвет картинки или обложки.
  final Set<ColorFamily> colors;

  /// «дома», «на работе».
  final PlaceMark? at;

  final List<QueryWord> words;

  /// Создано не раньше [from] и раньше [to]. Пусто — без границы.
  final DateTime? from;
  final DateTime? to;

  /// Час создания: с [fromHour] до [toHour], ночь переходит через полночь.
  final int? fromHour;
  final int? toHour;

  final Set<ItemKind> kinds;

  /// Окончания имени файла или ссылки: pdf, docx.
  final Set<String> extensions;

  /// Сайты из [siteHosts]: youtube, tiktok.
  final Set<String> hosts;

  /// Длина ролика или голосового в секундах.
  final int? minSeconds;
  final int? maxSeconds;
  final bool near;

  /// Сумма в вещи: «до 500 лей», «дороже 1000». [currency] — если валюту назвали.
  final double? minPrice;
  final double? maxPrice;
  final String? currency;

  /// Только скриншоты, а не все картинки.
  final bool screenshots;

  /// Узнанные фразы, как набраны: для подписи «Ищу: видео · вчера».
  final List<String> understood;

  /// Все слова запроса, и узнанные тоже: ими ищется, когда фильтры ничего не нашли.
  final List<QueryWord> plainWords;

  bool get hasFilters =>
      from != null ||
      to != null ||
      fromHour != null ||
      kinds.isNotEmpty ||
      extensions.isNotEmpty ||
      hosts.isNotEmpty ||
      minSeconds != null ||
      maxSeconds != null ||
      near ||
      minPrice != null ||
      maxPrice != null ||
      screenshots ||
      spending ||
      colors.isNotEmpty ||
      at != null;

  bool get isEmpty => words.isEmpty && !hasFilters;

  /// Тот же запрос простыми словами, без фильтров.
  SearchQuery withoutFilters() => SearchQuery(words: plainWords, plainWords: plainWords);

  /// Тот же запрос с другими словами поиска: слово-папку трат репозиторий забирает себе.
  SearchQuery withWords(List<QueryWord> words) => SearchQuery(
    words: words,
    from: from,
    to: to,
    fromHour: fromHour,
    toHour: toHour,
    kinds: kinds,
    extensions: extensions,
    hosts: hosts,
    minSeconds: minSeconds,
    maxSeconds: maxSeconds,
    near: near,
    minPrice: minPrice,
    maxPrice: maxPrice,
    currency: currency,
    screenshots: screenshots,
    spending: spending,
    colors: colors,
    at: at,
    understood: understood,
    plainWords: plainWords,
  );

  /// Подходит ли вещь под фильтры. Слова проверяет ранжирование.
  /// [marks] — где вещь сохранена: дома, на работе.
  bool admits({
    required DateTime createdAt,
    required ItemKind kind,
    String url = '',
    String fileName = '',
    int? durationSeconds,
    double? metersAway,
    Set<PlaceMark> marks = const {},
    List<(double, String)> prices = const [],
    bool screenshot = false,
    Set<String> colors = const {},
  }) {
    if (at != null && !marks.contains(at)) return false;
    if (screenshots && !screenshot) return false;
    if (spending && prices.isEmpty) return false;
    // [colors] вещи — имена семей её главных цветов
    if (this.colors.isNotEmpty && !this.colors.any((family) => colors.contains(family.name))) return false;
    if (minPrice != null || maxPrice != null) {
      final fits = prices.any(
        (price) => (currency == null || price.$2 == currency) && (minPrice == null || price.$1 >= minPrice!) && (maxPrice == null || price.$1 <= maxPrice!),
      );
      if (!fits) return false;
    }
    if (from != null && createdAt.isBefore(from!)) return false;
    if (to != null && !createdAt.isBefore(to!)) return false;
    if (fromHour != null && toHour != null) {
      final hour = createdAt.hour;
      final inside = fromHour! <= toHour! ? hour >= fromHour! && hour < toHour! : hour >= fromHour! || hour < toHour!;
      if (!inside) return false;
    }
    // сайт главнее вида: ролик с YouTube мог сохраниться и ссылкой
    if (hosts.isNotEmpty) {
      if (!hosts.any((site) => hostMatches(site, url))) return false;
    } else if (extensions.isNotEmpty) {
      final name = '${fileName.toLowerCase()} ${url.toLowerCase().split('?').first}';
      if (!extensions.any((extension) => RegExp('\\.${extension}x?(\\s|\$)').hasMatch(name))) return false;
    } else if (kinds.isNotEmpty && !kinds.contains(kind)) {
      return false;
    }
    if (minSeconds != null || maxSeconds != null) {
      if (durationSeconds == null) return false;
      if (minSeconds != null && durationSeconds < minSeconds!) return false;
      if (maxSeconds != null && durationSeconds > maxSeconds!) return false;
    }
    if (near && (metersAway == null || metersAway > nearMeters)) return false;
    return true;
  }
}

/// Сайты, которые узнаёт поиск, и их адреса.
const siteHosts = {
  'youtube': ['youtube.com', 'youtu.be'],
  'tiktok': ['tiktok.com'],
  'instagram': ['instagram.com'],
  'twitter': ['twitter.com', 'x.com'],
  'telegram': ['t.me', 'telegram.org', 'telegram.me'],
  'reddit': ['reddit.com', 'redd.it'],
  'pinterest': ['pinterest.'],
  'vk': ['vk.com', 'vk.ru'],
  'github': ['github.com'],
  'wikipedia': ['wikipedia.org'],
  'spotify': ['spotify.com'],
  'twitch': ['twitch.tv'],
  'vimeo': ['vimeo.com'],
  'habr': ['habr.com'],
  'facebook': ['facebook.com', 'fb.com', 'fb.watch'],
};

/// Адрес ведёт на сайт: сам домен или его поддомен.
bool hostMatches(String site, String url) {
  final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
  if (host.isEmpty) return false;
  return (siteHosts[site] ?? const []).any((known) => known.endsWith('.') ? host.contains(known) : host == known || host.endsWith('.$known'));
}

SearchQuery parseSearch(String text, DateTime now) => _Parser(text, now).parse();

// ---------------------------------------------------------------------------
// Списки слов. Пишутся как в языке, со знаками; сравниваются свёрнутыми.

String _clean(String word) => foldText(word).replaceAll(RegExp("['’ʼ]"), '');

/// Набор слов: точные формы и начала. У начала можно ограничить, сколько букв дальше.
class _Words {
  _Words(String exact, [String prefixes = '', this.extra]) : exact = {for (final word in exact.split(' ')) if (word.isNotEmpty) _clean(word)}, prefixes = [for (final word in prefixes.split(' ')) if (word.isNotEmpty) _clean(word)];

  final Set<String> exact;
  final List<String> prefixes;
  final int? extra;

  bool has(String word) => exact.contains(word) || prefixes.any((prefix) => word.startsWith(prefix) && (extra == null || word.length - prefix.length <= extra!));
}

final _today = _Words('сегодня сёдня сьогодні today heute hoy azi astăzi astazi dzisiaj dziś');
final _yesterday = _Words('вчера вчора yesterday gestern ayer ieri wczoraj');
final _beforeYesterday = _Words('позавчера позавчора vorgestern anteayer antier alaltăieri przedwczoraj');

final _thisWords = _Words(
  'этот эта это этой этом эту этого цей ця це цього цьому цієї цю this current diese diesen dieser dieses diesem este esta asta aceasta acesta acest ten tym tego tej',
  'текущ поточн curent bieżąc',
);
final _lastWords = _Words('last previous past', 'прошл прошедш минул letzt vorig vergangen pasad anterior trecut precedent zeszł ubiegł poprzedni ostatni');

final _weekNouns = _Words('week woche semana săptămâna săptămâna săptămânii săptămînă tydzień', 'недел тижн тижден tygodn');
final _monthNouns = _Words('month monat monats mes luna lunii miesiąc miesiącu miesiąca', 'месяц місяц');
final _yearNouns = _Words('год году года рік році року year jahr jahres año an anul anului rok roku');

// время назад: «3 дня назад», «vor 2 Tagen», «hace un mes», «rok temu»
final _agoAfter = _Words('назад тому ago temu');
final _agoBefore = _Words('vor hace acum');

enum _Unit { minute, hour, day, week, month, year }

final _agoUnits = {
  _Unit.minute: _Words('минуту минуты минут хвилину хвилини хвилин minute minutes min minuten minuto minutos minut minuty'),
  _Unit.hour: _Words('час часа часов годину години годин hour hours stunde stunden hora horas oră ore godzinę godziny godzin'),
  _Unit.day: _Words('день дня дней дни дні днів day days tag tage tagen tages día días zi zile ziua dzień dni dnia'),
  _Unit.week: _Words('неделю недели недель неделя тиждень тижні тижнів тижня week weeks woche wochen semana semanas săptămână săptămâni tydzień tygodnie tygodni'),
  _Unit.month: _Words('месяц месяца месяцев місяць місяці місяців місяця month months monat monate monaten mes meses lună luni miesiąc miesiące miesięcy'),
  _Unit.year: _Words('год года лет рік роки років року year years jahr jahre jahren año años an ani rok lata lat'),
};

const _numberWords = {
  'один': 1, 'одну': 1, 'одна': 1, 'одного': 1, 'одне': 1, 'one': 1, 'a': 1, 'an': 1,
  'ein': 1, 'eine': 1, 'einen': 1, 'einem': 1, 'einer': 1, 'un': 1, 'una': 1, 'uno': 1, 'o': 1, 'unu': 1,
  'jeden': 1, 'jedna': 1, 'jedno': 1,
  'два': 2, 'две': 2, 'дві': 2, 'пару': 2, 'пара': 2, 'two': 2, 'couple': 2, 'zwei': 2, 'dos': 2, 'doi': 2, 'doua': 2, 'dwa': 2, 'dwie': 2,
  'три': 3, 'three': 3, 'drei': 3, 'tres': 3, 'trei': 3, 'trzy': 3,
  'несколько': 3, 'кілька': 3, 'few': 3, 'several': 3, 'einige': 3, 'unos': 3, 'unas': 3, 'cateva': 3, 'kilka': 3,
  'четыре': 4, 'чотири': 4, 'four': 4, 'vier': 4, 'cuatro': 4, 'patru': 4, 'cztery': 4,
  'пять': 5, 'five': 5, 'funf': 5, 'cinco': 5, 'cinci': 5, 'piec': 5,
  'шесть': 6, 'шість': 6, 'six': 6, 'sechs': 6, 'seis': 6, 'sase': 6, 'szesc': 6,
  'семь': 7, 'сім': 7, 'seven': 7, 'sieben': 7, 'siete': 7, 'sapte': 7, 'siedem': 7,
  'десять': 10, 'ten': 10, 'zehn': 10, 'diez': 10, 'zece': 10, 'dziesiec': 10,
};

// месяцы: номер и формы; двусмысленные (may, mai, march) узнаются только с предлогом или годом
final _months = <(int, _Words, _Words)>[
  (1, _Words('січень січня січні january januar jänner enero ianuarie styczeń stycznia styczniu', 'январ', 2), _Words('jan')),
  (2, _Words('лютого лютому february februar febrero februarie lutego lutym', 'феврал', 2), _Words('лютий luty feb')),
  (3, _Words('березень березня березні märz marzo martie marzec marcu', 'март', 2), _Words('march mar marca')),
  (4, _Words('квітень квітня квітні april abril aprilie kwiecień kwietnia kwietniu', 'апрел', 2), _Words('apr')),
  (5, _Words('май мая мае маю травень травня травні mayo maju'), _Words('may mai maj maja')),
  (6, _Words('червень червня червні june juni junio iunie czerwiec czerwca czerwcu', 'июн', 2), _Words('jun')),
  (7, _Words('липень липня липні july juli julio iulie lipiec lipca lipcu', 'июл', 2), _Words('jul')),
  (8, _Words('серпень серпня серпні agosto sierpień sierpnia sierpniu', 'август', 2), _Words('august aug')),
  (9, _Words('вересень вересня вересні september septiembre setiembre septembrie wrzesień września wrześniu', 'сентябр', 2), _Words('sep sept')),
  (10, _Words('жовтень жовтня жовтні october oktober octubre octombrie październik października październiku', 'октябр', 2), _Words('oct')),
  (11, _Words('листопада листопаді november noviembre noiembrie listopada listopadzie', 'ноябр', 2), _Words('листопад listopad nov')),
  (12, _Words('грудень грудня грудні december dezember diciembre decembrie grudzień grudnia grudniu', 'декабр', 2), _Words('dec')),
];

enum _Season { winter, spring, summer, autumn }

const _seasonStart = {_Season.spring: 3, _Season.summer: 6, _Season.autumn: 9, _Season.winter: 12};

// времена года: все формы; «зимой», «влітку», «latem» сами говорят о времени, «лето» — нет
final _seasons = <(_Season, _Words, _Words)>[
  (_Season.winter, _Words('зима зимы зиму зиме зими зимі winter invierno iarnă iernii zima zimy zimie zimę'), _Words('зимой зимою взимку узимку iarna zimą')),
  (_Season.spring, _Words('весна весны весну весне весни весні spring frühling primavera primăvară primăverii wiosna wiosny wiosnę wiośnie'), _Words('весной весною навесні primăvara wiosną')),
  (_Season.summer, _Words('лето лета лете літо літа літі summer sommer verano vară verii lato lata lecie'), _Words('летом влітку улітку літом vara latem')),
  (_Season.autumn, _Words('осень осени осінь осені autumn fall herbst otoño toamnă toamnei jesień jesieni'), _Words('осенью восени увосени осінню toamna jesienią')),
];

// дни недели с понедельника; без предлога узнаются только румынские, кроме «luni» (это и «месяцы»)
final _weekdays = <(int, _Words)>[
  (1, _Words('monday montag lunes luni poniedziałek', 'понедельник понеділ')),
  (2, _Words('tuesday dienstag martes marți wtorek', 'вторник вівтор')),
  (3, _Words('среда среду среды среде середа середу середи wednesday mittwoch miércoles miercuri środa środę')),
  (4, _Words('thursday donnerstag jueves joi czwartek', 'четверг четвер')),
  (5, _Words('friday freitag viernes vineri piątek', 'пятниц')),
  (6, _Words('saturday samstag sonnabend sábado sâmbătă sobota sobotę', 'суббот субот')),
  (7, _Words('воскресенье воскресенья неділя неділю неділі sunday sonntag domingo duminică niedziela niedzielę')),
];
final _weekdayBare = _Words('marți miercuri joi vineri sâmbătă duminică');

// время суток: часы с какого и до какого; английские и испанские слова — только в связке
final _dayTimes = <(int, int, _Words, _Words)>[
  (5, 12, _Words('утром вранці зранку уранці morgens vormittags dimineața dimineata rano rankiem'), _Words('morning mañana vormittag')),
  (12, 17, _Words('днём днем вдень удень mittags nachmittags'), _Words('afternoon nachmittag tarde południu')),
  (17, 24, _Words('вечером ввечері увечері вечором abends seara wieczorem'), _Words('evening abend')),
  (22, 5, _Words('ночью вночі уночі ніччю nachts noaptea nocą'), _Words('night nacht noche nocy')),
];
final _dayTimeLead = _Words('the this at in am por la esta po w heute gestern');
final _todayLead = _Words('this esta heute dziś azi');
final _lastNight = _Words('anoche aseară');

// «рядом» на всех языках, длинные фразы первыми
final _nearPhrases = [
  for (final phrase in [
    'hier in der nähe', 'рядом со мной', 'in meiner nähe', 'in der nähe', 'cerca de mí', 'возле меня', 'около меня', 'біля мене',
    'near me', 'near here', 'close by', 'around me', 'around here', 'în apropiere', 'prin apropiere', 'w pobliżu', 'obok mnie', 'por aquí',
    'рядом', 'поблизости', 'неподалёку', 'недалеко', 'поруч', 'поблизу', 'неподалік', 'nearby', 'cerca', 'aproape', 'blisko', 'niedaleko',
  ])
    [for (final word in phrase.split(' ')) _clean(word)],
];

// дом и работа, длинные фразы первыми
List<List<String>> _placePhrases(List<String> phrases) => [for (final phrase in phrases) [for (final word in phrase.split(' ')) _clean(word)]]..sort((a, b) => b.length.compareTo(a.length));
final _homePhrases = _placePhrases(['дома', 'у себя дома', 'вдома', 'удома', 'at home', 'zu hause', 'zuhause', 'daheim', 'en casa', 'acasă', 'w domu']);
final _workPhrases = _placePhrases([
  'на работе', 'в офисе', 'на роботі', 'в офісі', 'at work', 'at the office', 'in the office', 'auf der arbeit', 'bei der arbeit', 'im büro',
  'en el trabajo', 'en la oficina', 'la serviciu', 'la birou', 'w pracy', 'w biurze',
]);

// длина ролика: «до 5 минут», «больше 10 минут», «от 2 до 5 минут»
final _shorterThan = _phrases(
  'до|меньше|менее|короче|не больше|не дольше|не длиннее|максимум|менше|коротше|не більше|under|below|less than|shorter than|up to|max|maximum|at most|'
  'bis|unter|kürzer als|weniger als|höchstens|maximal|menos de|hasta|como máximo|sub|mai puțin de|până la|maxim|mai scurt de|mai scurte de|'
  'do|poniżej|mniej niż|krótsze niż|krótszy niż|maks|maksymalnie',
);
final _longerThan = _phrases(
  'больше|более|дольше|длиннее|свыше|минимум|більше|довше|понад|мінімум|over|above|more than|longer than|at least|minimum|'
  'über|mehr als|länger als|mindestens|ab|más de|más largo de|más largos de|mínimo|peste|mai mult de|mai lung de|mai lungi de|minim|cel puțin|'
  'ponad|powyżej|więcej niż|dłuższe niż|dłuższy niż',
);
final _rangeFrom = _Words('от від from von de din od');
final _rangeTo = _Words('до to bis a la do');

// цена без валюты понятна только по этим словам: «дешевле 500», «more expensive than 50»
final _cheaperThan = _phrases('дешевле|дешевше|cheaper than|cheaper|billiger als|más barato que|más barato de|mai ieftin de|mai ieftine de|tańsze niż|taniej niż|tańszy niż');
final _pricierThan = _phrases(
  'дороже|дорожче|more expensive than|pricier than|teurer als|más caro que|más caro de|mai scump de|mai scumpe de|droższe niż|drożej niż|droższy niż',
);
final _amount = RegExp(r'\d+(?:[   ]\d{3})*(?:[.,]\d+)*');
final _currencySign = RegExp(r'[$€£₽₴]');

// скриншоты отдельно от фото: их отличает извлекатель
final _screenshotWords = _Words('', 'скрин скрін screenshot bildschirmfoto captur zrzut');

// «потратил на ремонт», «расходы», «spent on»: заметки с ценой, папку по слову находит репозиторий
final _spentWords = _Words(
  'траты трат расходы расход spent spending expenses ausgaben gastos gasté gastado gastamos wydatki cheltuieli витрати',
  'потрат потрач израсход витрат wydał wydal ausgegeb cheltuit',
);
final _spentLinks = _Words('на для в on for pe na für auf en para');

// формы прилагательного: «синее», «синей», «синюю» — одно слово цвета. Перечислены целиком:
// начало «черн» поймало бы и «чернику», «бел» — «белку»
String _ruForms(String stem, {bool soft = false}) => [
  for (final ending in soft ? ['ий', 'ее', 'яя', 'ие', 'их', 'им', 'ими', 'юю', 'его', 'ей', 'ему', 'ем'] : ['ый', 'ое', 'ая', 'ые', 'ых', 'ым', 'ыми', 'ую', 'ого', 'ой', 'ому', 'ом'])
    '$stem$ending',
].join(' ');

String _ukForms(String stem, {bool soft = false}) => [
  for (final ending in soft ? ['ій', 'є', 'я', 'і', 'іх', 'ім', 'іми', 'ю', 'ього', 'ьої', 'ьому'] : ['ий', 'е', 'а', 'і', 'их', 'им', 'ими', 'у', 'ого', 'ої', 'ому', 'ій'])
    '$stem$ending',
].join(' ');

String _plForms(String stem) => [for (final ending in ['y', 'i', 'a', 'e', 'ego', 'ej', 'ym', 'im', 'ych', 'ich', 'ą', 'ymi', 'imi']) '$stem$ending'].join(' ');

String _deForms(String stem) => [for (final ending in ['', 'e', 'er', 'es', 'en', 'em']) '$stem$ending'].join(' ');

String _esForms(String stem) => [for (final ending in ['o', 'a', 'os', 'as']) '$stem$ending'].join(' ');

// слова цвета на семи языках: «синее платье», «red dress», «rote Jacke», «vestido rojo»
final _colorWords = <ColorFamily, _Words>{
  ColorFamily.red: _Words(
    '${_ruForms('красн')} ${_ukForms('червон')} red ${_deForms('rot')} ${_esForms('roj')} roșu roșie roșii rosu rosie rosii ${_plForms('czerwon')}',
  ),
  ColorFamily.orange: _Words(
    '${_ruForms('оранжев')} ${_ukForms('помаранчев')} ${_ukForms('оранжев')} orange orangene orangener orangenes orangenen naranja naranjas ${_esForms('anaranjad')} portocaliu portocalie portocalii ${_plForms('pomarańczow')}',
  ),
  ColorFamily.yellow: _Words('${_ruForms('желт')} ${_ukForms('жовт')} yellow ${_deForms('gelb')} ${_esForms('amarill')} galben galbenă galbena galbeni galbene ${_plForms('żółt')}'),
  ColorFamily.green: _Words('${_ruForms('зелен')} ${_ukForms('зелен')} green ${_deForms('grün')} verde verdes verzi ${_plForms('zielon')}'),
  ColorFamily.teal: _Words('${_ruForms('бирюзов')} ${_ukForms('бірюзов')} teal turquoise türkis turquesa turquesas turcoaz ${_plForms('turkusow')}'),
  ColorFamily.sky: _Words('${_ruForms('голуб')} ${_ukForms('блакитн')} cyan azure ${_deForms('hellblau')} celeste celestes bleu ${_plForms('błękitn')}'),
  ColorFamily.blue: _Words(
    '${_ruForms('син', soft: true)} ${_ukForms('син', soft: true)} blue ${_deForms('blau')} azul azules albastru albastră albastra albaștri albastri albastre ${_plForms('niebiesk')}',
  ),
  ColorFamily.purple: _Words(
    '${_ruForms('фиолетов')} ${_ruForms('сиренев')} ${_ruForms('лилов')} ${_ukForms('фіолетов')} ${_ukForms('бузков')} purple violet lila ${_deForms('violett')} ${_esForms('morad')} violeta violetas púrpura mov ${_plForms('fioletow')}',
  ),
  ColorFamily.pink: _Words('${_ruForms('розов')} ${_ukForms('рожев')} pink rosa ${_esForms('rosad')} roz ${_plForms('różow')}'),
  ColorFamily.brown: _Words('${_ruForms('коричнев')} ${_ukForms('коричнев')} brown ${_deForms('braun')} marrón marrones maro ${_plForms('brązow')}'),
  ColorFamily.white: _Words('${_ruForms('бел')} ${_ukForms('біл')} white weiß weiße weißer weißes weißen weiss weisse ${_esForms('blanc')} alb albă alba albi albe ${_plForms('biał')}'),
  ColorFamily.gray: _Words('${_ruForms('сер')} ${_ukForms('сір')} gray grey ${_deForms('grau')} gris grises gri ${_plForms('szar')}'),
  ColorFamily.black: _Words('${_ruForms('черн')} ${_ukForms('чорн')} black ${_deForms('schwarz')} ${_esForms('negr')} negru neagră neagra negri negre ${_plForms('czarn')}'),
};

List<List<String>> _phrases(String list) {
  final phrases = [for (final phrase in list.split('|')) [for (final word in phrase.split(' ')) _clean(word)]];
  return phrases..sort((a, b) => b.length.compareTo(a.length));
}

final _durationUnits = {
  1: _Words('сек секунд секунды секунду секунда секунди sec secs second seconds sekunde sekunden sek segundo segundos seg secunde secundă sekund sekundy sekunda'),
  60: _Words('мин минут минуты минуту минута хв хвилин хвилини хвилину хвилина min mins minute minutes minuten minuto minutos minut minuty minutę'),
  3600: _Words('час часа часов годину години годин година hour hours std stunde stunden hora horas oră ore godzina godziny godzin godzinę'),
};
final _shortWords = _Words('короткие короткий короткое короткая коротких коротенькие короткі коротке коротка short kurz kurze kurzen kurzes corto cortos corta cortas scurt scurte scurtă krótkie krótki krótka krótkich');
final _longWords = _Words('длинные длинный длинное длинная длинных долгие долгий довгі довгий довге довга довгих long lang lange langen langes largo largos larga largas lung lungi lungă długie długi długa długich');
const _shortSeconds = 60;
const _longSeconds = 600;

// виды вещей
final _kindWords = <(ItemKind, _Words)>[
  (ItemKind.voice, _Words('voice audio audios recording recordings voz vocal vocale vocală nagranie nagrania', 'голосов войс аудио аудіо голосовух sprachnachricht sprachmemo sprachaufnahme głosow')),
  (ItemKind.video, _Words('shorts', 'видео видос ролик рилс клип відео video clip reel wideo filmik')),
  (ItemKind.image, _Words('pic pics image images bild bilder imagen imágenes poza poze pozele imagini imaginea', 'фото фотк картинк картинок изображен скрин снимок снимк світлин знімок знімк зображен скрін photo picture screenshot foto bildschirmfoto captur zdjęci zdjęć zrzut obrazek obrazk')),
  (ItemKind.link, _Words('link links url urls website websites article articles artikel enlace enlaces linkuri', 'ссылк ссылок линк стать статей сайт посилан статт artícul articul articol artykuł')),
  (ItemKind.file, _Words('file files docs datei dateien archivo archivos', 'файл документ document dokument fișier plik')),
  (ItemKind.note, _Words('note notes nota notas notiță notițe notite notita', 'заметк заметок записк нотатк нотаток замітк notiz notatk notatek')),
];
final _messageWords = _Words('сообщение сообщения сообщений повідомлення message messages note notes memo memos nachricht nachrichten notiz mensaje mensajes nota notas mesaj mesaje wiadomość wiadomości notatka notatki');
final _extensions = _Words('pdf doc docx xls xlsx ppt pptx txt csv zip rar epub djvu odt');

final _sites = <(String, _Words, bool)>[
  ('youtube', _Words('yt', 'ютуб ютюб youtube', 3), true),
  ('tiktok', _Words('', 'тикток тікток tiktok', 3), true),
  ('instagram', _Words('инста инсты инст insta', 'инстаграм інстаграм instagram', 3), false),
  ('twitter', _Words('', 'твиттер твітер twitter', 3), false),
  ('telegram', _Words('', 'телеграм telegram', 3), false),
  ('reddit', _Words('', 'реддит редит reddit', 3), false),
  ('pinterest', _Words('', 'пинтерест пінтерест pinterest', 3), false),
  ('vk', _Words('вк vk вконтакте vkontakte'), false),
  ('github', _Words('', 'гитхаб github', 3), false),
  ('wikipedia', _Words('wiki вики вікі', 'википеди вікіпеді wikipedi', 3), false),
  ('spotify', _Words('', 'спотифай spotify', 3), false),
  ('twitch', _Words('', 'твич twitch', 3), true),
  ('vimeo', _Words('', 'vimeo вимео', 3), true),
  ('habr', _Words('', 'хабр habr', 3), false),
  ('facebook', _Words('fb', 'фейсбук facebook', 3), false),
];
final _topLevel = _Words('com ru be tv org me net io md ua ro pl de es');

// предлоги перед временем и местом: уходят в узнанную фразу вместе с ней
final _leadWords = _Words('в во на у за с со з із зі від до in im on at during the from since until till before en el la los las por durante desde hasta antes din în de del w we z ze od do am um of seit ab bis vor przed pana până');
final _sinceWords = _Words('с со з із зі від since from seit ab desde od');
final _untilWords = _Words('до until till before bis hasta antes przed do pana până');
final _prepositions = _Words('в во у на in im on at during en durante în w we am um');
final _articles = _Words('the el la der dem den die das');

// служебные слова: ни искать, ни раскладывать по ним нечего; сравниваются как набраны
final _stopWords = {
  for (final word
      in ('и в во на с со к ко по для из от до о об обо у за под над при про а но или же ли не ни то это мне мой моя мои моё мое все всё что чтобы как где когда '
              'который которая которые которое тот та те там тут был была было были бы еще ещё уже так вот тоже только чем его ее её их надо нужно найти найди найду покажи показать искать ищу '
              'і й та з із зі від під але чи або мені мій моє що щоб як де коли який яка які яке той був була було були би ще вже ось теж тільки знайди знайти '
              'the a an of in on at to for from with by and or but is are was were be been my me i you your it its this that these those all find show search some any about what where when which there here '
              'how why who we they he she our their us them can will just so not no do does did have has had get got into out up '
              // куски адресов: «www», «com» в тексте ссылки — не слова
              'www com http https html '
              'der die das den dem des ein eine einen einem einer und oder aber im an am auf aus bei mit nach von vom zu zum zur für um ist sind war waren mein meine meinen mich mir ich du alle finde finden zeige zeig suche was wo wann '
              'el la los las lo un una unos unas de del al y e u en con por para que mi mis yo tu es son era todo todos todas busca buscar encuentra muestra donde cuando '
              'și si în pe cu pentru despre ale ai sau dar mea meu mele mei toate tot este sunt găsește gaseste arată arata caută cauta unde când cand ce '
              'w we z ze od dla po pod nad przy ale lub albo czy nie ten ta mój moja moje mnie wszystkie znajdź znajdz pokaż pokaz szukaj gdzie kiedy jest są')
          .split(' '))
    if (word.isNotEmpty) word,
};

/// Служебное слово любого из семи языков: связи, угадыватель папки и поиск его не считают.
bool isServiceWord(String word) => _stopWords.contains(word.toLowerCase());

// ---------------------------------------------------------------------------

class _Token {
  _Token(this.raw, this.start, this.end) : word = _clean(raw);

  /// Как набрано, в нижнем регистре.
  final String raw;

  /// Свёрнуто и без апострофа: так сравнивается со списками.
  final String word;
  final int start;
  final int end;
}

final _tokenPattern = RegExp(r"[\p{L}\p{N}]+(?:['’ʼ][\p{L}\p{N}]+)*", unicode: true);
final _ordinal = RegExp(r'^(\d{1,2})(st|nd|rd|th)?$');

/// Узнанная фраза, которая ждёт конца разбора: голый год и «короткие» решаются по остальному запросу.
class _Pending {
  _Pending(this.start, this.end, this.apply);

  final int start;
  final int end;
  final void Function() apply;
}

class _Parser {
  _Parser(this.text, this.now) : tokens = [for (final match in _tokenPattern.allMatches(text)) _Token(match.group(0)!.toLowerCase(), match.start, match.end)] {
    used = List.filled(tokens.length, false);
  }

  final String text;
  final DateTime now;
  final List<_Token> tokens;
  late final List<bool> used;
  final _dateTokens = <int>{};

  // числа и единицы цены и длины: в запасной поиск словами они не идут, «5000 лей» как текст — шум
  final _quantityTokens = <int>{};
  final _understood = <(int, String)>[];
  final _pending = <(String, _Pending)>[];

  DateTime? from;
  DateTime? to;
  var _dated = false;
  int? fromHour;
  int? toHour;
  final kinds = <ItemKind>{};
  final extensions = <String>{};
  final hosts = <String>{};
  double? minPrice;
  double? maxPrice;
  String? currency;
  var screenshots = false;
  var spending = false;
  final colors = <ColorFamily>{};
  int? minSeconds;
  int? maxSeconds;
  var near = false;
  PlaceMark? at;

  DateTime get _day => DateTime(now.year, now.month, now.day);

  String? _word(int index) => index >= 0 && index < tokens.length ? tokens[index].word : null;

  bool _is(int index, _Words words) {
    final word = _word(index);
    return word != null && !used[index] && words.has(word);
  }

  SearchQuery parse() {
    var index = 0;
    while (index < tokens.length) {
      final taken = used[index] ? 1 : _match(index);
      index += max(1, taken);
    }
    _settlePending();

    final plain = _wordsOf([for (var index = 0; index < tokens.length; index++) if (!_quantityTokens.contains(index)) index]);
    var free = _wordsOf([for (var index = 0; index < tokens.length; index++) if (!used[index]) index]);
    final filtered = from != null || to != null || fromHour != null || kinds.isNotEmpty || extensions.isNotEmpty || hosts.isNotEmpty || minSeconds != null || maxSeconds != null || near || at != null || minPrice != null || maxPrice != null || screenshots || spending || colors.isNotEmpty;
    // запрос из одних служебных слов ищется как есть
    if (free.isEmpty && !filtered) free = _wordsOf(List.generate(tokens.length, (index) => index), keepStop: true);
    _understood.sort((a, b) => a.$1.compareTo(b.$1));
    return SearchQuery(
      words: free,
      from: from,
      to: to,
      fromHour: fromHour,
      toHour: toHour,
      kinds: kinds,
      extensions: extensions,
      hosts: hosts,
      minSeconds: minSeconds,
      maxSeconds: maxSeconds,
      near: near,
      minPrice: minPrice,
      maxPrice: maxPrice,
      currency: currency,
      screenshots: screenshots,
      spending: spending,
      colors: colors,
      at: at,
      understood: [for (final entry in _understood) entry.$2],
      plainWords: plain.isEmpty ? free : plain,
    );
  }

  // слова для поиска: без служебных и без повторов по основе; слово с апострофом делится, как в индексе
  List<QueryWord> _wordsOf(List<int> indexes, {bool keepStop = false}) {
    final seen = <String>{};
    final words = <QueryWord>[];
    for (final index in indexes) {
      final token = tokens[index];
      if (!keepStop && (_stopWords.contains(token.raw) || _stopWords.contains(foldText(token.raw)))) continue;
      for (final part in token.raw.split(RegExp("['’ʼ]"))) {
        final digits = RegExp(r'^\d+$').hasMatch(part);
        if (part.length < 2 && !digits) continue;
        if (!seen.add(stemOf(part))) continue;
        words.add(QueryWord(part, variantsOf(part)));
      }
    }
    return words;
  }

  int _match(int index) {
    for (final matcher in [_spent, _duration, _price, _ago, _period, _season, _month, _weekday, _dayWord, _dayTime, _year, _near, _placeMark, _site, _screenshot, _color, _kind, _shortLong]) {
      final taken = matcher(index);
      if (taken > 0) return taken;
    }
    return 0;
  }

  /// Отметить фразу узнанной. С [lead] к ней пристают предлоги перед ней: «на прошлой неделе».
  /// [endChar] — где фраза кончается в тексте, если после последнего слова стоит знак: «under $300».
  int _take(int start, int end, {bool lead = false, bool date = false, bool quantity = false, int? endChar}) {
    var first = start;
    if (lead) {
      while (first > 0 && start - first < 2 && !used[first - 1] && _leadWords.has(tokens[first - 1].word)) {
        first--;
      }
    }
    for (var index = first; index < end; index++) {
      used[index] = true;
      if (date) _dateTokens.add(index);
      if (quantity) _quantityTokens.add(index);
    }
    _understood.add((first, text.substring(tokens[first].start, endChar ?? tokens[end - 1].end)));
    return end - start;
  }

  /// Сумма с места слова [index]: «1 500», «19.99» — в тексте это несколько слов.
  /// Сколько слов заняла, где кончилась и валюта рядом, если есть.
  ({double amount, int words, int end, String? currency})? _amountAt(int index) {
    if (index >= tokens.length || used[index] || int.tryParse(tokens[index].word) == null) return null;
    final match = _amount.matchAsPrefix(text, tokens[index].start);
    if (match == null) return null;
    final amount = parseAmount(match.group(0)!);
    if (amount == null) return null;
    var words = 0;
    while (index + words < tokens.length && tokens[index + words].start < match.end) {
      words++;
    }
    var end = match.end;
    String? currency;
    // знак сразу после суммы или через пробел: «300 €», «300$»
    final after = text.substring(end).trimLeft();
    final gap = text.length - end - after.length;
    if (after.isNotEmpty && _currencySign.hasMatch(after[0]) && gap <= 1) {
      currency = currencyOf(after[0]);
      end += gap + 1;
    } else {
      final next = index + words;
      final word = next < tokens.length && !used[next] ? currencyOf(tokens[next].raw) : null;
      if (word != null) {
        currency = word;
        end = tokens[next].end;
        words++;
      }
    }
    // знак перед суммой: «under $300»
    if (currency == null && index > 0) {
      final between = text.substring(tokens[index - 1].end, tokens[index].start);
      final sign = _currencySign.firstMatch(between);
      if (sign != null) currency = currencyOf(sign.group(0)!);
    }
    return (amount: amount, words: words, end: end, currency: currency);
  }

  // «до 500 лей», «дешевле 500», «under $300», «от 100 до 500 лей»
  int _price(int index) {
    if (_is(index, _rangeFrom)) {
      final low = _amountAt(index + 1);
      if (low != null && _is(index + 1 + low.words, _rangeTo)) {
        final high = _amountAt(index + 2 + low.words);
        final money = high?.currency ?? low.currency;
        if (high != null && money != null) {
          minPrice = low.amount;
          maxPrice = high.amount;
          currency = money;
          return _take(index, index + 2 + low.words + high.words, endChar: high.end, quantity: true);
        }
      }
    }
    for (final (phrases, dearer, needsCurrency) in [(_cheaperThan, false, false), (_pricierThan, true, false), (_shorterThan, false, true), (_longerThan, true, true)]) {
      for (final phrase in phrases) {
        if (!_seq(index, phrase)) continue;
        final found = _amountAt(index + phrase.length);
        // «до 5» без валюты может быть чем угодно; «дешевле 5» — только ценой
        if (found == null || (needsCurrency && found.currency == null)) continue;
        if (dearer) {
          minPrice = found.amount;
        } else {
          maxPrice = found.amount;
        }
        currency = found.currency;
        return _take(index, index + phrase.length + found.words, endChar: found.end, quantity: true);
      }
    }
    return 0;
  }

  // «синее», «red», «rote»: главный цвет картинки или обложки
  int _color(int index) {
    for (final MapEntry(key: family, value: words) in _colorWords.entries) {
      if (!_is(index, words)) continue;
      colors.add(family);
      return _take(index, index + 1);
    }
    return 0;
  }

  // «потратил на», «spent on»: предлог после слова трат — часть фразы, а не слово поиска
  int _spent(int index) {
    if (!_is(index, _spentWords)) return 0;
    spending = true;
    return _take(index, _is(index + 1, _spentLinks) ? index + 2 : index + 1);
  }

  // «скрины», «screenshots», «capturas»: картинки, которые извлекатель признал скриншотами
  int _screenshot(int index) {
    if (!_is(index, _screenshotWords)) return 0;
    kinds.add(ItemKind.image);
    screenshots = true;
    return _take(index, index + 1);
  }

  /// Диапазон дат с предлогом перед ним: «с мая» — до сегодня, «до мая» — всё раньше.
  int _takeDate(int start, int end, DateTime begin, DateTime finish) {
    final before = start > 0 && !used[start - 1] ? tokens[start - 1].word : null;
    final taken = _take(start, end, lead: true, date: true);
    if (before != null && _sinceWords.has(before) && !_untilWords.has(before)) {
      _range(begin, null);
    } else if (before != null && _untilWords.has(before) && !_sinceWords.has(before)) {
      _range(null, begin);
    } else {
      _range(begin, finish);
    }
    return taken;
  }

  // несколько дат пересекаются: «в мае 2025» и «вечером»; не пересеклись — главнее последняя
  void _range(DateTime? begin, DateTime? finish) {
    if (!_dated) {
      from = begin;
      to = finish;
      _dated = true;
      return;
    }
    final joinedFrom = [from, begin].nonNulls.fold<DateTime?>(null, (best, date) => best == null || date.isAfter(best) ? date : best);
    final joinedTo = [to, finish].nonNulls.fold<DateTime?>(null, (best, date) => best == null || date.isBefore(best) ? date : best);
    if (joinedFrom != null && joinedTo != null && !joinedFrom.isBefore(joinedTo)) {
      from = begin;
      to = finish;
    } else {
      from = joinedFrom;
      to = joinedTo;
    }
  }

  bool _seq(int index, List<String> words) {
    for (var offset = 0; offset < words.length; offset++) {
      if (_word(index + offset) != words[offset] || used[index + offset]) return false;
    }
    return true;
  }

  /// Предлог перед словом, может быть через артикль: «in the summer», «в мае».
  bool _prepositionBefore(int index) {
    var before = index - 1;
    if (before >= 0 && _articles.has(tokens[before].word)) before--;
    return before >= 0 && !used[before] && _prepositions.has(tokens[before].word);
  }

  /// Число цифрами или словом: «3», «три», «a couple of», «ein paar».
  (int, int)? _number(int index) {
    final word = _word(index);
    if (word == null || used[index]) return null;
    final digits = int.tryParse(word);
    if (digits != null) return (digits, 1);
    final next = _word(index + 1);
    if ((word == 'a' || word == 'an') && (next == 'couple' || next == 'few')) {
      final length = _word(index + 2) == 'of' ? 3 : 2;
      return (next == 'couple' ? 2 : 3, length);
    }
    if (word == 'ein' && next == 'paar') return (3, 2);
    final value = _numberWords[word];
    return value == null ? null : (value, 1);
  }

  // «до 5 минут», «больше 10 минут», «от 2 до 5 минут»
  int _duration(int index) {
    if (_is(index, _rangeFrom)) {
      final low = _number(index + 1);
      if (low != null && _is(index + 1 + low.$2, _rangeTo)) {
        final highAt = index + 2 + low.$2;
        final high = _number(highAt);
        if (high != null) {
          final unit = _durationUnit(highAt + high.$2);
          if (unit != null) {
            minSeconds = low.$1 * unit;
            maxSeconds = high.$1 * unit;
            return _take(index, highAt + high.$2 + 1, quantity: true);
          }
        }
      }
    }
    for (final (phrases, longer) in [(_shorterThan, false), (_longerThan, true)]) {
      for (final phrase in phrases) {
        if (!_seq(index, phrase)) continue;
        final number = _number(index + phrase.length);
        if (number == null) continue;
        final unitAt = index + phrase.length + number.$2;
        final unit = _durationUnit(unitAt);
        if (unit == null) continue;
        if (longer) {
          minSeconds = number.$1 * unit;
        } else {
          maxSeconds = number.$1 * unit;
        }
        return _take(index, unitAt + 1, quantity: true);
      }
    }
    return 0;
  }

  int? _durationUnit(int index) {
    for (final entry in _durationUnits.entries) {
      if (_is(index, entry.value)) return entry.key;
    }
    return null;
  }

  _Unit? _agoUnit(int index) {
    for (final entry in _agoUnits.entries) {
      if (_is(index, entry.value)) return entry.key;
    }
    return null;
  }

  // «3 дня назад», «неделю назад», «vor 2 Tagen», «hace un mes», «acum o săptămână», «rok temu»
  int _ago(int index) {
    final before = _is(index, _agoBefore);
    var at = before ? index + 1 : index;
    var count = 1;
    final number = _number(at);
    if (number != null) {
      count = number.$1;
      at += number.$2;
    }
    final unit = _agoUnit(at);
    if (unit == null) return 0;
    at++;
    if (!before) {
      if (!_is(at, _agoAfter)) return 0;
      at++;
    }
    final day = _day;
    final (DateTime begin, DateTime finish) = switch (unit) {
      _Unit.minute => (now.subtract(Duration(minutes: count * 2 + 5)), now.add(const Duration(minutes: 1))),
      _Unit.hour => (now.subtract(Duration(hours: count + 1)), now.add(const Duration(minutes: 1))),
      _Unit.day => (DateTime(day.year, day.month, day.day - count), DateTime(day.year, day.month, day.day - count + 1)),
      _Unit.week => (DateTime(day.year, day.month, day.day - count * 7 - 3), DateTime(day.year, day.month, day.day - count * 7 + 4)),
      _Unit.month => (DateTime(day.year, day.month - count, day.day - 15), DateTime(day.year, day.month - count, day.day + 16)),
      _Unit.year => (DateTime(day.year - count, day.month - 1, day.day), DateTime(day.year - count, day.month + 1, day.day)),
    };
    return _takeDate(index, at, begin, finish);
  }

  // «на прошлой неделе», «this month», «la semana pasada», «anul trecut»
  int _period(int index) {
    for (final (modifierAt, nounAt) in [(index, index + 1), (index + 1, index)]) {
      final last = _is(modifierAt, _lastWords);
      final current = _is(modifierAt, _thisWords);
      if (!last && !current) continue;
      final shift = last ? 1 : 0;
      final day = _day;
      if (_is(nounAt, _weekNouns)) {
        final monday = DateTime(day.year, day.month, day.day - (day.weekday - 1) - shift * 7);
        return _takeDate(index, index + 2, monday, DateTime(monday.year, monday.month, monday.day + 7));
      }
      if (_is(nounAt, _monthNouns)) {
        return _takeDate(index, index + 2, DateTime(day.year, day.month - shift), DateTime(day.year, day.month - shift + 1));
      }
      if (_is(nounAt, _yearNouns)) {
        return _takeDate(index, index + 2, DateTime(day.year - shift), DateTime(day.year - shift + 1));
      }
    }
    return 0;
  }

  _Season? _seasonAt(int index, {bool adverbOnly = false}) {
    for (final (season, plain, adverb) in _seasons) {
      if (_is(index, adverb) || (!adverbOnly && _is(index, plain))) return season;
    }
    return null;
  }

  // «прошлым летом», «зимой», «last summer», «vara trecută», «im Winter»
  int _season(int index) {
    var start = index;
    var end = index + 1;
    var last = false;
    _Season? season;
    if ((_is(index, _lastWords) || _is(index, _thisWords)) && _seasonAt(index + 1) != null) {
      last = _is(index, _lastWords);
      season = _seasonAt(index + 1);
      end = index + 2;
    } else if (_seasonAt(index) != null && (_is(index + 1, _lastWords) || _is(index + 1, _thisWords))) {
      last = _is(index + 1, _lastWords);
      season = _seasonAt(index);
      end = index + 2;
    } else if (_seasonAt(index, adverbOnly: true) != null || (_seasonAt(index) != null && _prepositionBefore(index))) {
      season = _seasonAt(index);
    }
    if (season == null) return 0;
    // последний такой сезон, который уже начался; «прошлый» — который уже кончился
    final startMonth = _seasonStart[season]!;
    var year = now.year;
    DateTime begin() => DateTime(year, startMonth);
    DateTime finish() => DateTime(year, startMonth + 3);
    while (begin().isAfter(now) || (last && finish().isAfter(now))) {
      year--;
    }
    return _takeDate(start, end, begin(), finish());
  }

  (int, bool)? _monthAt(int index) {
    for (final (month, plain, ambiguous) in _months) {
      if (_is(index, plain)) return (month, false);
      if (_is(index, ambiguous)) return (month, true);
    }
    return null;
  }

  int? _yearAt(int index) {
    final word = _word(index);
    if (word == null || used[index] || !RegExp(r'^\d{4}$').hasMatch(word)) return null;
    final year = int.parse(word);
    return year >= 1970 && year <= now.year + 1 ? year : null;
  }

  int? _dayOfMonth(int index) {
    final word = _word(index);
    if (word == null || used[index]) return null;
    final match = _ordinal.firstMatch(word);
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    return day >= 1 && day <= 31 ? day : null;
  }

  // «в мае», «март 2024», «5 мая», «May 5th», «5 de mayo», «în luna mai», «в мае прошлого года»
  int _month(int index) {
    final found = _monthAt(index);
    if (found == null) return 0;
    final (month, ambiguous) = found;
    var start = index;
    var end = index + 1;
    int? day;
    int? year;
    // число перед месяцем, у испанцев через «de»
    if (_dayOfMonth(index - 1) != null) {
      day = _dayOfMonth(index - 1);
      start = index - 1;
    } else if (_word(index - 1) == 'de' && !used[index - 1] && _dayOfMonth(index - 2) != null) {
      day = _dayOfMonth(index - 2);
      start = index - 2;
    } else if (_dayOfMonth(index + 1) != null && _yearAt(index + 1) == null) {
      day = _dayOfMonth(index + 1);
      end = index + 2;
    }
    // «луна» перед румынским месяцем: «în luna mai»
    final monthNoun = start == index && _is(index - 1, _monthNouns);
    if (monthNoun) start = index - 1;
    if (_yearAt(end) != null) {
      year = _yearAt(end);
      end++;
      if (_is(end, _yearNouns)) end++;
    } else if ((_is(end, _lastWords) || _is(end, _thisWords)) && _is(end + 1, _yearNouns)) {
      year = now.year - (_is(end, _lastWords) ? 1 : 0);
      end += 2;
    }
    if (ambiguous && day == null && year == null && !monthNoun && !_prepositionBefore(start)) return 0;
    if (year == null) {
      final candidate = DateTime(now.year, month, day ?? 1);
      year = candidate.isAfter(now) ? now.year - 1 : now.year;
    }
    if (day != null) return _takeDate(start, end, DateTime(year, month, day), DateTime(year, month, day + 1));
    return _takeDate(start, end, DateTime(year, month), DateTime(year, month + 1));
  }

  // «в пятницу», «last friday», «am Freitag», «el viernes», «vineri»
  int _weekday(int index) {
    for (final (weekday, words) in _weekdays) {
      if (!_is(index, words)) continue;
      var start = index;
      final last = _is(index - 1, _lastWords);
      if (last) start = index - 1;
      final bare = _is(index, _weekdayBare);
      if (!last && !bare && !_prepositionBefore(index) && !_is(index - 1, _articles)) return 0;
      var back = (_day.weekday - weekday) % 7;
      if (last && back == 0) back = 7;
      final day = DateTime(_day.year, _day.month, _day.day - back);
      return _takeDate(start, index + 1, day, DateTime(day.year, day.month, day.day + 1));
    }
    return 0;
  }

  // «вчера», «heute», «anteayer», «the day before yesterday»
  int _dayWord(int index) {
    var back = -1;
    var end = index + 1;
    if (_is(index, _today)) back = 0;
    if (_is(index, _yesterday)) back = 1;
    if (_is(index, _beforeYesterday)) back = 2;
    if (_seq(index, ['day', 'before', 'yesterday'])) {
      back = 2;
      end = index + 3;
    }
    if (back < 0) return 0;
    final day = DateTime(_day.year, _day.month, _day.day - back);
    return _takeDate(index, end, day, DateTime(day.year, day.month, day.day + 1));
  }

  // «утром», «вчера вечером», «this morning», «por la noche», «last night», «anoche»
  int _dayTime(int index) {
    if (_is(index, _lastNight) || (_word(index) == 'night' && _is(index - 1, _lastWords))) {
      final start = _is(index, _lastNight) ? index : index - 1;
      final day = DateTime(_day.year, _day.month, _day.day - 1);
      _range(day, DateTime(day.year, day.month, day.day + 1));
      fromHour = 17;
      toHour = 24;
      return _take(start, index + 1, date: true);
    }
    for (final (begin, finish, alone, paired) in _dayTimes) {
      final bound = _is(index, alone);
      if (!bound && !_is(index, paired)) continue;
      final afterDate = _dateTokens.contains(index - 1);
      final lead = index > 0 && !used[index - 1] && _dayTimeLead.has(tokens[index - 1].word);
      if (!bound && !afterDate && !lead) continue;
      var start = index;
      // «this morning», «esta mañana», «heute Morgen» — это сегодня
      if (index > 0 && !used[index - 1] && _todayLead.has(tokens[index - 1].word)) {
        _range(_day, DateTime(_day.year, _day.month, _day.day + 1));
        start = index - 1;
      }
      fromHour = begin;
      toHour = finish;
      return _take(start, index + 1, lead: true);
    }
    return 0;
  }

  // «в 2025 году», «im Jahr 2025», «w roku 2025»; голый год решается в конце
  int _year(int index) {
    final year = _yearAt(index);
    if (year == null) return 0;
    if (_is(index + 1, _yearNouns)) return _takeDate(index, index + 2, DateTime(year), DateTime(year + 1));
    if (_is(index - 1, _yearNouns)) return _takeDate(index - 1, index + 1, DateTime(year), DateTime(year + 1));
    used[index] = true;
    _pending.add(('year', _Pending(index, index + 1, () => _takeDate(index, index + 1, DateTime(year), DateTime(year + 1)))));
    return 1;
  }

  // «дома», «at work», «im Büro», «la serviciu»
  int _placeMark(int index) {
    for (final (mark, phrases) in [(PlaceMark.home, _homePhrases), (PlaceMark.work, _workPhrases)]) {
      for (final phrase in phrases) {
        if (!_seq(index, phrase)) continue;
        at = mark;
        return _take(index, index + phrase.length);
      }
    }
    return 0;
  }

  int _near(int index) {
    for (final phrase in _nearPhrases) {
      if (!_seq(index, phrase)) continue;
      near = true;
      return _take(index, index + phrase.length);
    }
    return 0;
  }

  // «ютуб», «tiktok», «youtube.com»
  int _site(int index) {
    for (final (site, words, video) in _sites) {
      if (!_is(index, words)) continue;
      hosts.add(site);
      if (video) kinds.add(ItemKind.video);
      return _take(index, _is(index + 1, _topLevel) ? index + 2 : index + 1);
    }
    return 0;
  }

  // «видео», «скрины», «pdf», «голосовое сообщение», «nota de voz»
  int _kind(int index) {
    final word = _word(index)!;
    if (_extensions.has(word)) {
      extensions.add(word);
      return _take(index, index + 1);
    }
    // «голосовое сообщение», «voice note», «mesaj vocal», «nota de voz» — одно голосовое
    final voice = _kindWords.first.$2;
    final message = _is(index, _messageWords);
    final voiceLength = _is(index, voice) && _is(index + 1, _messageWords) || message && _is(index + 1, voice)
        ? 2
        : message && _word(index + 1) == 'de' && _word(index + 2) == 'voz'
        ? 3
        : 0;
    if (voiceLength > 0) {
      kinds.add(ItemKind.voice);
      return _take(index, index + voiceLength);
    }
    for (final (kind, words) in _kindWords) {
      if (!_is(index, words)) continue;
      kinds.add(kind);
      return _take(index, index + 1);
    }
    return 0;
  }

  // «короткие», «long» — только рядом с роликами или голосовыми, иначе это просто слово
  int _shortLong(int index) {
    final short = _is(index, _shortWords);
    if (!short && !_is(index, _longWords)) return 0;
    used[index] = true;
    _pending.add((
      'length',
      _Pending(index, index + 1, () {
        if (short) {
          maxSeconds = _shortSeconds;
        } else {
          minSeconds = _longSeconds;
        }
        _take(index, index + 1);
      }),
    ));
    return 1;
  }

  void _settlePending() {
    for (final (_, pending) in _pending) {
      for (var index = pending.start; index < pending.end; index++) {
        used[index] = false;
      }
    }
    final freeLeft = [for (var index = 0; index < tokens.length; index++) if (!used[index] && !_stopWords.contains(tokens[index].raw)) index];
    for (final (kind, pending) in _pending) {
      final accept = switch (kind) {
        'year' => freeLeft.every((index) => index >= pending.start && index < pending.end),
        _ => kinds.contains(ItemKind.video) || kinds.contains(ItemKind.voice),
      };
      if (accept) pending.apply();
    }
  }
}
