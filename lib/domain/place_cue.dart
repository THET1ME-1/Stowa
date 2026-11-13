/// Напоминание по месту в тексте строки. На семи языках — «напомни дома», «когда приду
/// на работу», «remind me here». По-русски ещё и без «напомни»: «буду проходить мимо
/// магазина», «зайду в аптеку», «иду в гости к другу», «буду у Саши». Без ИИ, по шаблонам.
///
/// Место само по себе («купил молоко дома») напоминанием не считается: нужен глагол
/// движения в будущем или «напомни». Иначе каждая вторая заметка звенела бы дома.
library;

import 'models.dart';
import 'word_forms.dart' show foldText, stemOf;

/// Найденное место: какое и где оно в тексте (строка его подчёркивает).
/// У своего места — его id и имя.
class PlaceCue {
  const PlaceCue({required this.kind, required this.start, required this.end, this.placeId, this.placeName});

  final PlaceReminderKind kind;
  final int start;
  final int end;
  final String? placeId;
  final String? placeName;

  /// Текст без места и без «напомни»: из него получается заголовок.
  /// «в 9 и когда буду мимо магазина купить хлеб» без времени и места — «купить хлеб», без висящего «и».
  String restOf(String text) => '${text.substring(0, start)} ${text.substring(end)}'
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s,.:;—–-]+|[\s,.:;—–-]+$'), '')
      .replaceAll(RegExp(r'^(?:и|а|and|und|și|si|i|y)\s+|\s+(?:и|а|and|und|și|si|i|y)$', caseSensitive: false, unicode: true), '')
      .trim();
}

// «напомни» на семи языках, с «мне» там, где его говорят
const _remind = r'напомни(?:те|ть)?(?:\s+мне)?|нагадай(?:те)?(?:\s+мені)?|remind(?:\s+me)?|amintește(?:-mi)?|aminteste(?:-mi)?|przypomnij(?:\s+mi)?|erinnere(?:\s+mich)?|recuérdame|recuerdame';

// где: «дома», «at home», «zu Hause»…
const _at = {
  PlaceReminderKind.home: r'дома|вдома|удома|at\s+home|acasă|acasa|w\s+domu|zu\s+hause|zuhause|daheim|en\s+casa',
  PlaceReminderKind.work: r'на\s+работе|на\s+роботі|at\s+work|la\s+serviciu|la\s+muncă|w\s+pracy|auf\s+der\s+arbeit|bei\s+der\s+arbeit|en\s+el\s+trabajo',
  PlaceReminderKind.point: r'тут|здесь|here|aici|tutaj|hier|aquí|aqui',
  PlaceReminderKind.shop: r'в\s+магазине|в\s+магазині|у\s+магазині|at\s+the\s+(?:store|shop|supermarket)|in\s+the\s+(?:store|shop)|la\s+magazin|w\s+sklepie|im\s+(?:laden|supermarkt|geschäft)|en\s+la\s+tienda|en\s+el\s+s[úu]per(?:mercado)?',
};

// «когда приду домой» и родня: сама просьба напомнить уже в обороте
const _when = {
  PlaceReminderKind.home:
      r'(?:когда|как)\s+(?:буду|приду|вернусь|окажусь)\s+(?:дома|домой)|when\s+i(?:\x27m|\s+am|\s+get|\s+come)(?:\s+back)?\s+home|коли\s+(?:буду|прийду|повернуся)\s+(?:вдома|додому)|când\s+(?:ajung|sunt|vin)\s+acasă|(?:gdy|jak|kiedy)\s+(?:będę\s+w\s+domu|wrócę\s+do\s+domu)|wenn\s+ich\s+(?:nach\s+hause\s+komme|zu\s+hause\s+bin|zuhause\s+bin|daheim\s+bin)|cuando\s+(?:llegue\s+a\s+casa|esté\s+en\s+casa|vuelva\s+a\s+casa)',
  PlaceReminderKind.work:
      r'(?:когда|как)\s+(?:буду|приду)\s+(?:на\s+работе|на\s+работу)|when\s+i(?:\x27m|\s+am|\s+get)(?:\s+to|\s+at)?\s+work|коли\s+(?:буду|прийду)\s+(?:на\s+роботі|на\s+роботу)|când\s+(?:ajung|sunt)\s+la\s+(?:serviciu|muncă)|(?:gdy|jak|kiedy)\s+(?:będę\s+w\s+pracy|przyjdę\s+do\s+pracy)|wenn\s+ich\s+(?:auf\s+der|bei\s+der|zur)\s+arbeit\s+(?:bin|komme)|cuando\s+(?:llegue\s+al|esté\s+en\s+el)\s+trabajo',
  PlaceReminderKind.point:
      r'(?:когда|как)\s+(?:буду|окажусь|вернусь)\s+(?:тут|здесь|сюда)|when\s+i(?:\x27m|\s+am|\s+get|\s+come)(?:\s+back)?\s+here|коли\s+(?:буду|повернуся)\s+(?:тут|сюди)|când\s+(?:ajung|revin|sunt)\s+aici|(?:gdy|jak|kiedy)\s+(?:będę\s+tutaj|wrócę\s+tutaj)|wenn\s+ich\s+(?:wieder\s+)?hier\s+bin|cuando\s+(?:vuelva|esté)\s+aquí',
  PlaceReminderKind.shop:
      r'(?:когда|как)\s+(?:буду|зайду|приду)\s+в\s+магазин(?:е)?|when\s+i(?:\x27m|\s+am|\s+get)(?:\s+to|\s+at)\s+the\s+(?:store|shop|supermarket)|коли\s+(?:буду|зайду)\s+(?:в|у)\s+магазин(?:і)?|când\s+(?:ajung|sunt|intru)\s+(?:la|în)\s+magazin|(?:gdy|jak|kiedy)\s+(?:będę\s+w\s+sklepie|wejdę\s+do\s+sklepu)|wenn\s+ich\s+im\s+(?:laden|supermarkt)\s+bin|cuando\s+(?:esté|llegue)\s+(?:en|a)\s+la\s+tienda',
};

