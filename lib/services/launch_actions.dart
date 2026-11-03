import 'package:flutter/services.dart';

/// Откуда пришёл запуск: виджет рабочего стола просит строку или сразу запись голоса.
enum LaunchAction { compose, voice }

/// Канал с MainActivity: `initial` — с чем приложение открыли, `open` — касание
/// виджета, когда приложение уже живо.
const launchChannel = MethodChannel('stowa/launch');

LaunchAction? _parse(Object? raw) => LaunchAction.values.asNameMap()[raw];

/// С чем приложение запустили. Нет платформы (тесты, кадры) — null.
Future<LaunchAction?> initialLaunchAction() async {
  try {
    return _parse(await launchChannel.invokeMethod<String>('initial'));
  } on MissingPluginException {
    return null;
  }
}

/// Слушать касания виджета, пока приложение открыто.
void listenLaunchActions(void Function(LaunchAction action) onAction) {
  launchChannel.setMethodCallHandler((call) async {
    final action = call.method == 'open' ? _parse(call.arguments) : null;
    if (action != null) onAction(action);
  });
}
