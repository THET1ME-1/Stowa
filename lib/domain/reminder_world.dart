part of 'reminder_parser.dart';

// Время на языках без своих таблиц: слова — из Unicode CLDR (cldr_time_words.dart), здесь —
// как их искать в тексте и чего CLDR не знает («alle 9», «saat 9», «ce soir», «9h»).
// Чужие слова строже своих: день, совпавший с обычным словом другого языка, — только рядом
// со временем, предлог перед часом — только при дате, часть суток — только рядом с днём или часом.
//
// Таблицы — тысячи слов, поэтому они ищутся не одним выражением (оно проверялось бы на каждой
// букве: 40 000 знаков — 150 мс), а словарём по словам текста: время растёт с числом слов.

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
    final block = code < 0x660 ? null : _digitBlocks.where((start) => code >= start && code < start + 10).firstOrNull;
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

// письменности без пробелов между словами (и корейский с окончаниями, прилипшими к слову):
// там слова ищутся как куски текста, без границ
final _joined = RegExp('[぀-ヿ㐀-鿿가-힯฀-໿က-႟ក-៿]');

final _letter = RegExp(r'[\p{L}\p{M}]', unicode: true);
final _tokenPattern = RegExp(r'[\p{L}\p{M}]+|\d+', unicode: true);

bool _isLetter(String text, int index) => index >= 0 && index < text.length && _letter.hasMatch(text[index]);
bool _isDigit(String text, int index) => index >= 0 && index < text.length && text.codeUnitAt(index) ^ 0x30 <= 9;
bool _isGap(String char) => char == ' ' || char == '-' || char == '\t' || char == '\n' || char == ' ' || char == ' ';

int _skipSpaces(String text, int at) {
  var index = at;
  while (index < text.length && _isGap(text[index]) && text[index] != '-') {
    index++;
  }
  return index;
}

int _skipSpacesBack(String text, int at) {
  var index = at;
  while (index > 0 && _isGap(text[index - 1]) && text[index - 1] != '-') {
    index--;
  }
  return index;
}

/// Слово таблицы с [from]: конец куска или null. Пробел в слове — любые пробелы или дефис в тексте.
int? _wordsAt(String text, int from, String key) {
  var index = from;
  for (var at = 0; at < key.length; at++) {
    if (key[at] == ' ') {
      if (index >= text.length || !_isGap(text[index])) return null;
      while (index < text.length && _isGap(text[index])) {
        index++;
      }
      continue;
    }
    if (index >= text.length || text[index] != key[at]) return null;
    index++;
  }
  return index;
}

/// Слово таблицы, которое кончается на [to]: начало куска или null.
int? _wordsBefore(String text, int to, String key) {
  var index = to;
  for (var at = key.length - 1; at >= 0; at--) {
    if (key[at] == ' ') {
      if (index <= 0 || !_isGap(text[index - 1])) return null;
      while (index > 0 && _isGap(text[index - 1])) {
        index--;
      }
      continue;
    }
    if (index <= 0 || text[index - 1] != key[at]) return null;
    index--;
  }
  return index;
}

/// Текст и его слова: где какое начинается и кончается.
class _Text {
  _Text(this.text) : joined = _joined.hasMatch(text) {
    for (final match in _tokenPattern.allMatches(text)) {
      final token = (start: match.start, end: match.end, word: match.group(0)!);
      tokens.add(token);
      byStart[match.start] = token;
      byEnd[match.end] = token;
    }
  }

  final String text;
  final bool joined;
  final tokens = <({int start, int end, String word})>[];
  final byStart = <int, ({int start, int end, String word})>{};
  final byEnd = <int, ({int start, int end, String word})>{};
}

typedef _Hit = ({int start, int end, int value, String key});

// первое и последнее слово ключа: по ним ключ находится в тексте
String _firstToken(String key) => _tokenPattern.firstMatch(key)?.group(0) ?? '';
String _lastToken(String key) => _tokenPattern.allMatches(key).lastOrNull?.group(0) ?? '';

