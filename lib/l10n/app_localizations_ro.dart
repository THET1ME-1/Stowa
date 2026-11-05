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
  String get reasonKind => 'by item type, offline';

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
}
