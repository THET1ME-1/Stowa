/// Напоминание в тексте строки на семи языках Stowa: русском, украинском, английском,
/// немецком, испанском, польском и румынском. Без ИИ, по словам каждого языка:
/// «завтра в 10», «tomorrow at 9 pm», «morgen um 9 Uhr», «mañana a las 9», «jutro o 9»,
/// «mâine la 9», «завтра о 9 вечора». Знаки над буквами необязательны: «manana» — тоже завтра.
/// Остальные ~100 языков — по таблицам Unicode CLDR (`reminder_world.dart`): «demain à 9h»,
/// «domani alle 9», «yarın saat 9», «明日9時».
library;

import 'cldr_time_words.dart';
import 'language_guess.dart' show guessLanguage, ownLanguages;
import 'word_forms.dart' show foldText;

part 'reminder_world.dart';

/// Напоминание, найденное в тексте: где оно и на какой момент.
class ReminderMatch {
  ReminderMatch({required this.start, required this.end, required this.at, required this.hasTime, List<(int, int)>? parts}) : parts = parts ?? [(start, end)];

  /// Весь охват напоминания: от первого куска до последнего.
  final int start;
  final int end;
  final DateTime at;

  /// Куски текста с датой и временем, их подчёркивает строка и вырезает заголовок.
  /// Обычно один, а в «завтра кафедра в 14:00» — два: день и время порознь.
  final List<(int, int)> parts;

  /// Время названо. Без времени напоминание встаёт на 9 утра.
  final bool hasTime;

  /// Текст без даты и без «напомни» в начале: из него получается заголовок.
  String restOf(String text) {
    var rest = text;
    // с конца, чтобы места ещё не вырезанных кусков не сдвигались
    for (final (from, to) in [...parts]..sort((a, b) => b.$1.compareTo(a.$1))) {
      rest = '${rest.substring(0, from)} ${rest.substring(to)}';
    }
    rest = rest
        .replaceAll(RegExp(r'\s+'), ' ')
        // «в зал в 7, ноги» без времени — «в зал, ноги», а не «в зал , ноги»
        .replaceAllMapped(RegExp(r' ([,.:;!?])'), (match) => match[1]!)
        .trim();
    // «напомни», «remind me», «erinnere mich» в начале — по тексту без знаков над буквами, длина та же
    final ask = _askPrefix.firstMatch(foldText(rest));
    if (ask != null) rest = rest.substring(ask.end);
    return rest
        .replaceAll(RegExp(r'^[\s,.:;-]+|[\s,.:;-]+$'), '')
        // «напомни в 9 и купить хлеб» без времени — «купить хлеб», без висящего «и»
        .replaceAll(RegExp(r'^(?:и|а|і|and|und|y|i|si)\s+|\s+(?:и|а|і|and|und|y|i|si)$', caseSensitive: false), '');
  }
}

const _morning = 9;

// граница слова на любом языке: буквы и цифры
const _before = r'(?<![\p{L}\p{N}])';
const _after = r'(?![\p{L}\p{N}])';

RegExp _word(String body) => RegExp('$_before(?:$body)$_after', unicode: true);

final _askPrefix = RegExp(
  r'^(?:напомни(?:те|ть)?|напоминание|нагадай(?:те)?|нагадування|remind me|reminder|erinnere mich|erinnerung|recuerdame|recordatorio|przypomnij(?: mi)?|przypomnienie|aminteste-mi|aminteste|memento)(?:\s+(?:мне|мені))?[\s,:]*',
  unicode: true,
);

/// Сегодня, завтра, послезавтра: сдвиг в днях. Длинные раньше коротких: «послезавтра» не «завтра».
final _dayWords = <(RegExp, int)>[
  for (final (body, shift) in const [
    ('послезавтра|післязавтра|the day after tomorrow|day after tomorrow|ubermorgen|pasado manana|pojutrze|poimaine', 2),
    ('сегодня|сьогодні|today|heute|hoy|dzisiaj|dzis|astazi|azi', 0),
    // «morgen» — завтра, а «am Morgen» и «Guten Morgen» — утро; «mañana» после «la» — тоже утро
    ('завтра|tomorrow|(?<!am |guten |jeden )morgen|(?<!la )manana|jutro|maine', 1),
  ])
    (_word(body), shift),
];