/// Слова одной таблицы: значение каждого и указатели по первому и последнему слову.
class _Lexicon {
  _Lexicon(Map<String, int> words, {bool Function(String key)? known}) {
    for (final MapEntry(:key, :value) in words.entries) {
      final word = _keyOf(key);
      if (word.isEmpty || (known?.call(word) ?? false)) continue;
      values[word] = value;
    }
    // длинные раньше коротких: «après-demain» не «demain»
    final keys = values.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      if (_joined.hasMatch(key)) {
        joined.add(key);
      } else {
        byFirst.putIfAbsent(_firstToken(key), () => []).add(key);
        byLast.putIfAbsent(_lastToken(key), () => []).add(key);
      }
    }
  }

  final values = <String, int>{};
  final byFirst = <String, List<String>>{};
  final byLast = <String, List<String>>{};
  final joined = <String>[];

  // граница слова: буква с буквой не слипается; знак часа после цифры («9h») — можно
  bool _bounded(String text, int start, int end, String key) {
    if (_isLetter(key, 0) && _isLetter(text, start - 1)) return false;
    if (_isLetter(key, key.length - 1) && _isLetter(text, end)) return false;
    return true;
  }

  /// Все вхождения слов таблицы, без наложений: длинное раньше короткого.
  List<_Hit> hits(_Text text) {
    final found = <_Hit>[];
    for (final token in text.tokens) {
      for (final key in byFirst[token.word] ?? const <String>[]) {
        final start = token.start - key.indexOf(token.word);
        if (start < 0) continue;
        final end = _wordsAt(text.text, start, key);
        if (end != null && _bounded(text.text, start, end, key)) {
          found.add((start: start, end: end, value: values[key]!, key: key));
          break;
        }
      }
    }
    if (text.joined) {
      for (final key in joined) {
        for (var at = text.text.indexOf(key); at >= 0; at = text.text.indexOf(key, at + key.length)) {
          found.add((start: at, end: at + key.length, value: values[key]!, key: key));
        }
      }
    }
    found.sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : b.end.compareTo(a.end));
    final kept = <_Hit>[];
    for (final hit in found) {
      if (kept.isEmpty || hit.start >= kept.last.end) kept.add(hit);
    }
    return kept;
  }

  /// Слово таблицы ровно с [from].
  _Hit? at(_Text text, int from) {
    if (text.joined) {
      for (final key in joined) {
        if (text.text.startsWith(key, from)) return (start: from, end: from + key.length, value: values[key]!, key: key);
      }
    }
    final token = text.byStart[from] ?? (from < text.text.length ? text.byStart[from + 1] : null);
    if (token == null) return null;
    for (final key in byFirst[token.word] ?? const <String>[]) {
      if (token.start - key.indexOf(token.word) != from) continue;
      final end = _wordsAt(text.text, from, key);
      if (end != null && _bounded(text.text, from, end, key)) return (start: from, end: end, value: values[key]!, key: key);
    }
    return null;
  }

  /// Слово таблицы, которое кончается ровно на [to].
  _Hit? before(_Text text, int to) {
    if (text.joined) {
      for (final key in joined) {
        if (to >= key.length && text.text.startsWith(key, to - key.length)) return (start: to - key.length, end: to, value: values[key]!, key: key);
      }
    }
    final token = text.byEnd[to];
    if (token == null) return null;
    for (final key in byLast[token.word] ?? const <String>[]) {
      final start = _wordsBefore(text.text, to, key);
      if (start != null && _bounded(text.text, start, to, key)) return (start: start, end: to, value: values[key]!, key: key);
    }
    return null;
  }
}

// своя таблица уже знает это слово целиком: голландское «morgen» найдёт немецкая строка
bool _whole(RegExp pattern, String key) {
  final match = pattern.firstMatch(key);
  return match != null && match.start == 0 && match.end == key.length;
}

final _worldDays = _Lexicon(cldrDayWords, known: (key) => _dayWords.any((entry) => _whole(entry.$1, key)));
final _worldWeekdays = _Lexicon(cldrWeekdays, known: (key) => _weekdayNames.containsKey(key) || _whole(_weekday, key));
final _worldMonths = _Lexicon(cldrMonths, known: (key) => _months.any((month) => month.$1 == key));
final _worldWeak = {for (final word in cldrWeakWords) _keyOf(word)};

