import 'reminder_service.dart';

/// Уведомления браузера. Вне браузера их нет: у телефона свой порт.
StartingNotificationPort? browserNotificationPort({required String doneLabel, required String snoozeLabel, required String removeLabel}) => null;

/// Касания уведомлений браузера, которые выполняет открытая вкладка.
Stream<NotificationTap> browserNotificationTaps(NotificationPort port) => const Stream.empty();
