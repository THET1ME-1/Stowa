import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db/database.dart';
import '../data/repositories/items_repository.dart';
import '../data/settings_repository.dart';
import '../l10n/app_language.dart';
import '../l10n/app_localizations.dart';
import 'reminder_service.dart';

export 'reminder_service.dart' show reminderDone, reminderSnooze;

/// Кнопка на уведомлении. «Готово» снимает напоминание, «Через час» переносит
/// и возвращает новое, чтобы поставить будильник сразу, даже если приложение закрыто.
Future<Reminder?> handleReminderAction(ItemsRepository items, {required String actionId, required String itemId, required DateTime now}) async {
  switch (actionId) {
    case reminderDone:
      await items.clearReminder(itemId);
      return null;
    case reminderSnooze:
      return items.snoozeReminder(itemId, now.add(const Duration(hours: 1)));
  }
  return null;
}

/// Подписи уведомлений на языке телефона.
LocalNotificationPort reminderPort({void Function(String id)? onOpen}) {
  final l = lookupL(AppLanguage.resolve(PlatformDispatcher.instance.locales).locale);
  return LocalNotificationPort(
    channelName: l.reminderChannel,
    doneLabel: l.reminderDoneAction,
    snoozeLabel: l.reminderSnoozeAction,
    returnChannelName: l.returnChannel,
    onOpen: onOpen,
    onAction: reminderActionInBackground,
  );
}

/// Нажали кнопку на уведомлении. Система будит отдельный процесс Dart без экрана:
/// база общая с приложением, если оно открыто, — его ленты обновятся сами.
@pragma('vm:entry-point')
Future<void> reminderActionInBackground(NotificationResponse response) async {
  final itemId = response.payload;
  final actionId = response.actionId;
  if (itemId == null || actionId == null) return;
  DartPluginRegistrant.ensureInitialized();
  // база открытого хранилища: уведомления других при смене хранилища снимаются
  final settings = SettingsRepository(await SharedPreferences.getInstance(), const SecureKeyStore());
  final db = AppDatabase.named(settings.vaultDb);
  try {
    // скрытая заметка в базе, только пока скрытое открыто; закрытое кнопки не трогают
    final hidden = itemId.startsWith('hidden:');
    final again = await handleReminderAction(ItemsRepository(db), actionId: actionId, itemId: reminderItemId(itemId), now: DateTime.now());
    if (again != null) {
      final l = lookupL(AppLanguage.resolve(PlatformDispatcher.instance.locales).locale);
      await reminderPort().schedule(
        id: notificationId(hidden ? itemId : again.id),
        title: hidden ? l.hiddenReminder : again.title,
        body: hidden ? '' : again.body,
        at: again.at,
        payload: hidden ? itemId : again.id,
      );
    }
  } finally {
    await db.close();
  }
}
