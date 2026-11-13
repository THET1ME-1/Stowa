part of 'reminder_parser.dart';

// Время на языках без своих таблиц: слова — из Unicode CLDR (cldr_time_words.dart), здесь —
// как их искать в тексте и чего CLDR не знает («alle 9», «saat 9», «ce soir», «9h»).
// Чужие слова строже своих: день, совпавший с обычным словом другого языка, — только рядом
// со временем, предлог перед часом — только при дате, часть суток — только рядом с днём или часом.

// буквы, которые часто пишут без знаков, а в таблице они со знаками: «yarin» — это «yarın»;
// в foldText их нет, потому что поиск сверяется с индексом, который их не снимает
const _plainLetters = {
  'ı': 'i', 'ğ': 'g', 'č': 'c', 'ř': 'r', 'ě': 'e', 'š': 's', 'ž': 'z', 'ů': 'u', 'ő': 'o', 'ű': 'u',
  'å': 'a', 'ø': 'o', 'ā': 'a', 'ē': 'e', 'ī': 'i', 'ū': 'u', 'ė': 'e', 'į': 'i', 'ų': 'u', 'ķ': 'k',
  'ļ': 'l', 'ņ': 'n', 'ģ': 'g', 'đ': 'd', '’': "'", 'ʼ': "'", '`': "'",
};

// начала десятков цифр других письменностей: арабские, персидские, деванагари, бенгальские, тайские, широкие
const _digitBlocks = [0x660, 0x6F0, 0x966, 0x9E6, 0xE50, 0xFF10];

/// Текст для сверки: буквы выше без знаков, цифры обычные. Длина та же.
String _plain(String folded) {
  final out = StringBuffer();
  for (final code in folded.codeUnits) {
    final block = _digitBlocks.where((start) => code >= start && code < start + 10).firstOrNull;
    if (block != null) {
      out.writeCharCode(0x30 + code - block);
      continue;
    }
    final char = String.fromCharCode(code);
    out.write(_plainLetters[char] ?? char);
  }
  return out.toString();
}

// огласовки арабского письма: в CLDR «غدًا», а пишут «غدا»
final _harakat = RegExp('[ً-ٰٟ]');

/// Слово таблицы в том виде, в каком его сверяют: как текст, пробелы и дефисы — один пробел.
String _keyOf(String word) => _plain(foldText(word)).replaceAll(_harakat, '').replaceAll(RegExp(r"[\s\-]+"), ' ').trim();

// письменности без пробелов между словами (и корейский с его окончаниями): границы слова там нет
final _joined = RegExp('[぀-ヿ㐀-鿿가-힯฀-໿က-႟ក-៿]');

const _edge = r'\p{L}\p{M}\p{N}';

/// Слово таблицы в выражении: пробел или дефис между частями.
String _alternative(String key) => key.split(' ').map(RegExp.escape).join(r'[\s\-]+');

/// Слова одним выражением: граница слова одна на всех, а не у каждого из тысячи —
/// так выражение собирается за миллисекунды. Китайскому и тайскому границы не нужны.
String _alternatives(Iterable<String> keys, {bool before = true, bool after = true}) {
  final spaced = [for (final key in keys) if (!_joined.hasMatch(key)) _alternative(key)];
  final joined = [for (final key in keys) if (_joined.hasMatch(key)) _alternative(key)];
  return [
    if (spaced.isNotEmpty) '${before ? '(?<![$_edge])' : ''}(?:${spaced.join('|')})${after ? '(?![\\p{L}\\p{M}])' : ''}',
    if (joined.isNotEmpty) '(?:${joined.join('|')})',
  ].join('|');
}

