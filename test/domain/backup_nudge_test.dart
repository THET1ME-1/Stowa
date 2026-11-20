import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/backup_nudge.dart';

void main() {
  final now = DateTime(2026, 11, 20, 12);

  test('заметок нет — напоминать не о чем', () {
    expect(backupNudge(now: now, notes: 0, editedSince: 0), BackupNudge.none);
  });

  test('есть заметки, а копии ни разу не было — первое предупреждение', () {
    expect(backupNudge(now: now, notes: 1, editedSince: 1), BackupNudge.first);
  });

  test('копия свежая и правок мало — молчим', () {
    expect(backupNudge(now: now, notes: 40, editedSince: 3, lastCopy: now.subtract(const Duration(days: 2))), BackupNudge.none);
  });

  test('неделя с последней копии и за это время что-то правили — напоминание', () {
    final lastCopy = now.subtract(const Duration(days: 7, minutes: 1));
    expect(backupNudge(now: now, notes: 40, editedSince: 1, lastCopy: lastCopy), BackupNudge.stale);
  });

  test('неделя прошла, но с копии ничего не меняли — копия всё ещё целая, молчим', () {
    expect(backupNudge(now: now, notes: 40, editedSince: 0, lastCopy: now.subtract(const Duration(days: 30))), BackupNudge.none);
  });

  test('пятьдесят правок после копии — напоминание, хоть она и вчерашняя', () {
    final lastCopy = now.subtract(const Duration(days: 1));
    expect(backupNudge(now: now, notes: 400, editedSince: 49, lastCopy: lastCopy), BackupNudge.none);
    expect(backupNudge(now: now, notes: 400, editedSince: 50, lastCopy: lastCopy), BackupNudge.stale);
  });

  test('человек отложил напоминание — молчим до срока, потом снова', () {
    final later = now.add(const Duration(days: 3));
    expect(backupNudge(now: now, notes: 5, editedSince: 5, snoozedUntil: later), BackupNudge.none);
    expect(backupNudge(now: later.add(const Duration(minutes: 1)), notes: 5, editedSince: 5, snoozedUntil: later), BackupNudge.first);
  });
}
