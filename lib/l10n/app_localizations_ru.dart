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
  String get homeEmpty => 'Пока пусто. Закинь первую заметку в строку снизу.';

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
  String get savePhotosHint => 'подпись и теги можно дописать потом';

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
  String get reasonKind => 'по виду заметки, без сети';

  @override
  String get reasonNone => 'без папки, разложу, когда появится похожее';

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
      other: '$count заметки',
      many: '$count заметок',
      few: '$count заметки',
      one: '$count заметка',
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
  String get voiceSaved => 'Голосовое легло';

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
  String get folderLook => 'Цвет и значок';

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
    return 'Удалить «$name»? Заметки из неё останутся без папки.';
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
  String get voiceNoTranscript => 'Без расшифровки';

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
      other: '$count заметки',
      many: '$count заметок',
      few: '$count заметок',
      one: '$count заметки',
    );
    return 'Убрать тег #$name у $_temp0? Сами заметки останутся.';
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
  String get ruleIfKind => 'вид заметки';

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

  @override
  String get itemMore => 'Ещё';

  @override
  String get itemAppend => 'Дописать';

  @override
  String get itemShare => 'Поделиться';

  @override
  String get itemAutosave => 'Сохраняется само';

  @override
  String itemPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фото',
      many: '$count фото',
      few: '$count фото',
      one: '$count фото',
    );
    return '$_temp0';
  }

  @override
  String get tagAddShort => 'Тег';

  @override
  String get itemOpenLink => 'Открыть';

  @override
  String get itemWatch => 'Смотреть';

  @override
  String get fileOpenFailed => 'Нечем открыть такой файл';

  @override
  String get linkOpenFailed => 'Не получилось открыть ссылку';

  @override
  String photoCounter(Object count, Object index) {
    return '$index из $count';
  }

  @override
  String get photoToGallery => 'В галерею';

  @override
  String get photoSaved => 'Сохранил в галерею';

  @override
  String get photoSaveFailed =>
      'Не получилось сохранить: нет доступа к галерее';

  @override
  String get photoClose => 'Закрыть';

  @override
  String get voiceSpeed => 'Скорость';

  @override
  String autoSorted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Разложил $count похожих заметки',
      many: 'Разложил $count похожих заметок',
      few: 'Разложил $count похожие заметки',
      one: 'Разложил $count похожую заметку',
    );
    return '$_temp0';
  }

  @override
  String get relatedTitle => 'Связано';

  @override
  String relatedWords(Object words) {
    return 'общее: $words';
  }

  @override
  String relatedSite(Object site) {
    return 'тот же сайт, $site';
  }

  @override
  String get relatedHide => 'Не связывать';

  @override
  String get relatedHidden => 'Больше не покажу их рядом';

  @override
  String aiSortedInto(String folder) {
    return 'Положил в «$folder»';
  }

  @override
  String get aiOtherFolder => 'Другая';

  @override
  String get aiPausedAuth => 'Разбор на паузе: ключ не принят';

  @override
  String get aiPausedPayment => 'Разбор на паузе: на ключе кончились деньги';

  @override
  String get aiPausedAction => 'Проверить ключ';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsAi => 'Разбор ИИ';

  @override
  String get aiStateOff => 'Выключен';

  @override
  String get aiStateOffHint =>
      'Вставь свой ключ, и заметки без папки разложатся сами: с тегами, заголовком и описанием для поиска. Ключ хранится только на этом телефоне, запросы идут прямо к поставщику.';

  @override
  String get aiStateOn => 'Работает';

  @override
  String aiStateWait(String time) {
    return 'Поставщик просит подождать до $time';
  }

  @override
  String aiQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count заметки ждут разбора',
      many: '$count заметок ждут разбора',
      few: '$count заметки ждут разбора',
      one: '$count заметка ждёт разбора',
    );
    return '$_temp0';
  }

  @override
  String get aiSortNow => 'Разобрать сейчас';

  @override
  String get aiKey => 'Ключ';

  @override
  String get aiKeyNone => 'Не задан';

  @override
  String get aiKeySet => 'Задан';

  @override
  String get aiKeyPaste => 'Вставить';

  @override
  String get aiKeySave => 'Сохранить и проверить';

  @override
  String get aiKeyRemove => 'Удалить ключ';

  @override
  String get aiKeyWhere =>
      'Ключ берётся у поставщика: на OpenRouter — в разделе Keys. Есть бесплатные модели.';

  @override
  String get aiCheckOk => 'Ключ работает';

  @override
  String get aiCheckAuth => 'Поставщик не принял ключ';

  @override
  String get aiCheckPayment => 'На ключе нет денег';

  @override
  String get aiCheckRate => 'Поставщик просит подождать';

  @override
  String get aiCheckNetwork => 'Нет связи с поставщиком';

  @override
  String get aiCheckServer => 'Поставщик ответил ошибкой';

  @override
  String get aiProvider => 'Поставщик';

  @override
  String get aiProviderHint =>
      'Адрес API, совместимого с OpenAI. Без него — OpenRouter.';

  @override
  String get aiSortModel => 'Модель разбора';

  @override
  String get aiSpeechModel => 'Расшифровка голосовых';

  @override
  String get aiSpeechOff => 'Выключена';

  @override
  String get aiModelsSearch => 'Найти модель';

  @override
  String get aiModelFree => 'бесплатная';

  @override
  String get aiModelVision => 'видит фото';

  @override
  String get aiModelsNeedKey => 'Список моделей откроется после ключа';

  @override
  String get aiModelsFailed => 'Список моделей не загрузился';

  @override
  String aiModelOwn(String name) {
    return 'Своя: «$name»';
  }

  @override
  String get settingsOrder => 'Порядок';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get languageSystem => 'Как в системе';

  @override
  String settingsVersion(String version) {
    return 'Stowa $version';
  }

  @override
  String get trashTitle => 'Корзина';

  @override
  String get trashEmpty => 'Корзина пуста';

  @override
  String get trashHint =>
      'Удалённое лежит здесь 30 дней, потом стирается вместе с файлами.';

  @override
  String trashDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'сотрётся через $count дня',
      many: 'сотрётся через $count дней',
      few: 'сотрётся через $count дня',
      one: 'сотрётся через $count день',
    );
    return '$_temp0';
  }

  @override
  String trashFrom(String folder) {
    return 'из «$folder»';
  }

  @override
  String get trashPurge => 'Стереть насовсем';

  @override
  String get trashPurgeAll => 'Очистить корзину';

  @override
  String trashPurgeAllAsk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Стереть $count заметки насовсем? Вернуть их будет нельзя.',
      many: 'Стереть $count заметок насовсем? Вернуть их будет нельзя.',
      few: 'Стереть $count заметки насовсем? Вернуть их будет нельзя.',
      one: 'Стереть $count заметку насовсем? Вернуть её будет нельзя.',
    );
    return '$_temp0';
  }

  @override
  String trashRestored(String title) {
    return 'Вернул «$title»';
  }

  @override
  String get trashPurged => 'Стёрто насовсем';

  @override
  String get settingsData => 'Данные';

  @override
  String get backupSave => 'Сохранить копию';

  @override
  String get backupSaveHint =>
      'Вся Stowa одним файлом: заметки, папки, теги, правила и файлы. Ключа ИИ в копии нет.';

  @override
  String get backupRestore => 'Восстановить из копии';

  @override
  String backupRestoreAsk(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Заменить всё копией от $date? В ней $count заметки, нынешние пропадут.',
      many:
          'Заменить всё копией от $date? В ней $count заметок, нынешние пропадут.',
      few:
          'Заменить всё копией от $date? В ней $count заметки, нынешние пропадут.',
      one:
          'Заменить всё копией от $date? В ней $count заметка, нынешние пропадут.',
    );
    return '$_temp0';
  }

  @override
  String get backupReplace => 'Заменить';

  @override
  String get backupRestored => 'Восстановлено из копии';

  @override
  String get backupNotStowa => 'Это не копия Stowa';

  @override
  String get backupTooNew =>
      'Копию сделала более новая Stowa, обнови приложение';

  @override
  String get backupFailed => 'Копия не получилась';

  @override
  String get folderNewBadge => 'новая';

  @override
  String get aiSortingNow => 'Разбираю…';

  @override
  String get aiLog => 'Журнал запросов';

  @override
  String get aiLogEmpty => 'Запросов к поставщику ещё не было';

  @override
  String get aiLogCluster => 'Новые папки из «Без папки»';

  @override
  String get aiCheckTimeout => 'Модель не ответила вовремя';

  @override
  String get tgTitle => 'Свой бот Telegram';

  @override
  String get tgNone => 'Не подключён';

  @override
  String get tgHowTo =>
      '1. Открой @BotFather в Telegram и отправь /⁠newbot.\n2. Придумай боту имя, BotFather пришлёт токен.\n3. Вставь токен сюда.\n4. Напиши своему боту что угодно: с этого момента он слушает только тебя, а всё пересланное ему ложится в Stowa.';

  @override
  String get tgConnect => 'Подключить';

  @override
  String tgOwner(String name) {
    return 'Слушает только $name';
  }

  @override
  String get tgWaitingOwner => 'Напиши боту что угодно, чтобы он запомнил тебя';

  @override
  String get tgOpenBot => 'Открыть бота';

  @override
  String get tgDisconnect => 'Отключить бота';

  @override
  String get tgBadToken => 'Telegram не принял токен';

  @override
  String get tgOffline => 'Нет связи с Telegram';

  @override
  String tgPulled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Забрал $count сообщения',
      many: 'Забрал $count сообщений',
      few: 'Забрал $count сообщения',
      one: 'Забрал $count сообщение',
    );
    return '$_temp0';
  }

  @override
  String get settingsOutside => 'Снаружи';

  @override
  String selCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get selClear => 'Снять выбор';

  @override
  String get selAll => 'Выбрать все';

  @override
  String get selMove => 'В папку';

  @override
  String get selTag => 'Тег';

  @override
  String get selUntag => 'Снять тег';

  @override
  String get selDelete => 'Удалить';

  @override
  String selMoved(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Переложил $count заметки в «$folder»',
      many: 'Переложил $count заметок в «$folder»',
      few: 'Переложил $count заметки в «$folder»',
      one: 'Переложил $count заметку в «$folder»',
    );
    return '$_temp0';
  }

  @override
  String selDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалил $count заметки',
      many: 'Удалил $count заметок',
      few: 'Удалил $count заметки',
      one: 'Удалил $count заметку',
    );
    return '$_temp0';
  }

  @override
  String selTagged(String tag) {
    return 'Поставил #$tag';
  }

  @override
  String selUntagged(String tag) {
    return 'Снял #$tag';
  }

  @override
  String get tagPickTitle => 'Какой тег';

  @override
  String get folderCanvas => 'Холст';

  @override
  String get canvasFit => 'Уместить всё';

  @override
  String get canvasNote => 'Записка';

  @override
  String get canvasNoteHint => 'Что написать на холсте';

  @override
  String get graphTitle => 'Граф связей';

  @override
  String get graphEmpty =>
      'Связей пока нет. Они появятся, когда заметки начнут перекликаться словами или ИИ свяжет их сам.';

  @override
  String get graphFailed => 'Граф не построился';

  @override
  String copyPartlyFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла не сохранились: приложение не дало доступ',
      many: '$count файлов не сохранились: приложение не дало доступ',
      few: '$count файла не сохранились: приложение не дало доступ',
      one: '$count файл не сохранился: приложение не дало доступ',
    );
    return '$_temp0';
  }

  @override
  String get mapTitle => 'Карта';

  @override
  String get mapEmpty =>
      'Пока нет заметок с местом. Новые заметки запомнят, где их сохранили, и встанут сюда.';

  @override
  String get mapWhereAmI => 'Где я';

  @override
  String get mapPlaceUnnamed => 'Место без названия';

  @override
  String get placeSetting => 'Запоминать, где сохранено';

  @override
  String get placeSettingHint =>
      'Место ставится после сохранения и видно на странице заметки и на карте. Координаты остаются на телефоне, наружу уходит только запрос названия улицы.';

  @override
  String panelLooking(Object what) {
    return 'Ищу: $what';
  }

  @override
  String get foundAtPlace => 'по месту';

  @override
  String fileSaving(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сохраняю $count файлов',
      few: 'Сохраняю $count файла',
      one: 'Сохраняю файл',
    );
    return '$_temp0';
  }

  @override
  String get fileSavingHint =>
      'Можно закрыть приложение: файл доляжет сам. Когда полоска пропадёт, оригинал можно удалить.';

  @override
  String get foundInFile => 'в файле';

  @override
  String get foundOnPage => 'на странице';

  @override
  String get foundInPhotoInfo => 'в данных фото';

  @override
  String documentSheet(Object name) {
    return 'лист «$name»';
  }

  @override
  String documentSlide(Object number) {
    return 'слайд $number';
  }

  @override
  String documentChapter(Object number) {
    return 'глава $number';
  }

  @override
  String get factCall => 'Позвонить';

  @override
  String get factWrite => 'Написать';

  @override
  String get factCopy => 'Скопировать';

  @override
  String photoTaken(Object date) {
    return 'Снято $date';
  }

  @override
  String foundInSubtitles(Object time) {
    return 'в субтитрах · $time';
  }

  @override
  String foundInChapters(Object time) {
    return 'в главах · $time';
  }

  @override
  String get foundInIngredients => 'в ингредиентах';

  @override
  String get foundAtAddress => 'по адресу';

  @override
  String get foundInHashtags => 'в хэштегах';

  @override
  String get watchFromHere => 'Смотреть с этого места';

  @override
  String get pageRecipe => 'рецепт';

  @override
  String get pageProduct => 'товар';

  @override
  String get pageEvent => 'событие';

  @override
  String get pagePlace => 'место';

  @override
  String get pageMovie => 'фильм';

  @override
  String get pageBook => 'книга';

  @override
  String get pageVideo => 'видео';

  @override
  String get pageArticle => 'статья';

  @override
  String minutesShort(Object count) {
    return '$count мин';
  }

  @override
  String servings(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count порций',
      few: '$count порции',
      one: '$count порция',
    );
    return '$_temp0';
  }

  @override
  String readingMinutes(Object count) {
    return '$count мин чтения';
  }

  @override
  String get inStock => 'В наличии';

  @override
  String get outOfStock => 'Нет в наличии';

  @override
  String get toShoppingList => 'В список покупок';

  @override
  String shoppingFor(Object name) {
    return 'Купить: $name';
  }

  @override
  String get shoppingReady => 'Список покупок готов';

  @override
  String get chaptersTitle => 'Главы';

  @override
  String get authorTags => 'Теги автора';

  @override
  String get pageSeries => 'сериал';

  @override
  String get pageComic => 'манга';

  @override
  String get adultSetting => 'Показывать 18+';

  @override
  String get adultSettingHint =>
      'Страницы, которые сами помечают себя как 18+, и известные сайты для взрослых. Пока выключено, их обложки размыты, а описания скрыты. Заметка и поиск по ней остаются.';

  @override
  String get adultHidden =>
      'Описание скрыто: 18+. Показ включается в настройках.';

  @override
  String get vaultSetupTitle => 'Где хранить заметки';

  @override
  String get vaultSetupHint =>
      'Заметки, фото и файлы лежат обычными файлами в папке. Её видно в файловом менеджере, её открывает Obsidian и синхронизирует Syncthing.';

  @override
  String get vaultCreate => 'Создать хранилище';

  @override
  String get vaultCreateHint =>
      'Новая папка в памяти телефона. Заметки останутся, даже если удалить приложение.';

  @override
  String get vaultCreateButton => 'Создать';

  @override
  String get vaultOpen => 'Открыть папку как хранилище';

  @override
  String get vaultOpenHint =>
      'Прежнее хранилище Stowa после переустановки или хранилище Obsidian.';

  @override
  String get vaultOpenButton => 'Открыть';

  @override
  String get vaultInApp => 'Хранить внутри приложения';

  @override
  String get vaultInAppHint =>
      'Без разрешений. При удалении приложения заметки пропадут.';

  @override
  String get vaultInAppButton => 'Выбрать';

  @override
  String get vaultInAppWarning =>
      'Заметки будут лежать внутри приложения и пропадут, если его удалить. Перенести их в обычную папку можно потом в настройках.';

  @override
  String get vaultInAppConfirm => 'Хранить внутри';

  @override
  String get vaultName => 'Имя хранилища';

  @override
  String get vaultPlace => 'Где создать';

  @override
  String get vaultAccessTitle => 'Нужен доступ к файлам';

  @override
  String get vaultAccessHint =>
      'Чтобы хранить заметки в обычной папке, Android просит разрешение «Доступ ко всем файлам». Stowa читает и пишет только папку хранилища.';

  @override
  String get vaultAccessGrant => 'Открыть настройки';

  @override
  String get vaultAccessDenied =>
      'Без доступа к файлам хранилище в памяти телефона не работает';

  @override
  String vaultMoving(int done, int total) {
    return 'Переношу: $done из $total';
  }

  @override
  String vaultBuilding(int done, int total) {
    return 'Собираю указатель: $done из $total';
  }

  @override
  String vaultMoveFailed(int count) {
    return 'Перенеслось не всё, не хватает: $count. Заметки остались на прежнем месте.';
  }

  @override
  String get vaultMissingTitle => 'Хранилище не найдено';

  @override
  String vaultMissingHint(String path) {
    return 'Папки $path нет или у Stowa забрали доступ к файлам. Заметки в приложении целы.';
  }

  @override
  String get vaultGrantAccess => 'Дать доступ';

  @override
  String get vaultChooseAgain => 'Выбрать папку';

  @override
  String get vaultSection => 'Хранилище';

  @override
  String get vaultFolder => 'Папка';

  @override
  String get vaultInsideApp => 'Внутри приложения';

  @override
  String get vaultMoveTo => 'Перенести в другую папку';

  @override
  String get vaultRebuild => 'Пересобрать указатель';

  @override
  String get vaultSettingHint =>
      'Заметки лежат файлами .md: эту папку открывает Obsidian и синхронизирует Syncthing. Указатель — служебная база для поиска, приложение собирает его само.';

  @override
  String get vaultMoved => 'Хранилище перенесено';

  @override
  String get vaultRebuilt => 'Указатель собран';

  @override
  String vaultSyncing(int done, int total) {
    return 'Синхронизация заметок $done из $total';
  }

  @override
  String repeatIn(String folder, String date) {
    return 'Такая же лежит в папке «$folder» с $date';
  }

  @override
  String repeatNoFolder(String date) {
    return 'Такая же лежит без папки с $date';
  }

  @override
  String get settingsImport => 'Перенос';

  @override
  String get importTelegram => 'Из Telegram';

  @override
  String get importTelegramHint =>
      'Выбери папку выгрузки «Избранного» из Telegram Desktop — HTML или JSON. Заметки встанут со своими датами, альбом — одной заметкой.';

  @override
  String importProgress(int done, int total) {
    return 'Переношу $done из $total';
  }

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Перенёс $count заметки',
      many: 'Перенёс $count заметок',
      few: 'Перенёс $count заметки',
      one: 'Перенёс $count заметку',
    );
    return '$_temp0';
  }

  @override
  String importRepeated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count уже были',
      many: '$count уже были',
      few: '$count уже были',
      one: '$count уже была',
    );
    return '$_temp0';
  }

  @override
  String get importNotTelegram =>
      'В этой папке нет выгрузки Telegram: нужен messages.html или result.json';

  @override
  String importMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла Telegram не выгрузил',
      many: '$count файлов Telegram не выгрузил',
      few: '$count файла Telegram не выгрузил',
      one: '$count файл Telegram не выгрузил',
    );
    return '$_temp0 — включи файлы в настройках выгрузки и перенеси ещё раз';
  }

  @override
  String importFilled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count перенесённой раньше получили файлы',
      many: '$count перенесённых раньше получили файлы',
      few: '$count перенесённые раньше получили файлы',
      one: '$count перенесённая раньше получила файлы',
    );
    return '$_temp0';
  }

  @override
  String get returnChannel => 'Возвращение';

  @override
  String get returnWatchTitle => 'Посмотреть потом';

  @override
  String returnVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ролика',
      many: '$count роликов',
      few: '$count ролика',
      one: '$count ролик',
    );
    return '$_temp0';
  }

  @override
  String returnArticles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count статьи',
      many: '$count статей',
      few: '$count статьи',
      one: '$count статья',
    );
    return '$_temp0';
  }

  @override
  String returnMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count минуты',
      many: '$count минут',
      few: '$count минуты',
      one: '$count минута',
    );
    return '$_temp0';
  }

  @override
  String returnAnd(String first, String second) {
    return '$first и $second';
  }

  @override
  String returnWatchBody(String what, String minutes) {
    return '$what — $minutes';
  }

  @override
  String returnYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count года назад',
      many: '$count лет назад',
      few: '$count года назад',
      one: 'Год назад',
    );
    return '$_temp0';
  }

  @override
  String get returnMonthAgo => 'Месяц назад';

  @override
  String get returnWeekAgo => 'Неделю назад';

  @override
  String returnDayOne(String title) {
    return '«$title»';
  }

  @override
  String returnDayMore(String title, int count) {
    return '«$title» и ещё $count';
  }

  @override
  String get returnOnThisDay => 'В этот день';

  @override
  String get returnWeekTitle => 'Неделя в Stowa';

  @override
  String returnWeekSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'За неделю $count заметки',
      many: 'За неделю $count заметок',
      few: 'За неделю $count заметки',
      one: 'За неделю $count заметка',
    );
    return '$_temp0';
  }

  @override
  String returnWeekUnopened(int count) {
    return '$count не открыты';
  }

  @override
  String returnWeekUnsorted(int count) {
    return '$count без папки';
  }

  @override
  String get returnWeekUnopenedTitle => 'Не открыты';

  @override
  String get returnWeekUnsortedTitle => 'Без папки';

  @override
  String returnShopTitle(String shop) {
    return 'В магазине «$shop»';
  }

  @override
  String returnShopMore(String items, int count) {
    return '$items и ещё $count';
  }

  @override
  String get returnShopping => 'Купить';

  @override
  String get settingsReturns => 'Возвращать';

  @override
  String get returnWeekSetting => 'Сводка недели';

  @override
  String get returnShoppingSetting => 'Покупки у магазина';

  @override
  String get returnEveningRow => 'Вечером в';

  @override
  String get returnQuietRow => 'Тихие часы';

  @override
  String get returnWeekDayRow => 'День сводки';

  @override
  String get returnSettingsHint =>
      'Не больше одного уведомления в день, тихо, без звука, и ничего в тихие часы. Свои напоминания по времени и месту не в счёт.';

  @override
  String returnRange(String from, String to) {
    return '$from–$to';
  }

  @override
  String get returnQuietFrom => 'Тихо с';

  @override
  String get returnQuietTo => 'Тихо до';

  @override
  String get returnWatchEmpty => 'Очередь пуста: всё свежее уже посмотрено.';

  @override
  String get returnDayEmpty => 'В этот день раньше ничего не сохраняли.';

  @override
  String get returnWeekEmpty => 'За неделю ничего не сохранено.';

  @override
  String get returnShoppingEmpty => 'Покупать нечего: списки отмечены.';

  @override
  String returnMinutesShort(int count) {
    return '$count мин';
  }

  @override
  String get returnsAskTitle => 'Возвращать сохранённое?';

  @override
  String get returnsAskBody =>
      'Вечером — одно тихое уведомление: что посмотреть, что было в этот день год назад, сводка недели. Не чаще раза в день.';

  @override
  String get returnsAskOn => 'Включить';

  @override
  String get returnsAskLater => 'Не сейчас';

  @override
  String get placeRemindHome => 'Напомнить дома';

  @override
  String get placeRemindWork => 'Напомнить на работе';

  @override
  String get placeRemindHere => 'Напомнить здесь';

  @override
  String get placeRemindShop => 'Напомнить в магазине';

  @override
  String placeRemindAt(String place) {
    return 'Напомнить: $place';
  }

  @override
  String get composerRemovePlace => 'Без напоминания по месту';

  @override
  String get placesTitle => 'Места';

  @override
  String get placesHome => 'Дом';

  @override
  String get placesWork => 'Работа';

  @override
  String get placesShops => 'Магазины';

  @override
  String get placesNotSet => 'Не задано';

  @override
  String placesWifi(String name) {
    return 'Wi-Fi: $name';
  }

  @override
  String get placesImHome => 'Я сейчас дома';

  @override
  String get placesImWork => 'Я сейчас на работе';

  @override
  String get placesImShop => 'Я в магазине — запомнить';

  @override
  String placesGuessHome(String name) {
    return 'Похоже, дом — $name';
  }

  @override
  String placesGuessWork(String name) {
    return 'Похоже, работа — $name';
  }

  @override
  String get placesRemove => 'Убрать';

  @override
  String get placesShopName => 'Как назвать магазин';

  @override
  String get placesSave => 'Сохранить';

  @override
  String get placesNoFix =>
      'Не вышло узнать, где ты. Проверь, что место на телефоне включено и разрешено Stowa.';

  @override
  String get placesPermissionTitle => 'Нужно место «всегда»';

  @override
  String get placesPermissionBody =>
      'Android будит Stowa у нужной точки и показывает имя сети Wi-Fi, только если месту разрешено «всегда». Координаты остаются на телефоне.';

  @override
  String get placesPermissionAllow => 'Разрешить';

  @override
  String get placesHint =>
      'Места нужны для «напомни дома», «на работе» и «в магазине». Заметки с тегом #купить всплывают у отмеченных магазинов, не чаще раза в день.';

  @override
  String placesShopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count магазина',
      many: '$count магазинов',
      few: '$count магазина',
      one: '$count магазин',
    );
    return '$_temp0';
  }

  @override
  String get itemRemindTime => 'По времени';

  @override
  String get itemPlaceChange => 'Другое место';

  @override
  String get placesMissingHome =>
      'Дом ещё не отмечен: Stowa напомнит, когда отметишь его в «Местах»';

  @override
  String get placesMissingWork =>
      'Работа ещё не отмечена: Stowa напомнит, когда отметишь её в «Местах»';

  @override
  String get placesMissingShop =>
      'Магазинов ещё нет: отметь хотя бы один в «Местах»';

  @override
  String get placeChannel => 'Напоминания по месту';

  @override
  String get remindPlaceNeedsAlways =>
      'Напомню у места, если разрешишь место «всегда»';

  @override
  String get lookColor => 'Цвет';

  @override
  String homeFoldersMore(Object count) {
    return 'Ещё $count';
  }

  @override
  String homeChecksMore(Object count) {
    return 'ещё $count';
  }

  @override
  String get catalogTitle => 'Каталог';

  @override
  String get catalogExpand => 'Раскрыть всё';

  @override
  String get catalogCollapse => 'Свернуть всё';

  @override
  String get catalogOpenFolder => 'Открыть папку';
}
