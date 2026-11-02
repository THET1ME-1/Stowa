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

  @override
  String get homeNext => 'Ближайшее';

  @override
  String homeMoreToday(Object count) {
    return 'ещё $count';
  }

  @override
  String get homeReminderDone => 'Готово';

  @override
  String get homeAll => 'Все';

  @override
  String get folderNone => 'Без папки';

  @override
  String get itemSorting => 'разбираю';

  @override
  String get folderNew => 'новая';

  @override
  String remindToday(Object time) {
    return 'сегодня в $time';
  }

  @override
  String remindTomorrow(Object time) {
    return 'завтра в $time';
  }

  @override
  String remindOn(Object date, Object time) {
    return '$date в $time';
  }

  @override
  String get composerStow => 'Закинуть';

  @override
  String composerRemind(Object when) {
    return 'Напомню $when';
  }

  @override
  String get composerRemoveReminder => 'Не напоминать';

  @override
  String get composerAttach => 'Прикрепить';

  @override
  String get composerAddTag => 'Тег';

  @override
  String get composerGoesTo => 'Ляжет так';

  @override
  String get attachGallery => 'Фото и видео';

  @override
  String get attachCamera => 'Снять фото';

  @override
  String get attachFile => 'Файлы';

  @override
  String get savedToast => 'Закинул';

  @override
  String savedWithReminder(Object when) {
    return 'Закинул, напомню $when';
  }

  @override
  String get undo => 'Отменить';

  @override
  String get saveFailed => 'Не сохранилось, текст вернул в строку';

  @override
  String get removeAttachment => 'Убрать';

  @override
  String get attachGalleryHint => 'Сразу несколько';

  @override
  String get attachVideo => 'Снять видео';

  @override
  String get attachFileHint => 'Любой формат: документы, текст, архивы';

  @override
  String get attachFailed => 'Не открылось. Попробуй ещё раз';
}
