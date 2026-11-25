import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import 'reminder_service.dart';
import 'sync/sync_http.dart' show syncServer;
import 'web_push_crypto.dart';

/// Уведомления браузера: открытая вкладка держит будильники и показывает их своим service
/// worker (`web/stowa_sw.js`) — только так у уведомления есть кнопки.
StartingNotificationPort? browserNotificationPort({required String doneLabel, required String snoozeLabel, required String removeLabel}) =>
    WebNotificationPort(doneLabel: doneLabel, snoozeLabel: snoozeLabel, removeLabel: removeLabel);

/// Касания уведомлений браузера, которые выполняет открытая вкладка.
Stream<NotificationTap> browserNotificationTaps(NotificationPort port) => port is WebNotificationPort ? port.taps : const Stream.empty();

/// Будильник, который ждёт своего часа.
typedef PlannedNotice = ({int id, String title, String body, DateTime at, String payload});

/// Уведомления в браузере. Будильник — таймер вкладки: пока вкладка открыта, уведомление
/// приходит в срок (скрытой вкладке браузер сдвигает таймеры до минуты). Закрыли вкладку —
/// напоминание присылает сервер Stowa через Web Push: план будильников уходит туда после
/// каждой правки, текст шифрует сама страница ключами своей подписки (RFC 8291), сервер его
/// не видит. Кнопки «Готово», «Через час» и «Убрать» service worker передаёт вкладке, которая
/// держит хранилище; вкладки нет — открывает Stowa с действием в адресе, и [start] выполняет
/// его при запуске.
class WebNotificationPort implements StartingNotificationPort {
  WebNotificationPort({required this.doneLabel, required this.snoozeLabel, required this.removeLabel});

  final String doneLabel;
  final String snoozeLabel;
  final String removeLabel;

  /// Таймер в браузере — `setTimeout`: дальше 24 дней он срабатывает сразу. Ставим только
  /// ближайшие, остальные встают при пересмотре раз в полчаса.
  static const _horizon = Duration(hours: 12);
  static const _recheck = Duration(minutes: 30);

  final _planned = <int, PlannedNotice>{};
  final _timers = <int, Timer>{};
  final _pending = <NotificationTap>[];
  final _listeners = <MultiStreamController<NotificationTap>>{};
  Timer? _rearm;
  bool _started = false;

  // свой service worker; не встал (частный режим Firefox) — null, и уведомлений нет: без него
  // у уведомления не было бы кнопок, а `ready` ждал бы вечно
  final _registration = Completer<web.ServiceWorkerRegistration?>();

  // ——— план для сервера: напоминания при закрытой вкладке ———

  Timer? _upload;
  String? _vapidKey;

  // правки будильников идут пачкой (пересчёт снимает все и ставит заново): план уходит один раз
  void _planChanged() {
    _upload?.cancel();
    _upload = Timer(const Duration(seconds: 2), () => unawaited(_sendPlan().catchError((Object _) {})));
  }

  Future<void> _sendPlan() async {
    final registration = await _registration.future;
    if (registration == null || !_allowed) return;
    final subscription = await _subscription(registration);
    if (subscription == null) return;
    final uaPublic = subscription.getKey('p256dh')?.toDart.asUint8List();
    final authSecret = subscription.getKey('auth')?.toDart.asUint8List();
    if (uaPublic == null || authSecret == null) return;
    final now = DateTime.now();
    final notices = <Map<String, Object>>[];
    for (final notice in planned.where((one) => one.at.isAfter(now)).take(100)) {
      final plaintext = webPushNotice(
        title: notice.title,
        body: notice.body,
        tag: 'reminder-${notice.id}',
        payload: notice.payload,
        actions: [(reminderDone, doneLabel), (reminderSnooze, snoozeLabel)],
      );
      final body = await _encrypt(plaintext, uaPublic, authSecret);
      notices.add({'id': notice.id, 'at': notice.at.toUtc().toIso8601String(), 'body': base64Url.encode(body).replaceAll('=', '')});
    }
    await http
        .put(Uri.parse('$syncServer/v1/push/plan'), headers: {'content-type': 'application/json'}, body: jsonEncode({'endpoint': subscription.endpoint, 'notices': notices}))
        .timeout(const Duration(seconds: 20));
  }