/// Слова одной таблицы: само выражение и значение каждого слова.
class _Words {
  _Words(Map<String, int> words, {bool Function(String key)? known, bool before = true, bool after = true}) {
    for (final MapEntry(:key, :value) in words.entries) {
      final word = _keyOf(key);
      if (word.isEmpty || (known?.call(word) ?? false)) continue;
      values[word] = value;
    }
    // длинные раньше коротких: «après-demain» не «demain»
    final keys = values.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    body = _alternatives(keys, before: before, after: after);
    pattern = RegExp('(?:$body)${after ? '(?![\\p{N}])' : ''}', unicode: true);
  }

  final values = <String, int>{};
  late final String body;
  late final RegExp pattern;

  int? valueOf(String matched) => values[_keyOf(matched)];

  Iterable<(RegExpMatch, int)> find(String text) sync* {
    for (final match in pattern.allMatches(text)) {
      if (valueOf(match.group(0)!) case final value?) yield (match, value);
    }
  }
}

// своя таблица уже знает это слово целиком: голландское «morgen» найдёт немецкая строка
bool _whole(RegExp pattern, String key) {
  final match = pattern.firstMatch(key);
  return match != null && match.start == 0 && match.end == key.length;
}

final _worldDays = _Words(cldrDayWords, known: (key) => _dayWords.any((entry) => _whole(entry.$1, key)));
final _worldWeekdays = _Words(cldrWeekdays, known: (key) => _weekdayNames.containsKey(key) || _whole(_weekday, key));
final _worldMonths = _Words(cldrMonths, known: (key) => _months.any((month) => month.$1 == key));
final _worldWeak = {for (final word in cldrWeakWords) _keyOf(word)};

// «23 décembre», «décembre 23», «23. prosince»
final _worldMonthDay = RegExp('(?<![$_edge])(\\d{1,2})\\.?\\s*(?:de\\s+|d\'|di\\s+)?(${_worldMonths.body})', unicode: true);
final _worldMonthFirst = RegExp('(${_worldMonths.body})\\s+(\\d{1,2})\\.?(?![\\p{N}])', unicode: true);

// «12月23日», «12월 23일»: месяц числом у китайского, японского, корейского
final _eastDate = RegExp(r'(\d{1,2})\s*[月월]\s*(\d{1,2})\s*[日号號일]');

List<_Date> _worldDates(String text, DateTime now, List<_Date> own) {
  final dates = <_Date>[];
  bool taken(int start, int end) => [...own, ...dates].any((date) => start < date.end && date.start < end);
  void add(_Date date) {
    if (!taken(date.start, date.end)) dates.add(date);
  }

  for (final (match, shift) in _worldDays.find(text)) {
    add(
      _Date(match.start, match.end, (hour, minute) => DateTime(now.year, now.month, now.day + shift, hour, minute),
          weak: _worldWeak.contains(_keyOf(match.group(0)!)), world: true),
    );
  }
  for (final (match, target) in _worldWeekdays.find(text)) {
    add(_Date(match.start, match.end, _weekdayMoment(target, now), weak: _worldWeak.contains(_keyOf(match.group(0)!)), world: true));
  }
  for (final match in _worldMonthDay.allMatches(text)) {
    final month = _worldMonths.valueOf(match.group(2)!);
    if (month == null) continue;
    if (_calendarDate(match, int.parse(match.group(1)!), month, null, now) case final date?) add(_Date(date.start, date.end, date.resolve, world: true));
  }
  for (final match in _worldMonthFirst.allMatches(text)) {
    final month = _worldMonths.valueOf(match.group(1)!);
    if (month == null) continue;
    if (_calendarDate(match, int.parse(match.group(2)!), month, null, now) case final date?) add(_Date(date.start, date.end, date.resolve, world: true));
  }
  for (final match in _eastDate.allMatches(text)) {
    if (_calendarDate(match, int.parse(match.group(2)!), int.parse(match.group(1)!), null, now) case final date?) {
      add(_Date(date.start, date.end, date.resolve, world: true));
    }
  }
  return dates;
}

