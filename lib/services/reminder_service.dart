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

/// «Убрать» на заметке, закреплённой в уведомлениях.
const noticeRemoveAction = 'notice_remove';

/// Категории уведомлений iPhone: какие кнопки у напоминания и у закреплённой заметки.
const reminderCategory = 'reminder';
const pinnedCategory = 'pinned';

/// Стопка закреплённых в шторке. На iPhone по ней закреплённые и узнаются: каналов там нет.
const pinnedGroup = 'stowa.pinned';

/// Вечернее возвращающее, поставленное заранее (iPhone: фон там не обещает проснуться к вечеру).
/// Пересчёт напоминаний его не снимает.
const returnPlannedNotificationId = 7000002;

/// Кнопки уведомлений iPhone. Без `foreground` кнопка выполняется фоновым процессом Dart и
/// приложение не открывает — как на Android. Подписи уходят в систему один раз за запуск.
List<DarwinNotificationCategory> darwinCategories({required String done, required String snooze, required String remove}) => [
  DarwinNotificationCategory(
    reminderCategory,
    actions: [DarwinNotificationAction.plain(reminderDone, done), DarwinNotificationAction.plain(reminderSnooze, snooze)],
  ),
  DarwinNotificationCategory(pinnedCategory, actions: [DarwinNotificationAction.plain(noticeRemoveAction, remove)]),
];

/// Закреплённое ли это уведомление: Android узнаёт его по каналу, iPhone — по стопке.
bool isPinnedNotification({String? channelId, String? groupKey}) => channelId == 'pinned' || groupKey == pinnedGroup;

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

/// Адрес уведомления скрытой заметки: касание сперва просит код.
String hiddenReminderPayload(String itemId) => 'hidden:$itemId';

/// Id заметки из адреса уведомления, скрытой или обычной.
String reminderItemId(String payload) => payload.startsWith('hidden:') ? payload.substring(7) : payload;

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

  @override
  Future<void> scheduleQuiet({required int id, required String title, required String body, required DateTime at, required String payload}) async {}

  @override
  Future<void> showPinned({required int id, required String title, required String body, required String payload, required bool private}) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<List<int>> activePinned() async => const [];
}

/// Система уведомлений за тонкой стенкой: в тестах её подменяют.
abstract interface class NotificationPort {
  /// Разрешение на уведомления: спрашивается по действию человека, не при открытии.
  Future<void> ensurePermission();

  /// Снять запланированные будильники напоминаний. Уже показанные уведомления остаются:
  /// пересчёт при открытии приложения не должен стирать вечернее «посмотреть потом».
  Future<void> cancelAll();

  Future<void> schedule({required int id, required String title, required String body, required DateTime at, required String payload});

  /// Показать сейчас, в тихом канале «Возвращение»: то, о чём человек не просил, не звенит.
  Future<void> show({required int id, required String title, required String body, required String payload});

  /// То же тихое уведомление, но в назначенный момент: на iPhone вечернее возвращающее ставится
  /// заранее, фон к вечеру может и не проснуться. Его не снимает [cancelAll].
  Future<void> scheduleQuiet({required int id, required String title, required String body, required DateTime at, required String payload});

  /// Заметка, закреплённая в уведомлениях: тихо, без смахивания на экране блокировки, с
  /// кнопкой «Убрать». [private] — на экране блокировки без текста («Код на вход»).
  Future<void> showPinned({required int id, required String title, required String body, required String payload, required bool private});

  /// Снять одно уведомление.
  Future<void> cancel(int id);

  /// Номера закреплённых уведомлений, которые висят сейчас, — и от прошлых запусков.
  Future<List<int>> activePinned();
}

/// Порт, которому нужен запуск после первого кадра: подписка на касания и разбор запуска
/// касанием по уведомлению.
abstract interface class StartingNotificationPort implements NotificationPort {
  Future<void> start();
}

/// Касание уведомления ([action] — `open`) или его кнопки (`done`, `snooze`, `notice_remove`)
/// там, где кнопку выполняет само приложение, а не фоновый процесс: в браузере.
typedef NotificationTap = ({String action, String payload});

/// Действие «просто открыть» у [NotificationTap].
const notificationOpen = 'open';

/// Держит будильники системы в согласии с базой. Любая правка напоминаний —
/// сохранение, «Готово», удаление, «Отменить» — ведёт к одному пересчёту.
class ReminderService {
  ReminderService(this._port, {this.extra});

  final NotificationPort _port;
  String? _last;

  /// Будильник не из заметок: «копия в облаке скоро сотрётся». Берётся из сохранённого снимка
  /// подписки на каждом пересчёте — пересчёт снимает все будильники разом, в любом окне
  /// приложения, и будильник, поставленный отдельно, пропал бы.
  final Future<Reminder?> Function(DateTime now)? extra;

  List<Reminder>? _reminders;

  /// Пересчитать с прошлым списком напоминаний: поменялось только [extra]. Списка ещё не было —
  /// ничего не трогаем: снять будильники, не зная напоминаний, значит потерять их.
  Future<void> refresh(DateTime now) async {
    if (_reminders case final reminders?) await sync(reminders, now);
  }

