import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// «сегодня в 13:00», «завтра в 10:00», «23 декабря в 13:00».
String formatReminder(L l, DateTime at, DateTime now) {
  final locale = l.localeName;
  final time = DateFormat.jm(locale).format(at);
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  if (days == 0) return l.remindToday(time);
  if (days == 1) return l.remindTomorrow(time);
  final date = at.year == now.year ? DateFormat.MMMMd(locale).format(at) : DateFormat.yMMMMd(locale).format(at);
  return l.remindOn(date, time);
}

/// Короткая подпись под карточкой: «23 дек., 13:00».
String formatReminderShort(L l, DateTime at, DateTime now) {
  final locale = l.localeName;
  final time = DateFormat.jm(locale).format(at);
  final sameDay = at.year == now.year && at.month == now.month && at.day == now.day;
  if (sameDay) return time;
  return '${DateFormat.MMMd(locale).format(at)}, $time';
}