// «через сколько» по единицам: шаблон с {0} — число, с #N — число словом («ymhen awr»)
final _worldRelatives = [
  for (final unit in _Unit.values)
    (
      unit,
      _Words({
        for (final MapEntry(:key, :value) in cldrRelative.entries)
          if (value == unit.index && key.contains('#')) key.split('#').first: int.parse(key.split('#').last),
      }),
      _relativePattern([
        for (final MapEntry(:key, :value) in cldrRelative.entries)
          if (value == unit.index && key.contains('{0}')) key,
      ]),
    ),
];

// «dans {0} heures» → «dans\s*(\d+)\s*heures», «{0}小时后» → «(\d+)\s*小时后»; число — одна группа на всех
RegExp _relativePattern(List<String> patterns) {
  String body(String pattern) => [
    for (final part in pattern.split('{0}')) _keyOf(part).split(' ').where((piece) => piece.isNotEmpty).map(RegExp.escape).join(r'[\s\-]*'),
  ].join(r'\s*(\d+)\s*');
  final spaced = [for (final pattern in patterns) if (!_joined.hasMatch(pattern)) body(pattern)];
  final joined = [for (final pattern in patterns) if (_joined.hasMatch(pattern)) body(pattern)];
  return RegExp('(?<![$_edge])(?:${spaced.join('|')})(?![\\p{L}\\p{M}])|(?:${joined.join('|')})', unicode: true);
}

_Relative? _worldRelative(String text) {
  _Relative? best;
  for (final (unit, fixed, pattern) in _worldRelatives) {
    for (final (match, count) in fixed.find(text)) {
      if (best == null || match.start < best.start) best = (start: match.start, end: match.end, count: count, unit: unit);
    }
    final match = pattern.firstMatch(text);
    if (match == null || (best != null && match.start >= best.start)) continue;
    final number = [for (var group = 1; group <= match.groupCount; group++) match.group(group)].nonNulls.firstOrNull;
    best = (start: match.start, end: match.end, count: int.tryParse(number ?? '1') ?? 1, unit: unit);
  }
  return best;
}

// предлоги перед часом, которых нет в CLDR: «alle 9», «saat 9», «jam 9», «στις 9», «الساعة 9»
const _moreAtWords = {'alle', 'vers', 'pelas', 'saat', 'klockan', 'kello', 'klokka', 'v', 've', 'jam', 'στις', 'στη', 'الساعة', 'בשעה', 'ساعت'};

// слова и знаки часа после числа: «9h», «9 uur», «9 óra», «3点»
const _moreHourMarks = {'h', 'uur', 'ora', 'heures', 'heure', 'hodin', 'hodiny', 'hod', '点', '點', '時', 'giờ', 'saat'};

// части суток с «этим»: CLDR их не знает, а пишут их чаще всего
const _worldPhrases = {
  'ce soir': 19, 'ce matin': 9, 'cet après-midi': 15, 'cette nuit': 23,
  'stasera': 19, 'stamattina': 9, 'stamani': 9, 'stanotte': 23, 'oggi pomeriggio': 15,
  'esta noite': 21, 'hoje à noite': 21, 'esta tarde': 16,
  'bu akşam': 19, 'bu sabah': 9, 'bu gece': 23,
  'vanavond': 19, 'vanmorgen': 9, 'vanmiddag': 15, 'vannacht': 23,
  'ikväll': 19, 'i kväll': 19, 'i kveld': 19, 'i aften': 19, 'tänään illalla': 19,
  'ma este': 19, 'ma reggel': 9, 'malam ini': 19, 'nanti malam': 19, 'tối nay': 19,
  '今晚': 19, '今夜': 19, '今晩': 19, '오늘 밤': 19, 'απόψε': 19, 'आज रात': 21,
};

final _phraseWords = _Words(_worldPhrases);

final _periodMarks = _Words({...cldrPeriodMarks, 'am': _Part.am.index, 'pm': _Part.pm.index});