  Future<void> sync(List<Reminder> reminders, DateTime now) async {
    _reminders = reminders;
    final own = await extra?.call(now).catchError((Object _) => null);
    final coming = [...reminders, ?own].where((one) => one.at.isAfter(now)).toList()..sort((a, b) => a.at.compareTo(b.at));
    final planned = coming.take(_limit).toList();
    // тот же список — системе ничего не говорим
    final key = planned.map((one) => '${one.id}|${one.at.toIso8601String()}|${one.title}|${one.body}').join('\n');
    if (key == _last) return;
    _last = key;
    // разрешение здесь не спрашиваем: пересчёт идёт при открытии, а окно должно появляться
    // по действию — поставил напоминание, включил возврат (askReminderPermissions)
    await _port.cancelAll();
    for (final one in planned) {
      await _port.schedule(id: notificationId(one.id), title: one.title, body: one.body, at: one.at, payload: one.id);
    }
  }
}

/// Настоящие уведомления: на Android канал «Напоминания» и точные будильники, если разрешены;
/// на iPhone — категории с теми же кнопками (`darwinCategories`).
class LocalNotificationPort implements StartingNotificationPort {
  LocalNotificationPort({
    required this.channelName,
    required this.doneLabel,
    required this.snoozeLabel,
    this.returnChannelName = '',
    this.pinnedChannelName = '',
    this.removeLabel = '',
    this.onOpen,
    this.onAction,
  });

  final String channelName;

  /// Канал возвращающих уведомлений: «посмотреть потом», «в этот день», сводка.
  final String returnChannelName;

  /// Канал закреплённых заметок и подпись кнопки «Убрать».
  final String pinnedChannelName;
  final String removeLabel;
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
  @override
  Future<void> start() async {
    if (_ready) return;
    zones.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      // незнакомый пояс: остаётся UTC, время всё равно считается от абсолютного момента
    }
    await _plugin.initialize(
      // на iPhone разрешение не спрашивается при запуске: только по действию человека, в ensurePermission
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('ic_stat_reminder'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: darwinCategories(done: doneLabel, snooze: snoozeLabel, remove: removeLabel),
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && response.actionId == null) onOpen?.call(id);
      },
      onDidReceiveBackgroundNotificationResponse: onAction,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && payload != null) onOpen?.call(payload);
    // точные будильники только узнаём: спрашивать нечего, USE_EXACT_ALARM выдан с установкой
    _exact = await _android?.canScheduleExactNotifications() ?? false;
    _ready = true;
  }

  @override
  Future<void> ensurePermission() async {
    await start();
    await _android?.requestNotificationsPermission();
    await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true);
    _exact = await _android?.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> cancelAll() async {
    await start();
    // на iPhone среди будущих лежит и вечернее возвращающее: его ставит не пересчёт напоминаний
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      await _plugin.cancelAllPendingNotifications();
      return;
    }
    for (final pending in await _plugin.pendingNotificationRequests()) {
      if (pending.id != returnPlannedNotificationId) await _plugin.cancel(id: pending.id);
    }
  }

  @override
  Future<void> scheduleQuiet({required int id, required String title, required String body, required DateTime at, required String payload}) async {
    await start();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body.isEmpty ? null : body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails('returns', returnChannelName, importance: Importance.low, priority: Priority.low),
        iOS: const DarwinNotificationDetails(presentSound: false, interruptionLevel: InterruptionLevel.passive),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
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
        iOS: const DarwinNotificationDetails(presentSound: false, interruptionLevel: InterruptionLevel.passive),
      ),
      payload: payload,
    );
  }

  @override
  Future<void> showPinned({required int id, required String title, required String body, required String payload, required bool private}) async {
    await start();
    await _plugin.show(
      id: id,
      title: title,
      body: body.isEmpty ? null : body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'pinned',
          pinnedChannelName,
          // обычная важность: бесшумные (low) Android по умолчанию прячет из строки состояния,
          // а значок там и нужен. Звука и вибрации нет, поверх экрана не выскакивает
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: false,
          enableVibration: false,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: false,
          visibility: private ? NotificationVisibility.private : NotificationVisibility.public,
          groupKey: pinnedGroup,
          styleInformation: body.isEmpty ? null : BigTextStyleInformation(body),
          actions: [AndroidNotificationAction(noticeRemoveAction, removeLabel, cancelNotification: true)],
        ),
        // iPhone не умеет «не смахивается»: смахнутое ставится снова при возврате в приложение,
        // поэтому баннером поверх экрана оно не выскакивает — только тихо ложится в шторку.
        // Скрыть текст на заблокированном экране там может только сам человек («Показ миниатюр»)
        iOS: const DarwinNotificationDetails(
          presentBanner: false,
          presentList: true,
          presentSound: false,
          interruptionLevel: InterruptionLevel.passive,
          threadIdentifier: pinnedGroup,
          categoryIdentifier: pinnedCategory,
        ),
      ),
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await start();
    await _plugin.cancel(id: id);
  }

  @override
  Future<List<int>> activePinned() async {
    await start();
    try {
      final active = await _plugin.getActiveNotifications();
      return [
        for (final one in active)
          if (isPinnedNotification(channelId: one.channelId, groupKey: one.groupKey) && one.id != null) one.id!,
      ];
    } on Object {
      return const [];
    }
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
        iOS: const DarwinNotificationDetails(categoryIdentifier: reminderCategory, interruptionLevel: InterruptionLevel.active),
      ),
      // без разрешения на точные будильники система может сдвинуть на несколько минут
      androidScheduleMode: _exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }
}
