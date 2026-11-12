import 'package:flutter/services.dart';

/// С чем открыли окно виджета: строка с клавиатурой, сразу запись голоса или камера.
enum LaunchAction { compose, voice, camera }

/// Канал с окном. У главного: `initial` — с чем приложение открыли, `open` — касание
/// уведомления по месту или заметки в окне виджета, когда приложение уже живо.
/// У окна виджета: `initial` — какую кнопку нажали, `openNote` — открыть заметку в приложении.
const launchChannel = MethodChannel('stowa/launch');

LaunchAction? launchActionOf(String? raw) => LaunchAction.values.asNameMap()[raw];

/// Касание уведомления по месту (его показывает сам Android): `open:note:<id>` → `note:<id>`.
String? openPayloadOf(String? raw) => raw != null && raw.startsWith('open:') ? raw.substring(5) : null;

/// С чем окно запустили: кнопка виджета или «open:…». Нет платформы (тесты, кадры) — null.
Future<String?> initialLaunch() async {
  try {
    return await launchChannel.invokeMethod<String>('initial');
  } on MissingPluginException {
    return null;
  }
}

/// Кнопка виджета, с которой открыли его окно. Не узнали — строка.
Future<LaunchAction> quickAction() async => launchActionOf(await initialLaunch()) ?? LaunchAction.compose;

/// Из окна виджета: открыть заметку в самом приложении.
Future<void> openNoteInApp(String id) async {
  try {
    await launchChannel.invokeMethod<void>('openNote', id);
  } on MissingPluginException {
    // платформы нет: открывать негде
  }
}

/// Слушать касания уведомлений по месту и заметок из окна виджета, пока приложение открыто.
void listenLaunches(void Function(String raw) onLaunch) {
  launchChannel.setMethodCallHandler((call) async {
    if (call.method == 'open' && call.arguments is String) onLaunch(call.arguments as String);
  });
}
