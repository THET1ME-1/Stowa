import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/return_plan.dart';

void main() {
  const settings = ReturnSettings();
  // пятница 6 ноября 2026, 20:30 — вечернее окно
  final evening = DateTime(2026, 11, 6, 20, 30);
  const watch = WatchLaterFound(videos: 3, articles: 1, minutes: 24);
  const day = OnThisDayFound(period: ReturnPeriod.year, yearsAgo: 1, count: 1, firstId: 'b', firstTitle: 'Борщ бабушкин');
  const week = WeekFound(saved: 23, unopened: 7, unsorted: 5);

  ReturnPick? pick(DateTime now, {ReturnSettings settings = settings, String? lastDay, ReturnFound found = const ReturnFound(watch: watch)}) =>
      pickReturn(now: now, settings: settings, lastDay: lastDay, found: found);

  test('вечером «посмотреть потом» уходит, днём и ночью — нет', () {
    expect(pick(evening)?.kind, ReturnKind.watchLater);
    expect(pick(DateTime(2026, 11, 6, 19, 59)), isNull);
    // тихие часы с 22:00 до 8:00
    expect(pick(DateTime(2026, 11, 6, 22, 0)), isNull);
    expect(pick(DateTime(2026, 11, 7, 7, 30)), isNull);
  });

  test('не больше одного в день: сегодня уже было — молчим, завтра снова можно', () {
    expect(pick(evening, lastDay: returnDayKey(evening)), isNull);
    expect(pick(evening, lastDay: '2026-11-05')?.kind, ReturnKind.watchLater);
    expect(returnDayKey(DateTime(2026, 1, 3, 23)), '2026-01-03');
  });

  test('пустое не шлётся, выключенный вид — тоже', () {
    expect(pick(evening, found: const ReturnFound()), isNull);
    expect(pick(evening, found: const ReturnFound(watch: WatchLaterFound(videos: 0, articles: 0, minutes: 0))), isNull);
    expect(pick(evening, settings: const ReturnSettings(watchLater: false)), isNull);
  });

  test('порядок на один день: сводка в свой день, потом «в этот день», потом очередь', () {
    const all = ReturnFound(watch: watch, day: day, week: week);
    // пятница — не день сводки
    expect(pick(evening, found: all)?.kind, ReturnKind.onThisDay);
    // воскресенье — сводка
    expect(pick(DateTime(2026, 11, 8, 20, 30), found: all)?.kind, ReturnKind.week);
    // сводку выключили — «в этот день»
    expect(pick(DateTime(2026, 11, 8, 20, 30), found: all, settings: const ReturnSettings(week: false))?.kind, ReturnKind.onThisDay);
    // за неделю ничего не сохранено — сводки нет
    expect(pick(DateTime(2026, 11, 8, 20, 30), found: const ReturnFound(watch: watch, week: WeekFound(saved: 0, unopened: 0, unsorted: 0)))?.kind, ReturnKind.watchLater);
  });

  test('выбранный час вечера и свои тихие часы, в том числе через полночь', () {
    const late = ReturnSettings(evening: 21 * 60, quietStart: 23 * 60, quietEnd: 7 * 60);
    expect(pick(DateTime(2026, 11, 6, 20, 30), settings: late), isNull);
    expect(pick(DateTime(2026, 11, 6, 22, 45), settings: late)?.kind, ReturnKind.watchLater);
    // тихие часы днём, без перехода через полночь
    const day = ReturnSettings(evening: 9 * 60, quietStart: 13 * 60, quietEnd: 15 * 60);
    expect(pick(DateTime(2026, 11, 6, 14, 0), settings: day), isNull);
    expect(pick(DateTime(2026, 11, 6, 16, 0), settings: day)?.kind, ReturnKind.watchLater);
    expect(isQuietTime(DateTime(2026, 11, 6, 3), const ReturnSettings()), isTrue);
  });

  test('найденное едет в решение целиком: из него собирается текст', () {
    final chosen = pick(evening, found: const ReturnFound(day: day))!;
    expect(chosen.day, day);
    expect(pick(evening)!.watch, watch);
  });
}
