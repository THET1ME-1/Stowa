import 'package:shared_preferences/shared_preferences.dart';

import '../data/db/database.dart';
import '../data/repositories/return_repository.dart';
import '../domain/return_plan.dart';
import '../l10n/app_localizations.dart';
import 'reminder_service.dart';

/// День, когда возвращающее уведомление уже ушло ([returnDayKey]). Его же читает и пишет
/// приёмник Android для покупок у магазина: бюджет дня один на всех.
const returnDayPref = 'return_day';

/// Одно место в шторке на все возвращающие: новое заменяет вчерашнее, а не копится.
const returnNotificationId = 7000001;

/// Раз в проход (фон раз в 15 минут) решает, вернуть ли что-то, и показывает одно тихое
/// уведомление. Отправил — записал день: до завтра молчит.
class ReturnService {
  ReturnService(this._db, {required SharedPreferences prefs, required NotificationPort port, required DateTime Function() clock, required ReturnSettings Function() settings, required L Function() l})
    : _prefs = prefs, // ignore: prefer_initializing_formals
      _port = port, // ignore: prefer_initializing_formals
      _clock = clock, // ignore: prefer_initializing_formals
      _settings = settings, // ignore: prefer_initializing_formals
      _l = l; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final SharedPreferences _prefs;
  final NotificationPort _port;
  final DateTime Function() _clock;
  final ReturnSettings Function() _settings;
  final L Function() _l;

  Future<ReturnPick?> tick() async {
    final now = _clock();
    final settings = _settings();
    await _prefs.reload();
    final lastDay = _prefs.getString(returnDayPref);
    // сперва дешёвое: сегодня уже было, тихие часы или ещё не вечер — база не нужна
    if (lastDay == returnDayKey(now) || isQuietTime(now, settings) || now.hour * 60 + now.minute < settings.evening) return null;
    final repository = ReturnRepository(_db);
    final found = ReturnFound(
      watch: settings.watchLater ? summarizeWatchLater(await repository.watchLater(now)) : null,
      day: settings.onThisDay ? (await repository.onThisDay(now))?.found : null,
      week: settings.week && now.weekday == settings.weekDay ? (await repository.week(now)).found : null,
    );
    final pick = pickReturn(now: now, settings: settings, lastDay: lastDay, found: found);
    if (pick == null) return null;
    final text = returnText(_l(), pick);
    await _port.show(id: returnNotificationId, title: text.title, body: text.body, payload: text.payload);
    await _prefs.setString(returnDayPref, returnDayKey(now));
    return pick;
  }
}

/// Текст уведомления и куда ведёт касание: `return:<вид>` — экран, `note:<id>` — сама заметка.
({String title, String body, String payload}) returnText(L l, ReturnPick pick) {
  switch (pick.kind) {
    case ReturnKind.watchLater:
      final watch = pick.watch!;
      final parts = [if (watch.videos > 0) l.returnVideos(watch.videos), if (watch.articles > 0) l.returnArticles(watch.articles)];
      final what = parts.length == 2 ? l.returnAnd(parts[0], parts[1]) : parts.single;
      return (title: l.returnWatchTitle, body: l.returnWatchBody(what, l.returnMinutes(watch.minutes)), payload: 'return:${ReturnKind.watchLater.name}');
    case ReturnKind.onThisDay:
      final day = pick.day!;
      final title = switch (day.period) {
        ReturnPeriod.year => l.returnYearsAgo(day.yearsAgo),
        ReturnPeriod.month => l.returnMonthAgo,
        ReturnPeriod.week => l.returnWeekAgo,
      };
      return day.count == 1
          ? (title: title, body: l.returnDayOne(day.firstTitle), payload: 'note:${day.firstId}')
          : (title: title, body: l.returnDayMore(day.firstTitle, day.count - 1), payload: 'return:${ReturnKind.onThisDay.name}');
    case ReturnKind.week:
      final week = pick.week!;
      final parts = [if (week.unopened > 0) l.returnWeekUnopened(week.unopened), if (week.unsorted > 0) l.returnWeekUnsorted(week.unsorted)];
      final saved = l.returnWeekSaved(week.saved);
      return (title: l.returnWeekTitle, body: parts.isEmpty ? saved : '$saved: ${parts.join(', ')}', payload: 'return:${ReturnKind.week.name}');
    case ReturnKind.shopping:
      return (title: l.returnShopping, body: '', payload: 'return:${ReturnKind.shopping.name}');
  }
}
