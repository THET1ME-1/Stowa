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
  String get reasonNone => 'noch ohne Ordner, ich sortiere später';

  @override
  String get reasonAsIs => 'unsorted, as asked';

  @override
  String get actionStow => 'Ablegen';

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
  String get cmdRemind => 'erinnern';

  @override
  String get cmdTask => 'aufgabe';

  @override
  String get cmdList => 'liste';

  @override
  String get cmdFind => 'finden';

  @override
  String get cmdInbox => 'eingang';

  @override
  String get cmdRemindHint => 'Sag wann: „morgen um 10“, „am Fr“';

  @override
  String get cmdTaskHint => 'Wird mit Häkchen gespeichert';

  @override
  String get cmdListHint => 'Jede Zeile oder jedes Komma wird ein Punkt';

  @override
  String get cmdFindHint => 'Nur suchen, nichts speichern';

  @override
  String get cmdInboxHint => 'So lassen, wie es ist, unsortiert';

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
  String get voiceFold => 'Aufnahme minimieren';

  @override
  String get voiceUnfold => 'Aufnahme öffnen';

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
      other: '$count ähnliche Notizen einsortiert',
      one: '$count ähnliche Notiz einsortiert',
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
      'Füge deinen eigenen Schlüssel hinzu, dann sortieren sich Notizen ohne Ordner selbst.';

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
      other: '$count Notizen warten',
      one: '$count Notiz wartet',
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
      'Den Schlüssel gibt es beim Anbieter: bei OpenRouter unter Keys, dort gibt es auch kostenlose Modelle.';

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
      'Adresse einer OpenAI-kompatiblen API, leer heißt OpenRouter.';

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
          '$count Notizen werden endgültig gelöscht. Das lässt sich nicht rückgängig machen.',
      one:
          '$count Notiz wird endgültig gelöscht. Das lässt sich nicht rückgängig machen.',
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
      'Alle Notizen, Ordner und Dateien in einer Datei, ohne den KI-Schlüssel.';

  @override
  String get backupRestore => 'Aus Sicherung wiederherstellen';

  @override
  String backupRestoreAsk(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Notizen aus der Sicherung vom $date ersetzen alles, was du jetzt hast.',
      one:
          '$count Notiz aus der Sicherung vom $date ersetzt alles, was du jetzt hast.',
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
      other: '$count Notizen nach „$folder“ verschoben',
      one: '$count Notiz nach „$folder“ verschoben',
    );
    return '$_temp0';
  }

  @override
  String selDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen gelöscht',
      one: '$count Notiz gelöscht',
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
      'Noch keine Verknüpfungen. Sie entstehen, wenn Notizen gemeinsame Wörter haben oder die KI sie verbindet.';

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
      'Der Ort erscheint in der Notiz und auf der Karte, nach außen geht nur die Abfrage des Straßennamens.';

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
      'Du kannst die App schließen und das Original löschen, sobald der Balken weg ist.';

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
      'Solange das aus ist, bleiben Cover und Beschreibungen von 18+-Seiten verborgen.';

  @override
  String get adultHidden =>
      'Beschreibung verborgen: 18+. In den Einstellungen einschaltbar.';

  @override
  String get vaultSetupTitle => 'Wo deine Notizen liegen';

  @override
  String get vaultSetupHint =>
      'Unsicher? Tippe auf „Erstellen“: Das ist ein normaler Ordner auf dem Handy.';

  @override
  String get vaultCreate => 'Tresor anlegen';

  @override
  String get vaultCreateHint =>
      'Ein neuer Ordner im Telefonspeicher: Die Notizen bleiben, auch wenn du die App löschst.';

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
      'Ohne Berechtigungen, aber löschst du die App, sind die Notizen weg.';

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
      'Für Notizen in einem normalen Ordner fragt Android nach „Zugriff auf alle Dateien“, Stowa nutzt aber nur den eigenen Ordner.';

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
      'Notizen sind normale .md-Dateien, die auch Obsidian öffnet.';

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
      'Wähle den Exportordner der „Gespeicherten Nachrichten“ aus Telegram Desktop.';

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
  String get settingsReturns => 'Benachrichtigungen';

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
      'Höchstens eine lautlose Benachrichtigung am Tag.';

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
      'Eine lautlose Benachrichtigung am Abend erinnert an Gespeichertes.';

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
      'Erinnerungen an einem Ort klappen nur, wenn der Standort „immer“ erlaubt ist.';

  @override
  String get placesPermissionAllow => 'Erlauben';

  @override
  String get placesHint =>
      'Schreib „erinnere mich in der Apotheke“, und Stowa erinnert dich dort.';

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
      'Einmal pro Woche prüft Stowa deine Links und sammelt hier Seiten, die die Website gelöscht hat.';

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
      'Die letzte Notiz macht dort weiter, wo du aufgehört hast, eine zufällige erinnert an Gespeichertes.';

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
      '„Kräftig“ färbt auch den Hintergrund, „Genau“ lässt ihn grau.';

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

  @override
  String get colorCoral => 'Koralle';

  @override
  String get colorAmber => 'Bernstein';

  @override
  String get colorLime => 'Limette';

  @override
  String get colorMint => 'Minze';

  @override
  String get colorTeal => 'Türkis';

  @override
  String get colorBlue => 'Blau';

  @override
  String get colorViolet => 'Violett';

  @override
  String get colorRose => 'Rosé';

  @override
  String get folderNewInside => 'Neuer Ordner darin';

  @override
  String get folderMoveTo => 'Verschieben nach…';

  @override
  String get folderMoveTop => 'Nach oben';

  @override
  String get folderMoveNone =>
      'Kein Ziel: Ordner lassen sich höchstens drei Ebenen tief verschachteln';

  @override
  String get historyTitle => 'Verlauf';

  @override
  String get historyNow => 'Jetzt';

  @override
  String get historyHint =>
      'Der frühere Text bleibt erhalten, wenn du die Notiz nach einer Pause bearbeitest.';

  @override
  String get historyNoChanges => 'Gleicher Text';

  @override
  String get historyText => 'Text';

  @override
  String get historyDiff => 'Unterschiede';

  @override
  String get historyDiffHint =>
      'Durchgestrichen: stand in dieser Version. Hervorgehoben: kam danach dazu';

  @override
  String get historyRestore => 'Diese Version wiederherstellen';

  @override
  String get historyRestored => 'Version wiederhergestellt';

  @override
  String get sortByColor => 'Nach Farbe';

  @override
  String qrWifi(String network) {
    return 'WLAN „$network“';
  }

  @override
  String get qrCopyPassword => 'WLAN-Passwort kopieren';

  @override
  String get qrPasswordCopied => 'Passwort kopiert';

  @override
  String get qrOpenLink => 'Link aus dem QR-Code öffnen';

  @override
  String get qrCopyText => 'Text des QR-Codes kopieren';

  @override
  String get foundInQr => 'im QR-Code';

  @override
  String documentPage(String number) {
    return 'S. $number';
  }

  @override
  String get titleDateSetting => 'Namen von Fotos und Videos';

  @override
  String get titleDateShot => 'Nach Aufnahmedatum';

  @override
  String get titleDateSaved => 'Nach Speicherdatum';

  @override
  String get titleDateHint =>
      'Fotos und Videos ohne Beschriftung bekommen ein Datum im Namen.';

  @override
  String get factPassword => 'Passwort ••••••';

  @override
  String factPasswordFor(String network) {
    return 'WLAN „$network“ ••••••';
  }

  @override
  String get factCopyPassword => 'Passwort kopieren';

  @override
  String factCard(String last) {
    return 'Karte ••$last';
  }

  @override
  String get factCopyCard => 'Kartennummer kopieren';

  @override
  String factPromo(String code) {
    return 'Code $code';
  }

  @override
  String get factCopyPromo => 'Code kopieren';

  @override
  String get factTrack => 'Sendung verfolgen';

  @override
  String get factOnMap => 'In Karten öffnen';

  @override
  String get workEndRow => 'Arbeit bis';

  @override
  String get toChecklist => 'Als Einkaufsliste';

  @override
  String get toChecklistHint => 'Punkte zum Abhaken';

  @override
  String get toChecklistDone => 'Einkaufsliste fertig';

  @override
  String folderTotal(String sum) {
    return 'Gesamt $sum';
  }

  @override
  String get smartSave => 'Intelligenter Ordner';

  @override
  String smartSaved(String name) {
    return 'Intelligenter Ordner „$name“ ist auf dem Startbildschirm';
  }

  @override
  String get smartEmpty => 'Noch passt nichts zu dieser Suche';

  @override
  String get smartDelete => 'Intelligenten Ordner löschen';

  @override
  String smartDeleted(String name) {
    return 'Ordner „$name“ gelöscht, Notizen bleiben';
  }

  @override
  String suggestSite(int count, String site) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Links',
      one: '$count Link',
    );
    return '$_temp0 von $site ohne Ordner';
  }

  @override
  String suggestScreenshots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Screenshots',
      one: '$count Screenshot',
    );
    return '$_temp0 ohne Ordner';
  }

  @override
  String suggestVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Videos',
      one: '$count Video',
    );
    return '$_temp0 ohne Ordner';
  }

  @override
  String suggestFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien',
      one: '$count Datei',
    );
    return '$_temp0 ohne Ordner';
  }

  @override
  String suggestVoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sprachnotizen',
      one: '$count Sprachnotiz',
    );
    return '$_temp0 ohne Ordner';
  }

  @override
  String suggestSiteBody(String name) {
    return 'Ordner „$name“ anlegen? Neue Links von dieser Seite landen dort von selbst.';
  }

  @override
  String suggestBody(String name) {
    return 'Ordner „$name“ anlegen und sie dorthin verschieben?';
  }

  @override
  String get suggestYes => 'Anlegen';

  @override
  String get suggestNo => 'Nein danke';

  @override
  String suggestDone(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen',
      one: '$count Notiz',
    );
    return 'Ordner „$name“: $_temp0';
  }

  @override
  String get suggestScreenshotsName => 'Screenshots';

  @override
  String get suggestVideosName => 'Videos';

  @override
  String get suggestFilesName => 'Dateien';

  @override
  String get suggestVoicesName => 'Sprachnotizen';

  @override
  String get ruleIfPage => 'Seite ist';

  @override
  String get ruleIfPriceAbove => 'Preis über';

  @override
  String get ruleIfPriceBelow => 'Preis unter';

  @override
  String get ruleValuePrice => 'Betrag, z. B. 1000';

  @override
  String rulePriceAboveValue(String value) {
    return 'über $value';
  }

  @override
  String rulePriceBelowValue(String value) {
    return 'unter $value';
  }

  @override
  String get ruleThenRemind => 'erinnern';

  @override
  String get remindHourBefore => 'eine Stunde vorher';

  @override
  String get remindDayBefore => 'einen Tag vorher';

  @override
  String get remindWeekBefore => 'eine Woche vorher';

  @override
  String codeWait(Object seconds) {
    return 'Bitte $seconds s warten';
  }

  @override
  String get codeFingerprint => 'Fingerabdruck';

  @override
  String get codeErase => 'Löschen';

  @override
  String get codeDone => 'Fertig';

  @override
  String get codeWrong => 'Falscher Code';

  @override
  String get codeCreateTitle => 'Code festlegen';

  @override
  String get codeRepeatTitle => 'Code wiederholen';

  @override
  String get codeCreateHint =>
      '6 bis 12 Ziffern: Wenn du den Code vergisst, sind versteckte Notizen für immer verloren.';

  @override
  String get codeMismatch =>
      'Die Codes stimmen nicht überein, bitte neu festlegen';

  @override
  String get hiddenOpenReason => 'Versteckte Ordner öffnen';

  @override
  String get hiddenOpenTitle => 'Code für versteckte Ordner';

  @override
  String get codeForgot => 'Code vergessen';

  @override
  String get codeOldTitle => 'Aktueller Code';

  @override
  String get codeNewTitle => 'Neuer Code';

  @override
  String get codeChanged => 'Code geändert';

  @override
  String get codeForgetTitle => 'Code entfernen?';

  @override
  String get codeForgetText =>
      'Die Sperre geht aus, versteckte Ordner werden samt Notizen gelöscht. Zurückholen lassen sie sich nicht.';

  @override
  String get codeForgetAction => 'Code entfernen und Verstecktes löschen';

  @override
  String folderHidden(Object name) {
    return 'Ordner „$name“ ist versteckt';
  }

  @override
  String folderUnhidden(Object name) {
    return 'Ordner „$name“ ist wieder sichtbar';
  }

  @override
  String get lockReason => 'Stowa entsperren';

  @override
  String get lockTitle => 'Code eingeben';

  @override
  String get codeEnterTitle => 'Code eingeben';

  @override
  String get closeAfterNow => 'Sofort';

  @override
  String get closeAfterMinute => 'Nach 1 Minute';

  @override
  String closeAfterMinutes(Object minutes) {
    return 'Nach $minutes Minuten';
  }

  @override
  String get privacySection => 'Privatsphäre';

  @override
  String get codeCreateRow => 'Code festlegen';

  @override
  String get appLockRow => 'Code beim Öffnen';

  @override
  String get fingerprintRow => 'Fingerabdruck';

  @override
  String get closeAfterRow => 'Wieder sperren';

  @override
  String get hiddenCloseRow => 'Versteckte Ordner schließen';

  @override
  String get hiddenOpenRow => 'Versteckte Ordner öffnen';

  @override
  String get codeChangeRow => 'Code ändern';

  @override
  String get privacyHint =>
      'Versteckte Ordner sind verschlüsselt und ohne Code nicht lesbar.';

  @override
  String get markdownExport => 'Als Markdown exportieren';

  @override
  String get markdownNoVault => 'Wähle zuerst einen Tresor-Ordner';

  @override
  String get markdownHiddenAsk => 'Versteckte Ordner mit exportieren?';

  @override
  String get markdownHiddenHint =>
      'Versteckte Notizen werden zu normalen Dateien. Wer diesen Ordner hat, kann sie lesen.';

  @override
  String get markdownWithoutHidden => 'Ohne versteckte';

  @override
  String get markdownWithHidden => 'Mit versteckten';

  @override
  String markdownDone(Object path) {
    return 'Exportiert nach $path';
  }

  @override
  String get markdownFailed => 'In diesen Ordner ließ sich nicht schreiben';

  @override
  String get folderUnhide => 'Nicht mehr verstecken';

  @override
  String get folderHide => 'Ordner verstecken';

  @override
  String get folderHiddenMark => 'versteckt';

  @override
  String get hiddenFolders => 'Versteckte Ordner';

  @override
  String get hiddenReminder => 'Erinnerung aus einem versteckten Ordner';

  @override
  String get aiFirst => 'KI hat Vorrang';

  @override
  String get aiFirstHint =>
      'Das Modell prüft auch, was ohne es sortiert wurde.';

  @override
  String get composerHintNoSearch => 'Wirf irgendwas rein';

  @override
  String get returnsOff => 'Aus';

  @override
  String get crashSetting => 'Fehlerberichte';

  @override
  String get crashSettingHint =>
      'Der Entwickler erhält den Fehler und das Telefonmodell, aber keine Notizen oder Dateinamen.';

  @override
  String get vaultInFiles => 'Dateien → Stowa';

  @override
  String get vaultFilesHint =>
      'Notizen sind einfache .md-Dateien, die du in der App „Dateien“ siehst.';

  @override
  String get itemDateChange => 'Datum ändern';

  @override
  String get itemDateNow => 'Jetzt';

  @override
  String get itemDatePick => 'Tag und Uhrzeit wählen';

  @override
  String get itemDateChanged => 'Datum geändert';

  @override
  String get propertiesTitle => 'Eigenschaften';

  @override
  String propertiesMore(Object count) {
    return '$count weitere';
  }

  @override
  String get propertiesLess => 'Einklappen';

  @override
  String get propertyAdd => 'Eigenschaft hinzufügen';

  @override
  String get propertyNew => 'Neue Eigenschaft';

  @override
  String get propertyEdit => 'Eigenschaft';

  @override
  String get propertyNameHint => 'Name';

  @override
  String get propertyValueHint => 'Wert';

  @override
  String get propertyListHint => 'Ein Eintrag pro Zeile';

  @override
  String get propertyKindText => 'Text';

  @override
  String get propertyKindList => 'Liste';

  @override
  String get propertyKindNumber => 'Zahl';

  @override
  String get propertyKindCheckbox => 'Kontrollkästchen';

  @override
  String get propertyKindDate => 'Datum';

  @override
  String get propertyNameTaken => 'Diese Eigenschaft gibt es schon';

  @override
  String get propertyNumberWrong => 'Hier gehört eine Zahl hin';

  @override
  String get propertyDatePick => 'Tag wählen';

  @override
  String get propertyDelete => 'Eigenschaft löschen';

  @override
  String get propertyRemoved => 'Eigenschaft gelöscht';

  @override
  String get propertyOtherHint =>
      'Dieser Wert lässt sich in der Notizdatei ändern.';

  @override
  String get propertyYes => 'Ja';

  @override
  String get propertyNo => 'Nein';

  @override
  String get lookSuggested => 'Passend zum Namen';

  @override
  String get lookPopular => 'Häufig';

  @override
  String get lookAll => 'Alle Symbole';

  @override
  String get iconsNone => 'Kein passendes Symbol, versuch ein anderes Wort.';

  @override
  String get placeKindHome => 'Zuhause';

  @override
  String get placeKindWork => 'Arbeit';

  @override
  String get placeKindStudy => 'Studium';

  @override
  String get placeKindShop => 'Laden';

  @override
  String get placeKindPharmacy => 'Apotheke';

  @override
  String get placeKindFood => 'Cafés und Restaurants';

  @override
  String get placeKindSport => 'Sport';

  @override
  String get placeKindGuests => 'Freunde und Familie';

  @override
  String get placeKindOther => 'Sonstiges';

  @override
  String get placeRemindStudy => 'Beim Studium erinnern';

  @override
  String get placeRemindPharmacy => 'An der Apotheke erinnern';

  @override
  String get placeRemindFood => 'Im Café erinnern';

  @override
  String get placeRemindSport => 'Im Fitnessstudio erinnern';

  @override
  String get placeRemindGuests => 'Beim Besuch erinnern';

  @override
  String get placeRemindOther => 'Am Ort erinnern';

  @override
  String placeRemindDay(String place, String day) {
    return '$place · $day';
  }

  @override
  String get dayToday => 'heute';

  @override
  String get dayTomorrow => 'morgen';

  @override
  String get placesMissingKind =>
      'Diesen Ort gibt es noch nicht: Ich erinnere dich, sobald du ihn unter Orte hinzufügst';

  @override
  String get placesAdd => 'Ort hinzufügen';

  @override
  String get placesEmpty =>
      'Noch keine Orte: Füge Zuhause, Arbeit, dein Lieblingscafé oder einen Freund hinzu.';

  @override
  String get placeNewTitle => 'Neuer Ort';

  @override
  String get placeEditTitle => 'Ort';

  @override
  String get placeNameHint => 'Name: Uni, Sascha, Andy’s';

  @override
  String get placeKindTitle => 'Was ist das';

  @override
  String get placeWhereTitle => 'Wo';

  @override
  String get placeHereNow => 'Ich bin gerade hier';

  @override
  String get placeMapHint =>
      'Verschiebe die Karte: Der Ort ist dort, wo der Punkt in der Mitte ist.';

  @override
  String get placeKindMore => 'Suchen oder neu';

  @override
  String get placeKindSearchHint => 'Art suchen oder eigene benennen';

  @override
  String placeKindCreate(String name) {
    return '„$name“ anlegen';
  }

  @override
  String get placeIcon => 'Symbol';

  @override
  String get lineLanguageHint =>
      'Uhrzeiten in Worten verstehe ich in dieser Sprache nicht — schreib Ziffern: 14:30';

  @override
  String get lineLanguageHide => 'Ausblenden';

  @override
  String get placeSearchHint => 'Adresse oder Ort suchen';

  @override
  String get placeSearchNone => 'Nichts gefunden';

  @override
  String get placeMapEmpty =>
      'Adresse suchen oder Karte gedrückt halten, um den Punkt zu setzen';

  @override
  String get placeMapMove =>
      'Karte gedrückt halten, um den Punkt zu verschieben';

  @override
  String get placePointMoved => 'Punkt verschoben';

  @override
  String get placeNoPoint => 'Noch kein Punkt';

  @override
  String get placeKindOwn => 'Eigene Art';

  @override
  String placeRadiusValue(int meters) {
    return '$meters m';
  }

  @override
  String get placeRadiusTitle => 'Erinnerungsradius';

  @override
  String get relatedInText => 'im Text der Notiz';

  @override
  String get relatedBacklink => 'verweist hierher';

  @override
  String get relatedManual => 'von dir verknüpft';

  @override
  String relatedAi(String reason) {
    return 'KI: $reason';
  }

  @override
  String get relatedAiPlain => 'von der KI verknüpft';

  @override
  String get relatedUnlink => 'Verknüpfung entfernen';

  @override
  String get relatedUnlinked => 'Verknüpfung entfernt';

  @override
  String get linkAdd => 'Mit Notiz verknüpfen';

  @override
  String get linkAddShort => 'Link';

  @override
  String get linkSearchHint => 'Notiz nach Wörtern suchen';

  @override
  String get linkNone => 'Keine solche Notiz';

  @override
  String linkAdded(String title) {
    return 'Mit „$title“ verknüpft';
  }

  @override
  String linkMissing(String title) {
    return 'Keine Notiz „$title“';
  }

  @override
  String get settingsCatalog => 'Speicher';

  @override
  String get settingsLook => 'Aussehen';

  @override
  String get settingsHelpers => 'Sortieren und Mitteilungen';

  @override
  String get settingsCopies => 'Sicherungen';

  @override
  String get vaultsSection => 'Tresore';

  @override
  String get vaultOpenNow => 'Offen';

  @override
  String get vaultAdd => 'Tresor hinzufügen';

  @override
  String get vaultAddNew => 'Neu anlegen';

  @override
  String get vaultAddNewHint => 'Ein leerer Ordner für neue Notizen';

  @override
  String get vaultAddOpen => 'Ordner öffnen';

  @override
  String get vaultAddOpenHint =>
      'Ein früherer Stowa-Tresor oder ein Obsidian-Tresor';

  @override
  String get vaultsHint =>
      'Tippe auf einen anderen Tresor, um ihn zu öffnen; Erinnerungen kommen nur aus dem offenen.';

  @override
  String get vaultFolderGone => 'Ordner nicht gefunden';

  @override
  String get vaultForget => 'Aus der Liste entfernen';

  @override
  String get vaultForgetHint => 'Die Dateien bleiben im Ordner';

  @override
  String get vaultForgotten =>
      'Tresor aus der Liste entfernt, die Dateien sind noch da';

  @override
  String get vaultOpenIt => 'Öffnen';

  @override
  String get vaultAlreadyOpen => 'Dieser Tresor ist schon offen';

  @override
  String get vaultHasNotes => 'In diesem Ordner liegen schon Notizen';

  @override
  String get vaultOpenSeparately => 'Als eigenen Tresor öffnen';

  @override
  String get vaultOpenSeparatelyHint => 'Der jetzige bleibt in der Liste';

  @override
  String get vaultMergeHere => 'Hierher verschieben und zusammenführen';

  @override
  String get vaultMergeHereHint => 'Die Notizen beider landen in einem Ordner';

  @override
  String vaultSwitching(String name) {
    return 'Öffne „$name“';
  }

  @override
  String get vaultChangeFolder => 'Ordner wechseln';

  @override
  String vaultAllCount(int count) {
    return 'Alle Tresore · $count';
  }

  @override
  String get syncTitle => 'Stowa Sync';

  @override
  String get syncPaid => 'Kostenpflichtig';

  @override
  String get syncSoon => 'Bald';

  @override
  String get syncAbout =>
      'Deine Notizen gleichen sich von selbst auf Handy, Tablet und Computer ab.';

  @override
  String get syncLater => 'Das Abo kommt mit einem der nächsten Updates.';

  @override
  String get syncOk => 'Verstanden';

  @override
  String get itemPin => 'Anheften';

  @override
  String get itemUnpin => 'Lösen';

  @override
  String get itemPinned => 'Oben auf der Startseite angeheftet';

  @override
  String get itemUnpinned => 'Gelöst';

  @override
  String get homePinned => 'Angeheftet';

  @override
  String homePinnedMore(Object count) {
    return '$count weitere';
  }

  @override
  String get homePinnedLess => 'Weniger';

  @override
  String get catalogReorderHint =>
      'Halte einen Ordner gedrückt und zieh ihn: In dieser Reihenfolge stehen die Ordner auch auf der Startseite.';

  @override
  String linkCreate(Object title) {
    return 'Notiz „$title“ anlegen';
  }

  @override
  String get linkCreateAction => 'Anlegen';

  @override
  String homeMoreLines(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'noch $count Zeilen',
      one: 'noch $count Zeile',
    );
    return '$_temp0';
  }

  @override
  String get edgeTitle => 'Griffbereit';

  @override
  String get edgeSwitch => 'Rücken am Rand';

  @override
  String get edgeSwitchHint =>
      'Angeheftete Notizen warten am Bildschirmrand, ein Tippen öffnet sie über jeder App.';

  @override
  String get edgePlace => 'Wo';

  @override
  String get edgeLook => 'Aussehen und Ort';

  @override
  String get edgeDragHint =>
      'Zieh die Rücken auf dem Handy nach oben oder unten.';

  @override
  String get edgeLeft => 'Links';

  @override
  String get edgeRight => 'Rechts';

  @override
  String get edgeHeight => 'Höhe am Bildschirm';

  @override
  String get edgeHigher => 'weiter oben';

  @override
  String get edgeMiddle => 'mittig';

  @override
  String get edgeLower => 'weiter unten';

  @override
  String get edgeSize => 'Größe';

  @override
  String get edgeThin => 'schmal';

  @override
  String get edgeNormal => 'normal';

  @override
  String get edgeLarge => 'groß';

  @override
  String get edgeAlpha => 'Sichtbarkeit';

  @override
  String get edgeHideVideo => 'Bei Vollbildvideo ausblenden';

  @override
  String get edgeHideVideoHint =>
      'Solange ein Video oder Spiel im Vollbild läuft, stören die Rücken nicht.';

  @override
  String get edgeOff => 'Aus';

  @override
  String get edgeRecent => 'Zuletzt';

  @override
  String get edgeOpenApp => 'Stowa öffnen';

  @override
  String get edgeStick => 'Als Sticker anheften';

  @override
  String get edgeSpinesSetup => 'Rücken einrichten';

  @override
  String get edgeUnstick => 'Sticker entfernen';

  @override
  String get edgeNearby => 'In der Nähe';

  @override
  String get suggestPaste => 'Aus der Zwischenablage einfügen';

  @override
  String get edgeGestures => 'Gesten';

  @override
  String get edgeGestureSwipe => 'Nach unten wischen zum Schreiben';

  @override
  String get edgeGestureSwipeHint =>
      'Die Zeile öffnet sich gleich mit Tastatur.';

  @override
  String get edgeGestureHold => 'Halten für eine Sprachnotiz';

  @override
  String get edgeGestureHoldHint =>
      'Die Aufnahme läuft auch ohne Finger weiter, bis du auf Speichern tippst.';

  @override
  String get edgeGestureDouble => 'Doppeltippen für die letzte Notiz';

  @override
  String get edgeGestureDoubleHint =>
      'Einmal tippen reagiert dann etwas später.';

  @override
  String get edgeVoiceChannel => 'Sprachaufnahme';

  @override
  String get edgeVoiceNow => 'Sprachnotiz wird aufgenommen';

  @override
  String get importSummary =>
      'Telegram, Google Keep, Lesezeichen, Obsidian, mymind';

  @override
  String get importKeep => 'Aus Google Keep';

  @override
  String get importBookmarks => 'Browser-Lesezeichen';

  @override
  String get importObsidian => 'Aus Obsidian';

  @override
  String get importMymind => 'Aus mymind';

  @override
  String get importScreenHint =>
      'Entpacke den Export auf dem Handy und wähle seinen Ordner, für Lesezeichen die .html-Datei.';

  @override
  String get importNotKeep =>
      'In diesem Ordner sind keine Google-Keep-Notizen: wähle den Keep-Ordner aus Google Takeout';

  @override
  String get importNotBookmarks =>
      'Das ist keine Lesezeichendatei: exportiere die Lesezeichen aus dem Browser als .html';

  @override
  String get importNotObsidian => 'In diesem Ordner sind keine .md-Notizen';

  @override
  String get importNotMymind =>
      'In diesem Ordner ist keine cards.csv aus mymind';

  @override
  String importFilesNotFound(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien nicht gefunden',
      one: '$count Datei nicht gefunden',
    );
    return '$_temp0';
  }

  @override
  String get settingsPrivacyPolicy => 'Datenschutzerklärung';

  @override
  String get settingsHelp => 'Hilfe';

  @override
  String get feedbackRow => 'Problem melden';

  @override
  String get feedbackRowHint => 'Fehler, Idee oder Frage direkt von hier';

  @override
  String get supportRow => 'Support anschreiben';

  @override
  String get feedbackKindBug => 'Fehler';

  @override
  String get feedbackKindIdea => 'Idee';

  @override
  String get feedbackKindQuestion => 'Frage';

  @override
  String get feedbackField =>
      'Was passiert ist und was du kurz davor gemacht hast';

  @override
  String get feedbackAttach => 'App-Version und Handymodell anhängen';

  @override
  String get feedbackSend => 'Senden';

  @override
  String get feedbackHint =>
      'Die Nachricht kommt bei uns an. Hinterlass eine E-Mail, wenn du eine Antwort willst.';

  @override
  String get feedbackEmail => 'E-Mail für eine Antwort, falls gewünscht';

  @override
  String get feedbackSentTitle => 'Gesendet, danke';

  @override
  String feedbackSentReply(String email) {
    return 'Wir antworten an $email.';
  }

  @override
  String get feedbackSentQuiet =>
      'Du hast keine E-Mail hinterlassen, also können wir nicht antworten, aber wir lesen es.';

  @override
  String get feedbackAgain => 'Noch eine schreiben';

  @override
  String get feedbackFailed =>
      'Nicht gesendet. Prüfe die Verbindung und tippe noch einmal.';

  @override
  String get feedbackTooMany =>
      'Heute schon zu viele Nachrichten von diesem Handy. Versuch es morgen oder per E-Mail aus den Einstellungen.';

  @override
  String get feedbackBadEmail =>
      'Die E-Mail sieht falsch aus, prüf die Adresse.';

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
  String get canvasDefaultName => 'Canvas';

  @override
  String get baseDefaultName => 'Base';

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
  String get documentNew => 'Canvas oder Base';

  @override
  String get kindDrawing => 'Zeichnung';

  @override
  String get kindsDrawing => 'Zeichnungen';

  @override
  String get drawingTexts => 'Text der Zeichnung';

  @override
  String get drawingTextCopied => 'Text kopiert';

  @override
  String get drawingEditInObsidian =>
      'Bearbeiten lässt sich die Zeichnung in Obsidian';

  @override
  String get drawingUnreadable =>
      'Die Zeichnung ließ sich nicht lesen, öffne sie in Obsidian';

  @override
  String drawingTextCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Beschriftungen',
      one: '$count Beschriftung',
    );
    return '$_temp0';
  }

  @override
  String get cmdCanvas => 'leinwand';

  @override
  String get cmdBase => 'basis';

  @override
  String get cmdCanvasHint =>
      'Neue Leinwand mit diesem Namen, öffnet sich sofort';

  @override
  String get cmdBaseHint =>
      'Neue Basis mit den Notizen des Ordners, öffnet sich sofort';

  @override
  String get baseSort => 'Sortieren';

  @override
  String get baseGroup => 'Gruppieren';

  @override
  String get baseFilter => 'Filter';

  @override
  String get baseProperties => 'Eigenschaften';

  @override
  String get baseSearch => 'Suchen';

  @override
  String get baseSearchHint => 'In der Basis suchen';

  @override
  String get baseCreate => 'Neu';

  @override
  String baseShown(int shown, int total) {
    return '$shown von $total angezeigt';
  }

  @override
  String get baseSortAdd => 'Sortierung hinzufügen';

  @override
  String get baseAscending => 'Aufsteigend';

  @override
  String get baseDescending => 'Absteigend';

  @override
  String get baseGroupNone => 'Keine Gruppierung';

  @override
  String get baseFilterAll => 'Alle Ansichten';

  @override
  String get baseFilterThis => 'Diese Ansicht';

  @override
  String get baseFilterEmpty =>
      'Keine Bedingungen, alle Notizen sind sichtbar.';

  @override
  String get baseJoinAll => 'Alle Bedingungen';

  @override
  String get baseJoinAny => 'Eine der Bedingungen';

  @override
  String get baseJoinNone => 'Keine der Bedingungen';

  @override
  String get baseFilterAdd => 'Bedingung hinzufügen';

  @override
  String get baseFilterAddGroup => 'Gruppe hinzufügen';

  @override
  String get baseMoveToAll => 'In alle Ansichten verschieben';

  @override
  String get baseMoveToThis => 'In diese Ansicht verschieben';

  @override
  String get baseExpression => 'Ausdruck';

  @override
  String get baseValue => 'Wert';

  @override
  String get baseOpIs => 'ist';

  @override
  String get baseOpIsNot => 'ist nicht';

  @override
  String get baseOpContains => 'enthält';

  @override
  String get baseOpNotContains => 'enthält nicht';

  @override
  String get baseOpStarts => 'beginnt mit';

  @override
  String get baseOpEnds => 'endet mit';

  @override
  String get baseOpEmpty => 'ist leer';

  @override
  String get baseOpNotEmpty => 'ist nicht leer';

  @override
  String get baseOpGreater => 'größer als';

  @override
  String get baseOpAtLeast => 'mindestens';

  @override
  String get baseOpLess => 'kleiner als';

  @override
  String get baseOpAtMost => 'höchstens';

  @override
  String get baseOpHasTag => 'hat Tag';

  @override
  String get baseOpNotHasTag => 'hat Tag nicht';

  @override
  String get baseOpInFolder => 'liegt im Ordner';

  @override
  String get baseOpNotInFolder => 'liegt nicht im Ordner';

  @override
  String get baseOpHasLink => 'verlinkt auf';

  @override
  String get baseFormulaAdd => 'Formel hinzufügen';

  @override
  String get baseFormulaName => 'Name';

  @override
  String baseFormulaError(String what) {
    return 'Nicht verstanden: $what';
  }

  @override
  String get baseFormulaEdit => 'Formel bearbeiten';

  @override
  String get baseFormulaDelete => 'Formel löschen';

  @override
  String get baseRename => 'Umbenennen';

  @override
  String get baseRemove => 'Entfernen';

  @override
  String get baseColumnHide => 'Spalte ausblenden';

  @override
  String get baseShownProps => 'Angezeigt';

  @override
  String get baseOtherProps => 'Weitere Eigenschaften';

  @override
  String get baseSummary => 'Zusammenfassung';

  @override
  String get baseSummaryNone => 'Keine Zusammenfassung';

  @override
  String get baseSumAverage => 'Durchschnitt';

  @override
  String get baseSumMedian => 'Median';

  @override
  String get baseSumMin => 'Minimum';

  @override
  String get baseSumMax => 'Maximum';

  @override
  String get baseSumSum => 'Summe';

  @override
  String get baseSumRange => 'Spanne';

  @override
  String get baseSumStddev => 'Abweichung';

  @override
  String get baseSumEarliest => 'Früheste';

  @override
  String get baseSumLatest => 'Späteste';

  @override
  String get baseSumChecked => 'Angehakt';

  @override
  String get baseSumUnchecked => 'Nicht angehakt';

  @override
  String get baseSumEmpty => 'Leer';

  @override
  String get baseSumFilled => 'Ausgefüllt';

  @override
  String get baseSumUnique => 'Verschiedene';

  @override
  String get baseViewAdd => 'Ansicht hinzufügen';

  @override
  String get baseViewLayout => 'Layout';

  @override
  String get baseViewCopy => 'Ansicht kopieren';

  @override
  String get baseViewDelete => 'Ansicht löschen';

  @override
  String get baseViewSettings => 'Ansicht einstellen';

  @override
  String get baseLayoutTable => 'Tabelle';

  @override
  String get baseLayoutCards => 'Karten';

  @override
  String get baseLayoutList => 'Liste';

  @override
  String get baseLayoutKanban => 'Board';

  @override
  String get baseLayoutMap => 'Karte';

  @override
  String get baseLimit => 'Wie viele anzeigen';

  @override
  String get baseLimitNone => 'Alle';

  @override
  String get baseImage => 'Bild aus Eigenschaft';

  @override
  String get baseImageNone => 'Kein Bild';

  @override
  String get baseCardSize => 'Kartengröße';

  @override
  String get baseImageRatio => 'Bildformat';

  @override
  String get baseImageFitCover => 'Zuschneiden';

  @override
  String get baseImageFitContain => 'Ganz zeigen';

  @override
  String get baseKanbanNeedsGroup =>
      'Wähle unter „Gruppieren“ eine Eigenschaft für die Spalten.';

  @override
  String get baseUntitled => 'Ohne Titel';

  @override
  String get baseColExt => 'Dateityp';

  @override
  String get baseSectionNotes => 'Eigenschaften der Notizen';

  @override
  String get baseSectionFile => 'Datei';

  @override
  String get folderCreateInside => 'Darin erstellen';

  @override
  String get folderTileFolder => 'Ordner';

  @override
  String get folderTileCanvas => 'Canvas';

  @override
  String get folderTileBase => 'Base';

  @override
  String get folderEdit => 'Name und Aussehen';

  @override
  String get startStow => 'Schreib irgendwas und tippe auf „Ablegen“.';

  @override
  String get startSearch =>
      'Dieselbe Zeile sucht: Tippe ein Wort aus deiner Notiz.';

  @override
  String get startRemind => 'Eine Uhrzeit im Text ist schon eine Erinnerung.';

  @override
  String get startFolder =>
      'Das Zeichen @ legt die Notiz in einen Ordner, neu oder vorhanden.';

  @override
  String get startTag =>
      'Das Zeichen # setzt ein Schlagwort, über das man die Notiz leicht findet.';

  @override
  String get startCommands =>
      'Das Zeichen / öffnet Befehle: Liste, Aufgabe, Canvas.';

  @override
  String get startFinish =>
      'Die Einführung ist vorbei, du kannst sie in den Einstellungen zurückholen.';

  @override
  String get startTry => 'Ausprobieren';

  @override
  String get startSkip => 'Überspringen';

  @override
  String get startRemindExample => 'Mama morgen um 10 anrufen';

  @override
  String get startFolderExample => '@Einkauf ';

  @override
  String get startTagExample => '#idee ';

  @override
  String get lineExplainTag => 'Tippe ein Wort: #idee, #arbeit';

  @override
  String get lineExplainFolder =>
      'Tippe einen Namen: gibt es ihn, wähle ich ihn, sonst lege ich ihn an';

  @override
  String get tipNoteBar =>
      'Unten: erinnern, Schlagwort, anderer Ordner und teilen.';

  @override
  String get tipLongPress =>
      'Halte eine Notiz gedrückt: anheften, verschieben oder löschen.';

  @override
  String get tipCatalog =>
      'Halte einen Ordner gedrückt und zieh ihn, um die Reihenfolge zu ändern.';

  @override
  String get tipFolderMenu =>
      'Die drei Punkte oben: Ordner darin, Canvas, Base, Name und Farbe.';

  @override
  String get tipSort =>
      '„Sortieren“ zeigt die Notizen einzeln, und du legst jede in einen Ordner.';

  @override
  String get tipCanvas =>
      'Tippe zweimal auf eine leere Stelle, um eine Karte hinzuzufügen.';

  @override
  String get tipBase =>
      'Symbole oben: Sortierung, Gruppe, Filter, Spalten, Suche.';

  @override
  String get tipAiKey =>
      'Den Schlüssel bekommst du bei einem KI-Anbieter, openrouter.ai hat kostenlose Modelle.';

  @override
  String get tipEdge =>
      'Rücken sind schmale Laschen am Bildschirmrand, zieh sie nach innen.';

  @override
  String get tipClose => 'Verstanden';

  @override
  String get hintsToggle => 'Tipps';

  @override
  String get hintsRestart => 'Einführung neu starten';

  @override
  String get hintsRestarted => 'Die Einführung beginnt auf dem Startbildschirm';

  @override
  String get attachmentsSection => 'Anhänge';

  @override
  String get attachmentsShared => 'In einem gemeinsamen Ordner';

  @override
  String get attachmentsNear => 'Neben der Notiz';

  @override
  String get attachmentsSub => 'In einem Unterordner neben der Notiz';

  @override
  String get attachmentsRoot => 'Im Hauptordner des Speichers';

  @override
  String get attachmentsHint =>
      'Gilt für neue Fotos und Dateien, alte bleiben, wo sie sind.';

  @override
  String get attachmentsWithObsidian => 'Dieselbe Einstellung wie in Obsidian';

  @override
  String get attachmentsNameLabel => 'Ordnername';

  @override
  String get attachmentsNameBad =>
      'Dieser Name geht nicht: kein Punkt am Anfang und kein „..“.';

  @override
  String get attachmentsObsidianBroken =>
      'Die Obsidian-Einstellungen sind nicht lesbar, die Auswahl wurde nicht gespeichert.';

  @override
  String get codeCopy => 'Code kopieren';

  @override
  String get codeCopied => 'Kopiert';

  @override
  String codeShowAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alles zeigen · $count Zeilen',
      one: 'Alles zeigen · $count Zeile',
    );
    return '$_temp0';
  }

  @override
  String get codeCollapse => 'Einklappen';

  @override
  String get mdMath => 'Formel';

  @override
  String get mdMathNext => 'Nächstes Formelfeld';

  @override
  String get settingsLine => 'Eingabefeld';

  @override
  String get enterKeyTitle => 'Eingabetaste';

  @override
  String get enterNewLine => 'Neue Zeile';

  @override
  String get enterStow => 'Notiz speichern';

  @override
  String get enterHint =>
      'Im Eingabefeld im Vollbild beginnt Enter immer eine neue Zeile.';

  @override
  String get noticePin => 'In Benachrichtigungen anheften';

  @override
  String get noticeUnpin => 'Aus Benachrichtigungen entfernen';

  @override
  String get noticePinned => 'Notiz in Benachrichtigungen angeheftet';

  @override
  String get noticeUnpinned => 'Notiz aus Benachrichtigungen entfernt';

  @override
  String get noticeChannel => 'Angeheftete Notizen';

  @override
  String get noticeRemove => 'Entfernen';

  @override
  String get noticeHiddenTitle => 'Angeheftete Notiz';

  @override
  String get syncOff => 'Aus';

  @override
  String get syncIntro =>
      'Deine Notizen bleiben auf dem Handy und im Web gleich und werden schon vor dem Senden verschlüsselt.';

  @override
  String get syncEmail => 'E-Mail';

  @override
  String get syncGetCode => 'Code anfordern';

  @override
  String syncCodeSent(String email) {
    return 'Code an $email gesendet';
  }

  @override
  String get syncCode => 'Code aus der E-Mail';

  @override
  String get syncSignIn => 'Anmelden';

  @override
  String syncResendIn(int seconds) {
    return 'Erneut senden in $seconds s';
  }

  @override
  String get syncResend => 'Code erneut senden';

  @override
  String get syncOtherEmail => 'Andere E-Mail';

  @override
  String get syncWrongCode => 'Der Code ist falsch oder abgelaufen';

  @override
  String get syncMailFailed =>
      'Die E-Mail wurde nicht gesendet. Prüfe die Verbindung und versuch es noch einmal';

  @override
  String get syncNoServer => 'Server nicht erreichbar';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get syncRunning => 'Wird synchronisiert…';

  @override
  String syncLast(String time) {
    return 'Synchronisiert um $time';
  }

  @override
  String get syncInactive =>
      'Synchronisierung ist für dieses Konto nicht aktiv';

  @override
  String get syncMassDelete =>
      'Viele Dateien sind auf einmal verschwunden, deshalb wurden sie auf deinen anderen Geräten nicht gelöscht';

  @override
  String get syncVaultUnreadable => 'Tresorordner konnte nicht gelesen werden';

  @override
  String get syncOffline =>
      'Server nicht erreichbar. Die Synchronisierung läuft von selbst weiter';

  @override
  String get syncOtherVault => 'Ein anderer Tresor wird synchronisiert';

  @override
  String get syncNoVault => 'Wähle zuerst einen Tresorordner';

  @override
  String get syncSignOut => 'Abmelden';

  @override
  String get syncSignOutHint => 'Deine Notizen bleiben auf diesem Gerät.';

  @override
  String get syncStepFolder => 'Ordner';

  @override
  String get syncStepReceive => 'Empfang';

  @override
  String get syncStepSend => 'Senden';

  @override
  String get syncStepPlace => 'Notizen';

  @override
  String get syncDoingFolder => 'Ordner wird geprüft';

  @override
  String get syncDoingReceive => 'Empfange vom Server';

  @override
  String get syncDoingSend => 'Abgleichen und senden';

  @override
  String get syncDoingPlace => 'Notizen werden einsortiert';

  @override
  String syncOf(String done, String total) {
    return '$done von $total';
  }

  @override
  String syncOfMb(String done, String total) {
    return '$done von $total MB';
  }

  @override
  String syncOfGb(String done, String total) {
    return '$done von $total GB';
  }

  @override
  String syncPassReceived(int count) {
    return 'Empfangen: $count';
  }

  @override
  String syncPassSent(int count) {
    return 'Gesendet: $count';
  }

  @override
  String syncPassBoth(int received, int sent) {
    return 'Empfangen: $received, gesendet: $sent';
  }

  @override
  String get wsSections => 'Bereiche';

  @override
  String get wsHome => 'Start';

  @override
  String get wsFind => 'Suchen oder notieren';

  @override
  String get wsSplitRight => 'Rechts teilen';

  @override
  String get wsSplitDown => 'Unten teilen';

  @override
  String get wsCloseTab => 'Tab schließen';

  @override
  String get wsLeftDock => 'Linke Leiste';

  @override
  String get wsRightDock => 'Rechte Leiste';

  @override
  String get wsYearAgo => 'Vor einem Jahr';

  @override
  String get wsKeys => 'Tastenkürzel';

  @override
  String get wsTheme => 'Design wechseln';

  @override
  String get wsInBrowser => 'In diesem Browser';

  @override
  String get wsSynced => 'Synchronisiert';

  @override
  String get wsSyncOff => 'Synchronisierung aus';

  @override
  String get wsGroupNav => 'Suche und Navigation';

  @override
  String get wsGroupNotes => 'Notizen und Ordner';

  @override
  String get wsGroupTabs => 'Tabs und Fenster';

  @override
  String get wsGroupDocks => 'Leisten und Layouts';

  @override
  String get wsCmdPalette => 'Alle Befehle';

  @override
  String get wsCmdSwitch => 'Notiz nach Titel öffnen';

  @override
  String get wsCmdHome => 'Zum Start';

  @override
  String get wsCmdNew => 'Neue Notiz';

  @override
  String get wsCmdTrash => 'In den Papierkorb';

  @override
  String get wsCmdPin => 'Notiz anheften';

  @override
  String get wsCmdMove => 'In Ordner verschieben';

  @override
  String get wsCmdEdit => 'Notiz bearbeiten oder ansehen';

  @override
  String get wsCmdReopen => 'Geschlossenen Tab wiederherstellen';

  @override
  String get wsCmdNext => 'Nächster Tab';

  @override
  String get wsCmdPrev => 'Vorheriger Tab';

  @override
  String get wsCmdNextPane => 'Nächstes Fenster';

  @override
  String get wsCmdPrevPane => 'Vorheriges Fenster';

  @override
  String get wsCmdClosePane => 'Fenster schließen';

  @override
  String get wsCmdTheme => 'Helles oder dunkles Design';

  @override
  String get wsThen => 'dann';

  @override
  String get wsKeysHint =>
      'Eine einzelne Taste ohne Strg und Alt wirkt nur außerhalb eines Textfelds, und Tasten zählen nach ihrer Lage auf der Tastatur, in jedem Layout.';

  @override
  String get wsKeysResetAll => 'Alles zurücksetzen';

  @override
  String get wsKeysAdd => 'Kürzel hinzufügen';

  @override
  String get wsKeysPress => 'Kürzel drücken · Esc bricht ab';

  @override
  String wsKeysTaken(String name) {
    return 'Kürzel von „$name“ entfernt';
  }

  @override
  String get wsKeysBrowser => 'Dieses Kürzel behält der Browser für sich';

  @override
  String get wsKeysReset => 'Zurücksetzen';

  @override
  String get wsKeysRemove => 'Entfernen';

  @override
  String get wsChanged => 'geändert';

  @override
  String get wsPaletteHint => 'Befehl oder Notiztitel';

  @override
  String get wsOpenNoteFirst => 'Öffne zuerst eine Notiz';

  @override
  String get wsAddPanel => 'Leiste';

  @override
  String get wsToRight => 'In die rechte Leiste';

  @override
  String get wsToLeft => 'In die linke Leiste';

  @override
  String get wsHidePanel => 'Leiste entfernen';

  @override
  String get wsPanelEmpty => 'Noch leer';

  @override
  String get canvasDropHint =>
      'Loslassen — die Dateien landen auf der Leinwand';

  @override
  String get tabBusyTitle => 'Stowa ist bereits in einem anderen Tab geöffnet';

  @override
  String get tabBusyHint =>
      'Zwei Tabs gleichzeitig würden deine Notizen beschädigen, deshalb arbeitet nur einer.';

  @override
  String get tabBusyOpenHere => 'Hier öffnen';

  @override
  String get tabBusyWaiting => 'Der andere Tab schließt deine Notizen…';

  @override
  String backupMergeAsk(String date) {
    return 'Notizen aus der Kopie vom $date hinzufügen? Deine jetzigen bleiben, gleichnamige Dateien werden ersetzt.';
  }

  @override
  String get backupAdd => 'Hinzufügen';

  @override
  String get copyNudgeFirst =>
      'Deine Notizen liegen nur in diesem Browser: Speichere eine Kopie, damit sie nicht verloren gehen.';

  @override
  String get copyNudgeStale =>
      'Die Kopie deiner Notizen ist veraltet: Speichere eine neue.';

  @override
  String get copyNudgeLater => 'Später';

  @override
  String get storageWeak =>
      'Der Browser hat keinen verlässlichen Speicher bereitgestellt: Deine Notizen können beim Schließen des Tabs verschwinden.';

  @override
  String get vaultBrowserHint =>
      'Deine Notizen liegen im Speicher dieses Browsers und sind nicht als Dateien auf der Festplatte sichtbar.';

  @override
  String vaultBuildingFiles(int done, int total) {
    return 'Prüfe Dateien: $done von $total';
  }

  @override
  String vaultBuildingExtras(int done, int total) {
    return 'Index wird fertig: $done von $total';
  }

  @override
  String get wsEmptyTitle => 'Hier landen deine Notizen';

  @override
  String get wsEmptyBody =>
      'Wirf einen Gedanken, Link oder eine Datei in die Zeile unten, Stowa sortiert sie selbst in Ordner.';

  @override
  String get wsEmptyWrite => 'Erste Notiz schreiben';

  @override
  String get wsEmptyFolder => 'Ordner anlegen';

  @override
  String get wsEmptyRestore => 'Aus Sicherung holen';

  @override
  String get itemPropFolder => 'Ordner';

  @override
  String get itemPropTags => 'Tags';

  @override
  String get itemPropRemind => 'Erinnern';

  @override
  String get itemPropPlace => 'Ort';

  @override
  String get itemPropCreated => 'Erstellt';

  @override
  String get itemPropTaken => 'Aufgenommen';

  @override
  String get itemPropLinks => 'Verknüpfungen';

  @override
  String get itemWriteMore => 'Text ergänzen…';

  @override
  String get graphLoading => 'Verknüpfungen werden gelegt…';

  @override
  String folderSubAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ordner',
      one: '$count Ordner',
    );
    return 'Alle $_temp0';
  }

  @override
  String get folderSubLess => 'Weniger';

  @override
  String get itemPlaceAdd => 'Ort hinzufügen';

  @override
  String get itemPlaceAddShort => 'Ort';

  @override
  String get itemPlaceTitle => 'Ort der Notiz';

  @override
  String get itemPlaceShowMap => 'Auf der Karte zeigen';

  @override
  String get itemPlacePickMap => 'Auf der Karte wählen';

  @override
  String get itemPlaceRemove => 'Ort entfernen';

  @override
  String get itemPlaceRemoved => 'Ort entfernt';

  @override
  String get itemPlaceSetHere => 'Hierhin setzen';

  @override
  String get itemPlaceMapHint =>
      'Verschiebe die Karte, die Nadel markiert den Ort';

  @override
  String get placesNoFixBrowser =>
      'Dein Standort ließ sich nicht bestimmen. Prüfe, ob der Browser Stowa den Standort erlaubt.';

  @override
  String get rulesTab => 'Regeln';

  @override
  String get tagsIntro =>
      'Ein Etikett über Ordner hinweg: Schreib #Wort in die Zeile und finde diese Notizen aus jedem Ordner.';

  @override
  String get rulesIntro =>
      'Eine Regel sortiert neue Notizen selbst: Sie erkennt ein Tag, eine Website oder ein Wort und legt die Notiz in einen Ordner oder setzt ein Tag.';

  @override
  String get rulesWhenWorks =>
      'Regeln greifen bei neuen Notizen und lassen in Ruhe, was du selbst einsortiert hast.';

  @override
  String get rulesEmpty =>
      'Noch keine Regeln: Fang mit einem Beispiel unten an.';

  @override
  String get rulesExamples => 'Beispiele';

  @override
  String ruleWhenTag(String tag) {
    return 'Hat das Tag #$tag';
  }

  @override
  String ruleWhenSite(String site) {
    return 'Link von $site';
  }

  @override
  String ruleWhenWord(String word) {
    return 'Im Text steht „$word“';
  }

  @override
  String ruleWhenKind(String kind) {
    return 'Notizart: $kind';
  }

  @override
  String ruleWhenPage(String page) {
    return 'Seite: $page';
  }

  @override
  String ruleWhenPriceAbove(String value) {
    return 'Preis über $value';
  }

  @override
  String ruleWhenPriceBelow(String value) {
    return 'Preis unter $value';
  }

  @override
  String ruleDoFolder(String folder) {
    return 'in den Ordner „$folder“';
  }

  @override
  String ruleDoTag(String tag) {
    return 'Tag #$tag setzen';
  }

  @override
  String ruleDoRemind(String when) {
    return 'erinnern: $when';
  }

  @override
  String get ruleCondTag => 'Hat ein Tag';

  @override
  String get ruleCondTagHint => 'Du hast beim Schreiben ein #Tag gesetzt';

  @override
  String get ruleCondSite => 'Link von einer Website';

  @override
  String get ruleCondSiteHint => 'Zum Beispiel Videos von youtube.com';

  @override
  String get ruleCondWord => 'Wort im Text';

  @override
  String get ruleCondWordHint => 'Zum Beispiel „kaufen“ oder „Rezept“';

  @override
  String get ruleCondKind => 'Notizart';

  @override
  String get ruleCondKindHint => 'Foto, Video, Sprachnotiz, Datei oder Link';

  @override
  String get ruleCondPage => 'Seitentyp';

  @override
  String get ruleCondPageHint => 'Link zu Rezept, Produkt, Termin oder Film';

  @override
  String get ruleCondPriceAbove => 'Preis über';

  @override
  String get ruleCondPriceAboveHint => 'Die Notiz enthält einen höheren Betrag';

  @override
  String get ruleCondPriceBelow => 'Preis unter';

  @override
  String get ruleCondPriceBelowHint =>
      'Die Notiz enthält einen niedrigeren Betrag';

  @override
  String get ruleActFolder => 'In Ordner legen';

  @override
  String get ruleActFolderHint => 'Die Notiz landet direkt in diesem Ordner';

  @override
  String get ruleActTag => 'Tag setzen';

  @override
  String get ruleActTagHint => 'Die Notiz bekommt ein Tag';

  @override
  String get ruleActRemind => 'Vorher erinnern';

  @override
  String get ruleActRemindHint => 'Nur bei Terminen: vor Beginn';

  @override
  String get ruleStepWhen => 'Wenn';

  @override
  String get ruleStepDo => 'Dann';

  @override
  String get ruleFolderPick => 'Ordner wählen';

  @override
  String get ruleSaveButton => 'Regel speichern';

  @override
  String get ruleValueTagHint => 'zum Beispiel arbeit';

  @override
  String get ruleValueWordHint => 'zum Beispiel kaufen';

  @override
  String get ruleValueSiteHint => 'zum Beispiel youtube.com';

  @override
  String get ruleExampleVideoTag => 'video';

  @override
  String get ruleExampleBuyWord => 'kaufen';

  @override
  String get ruleExampleShoppingTag => 'einkauf';

  @override
  String get tagFolderRow => 'In Ordner legen';

  @override
  String get tagFolderNone => 'Nicht ablegen';

  @override
  String get tagFolderHint =>
      'Das ist eine Regel: Du siehst sie im Tab „Regeln“ und kannst sie dort ausschalten.';

  @override
  String get tagPinHint =>
      'Das Tag erscheint in der Reihe oben auf der Startseite';

  @override
  String numberPadRange(String min, String max) {
    return 'Von $min bis $max';
  }

  @override
  String get numberPadOpen => 'Zahl eingeben';

  @override
  String tagShowNotes(String tag) {
    return 'Notizen mit #$tag';
  }

  @override
  String get panelHint =>
      'Notizen und Suche laufen über deinen offenen Stowa-Tab.';

  @override
  String get panelEmpty =>
      'Schreib einen Gedanken oder such eine Notiz: Die Zeile kann beides.';

  @override
  String get panelLocked =>
      'Die Suche ist durch den Zugangscode gesperrt, schreiben geht.';

  @override
  String get panelOpened => 'Im Stowa-Tab geöffnet';

  @override
  String get panelSaved => 'Gerade gespeichert';

  @override
  String get panelWaiting => 'Warte auf den Stowa-Tab…';
}
