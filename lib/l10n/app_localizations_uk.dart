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
  String get reasonKind => 'by note type, offline';

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
      other: '$count notes',
      one: '$count note',
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
  String get folderLook => 'Color and icon';

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
    return 'Delete “$name”? Its notes stay without a folder.';
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
      other: '$count notes',
      one: '$count note',
    );
    return 'Remove #$name from $_temp0? The notes stay.';
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
  String get ruleIfKind => 'note type';

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
      other: 'Розклав $count схожої нотатки',
      many: 'Розклав $count схожих нотаток',
      few: 'Розклав $count схожі нотатки',
      one: 'Розклав $count схожу нотатку',
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
      'Встав свій ключ, і нотатки без папки розкладуться самі.';

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
      other: '$count нотатки чекають розбору',
      many: '$count нотаток чекають розбору',
      few: '$count нотатки чекають розбору',
      one: '$count нотатка чекає розбору',
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
      'Ключ дає постачальник: на OpenRouter він у розділі Keys, є безкоштовні моделі.';

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
      'Адреса API, сумісного з OpenAI, а без неї — OpenRouter.';

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
      other: 'Стерти $count нотатки назавжди? Повернути їх не вийде.',
      many: 'Стерти $count нотаток назавжди? Повернути їх не вийде.',
      few: 'Стерти $count нотатки назавжди? Повернути їх не вийде.',
      one: 'Стерти $count нотатку назавжди? Повернути її не вийде.',
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
      'Усі нотатки, папки й файли одним файлом, без ключа ШІ.';

  @override
  String get backupRestore => 'Відновити з копії';

  @override
  String backupRestoreAsk(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Замінити все копією від $date? У ній $count нотатки, нинішні зникнуть.',
      many:
          'Замінити все копією від $date? У ній $count нотаток, нинішні зникнуть.',
      few:
          'Замінити все копією від $date? У ній $count нотатки, нинішні зникнуть.',
      one:
          'Замінити все копією від $date? У ній $count нотатка, нинішні зникнуть.',
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
      '1. Відкрий @BotFather у Telegram і надішли /⁠newbot.\n2. Вигадай ботові ім’я, BotFather надішле токен.\n3. Встав токен сюди.\n4. Напиши своєму ботові будь-що: відтепер він слухає лише тебе, а все переслане йому потрапляє в Stowa.';

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

  @override
  String selCount(int count) {
    return 'Вибрано: $count';
  }

  @override
  String get selClear => 'Зняти вибір';

  @override
  String get selAll => 'Вибрати всі';

  @override
  String get selMove => 'У папку';

  @override
  String get selTag => 'Тег';

  @override
  String get selUntag => 'Зняти тег';

  @override
  String get selDelete => 'Видалити';

  @override
  String selMoved(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Переклав $count нотатки у «$folder»',
      many: 'Переклав $count нотаток у «$folder»',
      few: 'Переклав $count нотатки у «$folder»',
      one: 'Переклав $count нотатку у «$folder»',
    );
    return '$_temp0';
  }

  @override
  String selDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Видалив $count нотатки',
      many: 'Видалив $count нотаток',
      few: 'Видалив $count нотатки',
      one: 'Видалив $count нотатку',
    );
    return '$_temp0';
  }

  @override
  String selTagged(String tag) {
    return 'Поставив #$tag';
  }

  @override
  String selUntagged(String tag) {
    return 'Зняв #$tag';
  }

  @override
  String get tagPickTitle => 'Який тег';

  @override
  String get folderCanvas => 'Полотно';

  @override
  String get canvasFit => 'Вмістити все';

  @override
  String get canvasNote => 'Записка';

  @override
  String get canvasNoteHint => 'Що написати на полотні';

  @override
  String get graphTitle => 'Граф зв’язків';

  @override
  String get graphEmpty =>
      'Зв’язків поки немає. Вони з’являться, коли нотатки почнуть перегукуватися словами або ШІ зв’яже їх сам.';

  @override
  String get graphFailed => 'Граф не побудувався';

  @override
  String copyPartlyFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файлу не збережено: застосунок не дав доступу',
      many: '$count файлів не збережено: застосунок не дав доступу',
      few: '$count файли не збережено: застосунок не дав доступу',
      one: '$count файл не збережено: застосунок не дав доступу',
    );
    return '$_temp0';
  }

  @override
  String get mapTitle => 'Мапа';

  @override
  String get mapEmpty =>
      'Поки немає нотаток з місцем. Нові нотатки запам’ятають, де їх збережено, і з’являться тут.';

  @override
  String get mapWhereAmI => 'Де я';

  @override
  String get mapPlaceUnnamed => 'Місце без назви';

  @override
  String get placeSetting => 'Запам’ятовувати, де збережено';

  @override
  String get placeSettingHint =>
      'Місце видно в нотатці й на мапі, назовні йде тільки запит назви вулиці.';

  @override
  String panelLooking(Object what) {
    return 'Шукаю: $what';
  }

  @override
  String get foundAtPlace => 'за місцем';

  @override
  String fileSaving(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Зберігаю $count файлів',
      few: 'Зберігаю $count файли',
      one: 'Зберігаю файл',
    );
    return '$_temp0';
  }

  @override
  String get fileSavingHint =>
      'Застосунок можна закрити, а оригінал видалити, коли смужка зникне.';

  @override
  String get foundInFile => 'у файлі';

  @override
  String get foundOnPage => 'на сторінці';

  @override
  String get foundInPhotoInfo => 'у даних фото';

  @override
  String documentSheet(Object name) {
    return 'аркуш «$name»';
  }

  @override
  String documentSlide(Object number) {
    return 'слайд $number';
  }

  @override
  String documentChapter(Object number) {
    return 'розділ $number';
  }

  @override
  String get factCall => 'Зателефонувати';

  @override
  String get factWrite => 'Написати';

  @override
  String get factCopy => 'Скопіювати';

  @override
  String photoTaken(Object date) {
    return 'Знято $date';
  }

  @override
  String foundInSubtitles(Object time) {
    return 'у субтитрах · $time';
  }

  @override
  String foundInChapters(Object time) {
    return 'у розділах · $time';
  }

  @override
  String get foundInIngredients => 'в інгредієнтах';

  @override
  String get foundAtAddress => 'за адресою';

  @override
  String get foundInHashtags => 'у хештегах';

  @override
  String get watchFromHere => 'Дивитися з цього місця';

  @override
  String get pageRecipe => 'рецепт';

  @override
  String get pageProduct => 'товар';

  @override
  String get pageEvent => 'подія';

  @override
  String get pagePlace => 'місце';

  @override
  String get pageMovie => 'фільм';

  @override
  String get pageBook => 'книга';

  @override
  String get pageVideo => 'відео';

  @override
  String get pageArticle => 'стаття';

  @override
  String minutesShort(Object count) {
    return '$count хв';
  }

  @override
  String servings(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count порцій',
      few: '$count порції',
      one: '$count порція',
    );
    return '$_temp0';
  }

  @override
  String readingMinutes(Object count) {
    return '$count хв читання';
  }

  @override
  String get inStock => 'Є в наявності';

  @override
  String get outOfStock => 'Немає в наявності';

  @override
  String get toShoppingList => 'До списку покупок';

  @override
  String shoppingFor(Object name) {
    return 'Купити: $name';
  }

  @override
  String get shoppingReady => 'Список покупок готовий';

  @override
  String get chaptersTitle => 'Розділи';

  @override
  String get authorTags => 'Теги автора';

  @override
  String get pageSeries => 'серіал';

  @override
  String get pageComic => 'манга';

  @override
  String get adultSetting => 'Показувати 18+';

  @override
  String get adultSettingHint =>
      'Поки вимкнено, обкладинки й описи сторінок 18+ приховані.';

  @override
  String get adultHidden =>
      'Опис приховано: 18+. Показ вмикається в налаштуваннях.';

  @override
  String get vaultSetupTitle => 'Де зберігати нотатки';

  @override
  String get vaultSetupHint =>
      'Нотатки, фото й файли лежать звичайними файлами в папці, яку відкриває і Obsidian.';

  @override
  String get vaultCreate => 'Створити сховище';

  @override
  String get vaultCreateHint =>
      'Нова папка в пам’яті телефона: нотатки залишаться, навіть якщо видалити застосунок.';

  @override
  String get vaultCreateButton => 'Створити';

  @override
  String get vaultOpen => 'Відкрити папку як сховище';

  @override
  String get vaultOpenHint =>
      'Попереднє сховище Stowa після перевстановлення або сховище Obsidian.';

  @override
  String get vaultOpenButton => 'Відкрити';

  @override
  String get vaultInApp => 'Зберігати всередині застосунку';

  @override
  String get vaultInAppHint =>
      'Без дозволів, але якщо видалити застосунок, нотатки зникнуть.';

  @override
  String get vaultInAppButton => 'Вибрати';

  @override
  String get vaultInAppWarning =>
      'Нотатки лежатимуть усередині застосунку й зникнуть, якщо його видалити. Перенести їх у звичайну папку можна згодом у налаштуваннях.';

  @override
  String get vaultInAppConfirm => 'Зберігати всередині';

  @override
  String get vaultName => 'Назва сховища';

  @override
  String get vaultPlace => 'Де створити';

  @override
  String get vaultAccessTitle => 'Потрібен доступ до файлів';

  @override
  String get vaultAccessHint =>
      'Щоб зберігати нотатки у звичайній папці, Android просить «Доступ до всіх файлів», але Stowa чіпає лише свою папку.';

  @override
  String get vaultAccessGrant => 'Відкрити налаштування';

  @override
  String get vaultAccessDenied =>
      'Без доступу до файлів сховище в пам\'яті телефона не працює';

  @override
  String vaultMoving(int done, int total) {
    return 'Переношу: $done з $total';
  }

  @override
  String vaultBuilding(int done, int total) {
    return 'Збираю покажчик: $done з $total';
  }

  @override
  String vaultMoveFailed(int count) {
    return 'Перенеслося не все, бракує: $count. Нотатки лишилися на старому місці.';
  }

  @override
  String get vaultMissingTitle => 'Сховище не знайдено';

  @override
  String vaultMissingHint(String path) {
    return 'Папки $path немає або Stowa втратила доступ до файлів. Нотатки в застосунку цілі.';
  }

  @override
  String get vaultGrantAccess => 'Дати доступ';

  @override
  String get vaultChooseAgain => 'Вибрати папку';

  @override
  String get vaultSection => 'Сховище';

  @override
  String get vaultFolder => 'Папка';

  @override
  String get vaultInsideApp => 'Усередині застосунку';

  @override
  String get vaultMoveTo => 'Перенести в іншу папку';

  @override
  String get vaultRebuild => 'Перезібрати покажчик';

  @override
  String get vaultSettingHint =>
      'Нотатки лежать звичайними файлами .md, їх відкриває і Obsidian.';

  @override
  String get vaultMoved => 'Сховище перенесено';

  @override
  String get vaultRebuilt => 'Покажчик зібрано';

  @override
  String vaultSyncing(int done, int total) {
    return 'Синхронізація нотаток $done з $total';
  }

  @override
  String repeatIn(String folder, String date) {
    return 'Така сама лежить у теці «$folder» з $date';
  }

  @override
  String repeatNoFolder(String date) {
    return 'Така сама лежить без теки з $date';
  }

  @override
  String get settingsImport => 'Перенесення';

  @override
  String get importTelegram => 'З Telegram';

  @override
  String get importTelegramHint =>
      'Обери папку вивантаження «Збереженого» з Telegram Desktop.';

  @override
  String importProgress(int done, int total) {
    return 'Переношу $done з $total';
  }

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Переніс $count нотатки',
      many: 'Переніс $count нотаток',
      few: 'Переніс $count нотатки',
      one: 'Переніс $count нотатку',
    );
    return '$_temp0';
  }

  @override
  String importRepeated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вже були',
      many: '$count вже були',
      few: '$count вже були',
      one: '$count вже була',
    );
    return '$_temp0';
  }

  @override
  String get importNotTelegram =>
      'У цій теці немає вивантаження Telegram: потрібен messages.html або result.json';

  @override
  String importMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файлу Telegram не вивантажив',
      many: '$count файлів Telegram не вивантажив',
      few: '$count файли Telegram не вивантажив',
      one: '$count файл Telegram не вивантажив',
    );
    return '$_temp0 — увімкни файли в налаштуваннях вивантаження й перенеси ще раз';
  }

  @override
  String importFilled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count перенесеної раніше отримали файли',
      many: '$count перенесених раніше отримали файли',
      few: '$count перенесені раніше отримали файли',
      one: '$count перенесена раніше отримала файли',
    );
    return '$_temp0';
  }

  @override
  String get returnChannel => 'Повернення';

  @override
  String get returnWatchTitle => 'Переглянути пізніше';

  @override
  String returnVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count відео',
      many: '$count відео',
      few: '$count відео',
      one: '$count відео',
    );
    return '$_temp0';
  }

  @override
  String returnArticles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count статті',
      many: '$count статей',
      few: '$count статті',
      one: '$count стаття',
    );
    return '$_temp0';
  }

  @override
  String returnMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хвилини',
      many: '$count хвилин',
      few: '$count хвилини',
      one: '$count хвилина',
    );
    return '$_temp0';
  }

  @override
  String returnAnd(String first, String second) {
    return '$first і $second';
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
      other: '$count року тому',
      many: '$count років тому',
      few: '$count роки тому',
      one: 'Рік тому',
    );
    return '$_temp0';
  }

  @override
  String get returnMonthAgo => 'Місяць тому';

  @override
  String get returnWeekAgo => 'Тиждень тому';

  @override
  String returnDayOne(String title) {
    return '«$title»';
  }

  @override
  String returnDayMore(String title, int count) {
    return '«$title» і ще $count';
  }

  @override
  String get returnOnThisDay => 'Цього дня';

  @override
  String get returnWeekTitle => 'Тиждень у Stowa';

  @override
  String returnWeekSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'За тиждень $count нотатки',
      many: 'За тиждень $count нотаток',
      few: 'За тиждень $count нотатки',
      one: 'За тиждень $count нотатка',
    );
    return '$_temp0';
  }

  @override
  String returnWeekUnopened(int count) {
    return '$count не відкриті';
  }

  @override
  String returnWeekUnsorted(int count) {
    return '$count без теки';
  }

  @override
  String get returnWeekUnopenedTitle => 'Не відкриті';

  @override
  String get returnWeekUnsortedTitle => 'Без теки';

  @override
  String returnShopTitle(String shop) {
    return 'У магазині «$shop»';
  }

  @override
  String returnShopMore(String items, int count) {
    return '$items і ще $count';
  }

  @override
  String get returnShopping => 'Купити';

  @override
  String get settingsReturns => 'Сповіщення';

  @override
  String get returnWeekSetting => 'Підсумок тижня';

  @override
  String get returnShoppingSetting => 'Покупки біля магазину';

  @override
  String get returnEveningRow => 'Увечері о';

  @override
  String get returnQuietRow => 'Тихі години';

  @override
  String get returnWeekDayRow => 'День підсумку';

  @override
  String get returnSettingsHint =>
      'Не більше одного тихого сповіщення на день.';

  @override
  String returnRange(String from, String to) {
    return '$from–$to';
  }

  @override
  String get returnQuietFrom => 'Тихо з';

  @override
  String get returnQuietTo => 'Тихо до';

  @override
  String get returnWatchEmpty => 'Черга порожня: усе свіже вже переглянуто.';

  @override
  String get returnDayEmpty => 'Цього дня раніше нічого не зберігали.';

  @override
  String get returnWeekEmpty => 'За тиждень нічого не збережено.';

  @override
  String get returnShoppingEmpty => 'Купувати нічого: списки відмічені.';

  @override
  String returnMinutesShort(int count) {
    return '$count хв';
  }

  @override
  String get returnsAskTitle => 'Повертати збережене?';

  @override
  String get returnsAskBody =>
      'Одне тихе сповіщення ввечері нагадає про збережене.';

  @override
  String get returnsAskOn => 'Увімкнути';

  @override
  String get returnsAskLater => 'Не зараз';

  @override
  String get placeRemindHome => 'Нагадати вдома';

  @override
  String get placeRemindWork => 'Нагадати на роботі';

  @override
  String get placeRemindHere => 'Нагадати тут';

  @override
  String get placeRemindShop => 'Нагадати в магазині';

  @override
  String placeRemindAt(String place) {
    return 'Нагадати: $place';
  }

  @override
  String get composerRemovePlace => 'Без нагадування за місцем';

  @override
  String get placesTitle => 'Місця';

  @override
  String get placesHome => 'Дім';

  @override
  String get placesWork => 'Робота';

  @override
  String get placesShops => 'Магазини';

  @override
  String get placesNotSet => 'Не задано';

  @override
  String placesWifi(String name) {
    return 'Wi-Fi: $name';
  }

  @override
  String get placesImHome => 'Я зараз удома';

  @override
  String get placesImWork => 'Я зараз на роботі';

  @override
  String get placesImShop => 'Я в магазині — запам’ятати';

  @override
  String placesGuessHome(String name) {
    return 'Схоже, дім — $name';
  }

  @override
  String placesGuessWork(String name) {
    return 'Схоже, робота — $name';
  }

  @override
  String get placesRemove => 'Прибрати';

  @override
  String get placesShopName => 'Як назвати магазин';

  @override
  String get placesSave => 'Зберегти';

  @override
  String get placesNoFix =>
      'Не вдалося дізнатися, де ти. Перевір, що місце на телефоні увімкнене й дозволене Stowa.';

  @override
  String get placesPermissionTitle => 'Потрібне місце «завжди»';

  @override
  String get placesPermissionBody =>
      'Нагадування біля місця працюють, лише якщо місцю дозволено «завжди».';

  @override
  String get placesPermissionAllow => 'Дозволити';

  @override
  String get placesHint =>
      'Місця потрібні для нагадувань на кшталт «нагадай удома» чи «в магазині».';

  @override
  String placesShopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count магазину',
      many: '$count магазинів',
      few: '$count магазини',
      one: '$count магазин',
    );
    return '$_temp0';
  }

  @override
  String get itemRemindTime => 'За часом';

  @override
  String get itemPlaceChange => 'Інше місце';

  @override
  String get placesMissingHome =>
      'Дім ще не позначений: Stowa нагадає, коли позначиш його в «Місцях»';

  @override
  String get placesMissingWork =>
      'Робота ще не позначена: Stowa нагадає, коли позначиш її в «Місцях»';

  @override
  String get placesMissingShop =>
      'Магазинів ще немає: познач хоча б один у «Місцях»';

  @override
  String get placeChannel => 'Нагадування за місцем';

  @override
  String get remindPlaceNeedsAlways =>
      'Нагадаю на місці, якщо дозволиш місце «завжди»';

  @override
  String get lookColor => 'Колір';

  @override
  String homeFoldersMore(Object count) {
    return 'Ще $count';
  }

  @override
  String homeChecksMore(Object count) {
    return 'ще $count';
  }

  @override
  String get catalogTitle => 'Каталог';

  @override
  String get catalogExpand => 'Розгорнути все';

  @override
  String get catalogCollapse => 'Згорнути все';

  @override
  String get catalogOpenFolder => 'Відкрити папку';

  @override
  String foldersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count папки',
      many: '$count папок',
      few: '$count папки',
      one: '$count папка',
    );
    return '$_temp0';
  }

  @override
  String readerOpen(Object count) {
    return 'Читати · $count хв';
  }

  @override
  String get readerOriginal => 'Оригінал';

  @override
  String get readerQuote => 'Цитата';

  @override
  String get readerCopy => 'Копіювати';

  @override
  String get readerNote => 'Позначка';

  @override
  String get readerNoteHint => 'Позначка до цитати';

  @override
  String get readerRemove => 'Прибрати';

  @override
  String get readerRemoved => 'Цитату прибрано';

  @override
  String get readerGone => 'Оригінал видалено · копію збережено';

  @override
  String get readerNoCopy =>
      'Текст статті не зберігся. Його можна відкрити на сайті.';

  @override
  String get readerImageOff => 'Картинку не збережено';

  @override
  String get highlightsTitle => 'Цитати';

  @override
  String get linkGone => 'Посилання не відкривається';

  @override
  String get deadLinksTitle => 'Биті посилання';

  @override
  String get deadLinksAbout =>
      'Раз на тиждень Stowa перевіряє посилання й збирає сюди сторінки, які сайт видалив.';

  @override
  String get deadLinksEmpty => 'Усі посилання відкриваються';

  @override
  String get deadLinksCheck => 'Перевірити зараз';

  @override
  String get deadLinksChecking => 'Перевіряю посилання…';

  @override
  String get deadLinksKeep => 'Залишити';

  @override
  String get deadLinksDelete => 'Видалити';

  @override
  String get deadLinksDeleted => 'Нотатка в кошику';

  @override
  String deadLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count не відкриваються',
      many: '$count не відкриваються',
      few: '$count не відкриваються',
      one: '$count не відкривається',
    );
    return '$_temp0';
  }

  @override
  String get settingsArticles => 'Статті';

  @override
  String get articleImages => 'Картинки статей';

  @override
  String get articleImagesAbout =>
      'Завантажувати через Wi-Fi, щоб читати статті з картинками без мережі';

  @override
  String get foundInArticle => 'у статті';

  @override
  String get foundInQuote => 'у цитаті';

  @override
  String get settingsStart => 'Запуск';

  @override
  String get startOpen => 'Відкривати';

  @override
  String get startHome => 'Головну';

  @override
  String get startLast => 'Останню нотатку';

  @override
  String get startRandom => 'Випадкову нотатку';

  @override
  String get startHint =>
      'Остання нотатка поверне туди, де зупинилися, випадкова нагадає про збережене.';

  @override
  String get appearanceTitle => 'Оформлення';

  @override
  String get appearanceTheme => 'Тема';

  @override
  String get themeLight => 'Світла';

  @override
  String get themeDark => 'Темна';

  @override
  String get themeSystem => 'Як у системі';

  @override
  String get themeByTime => 'За часом доби';

  @override
  String get themeByTimeHint => 'Темна з 20:00 до 7:00';

  @override
  String get appearanceColor => 'Колір';

  @override
  String get colorGraphite => 'Графіт';

  @override
  String get colorCustom => 'Свій колір';

  @override
  String get colorFromWallpaper => 'Зі шпалер';

  @override
  String get colorIntensity => 'Насиченість';

  @override
  String get intensityVibrant => 'Соковито';

  @override
  String get intensityFaithful => 'Точнісінько';

  @override
  String get intensityHint =>
      '«Соковито» підфарбовує і фон, «Точнісінько» лишає його сірим.';

  @override
  String get wallpaperColors => 'Кольори зі шпалер';

  @override
  String get wallpaperColorsHint =>
      'Колір теми підлаштовується під шпалери телефона';

  @override
  String get amoledTitle => 'Чорне тло';

  @override
  String get amoledHint => 'Чистий чорний для екранів AMOLED, береже заряд';

  @override
  String get pickerApply => 'Готово';

  @override
  String get colorCoral => 'Корал';

  @override
  String get colorAmber => 'Бурштин';

  @override
  String get colorLime => 'Лайм';

  @override
  String get colorMint => 'М’ята';

  @override
  String get colorTeal => 'Бірюза';

  @override
  String get colorBlue => 'Синій';

  @override
  String get colorViolet => 'Фіалка';

  @override
  String get colorRose => 'Троянда';

  @override
  String get folderNewInside => 'Нова папка всередині';

  @override
  String get folderMoveTo => 'Перекласти в…';

  @override
  String get folderMoveTop => 'Нагору';

  @override
  String get folderMoveNone =>
      'Перекласти нікуди: папки вкладаються не глибше трьох рівнів';

  @override
  String get historyTitle => 'Історія';

  @override
  String get historyNow => 'Зараз';

  @override
  String get historyHint =>
      'Попередній текст зберігається, коли нотатку правлять після перерви.';

  @override
  String get historyNoChanges => 'Текст той самий';

  @override
  String get historyText => 'Текст';

  @override
  String get historyDiff => 'Різниця';

  @override
  String get historyDiffHint =>
      'Закреслено — було в цій версії, підсвічено — з\'явилося після';

  @override
  String get historyRestore => 'Повернути цю версію';

  @override
  String get historyRestored => 'Версію повернено';

  @override
  String get sortByColor => 'За кольором';

  @override
  String qrWifi(String network) {
    return 'Wi-Fi «$network»';
  }

  @override
  String get qrCopyPassword => 'Скопіювати пароль Wi-Fi';

  @override
  String get qrPasswordCopied => 'Пароль скопійовано';

  @override
  String get qrOpenLink => 'Відкрити посилання з QR-коду';

  @override
  String get qrCopyText => 'Скопіювати текст QR-коду';

  @override
  String get foundInQr => 'у QR-коді';

  @override
  String documentPage(String number) {
    return 'стор. $number';
  }

  @override
  String get titleDateSetting => 'Назва фото й відео';

  @override
  String get titleDateShot => 'За днем зйомки';

  @override
  String get titleDateSaved => 'За днем збереження';

  @override
  String get titleDateHint =>
      'Фото й відео без підпису отримують дату в назві.';

  @override
  String get factPassword => 'Пароль ••••••';

  @override
  String factPasswordFor(String network) {
    return 'Wi-Fi «$network» ••••••';
  }

  @override
  String get factCopyPassword => 'Скопіювати пароль';

  @override
  String factCard(String last) {
    return 'Картка ••$last';
  }

  @override
  String get factCopyCard => 'Скопіювати номер картки';

  @override
  String factPromo(String code) {
    return 'Промокод $code';
  }

  @override
  String get factCopyPromo => 'Скопіювати промокод';

  @override
  String get factTrack => 'Відстежити посилку';

  @override
  String get factOnMap => 'Відкрити на мапі';

  @override
  String get workEndRow => 'Робота до';

  @override
  String get toChecklist => 'Списком покупок';

  @override
  String get toChecklistHint => 'Зробити пункти галочками';

  @override
  String get toChecklistDone => 'Список покупок готовий';

  @override
  String folderTotal(String sum) {
    return 'Усього $sum';
  }

  @override
  String get smartSave => 'Розумна тека';

  @override
  String smartSaved(String name) {
    return 'Розумна тека «$name» — на головній';
  }

  @override
  String get smartEmpty => 'Поки нічого не підходить під цей запит';

  @override
  String get smartDelete => 'Видалити розумну теку';

  @override
  String smartDeleted(String name) {
    return 'Розумну теку «$name» видалено, нотатки на місці';
  }

  @override
  String suggestSite(int count, String site) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count посилання',
      many: '$count посилань',
      few: '$count посилання',
      one: '$count посилання',
    );
    return '$_temp0 з $site без теки';
  }

  @override
  String suggestScreenshots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count скриншота',
      many: '$count скриншотів',
      few: '$count скриншоти',
      one: '$count скриншот',
    );
    return '$_temp0 без теки';
  }

  @override
  String suggestVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ролика',
      many: '$count роликів',
      few: '$count ролики',
      one: '$count ролик',
    );
    return '$_temp0 без теки';
  }

  @override
  String suggestFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файлу',
      many: '$count файлів',
      few: '$count файли',
      one: '$count файл',
    );
    return '$_temp0 без теки';
  }

  @override
  String suggestVoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count голосового',
      many: '$count голосових',
      few: '$count голосових',
      one: '$count голосове',
    );
    return '$_temp0 без теки';
  }

  @override
  String suggestSiteBody(String name) {
    return 'Зробити теку «$name»? Нові посилання з цього сайту лягатимуть туди самі.';
  }

  @override
  String suggestBody(String name) {
    return 'Зробити теку «$name» і перекласти їх туди?';
  }

  @override
  String get suggestYes => 'Зробити';

  @override
  String get suggestNo => 'Не треба';

  @override
  String suggestDone(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count нотатки',
      many: '$count нотаток',
      few: '$count нотатки',
      one: '$count нотатка',
    );
    return 'Тека «$name»: $_temp0';
  }

  @override
  String get suggestScreenshotsName => 'Скриншоти';

  @override
  String get suggestVideosName => 'Ролики';

  @override
  String get suggestFilesName => 'Файли';

  @override
  String get suggestVoicesName => 'Голосові';

  @override
  String get ruleIfPage => 'це сторінка';

  @override
  String get ruleIfPriceAbove => 'ціна більша';

  @override
  String get ruleIfPriceBelow => 'ціна менша';

  @override
  String get ruleValuePrice => 'Сума, наприклад 1000';

  @override
  String rulePriceAboveValue(String value) {
    return 'дорожче $value';
  }

  @override
  String rulePriceBelowValue(String value) {
    return 'дешевше $value';
  }

  @override
  String get ruleThenRemind => 'нагадати';

  @override
  String get remindHourBefore => 'за годину';

  @override
  String get remindDayBefore => 'за день';

  @override
  String get remindWeekBefore => 'за тиждень';

  @override
  String codeWait(Object seconds) {
    return 'Зачекайте $seconds с';
  }

  @override
  String get codeFingerprint => 'Відбиток';

  @override
  String get codeErase => 'Стерти';

  @override
  String get codeDone => 'Готово';

  @override
  String get codeWrong => 'Неправильний код';

  @override
  String get codeCreateTitle => 'Придумайте код';

  @override
  String get codeRepeatTitle => 'Повторіть код';

  @override
  String get codeCreateHint =>
      'Від 6 до 12 цифр: забудете код — приховані нотатки не повернути.';

  @override
  String get codeMismatch => 'Коди не збіглися, придумайте заново';

  @override
  String get hiddenOpenReason => 'Відкрити приховані папки';

  @override
  String get hiddenOpenTitle => 'Код прихованих папок';

  @override
  String get codeForgot => 'Забув код';

  @override
  String get codeOldTitle => 'Поточний код';

  @override
  String get codeNewTitle => 'Новий код';

  @override
  String get codeChanged => 'Код змінено';

  @override
  String get codeForgetTitle => 'Зняти код?';

  @override
  String get codeForgetText =>
      'Замок вимкнеться, приховані папки зітруться разом із нотатками. Повернути їх не вийде.';

  @override
  String get codeForgetAction => 'Зняти код і стерти приховане';

  @override
  String folderHidden(Object name) {
    return 'Папку «$name» приховано';
  }

  @override
  String folderUnhidden(Object name) {
    return 'Папка «$name» знову видима';
  }

  @override
  String get lockReason => 'Відкрити Stowa';

  @override
  String get lockTitle => 'Введіть код';

  @override
  String get codeEnterTitle => 'Введіть код';

  @override
  String get closeAfterNow => 'Одразу';

  @override
  String get closeAfterMinute => 'Через хвилину';

  @override
  String closeAfterMinutes(Object minutes) {
    return 'Через $minutes хвилин';
  }

  @override
  String get privacySection => 'Приватність';

  @override
  String get codeCreateRow => 'Завести код';

  @override
  String get appLockRow => 'Код на вхід';

  @override
  String get fingerprintRow => 'Відбиток пальця';

  @override
  String get closeAfterRow => 'Замикати знову';

  @override
  String get hiddenCloseRow => 'Закрити приховані папки';

  @override
  String get hiddenOpenRow => 'Відкрити приховані папки';

  @override
  String get codeChangeRow => 'Змінити код';

  @override
  String get privacyHint =>
      'Приховані папки зашифровані, без коду їх не прочитати.';

  @override
  String get markdownExport => 'Вивантажити в Markdown';

  @override
  String get markdownNoVault => 'Спершу виберіть папку сховища';

  @override
  String get markdownHiddenAsk => 'Вивантажити й приховані папки?';

  @override
  String get markdownHiddenHint =>
      'Приховані нотатки ляжуть звичайними файлами, їх прочитає будь-хто, у кого опиниться ця папка.';

  @override
  String get markdownWithoutHidden => 'Без прихованих';

  @override
  String get markdownWithHidden => 'Разом із прихованими';

  @override
  String markdownDone(Object path) {
    return 'Вивантажив у $path';
  }

  @override
  String get markdownFailed => 'Не вдалося записати в цю папку';

  @override
  String get folderUnhide => 'Не приховувати';

  @override
  String get folderHide => 'Приховати папку';

  @override
  String get folderHiddenMark => 'прихована';

  @override
  String get hiddenFolders => 'Приховані папки';

  @override
  String get hiddenReminder => 'Нагадування з прихованої папки';

  @override
  String get aiFirst => 'ШІ в пріоритеті';

  @override
  String get aiFirstHint =>
      'Модель перевіряє й те, що застосунок розклав сам, запитів стане більше';

  @override
  String get composerHintNoSearch => 'Закинь що завгодно';

  @override
  String get returnsOff => 'Вимкнено';

  @override
  String get crashSetting => 'Звіти про помилки';

  @override
  String get crashSettingHint =>
      'Розробник отримує помилку й модель телефона, без нотаток і назв файлів.';

  @override
  String get vaultInFiles => '«Файли» → Stowa';

  @override
  String get vaultFilesHint =>
      'Нотатки лежать звичайними файлами .md, їх видно в застосунку «Файли».';

  @override
  String get itemDateChange => 'Змінити дату';

  @override
  String get itemDateNow => 'Зараз';

  @override
  String get itemDatePick => 'Вибрати день і час';

  @override
  String get itemDateChanged => 'Дату змінено';

  @override
  String get propertiesTitle => 'Властивості';

  @override
  String propertiesMore(Object count) {
    return 'Ще $count';
  }

  @override
  String get propertiesLess => 'Згорнути';

  @override
  String get propertyAdd => 'Додати властивість';

  @override
  String get propertyNew => 'Нова властивість';

  @override
  String get propertyEdit => 'Властивість';

  @override
  String get propertyNameHint => 'Назва';

  @override
  String get propertyValueHint => 'Значення';

  @override
  String get propertyListHint => 'Кожен пункт з нового рядка';

  @override
  String get propertyKindText => 'Текст';

  @override
  String get propertyKindList => 'Список';

  @override
  String get propertyKindNumber => 'Число';

  @override
  String get propertyKindCheckbox => 'Прапорець';

  @override
  String get propertyKindDate => 'Дата';

  @override
  String get propertyNameTaken => 'Така властивість уже є';

  @override
  String get propertyNumberWrong => 'Тут потрібне число';

  @override
  String get propertyDatePick => 'Вибрати день';

  @override
  String get propertyDelete => 'Видалити властивість';

  @override
  String get propertyRemoved => 'Властивість видалено';

  @override
  String get propertyOtherHint => 'Таке значення змінюється у файлі нотатки.';

  @override
  String get propertyYes => 'Так';

  @override
  String get propertyNo => 'Ні';

  @override
  String get lookSuggested => 'Пасують до назви';

  @override
  String get lookPopular => 'Часті';

  @override
  String get lookAll => 'Усі іконки';

  @override
  String get iconsNone =>
      'Такої іконки немає, спробуй інше слово або англійською.';
}