/// Дни недели: слово → 1–7. Перед русским и украинским — «в», «у», перед польским — «w», «we».
const _weekdayNames = {
  // русский
  'понедельник': 1, 'вторник': 2, 'среду': 3, 'четверг': 4, 'пятницу': 5, 'субботу': 6, 'воскресенье': 7,
  'пн': 1, 'вт': 2, 'ср': 3, 'чт': 4, 'пт': 5, 'сб': 6, 'вс': 7,
  // украинский
  'понеділок': 1, 'вівторок': 2, 'середу': 3, 'четвер': 4, 'пятницю': 5, 'суботу': 6, 'неділю': 7,
  // английский
  'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4, 'friday': 5, 'saturday': 6, 'sunday': 7,
  // немецкий
  'montag': 1, 'dienstag': 2, 'mittwoch': 3, 'donnerstag': 4, 'freitag': 5, 'samstag': 6, 'sonnabend': 6, 'sonntag': 7,
  // испанский
  'lunes': 1, 'martes': 2, 'miercoles': 3, 'jueves': 4, 'viernes': 5, 'sabado': 6, 'domingo': 7,
  // польский
  'poniedzialek': 1, 'wtorek': 2, 'srode': 3, 'czwartek': 4, 'piatek': 5, 'sobote': 6, 'niedziele': 7,
  // румынский
  'luni': 1, 'marti': 2, 'miercuri': 3, 'joi': 4, 'vineri': 5, 'sambata': 6, 'duminica': 7,
};

final _weekday = RegExp(
  // русские и украинские дни — только с «в»: «вторник» сам по себе чаще просто слово;
  // остальные — с предлогом или без: «Friday», «am Freitag», «el viernes», «vineri»;
  // «2 luni» по-румынски — два месяца, а не понедельник
  '$_before(?:'
  '(?:во?|у)\\s+(понедельник|вторник|среду|четверг|пятницу|субботу|воскресенье|пн|вт|ср|чт|пт|сб|вс|понеділок|вівторок|середу|четвер|п[ʼ\'’]?ятницю|суботу|неділю)'
  '|(?:(?:on|am|el|we?|pe|in)\\s+)?(?<!\\d\\s)(monday|tuesday|wednesday|thursday|friday|saturday|sunday|montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonnabend|sonntag|lunes|martes|miercoles|jueves|viernes|sabado|domingo|poniedzialek|wtorek|srode|czwartek|piatek|sobote|niedziele|luni|marti|miercuri|joi|vineri|sambata|duminica)'
  ')$_after',
  unicode: true,
);

/// Месяцы: полные формы раньше коротких, иначе «мар» съест начало «марта».
const _months = [
  // русский
  ('января', 1), ('февраля', 2), ('марта', 3), ('апреля', 4), ('мая', 5), ('июня', 6),
  ('июля', 7), ('августа', 8), ('сентября', 9), ('октября', 10), ('ноября', 11), ('декабря', 12),
  // украинский
  ('січня', 1), ('лютого', 2), ('березня', 3), ('квітня', 4), ('травня', 5), ('червня', 6),
  ('липня', 7), ('серпня', 8), ('вересня', 9), ('жовтня', 10), ('листопада', 11), ('грудня', 12),
  // английский
  ('january', 1), ('february', 2), ('march', 3), ('april', 4), ('may', 5), ('june', 6),
  ('july', 7), ('august', 8), ('september', 9), ('october', 10), ('november', 11), ('december', 12),
  // немецкий
  ('januar', 1), ('februar', 2), ('marz', 3), ('juni', 6), ('juli', 7), ('oktober', 10), ('dezember', 12),
  // испанский
  ('enero', 1), ('febrero', 2), ('marzo', 3), ('abril', 4), ('mayo', 5), ('junio', 6),
  ('julio', 7), ('agosto', 8), ('septiembre', 9), ('setiembre', 9), ('octubre', 10), ('noviembre', 11), ('diciembre', 12),
  // польский
  ('stycznia', 1), ('lutego', 2), ('marca', 3), ('kwietnia', 4), ('maja', 5), ('czerwca', 6),
  ('lipca', 7), ('sierpnia', 8), ('wrzesnia', 9), ('pazdziernika', 10), ('listopada', 11), ('grudnia', 12),
  // румынский
  ('ianuarie', 1), ('februarie', 2), ('martie', 3), ('aprilie', 4), ('mai', 5), ('iunie', 6),
  ('iulie', 7), ('septembrie', 9), ('octombrie', 10), ('noiembrie', 11), ('decembrie', 12),
  // короткие
  ('янв', 1), ('фев', 2), ('мар', 3), ('апр', 4), ('июн', 6), ('июл', 7), ('авг', 8), ('сент', 9), ('сен', 9), ('окт', 10), ('ноя', 11), ('дек', 12),
  ('jan', 1), ('feb', 2), ('mar', 3), ('apr', 4), ('jun', 6), ('jul', 7), ('aug', 8), ('sept', 9), ('sep', 9), ('oct', 10), ('nov', 11), ('dec', 12),
];

