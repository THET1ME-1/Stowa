import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stowa/l10n/app_localizations.dart';
import 'package:stowa/services/billing/copy_warning.dart';
import 'package:stowa/services/billing/subscription.dart';
import 'package:stowa/services/reminder_service.dart';

/// Будильники, которые поставили: номер → (когда, текст).
class _Port implements NotificationPort {
  final scheduled = <int, (DateTime, String)>{};
  var cleared = 0;

  @override
  Future<void> cancelAll() async {
    cleared++;
    scheduled.clear();
  }

  @override
  Future<void> schedule({required int id, required String title, required String body, required DateTime at, required String payload}) async => scheduled[id] = (at, body);

  @override
  Future<void> ensurePermission() async {}

  @override
  Future<void> show({required int id, required String title, required String body, required String payload}) async {}

  @override
  Future<void> showPinned({required int id, required String title, required String body, required String payload, required bool private}) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<List<int>> activePinned() async => const [];
}

void main() {
  setUpAll(() => initializeDateFormatting('ru'));
  final l = lookupL(const Locale('ru'));
  final now = DateTime(2026, 12, 1, 10);
  final until = DateTime(2026, 12, 21, 12);
  Subscription lapsed(DateTime? copyUntil) => Subscription(signedIn: true, paidUntil: DateTime(2026, 11, 21), copyUntil: copyUntil);

  test('когда предупредить: за неделю, неделя прошла — за сутки, сутки прошли — никак', () {
    expect(copyWarningAt(until, now), DateTime(2026, 12, 14, 12));
    expect(copyWarningAt(until, DateTime(2026, 12, 16)), DateTime(2026, 12, 20, 12));
    expect(copyWarningAt(until, DateTime(2026, 12, 21)), isNull);
  });

  test('предупреждение — только без подписки и пока копия на сервере есть', () {
    final warning = copyWarning(lapsed(until), l, now)!;
    expect(warning.id, syncCopyPayload);
    expect(warning.title, 'Копия в облаке скоро сотрётся');
    expect(warning.body, startsWith('21 декабря сервер сотрёт копию Stowa Sync'));
    expect(copyWarning(lapsed(null), l, now), isNull);
    expect(copyWarning(Subscription(signedIn: true, active: true, paidUntil: DateTime(2099), copyUntil: until), l, now), isNull);
    expect(copyWarning(Subscription.none, l, now), isNull);
  });

  test('пересчёт напоминаний ставит предупреждение вместе с напоминаниями, а не отдельно', () async {
    final port = _Port();
    Reminder? extra = copyWarning(lapsed(until), l, now);
    final service = ReminderService(port, extra: (_) async => extra);
    // пока напоминаний не видели, будильники не трогаем: снять их вслепую — значит потерять
    await service.refresh(now);
    expect(port.cleared, 0);
    final note = (id: 'n1', title: 'Позвонить', body: 'маме', at: now.add(const Duration(hours: 3)));
    await service.sync([note], now);
    expect(port.scheduled.keys.toSet(), {notificationId('n1'), notificationId(syncCopyPayload)});
    expect(port.scheduled[notificationId(syncCopyPayload)]!.$1, DateTime(2026, 12, 14, 12));
    // продлили: предупреждение снимается, напоминание остаётся
    extra = null;
    await service.refresh(now);
    expect(port.scheduled.keys.toSet(), {notificationId('n1')});
  });
}
