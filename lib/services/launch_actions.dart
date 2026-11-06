import 'package:flutter/services.dart';

/// Откуда пришёл запуск: виджет рабочего стола просит строку или сразу запись голоса.
enum LaunchAction { compose, voice }

/// Канал с MainActivity: `initial` — с чем приложение открыли, `open` — касание
/// виджета или уведомления по месту, когда приложение уже живо.
const launchChannel = MethodChannel('stowa/launch');

LaunchAction? launchActionOf(String? raw) => LaunchAction.values.asNameMap()[raw];

/// Касание уведомления по месту (его показывает сам Android): `open:note:<id>` → `note:<id>`.
String? openPayloadOf(String? raw) => raw != null && raw.startsWith('open:') ? raw.substring(5) : null;

/// С чем приложение запустили: действие виджета или «open:…». Нет платформы (тесты, кадры) — null.
Future<String?> initialLaunch() async {
  try {
    return await launchChannel.invokeMethod<String>('initial');
  } on MissingPluginException {
    return null;
  }
}

/// Слушать касания виджета и уведомлений по месту, пока приложение открыто.
void listenLaunches(void Function(String raw) onLaunch) {
  launchChannel.setMethodCallHandler((call) async {
    if (call.method == 'open' && call.arguments is String) onLaunch(call.arguments as String);
  });
}