const _englishMonths = 'january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sept|sep|oct|nov|dec';

// «23 декабря», «23. Dezember», «23 de diciembre», «23rd of December»
final _monthDate = RegExp(
  '$_before(\\d{1,2})(?:st|nd|rd|th)?\\.?\\s+(?:de\\s+|of\\s+)?(${_months.map((month) => month.$1).join('|')})\\.?(?:\\s+(?:de\\s+)?(\\d{4}))?$_after',
  unicode: true,
);

// «December 23», «Dec 23rd, 2027» — так пишут только по-английски
final _monthFirst = RegExp('$_before($_englishMonths)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(\\d{4}))?$_after', unicode: true);

final _dotDate = RegExp('(?<![\\p{L}\\p{N}.:]|в )(\\d{1,2})\\.(\\d{2})(?:\\.(\\d{4}|\\d{2}))?\\.?(?![\\p{L}\\p{N}:]|\\.\\d)', unicode: true);

// предлог перед часом: «в», «at», «um», «a las», «o», «la ora»; «o» и «la» — слабые, см. [_weakPrep]
const _prep = r'в|к|о|об|at|around|by|um|gegen|ab|a las|a la|sobre las|hacia las|okolo|kolo|o|la ora|pe la|la';

/// Слабые предлоги: «5 o 6 manzanas» — «пять или шесть», «de la 5 la 6» — с пяти до шести.
/// Перед ними число — значит, это не час.
const _weakPrep = {'o', 'la'};

final _clock = RegExp('$_before(?:($_prep)\\s+)?(\\d{1,2})[:.](\\d{2})(?:\\s*(am|pm|a\\.m\\.|p\\.m\\.))?(?:\\s*uhr)?$_after', unicode: true);

// «часов», «o'clock», «Uhr», «godzinie»; после числа
const _hourWord = r"часов|часа|час|годин[аиуі]?|o'?clock|uhr|horas?|godz(?:in[aeyi]e?|\.)?";

/// Часть суток после часа: «6 вечера», «6 pm», «7 Uhr abends», «6 de la tarde», «7 wieczorem», «6 seara».
const _qualifiers = {
  'утра': _Part.morning, 'ранку': _Part.morning, 'am': _Part.am, 'a.m.': _Part.am, 'in the morning': _Part.morning,
  'morgens': _Part.morning, 'fruh': _Part.morning, 'vormittags': _Part.morning, 'de la manana': _Part.morning,
  'rano': _Part.morning, 'dimineata': _Part.morning, 'de dimineata': _Part.morning,
  'дня': _Part.day, 'in the afternoon': _Part.afternoon, 'nachmittags': _Part.afternoon, 'po poludniu': _Part.afternoon,
  'dupa-amiaza': _Part.afternoon, 'dupa amiaza': _Part.afternoon,
  'вечера': _Part.evening, 'вечора': _Part.evening, 'pm': _Part.pm, 'p.m.': _Part.pm, 'in the evening': _Part.evening,
  'abends': _Part.evening, 'de la tarde': _Part.evening, 'de la noche': _Part.evening, 'wieczorem': _Part.evening, 'seara': _Part.evening,
  'ночи': _Part.night, 'ночі': _Part.night, 'at night': _Part.night, 'nachts': _Part.night, 'w nocy': _Part.night, 'noaptea': _Part.night,
};

final _hour = RegExp(
  '$_before(?:($_prep)\\s+)?(\\d{1,2})(?:\\s*($_hourWord))?(?:\\s*(${_qualifiers.keys.map(RegExp.escape).join('|')}))?(?![\\p{L}\\p{N}:]|\\.\\d)',
  unicode: true,
);

enum _Part { morning, day, afternoon, evening, night, am, pm, noon, midnight }

