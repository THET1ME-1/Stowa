// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class LRo extends L {
  LRo([String locale = 'ro']) : super(locale);

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
      'poți adăuga descrierea și etichetele mai târziu';

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
  String get reasonNone => 'fără dosar, îl sortez când apare ceva similar';

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
  String get voiceSaved => 'Mesajul vocal a fost salvat';

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
  String get voiceNoTranscript => 'Fără transcriere';

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
  String get itemMore => 'Mai mult';

  @override
  String get itemAppend => 'Adaugă';

  @override
  String get itemShare => 'Distribuie';

  @override
  String get itemAutosave => 'Se salvează singur';

  @override
  String itemPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de fotografii',
      few: '$count fotografii',
      one: '$count fotografie',
    );
    return '$_temp0';
  }

  @override
  String get tagAddShort => 'Etichetă';

  @override
  String get itemOpenLink => 'Deschide';

  @override
  String get itemWatch => 'Vizionează';

  @override
  String get fileOpenFailed => 'Nicio aplicație nu poate deschide fișierul';

  @override
  String get linkOpenFailed => 'Linkul nu s-a deschis';

  @override
  String photoCounter(Object count, Object index) {
    return '$index din $count';
  }

  @override
  String get photoToGallery => 'În galerie';

  @override
  String get photoSaved => 'Salvat în galerie';

  @override
  String get photoSaveFailed => 'Nu s-a salvat: fără acces la galerie';

  @override
  String get photoClose => 'Închide';

  @override
  String get voiceSpeed => 'Viteză';

  @override
  String autoSorted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de elemente similare sortate',
      few: '$count elemente similare sortate',
      one: '$count element similar sortat',
    );
    return '$_temp0';
  }

  @override
  String get relatedTitle => 'Legate';

  @override
  String relatedWords(Object words) {
    return 'în comun: $words';
  }

  @override
  String relatedSite(Object site) {
    return 'același site, $site';
  }

  @override
  String get relatedHide => 'Nu sunt legate';

  @override
  String get relatedHidden => 'Nu le mai arăt împreună';

  @override
  String aiSortedInto(String folder) {
    return 'Pus în „$folder”';
  }

  @override
  String get aiOtherFolder => 'Alta';

  @override
  String get aiPausedAuth => 'Sortare oprită: cheia a fost respinsă';

  @override
  String get aiPausedPayment => 'Sortare oprită: cheia nu mai are credit';

  @override
  String get aiPausedAction => 'Verifică cheia';

  @override
  String get settingsTitle => 'Setări';

  @override
  String get settingsAi => 'Sortare AI';

  @override
  String get aiStateOff => 'Oprită';

  @override
  String get aiStateOffHint =>
      'Adaugă cheia ta și elementele fără dosar se sortează singure, cu etichete, titlu și descriere pentru căutare. Cheia rămâne pe acest telefon, cererile merg direct la furnizor.';

  @override
  String get aiStateOn => 'Pornită';

  @override
  String aiStateWait(String time) {
    return 'Furnizorul cere să aștepți până la $time';
  }

  @override
  String aiQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de elemente așteaptă',
      few: '$count elemente așteaptă',
      one: '$count element așteaptă',
    );
    return '$_temp0';
  }

  @override
  String get aiSortNow => 'Sortează acum';

  @override
  String get aiKey => 'Cheie';

  @override
  String get aiKeyNone => 'Nesetată';

  @override
  String get aiKeySet => 'Setată';

  @override
  String get aiKeyPaste => 'Lipește';

  @override
  String get aiKeySave => 'Salvează și verifică';

  @override
  String get aiKeyRemove => 'Șterge cheia';

  @override
  String get aiKeyWhere =>
      'Cheia o iei de la furnizor: pe OpenRouter, la Keys. Există modele gratuite.';

  @override
  String get aiCheckOk => 'Cheia funcționează';

  @override
  String get aiCheckAuth => 'Furnizorul a respins cheia';

  @override
  String get aiCheckPayment => 'Cheia nu are credit';

  @override
  String get aiCheckRate => 'Furnizorul cere să aștepți';

  @override
  String get aiCheckNetwork => 'Furnizorul nu răspunde';

  @override
  String get aiCheckServer => 'Furnizorul a răspuns cu o eroare';

  @override
  String get aiProvider => 'Furnizor';

  @override
  String get aiProviderHint =>
      'Adresa unui API compatibil OpenAI. Gol înseamnă OpenRouter.';

  @override
  String get aiSortModel => 'Model de sortare';

  @override
  String get aiSpeechModel => 'Transcriere vocală';

  @override
  String get aiSpeechOff => 'Oprită';

  @override
  String get aiModelsSearch => 'Caută un model';

  @override
  String get aiModelFree => 'gratuit';

  @override
  String get aiModelVision => 'vede poze';

  @override
  String get aiModelsNeedKey => 'Lista de modele apare după cheie';

  @override
  String get aiModelsFailed => 'Lista de modele nu s-a încărcat';

  @override
  String aiModelOwn(String name) {
    return 'Proprie: „$name”';
  }

  @override
  String get settingsOrder => 'Organizare';

  @override
  String get settingsLanguage => 'Limbă';

  @override
  String get languageSystem => 'Ca în sistem';

  @override
  String settingsVersion(String version) {
    return 'Stowa $version';
  }

  @override
  String get trashTitle => 'Coș';

  @override
  String get trashEmpty => 'Coșul e gol';

  @override
  String get trashHint =>
      'Ce ștergi stă aici 30 de zile, apoi se șterge cu tot cu fișiere.';

  @override
  String trashDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de zile rămase',
      few: '$count zile rămase',
      one: '$count zi rămasă',
    );
    return '$_temp0';
  }

  @override
  String trashFrom(String folder) {
    return 'din „$folder”';
  }

  @override
  String get trashPurge => 'Șterge definitiv';

  @override
  String get trashPurgeAll => 'Golește coșul';

  @override
  String trashPurgeAllAsk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de elemente se șterg definitiv. Nu se poate anula.',
      few: '$count elemente se șterg definitiv. Nu se poate anula.',
      one: '$count element se șterge definitiv. Nu se poate anula.',
    );
    return '$_temp0';
  }

  @override
  String trashRestored(String title) {
    return 'Am readus „$title”';
  }

  @override
  String get trashPurged => 'Șters definitiv';

  @override
  String get settingsData => 'Date';

  @override
  String get backupSave => 'Salvează o copie';

  @override
  String get backupSaveHint =>
      'Tot Stowa într-un fișier: elemente, dosare, etichete, reguli și fișiere. Cheia AI nu e inclusă.';

  @override
  String get backupRestore => 'Restaurează din copie';

  @override
  String backupRestoreAsk(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count de elemente din copia de la $date înlocuiesc tot ce ai acum.',
      few: '$count elemente din copia de la $date înlocuiesc tot ce ai acum.',
      one: '$count element din copia de la $date înlocuiește tot ce ai acum.',
    );
    return '$_temp0';
  }

  @override
  String get backupReplace => 'Înlocuiește';

  @override
  String get backupRestored => 'Restaurat din copie';

  @override
  String get backupNotStowa => 'Nu e o copie Stowa';

  @override
  String get backupTooNew =>
      'Copia e făcută de un Stowa mai nou. Actualizează aplicația';

  @override
  String get backupFailed => 'Copia nu a reușit';

  @override
  String get folderNewBadge => 'nou';

  @override
  String get aiSortingNow => 'Sortez…';

  @override
  String get aiLog => 'Jurnal cereri';

  @override
  String get aiLogEmpty => 'Încă nu au fost cereri către furnizor';

  @override
  String get aiLogCluster => 'Dosare noi din „Fără dosar”';

  @override
  String get aiCheckTimeout => 'Modelul nu a răspuns la timp';

  @override
  String get tgTitle => 'Botul tău Telegram';

  @override
  String get tgNone => 'Neconectat';

  @override
  String get tgHowTo =>
      '1. Deschide @BotFather în Telegram și trimite /⁠newbot.\n2. Dă-i un nume, BotFather îți trimite un token.\n3. Lipește tokenul aici.\n4. Scrie-i botului orice: de atunci ascultă doar de tine, iar ce îi trimiți ajunge în Stowa.';

  @override
  String get tgConnect => 'Conectează';

  @override
  String tgOwner(String name) {
    return 'Ascultă doar de $name';
  }

  @override
  String get tgWaitingOwner => 'Scrie-i botului orice ca să te țină minte';

  @override
  String get tgOpenBot => 'Deschide botul';

  @override
  String get tgDisconnect => 'Deconectează botul';

  @override
  String get tgBadToken => 'Telegram a respins tokenul';

  @override
  String get tgOffline => 'Telegram nu răspunde';

  @override
  String tgPulled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de mesaje preluate',
      few: '$count mesaje preluate',
      one: '$count mesaj preluat',
    );
    return '$_temp0';
  }

  @override
  String get settingsOutside => 'Din afară';

  @override
  String selCount(int count) {
    return 'Selectate: $count';
  }

  @override
  String get selClear => 'Anulează selecția';

  @override
  String get selAll => 'Selectează tot';

  @override
  String get selMove => 'Mută';

  @override
  String get selTag => 'Etichetă';

  @override
  String get selUntag => 'Scoate eticheta';

  @override
  String get selDelete => 'Șterge';

  @override
  String selMoved(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de elemente mutate în „$folder”',
      few: '$count elemente mutate în „$folder”',
      one: '$count element mutat în „$folder”',
    );
    return '$_temp0';
  }

  @override
  String selDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de elemente șterse',
      few: '$count elemente șterse',
      one: '$count element șters',
    );
    return '$_temp0';
  }

  @override
  String selTagged(String tag) {
    return 'Etichetat #$tag';
  }

  @override
  String selUntagged(String tag) {
    return 'Scos #$tag';
  }

  @override
  String get tagPickTitle => 'Ce etichetă';

  @override
  String get folderCanvas => 'Pânză';

  @override
  String get canvasFit => 'Încadrează tot';

  @override
  String get canvasNote => 'Notiță';

  @override
  String get canvasNoteHint => 'Ce să scrii pe pânză';

  @override
  String get graphTitle => 'Graful legăturilor';

  @override
  String get graphEmpty =>
      'Încă nu sunt legături. Apar când elementele au cuvinte comune sau AI le leagă.';

  @override
  String get graphFailed => 'Graful nu s-a construit';

  @override
  String copyPartlyFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de fișiere nu s-au salvat: aplicația nu a dat acces',
      few: '$count fișiere nu s-au salvat: aplicația nu a dat acces',
      one: '$count fișier nu s-a salvat: aplicația nu a dat acces',
    );
    return '$_temp0';
  }

  @override
  String get mapTitle => 'Hartă';

  @override
  String get mapEmpty =>
      'Încă nimic nu are loc. Notițele noi țin minte unde le-ai salvat și apar aici.';

  @override
  String get mapWhereAmI => 'Unde sunt';

  @override
  String get mapPlaceUnnamed => 'Loc fără nume';

  @override
  String get placeSetting => 'Ține minte unde a fost salvat';

  @override
  String get placeSettingHint =>
      'Locul se adaugă după salvare și apare pe pagina elementului și pe hartă. Coordonatele rămân pe telefon, iese doar cererea numelui străzii.';

  @override
  String panelLooking(Object what) {
    return 'Caut: $what';
  }

  @override
  String get foundAtPlace => 'după loc';

  @override
  String fileSaving(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fișiere se salvează',
      one: '$count fișier se salvează',
    );
    return '$_temp0';
  }

  @override
  String get fileSavingHint =>
      'Poți închide aplicația, fișierul se termină singur. Când bara dispare, originalul poate fi șters.';

  @override
  String get foundInFile => 'în fișier';

  @override
  String get foundOnPage => 'pe pagină';

  @override
  String get foundInPhotoInfo => 'în datele fotografiei';

  @override
  String documentSheet(Object name) {
    return 'foaia „$name”';
  }

  @override
  String documentSlide(Object number) {
    return 'diapozitivul $number';
  }

  @override
  String documentChapter(Object number) {
    return 'capitolul $number';
  }

  @override
  String get factCall => 'Sună';

  @override
  String get factWrite => 'Scrie';

  @override
  String get factCopy => 'Copiază';

  @override
  String photoTaken(Object date) {
    return 'Făcută pe $date';
  }

  @override
  String foundInSubtitles(Object time) {
    return 'în subtitrări · $time';
  }

  @override
  String foundInChapters(Object time) {
    return 'în capitole · $time';
  }

  @override
  String get foundInIngredients => 'în ingrediente';

  @override
  String get foundAtAddress => 'după adresă';

  @override
  String get foundInHashtags => 'în hashtaguri';

  @override
  String get watchFromHere => 'Vezi de aici';

  @override
  String get pageRecipe => 'rețetă';

  @override
  String get pageProduct => 'produs';

  @override
  String get pageEvent => 'eveniment';

  @override
  String get pagePlace => 'loc';

  @override
  String get pageMovie => 'film';

  @override
  String get pageBook => 'carte';

  @override
  String get pageVideo => 'video';

  @override
  String get pageArticle => 'articol';

  @override
  String minutesShort(Object count) {
    return '$count min';
  }

  @override
  String servings(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count porții',
      one: '$count porție',
    );
    return '$_temp0';
  }

  @override
  String readingMinutes(Object count) {
    return '$count min de citit';
  }

  @override
  String get inStock => 'În stoc';

  @override
  String get outOfStock => 'Stoc epuizat';

  @override
  String get toShoppingList => 'În lista de cumpărături';

  @override
  String shoppingFor(Object name) {
    return 'De cumpărat: $name';
  }

  @override
  String get shoppingReady => 'Lista de cumpărături e gata';

  @override
  String get chaptersTitle => 'Capitole';

  @override
  String get authorTags => 'Etichetele autorului';

  @override
  String get pageSeries => 'serial';

  @override
  String get pageComic => 'bandă desenată';

  @override
  String get adultSetting => 'Arată 18+';

  @override
  String get adultSettingHint =>
      'Paginile care se marchează singure ca 18+ și site-urile cunoscute pentru adulți. Cât timp e dezactivat, copertele lor sunt estompate, iar descrierile ascunse. Elementul și căutarea rămân.';

  @override
  String get adultHidden =>
      'Descriere ascunsă: 18+. Se poate activa în setări.';

  @override
  String get vaultSetupTitle => 'Unde păstrezi notițele';

  @override
  String get vaultSetupHint =>
      'Notițele, pozele și fișierele stau ca fișiere obișnuite într-un dosar. Îl vezi în managerul de fișiere, îl deschide Obsidian și îl sincronizează Syncthing.';

  @override
  String get vaultCreate => 'Creează un seif';

  @override
  String get vaultCreateHint =>
      'Un dosar nou în memoria telefonului. Notițele rămân chiar dacă ștergi aplicația.';

  @override
  String get vaultCreateButton => 'Creează';

  @override
  String get vaultOpen => 'Deschide un dosar ca seif';

  @override
  String get vaultOpenHint =>
      'Seiful Stowa de dinainte de reinstalare sau un seif Obsidian.';

  @override
  String get vaultOpenButton => 'Deschide';

  @override
  String get vaultInApp => 'Păstrează în aplicație';

  @override
  String get vaultInAppHint =>
      'Fără permisiuni. Dacă ștergi aplicația, notițele dispar.';

  @override
  String get vaultInAppButton => 'Alege';

  @override
  String get vaultInAppWarning =>
      'Notițele vor sta în aplicație și dispar dacă o ștergi. Le poți muta mai târziu într-un dosar obișnuit, din setări.';

  @override
  String get vaultInAppConfirm => 'Păstrează în aplicație';

  @override
  String get vaultName => 'Numele seifului';

  @override
  String get vaultPlace => 'Unde';

  @override
  String get vaultAccessTitle => 'E nevoie de acces la fișiere';

  @override
  String get vaultAccessHint =>
      'Ca să păstrezi notițele într-un dosar obișnuit, Android cere „Acces la toate fișierele”. Stowa citește și scrie doar dosarul seifului.';

  @override
  String get vaultAccessGrant => 'Deschide setările';

  @override
  String get vaultAccessDenied =>
      'Fără acces la fișiere, seiful din memoria telefonului nu merge';

  @override
  String vaultMoving(int done, int total) {
    return 'Mut: $done din $total';
  }

  @override
  String vaultBuilding(int done, int total) {
    return 'Construiesc indexul: $done din $total';
  }

  @override
  String vaultMoveFailed(int count) {
    return 'Nu s-a mutat tot, lipsesc: $count. Notițele au rămas unde erau.';
  }

  @override
  String get vaultMissingTitle => 'Seiful nu a fost găsit';

  @override
  String vaultMissingHint(String path) {
    return 'Dosarul $path lipsește sau Stowa a pierdut accesul la fișiere. Notițele din aplicație sunt în siguranță.';
  }

  @override
  String get vaultGrantAccess => 'Dă acces';

  @override
  String get vaultChooseAgain => 'Alege un dosar';

  @override
  String get vaultSection => 'Seif';

  @override
  String get vaultFolder => 'Dosar';

  @override
  String get vaultInsideApp => 'În aplicație';

  @override
  String get vaultMoveTo => 'Mută în alt dosar';

  @override
  String get vaultRebuild => 'Reconstruiește indexul';

  @override
  String get vaultSettingHint =>
      'Notițele sunt fișiere .md: dosarul îl deschide Obsidian și îl sincronizează Syncthing. Indexul e baza de căutare pe care aplicația o face singură.';

  @override
  String get vaultMoved => 'Seiful a fost mutat';

  @override
  String get vaultRebuilt => 'Indexul a fost refăcut';

  @override
  String vaultSyncing(int done, int total) {
    return 'Sincronizare notițe $done din $total';
  }

  @override
  String repeatIn(String folder, String date) {
    return 'Aceeași e în dosarul „$folder” din $date';
  }

  @override
  String repeatNoFolder(String date) {
    return 'Aceeași e fără dosar din $date';
  }

  @override
  String get settingsImport => 'Import';

  @override
  String get importTelegram => 'Din Telegram';

  @override
  String get importTelegramHint =>
      'Alege dosarul exportului „Mesaje salvate” din Telegram Desktop, HTML sau JSON. Notițele își păstrează datele, un album devine o notiță.';

  @override
  String importProgress(int done, int total) {
    return 'Import $done din $total';
  }

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de notițe importate',
      few: '$count notițe importate',
      one: '$count notiță importată',
    );
    return '$_temp0';
  }

  @override
  String importRepeated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count existau deja',
      one: '$count exista deja',
    );
    return '$_temp0';
  }

  @override
  String get importNotTelegram =>
      'Nu există export Telegram în acest dosar: e nevoie de messages.html sau result.json';

  @override
  String importMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de fișiere lipsesc din export',
      few: '$count fișiere lipsesc din export',
      one: '$count fișier lipsește din export',
    );
    return '$_temp0 — activează fișierele în setările exportului și importă din nou';
  }

  @override
  String importFilled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de notițe importate anterior au primit fișierele',
      few: '$count notițe importate anterior au primit fișierele',
      one: '$count notiță importată anterior a primit fișierele',
    );
    return '$_temp0';
  }

  @override
  String get returnChannel => 'Reveniri';

  @override
  String get returnWatchTitle => 'De văzut mai târziu';

  @override
  String returnVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de videoclipuri',
      few: '$count videoclipuri',
      one: '$count videoclip',
    );
    return '$_temp0';
  }

  @override
  String returnArticles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de articole',
      few: '$count articole',
      one: '$count articol',
    );
    return '$_temp0';
  }

  @override
  String returnMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de minute',
      few: '$count minute',
      one: '$count minut',
    );
    return '$_temp0';
  }

  @override
  String returnAnd(String first, String second) {
    return '$first și $second';
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
      other: 'Acum $count de ani',
      few: 'Acum $count ani',
      one: 'Acum un an',
    );
    return '$_temp0';
  }

  @override
  String get returnMonthAgo => 'Acum o lună';

  @override
  String get returnWeekAgo => 'Acum o săptămână';

  @override
  String returnDayOne(String title) {
    return '„$title”';
  }

  @override
  String returnDayMore(String title, int count) {
    return '„$title” și încă $count';
  }

  @override
  String get returnOnThisDay => 'În această zi';

  @override
  String get returnWeekTitle => 'Săptămâna în Stowa';

  @override
  String returnWeekSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de notițe săptămâna aceasta',
      few: '$count notițe săptămâna aceasta',
      one: '$count notiță săptămâna aceasta',
    );
    return '$_temp0';
  }

  @override
  String returnWeekUnopened(int count) {
    return '$count nedeschise';
  }

  @override
  String returnWeekUnsorted(int count) {
    return '$count fără dosar';
  }

  @override
  String get returnWeekUnopenedTitle => 'Nedeschise';

  @override
  String get returnWeekUnsortedTitle => 'Fără dosar';

  @override
  String returnShopTitle(String shop) {
    return 'La $shop';
  }

  @override
  String returnShopMore(String items, int count) {
    return '$items și încă $count';
  }

  @override
  String get returnShopping => 'De cumpărat';

  @override
  String get settingsReturns => 'Readu aminte';

  @override
  String get returnWeekSetting => 'Rezumatul săptămânii';

  @override
  String get returnShoppingSetting => 'Cumpărături lângă magazin';

  @override
  String get returnEveningRow => 'Seara la';

  @override
  String get returnQuietRow => 'Ore de liniște';

  @override
  String get returnWeekDayRow => 'Ziua rezumatului';

  @override
  String get returnSettingsHint =>
      'Cel mult o notificare pe zi, fără sunet și nimic în orele de liniște. Mementourile tale după oră sau loc nu se pun la socoteală.';

  @override
  String returnRange(String from, String to) {
    return '$from–$to';
  }

  @override
  String get returnQuietFrom => 'Liniște de la';

  @override
  String get returnQuietTo => 'Liniște până la';

  @override
  String get returnWatchEmpty => 'Coada e goală: ai văzut tot ce e nou.';

  @override
  String get returnDayEmpty => 'În această zi nu ai salvat nimic înainte.';

  @override
  String get returnWeekEmpty => 'Nimic salvat săptămâna aceasta.';

  @override
  String get returnShoppingEmpty => 'Nimic de cumpărat: listele sunt bifate.';

  @override
  String returnMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get returnsAskTitle => 'Să-ți readuc aminte ce ai salvat?';

  @override
  String get returnsAskBody =>
      'Seara, o singură notificare fără sunet: ce să vezi, ce ai salvat în această zi acum un an, rezumatul săptămânii. Cel mult o dată pe zi.';

  @override
  String get returnsAskOn => 'Activează';

  @override
  String get returnsAskLater => 'Nu acum';

  @override
  String get placeRemindHome => 'Amintește acasă';

  @override
  String get placeRemindWork => 'Amintește la serviciu';

  @override
  String get placeRemindHere => 'Amintește aici';

  @override
  String get placeRemindShop => 'Amintește la magazin';

  @override
  String placeRemindAt(String place) {
    return 'Amintește la $place';
  }

  @override
  String get composerRemovePlace => 'Fără memento după loc';

  @override
  String get placesTitle => 'Locuri';

  @override
  String get placesHome => 'Acasă';

  @override
  String get placesWork => 'Serviciu';

  @override
  String get placesShops => 'Magazine';

  @override
  String get placesNotSet => 'Nesetat';

  @override
  String placesWifi(String name) {
    return 'Wi-Fi: $name';
  }

  @override
  String get placesImHome => 'Sunt acasă acum';

  @override
  String get placesImWork => 'Sunt la serviciu acum';

  @override
  String get placesImShop => 'Sunt la magazin — salvează';

  @override
  String placesGuessHome(String name) {
    return 'Se pare că acasă e $name';
  }

  @override
  String placesGuessWork(String name) {
    return 'Se pare că serviciul e $name';
  }

  @override
  String get placesRemove => 'Elimină';

  @override
  String get placesShopName => 'Numele magazinului';

  @override
  String get placesSave => 'Salvează';

  @override
  String get placesNoFix =>
      'Nu am aflat unde ești. Verifică dacă localizarea e pornită și permisă pentru Stowa.';

  @override
  String get placesPermissionTitle => 'E nevoie de localizare „mereu”';

  @override
  String get placesPermissionBody =>
      'Android trezește Stowa la locul potrivit și arată numele rețelei Wi-Fi doar dacă localizarea e permisă „mereu”. Coordonatele rămân pe telefon.';

  @override
  String get placesPermissionAllow => 'Permite';

  @override
  String get placesHint =>
      'Locurile sunt pentru „amintește-mi acasă”, „la serviciu” și „la magazin”. Notițele cu eticheta #cumpără apar la magazinele salvate, cel mult o dată pe zi.';

  @override
  String placesShopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de magazine',
      few: '$count magazine',
      one: '$count magazin',
    );
    return '$_temp0';
  }

  @override
  String get itemRemindTime => 'La o oră';

  @override
  String get itemPlaceChange => 'Alt loc';

  @override
  String get placesMissingHome =>
      'Acasă nu e setat încă: Stowa îți va aminti după ce îl setezi în Locuri';

  @override
  String get placesMissingWork =>
      'Serviciul nu e setat încă: Stowa îți va aminti după ce îl setezi în Locuri';

  @override
  String get placesMissingShop =>
      'Încă nu ai magazine: salvează măcar unul în Locuri';

  @override
  String get placeChannel => 'Mementouri după loc';

  @override
  String get remindPlaceNeedsAlways =>
      'Îți reamintesc acolo dacă permiți locația „mereu”';

  @override
  String get lookColor => 'Culoare';

  @override
  String homeFoldersMore(Object count) {
    return 'Încă $count';
  }

  @override
  String homeChecksMore(Object count) {
    return 'încă $count';
  }

  @override
  String get catalogTitle => 'Catalog';

  @override
  String get catalogExpand => 'Extinde tot';

  @override
  String get catalogCollapse => 'Restrânge tot';

  @override
  String get catalogOpenFolder => 'Deschide dosarul';

  @override
  String foldersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de dosare',
      few: '$count dosare',
      one: '$count dosar',
    );
    return '$_temp0';
  }

  @override
  String readerOpen(Object count) {
    return 'Citește · $count min';
  }

  @override
  String get readerOriginal => 'Original';

  @override
  String get readerQuote => 'Citat';

  @override
  String get readerCopy => 'Copiază';

  @override
  String get readerNote => 'Notă';

  @override
  String get readerNoteHint => 'Notă la citat';

  @override
  String get readerRemove => 'Elimină';

  @override
  String get readerRemoved => 'Citat eliminat';

  @override
  String get readerGone => 'Originalul a fost șters · copia e salvată';

  @override
  String get readerNoCopy =>
      'Textul articolului nu s-a salvat. Îl poți deschide pe site.';

  @override
  String get readerImageOff => 'Imagine nesalvată';

  @override
  String get highlightsTitle => 'Citate';

  @override
  String get linkGone => 'Linkul nu se mai deschide';

  @override
  String get deadLinksTitle => 'Linkuri moarte';

  @override
  String get deadLinksAbout =>
      'O dată pe săptămână, pe Wi-Fi, Stowa verifică linkurile salvate. Aici ajung paginile șterse de site.';

  @override
  String get deadLinksEmpty => 'Toate linkurile se deschid';

  @override
  String get deadLinksCheck => 'Verifică acum';

  @override
  String get deadLinksChecking => 'Verific linkurile…';

  @override
  String get deadLinksKeep => 'Păstrează';

  @override
  String get deadLinksDelete => 'Șterge';

  @override
  String get deadLinksDeleted => 'Notița e în coș';

  @override
  String deadLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nu se deschid',
      few: '$count nu se deschid',
      one: '$count nu se deschide',
    );
    return '$_temp0';
  }

  @override
  String get settingsArticles => 'Articole';

  @override
  String get articleImages => 'Imaginile articolelor';

  @override
  String get articleImagesAbout =>
      'Descarcă pe Wi-Fi ca să citești articolele cu imagini fără rețea';

  @override
  String get foundInArticle => 'în articol';

  @override
  String get foundInQuote => 'într-un citat';

  @override
  String get settingsStart => 'La pornire';

  @override
  String get startOpen => 'Deschide';

  @override
  String get startHome => 'Pagina principală';

  @override
  String get startLast => 'Ultima notiță';

  @override
  String get startRandom => 'O notiță la întâmplare';

  @override
  String get startHint =>
      'Ultima: continui de unde ai rămas. La întâmplare: la fiecare pornire îți amintește ceva salvat, așa reții mai bine.';

  @override
  String get appearanceTitle => 'Aspect';

  @override
  String get appearanceTheme => 'Temă';

  @override
  String get themeLight => 'Luminoasă';

  @override
  String get themeDark => 'Întunecată';

  @override
  String get themeSystem => 'Ca în sistem';

  @override
  String get themeByTime => 'După ora zilei';

  @override
  String get themeByTimeHint => 'Întunecată de la 20:00 la 7:00';

  @override
  String get appearanceColor => 'Culoare';

  @override
  String get colorGraphite => 'Grafit';

  @override
  String get colorCustom => 'Culoare proprie';

  @override
  String get colorFromWallpaper => 'Din fundal';

  @override
  String get colorIntensity => 'Intensitate';

  @override
  String get intensityVibrant => 'Viu';

  @override
  String get intensityFaithful => 'Exact';

  @override
  String get intensityHint =>
      '„Viu” nuanțează și fundalul. „Exact” lasă fundalul gri și colorează butoanele exact în culoarea aleasă.';

  @override
  String get wallpaperColors => 'Culori din fundal';

  @override
  String get wallpaperColorsHint =>
      'Culoarea temei urmează fundalul telefonului';

  @override
  String get amoledTitle => 'Fundal negru';

  @override
  String get amoledHint =>
      'Negru pur pentru ecrane AMOLED, economisește bateria';

  @override
  String get pickerApply => 'Gata';

  @override
  String get colorCoral => 'Coral';

  @override
  String get colorAmber => 'Chihlimbar';

  @override
  String get colorLime => 'Lime';

  @override
  String get colorMint => 'Mentă';

  @override
  String get colorTeal => 'Turcoaz';

  @override
  String get colorBlue => 'Albastru';

  @override
  String get colorViolet => 'Violet';

  @override
  String get colorRose => 'Trandafir';

  @override
  String get folderNewInside => 'Dosar nou în interior';

  @override
  String get folderMoveTo => 'Mută în…';

  @override
  String get folderMoveTop => 'Sus, la nivelul de bază';

  @override
  String get folderMoveNone =>
      'Nu are unde fi mutat: dosarele se pot încadra pe cel mult trei niveluri';

  @override
  String get historyTitle => 'Istoric';

  @override
  String get historyNow => 'Acum';

  @override
  String get historyHint =>
      'Textul anterior se păstrează când editezi notița după o pauză. Se păstrează ultimele 50 de versiuni sau toate din ultimele 30 de zile.';

  @override
  String get historyNoChanges => 'Același text';

  @override
  String get historyText => 'Text';

  @override
  String get historyDiff => 'Diferențe';

  @override
  String get historyDiffHint =>
      'Tăiat: era în această versiune. Evidențiat: adăugat ulterior';

  @override
  String get historyRestore => 'Restabilește această versiune';

  @override
  String get historyRestored => 'Versiune restabilită';

  @override
  String get sortByColor => 'După culoare';

  @override
  String qrWifi(String network) {
    return 'Wi-Fi „$network”';
  }

  @override
  String get qrCopyPassword => 'Copiază parola Wi-Fi';

  @override
  String get qrPasswordCopied => 'Parola a fost copiată';

  @override
  String get qrOpenLink => 'Deschide linkul din codul QR';

  @override
  String get qrCopyText => 'Copiază textul codului QR';

  @override
  String get foundInQr => 'în codul QR';

  @override
  String documentPage(String number) {
    return 'pag. $number';
  }

  @override
  String get titleDateSetting => 'Numele fotografiilor și videoclipurilor';

  @override
  String get titleDateShot => 'După data fotografierii';

  @override
  String get titleDateSaved => 'După data salvării';

  @override
  String get titleDateHint =>
      'O fotografie fără descriere primește o dată în nume. Data fotografierii se ia din imagine sau din numele fișierului; dacă nu există, se folosește data salvării. Numele date de dvs. nu se schimbă.';

  @override
  String get factPassword => 'Parolă ••••••';

  @override
  String factPasswordFor(String network) {
    return 'Wi-Fi „$network” ••••••';
  }

  @override
  String get factCopyPassword => 'Copiază parola';

  @override
  String factCard(String last) {
    return 'Card ••$last';
  }

  @override
  String get factCopyCard => 'Copiază numărul cardului';

  @override
  String factPromo(String code) {
    return 'Cod $code';
  }

  @override
  String get factCopyPromo => 'Copiază codul';

  @override
  String get factTrack => 'Urmărește coletul';

  @override
  String get factOnMap => 'Deschide pe hartă';

  @override
  String get workEndRow => 'Program până la';

  @override
  String get toChecklist => 'Ca listă de cumpărături';

  @override
  String get toChecklistHint => 'Transformă în bife';

  @override
  String get toChecklistDone => 'Lista de cumpărături e gata';

  @override
  String folderTotal(String sum) {
    return 'Total $sum';
  }
}
