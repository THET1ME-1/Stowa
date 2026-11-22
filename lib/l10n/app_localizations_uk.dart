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
  String get reasonNone => 'без теки, розкладу пізніше';

  @override
  String get reasonAsIs => 'unsorted, as asked';

  @override
  String get actionStow => 'Закинути';

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
  String get cmdRemind => 'нагадати';

  @override
  String get cmdTask => 'завдання';

  @override
  String get cmdList => 'список';

  @override
  String get cmdFind => 'знайти';

  @override
  String get cmdInbox => 'вхідні';

  @override
  String get cmdRemindHint => 'Скажи коли: «завтра о 10», «у пт»';

  @override
  String get cmdTaskHint => 'Ляже з галочкою';

  @override
  String get cmdListHint => 'Кожен рядок або кома стане пунктом';

  @override
  String get cmdFindHint => 'Лише шукати, нічого не зберігати';

  @override
  String get cmdInboxHint => 'Покласти як є, без розбору';

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
  String get voiceFold => 'Згорнути запис';

  @override
  String get voiceUnfold => 'Розгорнути запис';

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
  String get tabsSection => 'Вкладки';

  @override
  String get tabCloseTitle => 'Хрестик закриття вкладки';

  @override
  String get tabCloseLeft => 'Ліворуч';

  @override
  String get tabCloseRight => 'Праворуч';

  @override
  String get tabsHint => 'Подвійне клацання по вкладці теж закриває її.';

  @override
  String get trayPhotos => 'Фото й відео';

  @override
  String get trayPickHint => 'Вибери фото й відео з галереї';

  @override
  String get trayPickHintDesk =>
      'Вибери файли, фото й відео або перетягни їх у вікно';

  @override
  String get trayPick => 'Вибрати';

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
      'Не знаєш, що вибрати, — тисни «Створити»: це звичайна тека в телефоні.';

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
      'Напишеш «буду проходити повз аптеку» чи «зайду до Саші» — Stowa нагадає біля цього місця.';

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
  String get aiFirstHint => 'Модель перевіряє й те, що розкладено без неї.';

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

  @override
  String get placeKindHome => 'Дім';

  @override
  String get placeKindWork => 'Робота';

  @override
  String get placeKindStudy => 'Навчання';

  @override
  String get placeKindShop => 'Магазин';

  @override
  String get placeKindPharmacy => 'Аптека';

  @override
  String get placeKindFood => 'Кафе й ресторани';

  @override
  String get placeKindSport => 'Спорт';

  @override
  String get placeKindGuests => 'Гості';

  @override
  String get placeKindOther => 'Інше';

  @override
  String get placeRemindStudy => 'Нагадати на навчанні';

  @override
  String get placeRemindPharmacy => 'Нагадати біля аптеки';

  @override
  String get placeRemindFood => 'Нагадати в кафе';

  @override
  String get placeRemindSport => 'Нагадати в залі';

  @override
  String get placeRemindGuests => 'Нагадати в гостях';

  @override
  String get placeRemindOther => 'Нагадати біля місця';

  @override
  String placeRemindDay(String place, String day) {
    return '$place · $day';
  }

  @override
  String get dayToday => 'сьогодні';

  @override
  String get dayTomorrow => 'завтра';

  @override
  String get placesMissingKind =>
      'Такого місця ще немає: нагадаю, коли позначиш його в «Місцях»';

  @override
  String get placesAdd => 'Додати місце';

  @override
  String get placesEmpty =>
      'Місць поки немає: додай дім, роботу, улюблене кафе чи друга.';

  @override
  String get placeNewTitle => 'Нове місце';

  @override
  String get placeEditTitle => 'Місце';

  @override
  String get placeNameHint => 'Як назвати: Універ, Саша, Andy’s';

  @override
  String get placeKindTitle => 'Що це';

  @override
  String get placeWhereTitle => 'Де';

  @override
  String get placeHereNow => 'Я зараз тут';

  @override
  String get placeMapHint => 'Рухай мапу: місце там, де крапка в центрі.';

  @override
  String get placeKindMore => 'Знайти чи створити';

  @override
  String get placeKindSearchHint => 'Знайти вид або назвати свій';

  @override
  String placeKindCreate(String name) {
    return 'Створити «$name»';
  }

  @override
  String get placeIcon => 'Значок';

  @override
  String get lineLanguageHint =>
      'Час словами цією мовою не зрозумію — пиши цифрами: 14:30';

  @override
  String get lineLanguageHide => 'Сховати';

  @override
  String get placeSearchHint => 'Знайти адресу або місце';

  @override
  String get placeSearchNone => 'Нічого не знайшлося';

  @override
  String get placeMapEmpty =>
      'Знайди адресу або затисни карту, щоб поставити точку';

  @override
  String get placeMapMove => 'Затисни карту, щоб перенести точку';

  @override
  String get placePointMoved => 'Точку перенесено';

  @override
  String get placeNoPoint => 'Точку не вибрано';

  @override
  String get placeKindOwn => 'Свій вид';

  @override
  String placeRadiusValue(int meters) {
    return '$meters м';
  }

  @override
  String get placeRadiusTitle => 'Радіус нагадування';

  @override
  String get relatedInText => 'у тексті нотатки';

  @override
  String get relatedBacklink => 'посилається сюди';

  @override
  String get relatedManual => 'зв’язок вручну';

  @override
  String relatedAi(String reason) {
    return 'ШІ: $reason';
  }

  @override
  String get relatedAiPlain => 'зв’язок від ШІ';

  @override
  String get relatedUnlink => 'Прибрати зв’язок';

  @override
  String get relatedUnlinked => 'Зв’язок прибрано';

  @override
  String get linkAdd => 'Зв’язати з нотаткою';

  @override
  String get linkAddShort => 'Зв’язок';

  @override
  String get linkSearchHint => 'Знайти нотатку за словами';

  @override
  String get linkNone => 'Такої нотатки немає';

  @override
  String linkAdded(String title) {
    return 'Зв’язано з «$title»';
  }

  @override
  String linkMissing(String title) {
    return 'Нотатки «$title» немає';
  }

  @override
  String get settingsCatalog => 'Сховище';

  @override
  String get settingsLook => 'Вигляд';

  @override
  String get settingsHelpers => 'Розбір і сповіщення';

  @override
  String get settingsCopies => 'Копії';

  @override
  String get vaultsSection => 'Сховища';

  @override
  String get vaultOpenNow => 'Відкрито';

  @override
  String get vaultAdd => 'Додати сховище';

  @override
  String get vaultAddNew => 'Створити нове';

  @override
  String get vaultAddNewHint => 'Порожня тека для нових нотаток';

  @override
  String get vaultAddOpen => 'Відкрити теку';

  @override
  String get vaultAddOpenHint => 'Колишнє сховище Stowa або Obsidian';

  @override
  String get vaultsHint =>
      'Дотик до іншого сховища відкриває його, нагадування приходять лише з відкритого.';

  @override
  String get vaultFolderGone => 'Теку не знайдено';

  @override
  String get vaultForget => 'Прибрати зі списку';

  @override
  String get vaultForgetHint => 'Файли залишаться в теці';

  @override
  String get vaultForgotten => 'Сховище прибрано зі списку, файли на місці';

  @override
  String get vaultOpenIt => 'Відкрити';

  @override
  String get vaultAlreadyOpen => 'Це сховище вже відкрите';

  @override
  String vaultForeignAsk(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файлу',
      many: '$count файлів',
      few: '$count файли',
      one: '$count файл',
    );
    return 'У «$name» $_temp0, нотаток серед них немає';
  }

  @override
  String vaultForeignMany(String name, int count) {
    return 'У «$name» понад $count файлів, нотаток серед них немає';
  }

  @override
  String get vaultForeignOpen => 'Усе одно зробити сховищем';

  @override
  String get vaultForeignOpenHint => 'Кожен файл стане окремою нотаткою-файлом';

  @override
  String get vaultHasNotes => 'У цій теці вже є нотатки';

  @override
  String get vaultOpenSeparately => 'Відкрити окремим сховищем';

  @override
  String get vaultOpenSeparatelyHint => 'Поточне залишиться у списку';

  @override
  String get vaultMergeHere => 'Перенести сюди й об’єднати';

  @override
  String get vaultMergeHereHint => 'Нотатки обох опиняться в одній теці';

  @override
  String vaultSwitching(String name) {
    return 'Відкриваю «$name»';
  }

  @override
  String get vaultChangeFolder => 'Змінити теку';

  @override
  String vaultAllCount(int count) {
    return 'Усі сховища · $count';
  }

  @override
  String get syncTitle => 'Stowa Sync';

  @override
  String get syncPaid => 'Платно';

  @override
  String get syncSoon => 'Незабаром';

  @override
  String get syncAbout =>
      'Нотатки самі зійдуться на телефоні, планшеті й комп’ютері.';

  @override
  String get syncLater => 'Підписка з’явиться в одному з наступних оновлень.';

  @override
  String get syncOk => 'Зрозуміло';

  @override
  String get itemPin => 'Закріпити';

  @override
  String get itemUnpin => 'Відкріпити';

  @override
  String get itemPinned => 'Закріпив угорі головної';

  @override
  String get itemUnpinned => 'Відкріпив';

  @override
  String get homePinned => 'Закріплено';

  @override
  String homePinnedMore(Object count) {
    return 'Ще $count';
  }

  @override
  String get homePinnedLess => 'Згорнути';

  @override
  String get catalogReorderHint =>
      'Затисни папку й перетягни: у цьому порядку папки стоять і на головній.';

  @override
  String linkCreate(Object title) {
    return 'Створити нотатку «$title»';
  }

  @override
  String get linkCreateAction => 'Створити';

  @override
  String homeMoreLines(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ще $count рядка',
      many: 'ще $count рядків',
      few: 'ще $count рядки',
      one: 'ще $count рядок',
    );
    return '$_temp0';
  }

  @override
  String get edgeTitle => 'Під рукою';

  @override
  String get edgeSwitch => 'Корінці біля краю';

  @override
  String get edgeSwitchHint =>
      'Закріплені нотатки чекають біля краю екрана, дотик відкриває їх поверх будь-якого застосунку.';

  @override
  String get edgePlace => 'Де';

  @override
  String get edgeLook => 'Вигляд і місце';

  @override
  String get edgeDragHint => 'Потягни корінці на телефоні вгору чи вниз.';

  @override
  String get edgeLeft => 'Ліворуч';

  @override
  String get edgeRight => 'Праворуч';

  @override
  String get edgeHeight => 'Де по висоті';

  @override
  String get edgeHigher => 'вище';

  @override
  String get edgeMiddle => 'посередині';

  @override
  String get edgeLower => 'нижче';

  @override
  String get edgeSize => 'Розмір';

  @override
  String get edgeThin => 'тонкі';

  @override
  String get edgeNormal => 'звичайні';

  @override
  String get edgeLarge => 'великі';

  @override
  String get edgeAlpha => 'Помітність';

  @override
  String get edgeHideVideo => 'Ховати в повноекранному відео';

  @override
  String get edgeHideVideoHint =>
      'Поки відео чи гра на весь екран, корінці не заважають.';

  @override
  String get edgeOff => 'Вимкнено';

  @override
  String get edgeRecent => 'Нещодавні';

  @override
  String get edgeOpenApp => 'Відкрити Stowa';

  @override
  String get edgeStick => 'Повісити стікером';

  @override
  String get edgeSpinesSetup => 'Налаштувати корінці';

  @override
  String get edgeUnstick => 'Зняти стікер';

  @override
  String get edgeNearby => 'Поруч';

  @override
  String get suggestPaste => 'Вставити з буфера';

  @override
  String get edgeGestures => 'Жести';

  @override
  String get edgeGestureSwipe => 'Свайп униз — одразу писати';

  @override
  String get edgeGestureSwipeHint =>
      'Рядок відкривається одразу з клавіатурою.';

  @override
  String get edgeGestureHold => 'Утримання — голосове';

  @override
  String get edgeGestureHoldHint =>
      'Запис триває і без пальця, доки не натиснеш «Зберегти».';

  @override
  String get edgeGestureDouble => 'Подвійний дотик — остання нотатка';

  @override
  String get edgeGestureDoubleHint =>
      'Один дотик тоді спрацьовує трохи пізніше.';

  @override
  String get edgeVoiceChannel => 'Запис голосу';

  @override
  String get edgeVoiceNow => 'Іде запис голосового';

  @override
  String get importSummary =>
      'Telegram, Google Keep, закладки, Obsidian, mymind';

  @override
  String get importKeep => 'З Google Keep';

  @override
  String get importBookmarks => 'Закладки браузера';

  @override
  String get importObsidian => 'З Obsidian';

  @override
  String get importMymind => 'З mymind';

  @override
  String get importScreenHint =>
      'Розпакуй вивантаження на телефон і вибери його папку, а для закладок — файл .html.';

  @override
  String get importNotKeep =>
      'У цій папці немає нотаток Google Keep: потрібна папка Keep з Google Takeout';

  @override
  String get importNotBookmarks =>
      'Це не файл закладок: вивантаж закладки з браузера в .html';

  @override
  String get importNotObsidian => 'У цій папці немає нотаток .md';

  @override
  String get importNotMymind => 'У цій папці немає cards.csv з mymind';

  @override
  String importFilesNotFound(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файлу не знайшлося',
      many: '$count файлів не знайшлося',
      few: '$count файли не знайшлися',
      one: '$count файл не знайшовся',
    );
    return '$_temp0';
  }

  @override
  String get settingsPrivacyPolicy => 'Політика конфіденційності';

  @override
  String get settingsHelp => 'Допомога';

  @override
  String get feedbackRow => 'Повідомити про проблему';

  @override
  String get feedbackRowHint => 'Помилка, ідея чи питання просто звідси';

  @override
  String get supportRow => 'Написати в підтримку';

  @override
  String get feedbackKindBug => 'Помилка';

  @override
  String get feedbackKindIdea => 'Ідея';

  @override
  String get feedbackKindQuestion => 'Питання';

  @override
  String get feedbackField => 'Що сталося і що ви робили перед цим';

  @override
  String get feedbackAttach => 'Додати версію і модель телефона';

  @override
  String get feedbackSend => 'Надіслати';

  @override
  String get feedbackHint =>
      'Звернення прийде нам. Залиште пошту, якщо чекаєте відповіді.';

  @override
  String get feedbackEmail => 'Пошта для відповіді, якщо вона потрібна';

  @override
  String get feedbackSentTitle => 'Надіслано, дякуємо';

  @override
  String feedbackSentReply(String email) {
    return 'Відповімо на $email.';
  }

  @override
  String get feedbackSentQuiet =>
      'Пошту ви не залишили, тож відповісти не зможемо, але прочитаємо все.';

  @override
  String get feedbackAgain => 'Написати ще';

  @override
  String get feedbackFailed =>
      'Не надіслалося. Перевірте інтернет і натисніть ще раз.';

  @override
  String get feedbackTooMany =>
      'На сьогодні звернень із цього телефона вже багато. Напишіть завтра або на пошту в налаштуваннях.';

  @override
  String get feedbackBadEmail => 'У пошті помилка, перевірте адресу.';

  @override
  String get kindsCanvas => 'Canvases';

  @override
  String get kindsBase => 'Bases';

  @override
  String get kindCanvas => 'Canvas';

  @override
  String get kindBase => 'Base';

  @override
  String get canvasNew => 'New canvas';

  @override
  String get baseNew => 'New base';

  @override
  String get canvasDefaultName => 'Без назви';

  @override
  String get baseDefaultName => 'Без назви';

  @override
  String canvasCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '$count card',
      zero: 'no cards',
    );
    return '$_temp0';
  }

  @override
  String baseViews(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count views',
      one: '$count view',
    );
    return '$_temp0';
  }

  @override
  String get canvasAdd => 'Add';

  @override
  String get canvasAddText => 'Text';

  @override
  String get canvasAddNote => 'Note';

  @override
  String get canvasAddLink => 'Link';

  @override
  String get canvasAddGroup => 'Group';

  @override
  String get canvasEdit => 'Edit';

  @override
  String get canvasConnect => 'Connect';

  @override
  String get canvasColor => 'Color';

  @override
  String get canvasDelete => 'Delete';

  @override
  String get canvasDeleted => 'Card deleted';

  @override
  String get canvasEdgeDeleted => 'Arrow deleted';

  @override
  String get canvasEdgeLabel => 'Label';

  @override
  String get canvasConnectHint => 'Tap the card to draw an arrow to';

  @override
  String get canvasEmpty => 'Empty canvas. Double-tap to add a card.';

  @override
  String get canvasBroken =>
      'The canvas file is damaged, so Stowa leaves it alone. Open it in Obsidian.';

  @override
  String get canvasTextHint => 'Card text';

  @override
  String get canvasLinkHint => 'Link address';

  @override
  String get canvasGroupHint => 'Group label';

  @override
  String canvasMissingFile(String name) {
    return 'File not found: $name';
  }

  @override
  String get canvasNoColor => 'No color';

  @override
  String get canvasDone => 'Done';

  @override
  String get canvasPickNote => 'Which note to put on the canvas';

  @override
  String get baseUnsupported =>
      'Stowa didn\'t understand some conditions and skipped them.';

  @override
  String get baseBroken => 'The base file is damaged. Open it in Obsidian.';

  @override
  String get baseEmpty => 'No notes match.';

  @override
  String get baseMapAsList => 'The map view is shown as a list.';

  @override
  String get baseColName => 'Name';

  @override
  String get baseColCreated => 'Created';

  @override
  String get baseColModified => 'Modified';

  @override
  String get baseColFolder => 'Folder';

  @override
  String get baseColTags => 'Tags';

  @override
  String get baseColPath => 'Path';

  @override
  String get baseColLinks => 'Links';

  @override
  String baseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '$count note',
    );
    return '$_temp0';
  }

  @override
  String get baseNoGroup => 'No value';

  @override
  String get documentNew => 'Полотно або база';

  @override
  String get kindDrawing => 'Малюнок';

  @override
  String get kindsDrawing => 'Малюнки';

  @override
  String get drawingTexts => 'Текст малюнка';

  @override
  String get drawingTextCopied => 'Підпис скопійовано';

  @override
  String get drawingEditInObsidian => 'Змінити малюнок можна в Obsidian';

  @override
  String get drawingUnreadable =>
      'Малюнок не прочитався, відкрий його в Obsidian';

  @override
  String drawingTextCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count підписів',
      few: '$count підписи',
      one: '$count підпис',
    );
    return '$_temp0';
  }

  @override
  String get cmdCanvas => 'полотно';

  @override
  String get cmdBase => 'база';

  @override
  String get cmdCanvasHint => 'Нове полотно з цією назвою, відкриється одразу';

  @override
  String get cmdBaseHint => 'Нова база з нотатками папки, відкриється одразу';

  @override
  String get baseSort => 'Сортування';

  @override
  String get baseGroup => 'Група';

  @override
  String get baseFilter => 'Фільтр';

  @override
  String get baseProperties => 'Властивості';

  @override
  String get baseSearch => 'Пошук';

  @override
  String get baseSearchHint => 'Шукати в базі';

  @override
  String get baseCreate => 'Створити';

  @override
  String baseShown(int shown, int total) {
    return 'Показано $shown з $total';
  }

  @override
  String get baseSortAdd => 'Додати сортування';

  @override
  String get baseAscending => 'За зростанням';

  @override
  String get baseDescending => 'За спаданням';

  @override
  String get baseGroupNone => 'Без групи';

  @override
  String get baseFilterAll => 'Усі види';

  @override
  String get baseFilterThis => 'Цей вид';

  @override
  String get baseFilterEmpty => 'Умов немає, видно всі нотатки.';

  @override
  String get baseJoinAll => 'Усі умови';

  @override
  String get baseJoinAny => 'Будь-яка з умов';

  @override
  String get baseJoinNone => 'Жодна з умов';

  @override
  String get baseFilterAdd => 'Додати умову';

  @override
  String get baseFilterAddGroup => 'Додати групу';

  @override
  String get baseMoveToAll => 'Перенести в усі види';

  @override
  String get baseMoveToThis => 'Перенести в цей вид';

  @override
  String get baseExpression => 'Вираз';

  @override
  String get baseValue => 'Значення';

  @override
  String get baseOpIs => 'дорівнює';

  @override
  String get baseOpIsNot => 'не дорівнює';

  @override
  String get baseOpContains => 'містить';

  @override
  String get baseOpNotContains => 'не містить';

  @override
  String get baseOpStarts => 'починається з';

  @override
  String get baseOpEnds => 'закінчується на';

  @override
  String get baseOpEmpty => 'порожньо';

  @override
  String get baseOpNotEmpty => 'не порожньо';

  @override
  String get baseOpGreater => 'більше';

  @override
  String get baseOpAtLeast => 'не менше';

  @override
  String get baseOpLess => 'менше';

  @override
  String get baseOpAtMost => 'не більше';

  @override
  String get baseOpHasTag => 'є тег';

  @override
  String get baseOpNotHasTag => 'немає тегу';

  @override
  String get baseOpInFolder => 'у папці';

  @override
  String get baseOpNotInFolder => 'не в папці';

  @override
  String get baseOpHasLink => 'посилається на';

  @override
  String get baseFormulaAdd => 'Додати формулу';

  @override
  String get baseFormulaName => 'Назва';

  @override
  String baseFormulaError(String what) {
    return 'Не зрозумів: $what';
  }

  @override
  String get baseFormulaEdit => 'Змінити формулу';

  @override
  String get baseFormulaDelete => 'Видалити формулу';

  @override
  String get baseRename => 'Перейменувати';

  @override
  String get baseRemove => 'Прибрати';

  @override
  String get baseColumnHide => 'Сховати колонку';

  @override
  String get baseShownProps => 'Показано';

  @override
  String get baseOtherProps => 'Інші властивості';

  @override
  String get baseSummary => 'Підсумок';

  @override
  String get baseSummaryNone => 'Без підсумку';

  @override
  String get baseSumAverage => 'Середнє';

  @override
  String get baseSumMedian => 'Медіана';

  @override
  String get baseSumMin => 'Найменше';

  @override
  String get baseSumMax => 'Найбільше';

  @override
  String get baseSumSum => 'Сума';

  @override
  String get baseSumRange => 'Розкид';

  @override
  String get baseSumStddev => 'Відхилення';

  @override
  String get baseSumEarliest => 'Найраніша';

  @override
  String get baseSumLatest => 'Найпізніша';

  @override
  String get baseSumChecked => 'Позначено';

  @override
  String get baseSumUnchecked => 'Не позначено';

  @override
  String get baseSumEmpty => 'Порожніх';

  @override
  String get baseSumFilled => 'Заповнено';

  @override
  String get baseSumUnique => 'Різних';

  @override
  String get baseViewAdd => 'Додати вид';

  @override
  String get baseViewLayout => 'Розкладка';

  @override
  String get baseViewCopy => 'Копія виду';

  @override
  String get baseViewDelete => 'Видалити вид';

  @override
  String get baseViewSettings => 'Налаштування виду';

  @override
  String get baseLayoutTable => 'Таблиця';

  @override
  String get baseLayoutCards => 'Картки';

  @override
  String get baseLayoutList => 'Список';

  @override
  String get baseLayoutKanban => 'Дошка';

  @override
  String get baseLayoutMap => 'Мапа';

  @override
  String get baseLimit => 'Скільки показувати';

  @override
  String get baseLimitNone => 'Усі';

  @override
  String get baseImage => 'Картинка з властивості';

  @override
  String get baseImageNone => 'Без картинки';

  @override
  String get baseCardSize => 'Розмір картки';

  @override
  String get baseImageRatio => 'Пропорція картинки';

  @override
  String get baseImageFitCover => 'Обрізати по рамці';

  @override
  String get baseImageFitContain => 'Повністю';

  @override
  String get baseKanbanNeedsGroup =>
      'Виберіть у «Групі» властивість для колонок.';

  @override
  String get baseUntitled => 'Без назви';

  @override
  String get baseColExt => 'Тип файлу';

  @override
  String get baseSectionNotes => 'Властивості нотаток';

  @override
  String get baseSectionFile => 'Файл';

  @override
  String get folderCreateInside => 'Створити всередині';

  @override
  String get folderTileFolder => 'Теку';

  @override
  String get folderTileCanvas => 'Полотно';

  @override
  String get folderTileBase => 'Базу';

  @override
  String get folderEdit => 'Назва і вигляд';

  @override
  String get startStow => 'Напиши що завгодно й натисни «Закинути».';

  @override
  String get startSearch =>
      'Цей самий рядок шукає: набери слово зі своєї нотатки.';

  @override
  String get startRemind => 'Час у тексті — вже нагадування.';

  @override
  String get startFolder => 'Знак @ кладе нотатку в теку, нову чи наявну.';

  @override
  String get startTag => 'Знак # ставить мітку, за нею нотатку легко знайти.';

  @override
  String get startCommands =>
      'Знак / відкриває команди: список, завдання, полотно.';

  @override
  String get startFinish =>
      'Знайомство завершено, повернути його можна в налаштуваннях.';

  @override
  String get startTry => 'Спробувати';

  @override
  String get startSkip => 'Пропустити';

  @override
  String get startRemindExample => 'Подзвонити мамі завтра о 10';

  @override
  String get startFolderExample => '@Покупки ';

  @override
  String get startTagExample => '#ідея ';

  @override
  String get lineExplainTag => 'Набери слово: #ідея, #робота';

  @override
  String get lineExplainFolder =>
      'Набери назву: є така — виберу, немає — створю';

  @override
  String get tipNoteBar => 'Унизу: нагадати, мітка, інша тека і «поділитися».';

  @override
  String get tipLongPress =>
      'Затисни нотатку: закріпити, перекласти чи видалити.';

  @override
  String get tipCatalog => 'Затисни теку й перетягни, щоб змінити порядок.';

  @override
  String get tipFolderMenu =>
      'Три крапки вгорі: тека всередині, полотно, база, назва й колір.';

  @override
  String get tipSort =>
      '«Розібрати» показує нотатки по одній, а ти кладеш кожну в теку.';

  @override
  String get tipCanvas => 'Торкнися порожнього місця двічі, щоб додати картку.';

  @override
  String get tipBase =>
      'Значки вгорі: сортування, група, фільтр, колонки, пошук.';

  @override
  String get tipAiKey =>
      'Ключ беруть у постачальника ШІ, на openrouter.ai є безплатні моделі.';

  @override
  String get tipEdge =>
      'Корінці — тонкі ярлики біля краю екрана, тягни їх усередину.';

  @override
  String get tipClose => 'Зрозуміло';

  @override
  String get hintsToggle => 'Підказки';

  @override
  String get hintsRestart => 'Почати знайомство знову';

  @override
  String get hintsRestarted => 'Знайомство почнеться на головній';

  @override
  String get attachmentsSection => 'Вкладення';

  @override
  String get attachmentsShared => 'У спільній теці';

  @override
  String get attachmentsNear => 'Поруч із нотаткою';

  @override
  String get attachmentsSub => 'У підтеці поруч із нотаткою';

  @override
  String get attachmentsRoot => 'У корені сховища';

  @override
  String get attachmentsHint =>
      'Стосується нових фото й файлів, старі лишаються на місці.';

  @override
  String get attachmentsWithObsidian => 'Те саме налаштування, що в Obsidian';

  @override
  String get attachmentsNameLabel => 'Назва теки';

  @override
  String get attachmentsNameBad =>
      'Така назва не підійде: без крапки на початку й без «..».';

  @override
  String get attachmentsObsidianBroken =>
      'Налаштування Obsidian не читаються, вибір не збережено.';

  @override
  String get codeCopy => 'Скопіювати код';

  @override
  String get codeCopied => 'Скопійовано';

  @override
  String codeShowAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Показати все · $count рядка',
      many: 'Показати все · $count рядків',
      few: 'Показати все · $count рядки',
      one: 'Показати все · $count рядок',
    );
    return '$_temp0';
  }

  @override
  String get codeCollapse => 'Згорнути';

  @override
  String get mdMath => 'Формула';

  @override
  String get mdMathNext => 'Наступне поле формули';

  @override
  String get settingsLine => 'Поле введення';

  @override
  String get enterKeyTitle => 'Enter на клавіатурі';

  @override
  String get enterNewLine => 'Новий рядок';

  @override
  String get enterStow => 'Закинути нотатку';

  @override
  String get enterHint =>
      'У полі введення на весь екран Enter завжди починає новий рядок.';

  @override
  String get noticePin => 'Закріпити в сповіщеннях';

  @override
  String get noticeUnpin => 'Прибрати зі сповіщень';

  @override
  String get noticePinned => 'Нотатку закріплено в сповіщеннях';

  @override
  String get noticeUnpinned => 'Нотатку прибрано зі сповіщень';

  @override
  String get noticeChannel => 'Закріплені нотатки';

  @override
  String get noticeRemove => 'Прибрати';

  @override
  String get noticeHiddenTitle => 'Закріплена нотатка';

  @override
  String get syncOff => 'Вимкнена';

  @override
  String get syncIntro =>
      'Нотатки однакові на телефоні й на сайті, а шифруються ще до надсилання.';

  @override
  String get syncEmail => 'Пошта';

  @override
  String get syncGetCode => 'Отримати код';

  @override
  String syncCodeSent(String email) {
    return 'Код надіслано на $email';
  }

  @override
  String get syncCode => 'Код із листа';

  @override
  String get syncSignIn => 'Увійти';

  @override
  String syncResendIn(int seconds) {
    return 'Надіслати знову через $seconds с';
  }

  @override
  String get syncResend => 'Надіслати код знову';

  @override
  String get syncOtherEmail => 'Інша пошта';

  @override
  String get syncWrongCode => 'Код неправильний або застарів';

  @override
  String get syncMailFailed =>
      'Лист не надіслано, перевірте інтернет і спробуйте ще раз';

  @override
  String get syncNoServer => 'Немає зв\'язку з сервером';

  @override
  String get syncNow => 'Синхронізувати зараз';

  @override
  String get syncRunning => 'Синхронізація…';

  @override
  String syncLast(String time) {
    return 'Синхронізовано о $time';
  }

  @override
  String get syncInactive => 'Синхронізацію для цього акаунта не ввімкнено';

  @override
  String get syncMassDelete =>
      'Зникло багато файлів одразу, тож на інших пристроях їх не видалено';

  @override
  String get syncVaultUnreadable => 'Не вдалося прочитати теку сховища';

  @override
  String get syncOffline =>
      'Сервер недоступний, синхронізація продовжиться сама';

  @override
  String get syncOtherVault => 'Синхронізується інше сховище';

  @override
  String get syncNoVault => 'Спершу виберіть теку сховища';

  @override
  String get syncSignOut => 'Вийти';

  @override
  String get syncSignOutHint => 'Нотатки на цьому пристрої залишаться.';

  @override
  String get syncStepFolder => 'Тека';

  @override
  String get syncStepReceive => 'Прийом';

  @override
  String get syncStepSend => 'Відправка';

  @override
  String get syncStepPlace => 'Нотатки';

  @override
  String get syncDoingFolder => 'Перевіряю теку';

  @override
  String get syncDoingReceive => 'Отримую з сервера';

  @override
  String get syncDoingSend => 'Звіряю й надсилаю';

  @override
  String get syncDoingPlace => 'Розкладаю нотатки';

  @override
  String syncOf(String done, String total) {
    return '$done з $total';
  }

  @override
  String syncOfMb(String done, String total) {
    return '$done з $total МБ';
  }

  @override
  String syncOfGb(String done, String total) {
    return '$done з $total ГБ';
  }

  @override
  String syncPassReceived(int count) {
    return 'Отримано: $count';
  }

  @override
  String syncPassSent(int count) {
    return 'Надіслано: $count';
  }

  @override
  String syncPassBoth(int received, int sent) {
    return 'Отримано: $received, надіслано: $sent';
  }

  @override
  String get wsSections => 'Розділи';

  @override
  String get wsHome => 'Головна';

  @override
  String get wsFind => 'Знайти або записати';

  @override
  String get wsSplitRight => 'Розділити праворуч';

  @override
  String get wsSplitDown => 'Розділити вниз';

  @override
  String get wsCloseTab => 'Закрити вкладку';

  @override
  String get wsLeftDock => 'Ліва панель';

  @override
  String get wsRightDock => 'Права панель';

  @override
  String get wsYearAgo => 'Рік тому';

  @override
  String get wsKeys => 'Сполучення клавіш';

  @override
  String get wsTheme => 'Змінити тему';

  @override
  String get wsInBrowser => 'У цьому браузері';

  @override
  String get wsSynced => 'Синхронізовано';

  @override
  String get wsSyncOff => 'Синхронізацію вимкнено';

  @override
  String get wsGroupNav => 'Пошук і перехід';

  @override
  String get wsGroupNotes => 'Нотатки й папки';

  @override
  String get wsGroupTabs => 'Вкладки й вікна';

  @override
  String get wsGroupDocks => 'Панелі й розкладки';

  @override
  String get wsCmdPalette => 'Усі команди';

  @override
  String get wsCmdSwitch => 'Відкрити нотатку за назвою';

  @override
  String get wsCmdHome => 'На головну';

  @override
  String get wsCmdNew => 'Нова нотатка';

  @override
  String get wsCmdTrash => 'Видалити в кошик';

  @override
  String get wsCmdPin => 'Закріпити нотатку';

  @override
  String get wsCmdMove => 'Перекласти в папку';

  @override
  String get wsCmdEdit => 'Редагування і перегляд нотатки';

  @override
  String get wsCmdReopen => 'Повернути закриту вкладку';

  @override
  String get wsCmdNext => 'Наступна вкладка';

  @override
  String get wsCmdPrev => 'Попередня вкладка';

  @override
  String get wsCmdNextPane => 'Сусіднє вікно';

  @override
  String get wsCmdPrevPane => 'Попереднє вікно';

  @override
  String get wsCmdClosePane => 'Закрити вікно';

  @override
  String get wsCmdTheme => 'Світла чи темна тема';

  @override
  String get wsThen => 'потім';

  @override
  String get wsKeysHint =>
      'Одна клавіша без Ctrl і Alt спрацьовує, коли курсор не в полі введення, а клавіші ловляться за місцем на клавіатурі в будь-якій розкладці.';

  @override
  String get wsKeysResetAll => 'Повернути все як було';

  @override
  String get wsKeysAdd => 'Додати сполучення';

  @override
  String get wsKeysPress => 'Натисніть сполучення · Esc — скасувати';

  @override
  String wsKeysTaken(String name) {
    return 'Сполучення знято з «$name»';
  }

  @override
  String get wsKeysBrowser => 'Це сполучення браузер залишає собі';

  @override
  String get wsKeysReset => 'Повернути як було';

  @override
  String get wsKeysRemove => 'Прибрати';

  @override
  String get wsChanged => 'змінено';

  @override
  String get wsPaletteHint => 'Команда або назва нотатки';

  @override
  String get wsOpenNoteFirst => 'Спершу відкрийте нотатку';

  @override
  String get wsAddPanel => 'Панель';

  @override
  String get wsToRight => 'У праву панель';

  @override
  String get wsToLeft => 'У ліву панель';

  @override
  String get wsHidePanel => 'Прибрати панель';

  @override
  String get wsPanelEmpty => 'Поки порожньо';

  @override
  String get canvasDropHint => 'Відпустіть — файли стануть на полотно';

  @override
  String get tabBusyTitle => 'Stowa вже відкрита в іншій вкладці';

  @override
  String get tabBusyHint =>
      'Дві вкладки разом зіпсували б нотатки, тому працює одна.';

  @override
  String get tabBusyOpenHere => 'Відкрити тут';

  @override
  String get tabBusyWaiting => 'Та вкладка закриває нотатки…';

  @override
  String backupMergeAsk(String date) {
    return 'Додати до сховища нотатки з копії від $date? Нинішні залишаться, а однойменні файли заміняться.';
  }

  @override
  String get backupAdd => 'Додати';

  @override
  String get copyNudgeFirst =>
      'Нотатки лежать лише в цьому браузері: збережіть копію, щоб їх не втратити.';

  @override
  String get copyNudgeStale => 'Копія нотаток застаріла: збережіть свіжу.';

  @override
  String get copyNudgeLater => 'Пізніше';

  @override
  String get storageWeak =>
      'Браузер не дав надійного сховища: нотатки можуть зникнути, коли вкладку закриють.';

  @override
  String get vaultBrowserHint =>
      'Нотатки лежать у сховищі цього браузера, на диску їх не видно.';

  @override
  String vaultBuildingFiles(int done, int total) {
    return 'Звіряю файли: $done з $total';
  }

  @override
  String vaultBuildingExtras(int done, int total) {
    return 'Доробляю покажчик: $done з $total';
  }

  @override
  String get wsEmptyTitle => 'Тут будуть твої нотатки';

  @override
  String get wsEmptyBody =>
      'Закинь у рядок знизу думку, посилання чи файл, і Stowa сама розкладе їх по теках.';

  @override
  String get wsEmptyWrite => 'Записати першу нотатку';

  @override
  String get wsEmptyFolder => 'Створити теку';

  @override
  String get wsEmptyRestore => 'Повернути з копії';

  @override
  String get itemPropFolder => 'Тека';

  @override
  String get itemPropTags => 'Теги';

  @override
  String get itemPropRemind => 'Нагадати';

  @override
  String get itemPropPlace => 'Місце';

  @override
  String get itemPropCreated => 'Створено';

  @override
  String get itemPropTaken => 'Знято';

  @override
  String get itemPropLinks => 'Зв’язки';

  @override
  String get itemWriteMore => 'Дописати текст…';

  @override
  String get graphLoading => 'Розкладаю зв’язки…';

  @override
  String folderSubAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count теки',
      many: '$count тек',
      few: '$count теки',
      one: '$count тека',
    );
    return 'Усі $_temp0';
  }

  @override
  String get folderSubLess => 'Згорнути';

  @override
  String get itemPlaceAdd => 'Додати місце';

  @override
  String get itemPlaceAddShort => 'Місце';

  @override
  String get itemPlaceTitle => 'Місце нотатки';

  @override
  String get itemPlaceShowMap => 'Показати на мапі';

  @override
  String get itemPlacePickMap => 'Вибрати на мапі';

  @override
  String get itemPlaceRemove => 'Прибрати місце';

  @override
  String get itemPlaceRemoved => 'Місце прибрано';

  @override
  String get itemPlaceSetHere => 'Поставити сюди';

  @override
  String get itemPlaceMapHint => 'Рухай мапу, шпилька позначить місце';

  @override
  String get placesNoFixBrowser =>
      'Не вдалося дізнатися, де ти. Перевір, що браузер дозволяє Stowa місце.';

  @override
  String get rulesTab => 'Правила';

  @override
  String get tagsIntro =>
      'Мітка поверх папок: напиши #слово в рядку, і нотатки з ним знайдуться з будь-якої папки.';

  @override
  String get rulesIntro =>
      'Правило саме розбирає нові нотатки: бачить тег, сайт або слово й кладе нотатку в папку чи ставить тег.';

  @override
  String get rulesWhenWorks =>
      'Правила спрацьовують на нових нотатках і не чіпають те, що ти розклав сам.';

  @override
  String get rulesEmpty => 'Правил поки немає: почни з прикладу нижче.';

  @override
  String get rulesExamples => 'Приклади';

  @override
  String ruleWhenTag(String tag) {
    return 'Є тег #$tag';
  }

  @override
  String ruleWhenSite(String site) {
    return 'Посилання з сайту $site';
  }

  @override
  String ruleWhenWord(String word) {
    return 'У тексті є «$word»';
  }

  @override
  String ruleWhenKind(String kind) {
    return 'Вид нотатки: $kind';
  }

  @override
  String ruleWhenPage(String page) {
    return 'Сторінка: $page';
  }

  @override
  String ruleWhenPriceAbove(String value) {
    return 'Ціна більша за $value';
  }

  @override
  String ruleWhenPriceBelow(String value) {
    return 'Ціна менша за $value';
  }

  @override
  String ruleDoFolder(String folder) {
    return 'у папку «$folder»';
  }

  @override
  String ruleDoTag(String tag) {
    return 'поставити тег #$tag';
  }

  @override
  String ruleDoRemind(String when) {
    return 'нагадати $when';
  }

  @override
  String get ruleCondTag => 'Є тег';

  @override
  String get ruleCondTagHint => 'Ти поставив #тег, коли записував';

  @override
  String get ruleCondSite => 'Посилання з сайту';

  @override
  String get ruleCondSiteHint => 'Наприклад, ролики з youtube.com';

  @override
  String get ruleCondWord => 'Слово в тексті';

  @override
  String get ruleCondWordHint => 'Наприклад, «купити» або «рецепт»';

  @override
  String get ruleCondKind => 'Вид нотатки';

  @override
  String get ruleCondKindHint => 'Фото, відео, голосове, файл або посилання';

  @override
  String get ruleCondPage => 'Тип сторінки';

  @override
  String get ruleCondPageHint => 'Посилання на рецепт, товар, подію чи фільм';

  @override
  String get ruleCondPriceAbove => 'Ціна більша';

  @override
  String get ruleCondPriceAboveHint => 'У нотатці є сума, дорожча за неї';

  @override
  String get ruleCondPriceBelow => 'Ціна менша';

  @override
  String get ruleCondPriceBelowHint => 'У нотатці є сума, дешевша за неї';

  @override
  String get ruleActFolder => 'Покласти в папку';

  @override
  String get ruleActFolderHint => 'Нотатка одразу ляже в цю папку';

  @override
  String get ruleActTag => 'Поставити тег';

  @override
  String get ruleActTagHint => 'До нотатки додасться тег';

  @override
  String get ruleActRemind => 'Нагадати заздалегідь';

  @override
  String get ruleActRemindHint => 'Лише для подій: до початку';

  @override
  String get ruleStepWhen => 'Коли';

  @override
  String get ruleStepDo => 'Що зробити';

  @override
  String get ruleFolderPick => 'Вибрати папку';

  @override
  String get ruleSaveButton => 'Зберегти правило';

  @override
  String get ruleValueTagHint => 'наприклад, робота';

  @override
  String get ruleValueWordHint => 'наприклад, купити';

  @override
  String get ruleValueSiteHint => 'наприклад, youtube.com';

  @override
  String get ruleExampleVideoTag => 'відео';

  @override
  String get ruleExampleBuyWord => 'купити';

  @override
  String get ruleExampleShoppingTag => 'покупки';

  @override
  String get tagFolderRow => 'Класти в папку';

  @override
  String get tagFolderNone => 'Не класти';

  @override
  String get tagFolderHint =>
      'Це правило: його видно й можна вимкнути у вкладці «Правила».';

  @override
  String get tagPinHint => 'Тег стане в ряд угорі головної';

  @override
  String numberPadRange(String min, String max) {
    return 'Від $min до $max';
  }

  @override
  String get numberPadOpen => 'Вписати число';

  @override
  String tagShowNotes(String tag) {
    return 'Нотатки з #$tag';
  }

  @override
  String get panelHint => 'Записи й пошук ідуть через відкриту вкладку Stowa.';

  @override
  String get panelEmpty =>
      'Пиши думку або шукай нотатку: рядок робить і те, і інше.';

  @override
  String get panelLocked => 'Пошук закрито кодом на вхід, записувати можна.';

  @override
  String get panelOpened => 'Відкрив у вкладці Stowa';

  @override
  String get panelSaved => 'Щойно записано';

  @override
  String get panelWaiting => 'Чекаю вкладку Stowa…';

  @override
  String get accountSignIn => 'Увійти';

  @override
  String get accountSignInHint => 'Якщо вам видали підписку';

  @override
  String get accountTitle => 'Акаунт';

  @override
  String get signInTitle => 'Вхід';

  @override
  String get signInIntro =>
      'Надішлемо код на пошту. Пароль не потрібен, а акаунт з\'явиться сам під час першого входу.';

  @override
  String get accountDelete => 'Видалити акаунт';

  @override
  String accountDeleteAsk(String email) {
    return 'Видалити акаунт $email?';
  }

  @override
  String get accountDeleteHint =>
      'Нотатки на цьому пристрої залишаться. З сервера зітруться їхні копії та підписка.';

  @override
  String get accountDeleteStorePlay =>
      'Підписка Google Play сама не зупиниться: скасуйте її в Google Play.';

  @override
  String get accountDeleteStoreApple =>
      'Підписка App Store сама не зупиниться: скасуйте її в налаштуваннях Apple ID.';

  @override
  String get accountDeleteStoreAny =>
      'Підписка Google Play або App Store сама не зупиниться: скасуйте її в магазині.';

  @override
  String get accountDeleteLive =>
      'Спершу скасуйте продовження підписки, інакше оплата й далі списуватиметься.';

  @override
  String get accountDeleted => 'Акаунт видалено';

  @override
  String get subBuy => 'Купити підписку';

  @override
  String get subBuyHint => 'Синхронізація, хмара для файлів і бічна панель';

  @override
  String subActiveUntil(String date) {
    return 'Stowa Sync до $date';
  }

  @override
  String get paywallLead =>
      'Нотатки й файли на всіх ваших пристроях. На одному пристрої Stowa лишається безкоштовною.';

  @override
  String get featureSync => 'Синхронізація з наскрізним шифруванням';

  @override
  String get featureSyncHint =>
      'Телефон, сайт і комп\'ютер бачать одне й те саме. Усе шифрує ваш пристрій, а зі своїм паролем шифрування прочитати нотатки не зможе ніхто, крім вас.';

  @override
  String get featureFiles => 'Хмара для файлів';

  @override
  String get featureFilesHint =>
      'Фото, відео та PDF доїжджають до всіх пристроїв.';

  @override
  String get featurePanel => 'Бічна панель у браузері';

  @override
  String get featurePanelHint => 'Записати й знайти, не йдучи зі сторінки.';

  @override
  String get featureHistory => 'Історія версій';

  @override
  String get featureHistoryHint =>
      'Кожна правка нотатки зберігається на сервері: видно, що змінилося, і можна повернути будь-яку версію.';

  @override
  String get featureLinks => 'Дошка за посиланням';

  @override
  String get featureLinksHint =>
      'Покажіть дошку будь-кому. Ключ лежить у самому посиланні, сервер його не прочитає.';

  @override
  String get soon => 'Незабаром';

  @override
  String get planMonth => 'Місяць';

  @override
  String get planQuarter => '3 місяці';

  @override
  String get planYear => 'Рік';

  @override
  String planPerMonth(String price) {
    return '$price на місяць';
  }

  @override
  String planSave(int percent) {
    return 'Вигода $percent%';
  }

  @override
  String get paywallContinue => 'Продовжити';

  @override
  String get paywallWaiting => 'Чекаємо на оплату';

  @override
  String get paywallWaitingHint =>
      'Сторінка оплати відкрилася в браузері. Щойно оплата пройде, підписка ввімкнеться сама.';

  @override
  String get paywallOpenAgain => 'Відкрити оплату знову';

  @override
  String get paywallDone => 'Stowa Sync увімкнено';

  @override
  String paywallDoneUntil(String date) {
    return 'До $date. Синхронізація вже почалася.';
  }

  @override
  String get paywallDoneButton => 'Готово';

  @override
  String get paywallFailed => 'Оплата не пройшла. Спробуйте ще раз.';

  @override
  String get paywallUnavailable =>
      'Оплата зараз недоступна. Перевірте інтернет і спробуйте пізніше.';

  @override
  String get paywallOwned =>
      'Ця покупка прив\'язана до іншого акаунта Stowa. Увійдіть у нього, щоб користуватися підпискою.';

  @override
  String get paywallRestore => 'Відновити покупку';

  @override
  String get paywallRestoreNothing => 'Покупок для відновлення немає';

  @override
  String get paywallTerms => 'Умови';

  @override
  String get paywallPrivacy => 'Конфіденційність';

  @override
  String get paywallRenewDirect =>
      'Підписка продовжується сама наприкінці строку. Скасувати продовження можна будь-коли в налаштуваннях Stowa, доступ залишиться до кінця оплаченого строку.';

  @override
  String get paywallRenewPlay =>
      'Підписка продовжується сама наприкінці строку, оплата йде через Google Play. Скасувати можна будь-коли в Google Play, у розділі «Платежі й підписки».';

  @override
  String get paywallRenewApple =>
      'Оплата спишеться з Apple ID під час підтвердження покупки. Підписка продовжується сама, якщо не вимкнути продовження щонайменше за 24 години до кінця строку. Керувати підпискою можна в налаштуваннях Apple ID.';

  @override
  String get subTitle => 'Підписка';

  @override
  String get subPlan => 'Тариф';

  @override
  String get subUntil => 'Діє до';

  @override
  String subRenewOn(String date) {
    return 'Продовжиться $date';
  }

  @override
  String subRenewOff(String date) {
    return 'Продовження скасовано, доступ до $date';
  }

  @override
  String get subSourceGrant => 'Видана командою Stowa';

  @override
  String get subSourceCard => 'Оплачена карткою';

  @override
  String get subSourcePlay => 'Google Play';

  @override
  String get subSourceApple => 'App Store';

  @override
  String get subTest => 'Тестова покупка';

  @override
  String get subCancel => 'Скасувати продовження';

  @override
  String subCancelAsk(String date) {
    return 'Скасувати продовження? Stowa Sync працюватиме до $date.';
  }

  @override
  String get subKeep => 'Залишити';

  @override
  String get subCancelled => 'Продовження скасовано';

  @override
  String get subManagePlay => 'Керувати в Google Play';

  @override
  String get subManageApple => 'Керувати в App Store';

  @override
  String get syncOffer => 'Синхронізація входить у Stowa Sync';

  @override
  String get syncOfferHint =>
      'Оформіть підписку, і нотатки зійдуться на всіх пристроях.';

  @override
  String get syncHaveSub => 'Уже маєте підписку? Увійдіть';

  @override
  String get panelSubLocked => 'Бічна панель входить у Stowa Sync';

  @override
  String get panelSubLockedHint => 'Оформіть підписку, і панель відкриється.';

  @override
  String get panelSubOpen => 'Оформити Stowa Sync';

  @override
  String get syncPasswordAsk =>
      'Нотатки закриті вашим паролем шифрування. Введіть його, щоб відкрити їх на цьому пристрої.';

  @override
  String get syncPassword => 'Пароль шифрування';

  @override
  String get syncUnlock => 'Відкрити';

  @override
  String get syncPasswordWrong => 'Пароль не підходить';

  @override
  String get syncOwnPassword => 'Свій пароль шифрування';

  @override
  String get syncOwnPasswordOn => 'Увімкнено: прочитати нотатки можете лише ви';

  @override
  String get syncOwnPasswordOff => 'Вимкнено: для нового пристрою досить входу';

  @override
  String get syncOwnPasswordIntro =>
      'Ключ до нотаток закриється вашим паролем, а наша копія ключа зітреться. Прочитати нотатки не зможе ніхто, крім вас, навіть ми.';

  @override
  String get syncOwnPasswordWarn =>
      'Забудете пароль — копію на сервері не відкрити ніяк. Нотатки на ваших пристроях залишаться.';

  @override
  String get syncPasswordRepeat => 'Пароль ще раз';

  @override
  String get syncPasswordShort => 'Не коротше 8 знаків';

  @override
  String get syncPasswordMismatch => 'Паролі не збігаються';

  @override
  String get syncPasswordTurnOn => 'Увімкнути';

  @override
  String get syncPasswordChange => 'Змінити пароль';

  @override
  String get syncPasswordTurnOff => 'Вимкнути свій пароль';

  @override
  String get syncPasswordOffAsk =>
      'Вимкнути свій пароль? Копія ключа знову зберігатиметься в нас, і для нового пристрою вистачить входу.';

  @override
  String get syncPasswordDone => 'Свій пароль увімкнено';

  @override
  String get syncPasswordOffDone => 'Свій пароль вимкнено';

  @override
  String get photoDownload => 'Завантажити';

  @override
  String get photoSaveAs => 'Зберегти як…';

  @override
  String get photoPrevious => 'Попереднє фото';

  @override
  String get photoNext => 'Наступне фото';

  @override
  String get photoFileFailed => 'Не вдалося зберегти фото';

  @override
  String get canvasSnap => 'Прив\'язка до сітки';

  @override
  String get canvasSnapAlt => 'Прив\'язка до сітки. З Alt — вільно';
}