// «12月23日», «12월 23일»: месяц числом у китайского, японского, корейского
final _eastDate = RegExp(r'(\d{1,2})\s*[月월]\s*(\d{1,2})\s*[日号號일]');

// между числом и месяцем: «23 de março», «23. prosince», «23 d'abril»
const _monthLinks = {'de', 'di', 'of', 'd'};

/// Число в 1–2 цифры, которое кончается на [to] или начинается с [from].
int? _numberBefore(_Text text, int to) {
  final token = text.byEnd[to];
  if (token == null || token.word.length > 2 || !_isDigit(token.word, 0)) return null;
  return int.parse(token.word);
}

List<_Date> _worldDates(_Text text, DateTime now, List<_Date> own) {
  final lower = text.text;
  final dates = <_Date>[];
  bool taken(int start, int end) => [...own, ...dates].any((date) => start < date.end && date.start < end);
  void add(_Date date) {
    if (!taken(date.start, date.end)) dates.add(date);
  }

  for (final hit in _worldDays.hits(text)) {
    final shift = hit.value;
    add(_Date(hit.start, hit.end, (hour, minute) => DateTime(now.year, now.month, now.day + shift, hour, minute), weak: _worldWeak.contains(hit.key), world: true));
  }
  for (final hit in _worldWeekdays.hits(text)) {
    add(_Date(hit.start, hit.end, _weekdayMoment(hit.value, now), weak: _worldWeak.contains(hit.key), world: true));
  }
  for (final hit in _worldMonths.hits(text)) {
    // «23 décembre»: перед месяцем число, между ними пробел, точка или «de»
    var at = _skipSpacesBack(lower, hit.start);
    final link = text.byEnd[at];
    if (link != null && _monthLinks.contains(link.word)) at = _skipSpacesBack(lower, link.start);
    if (at > 0 && (lower[at - 1] == '.' || lower[at - 1] == "'")) at--;
    var day = _numberBefore(text, at);
    var start = day == null ? hit.start : text.byEnd[at]!.start;
    var end = hit.end;
    // «décembre 23», «december 23.»
    if (day == null) {
      final after = text.byStart[_skipSpaces(lower, hit.end)];
      if (after != null && after.word.length <= 2 && _isDigit(after.word, 0) && !_isDigit(lower, after.end)) {
        day = int.parse(after.word);
        start = hit.start;
        end = after.end;
      }
    }
    if (day == null) continue;
    if (_calendarDate(start, end, day, hit.value, null, now, world: true) case final date?) add(date);
  }
  if (lower.contains('月') || lower.contains('월')) {
    for (final match in _eastDate.allMatches(lower)) {
      if (_calendarDate(match.start, match.end, int.parse(match.group(2)!), int.parse(match.group(1)!), null, now, world: true) case final date?) add(date);
    }
  }
  return dates;
}

/// Шаблон «через сколько»: слова до числа и после, единица.
typedef _RelativeShape = ({String before, String after, _Unit unit});

// «dans {0} heures» → до «dans», после «heures»; по первому слову после числа (или последнему до него)
final _relativeShapes = () {
  final byAfter = <String, List<_RelativeShape>>{};
  final byBefore = <String, List<_RelativeShape>>{};
  final joined = <_RelativeShape>[];
  for (final MapEntry(:key, :value) in cldrRelative.entries) {
    if (!key.contains('{0}')) continue;
    final parts = key.split('{0}');
    final shape = (before: _keyOf(parts.first), after: _keyOf(parts.last), unit: _Unit.values[value]);
    if (_joined.hasMatch(key)) {
      joined.add(shape);
    } else if (shape.after.isNotEmpty) {
      byAfter.putIfAbsent(_firstToken(shape.after), () => []).add(shape);
    } else {
      byBefore.putIfAbsent(_lastToken(shape.before), () => []).add(shape);
    }
  }
  return (byAfter: byAfter, byBefore: byBefore, joined: joined);
}();

// «ymhen awr» — «через час» без числа: шаблоны с #N
final _fixedRelatives = [
  for (final unit in _Unit.values)
    (
      unit,
      _Lexicon({
        for (final MapEntry(:key, :value) in cldrRelative.entries)
          if (value == unit.index && key.contains('#')) key.split('#').first: int.parse(key.split('#').last),
      }),
    ),
];