RegExp _word(String body) => RegExp('(?<![\\p{L}\\p{N}])(?:$body)(?![\\p{L}\\p{N}])', caseSensitive: false, unicode: true);

final _patterns = [
  for (final kind in _when.keys) ...[
    (kind, _word(_when[kind]!)),
    // «напомни дома», «remind me at home», «дома напомни»
    (kind, _word('(?:$_remind)[\\s,:]+(?:${_at[kind]!})')),
    (kind, _word('(?:${_at[kind]!})[\\s,:]+(?:$_remind)')),
  ],
];

/// Своё место из «Мест» для разбора: по имени его узнаёт текст, по своему виду ([label]) — тоже.
typedef KnownPlace = ({String id, String name, PlaceKind kind, String? label});

/// Место-напоминание в тексте или null. Несколько — берётся первое по тексту.
/// [places] — свои места: «буду у Саши» узнаёт место с именем «Саша».
PlaceCue? parsePlaceCue(String text, {List<KnownPlace> places = const []}) {
  PlaceCue? best;
  for (final (kind, pattern) in _patterns) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    if (best == null || match.start < best.start) best = PlaceCue(kind: kind, start: match.start, end: match.end);
  }
  final moving = _movingCue(text, places);
  if (moving != null && (best == null || moving.start < best.start)) best = moving;
  return best;
}

// Русский разбор без «напомни»: глагол движения или «буду», предлог и место.
// Разбор без «напомни» на семи языках: союз, глагол движения или «буду», предлог и место.
// Слова — без знаков над буквами: сверка идёт по тексту, где «mâine» уже «maine».
// Глаголы — только будущее, инфинитив и деепричастие: «зашёл в магазин» уже было, звенеть незачем.

// «когда», «when», «wenn», «cuando», «gdy», «când», «коли» — уходят из заголовка вместе с глаголом
const _conj =
    r'когда|если|как\s+только|как|пока|коли|якщо|як\s+тільки'
    r'|when|whenever|if|once|next\s+time|wenn|sobald|falls|cuando|si|en\s+cuanto|al|gdy|jak|kiedy|jesli|jezeli|cand|daca|imediat\s+ce';

const _subject = r'я|мы|ми|i|we|ich|wir|yo|ja|my|eu|noi';

