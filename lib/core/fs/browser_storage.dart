import 'web_store.dart';

/// Хранилище и журнал браузера. Вне браузера их нет: этот файл подменяется
/// `browser_storage_web.dart` при сборке для веба.
WebStore openBrowserStore() => throw UnsupportedError('Хранилище браузера есть только в браузере');

WebWal openBrowserWal() => throw UnsupportedError('Журнал браузера есть только в браузере');

/// Вкладку прячут или закрывают.
void onPageHide(void Function() callback) {}

/// Перед закрытием вкладки браузер переспросит, пока [pending] истинно.
void warnBeforeLeave(bool Function() pending) {}