_Relative? _worldRelative(_Text text) {
  final lower = text.text;
  _Relative? best;
  void offer(int start, int end, int count, _Unit unit) {
    if (best == null || start < best!.start) best = (start: start, end: end, count: count, unit: unit);
  }

  for (final (unit, fixed) in _fixedRelatives) {
    if (fixed.hits(text).firstOrNull case final hit?) offer(hit.start, hit.end, hit.value, unit);
  }
  // шаблон сходится, если слова до числа кончаются перед ним, а слова после — начинаются за ним
  // у китайского и японского после шаблона сразу идёт следующее слово: «2小时后关烤箱»
  int? fits(_RelativeShape shape, ({int start, int end, String word}) number) {
    final from = shape.before.isEmpty ? number.start : _wordsBefore(lower, _skipSpacesBack(lower, number.start), shape.before);
    if (from == null || (!_joined.hasMatch(shape.before) && _isLetter(shape.before, 0) && _isLetter(lower, from - 1))) return null;
    if (shape.after.isEmpty) return from;
    final end = _wordsAt(lower, _skipSpaces(lower, number.end), shape.after);
    if (end == null || (!_joined.hasMatch(shape.after) && _isLetter(shape.after, shape.after.length - 1) && _isLetter(lower, end))) return null;
    return from;
  }

  for (final number in text.tokens) {
    if (!_isDigit(number.word, 0)) continue;
    final count = int.parse(number.word);
    final next = text.byStart[_skipSpaces(lower, number.end)];
    final previous = text.byEnd[_skipSpacesBack(lower, number.start)];
    final shapes = [
      ...?_relativeShapes.byAfter[next?.word],
      ...?_relativeShapes.byBefore[previous?.word],
      if (text.joined) ..._relativeShapes.joined,
    ];
    for (final shape in shapes) {
      final from = fits(shape, number);
      if (from == null) continue;
      final end = shape.after.isEmpty ? number.end : _wordsAt(lower, _skipSpaces(lower, number.end), shape.after)!;
      offer(from, end, count, shape.unit);
      break;
    }
  }
  return best;
}

// предлоги перед часом, которых нет в CLDR: «alle 9», «saat 9», «jam 9», «στις 9», «الساعة 9»
const _moreAtWords = {'alle', 'vers', 'pelas', 'saat', 'klockan', 'kello', 'klokka', 'v', 've', 'jam', 'στις', 'στη', 'الساعة', 'בשעה', 'ساعت'};

// слова и знаки часа после числа: «9h», «9 uur», «9 óra», «3点»
const _moreHourMarks = {'h', 'uur', 'ora', 'heures', 'heure', 'hodin', 'hodiny', 'hod', '点', '點', '時', 'giờ'};

// минуты после знака часа: «3時30分», «3시 30분»
const _minuteMarks = ['分', '분', 'phút', 'min'];

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

final _phraseWords = _Lexicon(_worldPhrases);

final _periodMarks = _Lexicon({...cldrPeriodMarks, 'am': _Part.am.index, 'pm': _Part.pm.index});

// перед часом — «午後3時», «akşam 9», но не «am 13 ani» по-румынски: короткие латинские только после
final _periodMarksBefore = _Lexicon({
  for (final MapEntry(:key, :value) in cldrPeriodMarks.entries)
    if (!RegExp('[a-z]').hasMatch(_keyOf(key)) || _keyOf(key).replaceAll(RegExp(r'[\s.]'), '').length >= 4) key: value,
});
final _atWords = _Lexicon({for (final word in {...cldrAtWords, ..._moreAtWords}) word: 0});
final _hourMarks = _Lexicon({for (final word in {...cldrHourMarks, ..._moreHourMarks}) word: 0});
final _periods = _Lexicon(
  {for (final MapEntry(:key, :value) in cldrPeriods.entries) key: value.$1 * 100 + value.$2},
  known: (key) => _dayPartPatterns.any((entry) => _whole(entry.$1, key)),
);