/// Часть суток сама по себе: час и как она уточняет соседний час («вечером в 6» — 18).
const _dayParts = <String, (int, _Part)>{
  // русский
  'с утра': (9, _Part.morning), 'утром': (9, _Part.morning), 'днем': (13, _Part.day), 'вечером': (19, _Part.evening),
  'ночью': (23, _Part.night), 'в полдень': (12, _Part.noon), 'в полночь': (0, _Part.midnight),
  // украинский
  'вранці': (9, _Part.morning), 'зранку': (9, _Part.morning), 'уранці': (9, _Part.morning), 'вдень': (13, _Part.day),
  'ввечері': (19, _Part.evening), 'увечері': (19, _Part.evening), 'вночі': (23, _Part.night), 'уночі': (23, _Part.night),
  'опівдні': (12, _Part.noon), 'опівночі': (0, _Part.midnight),
  // английский: «morning» и «evening» без «in the» — только после «today», «tomorrow»
  'in the morning': (9, _Part.morning), 'this morning': (9, _Part.morning), 'in the afternoon': (15, _Part.afternoon),
  'this afternoon': (15, _Part.afternoon), 'in the evening': (19, _Part.evening), 'this evening': (19, _Part.evening),
  'tonight': (19, _Part.evening), 'at night': (23, _Part.night), 'at noon': (12, _Part.noon), 'at midday': (12, _Part.noon),
  'at midnight': (0, _Part.midnight), '(?<=tomorrow |today )morning': (9, _Part.morning),
  '(?<=tomorrow |today )afternoon': (15, _Part.afternoon), '(?<=tomorrow |today )evening': (19, _Part.evening),
  '(?<=tomorrow |today )night': (23, _Part.night),
  // немецкий: «Guten Abend» — не напоминание
  'morgens': (9, _Part.morning), 'am morgen': (9, _Part.morning), 'mittags': (12, _Part.noon), 'am mittag': (12, _Part.noon),
  'nachmittags': (15, _Part.afternoon), 'am nachmittag': (15, _Part.afternoon), 'abends': (19, _Part.evening),
  'am abend': (19, _Part.evening), '(?<!guten |schonen )abend': (19, _Part.evening), 'nachts': (23, _Part.night),
  'in der nacht': (23, _Part.night), 'um mitternacht': (0, _Part.midnight),
  // испанский: «buenas noches» — не напоминание
  'por la manana': (9, _Part.morning), 'al mediodia': (12, _Part.noon), 'por la tarde': (16, _Part.evening),
  'por la noche': (21, _Part.evening), 'esta noche': (21, _Part.evening), 'a medianoche': (0, _Part.midnight),
  // польский
  'rano': (9, _Part.morning), 'w poludnie': (12, _Part.noon), 'po poludniu': (15, _Part.afternoon), 'wieczorem': (19, _Part.evening),
  'w nocy': (23, _Part.night), 'o polnocy': (0, _Part.midnight),
  // румынский: «bună seara» — не напоминание
  'dimineata': (9, _Part.morning), 'de dimineata': (9, _Part.morning), 'la pranz': (12, _Part.noon),
  'dupa-amiaza': (15, _Part.afternoon), 'dupa amiaza': (15, _Part.afternoon), '(?<!buna )seara': (19, _Part.evening),
  'diseara': (19, _Part.evening), 'asta-seara': (19, _Part.evening), 'noaptea': (23, _Part.night), 'la miezul noptii': (0, _Part.midnight),
};

final _dayPartPatterns = [for (final MapEntry(key: body, value: part) in _dayParts.entries) (_word(body), part)];

// слова после числа, с которыми оно — не час: «в 13 лет», «at 3 years», «um 2 mal»
final _notHour = RegExp(
  r'^\s*(лет|год|года|раз|раза|процент|%|штук|рубл|лей|долл|евро|км|кг|м\b|см|человек|этаж|класс|сери|сезон|минут|секунд|мес|недел|дн'
  r'|років|рік|роки|разів|рази|відсот|гривень|хвилин|тижн|днів'
  r'|years?|times?|percent|people|pieces|euros?|dollars?|minutes?|seconds?|months?|weeks?|days?|kg|km'
  r'|jahre?n?|mal|prozent|leute|personen|stuck|minuten|sekunden|monate?n?|wochen?|tage?n?'
  r'|anos|veces|por ciento|personas|minutos|segundos|meses|semanas|dias'
  r'|lat|razy|raz|procent|osob|zl|minut|sekund|miesiecy|tygodni|dni'
  r'|ani|ori|persoane|lei|minute|secunde|saptamani|zile)',
  unicode: true,
);

