import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

/// Напоминание вещи: что показать и когда.
typedef Reminder = ({String id, String title, String body, DateTime at});

/// Сколько будильников держать в системе разом: ближайшие, остальные встанут потом.
const _limit = 50;

/// Кнопки на уведомлении.
const reminderDone = 'done';
const reminderSnooze = 'snooze';

// значки разметки в начале строки и выделение внутри
final _lineMarks = RegExp(r'^(#{1,6}\s+|[-*+]\s+\[[ xX]\]\s+|[-*+]\s+|>\s+|\d+[.)]\s+)');
final _inlineMarks = RegExp(r'\*\*|__|`|~~');

/// Строка под заголовком уведомления: первая живая строка текста после заголовка, без разметки.
/// Первая строка текста — это и есть заголовок, пусть дата из него и ушла.
String reminderText(String title, String body) {
  var first = true;
  for (final raw in body.split('\n')) {
    final line = raw.trim().replaceFirst(_lineMarks, '').replaceAll(_inlineMarks, '').trim();
    if (line.isEmpty) continue;
    if (first || line == title.trim()) {
      first = false;
      continue;
    }
    return line.length > 120 ? '${line.substring(0, 119)}…' : line;
  }
  return '';
}

/// Номер уведомления вещи: один и тот же при каждом пересчёте.
int notificationId(String itemId) => itemId.codeUnits.fold(17, (hash, unit) => (hash * 31 + unit) & 0x7fffffff);

/// Без системы уведомлений: тесты и первый кадр до запуска.
class SilentNotificationPort implements NotificationPort {
  const SilentNotificationPort();

  @override
  Future<void> ensurePermission() async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule({required int id, required String title, required String body, required DateTime at, required String payload}) async {}

  @override
  Future<void> show({required int id, required String title, required String body, required String payload}) async {}
}

/// Система уведомлений за тонкой стенкой: в тестах её подменяют.
abstract interface class NotificationPort {
  /// Разрешения на уведомления и точные будильники: спрашиваются, когда есть что ставить.
  Future<void> ensurePermission();

  /// Снять запланированные будильники напоминаний. Уже показанные уведомления остаются:
  /// пересчёт при открытии приложения не должен стирать вечернее «посмотреть потом».
  Future<void> cancelAll();

  Future<void> schedule({required int id, required String title, required String body, required DateTime at, required String payload});

  /// Показать сейчас, в тихом канале «Возвращение»: то, о чём человек не просил, не звенит.
  Future<void> show({required int id, required String title, required String body, required String payload});
}

/// Держит будильники системы в согласии с базой. Любая правка напоминаний —
/// сохранение, «Готово», удаление, «Отменить» — ведёт к одному пересчёту.
class ReminderService {
  ReminderService(this._port);

  final NotificationPort _port;
  String? _last;
  bool _asked = false;

  Future<void> sync(List<Reminder> reminders, DateTime now) async {
    final coming = reminders.where((one) => one.at.isAfter(now)).toList()..sort((a, b) => a.at.compareTo(b.at));
    final planned = coming.take(_limit).toList();
    // тот же список — системе ничего не говорим
    final key = planned.map((one) => '${one.id}|${one.at.toIso8601String()}|${one.title}|${one.body}').join('\n');
    if (key == _last) return;
    _last = key;
    if (planned.isNotEmpty && !_asked) {
      _asked = true;
      await _port.ensurePermission();
    }
    await _port.cancelAll();
    for (final one in planned) {
      await _port.schedule(id: notificationId(one.id), title: one.title, body: one.body, at: one.at, payload: one.id);
    }
  }
}

/// Настоящие уведомления Android: канал «Напоминания», точные будильники, если разрешены.
class LocalNotificationPort implements NotificationPort {
  LocalNotificationPort({required this.channelName, required this.doneLabel, required this.snoozeLabel, this.returnChannelName = '', this.onOpen, this.onAction});

  final String channelName;

  /// Канал возвращающих уведомлений: «посмотреть потом», «в этот день», сводка.
  final String returnChannelName;
  final String doneLabel;
  final String snoozeLabel;

  /// Тап по уведомлению: открыть вещь.
  final ValueChanged<String>? onOpen;

  /// Кнопки «Готово» и «Через час»: система зовёт её в отдельном фоновом процессе Dart,
  /// приложение может быть закрыто. Функция верхнего уровня с `vm:entry-point`.
  final DidReceiveBackgroundNotificationResponseCallback? onAction;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _exact = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Часовой пояс и подписка на тапы. Если приложение открыли тапом — сразу открыть вещь.
  Future<void> start() async {
    if (_ready) return;
    zones.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      // незнакомый пояс: остаётся UTC, время всё равно считается от абсолютного момента
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_reminder')),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && response.actionId == null) onOpen?.call(id);
      },
      onDidReceiveBackgroundNotificationResponse: onAction,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && payload != null) onOpen?.call(payload);
    _ready = true;
  }

  @override
  Future<void> ensurePermission() async {
    await start();
    await _android?.requestNotificationsPermission();
    _exact = await _android?.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> cancelAll() async {
    await start();
    await _plugin.cancelAllPendingNotifications();
  }

  @override
  Future<void> show({required int id, required String title, required String body, required String payload}) async {
    await start();
    await _plugin.show(
      id: id,
      title: title,
      body: body.isEmpty ? null : body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'returns',
          returnChannelName,
          importance: Importance.low,
          priority: Priority.low,
          styleInformation: body.isEmpty ? null : BigTextStyleInformation(body),
        ),
      ),
      payload: payload,
    );
  }

  @override
  Future<void> schedule({required int id, required String title, required String body, required DateTime at, required String payload}) async {
    await start();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body.isEmpty ? null : body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          styleInformation: body.isEmpty ? null : BigTextStyleInformation(body),
          actions: [
            AndroidNotificationAction(reminderDone, doneLabel, cancelNotification: true),
            AndroidNotificationAction(reminderSnooze, snoozeLabel, cancelNotification: true),
          ],
        ),
      ),
      // без разрешения на точные будильники система может сдвинуть на несколько минут
      androidScheduleMode: _exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }
}
