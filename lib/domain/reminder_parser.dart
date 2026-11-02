/// Напоминание, найденное в тексте: где оно и на какой момент.
class ReminderMatch {
  const ReminderMatch({required this.start, required this.end, required this.at, required this.hasTime});

  /// Кусок текста с датой и временем, его подчёркивает строка и вырезает заголовок.
  final int start;
  final int end;
  final DateTime at;

  /// Время названо. Без времени напоминание встаёт на 9 утра.
  final bool hasTime;

  /// Текст без даты и без «напомни» в начале: из него получается заголовок.
  String restOf(String text) {
    final rest = '${text.substring(0, start)} ${text.substring(end)}';
    return rest
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceFirst(RegExp(r'^(напомни(ть)?|напоминание)(\s+мне)?[\s,:]*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^[\s,.:;-]+|[\s,.:;-]+$'), '');
  }
}

const _morning = 9;
const _letter = r'а-яa-z0-9';

const _weekdays = {
  'понедельник': 1,
  'пн': 1,
  'вторник': 2,
  'вт': 2,
  'среду': 3,
  'ср': 3,
  'четверг': 4,
  'чт': 4,
  'пятницу': 5,
  'пт': 5,
  'субботу': 6,
  'сб': 6,
  'воскресенье': 7,
  'вс': 7,
};

// полные формы раньше коротких, иначе «мар» съест начало «марта»
const _months = [
  ('января', 1),
  ('февраля', 2),
  ('марта', 3),
  ('апреля', 4),
  ('мая', 5),
  ('июня', 6),
  ('июля', 7),
  ('августа', 8),
  ('сентября', 9),
  ('октября', 10),
  ('ноября', 11),
  ('декабря', 12),
  ('янв', 1),
  ('фев', 2),
  ('мар', 3),
  ('апр', 4),
  ('июн', 6),
  ('июл', 7),
  ('авг', 8),
  ('сент', 9),
  ('сен', 9),
  ('окт', 10),
  ('ноя', 11),
  ('дек', 12),
];

const _dayParts = {'утром': 9, 'днем': 13, 'вечером': 19, 'ночью': 23, 'в полдень': 12, 'в полночь': 0};

// слова после «в 13», с которыми число — не час: «в 13 лет», «в 2 раза»
final _notHour = RegExp(r'^\s*(лет|год|года|раз|раза|процент|%|штук|рубл|лей|долл|евро|км|кг|м\b|см|человек|этаж|класс|сери|сезон|минут|секунд|мес|недел|дн)');

final _dayWord = RegExp('(?<![$_letter])(сегодня|завтра|послезавтра)(?![$_letter])');
final _weekday = RegExp('(?<![$_letter])во?\\s+(${_weekdays.keys.join('|')})(?![$_letter])');
final _monthDate = RegExp('(?<![$_letter])(\\d{1,2})\\s+(${_months.map((month) => month.$1).join('|')})\\.?(?:\\s+(\\d{4}))?(?![$_letter])');
final _dotDate = RegExp('(?<![$_letter.:]|в )(\\d{1,2})\\.(\\d{2})(?:\\.(\\d{4}|\\d{2}))?(?![$_letter.:])');
final _clock = RegExp('(?<![$_letter])(?:(?:в|к)\\s+)?(\\d{1,2})[:.](\\d{2})(?![$_letter])');
final _hour = RegExp('(?<![$_letter])(?:в|к)\\s+(\\d{1,2})(?:\\s+(утра|дня|вечера|ночи|часов|часа|час))?(?![$_letter:.])');
final _dayPart = RegExp('(?<![$_letter])(${_dayParts.keys.join('|')})(?![$_letter])');
final _relative = RegExp(
  '(?<![$_letter])через\\s+(?:(полчаса)|(?:(\\d+)\\s+)?(минуту|минуты|минут|мин|часа|часов|час|дня|дней|день|сутки|недели|неделю|недель|месяца|месяцев|месяц))(?![$_letter])',
);

class _Date {
  _Date(this.start, this.end, this.resolve);
  final int start;
  final int end;

  /// Дата по времени суток: учитывает, прошёл ли уже этот момент.
  final DateTime Function(int hour, int minute) resolve;
}

class _Time {
  _Time(this.start, this.end, this.hour, this.minute);
  final int start;
  final int end;
  final int hour;
  final int minute;
}

