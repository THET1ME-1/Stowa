/// Что из сохранённого вернуть человеку сегодня, — без ИИ, по времени и найденному.
/// Одно возвращающее уведомление в день на всех видах вместе и ничего в тихие часы:
/// иначе уведомления выключают совсем, и вместе с ними пропадают свои напоминания.
library;

/// Виды возврата. Покупки у магазина решает приёмник Android по тому же бюджету дня.
enum ReturnKind { watchLater, onThisDay, week, shopping }

/// Как давно сохранено то, что вернулось «в этот день».
enum ReturnPeriod { year, month, week }

/// Настройки возврата. Время — минуты от полуночи.
class ReturnSettings {
  const ReturnSettings({
    this.watchLater = true,
    this.onThisDay = true,
    this.week = true,
    this.shopping = true,
    this.evening = 20 * 60,
    this.quietStart = 22 * 60,
    this.quietEnd = 8 * 60,
    this.weekDay = DateTime.sunday,
  });

  final bool watchLater;
  final bool onThisDay;
  final bool week;
  final bool shopping;

  /// С этого часа вечером можно напомнить; окно кончается тихими часами.
  final int evening;
  final int quietStart;
  final int quietEnd;

  /// День сводки недели: 1 — понедельник, 7 — воскресенье.
  final int weekDay;

  ReturnSettings copyWith({bool? watchLater, bool? onThisDay, bool? week, bool? shopping, int? evening, int? quietStart, int? quietEnd, int? weekDay}) => ReturnSettings(
    watchLater: watchLater ?? this.watchLater,
    onThisDay: onThisDay ?? this.onThisDay,
    week: week ?? this.week,
    shopping: shopping ?? this.shopping,
    evening: evening ?? this.evening,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
    weekDay: weekDay ?? this.weekDay,
  );

  @override
  bool operator ==(Object other) =>
      other is ReturnSettings &&
      other.watchLater == watchLater &&
      other.onThisDay == onThisDay &&
      other.week == week &&
      other.shopping == shopping &&
      other.evening == evening &&
      other.quietStart == quietStart &&
      other.quietEnd == quietEnd &&
      other.weekDay == weekDay;

  @override
  int get hashCode => Object.hash(watchLater, onThisDay, week, shopping, evening, quietStart, quietEnd, weekDay);
}

/// Очередь «посмотреть потом»: непросмотренные ролики и статьи с известной длиной.
class WatchLaterFound {
  const WatchLaterFound({required this.videos, required this.articles, required this.minutes});

  final int videos;
  final int articles;
  final int minutes;

  int get count => videos + articles;

  @override
  bool operator ==(Object other) => other is WatchLaterFound && other.videos == videos && other.articles == articles && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(videos, articles, minutes);
}

/// Сохранённое ровно год (или несколько лет), месяц или неделю назад.
class OnThisDayFound {
  const OnThisDayFound({required this.period, required this.count, required this.firstId, required this.firstTitle, this.yearsAgo = 1});

  final ReturnPeriod period;

  /// Сколько лет назад, если [period] — год.
  final int yearsAgo;
  final int count;
  final String firstId;
  final String firstTitle;

  @override
  bool operator ==(Object other) =>
      other is OnThisDayFound && other.period == period && other.yearsAgo == yearsAgo && other.count == count && other.firstId == firstId && other.firstTitle == firstTitle;

  @override
  int get hashCode => Object.hash(period, yearsAgo, count, firstId, firstTitle);
}

/// Сводка за семь дней: сколько сохранено, сколько из этого не открыто и сколько лежит без папки.
class WeekFound {
  const WeekFound({required this.saved, required this.unopened, required this.unsorted});

  final int saved;
  final int unopened;
  final int unsorted;

  @override
  bool operator ==(Object other) => other is WeekFound && other.saved == saved && other.unopened == unopened && other.unsorted == unsorted;

  @override
  int get hashCode => Object.hash(saved, unopened, unsorted);
}

/// Что нашлось к этому проходу. Пусто — вида сегодня нет.
class ReturnFound {
  const ReturnFound({this.watch, this.day, this.week});

  final WatchLaterFound? watch;
  final OnThisDayFound? day;
  final WeekFound? week;
}

/// Решение: какой вид отправить и с чем. Текст собирает тот, кто знает язык.
class ReturnPick {
  const ReturnPick(this.kind, {this.watch, this.day, this.week});

  final ReturnKind kind;
  final WatchLaterFound? watch;
  final OnThisDayFound? day;
  final WeekFound? week;
}

/// День бюджета: «2026-11-06». Его же пишет и читает приёмник Android.
String returnDayKey(DateTime at) => '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';

/// Тихие часы, в том числе через полночь (22:00–8:00).
bool isQuietTime(DateTime at, ReturnSettings settings) {
  final minutes = at.hour * 60 + at.minute;
  final start = settings.quietStart;
  final end = settings.quietEnd;
  if (start == end) return false;
  return start < end ? minutes >= start && minutes < end : minutes >= start || minutes < end;
}

/// Одно уведомление или ничего. [lastDay] — день, когда возвращающее уже ушло ([returnDayKey]).
/// На один день первой идёт сводка (в её день), потом «в этот день», потом очередь.
ReturnPick? pickReturn({required DateTime now, required ReturnSettings settings, required String? lastDay, required ReturnFound found}) {
  if (lastDay == returnDayKey(now)) return null;
  if (isQuietTime(now, settings)) return null;
  if (now.hour * 60 + now.minute < settings.evening) return null;
  final week = found.week;
  if (settings.week && now.weekday == settings.weekDay && week != null && week.saved > 0) return ReturnPick(ReturnKind.week, week: week);
  final day = found.day;
  if (settings.onThisDay && day != null && day.count > 0) return ReturnPick(ReturnKind.onThisDay, day: day);
  final watch = found.watch;
  if (settings.watchLater && watch != null && watch.count > 0) return ReturnPick(ReturnKind.watchLater, watch: watch);
  return null;
}
