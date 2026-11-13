// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class LPl extends L {
  LPl([String locale = 'pl']) : super(locale);

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
  String get savePhotosHint => 'podpis i tagi możesz dodać później';

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
      'bez folderu, posortuję, gdy pojawi się coś podobnego';

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
  String get voiceSaved => 'Notatka głosowa zapisana';

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
  String get voiceNoTranscript => 'Bez transkrypcji';

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
  String get itemMore => 'Więcej';

  @override
  String get itemAppend => 'Dopisz';

  @override
  String get itemShare => 'Udostępnij';

  @override
  String get itemAutosave => 'Zapisuje się samo';

  @override
  String itemPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zdjęcia',
      many: '$count zdjęć',
      few: '$count zdjęcia',
      one: '$count zdjęcie',
    );
    return '$_temp0';
  }

  @override
  String get tagAddShort => 'Tag';

  @override
  String get itemOpenLink => 'Otwórz';

  @override
  String get itemWatch => 'Oglądaj';

  @override
  String get fileOpenFailed => 'Brak aplikacji do otwarcia pliku';

  @override
  String get linkOpenFailed => 'Nie udało się otworzyć linku';

  @override
  String photoCounter(Object count, Object index) {
    return '$index z $count';
  }

  @override
  String get photoToGallery => 'Do galerii';

  @override
  String get photoSaved => 'Zapisano w galerii';

  @override
  String get photoSaveFailed => 'Nie zapisano: brak dostępu do galerii';

  @override
  String get photoClose => 'Zamknij';

  @override
  String get voiceSpeed => 'Prędkość';

  @override
  String autoSorted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count podobnej notatki posortowanej',
      many: '$count podobnych notatek posortowanych',
      few: '$count podobne notatki posortowane',
      one: '$count podobna notatka posortowana',
    );
    return '$_temp0';
  }

  @override
  String get relatedTitle => 'Powiązane';

  @override
  String relatedWords(Object words) {
    return 'wspólne: $words';
  }

  @override
  String relatedSite(Object site) {
    return 'ta sama strona, $site';
  }

  @override
  String get relatedHide => 'Nie łącz';

  @override
  String get relatedHidden => 'Nie pokażę ich już razem';

  @override
  String aiSortedInto(String folder) {
    return 'Włożone do „$folder”';
  }

  @override
  String get aiOtherFolder => 'Inny';

  @override
  String get aiPausedAuth => 'Sortowanie wstrzymane: klucz odrzucony';

  @override
  String get aiPausedPayment =>
      'Sortowanie wstrzymane: na kluczu skończyły się środki';

  @override
  String get aiPausedAction => 'Sprawdź klucz';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get settingsAi => 'Sortowanie AI';

  @override
  String get aiStateOff => 'Wyłączone';

  @override
  String get aiStateOffHint =>
      'Dodaj własny klucz, a notatki bez folderu posortują się same.';

  @override
  String get aiStateOn => 'Działa';

  @override
  String aiStateWait(String time) {
    return 'Dostawca prosi o czekanie do $time';
  }

  @override
  String aiQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notatki czeka',
      many: '$count notatek czeka',
      few: '$count notatki czekają',
      one: '$count notatka czeka',
    );
    return '$_temp0';
  }

  @override
  String get aiSortNow => 'Posortuj teraz';

  @override
  String get aiKey => 'Klucz';

  @override
  String get aiKeyNone => 'Brak';

  @override
  String get aiKeySet => 'Ustawiony';

  @override
  String get aiKeyPaste => 'Wklej';

  @override
  String get aiKeySave => 'Zapisz i sprawdź';

  @override
  String get aiKeyRemove => 'Usuń klucz';

  @override
  String get aiKeyWhere =>
      'Klucz bierzesz od dostawcy: na OpenRouter jest w sekcji Keys, są też darmowe modele.';

  @override
  String get aiCheckOk => 'Klucz działa';

  @override
  String get aiCheckAuth => 'Dostawca odrzucił klucz';

  @override
  String get aiCheckPayment => 'Na kluczu brak środków';

  @override
  String get aiCheckRate => 'Dostawca prosi o chwilę';

  @override
  String get aiCheckNetwork => 'Brak połączenia z dostawcą';

  @override
  String get aiCheckServer => 'Dostawca zwrócił błąd';

  @override
  String get aiProvider => 'Dostawca';

  @override
  String get aiProviderHint =>
      'Adres API zgodnego z OpenAI, puste to OpenRouter.';

  @override
  String get aiSortModel => 'Model sortowania';

  @override
  String get aiSpeechModel => 'Transkrypcja głosówek';

  @override
  String get aiSpeechOff => 'Wyłączona';

  @override
  String get aiModelsSearch => 'Znajdź model';

  @override
  String get aiModelFree => 'darmowy';

  @override
  String get aiModelVision => 'widzi zdjęcia';

  @override
  String get aiModelsNeedKey => 'Lista modeli pojawi się po dodaniu klucza';

  @override
  String get aiModelsFailed => 'Lista modeli się nie wczytała';

  @override
  String aiModelOwn(String name) {
    return 'Własny: „$name”';
  }

  @override
  String get settingsOrder => 'Porządek';

  @override
  String get settingsLanguage => 'Język';

  @override
  String get languageSystem => 'Jak w systemie';

  @override
  String settingsVersion(String version) {
    return 'Stowa $version';
  }

  @override
  String get trashTitle => 'Kosz';

  @override
  String get trashEmpty => 'Kosz jest pusty';

  @override
  String get trashHint =>
      'Usunięte leży tu 30 dni, potem znika razem z plikami.';

  @override
  String trashDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dnia do usunięcia',
      many: '$count dni do usunięcia',
      few: '$count dni do usunięcia',
      one: '$count dzień do usunięcia',
    );
    return '$_temp0';
  }

  @override
  String trashFrom(String folder) {
    return 'z „$folder”';
  }

  @override
  String get trashPurge => 'Usuń na zawsze';

  @override
  String get trashPurgeAll => 'Opróżnij kosz';

  @override
  String trashPurgeAllAsk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notatki zniknie na zawsze. Nie da się tego cofnąć.',
      many: '$count notatek zniknie na zawsze. Nie da się tego cofnąć.',
      few: '$count notatki znikną na zawsze. Nie da się tego cofnąć.',
      one: '$count notatka zniknie na zawsze. Nie da się tego cofnąć.',
    );
    return '$_temp0';
  }

  @override
  String trashRestored(String title) {
    return 'Przywrócono „$title”';
  }

  @override
  String get trashPurged => 'Usunięto na zawsze';

  @override
  String get settingsData => 'Dane';

  @override
  String get backupSave => 'Zapisz kopię';

  @override
  String get backupSaveHint =>
      'Wszystkie notatki, foldery i pliki w jednym pliku, bez klucza AI.';

  @override
  String get backupRestore => 'Przywróć z kopii';

  @override
  String backupRestoreAsk(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notatki z kopii z $date zastąpi wszystko, co masz teraz.',
      many: '$count notatek z kopii z $date zastąpi wszystko, co masz teraz.',
      few: '$count notatki z kopii z $date zastąpią wszystko, co masz teraz.',
      one: '$count notatka z kopii z $date zastąpi wszystko, co masz teraz.',
    );
    return '$_temp0';
  }

  @override
  String get backupReplace => 'Zastąp';

  @override
  String get backupRestored => 'Przywrócono z kopii';

  @override
  String get backupNotStowa => 'To nie jest kopia Stowa';

  @override
  String get backupTooNew =>
      'Kopię zrobiła nowsza Stowa, zaktualizuj aplikację';

  @override
  String get backupFailed => 'Kopia się nie udała';

  @override
  String get folderNewBadge => 'nowy';

  @override
  String get aiSortingNow => 'Sortuję…';

  @override
  String get aiLog => 'Dziennik zapytań';

  @override
  String get aiLogEmpty => 'Nie było jeszcze zapytań do dostawcy';

  @override
  String get aiLogCluster => 'Nowe foldery z „Bez folderu”';

  @override
  String get aiCheckTimeout => 'Model nie odpowiedział na czas';

  @override
  String get tgTitle => 'Twój bot Telegram';

  @override
  String get tgNone => 'Niepodłączony';

  @override
  String get tgHowTo =>
      '1. Otwórz @BotFather w Telegramie i wyślij /⁠newbot.\n2. Nazwij bota, BotFather przyśle token.\n3. Wklej token tutaj.\n4. Napisz cokolwiek do swojego bota: od tej chwili słucha tylko ciebie, a wszystko, co mu przekażesz, trafia do Stowa.';

  @override
  String get tgConnect => 'Połącz';

  @override
  String tgOwner(String name) {
    return 'Słucha tylko: $name';
  }

  @override
  String get tgWaitingOwner => 'Napisz cokolwiek do bota, żeby cię zapamiętał';

  @override
  String get tgOpenBot => 'Otwórz bota';

  @override
  String get tgDisconnect => 'Odłącz bota';

  @override
  String get tgBadToken => 'Telegram odrzucił token';

  @override
  String get tgOffline => 'Brak połączenia z Telegramem';

  @override
  String tgPulled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wiadomości odebranej',
      many: '$count wiadomości odebranych',
      few: '$count wiadomości odebrane',
      one: '$count wiadomość odebrana',
    );
    return '$_temp0';
  }

  @override
  String get settingsOutside => 'Z zewnątrz';

  @override
  String selCount(int count) {
    return 'Zaznaczono: $count';
  }

  @override
  String get selClear => 'Odznacz';

  @override
  String get selAll => 'Zaznacz wszystko';

  @override
  String get selMove => 'Przenieś';

  @override
  String get selTag => 'Tag';

  @override
  String get selUntag => 'Usuń tag';

  @override
  String get selDelete => 'Usuń';

  @override
  String selMoved(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notatki przeniesionej do „$folder”',
      many: '$count notatek przeniesionych do „$folder”',
      few: '$count notatki przeniesione do „$folder”',
      one: '$count notatka przeniesiona do „$folder”',
    );
    return '$_temp0';
  }

  @override
  String selDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notatki usuniętej',
      many: '$count notatek usuniętych',
      few: '$count notatki usunięte',
      one: '$count notatka usunięta',
    );
    return '$_temp0';
  }

  @override
  String selTagged(String tag) {
    return 'Dodano #$tag';
  }

  @override
  String selUntagged(String tag) {
    return 'Usunięto #$tag';
  }

  @override
  String get tagPickTitle => 'Jaki tag';

  @override
  String get folderCanvas => 'Płótno';

  @override
  String get canvasFit => 'Pokaż wszystko';

  @override
  String get canvasNote => 'Notatka';

  @override
  String get canvasNoteHint => 'Co napisać na płótnie';

  @override
  String get graphTitle => 'Graf powiązań';

  @override
  String get graphEmpty =>
      'Nie ma jeszcze powiązań. Pojawią się, gdy notatki zaczną mieć wspólne słowa albo AI je połączy.';

  @override
  String get graphFailed => 'Graf się nie zbudował';

  @override
  String copyPartlyFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pliku się nie zapisało: aplikacja nie dała dostępu',
      many: '$count plików się nie zapisało: aplikacja nie dała dostępu',
      few: '$count pliki się nie zapisały: aplikacja nie dała dostępu',
      one: '$count plik się nie zapisał: aplikacja nie dała dostępu',
    );
    return '$_temp0';
  }

  @override
  String get mapTitle => 'Mapa';

  @override
  String get mapEmpty =>
      'Nic jeszcze nie ma miejsca. Nowe notatki zapamiętają, gdzie je zapisano, i pojawią się tutaj.';

  @override
  String get mapWhereAmI => 'Gdzie jestem';

  @override
  String get mapPlaceUnnamed => 'Miejsce bez nazwy';

  @override
  String get placeSetting => 'Zapamiętuj, gdzie zapisano';

  @override
  String get placeSettingHint =>
      'Miejsce widać w notatce i na mapie, na zewnątrz idzie tylko zapytanie o nazwę ulicy.';

  @override
  String panelLooking(Object what) {
    return 'Szukam: $what';
  }

  @override
  String get foundAtPlace => 'po miejscu';

  @override
  String fileSaving(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plików się zapisuje',
      few: '$count pliki się zapisują',
      one: '$count plik się zapisuje',
    );
    return '$_temp0';
  }

  @override
  String get fileSavingHint =>
      'Możesz zamknąć aplikację, a oryginał usunąć, gdy pasek zniknie.';

  @override
  String get foundInFile => 'w pliku';

  @override
  String get foundOnPage => 'na stronie';

  @override
  String get foundInPhotoInfo => 'w danych zdjęcia';

  @override
  String documentSheet(Object name) {
    return 'arkusz „$name”';
  }

  @override
  String documentSlide(Object number) {
    return 'slajd $number';
  }

  @override
  String documentChapter(Object number) {
    return 'rozdział $number';
  }

  @override
  String get factCall => 'Zadzwoń';

  @override
  String get factWrite => 'Napisz';

  @override
  String get factCopy => 'Kopiuj';

  @override
  String photoTaken(Object date) {
    return 'Zrobione $date';
  }

  @override
  String foundInSubtitles(Object time) {
    return 'w napisach · $time';
  }

  @override
  String foundInChapters(Object time) {
    return 'w rozdziałach · $time';
  }

  @override
  String get foundInIngredients => 'w składnikach';

  @override
  String get foundAtAddress => 'po adresie';

  @override
  String get foundInHashtags => 'w hashtagach';

  @override
  String get watchFromHere => 'Oglądaj od tego miejsca';

  @override
  String get pageRecipe => 'przepis';

  @override
  String get pageProduct => 'produkt';

  @override
  String get pageEvent => 'wydarzenie';

  @override
  String get pagePlace => 'miejsce';

  @override
  String get pageMovie => 'film';

  @override
  String get pageBook => 'książka';

  @override
  String get pageVideo => 'wideo';

  @override
  String get pageArticle => 'artykuł';

  @override
  String minutesShort(Object count) {
    return '$count min';
  }

  @override
  String servings(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count porcji',
      few: '$count porcje',
      one: '$count porcja',
    );
    return '$_temp0';
  }

  @override
  String readingMinutes(Object count) {
    return '$count min czytania';
  }

  @override
  String get inStock => 'Dostępny';

  @override
  String get outOfStock => 'Niedostępny';

  @override
  String get toShoppingList => 'Do listy zakupów';

  @override
  String shoppingFor(Object name) {
    return 'Kupić: $name';
  }

  @override
  String get shoppingReady => 'Lista zakupów gotowa';

  @override
  String get chaptersTitle => 'Rozdziały';

  @override
  String get authorTags => 'Tagi autora';

  @override
  String get pageSeries => 'serial';

  @override
  String get pageComic => 'komiks';

  @override
  String get adultSetting => 'Pokazuj 18+';

  @override
  String get adultSettingHint =>
      'Dopóki to wyłączone, okładki i opisy stron 18+ są ukryte.';

  @override
  String get adultHidden =>
      'Opis ukryty: 18+. Pokazywanie włączysz w ustawieniach.';

  @override
  String get vaultSetupTitle => 'Gdzie trzymać notatki';

  @override
  String get vaultSetupHint =>
      'Notatki, zdjęcia i pliki leżą jako zwykłe pliki w folderze, który otwiera też Obsidian.';

  @override
  String get vaultCreate => 'Utwórz skarbiec';

  @override
  String get vaultCreateHint =>
      'Nowy folder w pamięci telefonu: notatki zostaną, nawet gdy usuniesz aplikację.';

  @override
  String get vaultCreateButton => 'Utwórz';

  @override
  String get vaultOpen => 'Otwórz folder jako skarbiec';

  @override
  String get vaultOpenHint =>
      'Dawny skarbiec Stowa po ponownej instalacji albo skarbiec Obsidian.';

  @override
  String get vaultOpenButton => 'Otwórz';

  @override
  String get vaultInApp => 'Trzymaj w aplikacji';

  @override
  String get vaultInAppHint =>
      'Bez uprawnień, ale usunięcie aplikacji usunie notatki.';

  @override
  String get vaultInAppButton => 'Wybierz';

  @override
  String get vaultInAppWarning =>
      'Notatki będą w aplikacji i znikną, gdy ją usuniesz. Później przeniesiesz je do zwykłego folderu w ustawieniach.';

  @override
  String get vaultInAppConfirm => 'Trzymaj w aplikacji';

  @override
  String get vaultName => 'Nazwa skarbca';

  @override
  String get vaultPlace => 'Gdzie utworzyć';

  @override
  String get vaultAccessTitle => 'Potrzebny dostęp do plików';

  @override
  String get vaultAccessHint =>
      'Żeby trzymać notatki w zwykłym folderze, Android prosi o „Dostęp do wszystkich plików”, ale Stowa rusza tylko swój folder.';

  @override
  String get vaultAccessGrant => 'Otwórz ustawienia';

  @override
  String get vaultAccessDenied =>
      'Bez dostępu do plików skarbiec w pamięci telefonu nie działa';

  @override
  String vaultMoving(int done, int total) {
    return 'Przenoszę: $done z $total';
  }

  @override
  String vaultBuilding(int done, int total) {
    return 'Buduję indeks: $done z $total';
  }

  @override
  String vaultMoveFailed(int count) {
    return 'Nie wszystko się przeniosło, brakuje: $count. Notatki zostały na starym miejscu.';
  }

  @override
  String get vaultMissingTitle => 'Nie znaleziono skarbca';

  @override
  String vaultMissingHint(String path) {
    return 'Folderu $path nie ma albo Stowa straciła dostęp do plików. Notatki w aplikacji są całe.';
  }

  @override
  String get vaultGrantAccess => 'Daj dostęp';

  @override
  String get vaultChooseAgain => 'Wybierz folder';

  @override
  String get vaultSection => 'Skarbiec';

  @override
  String get vaultFolder => 'Folder';

  @override
  String get vaultInsideApp => 'W aplikacji';

  @override
  String get vaultMoveTo => 'Przenieś do innego folderu';

  @override
  String get vaultRebuild => 'Odbuduj indeks';

  @override
  String get vaultSettingHint =>
      'Notatki to zwykłe pliki .md, otwiera je też Obsidian.';

  @override
  String get vaultMoved => 'Skarbiec przeniesiony';

  @override
  String get vaultRebuilt => 'Indeks odbudowany';

  @override
  String vaultSyncing(int done, int total) {
    return 'Synchronizacja notatek $done z $total';
  }

  @override
  String repeatIn(String folder, String date) {
    return 'Taka sama leży w folderze „$folder” od $date';
  }

  @override
  String repeatNoFolder(String date) {
    return 'Taka sama leży bez folderu od $date';
  }

  @override
  String get settingsImport => 'Import';

  @override
  String get importTelegram => 'Z Telegrama';

  @override
  String get importTelegramHint =>
      'Wybierz folder eksportu „Zapisanych” z Telegram Desktop.';

  @override
  String importProgress(int done, int total) {
    return 'Przenoszę $done z $total';
  }

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notatki przeniesione',
      many: '$count notatek przeniesionych',
      few: '$count notatki przeniesione',
      one: '$count notatka przeniesiona',
    );
    return '$_temp0';
  }

  @override
  String importRepeated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count już były',
      many: '$count już były',
      few: '$count już były',
      one: '$count już była',
    );
    return '$_temp0';
  }

  @override
  String get importNotTelegram =>
      'W tym folderze nie ma eksportu Telegrama: potrzebny jest messages.html lub result.json';

  @override
  String importMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pliku pominiętego w eksporcie',
      many: '$count plików pominiętych w eksporcie',
      few: '$count pliki pominięte w eksporcie',
      one: '$count plik pominięty w eksporcie',
    );
    return '$_temp0 — włącz pliki w ustawieniach eksportu i przenieś ponownie';
  }

  @override
  String importFilled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wcześniejszej notatki dostało pliki',
      many: '$count wcześniejszych notatek dostało pliki',
      few: '$count wcześniejsze notatki dostały pliki',
      one: '$count wcześniejsza notatka dostała pliki',
    );
    return '$_temp0';
  }

  @override
  String get returnChannel => 'Powroty';

  @override
  String get returnWatchTitle => 'Do obejrzenia';

  @override
  String returnVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmu',
      many: '$count filmów',
      few: '$count filmy',
      one: '$count film',
    );
    return '$_temp0';
  }

  @override
  String returnArticles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artykułu',
      many: '$count artykułów',
      few: '$count artykuły',
      one: '$count artykuł',
    );
    return '$_temp0';
  }

  @override
  String returnMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minuty',
      many: '$count minut',
      few: '$count minuty',
      one: '$count minuta',
    );
    return '$_temp0';
  }

  @override
  String returnAnd(String first, String second) {
    return '$first i $second';
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
      other: '$count roku temu',
      many: '$count lat temu',
      few: '$count lata temu',
      one: 'Rok temu',
    );
    return '$_temp0';
  }

  @override
  String get returnMonthAgo => 'Miesiąc temu';

  @override
  String get returnWeekAgo => 'Tydzień temu';

  @override
  String returnDayOne(String title) {
    return '„$title”';
  }

  @override
  String returnDayMore(String title, int count) {
    return '„$title” i jeszcze $count';
  }

  @override
  String get returnOnThisDay => 'Tego dnia';

  @override
  String get returnWeekTitle => 'Tydzień w Stowa';

  @override
  String returnWeekSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notatki w tym tygodniu',
      many: '$count notatek w tym tygodniu',
      few: '$count notatki w tym tygodniu',
      one: '$count notatka w tym tygodniu',
    );
    return '$_temp0';
  }

  @override
  String returnWeekUnopened(int count) {
    return '$count nieotwarte';
  }

  @override
  String returnWeekUnsorted(int count) {
    return '$count bez folderu';
  }

  @override
  String get returnWeekUnopenedTitle => 'Nieotwarte';

  @override
  String get returnWeekUnsortedTitle => 'Bez folderu';

  @override
  String returnShopTitle(String shop) {
    return 'W sklepie $shop';
  }

  @override
  String returnShopMore(String items, int count) {
    return '$items i jeszcze $count';
  }

  @override
  String get returnShopping => 'Do kupienia';

  @override
  String get settingsReturns => 'Powiadomienia';

  @override
  String get returnWeekSetting => 'Podsumowanie tygodnia';

  @override
  String get returnShoppingSetting => 'Zakupy przy sklepie';

  @override
  String get returnEveningRow => 'Wieczorem o';

  @override
  String get returnQuietRow => 'Godziny ciszy';

  @override
  String get returnWeekDayRow => 'Dzień podsumowania';

  @override
  String get returnSettingsHint =>
      'Najwyżej jedno ciche powiadomienie dziennie.';

  @override
  String returnRange(String from, String to) {
    return '$from–$to';
  }

  @override
  String get returnQuietFrom => 'Cisza od';

  @override
  String get returnQuietTo => 'Cisza do';

  @override
  String get returnWatchEmpty =>
      'Kolejka jest pusta: wszystko świeże już obejrzane.';

  @override
  String get returnDayEmpty => 'Tego dnia wcześniej nic nie zapisano.';

  @override
  String get returnWeekEmpty => 'W tym tygodniu nic nie zapisano.';

  @override
  String get returnShoppingEmpty => 'Nic do kupienia: listy odhaczone.';

  @override
  String returnMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get returnsAskTitle => 'Przypominać zapisane?';

  @override
  String get returnsAskBody =>
      'Jedno ciche powiadomienie wieczorem przypomni o tym, co zapisałeś.';

  @override
  String get returnsAskOn => 'Włącz';

  @override
  String get returnsAskLater => 'Nie teraz';

  @override
  String get placeRemindHome => 'Przypomnij w domu';

  @override
  String get placeRemindWork => 'Przypomnij w pracy';

  @override
  String get placeRemindHere => 'Przypomnij tutaj';

  @override
  String get placeRemindShop => 'Przypomnij w sklepie';

  @override
  String placeRemindAt(String place) {
    return 'Przypomnij: $place';
  }

  @override
  String get composerRemovePlace => 'Bez przypomnienia o miejscu';

  @override
  String get placesTitle => 'Miejsca';

  @override
  String get placesHome => 'Dom';

  @override
  String get placesWork => 'Praca';

  @override
  String get placesShops => 'Sklepy';

  @override
  String get placesNotSet => 'Nie ustawiono';

  @override
  String placesWifi(String name) {
    return 'Wi-Fi: $name';
  }

  @override
  String get placesImHome => 'Jestem teraz w domu';

  @override
  String get placesImWork => 'Jestem teraz w pracy';

  @override
  String get placesImShop => 'Jestem w sklepie — zapamiętaj';

  @override
  String placesGuessHome(String name) {
    return 'Wygląda na to, że dom to $name';
  }

  @override
  String placesGuessWork(String name) {
    return 'Wygląda na to, że praca to $name';
  }

  @override
  String get placesRemove => 'Usuń';

  @override
  String get placesShopName => 'Nazwa sklepu';

  @override
  String get placesSave => 'Zapisz';

  @override
  String get placesNoFix =>
      'Nie udało się ustalić, gdzie jesteś. Sprawdź, czy lokalizacja jest włączona i dozwolona dla Stowa.';

  @override
  String get placesPermissionTitle => 'Potrzebna lokalizacja „zawsze”';

  @override
  String get placesPermissionBody =>
      'Przypomnienia w miejscu działają tylko wtedy, gdy lokalizacja jest dozwolona „zawsze”.';

  @override
  String get placesPermissionAllow => 'Zezwól';

  @override
  String get placesHint =>
      'Napisz „przypomnij mi w aptece”, a Stowa przypomni ci na miejscu.';

  @override
  String placesShopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sklepu',
      many: '$count sklepów',
      few: '$count sklepy',
      one: '$count sklep',
    );
    return '$_temp0';
  }

  @override
  String get itemRemindTime => 'O godzinie';

  @override
  String get itemPlaceChange => 'Inne miejsce';

  @override
  String get placesMissingHome =>
      'Dom nie jest jeszcze ustawiony: Stowa przypomni, gdy ustawisz go w Miejscach';

  @override
  String get placesMissingWork =>
      'Praca nie jest jeszcze ustawiona: Stowa przypomni, gdy ustawisz ją w Miejscach';

  @override
  String get placesMissingShop =>
      'Nie ma jeszcze sklepów: zapisz choć jeden w Miejscach';

  @override
  String get placeChannel => 'Przypomnienia o miejscu';

  @override
  String get remindPlaceNeedsAlways =>
      'Przypomnę na miejscu, jeśli zezwolisz na lokalizację „zawsze”';

  @override
  String get lookColor => 'Kolor';

  @override
  String homeFoldersMore(Object count) {
    return 'Jeszcze $count';
  }

  @override
  String homeChecksMore(Object count) {
    return 'jeszcze $count';
  }

  @override
  String get catalogTitle => 'Katalog';

  @override
  String get catalogExpand => 'Rozwiń wszystko';

  @override
  String get catalogCollapse => 'Zwiń wszystko';

  @override
  String get catalogOpenFolder => 'Otwórz folder';

  @override
  String foldersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count folderu',
      many: '$count folderów',
      few: '$count foldery',
      one: '$count folder',
    );
    return '$_temp0';
  }

  @override
  String readerOpen(Object count) {
    return 'Czytaj · $count min';
  }

  @override
  String get readerOriginal => 'Oryginał';

  @override
  String get readerQuote => 'Cytat';

  @override
  String get readerCopy => 'Kopiuj';

  @override
  String get readerNote => 'Notatka';

  @override
  String get readerNoteHint => 'Notatka do cytatu';

  @override
  String get readerRemove => 'Usuń';

  @override
  String get readerRemoved => 'Cytat usunięty';

  @override
  String get readerGone => 'Oryginał usunięty · kopia zapisana';

  @override
  String get readerNoCopy =>
      'Tekst artykułu się nie zapisał. Można go otworzyć na stronie.';

  @override
  String get readerImageOff => 'Obraz nie zapisany';

  @override
  String get highlightsTitle => 'Cytaty';

  @override
  String get linkGone => 'Link się nie otwiera';

  @override
  String get deadLinksTitle => 'Martwe linki';

  @override
  String get deadLinksAbout =>
      'Raz w tygodniu Stowa sprawdza linki i zbiera tu strony usunięte przez witrynę.';

  @override
  String get deadLinksEmpty => 'Wszystkie linki działają';

  @override
  String get deadLinksCheck => 'Sprawdź teraz';

  @override
  String get deadLinksChecking => 'Sprawdzam linki…';

  @override
  String get deadLinksKeep => 'Zostaw';

  @override
  String get deadLinksDelete => 'Usuń';

  @override
  String get deadLinksDeleted => 'Notatka w koszu';

  @override
  String deadLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nie działa',
      many: '$count nie działa',
      few: '$count nie działają',
      one: '$count nie działa',
    );
    return '$_temp0';
  }

  @override
  String get settingsArticles => 'Artykuły';

  @override
  String get articleImages => 'Obrazy w artykułach';

  @override
  String get articleImagesAbout =>
      'Pobieraj przez Wi-Fi, żeby czytać artykuły z obrazami bez sieci';

  @override
  String get foundInArticle => 'w artykule';

  @override
  String get foundInQuote => 'w cytacie';

  @override
  String get settingsStart => 'Uruchamianie';

  @override
  String get startOpen => 'Otwieraj';

  @override
  String get startHome => 'Ekran główny';

  @override
  String get startLast => 'Ostatnią notatkę';

  @override
  String get startRandom => 'Losową notatkę';

  @override
  String get startHint =>
      'Ostatnia notatka wraca tam, gdzie skończyłeś, losowa przypomina coś z zapisanych.';

  @override
  String get appearanceTitle => 'Wygląd';

  @override
  String get appearanceTheme => 'Motyw';

  @override
  String get themeLight => 'Jasny';

  @override
  String get themeDark => 'Ciemny';

  @override
  String get themeSystem => 'Jak w systemie';

  @override
  String get themeByTime => 'Według pory dnia';

  @override
  String get themeByTimeHint => 'Ciemny od 20:00 do 7:00';

  @override
  String get appearanceColor => 'Kolor';

  @override
  String get colorGraphite => 'Grafit';

  @override
  String get colorCustom => 'Własny kolor';

  @override
  String get colorFromWallpaper => 'Z tapety';

  @override
  String get colorIntensity => 'Nasycenie';

  @override
  String get intensityVibrant => 'Żywo';

  @override
  String get intensityFaithful => 'Dokładnie';

  @override
  String get intensityHint =>
      '„Żywo” barwi też tło, „Dokładnie” zostawia je szare.';

  @override
  String get wallpaperColors => 'Kolory z tapety';

  @override
  String get wallpaperColorsHint => 'Kolor motywu dopasowuje się do tapety';

  @override
  String get amoledTitle => 'Czarne tło';

  @override
  String get amoledHint => 'Czysta czerń dla ekranów AMOLED, oszczędza baterię';

  @override
  String get pickerApply => 'Gotowe';

  @override
  String get colorCoral => 'Koral';

  @override
  String get colorAmber => 'Bursztyn';

  @override
  String get colorLime => 'Limonka';

  @override
  String get colorMint => 'Mięta';

  @override
  String get colorTeal => 'Turkus';

  @override
  String get colorBlue => 'Niebieski';

  @override
  String get colorViolet => 'Fiolet';

  @override
  String get colorRose => 'Róża';

  @override
  String get folderNewInside => 'Nowy folder w środku';

  @override
  String get folderMoveTo => 'Przenieś do…';

  @override
  String get folderMoveTop => 'Na górę';

  @override
  String get folderMoveNone =>
      'Nie ma dokąd przenieść: foldery zagnieżdżają się do trzech poziomów';

  @override
  String get historyTitle => 'Historia';

  @override
  String get historyNow => 'Teraz';

  @override
  String get historyHint =>
      'Poprzedni tekst zostaje, gdy edytujesz notatkę po przerwie.';

  @override
  String get historyNoChanges => 'Ten sam tekst';

  @override
  String get historyText => 'Tekst';

  @override
  String get historyDiff => 'Różnice';

  @override
  String get historyDiffHint =>
      'Przekreślone — było w tej wersji, podświetlone — doszło później';

  @override
  String get historyRestore => 'Przywróć tę wersję';

  @override
  String get historyRestored => 'Wersja przywrócona';

  @override
  String get sortByColor => 'Według koloru';

  @override
  String qrWifi(String network) {
    return 'Wi-Fi „$network”';
  }

  @override
  String get qrCopyPassword => 'Kopiuj hasło Wi-Fi';

  @override
  String get qrPasswordCopied => 'Hasło skopiowane';

  @override
  String get qrOpenLink => 'Otwórz link z kodu QR';

  @override
  String get qrCopyText => 'Kopiuj tekst kodu QR';

  @override
  String get foundInQr => 'w kodzie QR';

  @override
  String documentPage(String number) {
    return 'str. $number';
  }

  @override
  String get titleDateSetting => 'Nazwy zdjęć i filmów';

  @override
  String get titleDateShot => 'Według daty zrobienia';

  @override
  String get titleDateSaved => 'Według daty zapisania';

  @override
  String get titleDateHint =>
      'Zdjęcia i filmy bez podpisu dostają datę w nazwie.';

  @override
  String get factPassword => 'Hasło ••••••';

  @override
  String factPasswordFor(String network) {
    return 'Wi-Fi „$network” ••••••';
  }

  @override
  String get factCopyPassword => 'Kopiuj hasło';

  @override
  String factCard(String last) {
    return 'Karta ••$last';
  }

  @override
  String get factCopyCard => 'Kopiuj numer karty';

  @override
  String factPromo(String code) {
    return 'Kod $code';
  }

  @override
  String get factCopyPromo => 'Kopiuj kod';

  @override
  String get factTrack => 'Śledź przesyłkę';

  @override
  String get factOnMap => 'Otwórz na mapie';

  @override
  String get workEndRow => 'Praca do';

  @override
  String get toChecklist => 'Jako lista zakupów';

  @override
  String get toChecklistHint => 'Zamień na pola wyboru';

  @override
  String get toChecklistDone => 'Lista zakupów gotowa';

  @override
  String folderTotal(String sum) {
    return 'Razem $sum';
  }

  @override
  String get smartSave => 'Inteligentny folder';

  @override
  String smartSaved(String name) {
    return 'Inteligentny folder „$name” jest na ekranie głównym';
  }

  @override
  String get smartEmpty => 'Na razie nic nie pasuje do tego wyszukiwania';

  @override
  String get smartDelete => 'Usuń inteligentny folder';

  @override
  String smartDeleted(String name) {
    return 'Usunięto folder „$name”, notatki zostały';
  }

  @override
  String suggestSite(int count, String site) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linku',
      many: '$count linków',
      few: '$count linki',
      one: '$count link',
    );
    return '$_temp0 z $site bez folderu';
  }

  @override
  String suggestScreenshots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zrzutu',
      many: '$count zrzutów',
      few: '$count zrzuty',
      one: '$count zrzut',
    );
    return '$_temp0 bez folderu';
  }

  @override
  String suggestVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmu',
      many: '$count filmów',
      few: '$count filmy',
      one: '$count film',
    );
    return '$_temp0 bez folderu';
  }

  @override
  String suggestFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pliku',
      many: '$count plików',
      few: '$count pliki',
      one: '$count plik',
    );
    return '$_temp0 bez folderu';
  }

  @override
  String suggestVoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notatki głosowej',
      many: '$count notatek głosowych',
      few: '$count notatki głosowe',
      one: '$count notatka głosowa',
    );
    return '$_temp0 bez folderu';
  }

  @override
  String suggestSiteBody(String name) {
    return 'Utworzyć folder „$name”? Nowe linki z tej strony trafią tam same.';
  }

  @override
  String suggestBody(String name) {
    return 'Utworzyć folder „$name” i przenieść je tam?';
  }

  @override
  String get suggestYes => 'Utwórz';

  @override
  String get suggestNo => 'Nie trzeba';

  @override
  String suggestDone(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notatki',
      many: '$count notatek',
      few: '$count notatki',
      one: '$count notatka',
    );
    return 'Folder „$name”: $_temp0';
  }

  @override
  String get suggestScreenshotsName => 'Zrzuty ekranu';

  @override
  String get suggestVideosName => 'Filmy';

  @override
  String get suggestFilesName => 'Pliki';

  @override
  String get suggestVoicesName => 'Notatki głosowe';

  @override
  String get ruleIfPage => 'strona to';

  @override
  String get ruleIfPriceAbove => 'cena powyżej';

  @override
  String get ruleIfPriceBelow => 'cena poniżej';

  @override
  String get ruleValuePrice => 'Kwota, np. 1000';

  @override
  String rulePriceAboveValue(String value) {
    return 'powyżej $value';
  }

  @override
  String rulePriceBelowValue(String value) {
    return 'poniżej $value';
  }

  @override
  String get ruleThenRemind => 'przypomnij';

  @override
  String get remindHourBefore => 'godzinę przed';

  @override
  String get remindDayBefore => 'dzień przed';

  @override
  String get remindWeekBefore => 'tydzień przed';

  @override
  String codeWait(Object seconds) {
    return 'Poczekaj $seconds s';
  }

  @override
  String get codeFingerprint => 'Odcisk palca';

  @override
  String get codeErase => 'Usuń';

  @override
  String get codeDone => 'Gotowe';

  @override
  String get codeWrong => 'Zły kod';

  @override
  String get codeCreateTitle => 'Wymyśl kod';

  @override
  String get codeRepeatTitle => 'Powtórz kod';

  @override
  String get codeCreateHint =>
      'Od 6 do 12 cyfr: jeśli zapomnisz kodu, ukrytych notatek nie da się odzyskać.';

  @override
  String get codeMismatch => 'Kody się różnią, wymyśl jeszcze raz';

  @override
  String get hiddenOpenReason => 'Otwórz ukryte foldery';

  @override
  String get hiddenOpenTitle => 'Kod ukrytych folderów';

  @override
  String get codeForgot => 'Nie pamiętam kodu';

  @override
  String get codeOldTitle => 'Obecny kod';

  @override
  String get codeNewTitle => 'Nowy kod';

  @override
  String get codeChanged => 'Kod zmieniony';

  @override
  String get codeForgetTitle => 'Zdjąć kod?';

  @override
  String get codeForgetText =>
      'Blokada się wyłączy, a ukryte foldery zostaną usunięte razem z notatkami. Nie da się ich przywrócić.';

  @override
  String get codeForgetAction => 'Zdejmij kod i usuń ukryte';

  @override
  String folderHidden(Object name) {
    return 'Folder „$name” ukryty';
  }

  @override
  String folderUnhidden(Object name) {
    return 'Folder „$name” znów widoczny';
  }

  @override
  String get lockReason => 'Odblokuj Stowa';

  @override
  String get lockTitle => 'Wpisz kod';

  @override
  String get codeEnterTitle => 'Wpisz kod';

  @override
  String get closeAfterNow => 'Od razu';

  @override
  String get closeAfterMinute => 'Po minucie';

  @override
  String closeAfterMinutes(Object minutes) {
    return 'Po $minutes minutach';
  }

  @override
  String get privacySection => 'Prywatność';

  @override
  String get codeCreateRow => 'Ustaw kod';

  @override
  String get appLockRow => 'Kod przy wejściu';

  @override
  String get fingerprintRow => 'Odcisk palca';

  @override
  String get closeAfterRow => 'Blokuj ponownie';

  @override
  String get hiddenCloseRow => 'Zamknij ukryte foldery';

  @override
  String get hiddenOpenRow => 'Otwórz ukryte foldery';

  @override
  String get codeChangeRow => 'Zmień kod';

  @override
  String get privacyHint =>
      'Ukryte foldery są zaszyfrowane, bez kodu nikt ich nie przeczyta.';

  @override
  String get markdownExport => 'Eksportuj do Markdown';

  @override
  String get markdownNoVault => 'Najpierw wybierz folder skarbca';

  @override
  String get markdownHiddenAsk => 'Eksportować też ukryte foldery?';

  @override
  String get markdownHiddenHint =>
      'Ukryte notatki staną się zwykłymi plikami, przeczyta je każdy, kto ma ten folder.';

  @override
  String get markdownWithoutHidden => 'Bez ukrytych';

  @override
  String get markdownWithHidden => 'Razem z ukrytymi';

  @override
  String markdownDone(Object path) {
    return 'Wyeksportowano do $path';
  }

  @override
  String get markdownFailed => 'Nie udało się zapisać w tym folderze';

  @override
  String get folderUnhide => 'Nie ukrywaj';

  @override
  String get folderHide => 'Ukryj folder';

  @override
  String get folderHiddenMark => 'ukryty';

  @override
  String get hiddenFolders => 'Ukryte foldery';

  @override
  String get hiddenReminder => 'Przypomnienie z ukrytego folderu';

  @override
  String get aiFirst => 'AI ma pierwszeństwo';

  @override
  String get aiFirstHint =>
      'Model sprawdza też to, co aplikacja posortowała sama, więc zapytań jest więcej';

  @override
  String get composerHintNoSearch => 'Wrzuć cokolwiek';

  @override
  String get returnsOff => 'Wyłączone';

  @override
  String get crashSetting => 'Raporty o błędach';

  @override
  String get crashSettingHint =>
      'Twórca dostaje błąd i model telefonu, bez notatek i nazw plików.';

  @override
  String get vaultInFiles => 'Pliki → Stowa';

  @override
  String get vaultFilesHint =>
      'Notatki to zwykłe pliki .md, widać je w aplikacji Pliki.';

  @override
  String get itemDateChange => 'Zmień datę';

  @override
  String get itemDateNow => 'Teraz';

  @override
  String get itemDatePick => 'Wybierz dzień i godzinę';

  @override
  String get itemDateChanged => 'Data zmieniona';

  @override
  String get propertiesTitle => 'Właściwości';

  @override
  String propertiesMore(Object count) {
    return 'Jeszcze $count';
  }

  @override
  String get propertiesLess => 'Zwiń';

  @override
  String get propertyAdd => 'Dodaj właściwość';

  @override
  String get propertyNew => 'Nowa właściwość';

  @override
  String get propertyEdit => 'Właściwość';

  @override
  String get propertyNameHint => 'Nazwa';

  @override
  String get propertyValueHint => 'Wartość';

  @override
  String get propertyListHint => 'Każdy element w nowej linii';

  @override
  String get propertyKindText => 'Tekst';

  @override
  String get propertyKindList => 'Lista';

  @override
  String get propertyKindNumber => 'Liczba';

  @override
  String get propertyKindCheckbox => 'Pole wyboru';

  @override
  String get propertyKindDate => 'Data';

  @override
  String get propertyNameTaken => 'Taka właściwość już jest';

  @override
  String get propertyNumberWrong => 'Wpisz liczbę';

  @override
  String get propertyDatePick => 'Wybierz dzień';

  @override
  String get propertyDelete => 'Usuń właściwość';

  @override
  String get propertyRemoved => 'Właściwość usunięta';

  @override
  String get propertyOtherHint => 'Tę wartość zmienia się w pliku notatki.';

  @override
  String get propertyYes => 'Tak';

  @override
  String get propertyNo => 'Nie';

  @override
  String get lookSuggested => 'Pasują do nazwy';

  @override
  String get lookPopular => 'Częste';

  @override
  String get lookAll => 'Wszystkie ikony';

  @override
  String get iconsNone => 'Nie ma takiej ikony, spróbuj innego słowa.';

  @override
  String get placeKindHome => 'Dom';

  @override
  String get placeKindWork => 'Praca';

  @override
  String get placeKindStudy => 'Nauka';

  @override
  String get placeKindShop => 'Sklep';

  @override
  String get placeKindPharmacy => 'Apteka';

  @override
  String get placeKindFood => 'Kawiarnie i restauracje';

  @override
  String get placeKindSport => 'Sport';

  @override
  String get placeKindGuests => 'Goście';

  @override
  String get placeKindOther => 'Inne';

  @override
  String get placeRemindStudy => 'Przypomnij na uczelni';

  @override
  String get placeRemindPharmacy => 'Przypomnij przy aptece';

  @override
  String get placeRemindFood => 'Przypomnij w kawiarni';

  @override
  String get placeRemindSport => 'Przypomnij na siłowni';

  @override
  String get placeRemindGuests => 'Przypomnij w gościach';

  @override
  String get placeRemindOther => 'Przypomnij w miejscu';

  @override
  String placeRemindDay(String place, String day) {
    return '$place · $day';
  }

  @override
  String get dayToday => 'dziś';

  @override
  String get dayTomorrow => 'jutro';

  @override
  String get placesMissingKind =>
      'Takiego miejsca jeszcze nie ma: przypomnę, gdy dodasz je w Miejscach';

  @override
  String get placesAdd => 'Dodaj miejsce';

  @override
  String get placesEmpty =>
      'Nie ma jeszcze miejsc: dodaj dom, pracę, ulubioną kawiarnię albo przyjaciela.';

  @override
  String get placeNewTitle => 'Nowe miejsce';

  @override
  String get placeEditTitle => 'Miejsce';

  @override
  String get placeNameHint => 'Jak nazwać: Uczelnia, Sasza, Andy’s';

  @override
  String get placeKindTitle => 'Co to';

  @override
  String get placeWhereTitle => 'Gdzie';

  @override
  String get placeHereNow => 'Jestem tu teraz';

  @override
  String get placeMapHint =>
      'Przesuń mapę: miejsce jest tam, gdzie kropka na środku.';

  @override
  String get placeKindMore => 'Znajdź lub utwórz';

  @override
  String get placeKindSearchHint => 'Znajdź rodzaj lub nazwij własny';

  @override
  String placeKindCreate(String name) {
    return 'Utwórz „$name”';
  }

  @override
  String get placeIcon => 'Ikona';
}