  // подписка этого браузера на push; нет — заводится с открытым ключом сервера
  Future<web.PushSubscription?> _subscription(web.ServiceWorkerRegistration registration) async {
    try {
      final manager = registration.pushManager;
      final existing = await manager.getSubscription().toDart;
      if (existing != null) return existing;
      final key = _vapidKey ??= (jsonDecode((await http.get(Uri.parse('$syncServer/v1/push/key')).timeout(const Duration(seconds: 20))).body) as Map)['key'] as String;
      final raw = Uint8List.fromList(base64Url.decode(base64Url.normalize(key)));
      return await manager.subscribe(web.PushSubscriptionOptionsInit(userVisibleOnly: true, applicationServerKey: raw.toJS)).toDart;
    } on Object {
      // браузер без push-службы (частный режим, сборка без ключей Google): только пока вкладка открыта
      return null;
    }
  }

  // своё тело на каждое сообщение: одноразовый ключ и соль
  Future<Uint8List> _encrypt(List<int> plaintext, List<int> uaPublic, List<int> authSecret) async {
    final ecdh = Ecdh.p256(length: 32);
    final pair = await ecdh.newKeyPair();
    final mine = await pair.extractPublicKey();
    final theirs = EcPublicKey(x: uaPublic.sublist(1, 33), y: uaPublic.sublist(33, 65), type: KeyPairType.p256);
    final shared = await (await ecdh.sharedSecretKey(keyPair: pair, remotePublicKey: theirs)).extractBytes();
    final random = Random.secure();
    return webPushBody(
      plaintext: plaintext,
      uaPublic: uaPublic,
      authSecret: authSecret,
      asPublic: [4, ...mine.x, ...mine.y],
      sharedSecret: shared,
      salt: [for (var index = 0; index < 16; index++) random.nextInt(256)],
    );
  }

  /// Все будильники, которые ждут: их же в срок отправит сервер, если вкладку закроют.
  List<PlannedNotice> get planned => [..._planned.values]..sort((a, b) => a.at.compareTo(b.at));

  /// Касания и кнопки уведомлений. Пришедшее до первого слушателя (Stowa открыли касанием,
  /// а главная ещё грузится) ждёт его.
  Stream<NotificationTap> get taps => Stream.multi((controller) {
    for (final tap in _pending) {
      controller.add(tap);
    }
    _pending.clear();
    _listeners.add(controller);
    controller.onCancel = () => _listeners.remove(controller);
  });

  void _deliver(NotificationTap tap) {
    if (_listeners.isEmpty) {
      _pending.add(tap);
      return;
    }
    for (final listener in _listeners) {
      listener.add(tap);
    }
  }

  web.ServiceWorkerContainer? get _workers {
    try {
      return web.window.navigator.serviceWorker;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final workers = _workers;
    if (workers == null) {
      _registration.complete(null);
    } else {
      workers.addEventListener('message', ((web.MessageEvent event) => _onWorkerMessage(event)).toJS);
      // без него сообщения service worker до вкладки не доходят: слушаем через addEventListener
      workers.startMessages();
      try {
        await workers.register('stowa_sw.js'.toJS).toDart;
        _registration.complete(await workers.ready.toDart.timeout(const Duration(seconds: 20)));
      } on Object {
        _registration.complete(null);
      }
    }
    _takeLaunchAction();
    _rearm = Timer.periodic(_recheck, (_) => _arm());
    // проснулись после сна компьютера: просроченное — сразу
    web.document.addEventListener('visibilitychange', ((web.Event _) => _arm()).toJS);
  }

  // кнопка нажата, когда вкладки не было: service worker открыл Stowa с действием в адресе
  void _takeLaunchAction() {
    final raw = Uri.base.queryParameters['notification'];
    if (raw == null) return;
    try {
      final message = jsonDecode(raw) as Map<String, Object?>;
      final tap = _tapOf(message);
      if (tap != null) _deliver(tap);
    } on Object {
      // испорченный адрес: просто открываем Stowa
    }
    // действие выполнено один раз: перезагрузка вкладки его не повторит
    final rest = {...Uri.base.queryParameters}..remove('notification');
    final path = Uri.base.path;
    web.window.history.replaceState(null, '', rest.isEmpty ? path : '$path?${Uri(queryParameters: rest).query}');
  }

  void _onWorkerMessage(web.MessageEvent event) {
    final data = event.data.dartify();
    if (data is! Map || data['type'] != 'stowa-notification') return;
    final tap = _tapOf(data.cast<String, Object?>());
    if (tap == null) return;
    // ответ service worker'у: эта вкладка держит хранилище и выполнит действие сама
    final ports = event.ports.toDart;
    if (ports.isNotEmpty) ports.first.postMessage('taken'.toJS);
    _deliver(tap);
  }

  NotificationTap? _tapOf(Map<String, Object?> message) {
    final payload = message['payload'];
    final action = message['action'];
    if (payload is! String || payload.isEmpty) return null;
    return (action: action is String && action.isNotEmpty ? action : notificationOpen, payload: payload);
  }

  bool get _allowed {
    try {
      return web.Notification.permission == 'granted';
    } on Object {
      return false;
    }
  }

  @override
  Future<void> ensurePermission() async {
    await start();
    try {
      if (web.Notification.permission == 'default') await web.Notification.requestPermission().toDart;
    } on Object {
      // браузер без уведомлений
    }
    // разрешили — будильники, поставленные до этого, тоже уходят серверу
    _planChanged();
  }

  @override
  Future<void> cancelAll() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _planned.clear();
    _planChanged();
  }