final _weekend = _word('на выходных|на вихідних|on the weekend|this weekend|at the weekend|am wochenende|el fin de semana|este fin de semana|w weekend|na weekend|in weekend|la sfarsit de saptamana');
final _afterWork = _word('после работы|після роботи|after work|nach der arbeit|despues del trabajo|po pracy|dupa munca|dupa serviciu|dupa lucru');

/// «На выходных» без часа — суббота в 10: утро выходного начинается позже будничного.
const _weekendHour = 10;

/// Конец рабочего дня по умолчанию для «после работы», в минутах от полуночи.
const defaultWorkEnd = 18 * 60;

enum _Unit { minute, hour, day, week, month }

const _units =
    'минуту|минуты|минут|мин|часа|часов|час|сутки|дня|дней|день|недели|неделю|недель|месяца|месяцев|месяц'
    '|хвилину|хвилини|хвилин|годину|години|годин|днів|дні|тиждень|тижні|тижнів|місяць|місяці|місяців'
    '|minutes?|mins?|hours?|days?|weeks?|months?'
    '|minuten?|stunden?|tagen?|tag|wochen?|monaten?|monat'
    '|minutos?|horas?|dias?|semanas?|meses|mes'
    '|minut[ey]?|godzin[ey]?|godzine|dni|dzien|tydzien|tygodni[ae]?|miesiac[ea]?|miesiecy'
    '|minute|ore|ora|zile|zi|saptamani|saptamana|luni|luna';

// «через 2 часа», «in 2 hours», «in 2 Stunden», «en 2 horas», «za 2 godziny», «peste 2 ore».
// Группы у всех одни: 1 — полчаса, 2 — число, 3 — единица
final _relatives = [
  RegExp(
    '$_before(?:(через\\s+(?:полчаса|пів\\s*години|півгодини)|in half an hour|in einer halben stunde|(?:en|dentro de) media hora|za pol godziny|(?:peste|in) (?:o )?jumatate de ora))$_after',
    unicode: true,
  ),
  // «через час», «za godzinę» — и без числа
  RegExp('$_before(?:(?:через|za)\\s+(?:(\\d+)\\s+)?($_units))$_after', unicode: true),
  // «in», «en», «peste» — только с числом: румынское «în zi» — «днём», а не «через день»
  RegExp('$_before(?:(?:in|en|dentro de|peste)\\s+(\\d+|an?|one|ein|eine|einer|einem|una?|uno|o)\\s+($_units))$_after', unicode: true),
];

/// «Через …» в тексте: где, сколько и чего. Без единицы — полчаса.
typedef _Relative = ({int start, int end, int count, _Unit? unit});

/// Первое «через …» в тексте: число и единица или полчаса.
_Relative? _findRelative(String text) {
  _Relative? best;
  for (final (index, pattern) in _relatives.indexed) {
    final match = pattern.firstMatch(text);
    if (match == null || (best != null && match.start >= best.start)) continue;
    best = switch (index) {
      0 => (start: match.start, end: match.end, count: 1, unit: null),
      // «an hour», «einer Stunde», «una hora» — один
      _ => (start: match.start, end: match.end, count: int.tryParse(match.group(1) ?? '1') ?? 1, unit: _unitOf(match.group(2)!)),
    };
  }
  return best;
}

_Unit _unitOf(String unit) {
  if (RegExp(r'^(мин|хвилин|min)').hasMatch(unit)) return _Unit.minute;
  if (RegExp(r'^(час|годин|hour|stund|hora|godzin|ora|ore)').hasMatch(unit)) return _Unit.hour;
  if (RegExp(r'^(недел|тиж|week|woch|semana|tydz|tygod|saptam)').hasMatch(unit)) return _Unit.week;
  if (RegExp(r'^(месяц|місяц|month|monat|mes|miesi|lun)').hasMatch(unit)) return _Unit.month;
  return _Unit.day;
}

class _Date {
  _Date(this.start, this.end, this.resolve, {this.hour = _morning, this.weak = false, this.world = false});
  final int start;
  final int end;