// между днём и частью суток пробел, запятая или одно короткое слово: «amanhã de manhã»
bool _near(String text, int start, int end, int otherStart, int otherEnd) {
  final gap = end <= otherStart ? text.substring(end, otherStart) : (otherEnd <= start ? text.substring(otherEnd, start) : null);
  return gap != null && RegExp(r'^[\s,]*(?:\S{1,3}\s+)?$').hasMatch(gap);
}

List<_Time> _worldTimes(_Text text, List<_Date> dates, List<_Time> own) {
  final lower = text.text;
  final times = <_Time>[];
  bool taken(int start, int end) => [...own, ...times].any((time) => start < time.end && time.start < end);

  for (final hit in _phraseWords.hits(text)) {
    if (!taken(hit.start, hit.end)) times.add(_Time(hit.start, hit.end, hit.value, 0, world: true));
  }

  // час с частью суток до или после, предлогом, знаком часа и минутами: «à 9h30 du soir», «午後3時», «saat 9»
  for (final number in text.tokens) {
    if (!_isDigit(number.word, 0) || number.word.length > 2) continue;
    // «14:30» и «12.11» разбирают свои таблицы
    if ((number.start > 0 && ':.'.contains(lower[number.start - 1]) && _isDigit(lower, number.start - 2)) ||
        (number.end < lower.length && ':.'.contains(lower[number.end]) && _isDigit(lower, number.end + 1))) {
      continue;
    }
    var hour = int.parse(number.word);
    var minute = 0;
    var end = number.end;
    final mark = _hourMarks.at(text, _skipSpaces(lower, end));
    if (mark != null) {
      end = mark.end;
      if (end < lower.length && lower[end] == '.') end++;
      // «9h30», «3時30分»
      final minutes = text.byStart[_skipSpaces(lower, end)];
      if (minutes != null && minutes.word.length == 2 && _isDigit(minutes.word, 0)) {
        minute = int.parse(minutes.word);
        end = minutes.end;
        final after = _skipSpaces(lower, end);
        for (final word in _minuteMarks) {
          if (lower.startsWith(word, after) && !_isLetter(lower, after + word.length)) end = after + word.length;
        }
      }
    }
    final after = _periodMarks.at(text, _skipSpaces(lower, end));
    var start = number.start;
    var at = _atWords.before(text, _skipSpacesBack(lower, start));
    // «kl. 9»
    if (at == null && start > 1 && lower[_skipSpacesBack(lower, start) - 1] == '.') at = _atWords.before(text, _skipSpacesBack(lower, start) - 1);
    if (at != null) start = at.start;
    final before = _periodMarksBefore.before(text, _skipSpacesBack(lower, start));
    final qualifier = after ?? before;
    if (qualifier == null && mark == null && at == null) continue;
    // один предлог без знака часа — час только при дате: «à 9 personnes» — не время
    if (qualifier == null && mark == null && (dates.isEmpty || _afterNumber(lower, start))) continue;
    if (hour > 23 || minute > 59) continue;
    if (before != null && after == null) start = before.start;
    if (after != null) end = after.end;
    if (qualifier != null) hour = _hourOfPart(hour, _Part.values[qualifier.value]);
    if (taken(start, end)) continue;
    times.add(_Time(start, end, hour, minute, world: true, bare: qualifier == null));
  }

  // «domani sera», «yarın akşam»: часть суток рядом с чужим днём или чужим часом
  for (final hit in _periods.hits(text)) {
    if (taken(hit.start, hit.end)) continue;
    final part = _Part.values[hit.value ~/ 100];
    final hour = hit.value % 100;
    final near = times.where((time) => time.bare && _near(lower, hit.start, hit.end, time.start, time.end)).firstOrNull;
    if (near != null) {
      times.remove(near);
      times.add(_Time(near.start < hit.start ? near.start : hit.start, near.end > hit.end ? near.end : hit.end, _hourOfPart(near.hour, part), near.minute, world: true));
      continue;
    }
    if (dates.any((date) => date.world && _near(lower, hit.start, hit.end, date.start, date.end))) {
      times.add(_Time(hit.start, hit.end, hour, 0, world: true));
    }
  }
  return times;
}
