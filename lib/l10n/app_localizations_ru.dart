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

  @override
  String get panelTags => 'Теги';

  @override
  String get panelFolders => 'Папки';

  @override
  String get panelCommands => 'Команды';

  @override
  String panelFound(int count) {
    return 'Нашлось $count';
  }

  @override
  String get panelNothing => 'Ничего не нашлось';

  @override
  String get panelSimilar => 'Уже лежит похожее';

  @override
  String get panelFresh => 'Похожего нет, это новое';

  @override
  String get filterAll => 'Всё';

  @override
  String get kindsNote => 'Заметки';

  @override
  String get kindsLink => 'Ссылки';

  @override
  String get kindsVideo => 'Видео';

  @override
  String get kindsImage => 'Фото';

  @override
  String get kindsFile => 'Файлы';

  @override
  String get kindsVoice => 'Голос';

  @override
  String get kindNote => 'заметка';

  @override
  String get kindLink => 'ссылка';

  @override
  String get kindVideo => 'видео';

  @override
  String get kindImage => 'фото';

  @override
  String get kindFile => 'файл';

  @override
  String get kindVoice => 'голосовое';

  @override
  String get foundInTranscript => 'в расшифровке';

  @override
  String get foundOnImage => 'на картинке';

  @override
  String get foundInDescription => 'в описании';

  @override
  String get dateToday => 'сегодня';

  @override
  String get dateYesterday => 'вчера';

  @override
  String get saveWhatNote => 'Закинуть';

  @override
  String get saveWhatLink => 'Ссылку';

  @override
  String get saveWhatVideo => 'Видео';

  @override
  String saveWhatPhotos(int count) {
    return '$count фото';
  }

  @override
  String saveWhatFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла',
      many: '$count файлов',
      few: '$count файла',
      one: '$count файл',
    );
    return '$_temp0';
  }

  @override
  String get saveWhatTask => 'Задача';

  @override
  String saveWhatList(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Список, $count пункта',
      many: 'Список, $count пунктов',
      few: 'Список, $count пункта',
      one: 'Список, $count пункт',
    );
    return '$_temp0';
  }

  @override
  String saveInto(String what, String folder) {
    return '$what в «$folder»';
  }

  @override
  String saveNoFolder(String what) {
    return '$what, папку подберу';
  }

  @override
  String saveRemind(String when) {
    return 'Напомнить $when';
  }

  @override
  String get saveRemindBare => 'Напомнить';

  @override
  String get saveAsIs => 'Без папки, как есть';

  @override
  String saveRemindAt(String when) {
    return 'напомню $when';
  }

  @override
  String get saveRemindWhen => 'когда? допиши «завтра в 10»';

  @override
  String get savePhotosHint => 'подпись и теги допишет твой ключ ИИ';

  @override
  String get reasonChosen => 'ты выбрал папку сам';

  @override
  String reasonTag(String tag) {
    return 'по тегу #$tag, без сети';
  }

  @override
  String reasonWord(String word) {
    return 'по слову «$word», без сети';
  }

  @override
  String reasonDomain(String domain) {
    return 'по ссылке на $domain, без сети';
  }

  @override
  String get reasonKind => 'по виду вещи, без сети';

  @override
  String get reasonNone => 'папку подберёт твой ключ ИИ';

  @override
  String get reasonAsIs => 'без разбора, как просил';

  @override
  String get actionStow => 'Закинуть';

  @override
  String get actionRemind => 'Напомнить';

  @override
  String get actionOpen => 'Открыть';

  @override
  String get actionInsert => 'Вставить';

  @override
  String get actionCreate => 'Создать';

  @override
  String get actionAppend => 'Дописать';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вещи',
      many: '$count вещей',
      few: '$count вещи',
      one: '$count вещь',
    );
    return '$_temp0';
  }

  @override
  String tagCreate(String name) {
    return 'Создать #$name';
  }

  @override
  String get tagCreateHint => 'иконку выберешь потом';

  @override
  String get cmdRemind => 'напомнить';

  @override
  String get cmdTask => 'задача';

  @override
  String get cmdList => 'список';

  @override
  String get cmdFind => 'найти';

  @override
  String get cmdInbox => 'входящие';

  @override
  String get cmdRemindHint => 'Скажи когда: «завтра в 10», «в пт»';

  @override
  String get cmdTaskHint => 'Ляжет с галочкой';

  @override
  String get cmdListHint => 'Каждая строка или запятая станет пунктом';

  @override
  String get cmdFindHint => 'Только искать, ничего не сохранять';

  @override
  String get cmdInboxHint => 'Положить как есть, без разбора';

  @override
  String savedInto(String folder) {
    return 'Легло в «$folder»';
  }

  @override
  String savedIntoRemind(String folder, String when) {
    return 'Легло в «$folder», напомню $when';
  }

  @override
  String appendedTo(String title) {
    return 'Дописал в «$title»';
  }

  @override
  String get voiceSaved => 'Голосовое легло, расшифрует твой ключ ИИ';

  @override
  String get voiceTitle => 'Голосовое';

  @override
  String get voiceCancel => 'Отменить запись';

  @override
  String get voiceDenied => 'Нет доступа к микрофону';

  @override
  String get voiceRecord => 'Записать голосовое';

  @override
  String get suggestClip => 'Ссылка из буфера';

  @override
  String get suggestShot => 'Скриншот';

  @override
  String minutesAgo(int count) {
    return '$count мин назад';
  }

  @override
  String get justNow => 'только что';

  @override
  String get trayGallery => 'Галерея';

  @override
  String get trayCamera => 'Камера';

  @override
  String get trayFile => 'Файл';

  @override
  String get trayLink => 'Ссылка';

  @override
  String get trayVideo => 'Видео';

  @override
  String get trayAccess => 'Дай доступ к фото, и выбирать можно прямо здесь';

  @override
  String get trayAllow => 'Разрешить';

  @override
  String get trayEmpty => 'В галерее пусто';

  @override
  String get trayNoLink => 'В буфере нет ссылки';

  @override
  String get fullHint => 'Пиши в Markdown, файлы прикрепляй плюсом';

  @override
  String get fullPickFolder => 'Папку подберу';

  @override
  String get fullExpand => 'На весь экран';

  @override
  String get fullCollapse => 'Свернуть';

  @override
  String get folderPickTitle => 'Куда положить';

  @override
  String get mdHeading => 'Заголовок';

  @override
  String get mdBold => 'Жирный';

  @override
  String get mdItalic => 'Курсив';

  @override
  String get mdStrike => 'Зачеркнуть';

  @override
  String get mdBullets => 'Список';

  @override
  String get mdChecklist => 'Чек-лист';

  @override
  String get mdQuote => 'Цитата';

  @override
  String get mdCode => 'Код';

  @override
  String get mdUndo => 'Отменить';

  @override
  String get mdRedo => 'Вернуть';

  @override
  String get removeChip => 'Убрать';

  @override
  String get pinTag => 'Поставить тег';

  @override
  String get itemCopy => 'Скопировать текст';

  @override
  String get itemCopied => 'Скопировал';

  @override
  String get itemDelete => 'Удалить';

  @override
  String get itemDeleted => 'Удалил';

  @override
  String get itemTranscript => 'Расшифровка';

  @override
  String get itemDescription => 'Что на картинке';

  @override
  String get itemFiles => 'Файлы';

  @override
  String itemMoved(String folder) {
    return 'Переложил в «$folder»';
  }

  @override
  String get itemSortingBadge => 'разбираю';

  @override
  String reasonName(String name) {
    return 'по имени «$name», без сети';
  }

  @override
  String reasonSimilar(String words) {
    return 'по словам «$words», без сети';
  }

  @override
  String folderCreate(String name) {
    return 'Создать папку «$name»';
  }

  @override
  String get folderCreateHint => 'иконку и форму поменяешь потом';

  @override
  String get folderBoard => 'Доска';

  @override
  String get folderList => 'Список';

  @override
  String get folderSearch => 'Искать в папке';

  @override
  String get folderMore => 'Ещё';

  @override
  String get folderRename => 'Переименовать';

  @override
  String get folderLook => 'Иконка и форма';

  @override
  String get folderDelete => 'Удалить папку';

  @override
  String get folderNameLabel => 'Имя папки';

  @override
  String get save => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String folderDeleteAsk(String name) {
    return 'Удалить «$name»? Вещи из неё останутся без папки.';
  }

  @override
  String get folderDeleted => 'Папка удалена';

  @override
  String get restoreAction => 'Вернуть';

  @override
  String get folderEmpty =>
      'Здесь пока пусто. Закинь что-нибудь в строку снизу — ляжет сюда.';

  @override
  String get dropHere => 'Закинуть сюда';

  @override
  String get lookIcon => 'Иконка';

  @override
  String get lookShape => 'Форма';

  @override
  String get voiceNoTranscript => 'Без расшифровки: её сделает твой ключ ИИ';

  @override
  String get voiceTranscribed => 'Голосовое, расшифровано';

  @override
  String get voicePlay => 'Слушать';

  @override
  String get voicePause => 'Пауза';

  @override
  String get reminderChannel => 'Напоминания';

  @override
  String get shareSaved => 'Сохранено';

  @override
  String shareInFolder(String folder) {
    return 'в папке «$folder»';
  }

  @override
  String get shareNoFolder => 'пока без папки';

  @override
  String get shareOther => 'Или в другую';

  @override
  String get shareNewFolder => 'Новая';

  @override
  String get shareAddWords => 'Добавить пару слов';

  @override
  String get shareDone => 'Готово';

  @override
  String get tagsTitle => 'Теги и папки';

  @override
  String get tagsTab => 'Теги';

  @override
  String get foldersTab => 'Папки';

  @override
  String get tagsPinned => 'На главной';

  @override
  String get tagsPinnedHint => 'Зажми и перетащи, чтобы поменять порядок';

  @override
  String get tagsAll => 'Все теги';

  @override
  String get tagsNone =>
      'Тегов пока нет. Напиши #тег в строке или создай здесь.';

  @override
  String get rulesTitle => 'Правила';

  @override
  String get rulesNone =>
      'Правил пока нет: строка раскладывает по словам, которые уже лежат в папках.';

  @override
  String get ruleNew => 'Новое правило';

  @override
  String get ruleStays => 'остаётся, где лежит';

  @override
  String get tagNew => 'Новый тег';

  @override
  String get tagEdit => 'Тег';

  @override
  String get tagNameHint => 'имя тега';

  @override
  String get iconSymbols => 'Иконки';

  @override
  String get iconEmoji => 'Эмодзи';

  @override
  String get iconImage => 'Своя картинка';

  @override
  String get iconPickImage => 'Выбрать картинку';

  @override
  String get emojiHint => 'Одно эмодзи';

  @override
  String get tagToFolder => 'Класть в папку';

  @override
  String get tagPin => 'Закрепить на главной';

  @override
  String get tagCreateButton => 'Создать тег';

  @override
  String get tagDelete => 'Удалить тег';

  @override
  String tagDeleteAsk(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вещи',
      many: '$count вещей',
      few: '$count вещей',
      one: '$count вещи',
    );
    return 'Убрать тег #$name у $_temp0? Сами вещи останутся.';
  }

  @override
  String tagDeleted(String name) {
    return 'Тег #$name удалён';
  }

  @override
  String get ruleSheetTitle => 'Правило';

  @override
  String get ruleIf => 'Если';

  @override
  String get ruleThen => 'То';

  @override
  String get ruleIfTag => 'есть тег';

  @override
  String get ruleIfDomain => 'ссылка на сайт';

  @override
  String get ruleIfWord => 'есть слово';

  @override
  String get ruleIfKind => 'вид вещи';

  @override
  String get ruleThenFolder => 'в папку';

  @override
  String get ruleThenTag => 'поставить тег';

  @override
  String get ruleValueTag => 'тег без решётки';

  @override
  String get ruleValueDomain => 'tiktok.com';

  @override
  String get ruleValueWord => 'слово';

  @override
  String get ruleEnabled => 'Включено';

  @override
  String get ruleDelete => 'Удалить правило';

  @override
  String get settingsTooltip => 'Теги, папки и правила';

  @override
  String get tagAdd => 'Добавить тег';

  @override
  String get sortMode => 'Разобрать';

  @override
  String get sortSkip => 'Пропустить';

  @override
  String sortLeft(int count) {
    return 'Осталось $count';
  }

  @override
  String get sortDone => 'Всё разобрано';

  @override
  String get sortHint =>
      'Касание папки кладёт туда. Вниз — пропустить, вверх — в корзину';

  @override
  String get iconSearch => 'Найти иконку: машина, кофе, дом';

  @override
  String get itemMove => 'Переложить в папку';

  @override
  String get sortNewest => 'Сначала новые';

  @override
  String get sortOldest => 'Сначала старые';

  @override
  String get sortByName => 'По имени';

  @override
  String get sortTooltip => 'Порядок';

  @override
  String get reminderDoneAction => 'Готово';

  @override
  String get reminderSnoozeAction => 'Через час';

  @override
  String get folderPickNew => 'Новая папка';

  @override
  String get reminderCleared => 'Напоминание снято';

  @override
  String untitledPhoto(String date) {
    return 'Фото от $date';
  }

  @override
  String untitledScreenshot(String date) {
    return 'Скриншот от $date';
  }

  @override
  String untitledVideo(String date) {
    return 'Видео от $date';
  }

  @override
  String untitledAudio(String date) {
    return 'Запись от $date';
  }

  @override
  String untitledFile(String date) {
    return 'Файл от $date';
  }

  @override
  String get shareFailed =>
      'Не получилось сохранить: приложение не дало доступ';

  @override
  String get ruleDeleted => 'Правило удалено';

  @override
  String get itemEdit => 'Править';

  @override
  String get itemEditDone => 'Готово';

  @override
  String get itemTitleHint => 'Заголовок';

  @override
  String get itemBodyHint => 'Текст, списки, - [ ] дела';

  @override
  String get itemAddPhoto => 'Фото';

  @override
  String get itemRemind => 'Напомнить';

  @override
  String get itemReminderChange => 'Другое время';

  @override
  String get itemReminderRemove => 'Убрать напоминание';

  @override
  String get itemSaved => 'Сохранено';
}
