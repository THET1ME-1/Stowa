import 'dart:typed_data';

import 'web_store.dart';

/// Хранилище и журнал браузера. Вне браузера их нет: этот файл подменяется
/// `browser_storage_web.dart` при сборке для веба.
WebStore openBrowserStore() => throw UnsupportedError('Хранилище браузера есть только в браузере');

WebWal openBrowserWal() => throw UnsupportedError('Журнал браузера есть только в браузере');

/// Вкладку прячут или закрывают.
void onPageHide(void Function() callback) {}

/// Перед закрытием вкладки браузер переспросит, пока [pending] истинно.
void warnBeforeLeave(bool Function() pending) {}

/// Занять хранилище этой вкладкой. Файлы и базу в браузере держит одна вкладка: две разом
/// испортили бы их. false — Stowa уже открыта в другой вкладке. Замок держится, пока
/// вкладка жива, и снимается сам, когда её закрыли или перезагрузили.
Future<bool> claimTab() async => true;

/// Дождаться, пока хранилище освободится: ту вкладку закрыли или она ушла по просьбе.
Future<void> waitForTab() async {}

/// Попросить вкладку, которая держит хранилище, дописать своё и уйти.
void askTabToLeave() {}

/// [leave] — другая вкладка попросила хранилище себе: дописать своё и уйти.
void onTabTakenOver(Future<void> Function() leave) {}

/// Перезагрузить вкладку: замок хранилища при этом снимается.
void reloadPage() {}

/// Следить за подстановкой менеджера паролей в поле страницы с `autocomplete` [hint]
/// («email»). Менеджер забирает фокус в своё окошко, Flutter закрывает ввод, и значение,
/// записанное потом прямо в поле страницы, до приложения не доходит. Вне браузера — ничего.
/// Возвращает, чем перестать следить.
void Function() watchAutofill(String hint, void Function(String value) onFill) => () {};

/// Попросить браузер не стирать заметки сайта, когда на диске мало места.
/// true — браузер обещал.
Future<bool> persistStorage() async => true;

/// Файл, который браузер скачает человеку. Копится кусками на стороне браузера, а не
/// в памяти приложения: резервная копия большого хранилища иначе не поместилась бы.
abstract class BrowserDownload {
  void add(Uint8List chunk);

  /// Отдать накопленное под именем [name]: браузер кладёт файл в «Загрузки».
  void save(String name);
}

BrowserDownload startDownload() => throw UnsupportedError('Скачивание файлом есть только в браузере');