  /// Дата по времени суток: учитывает, прошёл ли уже этот момент.
  final DateTime Function(int hour, int minute) resolve;

  /// Час, если время не названо.
  final int hour;

  /// Слово в другом языке значит другое («Cuma» — и пятница, и имя): дата только рядом со временем.
  final bool weak;

  /// Найдена по таблицам CLDR: к ней цепляется чужая часть суток («domani sera»).
  final bool world;
}

class _Time {
  _Time(this.start, this.end, this.hour, this.minute, {this.workday = false, this.world = false, this.bare = false});
  final int start;
  final int end;
  final int hour;
  final int minute;

  /// «После работы»: без даты — только будний день.
  final bool workday;

  /// Найдено по таблицам CLDR.
  final bool world;

  /// Час без части суток: «à 9h» уточнит «du soir».
  final bool bare;
}

/// Первое напоминание в тексте или null. Понимает «23 декабря 13:00», «завтра в 10»,
/// «в пятницу», «через 2 часа», «сегодня вечером», «12.11 в 9», «на выходных», «после работы»
/// и то же на шести других языках. [workEnd] — конец рабочего дня в минутах от полуночи.
ReminderMatch? parseReminder(String text, DateTime now, {int workEnd = defaultWorkEnd}) {
  // знаки над буквами и регистр сняты, цифры других письменностей обычные, длина та же:
  // места кусков совпадают с текстом
  final lower = _plain(foldText(text));
  // текст на своём языке чужие таблицы не смотрят: «mañana será» — не «завтра вечером» по-итальянски
  final world = !ownLanguages.contains(guessLanguage(text));

  final relatives = [_findRelative(lower), if (world) _worldRelative(lower)].nonNulls.toList()..sort((a, b) => a.start.compareTo(b.start));
  if (relatives.firstOrNull case final relative?) {
    return ReminderMatch(start: relative.start, end: relative.end, at: _relativeMoment(relative.count, relative.unit, now), hasTime: true);
  }

  final dates = _dates(lower, now);
  if (world) dates.addAll(_worldDates(lower, now, dates));
  dates.sort((a, b) => a.start.compareTo(b.start));
  final times = _times(lower, workEnd);
  if (world) times.addAll(_worldTimes(lower, dates, times));
  times.sort((a, b) => a.start.compareTo(b.start));
  // «Cuma» без времени — скорее имя, чем пятница
  if (times.isEmpty) dates.removeWhere((date) => date.weak);

  if (dates.isNotEmpty) {
    final date = dates.first;
    final time = times.where((time) => _adjacent(lower, date, time)).firstOrNull;
    if (time != null) {
      return ReminderMatch(
        start: date.start < time.start ? date.start : time.start,
        end: date.end > time.end ? date.end : time.end,
        at: date.resolve(time.hour, time.minute),
        hasTime: true,
      );
    }
    // время в другом конце строки: «завтра военная кафедра в 14:00»
    final apart = times.firstOrNull;
    if (apart != null) {
      final parts = [(date.start, date.end), (apart.start, apart.end)]..sort((a, b) => a.$1.compareTo(b.$1));
      return ReminderMatch(start: parts.first.$1, end: parts.last.$2, parts: parts, at: date.resolve(apart.hour, apart.minute), hasTime: true);
    }
    return ReminderMatch(start: date.start, end: date.end, at: date.resolve(date.hour, 0), hasTime: false);
  }

  final time = times.firstOrNull;
  if (time != null) {
    var day = 0;
    DateTime moment() => DateTime(now.year, now.month, now.day + day, time.hour, time.minute);
    // прошло — завтра; «после работы» в субботу и воскресенье не бывает
    while (!moment().isAfter(now) || (time.workday && moment().weekday > DateTime.friday)) {
      day++;
    }
    return ReminderMatch(start: time.start, end: time.end, at: moment(), hasTime: true);
  }
  return null;
}

/// Собрать выражения всех таблиц заранее: первый разбор с ними занимает ~0,1 с.
void warmUpReminders() => parseReminder('demain à 9h du soir, 明日の午後3時, 23 décembre', DateTime.now());

/// Как дата и время написаны в тексте, без регистра; нет — null. По нему видно, трогали ли время, правя заметку.
String? reminderPhrase(String text, DateTime now, {int workEnd = defaultWorkEnd}) {
  final found = parseReminder(text, now, workEnd: workEnd);
  return found == null ? null : _phrase(text, found);
}

