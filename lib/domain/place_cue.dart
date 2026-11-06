/// Напоминание по месту в тексте строки на семи языках: «напомни дома», «когда приду
/// на работу», «remind me here», «в магазине напомни». Без ИИ, по шаблонам.
///
/// Место само по себе («купил молоко дома») напоминанием не считается: рядом должно быть
/// «напомни» или оборот «когда приду». Иначе каждая вторая заметка звенела бы дома.
library;

import 'models.dart';

/// Найденное место: какое и где оно в тексте (строка его подчёркивает).
class PlaceCue {
  const PlaceCue({required this.kind, required this.start, required this.end});

  final PlaceReminderKind kind;
  final int start;
  final int end;

  /// Текст без места и без «напомни»: из него получается заголовок.
  String restOf(String text) =>
      '${text.substring(0, start)} ${text.substring(end)}'.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'^[\s,.:;—–-]+|[\s,.:;—–-]+$'), '').trim();
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
  for (final kind in PlaceReminderKind.values) ...[
    (kind, _word(_when[kind]!)),
    // «напомни дома», «remind me at home», «дома напомни»
    (kind, _word('(?:$_remind)[\\s,:]+(?:${_at[kind]!})')),
    (kind, _word('(?:${_at[kind]!})[\\s,:]+(?:$_remind)')),
  ],
];

/// Место-напоминание в тексте или null. Несколько — берётся первое по тексту.
PlaceCue? parsePlaceCue(String text) {
  PlaceCue? best;
  for (final (kind, pattern) in _patterns) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    if (best == null || match.start < best.start) best = PlaceCue(kind: kind, start: match.start, end: match.end);
  }
  return best;
}