// перед часом — «午後3時», «akşam 9», но не «am 13 ani» по-румынски: короткие латинские только после
final _periodMarksBefore = _Words({
  for (final MapEntry(:key, :value) in cldrPeriodMarks.entries)
    if (!RegExp('[a-z]').hasMatch(_keyOf(key)) || _keyOf(key).replaceAll(RegExp(r'[\s.]'), '').length >= 4) key: value,
});
final _atWords = _Words({for (final word in {...cldrAtWords, ..._moreAtWords}) word: 0}, after: false);
final _hourMarks = _Words({for (final word in {...cldrHourMarks, ..._moreHourMarks}) word: 0}, before: false);
final _periods = _Words(
  {for (final MapEntry(:key, :value) in cldrPeriods.entries) key: value.$1 * 100 + value.$2},
  known: (key) => _dayPartPatterns.any((entry) => _whole(entry.$1, key)),
);

// час с частью суток до или после, предлогом, знаком часа и минутами: «à 9h30 du soir», «午後3時», «saat 9»
final _worldHour = RegExp(
  '(?:(${_periodMarksBefore.body})\\s*)?(?:(${_atWords.body})\\.?\\s*)?(?<![\\p{N}:.])(\\d{1,2})'
  '(?:\\s*(${_hourMarks.body})\\.?(?:\\s*(\\d{2})(?![\\p{N}])\\s*(?:分|분|phút)?)?)?(?![\\p{N}:])'
  '(?:\\s*(${_periodMarks.body}))?',
  unicode: true,
);

// между днём и частью суток пробел, запятая или одно короткое слово: «amanhã de manhã»
bool _near(String text, int start, int end, int otherStart, int otherEnd) {
  final gap = end <= otherStart ? text.substring(end, otherStart) : (otherEnd <= start ? text.substring(otherEnd, start) : null);
  return gap != null && RegExp(r'^[\s,]*(?:\S{1,3}\s+)?$').hasMatch(gap);
}

List<_Time> _worldTimes(String text, List<_Date> dates, List<_Time> own) {
  final times = <_Time>[];
  bool taken(int start, int end) => [...own, ...times].any((time) => start < time.end && time.start < end);

  for (final (match, hour) in _phraseWords.find(text)) {
    if (!taken(match.start, match.end)) times.add(_Time(match.start, match.end, hour, 0, world: true));
  }

  for (final match in _worldHour.allMatches(text)) {
    final before = match.group(1);
    final at = match.group(2);
    final mark = match.group(4);
    final after = match.group(6);
    final qualifier = after ?? before;
    if (qualifier == null && mark == null && at == null) continue;
    // один предлог без знака часа — час только при дате: «à 9 personnes» — не время
    if (qualifier == null && mark == null && (dates.isEmpty || _afterNumber(text, match.start))) continue;
    var hour = int.parse(match.group(3)!);
    final minute = int.tryParse(match.group(5) ?? '') ?? 0;
    if (hour > 23 || minute > 59) continue;
    if (qualifier != null) hour = _hourOfPart(hour, _Part.values[_periodMarks.valueOf(qualifier)!]);
    if (taken(match.start, match.end)) continue;
    times.add(_Time(match.start, match.end, hour, minute, world: true, bare: qualifier == null));
  }

  // «domani sera», «yarın akşam»: часть суток рядом с чужим днём или чужим часом
  for (final (match, value) in _periods.find(text)) {
    if (taken(match.start, match.end)) continue;
    final part = _Part.values[value ~/ 100];
    final hour = value % 100;
    final near = times.where((time) => time.bare && _near(text, match.start, match.end, time.start, time.end)).firstOrNull;
    if (near != null) {
      times.remove(near);
      times.add(_Time(near.start < match.start ? near.start : match.start, near.end > match.end ? near.end : match.end, _hourOfPart(near.hour, part), near.minute, world: true));
      continue;
    }
    if (dates.any((date) => date.world && _near(text, match.start, match.end, date.start, date.end))) {
      times.add(_Time(match.start, match.end, hour, 0, world: true));
    }
  }
  return times;
}
