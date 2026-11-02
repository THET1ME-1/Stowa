// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class LRu extends L {
  LRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Stowa';

  @override
  String get composerHint => 'Закинь что угодно или найди';

  @override
  String get homeRecent => 'Только что';

  @override
  String get homeFolders => 'Папки';

  @override
  String get homeEmpty => 'Пока пусто. Закинь первую вещь в строку снизу.';
}