const _verbs =
    // русский
    r'(?:буду|будем)\s+(?:проходить|проезжать|пробегать|подходить|подъезжать|заходить|заезжать|приходить|приезжать|возвращаться|находиться)'
    r'|проходя|проезжая|прохожу|проезжаю|пройду|проеду|пробегу|подойду|подъеду|подхожу|подъезжаю'
    r'|зайду|заеду|забегу|загляну|заскочу|приду|приеду|прибегу|вернусь|доберусь|доеду|дойду|окажусь|окажемся|попаду'
    r'|иду|идём|идем|пойду|пойдём|пойдем|еду|едем|поеду|поедем|схожу|съезжу|сгоняю|собираюсь'
    r'|зайти|заехать|забежать|заглянуть|прийти|приехать|вернуться|добраться|дойти|доехать|попасть|пойти|поехать|сходить|съездить'
    r'|буду|будем'
    // украинский
    r'|буду\s+(?:проходити|проїжджати|заходити)|проходитиму|проїжджатиму|пройду|проїду|зайду|забіжу|загляну|піду|поїду|прийду|приїду'
    r'|повернуся|дійду|доїду|потраплю|опинюся|іду|йду|їду'
    // английский
    r"|(?:pass(?:ing)?|walk(?:ing)?\s+past|driv(?:e|ing)\s+past|go(?:ing)?\s+past|walk(?:ing)?\s+by|driv(?:e|ing)\s+by|go(?:ing)?\s+by"
    r"|stop(?:ping)?\s+by|drop(?:ping)?\s+by|swing\s+by|get(?:ting)?\s+to|go(?:ing)?\s+to|head(?:ing)?\s+to|come\s+to|coming\s+to|arrive\s+at|visit(?:ing)?|'ll\s+be|will\s+be)"
    // немецкий
    r'|gehe|gehen|fahre|fahren|komme|kommen|laufe|laufen'
    // испанский
    r'|pase|pasare|pasar|pasando|paso|vaya|ire|voy|vamos|llegue|llegare|llegar|llegando|entre|entrare'
    // польский
    r'|bede\s+(?:przechodzic|przechodzil|przechodzila|przejezdzac)|przechodzac|przejde|przejade|wejde|wpadne|zajrze|pojde|pojade|dojde|dojade|wroce|zajde|zajade|ide|jade|bede'
    // румынский
    r'|voi\s+trece|o\s+sa\s+trec|trec|trecand|voi\s+ajunge|o\s+sa\s+ajung|ajung|voi\s+fi|o\s+sa\s+fiu|merg|ma\s+duc|voi\s+intra|intru|vin';

// «буду» по-английски, по-испански и по-румынски — настоящее время: «I'm at the store» —
// просто где я, а «when I'm at the store» — напоминание. Эти глаголы — только после союза
const _beVerbs = r"'m|am|are|'re|be|bin|sind|este|estoy|estemos|sunt|suntem";

const _prepositions =
    r'мимо|около|возле|рядом\s+со?|в\s+гости\s+ко?|в\s+гостях\s+у|в|во|на|ко?|до|у'
    r'|повз|біля|коло|в\s+гості\s+до|у\s+гостях\s+у'
    r'|past|by|near|at|into|in|to|over'
    r'|zum|zur|zu|ins|im|in\s+die|in\s+den|in\s+das|in\s+der|beim|bei\s+der|nach|an\s+der|an\s+dem|am|an'
    r'|por\s+delante\s+de|por|cerca\s+de|hacia|al|a|en'
    r'|obok|kolo|przy|do|na|we?'
    r'|pe\s+langa|pe\s+la|la|spre|catre';

// «по дороге», «on my way», «auf dem Weg», «de camino», «po drodze», «în drum spre», «дорогою»
const _road = r'по\s+дороге|по\s+пути|дорогою|по\s+дорозі|on\s+my\s+way|on\s+the\s+way|auf\s+dem\s+weg|de\s+camino|camino|po\s+drodze|w\s+drodze|in\s+drum|pe\s+drum';

// после «по дороге» свой предлог: «по дороге в аптеку», «on my way to the store»
final _afterRoad = RegExp(r'^\s+(?:в|во|на|ко?|до|to|zum|zur|nach|in|a|al|do|spre|catre)(?=\s)', unicode: true);

final _moving = RegExp(
  '(?<![\\p{L}\\p{N}])(?:'
  // «когда я буду проходить мимо», «when I pass by», «cuando pase por»
  '(?:(?:$_conj)\\s+)?(?:(?:$_subject)\\s*)?(?:(?:$_road)|в\\s+гостях\\s+у|(?:$_verbs)(?:\\s+(?:morgen|heute|tomorrow|today|manana|hoy|jutro|maine|azi))?(?:\\s+(?:$_prepositions))?)'
  // «when I'm at», «wenn ich bin», «cuando esté en», «când sunt la» — только после союза
  '|(?:$_conj)\\s+(?:(?:$_subject)\\s*)?(?:$_beVerbs)\\s+(?:$_prepositions)'
  // немецкий порядок: «wenn ich an der Apotheke vorbeigehe» — место до глагола
  '|(?:wenn|sobald|falls)\\s+(?:ich|wir)\\s+(?:an\\s+der|an\\s+dem|am|an|beim|bei\\s+der|im|in\\s+der|in\\s+den|zum|zur|nach)'
  ')(?=[\\s,]+[\\p{L}\\p{N}])',
  unicode: true,
);

