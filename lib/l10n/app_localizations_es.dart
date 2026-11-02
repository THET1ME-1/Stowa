// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class LEs extends L {
  LEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Stowa';

  @override
  String get composerHint => 'Drop anything or search';

  @override
  String get homeRecent => 'Just now';

  @override
  String get homeFolders => 'Folders';

  @override
  String get homeEmpty =>
      'Nothing here yet. Drop the first thing into the line below.';
}
