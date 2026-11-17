import 'dart:io' show Platform, pid;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Какая платформа под приложением. `Platform` из `dart:io` в браузере бросает
/// ошибку на любом вопросе, поэтому спрашиваем здесь.
bool get isWeb => kIsWeb;

bool get isAndroid => !kIsWeb && Platform.isAndroid;

bool get isIOS => !kIsWeb && Platform.isIOS;

/// Язык системы, как `Platform.localeName`: «ru_RU» на телефоне, «ru-RU» в браузере.
String get systemLocaleName => kIsWeb ? PlatformDispatcher.instance.locale.toLanguageTag() : Platform.localeName;

/// Название системы и её версия для отчётов: «android 15», «web».
String get operatingSystemName => kIsWeb ? 'web' : Platform.operatingSystem;

String get operatingSystemVersion => kIsWeb ? '' : Platform.operatingSystemVersion;

/// Номер этого запуска, как `pid`: в браузере процесса нет, каждая загрузка вкладки — новый номер.
int get currentProcessId => kIsWeb ? _webLoad : pid;

final _webLoad = DateTime.now().microsecondsSinceEpoch & 0x3fffffff;
