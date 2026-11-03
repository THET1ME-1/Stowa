// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class LUk extends L {
  LUk([String locale = 'uk']) : super(locale);

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

  @override
  String get homeNext => 'Up next';

  @override
  String homeMoreToday(Object count) {
    return '$count more';
  }

  @override
  String get homeReminderDone => 'Done';

  @override
  String get homeAll => 'All';

  @override
  String get folderNone => 'No folder';

  @override
  String get itemSorting => 'sorting';

  @override
  String get folderNew => 'new';

  @override
  String remindToday(Object time) {
    return 'today at $time';
  }

  @override
  String remindTomorrow(Object time) {
    return 'tomorrow at $time';
  }

  @override
  String remindOn(Object date, Object time) {
    return '$date at $time';
  }

  @override
  String get composerStow => 'Stow';

  @override
  String composerRemind(Object when) {
    return 'Remind $when';
  }

  @override
  String get composerRemoveReminder => 'No reminder';

  @override
  String get composerAttach => 'Attach';

  @override
  String get composerAddTag => 'Tag';

  @override
  String get composerGoesTo => 'It goes';

  @override
  String get attachGallery => 'Photos and videos';

  @override
  String get attachCamera => 'Take a photo';

  @override
  String get attachFile => 'Files';

  @override
  String get savedToast => 'Stowed';

  @override
  String savedWithReminder(Object when) {
    return 'Stowed, reminder $when';
  }

  @override
  String get undo => 'Undo';

  @override
  String get saveFailed => 'Couldn\'t save, the text is back in the line';

  @override
  String get removeAttachment => 'Remove';

  @override
  String get attachGalleryHint => 'Several at once';

  @override
  String get attachVideo => 'Record a video';

  @override
  String get attachFileHint => 'Any format: documents, text, archives';

  @override
  String get attachFailed => 'Couldn\'t open it. Try again';

  @override
  String get panelTags => 'Tags';

  @override
  String get panelFolders => 'Folders';

  @override
  String get panelCommands => 'Commands';

  @override
  String panelFound(int count) {
    return 'Found $count';
  }

  @override
  String get panelNothing => 'Nothing found';

  @override
  String get panelSimilar => 'Something similar is here';

  @override
  String get panelFresh => 'Nothing like it yet, this is new';

  @override
  String get filterAll => 'All';

  @override
  String get kindsNote => 'Notes';

  @override
  String get kindsLink => 'Links';

  @override
  String get kindsVideo => 'Videos';

  @override
  String get kindsImage => 'Photos';

  @override
  String get kindsFile => 'Files';

  @override
  String get kindsVoice => 'Voice';

  @override
  String get kindNote => 'note';

  @override
  String get kindLink => 'link';

  @override
  String get kindVideo => 'video';

  @override
  String get kindImage => 'photo';

  @override
  String get kindFile => 'file';

  @override
  String get kindVoice => 'voice note';

  @override
  String get foundInTranscript => 'in the transcript';

  @override
  String get foundOnImage => 'on the picture';

  @override
  String get foundInDescription => 'in the description';

  @override
  String get dateToday => 'today';

  @override
  String get dateYesterday => 'yesterday';

  @override
  String get saveWhatNote => 'Stow it';

  @override
  String get saveWhatLink => 'Link';

  @override
  String get saveWhatVideo => 'Video';

  @override
  String saveWhatPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '$count photo',
    );
    return '$_temp0';
  }

  @override
  String saveWhatFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '$count file',
    );
    return '$_temp0';
  }

  @override
  String get saveWhatTask => 'Task';

  @override
  String saveWhatList(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-item list',
      one: '$count-item list',
    );
    return '$_temp0';
  }

  @override
  String saveInto(String what, String folder) {
    return '$what to “$folder”';
  }

  @override
  String saveNoFolder(String what) {
    return '$what, I’ll pick a folder';
  }

  @override
  String saveRemind(String when) {
    return 'Remind $when';
  }

  @override
  String get saveRemindBare => 'Remind';

  @override
  String get saveAsIs => 'No folder, as is';

  @override
  String saveRemindAt(String when) {
    return 'remind $when';
  }

  @override
  String get saveRemindWhen => 'when? add “tomorrow at 10”';

  @override
  String get savePhotosHint => 'підпис і теги можна дописати потім';

  @override
  String get reasonChosen => 'you picked the folder';

  @override
  String reasonTag(String tag) {
    return 'by tag #$tag, offline';
  }

  @override
  String reasonWord(String word) {
    return 'by the word “$word”, offline';
  }

  @override
  String reasonDomain(String domain) {
    return 'by a link to $domain, offline';
  }

  @override
  String get reasonKind => 'by item type, offline';

  @override
  String get reasonNone => 'без теки, розкладу, коли з\'явиться схоже';

  @override
  String get reasonAsIs => 'unsorted, as asked';

  @override
  String get actionStow => 'Stow';

  @override
  String get actionRemind => 'Remind';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionInsert => 'Insert';

  @override
  String get actionCreate => 'Create';

  @override
  String get actionAppend => 'Append';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String tagCreate(String name) {
    return 'Create #$name';
  }

  @override
  String get tagCreateHint => 'pick an icon later';

  @override
  String get cmdRemind => 'remind';

  @override
  String get cmdTask => 'task';

  @override
  String get cmdList => 'list';

  @override
  String get cmdFind => 'find';

  @override
  String get cmdInbox => 'inbox';

  @override
  String get cmdRemindHint => 'Say when: “tomorrow at 10”, “on fri”';

  @override
  String get cmdTaskHint => 'Saved with a checkbox';

  @override
  String get cmdListHint => 'Every line or comma becomes an item';

  @override
  String get cmdFindHint => 'Only search, save nothing';

  @override
  String get cmdInboxHint => 'Keep as is, unsorted';

  @override
  String savedInto(String folder) {
    return 'Went to “$folder”';
  }

  @override
  String savedIntoRemind(String folder, String when) {
    return 'Went to “$folder”, will remind $when';
  }

  @override
  String appendedTo(String title) {
    return 'Added to “$title”';
  }

  @override
  String get voiceSaved => 'Голосове збережено';

  @override
  String get voiceTitle => 'Voice note';

  @override
  String get voiceCancel => 'Cancel recording';

  @override
  String get voiceDenied => 'No microphone access';

  @override
  String get voiceRecord => 'Record a voice note';

  @override
  String get suggestClip => 'Link from clipboard';

  @override
  String get suggestShot => 'Screenshot';

  @override
  String minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String get justNow => 'just now';

  @override
  String get trayGallery => 'Gallery';

  @override
  String get trayCamera => 'Camera';

  @override
  String get trayFile => 'File';

  @override
  String get trayLink => 'Link';

  @override
  String get trayVideo => 'Video';

  @override
  String get trayAccess => 'Allow photo access to pick right here';

  @override
  String get trayAllow => 'Allow';

  @override
  String get trayEmpty => 'The gallery is empty';

  @override
  String get trayNoLink => 'No link in the clipboard';

  @override
  String get fullHint => 'Write in Markdown, attach files with plus';

  @override
  String get fullPickFolder => 'I’ll pick a folder';

  @override
  String get fullExpand => 'Full screen';

  @override
  String get fullCollapse => 'Collapse';

  @override
  String get folderPickTitle => 'Where to put it';

  @override
  String get mdHeading => 'Heading';

  @override
  String get mdBold => 'Bold';

  @override
  String get mdItalic => 'Italic';

  @override
  String get mdStrike => 'Strikethrough';

  @override
  String get mdBullets => 'Bullets';

  @override
  String get mdChecklist => 'Checklist';

  @override
  String get mdQuote => 'Quote';

  @override
  String get mdCode => 'Code';

  @override
  String get mdUndo => 'Undo';

  @override
  String get mdRedo => 'Redo';

  @override
  String get removeChip => 'Remove';

  @override
  String get pinTag => 'Add tag';

  @override
  String get itemCopy => 'Copy text';

  @override
  String get itemCopied => 'Copied';

  @override
  String get itemDelete => 'Delete';

  @override
  String get itemDeleted => 'Deleted';

  @override
  String get itemTranscript => 'Transcript';

  @override
  String get itemDescription => 'What is in the picture';

  @override
  String get itemFiles => 'Files';

  @override
  String itemMoved(String folder) {
    return 'Moved to “$folder”';
  }

  @override
  String get itemSortingBadge => 'sorting';

  @override
  String reasonName(String name) {
    return 'by the name “$name”, offline';
  }

  @override
  String reasonSimilar(String words) {
    return 'by the words “$words”, offline';
  }

  @override
  String folderCreate(String name) {
    return 'Create folder “$name”';
  }

  @override
  String get folderCreateHint => 'change the icon and shape later';

  @override
  String get folderBoard => 'Board';

  @override
  String get folderList => 'List';

  @override
  String get folderSearch => 'Search in folder';

  @override
  String get folderMore => 'More';

  @override
  String get folderRename => 'Rename';

  @override
  String get folderLook => 'Icon and shape';

  @override
  String get folderDelete => 'Delete folder';

  @override
  String get folderNameLabel => 'Folder name';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String folderDeleteAsk(String name) {
    return 'Delete “$name”? Its items stay without a folder.';
  }

  @override
  String get folderDeleted => 'Folder deleted';

  @override
  String get restoreAction => 'Restore';

  @override
  String get folderEmpty =>
      'Nothing here yet. Drop something into the line below and it lands here.';

  @override
  String get dropHere => 'Drop it here';

  @override
  String get lookIcon => 'Icon';

  @override
  String get lookShape => 'Shape';

  @override
  String get voiceNoTranscript => 'Без розшифровки';

  @override
  String get voiceTranscribed => 'Voice note, transcribed';

  @override
  String get voicePlay => 'Play';

  @override
  String get voicePause => 'Pause';

  @override
  String get reminderChannel => 'Reminders';

  @override
  String get shareSaved => 'Saved';

  @override
  String shareInFolder(String folder) {
    return 'in “$folder”';
  }

  @override
  String get shareNoFolder => 'no folder yet';

  @override
  String get shareOther => 'Or somewhere else';

  @override
  String get shareNewFolder => 'New';

  @override
  String get shareAddWords => 'Add a few words';

  @override
  String get shareDone => 'Done';

  @override
  String get tagsTitle => 'Tags and folders';

  @override
  String get tagsTab => 'Tags';

  @override
  String get foldersTab => 'Folders';

  @override
  String get tagsPinned => 'On the home screen';

  @override
  String get tagsPinnedHint => 'Hold and drag to reorder';

  @override
  String get tagsAll => 'All tags';

  @override
  String get tagsNone =>
      'No tags yet. Type #tag in the line or create one here.';

  @override
  String get rulesTitle => 'Rules';

  @override
  String get rulesNone =>
      'No rules yet: the line sorts by words already in your folders.';

  @override
  String get ruleNew => 'New rule';

  @override
  String get ruleStays => 'stays where it is';

  @override
  String get tagNew => 'New tag';

  @override
  String get tagEdit => 'Tag';

  @override
  String get tagNameHint => 'tag name';

  @override
  String get iconSymbols => 'Icons';

  @override
  String get iconEmoji => 'Emoji';

  @override
  String get iconImage => 'Own picture';

  @override
  String get iconPickImage => 'Pick a picture';

  @override
  String get emojiHint => 'One emoji';

  @override
  String get tagToFolder => 'Put into folder';

  @override
  String get tagPin => 'Pin to home';

  @override
  String get tagCreateButton => 'Create tag';

  @override
  String get tagDelete => 'Delete tag';

  @override
  String tagDeleteAsk(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return 'Remove #$name from $_temp0? The items stay.';
  }

  @override
  String tagDeleted(String name) {
    return 'Tag #$name deleted';
  }

  @override
  String get ruleSheetTitle => 'Rule';

  @override
  String get ruleIf => 'If';

  @override
  String get ruleThen => 'Then';

  @override
  String get ruleIfTag => 'has tag';

  @override
  String get ruleIfDomain => 'link to site';

  @override
  String get ruleIfWord => 'has word';

  @override
  String get ruleIfKind => 'item type';

  @override
  String get ruleThenFolder => 'into folder';

  @override
  String get ruleThenTag => 'add tag';

  @override
  String get ruleValueTag => 'tag without #';

  @override
  String get ruleValueDomain => 'tiktok.com';

  @override
  String get ruleValueWord => 'word';

  @override
  String get ruleEnabled => 'On';

  @override
  String get ruleDelete => 'Delete rule';

  @override
  String get settingsTooltip => 'Tags, folders and rules';

  @override
  String get tagAdd => 'Add tag';

  @override
  String get sortMode => 'Sort';

  @override
  String get sortSkip => 'Skip';

  @override
  String sortLeft(int count) {
    return '$count left';
  }

  @override
  String get sortDone => 'All sorted';

  @override
  String get sortHint =>
      'Tap a folder to put it there. Down to skip, up to delete';

  @override
  String get iconSearch => 'Find an icon: car, home, food';

  @override
  String get itemMove => 'Move to folder';

  @override
  String get sortNewest => 'Newest first';

  @override
  String get sortOldest => 'Oldest first';

  @override
  String get sortByName => 'By name';

  @override
  String get sortTooltip => 'Order';

  @override
  String get reminderDoneAction => 'Done';

  @override
  String get reminderSnoozeAction => 'In an hour';

  @override
  String get folderPickNew => 'New folder';

  @override
  String get reminderCleared => 'Reminder cleared';

  @override
  String untitledPhoto(String date) {
    return 'Photo, $date';
  }

  @override
  String untitledScreenshot(String date) {
    return 'Screenshot, $date';
  }

  @override
  String untitledVideo(String date) {
    return 'Video, $date';
  }

  @override
  String untitledAudio(String date) {
    return 'Recording, $date';
  }

  @override
  String untitledFile(String date) {
    return 'File, $date';
  }

  @override
  String get shareFailed => 'Couldn\'t save: the app didn\'t give access';

  @override
  String get ruleDeleted => 'Rule deleted';

  @override
  String get itemEdit => 'Edit';

  @override
  String get itemEditDone => 'Done';

  @override
  String get itemTitleHint => 'Title';

  @override
  String get itemBodyHint => 'Text, lists, - [ ] tasks';

  @override
  String get itemAddPhoto => 'Photo';

  @override
  String get itemRemind => 'Remind';

  @override
  String get itemReminderChange => 'Change time';

  @override
  String get itemReminderRemove => 'Remove reminder';

  @override
  String get itemSaved => 'Saved';

  @override
  String get itemMore => 'Ще';

  @override
  String get itemAppend => 'Дописати';

  @override
  String get itemShare => 'Поділитися';

  @override
  String get itemAutosave => 'Зберігається саме';

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
  String get itemOpenLink => 'Відкрити';

  @override
  String get itemWatch => 'Дивитися';

  @override
  String get fileOpenFailed => 'Немає чим відкрити такий файл';

  @override
  String get linkOpenFailed => 'Не вдалося відкрити посилання';

  @override
  String photoCounter(Object count, Object index) {
    return '$index з $count';
  }

  @override
  String get photoToGallery => 'У галерею';

  @override
  String get photoSaved => 'Зберіг у галерею';

  @override
  String get photoSaveFailed => 'Не вдалося зберегти: немає доступу до галереї';

  @override
  String get photoClose => 'Закрити';

  @override
  String get voiceSpeed => 'Швидкість';

  @override
  String autoSorted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Розклав $count схожих речі',
      many: 'Розклав $count схожих речей',
      few: 'Розклав $count схожі речі',
      one: 'Розклав $count схожу річ',
    );
    return '$_temp0';
  }

  @override
  String get relatedTitle => 'Пов\'язане';

  @override
  String relatedWords(Object words) {
    return 'спільне: $words';
  }

  @override
  String relatedSite(Object site) {
    return 'той самий сайт, $site';
  }

  @override
  String get relatedHide => 'Не пов\'язувати';

  @override
  String get relatedHidden => 'Більше не покажу їх поруч';

  @override
  String aiSortedInto(String folder) {
    return 'Поклав у «$folder»';
  }

  @override
  String get aiOtherFolder => 'Інша';

  @override
  String get aiPausedAuth => 'Розбір на паузі: ключ не прийнято';

  @override
  String get aiPausedPayment => 'Розбір на паузі: на ключі скінчилися гроші';

  @override
  String get aiPausedAction => 'Перевірити ключ';

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get settingsAi => 'Розбір ШІ';

  @override
  String get aiStateOff => 'Вимкнено';

  @override
  String get aiStateOffHint =>
      'Встав свій ключ, і речі без папки розкладуться самі: з тегами, заголовком і описом для пошуку. Ключ зберігається лише на цьому телефоні, запити йдуть прямо до постачальника.';

  @override
  String get aiStateOn => 'Працює';

  @override
  String aiStateWait(String time) {
    return 'Постачальник просить зачекати до $time';
  }

  @override
  String aiQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count речі чекають розбору',
      many: '$count речей чекають розбору',
      few: '$count речі чекають розбору',
      one: '$count річ чекає розбору',
    );
    return '$_temp0';
  }

  @override
  String get aiSortNow => 'Розібрати зараз';

  @override
  String get aiKey => 'Ключ';

  @override
  String get aiKeyNone => 'Не задано';

  @override
  String get aiKeySet => 'Задано';

  @override
  String get aiKeyPaste => 'Вставити';

  @override
  String get aiKeySave => 'Зберегти й перевірити';

  @override
  String get aiKeyRemove => 'Видалити ключ';

  @override
  String get aiKeyWhere =>
      'Ключ береться в постачальника: на OpenRouter — у розділі Keys. Є безкоштовні моделі.';

  @override
  String get aiCheckOk => 'Ключ працює';

  @override
  String get aiCheckAuth => 'Постачальник не прийняв ключ';

  @override
  String get aiCheckPayment => 'На ключі немає грошей';

  @override
  String get aiCheckRate => 'Постачальник просить зачекати';

  @override
  String get aiCheckNetwork => 'Немає зв’язку з постачальником';

  @override
  String get aiCheckServer => 'Постачальник відповів помилкою';

  @override
  String get aiProvider => 'Постачальник';

  @override
  String get aiProviderHint =>
      'Адреса API, сумісного з OpenAI. Без неї — OpenRouter.';

  @override
  String get aiSortModel => 'Модель розбору';

  @override
  String get aiSpeechModel => 'Розшифровка голосових';

  @override
  String get aiSpeechOff => 'Вимкнено';

  @override
  String get aiModelsSearch => 'Знайти модель';

  @override
  String get aiModelFree => 'безкоштовна';

  @override
  String get aiModelVision => 'бачить фото';

  @override
  String get aiModelsNeedKey => 'Список моделей відкриється після ключа';

  @override
  String get aiModelsFailed => 'Список моделей не завантажився';

  @override
  String aiModelOwn(String name) {
    return 'Своя: «$name»';
  }

  @override
  String get settingsOrder => 'Порядок';

  @override
  String get settingsLanguage => 'Мова';

  @override
  String get languageSystem => 'Як у системі';

  @override
  String settingsVersion(String version) {
    return 'Stowa $version';
  }

  @override
  String get trashTitle => 'Кошик';

  @override
  String get trashEmpty => 'Кошик порожній';

  @override
  String get trashHint =>
      'Видалене лежить тут 30 днів, потім стирається разом із файлами.';

  @override
  String trashDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'зітреться через $count дня',
      many: 'зітреться через $count днів',
      few: 'зітреться через $count дні',
      one: 'зітреться через $count день',
    );
    return '$_temp0';
  }

  @override
  String trashFrom(String folder) {
    return 'з «$folder»';
  }

  @override
  String get trashPurge => 'Стерти назавжди';

  @override
  String get trashPurgeAll => 'Очистити кошик';

  @override
  String trashPurgeAllAsk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Стерти $count речі назавжди? Повернути їх не вийде.',
      many: 'Стерти $count речей назавжди? Повернути їх не вийде.',
      few: 'Стерти $count речі назавжди? Повернути їх не вийде.',
      one: 'Стерти $count річ назавжди? Повернути її не вийде.',
    );
    return '$_temp0';
  }

  @override
  String trashRestored(String title) {
    return 'Повернув «$title»';
  }

  @override
  String get trashPurged => 'Стерто назавжди';

  @override
  String get settingsData => 'Дані';

  @override
  String get backupSave => 'Зберегти копію';

  @override
  String get backupSaveHint =>
      'Уся Stowa одним файлом: речі, папки, теги, правила й файли. Ключа ШІ в копії немає.';

  @override
  String get backupRestore => 'Відновити з копії';

  @override
  String backupRestoreAsk(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Замінити все копією від $date? У ній $count речі, нинішні зникнуть.',
      many:
          'Замінити все копією від $date? У ній $count речей, нинішні зникнуть.',
      few:
          'Замінити все копією від $date? У ній $count речі, нинішні зникнуть.',
      one: 'Замінити все копією від $date? У ній $count річ, нинішні зникнуть.',
    );
    return '$_temp0';
  }

  @override
  String get backupReplace => 'Замінити';

  @override
  String get backupRestored => 'Відновлено з копії';

  @override
  String get backupNotStowa => 'Це не копія Stowa';

  @override
  String get backupTooNew => 'Копію зробила новіша Stowa, онови застосунок';

  @override
  String get backupFailed => 'Копія не вийшла';

  @override
  String get folderNewBadge => 'нова';

  @override
  String get aiSortingNow => 'Розбираю…';

  @override
  String get aiLog => 'Журнал запитів';

  @override
  String get aiLogEmpty => 'Запитів до постачальника ще не було';

  @override
  String get aiLogCluster => 'Нові папки з «Без папки»';

  @override
  String get aiCheckTimeout => 'Модель не відповіла вчасно';

  @override
  String get tgTitle => 'Свій бот Telegram';

  @override
  String get tgNone => 'Не підключено';

  @override
  String get tgHowTo =>
      '1. Відкрий @BotFather у Telegram і надішли /newbot.\n2. Вигадай ботові ім’я, BotFather надішле токен.\n3. Встав токен сюди.\n4. Напиши своєму ботові будь-що: відтепер він слухає лише тебе, а все переслане йому потрапляє в Stowa.';

  @override
  String get tgConnect => 'Підключити';

  @override
  String tgOwner(String name) {
    return 'Слухає лише $name';
  }

  @override
  String get tgWaitingOwner => 'Напиши ботові будь-що, щоб він запам’ятав тебе';

  @override
  String get tgOpenBot => 'Відкрити бота';

  @override
  String get tgDisconnect => 'Відключити бота';

  @override
  String get tgBadToken => 'Telegram не прийняв токен';

  @override
  String get tgOffline => 'Немає зв’язку з Telegram';

  @override
  String tgPulled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Забрав $count повідомлення',
      many: 'Забрав $count повідомлень',
      few: 'Забрав $count повідомлення',
      one: 'Забрав $count повідомлення',
    );
    return '$_temp0';
  }

  @override
  String get settingsOutside => 'Ззовні';
}
