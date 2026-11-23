/// Предупреждение «копия в облаке скоро сотрётся»: подписки нет, а сервер через 30 дней после
/// её конца стирает копию. Уведомление встаёт в общий список будильников напоминаний —
/// пересчёт напоминаний снимает все будильники разом, и отдельный будильник пропал бы.
library;

import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../reminder_service.dart';
import 'subscription.dart';

/// Что приходит в уведомлении и куда ведёт касание: экран Stowa Sync.
const syncCopyPayload = 'sync:copy';

/// Когда предупредить о стирании [until]: за неделю; неделя уже прошла — за сутки; и это
/// прошло — уже никак, остаются надписи в приложении.
DateTime? copyWarningAt(DateTime until, DateTime now) {
  for (final ahead in const [Duration(days: 7), Duration(days: 1)]) {
    final at = until.subtract(ahead);
    if (at.isAfter(now)) return at;
  }
  return null;
}

/// Напоминание о стирании копии для [subscription]; null — предупреждать не о чем.
Reminder? copyWarning(Subscription subscription, L l, DateTime now) {
  final until = subscription.copyUntil;
  if (!subscription.signedIn || subscription.activeNow || until == null) return null;
  final at = copyWarningAt(until.toLocal(), now);
  if (at == null) return null;
  final date = DateFormat.MMMMd(l.localeName).format(until.toLocal());
  return (id: syncCopyPayload, title: l.syncCopyWarnTitle, body: l.syncCopyWarnBody(date), at: at);
}
