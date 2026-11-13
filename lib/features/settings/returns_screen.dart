import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/sheet_options.dart';
import '../../data/providers.dart';
import '../../domain/reminder_parser.dart' show defaultWorkEnd;
import '../../domain/return_plan.dart';
import '../../l10n/app_localizations.dart';
import '../places/places_screen.dart';
import '../places/reminder_permissions.dart';
import 'settings_blocks.dart';

Route<void> returnsRoute() => settingsPageRoute(const ReturnsScreen());

/// «Посмотреть потом · Сводка недели» — что включено, подписью строки «Возвращать» в настройках.
String returnsSummary(L l, ReturnSettings returns) {
  final kinds = [
    if (returns.watchLater) l.returnWatchTitle,
    if (returns.onThisDay) l.returnOnThisDay,
    if (returns.week) l.returnWeekSetting,
    if (returns.shopping) l.returnShoppingSetting,
  ];
  return kinds.isEmpty ? l.returnsOff : kinds.join(' · ');
}

/// «Возвращать»: виды по одному, с какого часа вечером, тихие часы, день сводки и места.
class ReturnsScreen extends ConsumerWidget {
  const ReturnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final returns = ref.watch(returnSettingsProvider).value ?? const ReturnSettings();
    final workEnd = ref.watch(workEndChoiceProvider).value ?? defaultWorkEnd;
    // настройки — в момент правки, не при отрисовке: экран живёт и в тестах без них
    Future<void> save(ReturnSettings value) async {
      await ref.read(settingsRepositoryProvider).setReturns(value);
      // включил вид возврата — придут уведомления: тут и спросить разрешение
      final switchedOn = (value.watchLater && !returns.watchLater) || (value.onThisDay && !returns.onThisDay) || (value.week && !returns.week) || (value.shopping && !returns.shopping);
      if (switchedOn) await askNotifications(ref);
    }

    String clock(int minutes) => DateFormat.Hm(l.localeName).format(DateTime(2026, 1, 1, minutes ~/ 60, minutes % 60));
    // 1 ноября 2026 — воскресенье: день недели 1…7 ложится на 2…8 ноября
    String weekday(int day) => capitalized(DateFormat.EEEE(l.localeName).format(DateTime(2026, 11, 1 + day)));
    // «Пн», «Вт» — в круге строки выбора
    String weekdayShort(int day) => capitalized(DateFormat.E(l.localeName).format(DateTime(2026, 11, 1 + day))).replaceAll('.', '');
    Future<int?> pickTime(int minutes, String help) async {
      final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60), helpText: help);
      return picked == null ? null : picked.hour * 60 + picked.minute;
    }

    // «Дом, Офис, Саша» — что уже отмечено; длинное строка обрежет сама
    String placesSummary() {
      final places = ref.watch(placesProvider).value ?? const [];
      return places.isEmpty ? l.placesNotSet : places.map((place) => place.name).join(', ');
    }

    Future<void> pickWeekDay() async {
      final day = await showOptionsSheet<int>(
        context,
        title: l.returnWeekDayRow,
        selected: returns.weekDay,
        options: [
          for (var day = DateTime.monday; day <= DateTime.sunday; day++) SheetChoice(value: day, title: weekday(day), mark: weekdayShort(day)),
        ],
      );
      if (day != null) await save(returns.copyWith(weekDay: day));
    }

    final tint = settingsTint('tangerine');
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            SettingsHeader(l.settingsReturns),
            const SizedBox(height: 18),
            SettingsGroup(
              tint: tint,
              children: [
                SettingsSwitchRow(icon: 'smart_display', title: l.returnWatchTitle, value: returns.watchLater, onChanged: (on) => save(returns.copyWith(watchLater: on))),
                SettingsSwitchRow(icon: 'history', title: l.returnOnThisDay, value: returns.onThisDay, onChanged: (on) => save(returns.copyWith(onThisDay: on))),
                SettingsSwitchRow(icon: 'calendar_view_week', title: l.returnWeekSetting, value: returns.week, onChanged: (on) => save(returns.copyWith(week: on))),
                SettingsSwitchRow(icon: 'shopping_basket', title: l.returnShoppingSetting, value: returns.shopping, onChanged: (on) => save(returns.copyWith(shopping: on))),
              ],
            ),
            SettingsHint(l.returnSettingsHint),
            SettingsGroup(
              tint: tint,
              children: [
                SettingsRow(
                  icon: 'schedule',
                  title: l.returnEveningRow,
                  value: clock(returns.evening),
                  onTap: () async {
                    final minutes = await pickTime(returns.evening, l.returnEveningRow);
                    if (minutes != null) await save(returns.copyWith(evening: minutes));
                  },
                ),
                // «после работы» в строке — в этот час
                SettingsRow(
                  icon: 'work_history',
                  title: l.workEndRow,
                  value: clock(workEnd),
                  onTap: () async {
                    final minutes = await pickTime(workEnd, l.workEndRow);
                    if (minutes != null) await ref.read(settingsRepositoryProvider).setWorkEnd(minutes);
                  },
                ),
                SettingsRow(
                  icon: 'bedtime',
                  title: l.returnQuietRow,
                  value: l.returnRange(clock(returns.quietStart), clock(returns.quietEnd)),
                  onTap: () async {
                    final start = await pickTime(returns.quietStart, l.returnQuietFrom);
                    if (start == null || !context.mounted) return;
                    final end = await pickTime(returns.quietEnd, l.returnQuietTo);
                    if (end != null) await save(returns.copyWith(quietStart: start, quietEnd: end));
                  },
                ),
                SettingsRow(icon: 'event_repeat', title: l.returnWeekDayRow, value: weekday(returns.weekDay), onTap: pickWeekDay),
              ],
            ),
            const SizedBox(height: 8),
            SettingsGroup(
              tint: tint,
              children: [
                SettingsRow(icon: 'location_on', title: l.placesTitle, value: placesSummary(), onTap: () => Navigator.of(context).push(placesRoute())),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