/// Первое напоминание в русском тексте или null. Понимает «23 декабря 13:00»,
/// «завтра в 10», «в пятницу», «через 2 часа», «сегодня вечером», «12.11 в 9».
ReminderMatch? parseReminder(String text, DateTime now) {
  final lower = text.toLowerCase().replaceAll('ё', 'е');

  final relative = _relative.firstMatch(lower);
  if (relative != null) {
    return ReminderMatch(start: relative.start, end: relative.end, at: _relativeMoment(relative, now), hasTime: true);
  }

  final dates = _dates(lower, now)..sort((a, b) => a.start.compareTo(b.start));
  final times = _times(lower)..sort((a, b) => a.start.compareTo(b.start));

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
    return ReminderMatch(start: date.start, end: date.end, at: date.resolve(_morning, 0), hasTime: false);
  }

  if (times.isNotEmpty) {
    final time = times.first;
    var at = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!at.isAfter(now)) at = DateTime(now.year, now.month, now.day + 1, time.hour, time.minute);
    return ReminderMatch(start: time.start, end: time.end, at: at, hasTime: true);
  }
  return null;
}

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

DateTime _relativeMoment(RegExpMatch match, DateTime now) {
  if (match.group(1) != null) return now.add(const Duration(minutes: 30));
  final count = int.parse(match.group(2) ?? '1');
  final unit = match.group(3)!;
  if (unit.startsWith('мин')) return now.add(Duration(minutes: count));
  if (unit.startsWith('час')) return now.add(Duration(hours: count));
  // дни и недели считаются по календарю, напоминание на утро
  if (unit.startsWith('д') || unit == 'сутки') return DateTime(now.year, now.month, now.day + count, _morning);
  if (unit.startsWith('недел')) return DateTime(now.year, now.month, now.day + 7 * count, _morning);
  return DateTime(now.year, now.month + count, now.day, _morning);
}

List<_Date> _dates(String text, DateTime now) {
  final dates = <_Date>[];

  for (final match in _dayWord.allMatches(text)) {
    final shift = switch (match.group(1)) {
      'сегодня' => 0,
      'завтра' => 1,
      _ => 2,
    };
    dates.add(_Date(match.start, match.end, (hour, minute) => DateTime(now.year, now.month, now.day + shift, hour, minute)));
  }

  for (final match in _weekday.allMatches(text)) {
    final target = _weekdays[match.group(1)]!;
    dates.add(
      _Date(match.start, match.end, (hour, minute) {
        final ahead = (target - now.weekday + 7) % 7;
        final at = DateTime(now.year, now.month, now.day + ahead, hour, minute);
        return at.isAfter(now) ? at : DateTime(now.year, now.month, now.day + ahead + 7, hour, minute);
      }),
    );
  }

  for (final match in _monthDate.allMatches(text)) {
    final day = int.parse(match.group(1)!);
    final month = _months.firstWhere((entry) => entry.$1 == match.group(2)).$2;
    final year = match.group(3) == null ? null : int.parse(match.group(3)!);
    final date = _calendarDate(match, day, month, year, now);
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

_Date? _calendarDate(RegExpMatch match, int day, int month, int? year, DateTime now) {
  if (month < 1 || month > 12 || day < 1 || day > DateTime(2024, month + 1, 0).day) return null;
  return _Date(match.start, match.end, (hour, minute) {
    final at = DateTime(year ?? now.year, month, day, hour, minute);
    // без года прошедшая дата значит следующий год
    if (year == null && at.isBefore(now)) return DateTime(now.year + 1, month, day, hour, minute);
    return at;
  });
}

List<_Time> _times(String text) {
  final times = <_Time>[];
  for (final match in _clock.allMatches(text)) {
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    // «в 9.30» — время, а «12.11» без «в» уже забрала дата
    final dotted = !match.group(0)!.contains(':');
    if (dotted && !match.group(0)!.startsWith(RegExp('[вк]'))) continue;
    if (hour > 23 || minute > 59) continue;
    times.add(_Time(match.start, match.end, hour, minute));
  }
  for (final match in _hour.allMatches(text)) {
    var hour = int.parse(match.group(1)!);
    final qualifier = match.group(2);
    if (hour > 23) continue;
    if (qualifier == null && _notHour.hasMatch(text.substring(match.end))) continue;
    if (times.any((time) => time.start <= match.start && match.start < time.end)) continue;
    if ((qualifier == 'дня' && hour <= 5) || (qualifier == 'вечера' && hour < 12) || (qualifier == 'ночи' && hour >= 6 && hour < 12)) {
      hour += 12;
    }
    if (qualifier == 'ночи' && hour == 12) hour = 0;
    times.add(_Time(match.start, match.end, hour, 0));
  }
  for (final match in _dayPart.allMatches(text)) {
    times.add(_Time(match.start, match.end, _dayParts[match.group(1)]!, 0));
  }
  return times;
}
