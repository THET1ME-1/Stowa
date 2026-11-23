import 'dart:async';
import 'dart:io' show Platform, pid;
import 'dart:isolate';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Какая платформа под приложением. `Platform` из `dart:io` в браузере бросает
/// ошибку на любом вопросе, поэтому спрашиваем здесь.
bool get isWeb => kIsWeb;

bool get isAndroid => !kIsWeb && Platform.isAndroid;

bool get isIOS => !kIsWeb && Platform.isIOS;

/// Код идёт в `flutter test`: там нет настоящих таймеров ожидания и фонового счёта.
bool get inFlutterTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// Тяжёлый счёт в стороне от главного потока: раскладка графа, текст документа, QR.
/// В браузере изолятов нет, и `Isolate.run` там бросает ошибку («Граф не построился»),
/// поэтому там счёт идёт на месте, после передышки. **Вместо `Isolate.run` звать это.**
Future<T> aside<T>(FutureOr<T> Function() work) => kIsWeb ? Future<T>(work) : Isolate.run(work);

/// Язык системы, как `Platform.localeName`: «ru_RU» на телефоне, «ru-RU» в браузере.
String get systemLocaleName => kIsWeb ? PlatformDispatcher.instance.locale.toLanguageTag() : Platform.localeName;

/// Название системы и её версия для отчётов: «android 15», «web».
String get operatingSystemName => kIsWeb ? 'web' : Platform.operatingSystem;

String get operatingSystemVersion => kIsWeb ? '' : Platform.operatingSystemVersion;

/// Номер этого запуска, как `pid`: в браузере процесса нет, каждая загрузка вкладки — новый номер.
int get currentProcessId => kIsWeb ? _webLoad : pid;

final _webLoad = DateTime.now().microsecondsSinceEpoch & 0x3fffffff;
