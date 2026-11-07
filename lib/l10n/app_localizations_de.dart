// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class LDe extends L {
  LDe([String locale = 'de']) : super(locale);

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
  String get savePhotosHint =>
      'Beschriftung und Tags kannst du später ergänzen';

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
      'noch ohne Ordner, ich sortiere, sobald Ähnliches auftaucht';

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
  String get voiceSaved => 'Sprachnotiz gespeichert';

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
  String get voiceNoTranscript => 'Ohne Transkript';

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
  String get itemMore => 'Mehr';

  @override
  String get itemAppend => 'Ergänzen';

  @override
  String get itemShare => 'Teilen';

  @override
  String get itemAutosave => 'Speichert automatisch';

  @override
  String itemPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos',
      one: '$count Foto',
    );
    return '$_temp0';
  }

  @override
  String get tagAddShort => 'Tag';

  @override
  String get itemOpenLink => 'Öffnen';

  @override
  String get itemWatch => 'Ansehen';

  @override
  String get fileOpenFailed => 'Keine App kann diese Datei öffnen';

  @override
  String get linkOpenFailed => 'Link ließ sich nicht öffnen';

  @override
  String photoCounter(Object count, Object index) {
    return '$index von $count';
  }

  @override
  String get photoToGallery => 'In Galerie';

  @override
  String get photoSaved => 'In Galerie gespeichert';

  @override
  String get photoSaveFailed =>
      'Nicht gespeichert: kein Zugriff auf die Galerie';

  @override
  String get photoClose => 'Schließen';

  @override
  String get voiceSpeed => 'Tempo';

  @override
  String autoSorted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ähnliche Elemente einsortiert',
      one: '$count ähnliches Element einsortiert',
    );
    return '$_temp0';
  }

  @override
  String get relatedTitle => 'Verwandt';

  @override
  String relatedWords(Object words) {
    return 'gemeinsam: $words';
  }

  @override
  String relatedSite(Object site) {
    return 'dieselbe Seite, $site';
  }

  @override
  String get relatedHide => 'Nicht verknüpfen';

  @override
  String get relatedHidden => 'Zeige sie nicht mehr zusammen';

  @override
  String aiSortedInto(String folder) {
    return 'In „$folder“ gelegt';
  }

  @override
  String get aiOtherFolder => 'Anderer';

  @override
  String get aiPausedAuth => 'Sortieren pausiert: Schlüssel abgelehnt';

  @override
  String get aiPausedPayment =>
      'Sortieren pausiert: Guthaben des Schlüssels aufgebraucht';

  @override
  String get aiPausedAction => 'Schlüssel prüfen';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsAi => 'KI-Sortierung';

  @override
  String get aiStateOff => 'Aus';

  @override
  String get aiStateOffHint =>
      'Füge deinen eigenen Schlüssel hinzu, dann sortieren sich Elemente ohne Ordner selbst, mit Tags, Titel und Beschreibung für die Suche. Der Schlüssel bleibt auf diesem Handy, Anfragen gehen direkt an den Anbieter.';

  @override
  String get aiStateOn => 'An';

  @override
  String aiStateWait(String time) {
    return 'Der Anbieter bittet bis $time zu warten';
  }

  @override
  String aiQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente warten',
      one: '$count Element wartet',
    );
    return '$_temp0';
  }

  @override
  String get aiSortNow => 'Jetzt sortieren';

  @override
  String get aiKey => 'Schlüssel';

  @override
  String get aiKeyNone => 'Nicht gesetzt';

  @override
  String get aiKeySet => 'Gesetzt';

  @override
  String get aiKeyPaste => 'Einfügen';

  @override
  String get aiKeySave => 'Speichern und prüfen';

  @override
  String get aiKeyRemove => 'Schlüssel entfernen';

  @override
  String get aiKeyWhere =>
      'Den Schlüssel gibt es beim Anbieter, bei OpenRouter unter Keys. Es gibt kostenlose Modelle.';

  @override
  String get aiCheckOk => 'Der Schlüssel funktioniert';

  @override
  String get aiCheckAuth => 'Der Anbieter hat den Schlüssel abgelehnt';

  @override
  String get aiCheckPayment => 'Der Schlüssel hat kein Guthaben';

  @override
  String get aiCheckRate => 'Der Anbieter bittet zu warten';

  @override
  String get aiCheckNetwork => 'Anbieter nicht erreichbar';

  @override
  String get aiCheckServer => 'Der Anbieter meldet einen Fehler';

  @override
  String get aiProvider => 'Anbieter';

  @override
  String get aiProviderHint =>
      'Adresse einer OpenAI-kompatiblen API. Leer heißt OpenRouter.';

  @override
  String get aiSortModel => 'Sortiermodell';

  @override
  String get aiSpeechModel => 'Sprachtranskription';

  @override
  String get aiSpeechOff => 'Aus';

  @override
  String get aiModelsSearch => 'Modell suchen';

  @override
  String get aiModelFree => 'kostenlos';

  @override
  String get aiModelVision => 'sieht Fotos';

  @override
  String get aiModelsNeedKey => 'Die Modellliste erscheint nach dem Schlüssel';

  @override
  String get aiModelsFailed => 'Die Modellliste wurde nicht geladen';

  @override
  String aiModelOwn(String name) {
    return 'Eigenes: „$name“';
  }

  @override
  String get settingsOrder => 'Ordnung';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get languageSystem => 'Wie im System';

  @override
  String settingsVersion(String version) {
    return 'Stowa $version';
  }

  @override
  String get trashTitle => 'Papierkorb';

  @override
  String get trashEmpty => 'Der Papierkorb ist leer';

  @override
  String get trashHint =>
      'Gelöschtes bleibt 30 Tage hier und wird dann samt Dateien gelöscht.';

  @override
  String trashDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage übrig',
      one: '$count Tag übrig',
    );
    return '$_temp0';
  }

  @override
  String trashFrom(String folder) {
    return 'aus „$folder“';
  }

  @override
  String get trashPurge => 'Endgültig löschen';

  @override
  String get trashPurgeAll => 'Papierkorb leeren';

  @override
  String trashPurgeAllAsk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Elemente werden endgültig gelöscht. Das lässt sich nicht rückgängig machen.',
      one:
          '$count Element wird endgültig gelöscht. Das lässt sich nicht rückgängig machen.',
    );
    return '$_temp0';
  }

  @override
  String trashRestored(String title) {
    return '„$title“ wiederhergestellt';
  }

  @override
  String get trashPurged => 'Endgültig gelöscht';

  @override
  String get settingsData => 'Daten';

  @override
  String get backupSave => 'Sicherung speichern';

  @override
  String get backupSaveHint =>
      'Ganz Stowa in einer Datei: Elemente, Ordner, Tags, Regeln und Dateien. Der KI-Schlüssel ist nicht enthalten.';

  @override
  String get backupRestore => 'Aus Sicherung wiederherstellen';

  @override
  String backupRestoreAsk(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Elemente aus der Sicherung vom $date ersetzen alles, was du jetzt hast.',
      one:
          '$count Element aus der Sicherung vom $date ersetzt alles, was du jetzt hast.',
    );
    return '$_temp0';
  }

  @override
  String get backupReplace => 'Ersetzen';

  @override
  String get backupRestored => 'Aus Sicherung wiederhergestellt';

  @override
  String get backupNotStowa => 'Das ist keine Stowa-Sicherung';

  @override
  String get backupTooNew =>
      'Eine neuere Stowa hat die Sicherung erstellt. Aktualisiere die App';

  @override
  String get backupFailed => 'Die Sicherung ist fehlgeschlagen';

  @override
  String get folderNewBadge => 'neu';

  @override
  String get aiSortingNow => 'Sortiere…';

  @override
  String get aiLog => 'Anfrageprotokoll';

  @override
  String get aiLogEmpty => 'Noch keine Anfragen an den Anbieter';

  @override
  String get aiLogCluster => 'Neue Ordner aus „Ohne Ordner“';

  @override
  String get aiCheckTimeout => 'Das Modell hat nicht rechtzeitig geantwortet';

  @override
  String get tgTitle => 'Dein Telegram-Bot';

  @override
  String get tgNone => 'Nicht verbunden';

  @override
  String get tgHowTo =>
      '1. Öffne @BotFather in Telegram und sende /⁠newbot.\n2. Gib dem Bot einen Namen, BotFather schickt ein Token.\n3. Füge das Token hier ein.\n4. Schreib deinem Bot irgendwas: Ab dann hört er nur auf dich, und alles, was du ihm weiterleitest, landet in Stowa.';

  @override
  String get tgConnect => 'Verbinden';

  @override
  String tgOwner(String name) {
    return 'Hört nur auf $name';
  }

  @override
  String get tgWaitingOwner => 'Schreib dem Bot irgendwas, damit er dich kennt';

  @override
  String get tgOpenBot => 'Bot öffnen';

  @override
  String get tgDisconnect => 'Bot trennen';

  @override
  String get tgBadToken => 'Telegram hat das Token abgelehnt';

  @override
  String get tgOffline => 'Telegram nicht erreichbar';

  @override
  String tgPulled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten abgeholt',
      one: '$count Nachricht abgeholt',
    );
    return '$_temp0';
  }

  @override
  String get settingsOutside => 'Von außen';

  @override
  String selCount(int count) {
    return 'Ausgewählt: $count';
  }

  @override
  String get selClear => 'Auswahl aufheben';

  @override
  String get selAll => 'Alle auswählen';

  @override
  String get selMove => 'Verschieben';

  @override
  String get selTag => 'Tag';

  @override
  String get selUntag => 'Tag entfernen';

  @override
  String get selDelete => 'Löschen';

  @override
  String selMoved(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente nach „$folder“ verschoben',
      one: '$count Element nach „$folder“ verschoben',
    );
    return '$_temp0';
  }

  @override
  String selDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente gelöscht',
      one: '$count Element gelöscht',
    );
    return '$_temp0';
  }

  @override
  String selTagged(String tag) {
    return '#$tag gesetzt';
  }

  @override
  String selUntagged(String tag) {
    return '#$tag entfernt';
  }

  @override
  String get tagPickTitle => 'Welcher Tag';

  @override
  String get folderCanvas => 'Leinwand';

  @override
  String get canvasFit => 'Alles einpassen';

  @override
  String get canvasNote => 'Notiz';

  @override
  String get canvasNoteHint => 'Was auf die Leinwand soll';

  @override
  String get graphTitle => 'Verknüpfungsgraph';

  @override
  String get graphEmpty =>
      'Noch keine Verknüpfungen. Sie entstehen, wenn Elemente gemeinsame Wörter haben oder die KI sie verbindet.';

  @override
  String get graphFailed => 'Der Graph wurde nicht erstellt';

  @override
  String copyPartlyFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien nicht gespeichert: Die App gab keinen Zugriff',
      one: '$count Datei nicht gespeichert: Die App gab keinen Zugriff',
    );
    return '$_temp0';
  }

  @override
  String get mapTitle => 'Karte';

  @override
  String get mapEmpty =>
      'Noch nichts hat einen Ort. Neue Notizen merken sich, wo du sie gespeichert hast, und erscheinen hier.';

  @override
  String get mapWhereAmI => 'Wo bin ich';

  @override
  String get mapPlaceUnnamed => 'Ort ohne Namen';

  @override
  String get placeSetting => 'Merken, wo gespeichert wurde';

  @override
  String get placeSettingHint =>
      'Der Ort wird nach dem Speichern ergänzt und erscheint auf der Seite und auf der Karte. Koordinaten bleiben auf dem Handy, nur die Straßenname-Abfrage geht raus.';

  @override
  String panelLooking(Object what) {
    return 'Suche: $what';
  }

  @override
  String get foundAtPlace => 'nach Ort';

  @override
  String fileSaving(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien werden gespeichert',
      one: '$count Datei wird gespeichert',
    );
    return '$_temp0';
  }

  @override
  String get fileSavingHint =>
      'Du kannst die App schließen, die Datei wird von selbst fertig. Ist der Balken weg, kann das Original gelöscht werden.';

  @override
  String get foundInFile => 'in der Datei';

  @override
  String get foundOnPage => 'auf der Seite';

  @override
  String get foundInPhotoInfo => 'in den Fotodaten';

  @override
  String documentSheet(Object name) {
    return 'Blatt „$name“';
  }

  @override
  String documentSlide(Object number) {
    return 'Folie $number';
  }

  @override
  String documentChapter(Object number) {
    return 'Kapitel $number';
  }

  @override
  String get factCall => 'Anrufen';

  @override
  String get factWrite => 'Schreiben';

  @override
  String get factCopy => 'Kopieren';

  @override
  String photoTaken(Object date) {
    return 'Aufgenommen am $date';
  }

  @override
  String foundInSubtitles(Object time) {
    return 'in Untertiteln · $time';
  }

  @override
  String foundInChapters(Object time) {
    return 'in Kapiteln · $time';
  }

  @override
  String get foundInIngredients => 'in den Zutaten';

  @override
  String get foundAtAddress => 'nach Adresse';

  @override
  String get foundInHashtags => 'in Hashtags';

  @override
  String get watchFromHere => 'Ab hier ansehen';

  @override
  String get pageRecipe => 'Rezept';

  @override
  String get pageProduct => 'Produkt';

  @override
  String get pageEvent => 'Veranstaltung';

  @override
  String get pagePlace => 'Ort';

  @override
  String get pageMovie => 'Film';

  @override
  String get pageBook => 'Buch';

  @override
  String get pageVideo => 'Video';

  @override
  String get pageArticle => 'Artikel';

  @override
  String minutesShort(Object count) {
    return '$count Min.';
  }

  @override
  String servings(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Portionen',
      one: '$count Portion',
    );
    return '$_temp0';
  }

  @override
  String readingMinutes(Object count) {
    return '$count Min. Lesezeit';
  }

  @override
  String get inStock => 'Auf Lager';

  @override
  String get outOfStock => 'Nicht auf Lager';

  @override
  String get toShoppingList => 'Auf die Einkaufsliste';

  @override
  String shoppingFor(Object name) {
    return 'Kaufen: $name';
  }

  @override
  String get shoppingReady => 'Einkaufsliste ist fertig';

  @override
  String get chaptersTitle => 'Kapitel';

  @override
  String get authorTags => 'Tags des Autors';

  @override
  String get pageSeries => 'Serie';

  @override
  String get pageComic => 'Comic';

  @override
  String get adultSetting => '18+ anzeigen';

  @override
  String get adultSettingHint =>
      'Seiten, die sich selbst als 18+ kennzeichnen, und bekannte Seiten für Erwachsene. Solange das aus ist, sind ihre Cover unscharf und die Beschreibungen verborgen. Eintrag und Suche bleiben.';

  @override
  String get adultHidden =>
      'Beschreibung verborgen: 18+. In den Einstellungen einschaltbar.';

  @override
  String get vaultSetupTitle => 'Wo deine Notizen liegen';

  @override
  String get vaultSetupHint =>
      'Notizen, Fotos und Dateien liegen als normale Dateien in einem Ordner. Du siehst ihn im Dateimanager, Obsidian öffnet ihn, Syncthing gleicht ihn ab.';

  @override
  String get vaultCreate => 'Tresor anlegen';

  @override
  String get vaultCreateHint =>
      'Ein neuer Ordner im Telefonspeicher. Die Notizen bleiben, auch wenn du die App löschst.';

  @override
  String get vaultCreateButton => 'Anlegen';

  @override
  String get vaultOpen => 'Ordner als Tresor öffnen';

  @override
  String get vaultOpenHint =>
      'Dein alter Stowa-Tresor nach einer Neuinstallation oder ein Obsidian-Tresor.';

  @override
  String get vaultOpenButton => 'Öffnen';

  @override
  String get vaultInApp => 'In der App behalten';

  @override
  String get vaultInAppHint =>
      'Ohne Berechtigungen. Löschst du die App, sind die Notizen weg.';

  @override
  String get vaultInAppButton => 'Wählen';

  @override
  String get vaultInAppWarning =>
      'Die Notizen liegen in der App und sind weg, wenn du sie löschst. In einen normalen Ordner verschieben kannst du sie später in den Einstellungen.';

  @override
  String get vaultInAppConfirm => 'In der App';

  @override
  String get vaultName => 'Name des Tresors';

  @override
  String get vaultPlace => 'Ort';

  @override
  String get vaultAccessTitle => 'Dateizugriff nötig';

  @override
  String get vaultAccessHint =>
      'Für Notizen in einem normalen Ordner fragt Android nach „Zugriff auf alle Dateien“. Stowa liest und schreibt nur den Tresor-Ordner.';

  @override
  String get vaultAccessGrant => 'Einstellungen öffnen';

  @override
  String get vaultAccessDenied =>
      'Ohne Dateizugriff funktioniert ein Tresor im Telefonspeicher nicht';

  @override
  String vaultMoving(int done, int total) {
    return 'Verschiebe: $done von $total';
  }

  @override
  String vaultBuilding(int done, int total) {
    return 'Baue den Index: $done von $total';
  }

  @override
  String vaultMoveFailed(int count) {
    return 'Nicht alles wurde verschoben, es fehlen: $count. Die Notizen bleiben am alten Ort.';
  }

  @override
  String get vaultMissingTitle => 'Tresor nicht gefunden';

  @override
  String vaultMissingHint(String path) {
    return 'Der Ordner $path fehlt oder Stowa hat keinen Dateizugriff mehr. Die Notizen in der App sind sicher.';
  }

  @override
  String get vaultGrantAccess => 'Zugriff erlauben';

  @override
  String get vaultChooseAgain => 'Ordner wählen';

  @override
  String get vaultSection => 'Tresor';

  @override
  String get vaultFolder => 'Ordner';

  @override
  String get vaultInsideApp => 'In der App';

  @override
  String get vaultMoveTo => 'In anderen Ordner verschieben';

  @override
  String get vaultRebuild => 'Index neu aufbauen';

  @override
  String get vaultSettingHint =>
      'Notizen sind .md-Dateien: Obsidian öffnet diesen Ordner, Syncthing gleicht ihn ab. Der Index ist eine Suchdatenbank, die die App selbst baut.';

  @override
  String get vaultMoved => 'Tresor verschoben';

  @override
  String get vaultRebuilt => 'Index neu aufgebaut';

  @override
  String vaultSyncing(int done, int total) {
    return 'Notizen synchronisieren $done von $total';
  }

  @override
  String repeatIn(String folder, String date) {
    return 'Dieselbe liegt seit $date im Ordner „$folder“';
  }

  @override
  String repeatNoFolder(String date) {
    return 'Dieselbe liegt seit $date ohne Ordner';
  }

  @override
  String get settingsImport => 'Import';

  @override
  String get importTelegram => 'Aus Telegram';

  @override
  String get importTelegramHint =>
      'Wähle den Exportordner der „Gespeicherten Nachrichten“ aus Telegram Desktop, HTML oder JSON. Notizen behalten ihr Datum, ein Album wird zu einer Notiz.';

  @override
  String importProgress(int done, int total) {
    return 'Übertrage $done von $total';
  }

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen übertragen',
      one: '$count Notiz übertragen',
    );
    return '$_temp0';
  }

  @override
  String importRepeated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count waren schon da',
      one: '$count war schon da',
    );
    return '$_temp0';
  }

  @override
  String get importNotTelegram =>
      'In diesem Ordner liegt kein Telegram-Export: messages.html oder result.json fehlt';

  @override
  String importMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien fehlen im Export',
      one: '$count Datei fehlt im Export',
    );
    return '$_temp0 — Dateien in den Exporteinstellungen einschalten und erneut übertragen';
  }

  @override
  String importFilled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frühere Notizen haben ihre Dateien bekommen',
      one: '$count frühere Notiz hat ihre Dateien bekommen',
    );
    return '$_temp0';
  }

  @override
  String get returnChannel => 'Erinnerungen an Gespeichertes';

  @override
  String get returnWatchTitle => 'Später ansehen';

  @override
  String returnVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Videos',
      one: '$count Video',
    );
    return '$_temp0';
  }

  @override
  String returnArticles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artikel',
      one: '$count Artikel',
    );
    return '$_temp0';
  }

  @override
  String returnMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Minuten',
      one: '$count Minute',
    );
    return '$_temp0';
  }

  @override
  String returnAnd(String first, String second) {
    return '$first und $second';
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
      other: 'Vor $count Jahren',
      one: 'Vor einem Jahr',
    );
    return '$_temp0';
  }

  @override
  String get returnMonthAgo => 'Vor einem Monat';

  @override
  String get returnWeekAgo => 'Vor einer Woche';

  @override
  String returnDayOne(String title) {
    return '„$title“';
  }

  @override
  String returnDayMore(String title, int count) {
    return '„$title“ und $count weitere';
  }

  @override
  String get returnOnThisDay => 'An diesem Tag';

  @override
  String get returnWeekTitle => 'Deine Woche in Stowa';

  @override
  String returnWeekSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen diese Woche',
      one: '$count Notiz diese Woche',
    );
    return '$_temp0';
  }

  @override
  String returnWeekUnopened(int count) {
    return '$count ungeöffnet';
  }

  @override
  String returnWeekUnsorted(int count) {
    return '$count ohne Ordner';
  }

  @override
  String get returnWeekUnopenedTitle => 'Noch nicht geöffnet';

  @override
  String get returnWeekUnsortedTitle => 'Ohne Ordner';

  @override
  String returnShopTitle(String shop) {
    return 'Bei $shop';
  }

  @override
  String returnShopMore(String items, int count) {
    return '$items und $count weitere';
  }

  @override
  String get returnShopping => 'Einkaufen';

  @override
  String get settingsReturns => 'Zurückbringen';

  @override
  String get returnWeekSetting => 'Wochenrückblick';

  @override
  String get returnShoppingSetting => 'Einkäufe am Laden';

  @override
  String get returnEveningRow => 'Abends um';

  @override
  String get returnQuietRow => 'Ruhezeit';

  @override
  String get returnWeekDayRow => 'Tag des Rückblicks';

  @override
  String get returnSettingsHint =>
      'Höchstens eine Benachrichtigung am Tag, lautlos, und nichts in der Ruhezeit. Eigene Erinnerungen nach Zeit und Ort zählen nicht mit.';

  @override
  String returnRange(String from, String to) {
    return '$from–$to';
  }

  @override
  String get returnQuietFrom => 'Ruhe ab';

  @override
  String get returnQuietTo => 'Ruhe bis';

  @override
  String get returnWatchEmpty =>
      'Die Liste ist leer: alles Neue ist schon angesehen.';

  @override
  String get returnDayEmpty => 'An diesem Tag wurde früher nichts gespeichert.';

  @override
  String get returnWeekEmpty => 'Diese Woche wurde nichts gespeichert.';

  @override
  String get returnShoppingEmpty => 'Nichts zu kaufen: alle Listen abgehakt.';

  @override
  String returnMinutesShort(int count) {
    return '$count Min.';
  }

  @override
  String get returnsAskTitle => 'Gespeichertes zurückbringen?';

  @override
  String get returnsAskBody =>
      'Abends eine lautlose Benachrichtigung: was du ansehen wolltest, was du vor einem Jahr an diesem Tag gespeichert hast, ein Wochenrückblick. Höchstens einmal am Tag.';

  @override
  String get returnsAskOn => 'Einschalten';

  @override
  String get returnsAskLater => 'Nicht jetzt';

  @override
  String get placeRemindHome => 'Zu Hause erinnern';

  @override
  String get placeRemindWork => 'Auf der Arbeit erinnern';

  @override
  String get placeRemindHere => 'Hier erinnern';

  @override
  String get placeRemindShop => 'Im Laden erinnern';

  @override
  String placeRemindAt(String place) {
    return 'Erinnern: $place';
  }

  @override
  String get composerRemovePlace => 'Keine Ortserinnerung';

  @override
  String get placesTitle => 'Orte';

  @override
  String get placesHome => 'Zuhause';

  @override
  String get placesWork => 'Arbeit';

  @override
  String get placesShops => 'Läden';

  @override
  String get placesNotSet => 'Nicht festgelegt';

  @override
  String placesWifi(String name) {
    return 'WLAN: $name';
  }

  @override
  String get placesImHome => 'Ich bin gerade zu Hause';

  @override
  String get placesImWork => 'Ich bin gerade auf der Arbeit';

  @override
  String get placesImShop => 'Ich bin im Laden — merken';

  @override
  String placesGuessHome(String name) {
    return 'Sieht aus, als wäre zu Hause $name';
  }

  @override
  String placesGuessWork(String name) {
    return 'Sieht aus, als wäre die Arbeit $name';
  }

  @override
  String get placesRemove => 'Entfernen';

  @override
  String get placesShopName => 'Name des Ladens';

  @override
  String get placesSave => 'Speichern';

  @override
  String get placesNoFix =>
      'Dein Standort ließ sich nicht bestimmen. Prüfe, ob der Standort an und für Stowa erlaubt ist.';

  @override
  String get placesPermissionTitle => 'Standort „immer“ wird gebraucht';

  @override
  String get placesPermissionBody =>
      'Android weckt Stowa am richtigen Ort und zeigt den WLAN-Namen nur, wenn der Standort „immer“ erlaubt ist. Die Koordinaten bleiben auf dem Handy.';

  @override
  String get placesPermissionAllow => 'Erlauben';

  @override
  String get placesHint =>
      'Orte braucht es für „erinnere mich zu Hause“, „auf der Arbeit“ und „im Laden“. Notizen mit dem Tag #kaufen tauchen an gespeicherten Läden auf, höchstens einmal am Tag.';

  @override
  String placesShopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Läden',
      one: '$count Laden',
    );
    return '$_temp0';
  }

  @override
  String get itemRemindTime => 'Zu einer Zeit';

  @override
  String get itemPlaceChange => 'Anderer Ort';

  @override
  String get placesMissingHome =>
      'Zuhause ist noch nicht festgelegt: Stowa erinnert dich, sobald du es unter Orte festlegst';

  @override
  String get placesMissingWork =>
      'Die Arbeit ist noch nicht festgelegt: Stowa erinnert dich, sobald du sie unter Orte festlegst';

  @override
  String get placesMissingShop =>
      'Noch keine Läden: lege mindestens einen unter Orte fest';

  @override
  String get placeChannel => 'Ortserinnerungen';

  @override
  String get remindPlaceNeedsAlways =>
      'Ich erinnere dich vor Ort, wenn der Standort „immer“ erlaubt ist';

  @override
  String get lookColor => 'Farbe';

  @override
  String homeFoldersMore(Object count) {
    return '$count weitere';
  }

  @override
  String homeChecksMore(Object count) {
    return '$count weitere';
  }

  @override
  String get catalogTitle => 'Katalog';

  @override
  String get catalogExpand => 'Alle aufklappen';

  @override
  String get catalogCollapse => 'Alle zuklappen';

  @override
  String get catalogOpenFolder => 'Ordner öffnen';

  @override
  String foldersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ordner',
      one: '$count Ordner',
    );
    return '$_temp0';
  }

  @override
  String readerOpen(Object count) {
    return 'Lesen · $count Min.';
  }

  @override
  String get readerOriginal => 'Original';

  @override
  String get readerQuote => 'Zitat';

  @override
  String get readerCopy => 'Kopieren';

  @override
  String get readerNote => 'Notiz';

  @override
  String get readerNoteHint => 'Notiz zum Zitat';

  @override
  String get readerRemove => 'Entfernen';

  @override
  String get readerRemoved => 'Zitat entfernt';

  @override
  String get readerGone => 'Original gelöscht · Kopie gespeichert';

  @override
  String get readerNoCopy =>
      'Der Artikeltext wurde nicht gespeichert. Du kannst ihn auf der Website öffnen.';

  @override
  String get readerImageOff => 'Bild nicht gespeichert';

  @override
  String get highlightsTitle => 'Zitate';

  @override
  String get linkGone => 'Link öffnet nicht mehr';

  @override
  String get deadLinksTitle => 'Tote Links';

  @override
  String get deadLinksAbout =>
      'Einmal pro Woche prüft Stowa über WLAN deine gespeicherten Links. Hier landen Seiten, die die Website gelöscht hat.';

  @override
  String get deadLinksEmpty => 'Alle Links funktionieren';

  @override
  String get deadLinksCheck => 'Jetzt prüfen';

  @override
  String get deadLinksChecking => 'Prüfe Links…';

  @override
  String get deadLinksKeep => 'Behalten';

  @override
  String get deadLinksDelete => 'Löschen';

  @override
  String get deadLinksDeleted => 'Notiz im Papierkorb';

  @override
  String deadLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count öffnen nicht',
      one: '$count öffnet nicht',
    );
    return '$_temp0';
  }

  @override
  String get settingsArticles => 'Artikel';

  @override
  String get articleImages => 'Bilder in Artikeln';

  @override
  String get articleImagesAbout =>
      'Über WLAN laden, um Artikel mit Bildern offline zu lesen';

  @override
  String get foundInArticle => 'im Artikel';

  @override
  String get foundInQuote => 'in einem Zitat';

  @override
  String get settingsStart => 'Beim Start';

  @override
  String get startOpen => 'Öffnen';

  @override
  String get startHome => 'Startseite';

  @override
  String get startLast => 'Letzte Notiz';

  @override
  String get startRandom => 'Zufällige Notiz';

  @override
  String get startHint =>
      'Letzte: dort weitermachen, wo du aufgehört hast. Zufällig: Jeder Start erinnert an etwas Gespeichertes, so bleibt es besser hängen.';

  @override
  String get appearanceTitle => 'Darstellung';

  @override
  String get appearanceTheme => 'Design';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeSystem => 'Wie im System';

  @override
  String get themeByTime => 'Nach Tageszeit';

  @override
  String get themeByTimeHint => 'Dunkel von 20:00 bis 7:00';

  @override
  String get appearanceColor => 'Farbe';

  @override
  String get colorGraphite => 'Graphit';

  @override
  String get colorCustom => 'Eigene Farbe';

  @override
  String get colorFromWallpaper => 'Vom Hintergrund';

  @override
  String get colorIntensity => 'Intensität';

  @override
  String get intensityVibrant => 'Kräftig';

  @override
  String get intensityFaithful => 'Genau';

  @override
  String get intensityHint =>
      '„Kräftig“ färbt auch den Hintergrund leicht. „Genau“ lässt ihn grau und färbt Knöpfe exakt in deiner Farbe.';

  @override
  String get wallpaperColors => 'Farben vom Hintergrund';

  @override
  String get wallpaperColorsHint => 'Die Farbe folgt dem Hintergrundbild';

  @override
  String get amoledTitle => 'Schwarzer Hintergrund';

  @override
  String get amoledHint => 'Reines Schwarz für AMOLED, spart Akku';

  @override
  String get pickerApply => 'Fertig';
}
