/// Напоминание по месту в тексте строки. На семи языках — «напомни дома», «когда приду
/// на работу», «remind me here». По-русски ещё и без «напомни»: «буду проходить мимо
/// магазина», «зайду в аптеку», «иду в гости к другу», «буду у Саши». Без ИИ, по шаблонам.
///
/// Место само по себе («купил молоко дома») напоминанием не считается: нужен глагол
/// движения в будущем или «напомни». Иначе каждая вторая заметка звенела бы дома.
library;

import 'models.dart';
import 'word_forms.dart' show stemOf;

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
// Глаголы — только будущее, инфинитив и деепричастие: «зашёл в магазин» уже было, звенеть незачем.
const _verbs =
    r'(?:буду|будем)\s+(?:проходить|проезжать|пробегать|подходить|подъезжать|заходить|заезжать|приходить|приезжать|возвращаться|находиться)'
    r'|проходя|проезжая|прохожу|проезжаю|пройду|проеду|пробегу|подойду|подъеду|подхожу|подъезжаю'
    r'|зайду|заеду|забегу|загляну|заскочу|приду|приеду|прибегу|вернусь|доберусь|доеду|дойду|окажусь|окажемся|попаду'
    r'|иду|идём|идем|пойду|пойдём|пойдем|еду|едем|поеду|поедем|схожу|съезжу|сгоняю|собираюсь'
    r'|зайти|заехать|забежать|заглянуть|прийти|приехать|вернуться|добраться|дойти|доехать|попасть|пойти|поехать|сходить|съездить'
    r'|буду|будем';

const _prepositions = r'мимо|около|возле|рядом\s+со?|в\s+гости\s+ко?|в\s+гостях\s+у|в|во|на|ко?|до|у';

final _moving = RegExp(
  '(?<![\\p{L}\\p{N}])'
  // «когда», «если», «как только» и «я» перед глаголом уходят из заголовка вместе с ним
  '(?:(?:когда|если|как\\s+только|как|пока)\\s+)?(?:(?:я|мы)\\s+)?'
  '(?:(?:по\\s+дороге|по\\s+пути)|в\\s+гостях\\s+у|(?:$_verbs)(?:\\s+(?:$_prepositions))?)'
  '(?=[\\s,]+[\\p{L}\\p{N}])',
  caseSensitive: false,
  unicode: true,
);

// после «по дороге» свой предлог: «по дороге в аптеку», «по пути домой»
final _afterRoad = RegExp(r'^\s+(?:в|во|на|ко?|до)(?=\s)', unicode: true);

// слова вида места; основы считаются от всех форм, где беглая гласная их меняет: «рынок» и «рынке»
const _kindWords = {
  PlaceKind.home: ['дом', 'домой', 'дома', 'квартира', 'хата'],
  PlaceKind.work: ['работа', 'офис', 'служба'],
  PlaceKind.study: ['универ', 'университет', 'институт', 'колледж', 'школа', 'учеба', 'курсы', 'лекция', 'лицей', 'техникум', 'академия'],
  PlaceKind.shop: ['магазин', 'супермаркет', 'гипермаркет', 'маркет', 'рынок', 'рынке', 'ларек', 'ларьке', 'магаз'],
  PlaceKind.pharmacy: ['аптека'],
  PlaceKind.food: ['кафе', 'кафешка', 'ресторан', 'кофейня', 'кофейне', 'бар', 'столовая', 'пиццерия', 'бистро', 'шаурмичная', 'суши'],
  PlaceKind.sport: ['зал', 'спортзал', 'качалка', 'бассейн', 'тренировка', 'фитнес', 'стадион', 'каток'],
  PlaceKind.guests: ['гости', 'гостях', 'друг', 'подруга', 'друзья', 'друзей', 'родители', 'бабушка', 'дедушка'],
};

const _hereWords = ['здесь', 'тут', 'сюда'];

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
  for (final match in _moving.allMatches(text)) {
    var tailStart = match.end;
    final road = match.group(0)!.toLowerCase().contains(RegExp(r'по\s+(?:дороге|пути)'));
    if (road) {
      final preposition = _afterRoad.firstMatch(text.substring(tailStart));
      if (preposition != null) tailStart += preposition.end;
    }
    // место — в первых трёх словах после предлога, до знака препинания
    final tail = text.substring(tailStart);
    final stop = tail.indexOf(RegExp(r'[,.;:!?\n—–]'));
    final words = _placeWord.allMatches(stop < 0 ? tail : tail.substring(0, stop)).take(3).toList();
    if (words.isEmpty || _verbEnding.hasMatch(words.first.group(0)!.toLowerCase())) continue;
    final stems = [for (final word in words) stemOf(word.group(0)!)];
    int endOf(int index) => tailStart + words[index].end;

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
    if (match.group(0)!.toLowerCase().contains('гост')) {
      return PlaceCue(kind: PlaceReminderKind.guests, start: match.start, end: endOf(0));
    }
  }
  return null;
}
