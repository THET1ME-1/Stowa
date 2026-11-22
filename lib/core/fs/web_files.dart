import 'dart:io';

import 'browser_storage.dart' if (dart.library.js_interop) 'browser_storage_web.dart';
import 'web_fs.dart';
import 'web_store.dart';

export 'browser_storage.dart' if (dart.library.js_interop) 'browser_storage_web.dart' show BrowserDownload, askTabToLeave, claimTab, markPanelYield, panelJustYielded, persistStorage, reloadPage, startDownload, waitForTab, watchAutofill;

/// Другая вкладка попросила хранилище себе: дописать файлы и перезагрузиться. Замок при
/// этом снимается, а эта вкладка после перезагрузки покажет «Stowa уже открыта в другой вкладке».
void leaveWhenAsked() => onTabTakenOver(() async {
  await webFileSystem?.flush().catchError((_) {});
  reloadPage();
});

/// Файлы приложения в браузере; на телефоне null.
WebFileSystem? webFileSystem;

/// Папки браузерной сборки вместо `path_provider`: в хранилище сайта идут `/app` и `/vault`,
/// `/cache` живёт до перезагрузки вкладки.
Directory get webAppDirectory => Directory('/app');

Directory get webCacheDirectory => Directory('/cache');

/// Файлы боковой панели, пока хранилище держит вкладка (STOWA-9): только в памяти, личную
/// папку сайта панель не трогает. Здесь лежат выбранные файлы, голос и черновики строки,
/// пока панель не отдала их вкладке байтами.
Future<void> startPanelFiles() async {
  final fs = WebFileSystem(MemoryWebStore(), wal: MemoryWebWal());
  await fs.hydrate();
  IOOverrides.global = WebIOOverrides(fs);
  for (final path in ['/app', '/cache', '/vault']) {
    await Directory(path).create(recursive: true);
  }
}

/// Поднять файлы из личной папки сайта и подменить ими `File` и `Directory`. [open] — папка
/// открытого хранилища: остальные хранилища браузера в память не читаются.
Future<void> startWebFiles({String? open}) async {
  final fs = WebFileSystem(openBrowserStore(), wal: openBrowserWal());
  await fs.hydrate(open: open);
  IOOverrides.global = WebIOOverrides(fs);
  webFileSystem = fs;
  for (final path in ['/app', '/cache', '/vault', '/vaults']) {
    await Directory(path).create(recursive: true);
  }
  // уходят с вкладки — дописать; не дописано — браузер переспросит перед закрытием
  onPageHide(() => fs.flush().ignore());
  warnBeforeLeave(() => fs.pending > 0);
}