// немецкий глагол после места уходит из заголовка вместе с оборотом
final _germanTail = RegExp(r'^\s+(?:vorbei\w*|bin|sind|komme|kommen|gehe|gehen|fahre|fahren|ankomme|ankommen)(?![\p{L}\p{N}])', unicode: true);

// артикли перед местом не мешают: «the pharmacy», «la farmacia», «der Apotheke»
const _articles = {'the', 'a', 'an', 'der', 'die', 'das', 'dem', 'den', 'des', 'el', 'la', 'los', 'las', 'un', 'una', 'lo', 'my', 'mein', 'meine', 'mi'};

// слова вида места на семи языках; основы считаются от всех форм, где беглая гласная их меняет: «рынок» и «рынке»
const _kindWords = {
  PlaceKind.home: [
    'дом', 'домой', 'дома', 'квартира', 'хата', 'дім', 'додому', 'вдома', 'хати',
    'home', 'house', 'hause', 'zuhause', 'casa', 'dom', 'domu', 'acasa', 'casa',
  ],
  PlaceKind.work: [
    'работа', 'офис', 'служба', 'робота', 'роботу', 'роботи', 'офіс',
    'work', 'office', 'job', 'arbeit', 'buro', 'trabajo', 'oficina', 'praca', 'pracy', 'prace', 'biuro', 'biura', 'serviciu', 'munca', 'birou',
  ],
  PlaceKind.study: [
    'универ', 'университет', 'институт', 'колледж', 'школа', 'учеба', 'курсы', 'лекция', 'лицей', 'техникум', 'академия',
    'універ', 'університет', 'школу', 'курси', 'пари',
    'school', 'university', 'uni', 'college', 'class', 'classes', 'schule', 'universitat', 'vorlesung',
    'escuela', 'universidad', 'facultad', 'clase', 'clases', 'szkola', 'szkoly', 'uczelnia', 'uczelni', 'zajecia',
    'scoala', 'facultate', 'universitate', 'cursuri',
  ],
  PlaceKind.shop: [
    'магазин', 'супермаркет', 'гипермаркет', 'маркет', 'рынок', 'рынке', 'ларек', 'ларьке', 'магаз', 'ринок', 'ринку',
    'store', 'shop', 'supermarket', 'market', 'grocery', 'laden', 'supermarkt', 'geschaft', 'markt',
    'tienda', 'supermercado', 'mercado', 'sklep', 'sklepu', 'sklepie', 'marketu', 'magazin', 'magazinul', 'piata',
  ],
  PlaceKind.pharmacy: ['аптека', 'pharmacy', 'drugstore', 'chemist', 'apotheke', 'farmacia', 'apteka', 'apteki', 'aptece', 'apteke', 'farmacie', 'farmaciei'],
  PlaceKind.food: [
    'кафе', 'кафешка', 'ресторан', 'кофейня', 'кофейне', 'бар', 'столовая', 'пиццерия', 'бистро', 'шаурмичная', 'суши', 'кавʼярня', 'кавярня',
    'cafe', 'restaurant', 'bar', 'pub', 'diner', 'kneipe', 'cafeteria', 'restaurante', 'kawiarnia', 'kawiarni', 'restauracja', 'restauracji',
    'cafenea', 'cafeneaua', 'restaurantul',
  ],
  PlaceKind.sport: [
    'зал', 'спортзал', 'качалка', 'бассейн', 'тренировка', 'фитнес', 'стадион', 'каток', 'басейн', 'спортзалі',
    'gym', 'pool', 'fitness', 'stadium', 'fitnessstudio', 'schwimmbad', 'gimnasio', 'piscina', 'silownia', 'silowni', 'basen', 'basenu',
    'sala', 'sala de sport',
  ],
  PlaceKind.guests: [
    'гости', 'гостях', 'друг', 'подруга', 'друзья', 'друзей', 'родители', 'бабушка', 'дедушка', 'гості', 'друга', 'друзів',
    'friend', 'friends', 'freund', 'freundin', 'freunden', 'amigo', 'amiga', 'amigos', 'przyjaciel', 'przyjaciela', 'znajomych',
    'prieten', 'prietena', 'prietenului',
  ],
};

const _hereWords = ['здесь', 'тут', 'сюда', 'сюди', 'here', 'hier', 'aqui', 'aca', 'tutaj', 'aici'];

final Map<String, PlaceKind> _kindByStem = {
  for (final MapEntry(key: kind, value: words) in _kindWords.entries)
    for (final word in words) stemOf(word): kind,
};