// куски даты и времени как написаны, без регистра: «Завтра в 10» и «завтра в 10» — одно
String _phrase(String text, ReminderMatch match) => [for (final (from, to) in match.parts) text.substring(from, to).toLowerCase()].join(' ');

// между датой и временем только пробелы и запятые: «23 декабря, 13:00»
bool _adjacent(String text, _Date date, _Time time) {
  final String gap;
  if (date.end <= time.start) {
    gap = text.substring(date.end, time.start);
  } else if (time.end <= date.start) {
    gap = text.substring(time.end, date.start);
  } else {
    return false;
  }
  return RegExp(r'^[\s,]{0,3}$').hasMatch(gap);
}

DateTime _relativeMoment(int count, _Unit? unit, DateTime now) {
  if (unit == null) return now.add(const Duration(minutes: 30));
  return switch (unit) {
    _Unit.minute => now.add(Duration(minutes: count)),
    _Unit.hour => now.add(Duration(hours: count)),
    // дни и недели считаются по календарю, напоминание на утро
    _Unit.day => DateTime(now.year, now.month, now.day + count, _morning),
    _Unit.week => DateTime(now.year, now.month, now.day + 7 * count, _morning),
    _Unit.month => DateTime(now.year, now.month + count, now.day, _morning),
  };
}

List<_Date> _dates(String text, DateTime now) {
  final dates = <_Date>[];

  for (final (pattern, shift) in _dayWords) {
    for (final match in pattern.allMatches(text)) {
      dates.add(_Date(match.start, match.end, (hour, minute) => DateTime(now.year, now.month, now.day + shift, hour, minute)));
    }
  }

  for (final match in _weekday.allMatches(text)) {
    final name = (match.group(1) ?? match.group(2)!).replaceAll(RegExp('[ʼ\'’]'), '');
    final target = _weekdayNames[name];
    if (target == null) continue;
    dates.add(_Date(match.start, match.end, _weekdayMoment(target, now)));
  }

  // суббота, а если её время прошло — воскресенье, прошло и оно — следующая суббота
  for (final match in _weekend.allMatches(text)) {
    dates.add(
      _Date(match.start, match.end, hour: _weekendHour, (hour, minute) {
        final toSaturday = (DateTime.saturday - now.weekday + 7) % 7;
        final saturday = now.weekday == DateTime.sunday ? -1 : toSaturday;
        for (final shift in [saturday, saturday + 1, saturday + 7]) {
          final at = DateTime(now.year, now.month, now.day + shift, hour, minute);
          if (at.isAfter(now)) return at;
        }
        return DateTime(now.year, now.month, now.day + saturday + 7, hour, minute);
      }),
    );
  }

  for (final match in _monthDate.allMatches(text)) {
    final month = _months.firstWhere((entry) => entry.$1 == match.group(2)).$2;
    final date = _calendarDate(match, int.parse(match.group(1)!), month, int.tryParse(match.group(3) ?? ''), now);
    if (date != null) dates.add(date);
  }

  for (final match in _monthFirst.allMatches(text)) {
    final month = _months.firstWhere((entry) => entry.$1 == match.group(1)).$2;
    final date = _calendarDate(match, int.parse(match.group(2)!), month, int.tryParse(match.group(3) ?? ''), now);
    if (date != null) dates.add(date);
  }

  for (final match in _dotDate.allMatches(text)) {
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final rawYear = match.group(3);
    final year = rawYear == null ? null : (rawYear.length == 2 ? 2000 + int.parse(rawYear) : int.parse(rawYear));
    final date = _calendarDate(match, day, month, year, now);
    if (date != null) dates.add(date);
  }
  return dates;
}

/// Ближайший такой день недели; сегодняшний, если его час ещё не прошёл.
DateTime Function(int hour, int minute) _weekdayMoment(int target, DateTime now) => (hour, minute) {
  final ahead = (target - now.weekday + 7) % 7;
  final at = DateTime(now.year, now.month, now.day + ahead, hour, minute);
  return at.isAfter(now) ? at : DateTime(now.year, now.month, now.day + ahead + 7, hour, minute);
};

