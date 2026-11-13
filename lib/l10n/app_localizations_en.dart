// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

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
  String get savePhotosHint => 'you can add a caption and tags later';

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
  String get reasonNone =>
      'no folder yet, I\'ll sort it once similar notes appear';

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
  String get voiceSaved => 'Voice note saved';

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
  String get voiceNoTranscript => 'No transcript';

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
  String get itemMore => 'More';

  @override
  String get itemAppend => 'Add more';

  @override
  String get itemShare => 'Share';

  @override
  String get itemAutosave => 'Saves as you type';

  @override
  String itemPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '$count photo',
    );
    return '$_temp0';
  }

  @override
  String get tagAddShort => 'Tag';

  @override
  String get itemOpenLink => 'Open';

  @override
  String get itemWatch => 'Watch';

  @override
  String get fileOpenFailed => 'No app can open this file';

  @override
  String get linkOpenFailed => 'Couldn\'t open the link';

  @override
  String photoCounter(Object count, Object index) {
    return '$index of $count';
  }

  @override
  String get photoToGallery => 'To gallery';

  @override
  String get photoSaved => 'Saved to gallery';

  @override
  String get photoSaveFailed => 'Couldn\'t save: no access to the gallery';

  @override
  String get photoClose => 'Close';

  @override
  String get voiceSpeed => 'Speed';

  @override
  String autoSorted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count similar notes sorted',
      one: '$count similar note sorted',
    );
    return '$_temp0';
  }

  @override
  String get relatedTitle => 'Related';

  @override
  String relatedWords(Object words) {
    return 'in common: $words';
  }

  @override
  String relatedSite(Object site) {
    return 'same site, $site';
  }

  @override
  String get relatedHide => 'Not related';

  @override
  String get relatedHidden => 'Won\'t show them together again';

  @override
  String aiSortedInto(String folder) {
    return 'Put in “$folder”';
  }

  @override
  String get aiOtherFolder => 'Other';

  @override
  String get aiPausedAuth => 'Sorting paused: key rejected';

  @override
  String get aiPausedPayment => 'Sorting paused: the key is out of credit';

  @override
  String get aiPausedAction => 'Check key';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAi => 'AI sorting';

  @override
  String get aiStateOff => 'Off';

  @override
  String get aiStateOffHint =>
      'Add your own key and notes without a folder sort themselves.';

  @override
  String get aiStateOn => 'On';

  @override
  String aiStateWait(String time) {
    return 'The provider asks to wait until $time';
  }

  @override
  String aiQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes waiting',
      one: '$count note waiting',
    );
    return '$_temp0';
  }

  @override
  String get aiSortNow => 'Sort now';

  @override
  String get aiKey => 'Key';

  @override
  String get aiKeyNone => 'Not set';

  @override
  String get aiKeySet => 'Set';

  @override
  String get aiKeyPaste => 'Paste';

  @override
  String get aiKeySave => 'Save and check';

  @override
  String get aiKeyRemove => 'Remove key';

  @override
  String get aiKeyWhere =>
      'Get a key from your provider: on OpenRouter it is under Keys, and free models are available.';

  @override
  String get aiCheckOk => 'The key works';

  @override
  String get aiCheckAuth => 'The provider rejected the key';

  @override
  String get aiCheckPayment => 'The key has no credit';

  @override
  String get aiCheckRate => 'The provider asks to wait';

  @override
  String get aiCheckNetwork => 'Can’t reach the provider';

  @override
  String get aiCheckServer => 'The provider returned an error';

  @override
  String get aiProvider => 'Provider';

  @override
  String get aiProviderHint =>
      'An OpenAI-compatible API address, empty means OpenRouter.';

  @override
  String get aiSortModel => 'Sorting model';

  @override
  String get aiSpeechModel => 'Voice transcription';

  @override
  String get aiSpeechOff => 'Off';

  @override
  String get aiModelsSearch => 'Find a model';

  @override
  String get aiModelFree => 'free';

  @override
  String get aiModelVision => 'sees photos';

  @override
  String get aiModelsNeedKey => 'The model list opens once a key is set';

  @override
  String get aiModelsFailed => 'The model list didn’t load';

  @override
  String aiModelOwn(String name) {
    return 'Custom: “$name”';
  }

  @override
  String get settingsOrder => 'Organizing';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String settingsVersion(String version) {
    return 'Stowa $version';
  }

  @override
  String get trashTitle => 'Trash';

  @override
  String get trashEmpty => 'Trash is empty';

  @override
  String get trashHint =>
      'Deleted notes stay here for 30 days, then they are erased with their files.';

  @override
  String trashDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '$count day left',
    );
    return '$_temp0';
  }

  @override
  String trashFrom(String folder) {
    return 'from “$folder”';
  }

  @override
  String get trashPurge => 'Erase forever';

  @override
  String get trashPurgeAll => 'Empty trash';

  @override
  String trashPurgeAllAsk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes will be erased forever. This can’t be undone.',
      one: '$count note will be erased forever. This can’t be undone.',
    );
    return '$_temp0';
  }

  @override
  String trashRestored(String title) {
    return 'Restored “$title”';
  }

  @override
  String get trashPurged => 'Erased forever';

  @override
  String get settingsData => 'Data';

  @override
  String get backupSave => 'Save a backup';

  @override
  String get backupSaveHint =>
      'All your notes, folders and files in one file, without the AI key.';

  @override
  String get backupRestore => 'Restore from backup';

  @override
  String backupRestoreAsk(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count notes from the $date backup will replace everything you have now.',
      one:
          '$count note from the $date backup will replace everything you have now.',
    );
    return '$_temp0';
  }

  @override
  String get backupReplace => 'Replace';

  @override
  String get backupRestored => 'Restored from backup';

  @override
  String get backupNotStowa => 'This is not a Stowa backup';

  @override
  String get backupTooNew =>
      'A newer Stowa made this backup. Update the app first';

  @override
  String get backupFailed => 'The backup failed';

  @override
  String get folderNewBadge => 'new';

  @override
  String get aiSortingNow => 'Sorting…';

  @override
  String get aiLog => 'Request log';

  @override
  String get aiLogEmpty => 'No requests to the provider yet';

  @override
  String get aiLogCluster => 'New folders from “No folder”';

  @override
  String get aiCheckTimeout => 'The model didn’t answer in time';

  @override
  String get tgTitle => 'Your Telegram bot';

  @override
  String get tgNone => 'Not connected';

  @override
  String get tgHowTo =>
      '1. Open @BotFather in Telegram and send /⁠newbot.\n2. Name your bot and BotFather will send a token.\n3. Paste the token here.\n4. Write anything to your bot: from then on it listens only to you, and whatever you forward to it lands in Stowa.';

  @override
  String get tgConnect => 'Connect';

  @override
  String tgOwner(String name) {
    return 'Listens only to $name';
  }

  @override
  String get tgWaitingOwner => 'Write anything to the bot so it remembers you';

  @override
  String get tgOpenBot => 'Open the bot';

  @override
  String get tgDisconnect => 'Disconnect the bot';

  @override
  String get tgBadToken => 'Telegram rejected the token';

  @override
  String get tgOffline => 'Can’t reach Telegram';

  @override
  String tgPulled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages picked up',
      one: '$count message picked up',
    );
    return '$_temp0';
  }

  @override
  String get settingsOutside => 'From outside';

  @override
  String selCount(int count) {
    return 'Selected: $count';
  }

  @override
  String get selClear => 'Clear selection';

  @override
  String get selAll => 'Select all';

  @override
  String get selMove => 'Move';

  @override
  String get selTag => 'Tag';

  @override
  String get selUntag => 'Untag';

  @override
  String get selDelete => 'Delete';

  @override
  String selMoved(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes moved to “$folder”',
      one: '$count note moved to “$folder”',
    );
    return '$_temp0';
  }

  @override
  String selDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes deleted',
      one: '$count note deleted',
    );
    return '$_temp0';
  }

  @override
  String selTagged(String tag) {
    return 'Tagged #$tag';
  }

  @override
  String selUntagged(String tag) {
    return 'Removed #$tag';
  }

  @override
  String get tagPickTitle => 'Which tag';

  @override
  String get folderCanvas => 'Canvas';

  @override
  String get canvasFit => 'Fit everything';

  @override
  String get canvasNote => 'Note';

  @override
  String get canvasNoteHint => 'What to write on the canvas';

  @override
  String get graphTitle => 'Link graph';

  @override
  String get graphEmpty =>
      'No links yet. They appear when notes start sharing words or the AI links them.';

  @override
  String get graphFailed => 'The graph didn’t build';

  @override
  String copyPartlyFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files weren’t saved: the app didn’t give access',
      one: '$count file wasn’t saved: the app didn’t give access',
    );
    return '$_temp0';
  }

  @override
  String get mapTitle => 'Map';

  @override
  String get mapEmpty =>
      'Nothing has a place yet. New notes remember where you saved them and show up here.';

  @override
  String get mapWhereAmI => 'Where am I';

  @override
  String get mapPlaceUnnamed => 'Unnamed place';

  @override
  String get placeSetting => 'Remember where it was saved';

  @override
  String get placeSettingHint =>
      'The place shows on the note and the map, and only a street-name lookup leaves the phone.';

  @override
  String panelLooking(Object what) {
    return 'Looking for: $what';
  }

  @override
  String get foundAtPlace => 'by place';

  @override
  String fileSaving(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files are being saved',
      one: '$count file is being saved',
    );
    return '$_temp0';
  }

  @override
  String get fileSavingHint =>
      'You can close the app, and delete the original once the bar is gone.';

  @override
  String get foundInFile => 'in the file';

  @override
  String get foundOnPage => 'on the page';

  @override
  String get foundInPhotoInfo => 'in photo details';

  @override
  String documentSheet(Object name) {
    return 'sheet “$name”';
  }

  @override
  String documentSlide(Object number) {
    return 'slide $number';
  }

  @override
  String documentChapter(Object number) {
    return 'chapter $number';
  }

  @override
  String get factCall => 'Call';

  @override
  String get factWrite => 'Write';

  @override
  String get factCopy => 'Copy';

  @override
  String photoTaken(Object date) {
    return 'Taken $date';
  }

  @override
  String foundInSubtitles(Object time) {
    return 'in subtitles · $time';
  }

  @override
  String foundInChapters(Object time) {
    return 'in chapters · $time';
  }

  @override
  String get foundInIngredients => 'in ingredients';

  @override
  String get foundAtAddress => 'by address';

  @override
  String get foundInHashtags => 'in hashtags';

  @override
  String get watchFromHere => 'Watch from here';

  @override
  String get pageRecipe => 'recipe';

  @override
  String get pageProduct => 'product';

  @override
  String get pageEvent => 'event';

  @override
  String get pagePlace => 'place';

  @override
  String get pageMovie => 'movie';

  @override
  String get pageBook => 'book';

  @override
  String get pageVideo => 'video';

  @override
  String get pageArticle => 'article';

  @override
  String minutesShort(Object count) {
    return '$count min';
  }

  @override
  String servings(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servings',
      one: '$count serving',
    );
    return '$_temp0';
  }

  @override
  String readingMinutes(Object count) {
    return '$count min read';
  }

  @override
  String get inStock => 'In stock';

  @override
  String get outOfStock => 'Out of stock';

  @override
  String get toShoppingList => 'To shopping list';

  @override
  String shoppingFor(Object name) {
    return 'Buy: $name';
  }

  @override
  String get shoppingReady => 'Shopping list is ready';

  @override
  String get chaptersTitle => 'Chapters';

  @override
  String get authorTags => 'Author’s tags';

  @override
  String get pageSeries => 'series';

  @override
  String get pageComic => 'comic';

  @override
  String get adultSetting => 'Show 18+';

  @override
  String get adultSettingHint =>
      'While this is off, covers and descriptions of 18+ pages stay hidden.';

  @override
  String get adultHidden =>
      'Description hidden: 18+. You can turn it on in settings.';

  @override
  String get vaultSetupTitle => 'Where to keep your notes';

  @override
  String get vaultSetupHint =>
      'Notes, photos and files live as plain files in a folder that Obsidian can open too.';

  @override
  String get vaultCreate => 'Create a vault';

  @override
  String get vaultCreateHint =>
      'A new folder in phone storage: your notes stay even if you uninstall the app.';

  @override
  String get vaultCreateButton => 'Create';

  @override
  String get vaultOpen => 'Open folder as vault';

  @override
  String get vaultOpenHint =>
      'Your old Stowa vault after a reinstall, or an Obsidian vault.';

  @override
  String get vaultOpenButton => 'Open';

  @override
  String get vaultInApp => 'Keep inside the app';

  @override
  String get vaultInAppHint =>
      'No permissions, but uninstalling the app deletes your notes.';

  @override
  String get vaultInAppButton => 'Choose';

  @override
  String get vaultInAppWarning =>
      'Your notes will live inside the app and disappear if you uninstall it. You can move them to a regular folder later in settings.';

  @override
  String get vaultInAppConfirm => 'Keep inside';

  @override
  String get vaultName => 'Vault name';

  @override
  String get vaultPlace => 'Location';

  @override
  String get vaultAccessTitle => 'File access needed';

  @override
  String get vaultAccessHint =>
      'To keep notes in a regular folder Android asks for “All files access”, but Stowa only touches its own folder.';

  @override
  String get vaultAccessGrant => 'Open settings';

  @override
  String get vaultAccessDenied =>
      'Without file access a vault in phone storage can’t work';

  @override
  String vaultMoving(int done, int total) {
    return 'Moving: $done of $total';
  }

  @override
  String vaultBuilding(int done, int total) {
    return 'Building the index: $done of $total';
  }

  @override
  String vaultMoveFailed(int count) {
    return 'Not everything moved, missing: $count. Your notes stayed where they were.';
  }

  @override
  String get vaultMissingTitle => 'Vault not found';

  @override
  String vaultMissingHint(String path) {
    return 'The folder $path is gone or Stowa lost file access. The notes in the app are safe.';
  }

  @override
  String get vaultGrantAccess => 'Grant access';

  @override
  String get vaultChooseAgain => 'Choose a folder';

  @override
  String get vaultSection => 'Vault';

  @override
  String get vaultFolder => 'Folder';

  @override
  String get vaultInsideApp => 'Inside the app';

  @override
  String get vaultMoveTo => 'Move to another folder';

  @override
  String get vaultRebuild => 'Rebuild the index';

  @override
  String get vaultSettingHint =>
      'Notes are plain .md files that Obsidian can open too.';

  @override
  String get vaultMoved => 'Vault moved';

  @override
  String get vaultRebuilt => 'Index rebuilt';

  @override
  String vaultSyncing(int done, int total) {
    return 'Syncing notes $done of $total';
  }

  @override
  String repeatIn(String folder, String date) {
    return 'Same one is in the “$folder” folder since $date';
  }

  @override
  String repeatNoFolder(String date) {
    return 'Same one is unfiled since $date';
  }

  @override
  String get settingsImport => 'Import';

  @override
  String get importTelegram => 'From Telegram';

  @override
  String get importTelegramHint =>
      'Pick the Saved Messages export folder from Telegram Desktop.';

  @override
  String importProgress(int done, int total) {
    return 'Importing $done of $total';
  }

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes imported',
      one: '$count note imported',
    );
    return '$_temp0';
  }

  @override
  String importRepeated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count were already here',
      one: '$count was already here',
    );
    return '$_temp0';
  }

  @override
  String get importNotTelegram =>
      'No Telegram export in this folder: messages.html or result.json is needed';

  @override
  String importMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files were left out of the export',
      one: '$count file was left out of the export',
    );
    return '$_temp0 — turn files on in the export settings and import again';
  }

  @override
  String importFilled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count earlier notes got their files',
      one: '$count earlier note got its files',
    );
    return '$_temp0';
  }

  @override
  String get returnChannel => 'Coming back';

  @override
  String get returnWatchTitle => 'Watch later';

  @override
  String returnVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '$count video',
    );
    return '$_temp0';
  }

  @override
  String returnArticles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '$count article',
    );
    return '$_temp0';
  }

  @override
  String returnMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '$count minute',
    );
    return '$_temp0';
  }

  @override
  String returnAnd(String first, String second) {
    return '$first and $second';
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
      other: '$count years ago',
      one: 'A year ago',
    );
    return '$_temp0';
  }

  @override
  String get returnMonthAgo => 'A month ago';

  @override
  String get returnWeekAgo => 'A week ago';

  @override
  String returnDayOne(String title) {
    return '“$title”';
  }

  @override
  String returnDayMore(String title, int count) {
    return '“$title” and $count more';
  }

  @override
  String get returnOnThisDay => 'On this day';

  @override
  String get returnWeekTitle => 'Your week in Stowa';

  @override
  String returnWeekSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes this week',
      one: '$count note this week',
    );
    return '$_temp0';
  }

  @override
  String returnWeekUnopened(int count) {
    return '$count unopened';
  }

  @override
  String returnWeekUnsorted(int count) {
    return '$count without a folder';
  }

  @override
  String get returnWeekUnopenedTitle => 'Not opened yet';

  @override
  String get returnWeekUnsortedTitle => 'Without a folder';

  @override
  String returnShopTitle(String shop) {
    return 'At $shop';
  }

  @override
  String returnShopMore(String items, int count) {
    return '$items and $count more';
  }

  @override
  String get returnShopping => 'To buy';

  @override
  String get settingsReturns => 'Bring back';

  @override
  String get returnWeekSetting => 'Weekly summary';

  @override
  String get returnShoppingSetting => 'Shopping near a store';

  @override
  String get returnEveningRow => 'In the evening at';

  @override
  String get returnQuietRow => 'Quiet hours';

  @override
  String get returnWeekDayRow => 'Summary day';

  @override
  String get returnSettingsHint => 'At most one silent notification a day.';

  @override
  String returnRange(String from, String to) {
    return '$from–$to';
  }

  @override
  String get returnQuietFrom => 'Quiet from';

  @override
  String get returnQuietTo => 'Quiet until';

  @override
  String get returnWatchEmpty =>
      'The queue is empty: you’ve seen everything recent.';

  @override
  String get returnDayEmpty => 'Nothing was saved on this day before.';

  @override
  String get returnWeekEmpty => 'Nothing saved this week.';

  @override
  String get returnShoppingEmpty =>
      'Nothing to buy: every list is checked off.';

  @override
  String returnMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get returnsAskTitle => 'Bring saved notes back?';

  @override
  String get returnsAskBody =>
      'One silent notification in the evening reminds you of what you saved.';

  @override
  String get returnsAskOn => 'Turn on';

  @override
  String get returnsAskLater => 'Not now';

  @override
  String get placeRemindHome => 'Remind at home';

  @override
  String get placeRemindWork => 'Remind at work';

  @override
  String get placeRemindHere => 'Remind me here';

  @override
  String get placeRemindShop => 'Remind at a store';

  @override
  String placeRemindAt(String place) {
    return 'Remind at $place';
  }

  @override
  String get composerRemovePlace => 'No place reminder';

  @override
  String get placesTitle => 'Places';

  @override
  String get placesHome => 'Home';

  @override
  String get placesWork => 'Work';

  @override
  String get placesShops => 'Stores';

  @override
  String get placesNotSet => 'Not set';

  @override
  String placesWifi(String name) {
    return 'Wi-Fi: $name';
  }

  @override
  String get placesImHome => 'I’m home now';

  @override
  String get placesImWork => 'I’m at work now';

  @override
  String get placesImShop => 'I’m at a store — save it';

  @override
  String placesGuessHome(String name) {
    return 'Looks like home is $name';
  }

  @override
  String placesGuessWork(String name) {
    return 'Looks like work is $name';
  }

  @override
  String get placesRemove => 'Remove';

  @override
  String get placesShopName => 'Store name';

  @override
  String get placesSave => 'Save';

  @override
  String get placesNoFix =>
      'Couldn’t find where you are. Check that location is on and allowed for Stowa.';

  @override
  String get placesPermissionTitle => 'Location “all the time” is needed';

  @override
  String get placesPermissionBody =>
      'Reminders at a place only work if location is allowed “all the time”.';

  @override
  String get placesPermissionAllow => 'Allow';

  @override
  String get placesHint =>
      'Places are for reminders like “remind me at home” or “at a store”.';

  @override
  String placesShopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stores',
      one: '$count store',
    );
    return '$_temp0';
  }

  @override
  String get itemRemindTime => 'At a time';

  @override
  String get itemPlaceChange => 'Another place';

  @override
  String get placesMissingHome =>
      'Home isn’t set yet: Stowa will remind you once you set it in Places';

  @override
  String get placesMissingWork =>
      'Work isn’t set yet: Stowa will remind you once you set it in Places';

  @override
  String get placesMissingShop => 'No stores yet: save at least one in Places';

  @override
  String get placeChannel => 'Place reminders';

  @override
  String get remindPlaceNeedsAlways =>
      'I\'ll remind you there if location is allowed all the time';

  @override
  String get lookColor => 'Color';

  @override
  String homeFoldersMore(Object count) {
    return '$count more';
  }

  @override
  String homeChecksMore(Object count) {
    return '$count more';
  }

  @override
  String get catalogTitle => 'Catalog';

  @override
  String get catalogExpand => 'Expand all';

  @override
  String get catalogCollapse => 'Collapse all';

  @override
  String get catalogOpenFolder => 'Open folder';

  @override
  String foldersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count folders',
      one: '$count folder',
    );
    return '$_temp0';
  }

  @override
  String readerOpen(Object count) {
    return 'Read · $count min';
  }

  @override
  String get readerOriginal => 'Original';

  @override
  String get readerQuote => 'Quote';

  @override
  String get readerCopy => 'Copy';

  @override
  String get readerNote => 'Note';

  @override
  String get readerNoteHint => 'Note for this quote';

  @override
  String get readerRemove => 'Remove';

  @override
  String get readerRemoved => 'Quote removed';

  @override
  String get readerGone => 'Original removed · copy saved';

  @override
  String get readerNoCopy =>
      'The article text wasn\'t saved. You can open it on the site.';

  @override
  String get readerImageOff => 'Image not saved';

  @override
  String get highlightsTitle => 'Quotes';

  @override
  String get linkGone => 'Link no longer opens';

  @override
  String get deadLinksTitle => 'Broken links';

  @override
  String get deadLinksAbout =>
      'Once a week Stowa checks your links and lists pages the site removed here.';

  @override
  String get deadLinksEmpty => 'All links open';

  @override
  String get deadLinksCheck => 'Check now';

  @override
  String get deadLinksChecking => 'Checking links…';

  @override
  String get deadLinksKeep => 'Keep';

  @override
  String get deadLinksDelete => 'Delete';

  @override
  String get deadLinksDeleted => 'Note moved to trash';

  @override
  String deadLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count don\'t open',
      one: '$count doesn\'t open',
    );
    return '$_temp0';
  }

  @override
  String get settingsArticles => 'Articles';

  @override
  String get articleImages => 'Article images';

  @override
  String get articleImagesAbout =>
      'Download on Wi-Fi to read articles with images offline';

  @override
  String get foundInArticle => 'in the article';

  @override
  String get foundInQuote => 'in a quote';

  @override
  String get settingsStart => 'On launch';

  @override
  String get startOpen => 'Open';

  @override
  String get startHome => 'Home';

  @override
  String get startLast => 'Last note';

  @override
  String get startRandom => 'Random note';

  @override
  String get startHint =>
      'The last note picks up where you left off, a random one brings back something you saved.';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceTheme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'Same as system';

  @override
  String get themeByTime => 'By time of day';

  @override
  String get themeByTimeHint => 'Dark from 20:00 to 7:00';

  @override
  String get appearanceColor => 'Color';

  @override
  String get colorGraphite => 'Graphite';

  @override
  String get colorCustom => 'Custom color';

  @override
  String get colorFromWallpaper => 'From wallpaper';

  @override
  String get colorIntensity => 'Intensity';

  @override
  String get intensityVibrant => 'Vivid';

  @override
  String get intensityFaithful => 'Exact';

  @override
  String get intensityHint =>
      'Vivid tints the background too, Exact keeps it gray.';

  @override
  String get wallpaperColors => 'Wallpaper colors';

  @override
  String get wallpaperColorsHint => 'The theme follows your phone wallpaper';

  @override
  String get amoledTitle => 'Black background';

  @override
  String get amoledHint => 'Pure black for AMOLED screens, saves battery';

  @override
  String get pickerApply => 'Done';

  @override
  String get colorCoral => 'Coral';

  @override
  String get colorAmber => 'Amber';

  @override
  String get colorLime => 'Lime';

  @override
  String get colorMint => 'Mint';

  @override
  String get colorTeal => 'Teal';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorViolet => 'Violet';

  @override
  String get colorRose => 'Rose';

  @override
  String get folderNewInside => 'New folder inside';

  @override
  String get folderMoveTo => 'Move to…';

  @override
  String get folderMoveTop => 'To the top';

  @override
  String get folderMoveNone =>
      'Nowhere to move: folders nest up to three levels';

  @override
  String get historyTitle => 'History';

  @override
  String get historyNow => 'Now';

  @override
  String get historyHint =>
      'The earlier text is kept when you edit a note after a break.';

  @override
  String get historyNoChanges => 'Same text';

  @override
  String get historyText => 'Text';

  @override
  String get historyDiff => 'Changes';

  @override
  String get historyDiffHint =>
      'Struck out: was in this version. Highlighted: added since';

  @override
  String get historyRestore => 'Restore this version';

  @override
  String get historyRestored => 'Version restored';

  @override
  String get sortByColor => 'By color';

  @override
  String qrWifi(String network) {
    return 'Wi-Fi “$network”';
  }

  @override
  String get qrCopyPassword => 'Copy Wi-Fi password';

  @override
  String get qrPasswordCopied => 'Password copied';

  @override
  String get qrOpenLink => 'Open the link from the QR code';

  @override
  String get qrCopyText => 'Copy the QR code text';

  @override
  String get foundInQr => 'in a QR code';

  @override
  String documentPage(String number) {
    return 'page $number';
  }

  @override
  String get titleDateSetting => 'Photo and video names';

  @override
  String get titleDateShot => 'By date taken';

  @override
  String get titleDateSaved => 'By date saved';

  @override
  String get titleDateHint =>
      'Photos and videos without a caption get a date in their name.';

  @override
  String get factPassword => 'Password ••••••';

  @override
  String factPasswordFor(String network) {
    return 'Wi-Fi “$network” ••••••';
  }

  @override
  String get factCopyPassword => 'Copy password';

  @override
  String factCard(String last) {
    return 'Card ••$last';
  }

  @override
  String get factCopyCard => 'Copy card number';

  @override
  String factPromo(String code) {
    return 'Promo code $code';
  }

  @override
  String get factCopyPromo => 'Copy promo code';

  @override
  String get factTrack => 'Track parcel';

  @override
  String get factOnMap => 'Open in maps';

  @override
  String get workEndRow => 'Work ends at';

  @override
  String get toChecklist => 'Make a shopping list';

  @override
  String get toChecklistHint => 'Turn items into checkboxes';

  @override
  String get toChecklistDone => 'Shopping list ready';

  @override
  String folderTotal(String sum) {
    return 'Total $sum';
  }

  @override
  String get smartSave => 'Smart folder';

  @override
  String smartSaved(String name) {
    return 'Smart folder “$name” is on the home screen';
  }

  @override
  String get smartEmpty => 'Nothing matches this search yet';

  @override
  String get smartDelete => 'Delete smart folder';

  @override
  String smartDeleted(String name) {
    return 'Smart folder “$name” deleted, notes are untouched';
  }

  @override
  String suggestSite(int count, String site) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links',
      one: '$count link',
    );
    return '$_temp0 from $site without a folder';
  }

  @override
  String suggestScreenshots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count screenshots',
      one: '$count screenshot',
    );
    return '$_temp0 without a folder';
  }

  @override
  String suggestVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '$count video',
    );
    return '$_temp0 without a folder';
  }

  @override
  String suggestFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '$count file',
    );
    return '$_temp0 without a folder';
  }

  @override
  String suggestVoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voice notes',
      one: '$count voice note',
    );
    return '$_temp0 without a folder';
  }

  @override
  String suggestSiteBody(String name) {
    return 'Make a folder “$name”? New links from this site will go there on their own.';
  }

  @override
  String suggestBody(String name) {
    return 'Make a folder “$name” and move them there?';
  }

  @override
  String get suggestYes => 'Make it';

  @override
  String get suggestNo => 'No thanks';

  @override
  String suggestDone(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '$count note',
    );
    return 'Folder “$name”: $_temp0';
  }

  @override
  String get suggestScreenshotsName => 'Screenshots';

  @override
  String get suggestVideosName => 'Videos';

  @override
  String get suggestFilesName => 'Files';

  @override
  String get suggestVoicesName => 'Voice notes';

  @override
  String get ruleIfPage => 'page is a';

  @override
  String get ruleIfPriceAbove => 'price over';

  @override
  String get ruleIfPriceBelow => 'price under';

  @override
  String get ruleValuePrice => 'Amount, e.g. 1000';

  @override
  String rulePriceAboveValue(String value) {
    return 'over $value';
  }

  @override
  String rulePriceBelowValue(String value) {
    return 'under $value';
  }

  @override
  String get ruleThenRemind => 'remind';

  @override
  String get remindHourBefore => 'an hour before';

  @override
  String get remindDayBefore => 'a day before';

  @override
  String get remindWeekBefore => 'a week before';

  @override
  String codeWait(Object seconds) {
    return 'Wait $seconds s';
  }

  @override
  String get codeFingerprint => 'Fingerprint';

  @override
  String get codeErase => 'Erase';

  @override
  String get codeDone => 'Done';

  @override
  String get codeWrong => 'Wrong code';

  @override
  String get codeCreateTitle => 'Create a code';

  @override
  String get codeRepeatTitle => 'Repeat the code';

  @override
  String get codeCreateHint =>
      '6 to 12 digits: if you forget the code, hidden notes are gone for good.';

  @override
  String get codeMismatch => 'Codes don\'t match. Create it again';

  @override
  String get hiddenOpenReason => 'Open hidden folders';

  @override
  String get hiddenOpenTitle => 'Code for hidden folders';

  @override
  String get codeForgot => 'Forgot the code';

  @override
  String get codeOldTitle => 'Current code';

  @override
  String get codeNewTitle => 'New code';

  @override
  String get codeChanged => 'Code changed';

  @override
  String get codeForgetTitle => 'Remove the code?';

  @override
  String get codeForgetText =>
      'The lock turns off and hidden folders are erased together with their notes. They can\'t be brought back.';

  @override
  String get codeForgetAction => 'Remove code and erase hidden';

  @override
  String folderHidden(Object name) {
    return 'Folder “$name” is hidden';
  }

  @override
  String folderUnhidden(Object name) {
    return 'Folder “$name” is visible again';
  }

  @override
  String get lockReason => 'Unlock Stowa';

  @override
  String get lockTitle => 'Enter the code';

  @override
  String get codeEnterTitle => 'Enter the code';

  @override
  String get closeAfterNow => 'Right away';

  @override
  String get closeAfterMinute => 'After 1 minute';

  @override
  String closeAfterMinutes(Object minutes) {
    return 'After $minutes minutes';
  }

  @override
  String get privacySection => 'Privacy';

  @override
  String get codeCreateRow => 'Create a code';

  @override
  String get appLockRow => 'Code on launch';

  @override
  String get fingerprintRow => 'Fingerprint';

  @override
  String get closeAfterRow => 'Lock again';

  @override
  String get hiddenCloseRow => 'Close hidden folders';

  @override
  String get hiddenOpenRow => 'Open hidden folders';

  @override
  String get codeChangeRow => 'Change code';

  @override
  String get privacyHint =>
      'Hidden folders are encrypted and can\'t be read without the code.';

  @override
  String get markdownExport => 'Export to Markdown';

  @override
  String get markdownNoVault => 'Choose a vault folder first';

  @override
  String get markdownHiddenAsk => 'Export hidden folders too?';

  @override
  String get markdownHiddenHint =>
      'Hidden notes will become plain files. Anyone with this folder can read them.';

  @override
  String get markdownWithoutHidden => 'Without hidden';

  @override
  String get markdownWithHidden => 'With hidden';

  @override
  String markdownDone(Object path) {
    return 'Exported to $path';
  }

  @override
  String get markdownFailed => 'Couldn\'t write to this folder';

  @override
  String get folderUnhide => 'Unhide';

  @override
  String get folderHide => 'Hide folder';

  @override
  String get folderHiddenMark => 'hidden';

  @override
  String get hiddenFolders => 'Hidden folders';

  @override
  String get hiddenReminder => 'Reminder from a hidden folder';

  @override
  String get aiFirst => 'AI goes first';

  @override
  String get aiFirstHint =>
      'The model also checks what the app sorted on its own, so it makes more requests';

  @override
  String get composerHintNoSearch => 'Drop anything';

  @override
  String get returnsOff => 'Off';

  @override
  String get crashSetting => 'Error reports';

  @override
  String get crashSettingHint =>
      'The developer gets the error and your phone model, never your notes or file names.';

  @override
  String get vaultInFiles => 'Files → Stowa';

  @override
  String get vaultFilesHint =>
      'Notes are plain .md files that you can see in the Files app.';

  @override
  String get itemDateChange => 'Change date';

  @override
  String get itemDateNow => 'Now';

  @override
  String get itemDatePick => 'Pick a day and time';

  @override
  String get itemDateChanged => 'Date changed';

  @override
  String get propertiesTitle => 'Properties';

  @override
  String propertiesMore(Object count) {
    return '$count more';
  }

  @override
  String get propertiesLess => 'Show less';

  @override
  String get propertyAdd => 'Add property';

  @override
  String get propertyNew => 'New property';

  @override
  String get propertyEdit => 'Property';

  @override
  String get propertyNameHint => 'Name';

  @override
  String get propertyValueHint => 'Value';

  @override
  String get propertyListHint => 'One item per line';

  @override
  String get propertyKindText => 'Text';

  @override
  String get propertyKindList => 'List';

  @override
  String get propertyKindNumber => 'Number';

  @override
  String get propertyKindCheckbox => 'Checkbox';

  @override
  String get propertyKindDate => 'Date';

  @override
  String get propertyNameTaken => 'This property already exists';

  @override
  String get propertyNumberWrong => 'Enter a number';

  @override
  String get propertyDatePick => 'Pick a day';

  @override
  String get propertyDelete => 'Delete property';

  @override
  String get propertyRemoved => 'Property deleted';

  @override
  String get propertyOtherHint => 'This value can be changed in the note file.';

  @override
  String get propertyYes => 'Yes';

  @override
  String get propertyNo => 'No';

  @override
  String get lookSuggested => 'Match the name';

  @override
  String get lookPopular => 'Popular';

  @override
  String get lookAll => 'All icons';

  @override
  String get iconsNone => 'No such icon, try another word.';
}