final Set<String> _hereStems = {for (final word in _hereWords) stemOf(word)};

/// Готовый вид по слову: «универ» — учёба, «аптека» — аптека. Подсказка вида по имени места.
PlaceKind? kindOfWord(String word) => _kindByStem[stemOf(word)];

// слово места: буквы и цифры, апостроф внутри («Andy's»)
final _placeWord = RegExp(r"[\p{L}\p{N}]+(?:'[\p{L}]+)?", unicode: true);

// глагол на месте места: «буду работать», «пойду спать»
final _verbEnding = RegExp(r'(?:ть|ти|чь|ться|тись)$');

PlaceCue? _movingCue(String text, List<KnownPlace> places) {
  final named = [
    for (final place in places)
      (place: place, stems: [for (final match in _placeWord.allMatches(place.name)) stemOf(match.group(0)!)]),
  ];
  // сверка по тексту без знаков над буквами, длина та же: места совпадают с исходным
  final folded = foldText(text);
  for (final match in _moving.allMatches(folded)) {
    var tailStart = match.end;
    final road = RegExp('$_road\$', unicode: true).hasMatch(match.group(0)!);
    if (road) {
      final preposition = _afterRoad.firstMatch(folded.substring(tailStart));
      if (preposition != null) tailStart += preposition.end;
    }
    // место — в первых трёх словах после предлога, до знака препинания; артикли не в счёт
    final tail = text.substring(tailStart);
    final stop = tail.indexOf(RegExp(r'[,.;:!?\n—–]'));
    final words = [
      for (final word in _placeWord.allMatches(stop < 0 ? tail : tail.substring(0, stop)))
        if (!_articles.contains(foldText(word.group(0)!))) word,
    ].take(3).toList();
    if (words.isEmpty || _verbEnding.hasMatch(words.first.group(0)!.toLowerCase())) continue;
    final stems = [for (final word in words) stemOf(word.group(0)!)];
    // немецкий глагол после места: «an der Apotheke vorbeigehe» — уходит вместе с оборотом
    int endOf(int index) {
      final end = tailStart + words[index].end;
      final verb = _germanTail.firstMatch(folded.substring(end));
      return verb == null ? end : end + verb.end;
    }

    // своё место по имени: со слова сразу после предлога, по всем словам имени или по первому;
    // совпало у нескольких одинаково («Дача родителей», «Дача Саши») — решает вид ниже
    final matched = <({KnownPlace place, int length})>[];
    for (final (:place, stems: name) in named) {
      if (name.isEmpty || stems.first != name.first) continue;
      var length = 1;
      while (length < name.length && length < stems.length && stems[length] == name[length]) {
        length++;
      }
      matched.add((place: place, length: length));
    }
    if (matched.isNotEmpty) {
      final best = matched.map((one) => one.length).reduce((a, b) => a > b ? a : b);
      final winners = matched.where((one) => one.length == best).toList();
      if (winners.length == 1) {
        final place = winners.single.place;
        return PlaceCue(kind: PlaceReminderKind.place, start: match.start, end: endOf(best - 1), placeId: place.id, placeName: place.name);
      }
    }
    // свой вид по слову: «поеду на дачу» — у мест вида «Дача»; одно такое место — оно само
    for (final (index, stem) in stems.indexed) {
      final owners = [
        for (final known in places)
          if (known.label case final label? when label.isNotEmpty && stemOf(_placeWord.firstMatch(label)?.group(0) ?? label) == stem) known,
      ];
      if (owners.isEmpty) continue;
      final only = owners.length == 1 ? owners.single : null;
      return PlaceCue(
        kind: PlaceReminderKind.place,
        start: match.start,
        end: endOf(index),
        placeId: only?.id ?? placeTypeRef(owners.first.label!),
        placeName: only?.name ?? owners.first.label,
      );
    }
    if (_hereStems.contains(stems.first)) return PlaceCue(kind: PlaceReminderKind.point, start: match.start, end: endOf(0));
    // вид по слову: «мимо продуктового магазина» — и через слово
    for (final (index, stem) in stems.indexed) {
      final kind = _kindByStem[stem];
      if (kind != null) return PlaceCue(kind: remindAtKind(kind), start: match.start, end: endOf(index));
    }
    // «в гости к Маше», «в гостях у Маши»: место не отмечено, но вид ясен
    if (RegExp('гост|гості').hasMatch(match.group(0)!)) {
      return PlaceCue(kind: PlaceReminderKind.guests, start: match.start, end: endOf(0));
    }
  }
  return null;
}