_Date? _calendarDate(RegExpMatch match, int day, int month, int? year, DateTime now) {
  if (month < 1 || month > 12 || day < 1 || day > DateTime(2024, month + 1, 0).day) return null;
  return _Date(match.start, match.end, (hour, minute) {
    final at = DateTime(year ?? now.year, month, day, hour, minute);
    // без года прошедшая дата значит следующий год
    if (year == null && at.isBefore(now)) return DateTime(now.year + 1, month, day, hour, minute);
    return at;
  });
}

// перед слабым предлогом число: «5 o 6 manzanas», «de la 5 la 6»
bool _afterNumber(String text, int start) => RegExp(r'\d\s*$').hasMatch(text.substring(0, start));

List<_Time> _times(String text, int workEnd) {
  final times = <_Time>[
    for (final match in _afterWork.allMatches(text)) _Time(match.start, match.end, workEnd ~/ 60, workEnd % 60, workday: true),
  ];
  for (final match in _clock.allMatches(text)) {
    final prep = match.group(1);
    var hour = int.parse(match.group(2)!);
    final minute = int.parse(match.group(3)!);
    // «в 9.30» — время, а «12.11» без предлога уже забрала дата
    final dotted = !match.group(0)!.contains(':');
    if (dotted && prep == null) continue;
    if (hour > 23 || minute > 59) continue;
    if (prep != null && _weakPrep.contains(prep) && _afterNumber(text, match.start)) continue;
    final meridiem = match.group(4);
    if (meridiem != null) hour = _hourOfPart(hour, meridiem.startsWith('p') ? _Part.pm : _Part.am);
    times.add(_Time(match.start, match.end, hour, minute));
  }
  // часы без части суток: «вечером в 6» их уточнит
  final bare = <_Time>[];
  for (final match in _hour.allMatches(text)) {
    final prep = match.group(1);
    final hour = int.parse(match.group(2)!);
    final hourWord = match.group(3);
    final qualifier = match.group(4);
    if (hour > 23) continue;
    // без предлога число — час только с «Uhr», «o'clock» или частью суток: «9 pm», «6 вечера»
    if (prep == null && qualifier == null && (hourWord == null || hourWord.startsWith('час') || hourWord.startsWith('годин') || hourWord.startsWith('hora'))) continue;
    if (qualifier == null && hourWord == null && _notHour.hasMatch(text.substring(match.end))) continue;
    if (times.any((time) => time.start <= match.start && match.start < time.end)) continue;
    if (prep != null && _weakPrep.contains(prep) && _afterNumber(text, match.start)) continue;
    final time = _Time(match.start, match.end, qualifier == null ? hour : _hourOfPart(hour, _qualifiers[qualifier]!), 0);
    times.add(time);
    if (qualifier == null) bare.add(time);
  }
  for (final (pattern, (partHour, part)) in _dayPartPatterns) {
    for (final match in pattern.allMatches(text)) {
      if (times.any((time) => time.start <= match.start && match.start < time.end)) continue;
      final near = bare.where((time) => _touching(text, match.start, match.end, time)).firstOrNull;
      if (near == null) {
        times.add(_Time(match.start, match.end, partHour, 0));
        continue;
      }
      // «вечером в 6» и «в 6 вечером» — один кусок, час с поправкой на вечер
      times.remove(near);
      bare.remove(near);
      final start = match.start < near.start ? match.start : near.start;
      final end = match.end > near.end ? match.end : near.end;
      times.add(_Time(start, end, _hourOfPart(near.hour, part), 0));
    }
  }
  return times;
}

/// Час с частью суток: «6 вечера» — 18, «3 дня» — 15, «12 ночи» — 0, «12 am» — 0.
int _hourOfPart(int hour, _Part part) {
  switch (part) {
    case _Part.day:
      return hour <= 5 ? hour + 12 : hour;
    case _Part.afternoon || _Part.evening || _Part.pm:
      return hour < 12 ? hour + 12 : hour;
    case _Part.night:
      if (hour == 12) return 0;
      return hour >= 6 && hour < 12 ? hour + 12 : hour;
    case _Part.am:
      return hour == 12 ? 0 : hour;
    case _Part.morning || _Part.noon || _Part.midnight:
      return hour;
  }
}

// часть суток и час рядом, между ними только пробелы и запятая
bool _touching(String text, int start, int end, _Time time) {
  final gap = end <= time.start ? text.substring(end, time.start) : (time.end <= start ? text.substring(time.end, start) : null);
  return gap != null && RegExp(r'^[\s,]{0,3}$').hasMatch(gap);
}