  @override
  Future<void> schedule({required int id, required String title, required String body, required DateTime at, required String payload}) async {
    _planned[id] = (id: id, title: title, body: body, at: at, payload: payload);
    _arm();
    _planChanged();
  }

  // поставить таймеры ближайшим; просроченное, пока вкладка спала, — показать сейчас
  void _arm() {
    final now = DateTime.now();
    for (final notice in [..._planned.values]) {
      final wait = notice.at.difference(now);
      if (wait > _horizon || _timers.containsKey(notice.id)) continue;
      _timers[notice.id] = Timer(wait.isNegative ? Duration.zero : wait, () => _fire(notice.id));
    }
  }

  void _fire(int id) {
    _timers.remove(id);
    final notice = _planned.remove(id);
    if (notice == null) return;
    // показала вкладка — сервер (он шлёт с запасом в 20 с) этого уже не пришлёт
    _planChanged();
    unawaited(
      _show(
        notice.title,
        body: notice.body,
        tag: 'reminder-$id',
        payload: notice.payload,
        // напоминание висит, пока его не сняли: как высокая важность на телефоне
        requireInteraction: true,
        actions: [(reminderDone, doneLabel), (reminderSnooze, snoozeLabel)],
      ),
    );
  }

  @override
  Future<void> show({required int id, required String title, required String body, required String payload}) =>
      // возвращающее — тихое: о нём человек не просил
      _show(title, body: body, tag: 'return-$id', payload: payload, silent: true);

  @override
  Future<void> showPinned({required int id, required String title, required String body, required String payload, required bool private}) => _show(
    title,
    // «Код на вход»: на чужих глазах компьютера — без текста, как экран блокировки телефона
    body: private ? '' : body,
    tag: 'pinned-$id',
    payload: payload,
    silent: true,
    requireInteraction: true,
    actions: [(noticeRemoveAction, removeLabel)],
  );

  @override
  Future<void> cancel(int id) async {
    _timers.remove(id)?.cancel();
    if (_planned.remove(id) != null) _planChanged();
    for (final notification in await _shown()) {
      if (notification.tag.endsWith('-$id')) notification.close();
    }
  }

  @override
  Future<List<int>> activePinned() async => [
    for (final notification in await _shown())
      if (notification.tag.startsWith('pinned-')) ?int.tryParse(notification.tag.substring(7)),
  ];

  Future<List<web.Notification>> _shown() async {
    final registration = await _registration.future;
    if (registration == null) return const [];
    try {
      return (await registration.getNotifications().toDart).toDart;
    } on Object {
      return const [];
    }
  }

  Future<void> _show(
    String title, {
    required String body,
    required String tag,
    required String payload,
    bool silent = false,
    bool requireInteraction = false,
    List<(String, String)> actions = const [],
  }) async {
    final registration = await _registration.future;
    if (registration == null || !_allowed) return;
    try {
      final data = JSObject()
        ..setProperty('payload'.toJS, payload.toJS)
        ..setProperty('tag'.toJS, tag.toJS);
      await registration
          .showNotification(
            title,
            web.NotificationOptions(
              body: body,
              tag: tag,
              icon: 'icons/Icon-192.png',
              badge: 'icons/Icon-192.png',
              silent: silent,
              requireInteraction: requireInteraction,
              data: data,
              actions: [for (final (action, label) in actions) web.NotificationAction(action: action, title: label)].toJS,
            ),
          )
          .toDart;
    } on Object {
      // браузер отказал (снят доступ посреди работы): без уведомления, заметка цела
    }
  }

  void dispose() {
    _rearm?.cancel();
    unawaited(cancelAll());
  }
}
