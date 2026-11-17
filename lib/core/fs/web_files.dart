import 'dart:io';

import 'browser_storage.dart' if (dart.library.js_interop) 'browser_storage_web.dart';
import 'web_fs.dart';

/// Файлы приложения в браузере; на телефоне null.
WebFileSystem? webFileSystem;

/// Папки браузерной сборки вместо `path_provider`: в хранилище сайта идут `/app` и `/vault`,
/// `/cache` живёт до перезагрузки вкладки.
Directory get webAppDirectory => Directory('/app');

Directory get webCacheDirectory => Directory('/cache');

/// Поднять файлы из личной папки сайта и подменить ими `File` и `Directory`.
Future<void> startWebFiles() async {
  final fs = WebFileSystem(openBrowserStore(), wal: openBrowserWal());
  await fs.hydrate();
  IOOverrides.global = WebIOOverrides(fs);
  webFileSystem = fs;
  for (final path in ['/app', '/cache', '/vault']) {
    await Directory(path).create(recursive: true);
  }
  // уходят с вкладки — дописать; не дописано — браузер переспросит перед закрытием
  onPageHide(() => fs.flush().ignore());
  warnBeforeLeave(() => fs.pending > 0);
}
