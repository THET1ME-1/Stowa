// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class LEs extends L {
  LEs([String locale = 'es']) : super(locale);

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
  String get savePhotosHint => 'puedes añadir descripción y etiquetas luego';

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
      'sin carpeta, la ordeno cuando aparezca algo parecido';

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
  String get voiceSaved => 'Nota de voz guardada';

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
  String get voiceNoTranscript => 'Sin transcripción';

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
  String get itemMore => 'Más';

  @override
  String get itemAppend => 'Añadir';

  @override
  String get itemShare => 'Compartir';

  @override
  String get itemAutosave => 'Se guarda solo';

  @override
  String itemPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos',
      one: '$count foto',
    );
    return '$_temp0';
  }

  @override
  String get tagAddShort => 'Etiqueta';

  @override
  String get itemOpenLink => 'Abrir';

  @override
  String get itemWatch => 'Ver';

  @override
  String get fileOpenFailed => 'Ninguna app puede abrir este archivo';

  @override
  String get linkOpenFailed => 'No se pudo abrir el enlace';

  @override
  String photoCounter(Object count, Object index) {
    return '$index de $count';
  }

  @override
  String get photoToGallery => 'A la galería';

  @override
  String get photoSaved => 'Guardado en la galería';

  @override
  String get photoSaveFailed => 'No se guardó: sin acceso a la galería';

  @override
  String get photoClose => 'Cerrar';

  @override
  String get voiceSpeed => 'Velocidad';

  @override
  String autoSorted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas parecidas ordenadas',
      one: '$count nota parecida ordenada',
    );
    return '$_temp0';
  }

  @override
  String get relatedTitle => 'Relacionado';

  @override
  String relatedWords(Object words) {
    return 'en común: $words';
  }

  @override
  String relatedSite(Object site) {
    return 'mismo sitio, $site';
  }

  @override
  String get relatedHide => 'No relacionar';

  @override
  String get relatedHidden => 'No los mostraré juntos de nuevo';

  @override
  String aiSortedInto(String folder) {
    return 'Guardado en «$folder»';
  }

  @override
  String get aiOtherFolder => 'Otra';

  @override
  String get aiPausedAuth => 'Orden en pausa: clave rechazada';

  @override
  String get aiPausedPayment => 'Orden en pausa: la clave no tiene saldo';

  @override
  String get aiPausedAction => 'Revisar clave';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsAi => 'Orden con IA';

  @override
  String get aiStateOff => 'Apagado';

  @override
  String get aiStateOffHint =>
      'Añade tu propia clave y las notas sin carpeta se ordenan solas.';

  @override
  String get aiStateOn => 'Activo';

  @override
  String aiStateWait(String time) {
    return 'El proveedor pide esperar hasta las $time';
  }

  @override
  String aiQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas en espera',
      one: '$count nota en espera',
    );
    return '$_temp0';
  }

  @override
  String get aiSortNow => 'Ordenar ahora';

  @override
  String get aiKey => 'Clave';

  @override
  String get aiKeyNone => 'Sin clave';

  @override
  String get aiKeySet => 'Guardada';

  @override
  String get aiKeyPaste => 'Pegar';

  @override
  String get aiKeySave => 'Guardar y comprobar';

  @override
  String get aiKeyRemove => 'Quitar clave';

  @override
  String get aiKeyWhere =>
      'La clave la da el proveedor: en OpenRouter está en Keys, y hay modelos gratis.';

  @override
  String get aiCheckOk => 'La clave funciona';

  @override
  String get aiCheckAuth => 'El proveedor rechazó la clave';

  @override
  String get aiCheckPayment => 'La clave no tiene saldo';

  @override
  String get aiCheckRate => 'El proveedor pide esperar';

  @override
  String get aiCheckNetwork => 'No hay conexión con el proveedor';

  @override
  String get aiCheckServer => 'El proveedor respondió con un error';

  @override
  String get aiProvider => 'Proveedor';

  @override
  String get aiProviderHint =>
      'Dirección de una API compatible con OpenAI, vacía es OpenRouter.';

  @override
  String get aiSortModel => 'Modelo para ordenar';

  @override
  String get aiSpeechModel => 'Transcribir notas de voz';

  @override
  String get aiSpeechOff => 'Apagada';

  @override
  String get aiModelsSearch => 'Buscar modelo';

  @override
  String get aiModelFree => 'gratis';

  @override
  String get aiModelVision => 've fotos';

  @override
  String get aiModelsNeedKey =>
      'La lista de modelos aparece tras añadir la clave';

  @override
  String get aiModelsFailed => 'La lista de modelos no cargó';

  @override
  String aiModelOwn(String name) {
    return 'Propio: «$name»';
  }

  @override
  String get settingsOrder => 'Orden';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageSystem => 'Como el sistema';

  @override
  String settingsVersion(String version) {
    return 'Stowa $version';
  }

  @override
  String get trashTitle => 'Papelera';

  @override
  String get trashEmpty => 'La papelera está vacía';

  @override
  String get trashHint =>
      'Lo borrado se queda aquí 30 días y luego se elimina con sus archivos.';

  @override
  String trashDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días restantes',
      one: '$count día restante',
    );
    return '$_temp0';
  }

  @override
  String trashFrom(String folder) {
    return 'de «$folder»';
  }

  @override
  String get trashPurge => 'Borrar para siempre';

  @override
  String get trashPurgeAll => 'Vaciar papelera';

  @override
  String trashPurgeAllAsk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas se borrarán para siempre. No se puede deshacer.',
      one: '$count nota se borrará para siempre. No se puede deshacer.',
    );
    return '$_temp0';
  }

  @override
  String trashRestored(String title) {
    return '«$title» restaurado';
  }

  @override
  String get trashPurged => 'Borrado para siempre';

  @override
  String get settingsData => 'Datos';

  @override
  String get backupSave => 'Guardar copia';

  @override
  String get backupSaveHint =>
      'Todas tus notas, carpetas y archivos en un solo archivo, sin la clave de IA.';

  @override
  String get backupRestore => 'Restaurar copia';

  @override
  String backupRestoreAsk(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count notas de la copia del $date reemplazan todo lo que tienes ahora.',
      one:
          '$count nota de la copia del $date reemplaza todo lo que tienes ahora.',
    );
    return '$_temp0';
  }

  @override
  String get backupReplace => 'Reemplazar';

  @override
  String get backupRestored => 'Copia restaurada';

  @override
  String get backupNotStowa => 'No es una copia de Stowa';

  @override
  String get backupTooNew =>
      'Una Stowa más nueva hizo esta copia. Actualiza la app';

  @override
  String get backupFailed => 'La copia falló';

  @override
  String get folderNewBadge => 'nueva';

  @override
  String get aiSortingNow => 'Ordenando…';

  @override
  String get aiLog => 'Registro de peticiones';

  @override
  String get aiLogEmpty => 'Aún no hubo peticiones al proveedor';

  @override
  String get aiLogCluster => 'Carpetas nuevas de «Sin carpeta»';

  @override
  String get aiCheckTimeout => 'El modelo no respondió a tiempo';

  @override
  String get tgTitle => 'Tu bot de Telegram';

  @override
  String get tgNone => 'Sin conectar';

  @override
  String get tgHowTo =>
      '1. Abre @BotFather en Telegram y envía /⁠newbot.\n2. Ponle nombre al bot y BotFather te enviará un token.\n3. Pega el token aquí.\n4. Escribe lo que sea a tu bot: desde entonces solo te escucha a ti, y lo que le reenvíes llega a Stowa.';

  @override
  String get tgConnect => 'Conectar';

  @override
  String tgOwner(String name) {
    return 'Solo escucha a $name';
  }

  @override
  String get tgWaitingOwner => 'Escribe algo al bot para que te recuerde';

  @override
  String get tgOpenBot => 'Abrir el bot';

  @override
  String get tgDisconnect => 'Desconectar el bot';

  @override
  String get tgBadToken => 'Telegram rechazó el token';

  @override
  String get tgOffline => 'No hay conexión con Telegram';

  @override
  String tgPulled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes recogidos',
      one: '$count mensaje recogido',
    );
    return '$_temp0';
  }

  @override
  String get settingsOutside => 'Desde fuera';

  @override
  String selCount(int count) {
    return 'Seleccionados: $count';
  }

  @override
  String get selClear => 'Quitar selección';

  @override
  String get selAll => 'Seleccionar todo';

  @override
  String get selMove => 'Mover';

  @override
  String get selTag => 'Etiqueta';

  @override
  String get selUntag => 'Quitar etiqueta';

  @override
  String get selDelete => 'Borrar';

  @override
  String selMoved(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas movidas a «$folder»',
      one: '$count nota movida a «$folder»',
    );
    return '$_temp0';
  }

  @override
  String selDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas borradas',
      one: '$count nota borrada',
    );
    return '$_temp0';
  }

  @override
  String selTagged(String tag) {
    return 'Etiquetado #$tag';
  }

  @override
  String selUntagged(String tag) {
    return 'Quitado #$tag';
  }

  @override
  String get tagPickTitle => 'Qué etiqueta';

  @override
  String get folderCanvas => 'Lienzo';

  @override
  String get canvasFit => 'Encajar todo';

  @override
  String get canvasNote => 'Nota';

  @override
  String get canvasNoteHint => 'Qué escribir en el lienzo';

  @override
  String get graphTitle => 'Grafo de enlaces';

  @override
  String get graphEmpty =>
      'Aún no hay enlaces. Aparecen cuando las notas comparten palabras o la IA las une.';

  @override
  String get graphFailed => 'El grafo no se generó';

  @override
  String copyPartlyFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos no se guardaron: la app no dio acceso',
      one: '$count archivo no se guardó: la app no dio acceso',
    );
    return '$_temp0';
  }

  @override
  String get mapTitle => 'Mapa';

  @override
  String get mapEmpty =>
      'Aún nada tiene lugar. Las notas nuevas recuerdan dónde las guardaste y aparecen aquí.';

  @override
  String get mapWhereAmI => 'Dónde estoy';

  @override
  String get mapPlaceUnnamed => 'Lugar sin nombre';

  @override
  String get placeSetting => 'Recordar dónde se guardó';

  @override
  String get placeSettingHint =>
      'El lugar aparece en la nota y en el mapa, y del teléfono solo sale la consulta del nombre de la calle.';

  @override
  String panelLooking(Object what) {
    return 'Busco: $what';
  }

  @override
  String get foundAtPlace => 'por lugar';

  @override
  String fileSaving(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos se están guardando',
      one: '$count archivo se está guardando',
    );
    return '$_temp0';
  }

  @override
  String get fileSavingHint =>
      'Puedes cerrar la app y borrar el original cuando desaparezca la barra.';

  @override
  String get foundInFile => 'en el archivo';

  @override
  String get foundOnPage => 'en la página';

  @override
  String get foundInPhotoInfo => 'en los datos de la foto';

  @override
  String documentSheet(Object name) {
    return 'hoja «$name»';
  }

  @override
  String documentSlide(Object number) {
    return 'diapositiva $number';
  }

  @override
  String documentChapter(Object number) {
    return 'capítulo $number';
  }

  @override
  String get factCall => 'Llamar';

  @override
  String get factWrite => 'Escribir';

  @override
  String get factCopy => 'Copiar';

  @override
  String photoTaken(Object date) {
    return 'Tomada el $date';
  }

  @override
  String foundInSubtitles(Object time) {
    return 'en los subtítulos · $time';
  }

  @override
  String foundInChapters(Object time) {
    return 'en los capítulos · $time';
  }

  @override
  String get foundInIngredients => 'en los ingredientes';

  @override
  String get foundAtAddress => 'por dirección';

  @override
  String get foundInHashtags => 'en los hashtags';

  @override
  String get watchFromHere => 'Ver desde aquí';

  @override
  String get pageRecipe => 'receta';

  @override
  String get pageProduct => 'producto';

  @override
  String get pageEvent => 'evento';

  @override
  String get pagePlace => 'lugar';

  @override
  String get pageMovie => 'película';

  @override
  String get pageBook => 'libro';

  @override
  String get pageVideo => 'vídeo';

  @override
  String get pageArticle => 'artículo';

  @override
  String minutesShort(Object count) {
    return '$count min';
  }

  @override
  String servings(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count raciones',
      one: '$count ración',
    );
    return '$_temp0';
  }

  @override
  String readingMinutes(Object count) {
    return '$count min de lectura';
  }

  @override
  String get inStock => 'En stock';

  @override
  String get outOfStock => 'Agotado';

  @override
  String get toShoppingList => 'A la lista de la compra';

  @override
  String shoppingFor(Object name) {
    return 'Comprar: $name';
  }

  @override
  String get shoppingReady => 'La lista de la compra está lista';

  @override
  String get chaptersTitle => 'Capítulos';

  @override
  String get authorTags => 'Etiquetas del autor';

  @override
  String get pageSeries => 'serie';

  @override
  String get pageComic => 'cómic';

  @override
  String get adultSetting => 'Mostrar 18+';

  @override
  String get adultSettingHint =>
      'Mientras esté desactivado, las portadas y descripciones de páginas 18+ quedan ocultas.';

  @override
  String get adultHidden =>
      'Descripción oculta: 18+. Puedes activarla en los ajustes.';

  @override
  String get vaultSetupTitle => 'Dónde guardar tus notas';

  @override
  String get vaultSetupHint =>
      'Las notas, fotos y archivos son archivos normales en una carpeta que también abre Obsidian.';

  @override
  String get vaultCreate => 'Crear una bóveda';

  @override
  String get vaultCreateHint =>
      'Una carpeta nueva en la memoria del teléfono: tus notas se quedan aunque borres la app.';

  @override
  String get vaultCreateButton => 'Crear';

  @override
  String get vaultOpen => 'Abrir carpeta como bóveda';

  @override
  String get vaultOpenHint =>
      'Tu bóveda de Stowa tras reinstalar o una bóveda de Obsidian.';

  @override
  String get vaultOpenButton => 'Abrir';

  @override
  String get vaultInApp => 'Guardar dentro de la app';

  @override
  String get vaultInAppHint =>
      'Sin permisos, pero si borras la app, se borran las notas.';

  @override
  String get vaultInAppButton => 'Elegir';

  @override
  String get vaultInAppWarning =>
      'Las notas estarán dentro de la app y desaparecerán si la borras. Puedes moverlas a una carpeta normal más tarde en los ajustes.';

  @override
  String get vaultInAppConfirm => 'Guardar dentro';

  @override
  String get vaultName => 'Nombre de la bóveda';

  @override
  String get vaultPlace => 'Ubicación';

  @override
  String get vaultAccessTitle => 'Hace falta acceso a archivos';

  @override
  String get vaultAccessHint =>
      'Para guardar notas en una carpeta normal, Android pide «Acceso a todos los archivos», pero Stowa solo toca su carpeta.';

  @override
  String get vaultAccessGrant => 'Abrir ajustes';

  @override
  String get vaultAccessDenied =>
      'Sin acceso a archivos, la bóveda en la memoria del teléfono no funciona';

  @override
  String vaultMoving(int done, int total) {
    return 'Moviendo: $done de $total';
  }

  @override
  String vaultBuilding(int done, int total) {
    return 'Creando el índice: $done de $total';
  }

  @override
  String vaultMoveFailed(int count) {
    return 'No se movió todo, faltan: $count. Las notas siguen donde estaban.';
  }

  @override
  String get vaultMissingTitle => 'No se encuentra la bóveda';

  @override
  String vaultMissingHint(String path) {
    return 'La carpeta $path no está o Stowa perdió el acceso a archivos. Las notas de la app están a salvo.';
  }

  @override
  String get vaultGrantAccess => 'Dar acceso';

  @override
  String get vaultChooseAgain => 'Elegir carpeta';

  @override
  String get vaultSection => 'Bóveda';

  @override
  String get vaultFolder => 'Carpeta';

  @override
  String get vaultInsideApp => 'Dentro de la app';

  @override
  String get vaultMoveTo => 'Mover a otra carpeta';

  @override
  String get vaultRebuild => 'Rehacer el índice';

  @override
  String get vaultSettingHint =>
      'Las notas son archivos .md normales que también abre Obsidian.';

  @override
  String get vaultMoved => 'Bóveda movida';

  @override
  String get vaultRebuilt => 'Índice rehecho';

  @override
  String vaultSyncing(int done, int total) {
    return 'Sincronizando notas $done de $total';
  }

  @override
  String repeatIn(String folder, String date) {
    return 'La misma está en la carpeta «$folder» desde el $date';
  }

  @override
  String repeatNoFolder(String date) {
    return 'La misma está sin carpeta desde el $date';
  }

  @override
  String get settingsImport => 'Importar';

  @override
  String get importTelegram => 'Desde Telegram';

  @override
  String get importTelegramHint =>
      'Elige la carpeta de exportación de «Mensajes guardados» de Telegram Desktop.';

  @override
  String importProgress(int done, int total) {
    return 'Importando $done de $total';
  }

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas importadas',
      one: '$count nota importada',
    );
    return '$_temp0';
  }

  @override
  String importRepeated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ya estaban',
      one: '$count ya estaba',
    );
    return '$_temp0';
  }

  @override
  String get importNotTelegram =>
      'En esta carpeta no hay exportación de Telegram: falta messages.html o result.json';

  @override
  String importMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos quedaron fuera de la exportación',
      one: '$count archivo quedó fuera de la exportación',
    );
    return '$_temp0 — activa los archivos en los ajustes de exportación e importa de nuevo';
  }

  @override
  String importFilled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas anteriores recibieron sus archivos',
      one: '$count nota anterior recibió sus archivos',
    );
    return '$_temp0';
  }

  @override
  String get returnChannel => 'Volver a lo guardado';

  @override
  String get returnWatchTitle => 'Ver más tarde';

  @override
  String returnVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos',
      one: '$count vídeo',
    );
    return '$_temp0';
  }

  @override
  String returnArticles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artículos',
      one: '$count artículo',
    );
    return '$_temp0';
  }

  @override
  String returnMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutos',
      one: '$count minuto',
    );
    return '$_temp0';
  }

  @override
  String returnAnd(String first, String second) {
    return '$first y $second';
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
      other: 'Hace $count años',
      one: 'Hace un año',
    );
    return '$_temp0';
  }

  @override
  String get returnMonthAgo => 'Hace un mes';

  @override
  String get returnWeekAgo => 'Hace una semana';

  @override
  String returnDayOne(String title) {
    return '«$title»';
  }

  @override
  String returnDayMore(String title, int count) {
    return '«$title» y $count más';
  }

  @override
  String get returnOnThisDay => 'Tal día como hoy';

  @override
  String get returnWeekTitle => 'Tu semana en Stowa';

  @override
  String returnWeekSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas esta semana',
      one: '$count nota esta semana',
    );
    return '$_temp0';
  }

  @override
  String returnWeekUnopened(int count) {
    return '$count sin abrir';
  }

  @override
  String returnWeekUnsorted(int count) {
    return '$count sin carpeta';
  }

  @override
  String get returnWeekUnopenedTitle => 'Sin abrir';

  @override
  String get returnWeekUnsortedTitle => 'Sin carpeta';

  @override
  String returnShopTitle(String shop) {
    return 'En $shop';
  }

  @override
  String returnShopMore(String items, int count) {
    return '$items y $count más';
  }

  @override
  String get returnShopping => 'Por comprar';

  @override
  String get settingsReturns => 'Notificaciones';

  @override
  String get returnWeekSetting => 'Resumen semanal';

  @override
  String get returnShoppingSetting => 'Compras cerca de la tienda';

  @override
  String get returnEveningRow => 'Por la tarde a las';

  @override
  String get returnQuietRow => 'Horas de silencio';

  @override
  String get returnWeekDayRow => 'Día del resumen';

  @override
  String get returnSettingsHint =>
      'Como mucho una notificación silenciosa al día.';

  @override
  String returnRange(String from, String to) {
    return '$from–$to';
  }

  @override
  String get returnQuietFrom => 'Silencio desde';

  @override
  String get returnQuietTo => 'Silencio hasta';

  @override
  String get returnWatchEmpty =>
      'La cola está vacía: ya viste todo lo reciente.';

  @override
  String get returnDayEmpty => 'Ningún otro año guardaste nada este día.';

  @override
  String get returnWeekEmpty => 'Esta semana no guardaste nada.';

  @override
  String get returnShoppingEmpty =>
      'Nada que comprar: las listas están marcadas.';

  @override
  String returnMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get returnsAskTitle => '¿Te recuerdo lo guardado?';

  @override
  String get returnsAskBody =>
      'Una notificación silenciosa por la tarde te recuerda lo que guardaste.';

  @override
  String get returnsAskOn => 'Activar';

  @override
  String get returnsAskLater => 'Ahora no';

  @override
  String get placeRemindHome => 'Recordar en casa';

  @override
  String get placeRemindWork => 'Recordar en el trabajo';

  @override
  String get placeRemindHere => 'Recordar aquí';

  @override
  String get placeRemindShop => 'Recordar en la tienda';

  @override
  String placeRemindAt(String place) {
    return 'Recordar en $place';
  }

  @override
  String get composerRemovePlace => 'Sin recordatorio por lugar';

  @override
  String get placesTitle => 'Lugares';

  @override
  String get placesHome => 'Casa';

  @override
  String get placesWork => 'Trabajo';

  @override
  String get placesShops => 'Tiendas';

  @override
  String get placesNotSet => 'Sin definir';

  @override
  String placesWifi(String name) {
    return 'Wi-Fi: $name';
  }

  @override
  String get placesImHome => 'Ahora estoy en casa';

  @override
  String get placesImWork => 'Ahora estoy en el trabajo';

  @override
  String get placesImShop => 'Estoy en una tienda — guardarla';

  @override
  String placesGuessHome(String name) {
    return 'Parece que tu casa es $name';
  }

  @override
  String placesGuessWork(String name) {
    return 'Parece que tu trabajo es $name';
  }

  @override
  String get placesRemove => 'Quitar';

  @override
  String get placesShopName => 'Nombre de la tienda';

  @override
  String get placesSave => 'Guardar';

  @override
  String get placesNoFix =>
      'No pude saber dónde estás. Comprueba que la ubicación esté activada y permitida para Stowa.';

  @override
  String get placesPermissionTitle => 'Hace falta la ubicación «siempre»';

  @override
  String get placesPermissionBody =>
      'Los recordatorios en un lugar solo funcionan si la ubicación está permitida «siempre».';

  @override
  String get placesPermissionAllow => 'Permitir';

  @override
  String get placesHint =>
      'Escribe «recuérdame en la farmacia» y Stowa te lo recordará allí.';

  @override
  String placesShopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tiendas',
      one: '$count tienda',
    );
    return '$_temp0';
  }

  @override
  String get itemRemindTime => 'A una hora';

  @override
  String get itemPlaceChange => 'Otro lugar';

  @override
  String get placesMissingHome =>
      'Tu casa aún no está definida: Stowa te avisará cuando la definas en Lugares';

  @override
  String get placesMissingWork =>
      'Tu trabajo aún no está definido: Stowa te avisará cuando lo definas en Lugares';

  @override
  String get placesMissingShop =>
      'Aún no hay tiendas: guarda al menos una en Lugares';

  @override
  String get placeChannel => 'Recordatorios por lugar';

  @override
  String get remindPlaceNeedsAlways =>
      'Te lo recordaré allí si permites la ubicación «siempre»';

  @override
  String get lookColor => 'Color';

  @override
  String homeFoldersMore(Object count) {
    return '$count más';
  }

  @override
  String homeChecksMore(Object count) {
    return '$count más';
  }

  @override
  String get catalogTitle => 'Catálogo';

  @override
  String get catalogExpand => 'Expandir todo';

  @override
  String get catalogCollapse => 'Contraer todo';

  @override
  String get catalogOpenFolder => 'Abrir carpeta';

  @override
  String foldersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count carpetas',
      one: '$count carpeta',
    );
    return '$_temp0';
  }

  @override
  String readerOpen(Object count) {
    return 'Leer · $count min';
  }

  @override
  String get readerOriginal => 'Original';

  @override
  String get readerQuote => 'Cita';

  @override
  String get readerCopy => 'Copiar';

  @override
  String get readerNote => 'Nota';

  @override
  String get readerNoteHint => 'Nota para la cita';

  @override
  String get readerRemove => 'Quitar';

  @override
  String get readerRemoved => 'Cita quitada';

  @override
  String get readerGone => 'Original eliminado · copia guardada';

  @override
  String get readerNoCopy =>
      'El texto del artículo no se guardó. Puedes abrirlo en el sitio.';

  @override
  String get readerImageOff => 'Imagen no guardada';

  @override
  String get highlightsTitle => 'Citas';

  @override
  String get linkGone => 'El enlace ya no abre';

  @override
  String get deadLinksTitle => 'Enlaces rotos';

  @override
  String get deadLinksAbout =>
      'Una vez a la semana Stowa revisa tus enlaces y reúne aquí las páginas que el sitio borró.';

  @override
  String get deadLinksEmpty => 'Todos los enlaces abren';

  @override
  String get deadLinksCheck => 'Comprobar ahora';

  @override
  String get deadLinksChecking => 'Comprobando enlaces…';

  @override
  String get deadLinksKeep => 'Conservar';

  @override
  String get deadLinksDelete => 'Eliminar';

  @override
  String get deadLinksDeleted => 'Nota en la papelera';

  @override
  String deadLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count no abren',
      one: '$count no abre',
    );
    return '$_temp0';
  }

  @override
  String get settingsArticles => 'Artículos';

  @override
  String get articleImages => 'Imágenes de artículos';

  @override
  String get articleImagesAbout =>
      'Descargar con Wi-Fi para leer artículos con imágenes sin conexión';

  @override
  String get foundInArticle => 'en el artículo';

  @override
  String get foundInQuote => 'en una cita';

  @override
  String get settingsStart => 'Al abrir';

  @override
  String get startOpen => 'Abrir';

  @override
  String get startHome => 'Inicio';

  @override
  String get startLast => 'La última nota';

  @override
  String get startRandom => 'Una nota al azar';

  @override
  String get startHint =>
      'La última nota sigue donde lo dejaste, una al azar te recuerda algo guardado.';

  @override
  String get appearanceTitle => 'Apariencia';

  @override
  String get appearanceTheme => 'Tema';

  @override
  String get themeLight => 'Clara';

  @override
  String get themeDark => 'Oscura';

  @override
  String get themeSystem => 'Como el sistema';

  @override
  String get themeByTime => 'Según la hora';

  @override
  String get themeByTimeHint => 'Oscura de 20:00 a 7:00';

  @override
  String get appearanceColor => 'Color';

  @override
  String get colorGraphite => 'Grafito';

  @override
  String get colorCustom => 'Color propio';

  @override
  String get colorFromWallpaper => 'Del fondo';

  @override
  String get colorIntensity => 'Intensidad';

  @override
  String get intensityVibrant => 'Vivo';

  @override
  String get intensityFaithful => 'Exacto';

  @override
  String get intensityHint =>
      '«Vivo» tiñe también el fondo, «Exacto» lo deja gris.';

  @override
  String get wallpaperColors => 'Colores del fondo';

  @override
  String get wallpaperColorsHint => 'El color sigue el fondo del teléfono';

  @override
  String get amoledTitle => 'Fondo negro';

  @override
  String get amoledHint => 'Negro puro para pantallas AMOLED, ahorra batería';

  @override
  String get pickerApply => 'Listo';

  @override
  String get colorCoral => 'Coral';

  @override
  String get colorAmber => 'Ámbar';

  @override
  String get colorLime => 'Lima';

  @override
  String get colorMint => 'Menta';

  @override
  String get colorTeal => 'Turquesa';

  @override
  String get colorBlue => 'Azul';

  @override
  String get colorViolet => 'Violeta';

  @override
  String get colorRose => 'Rosa';

  @override
  String get folderNewInside => 'Nueva carpeta dentro';

  @override
  String get folderMoveTo => 'Mover a…';

  @override
  String get folderMoveTop => 'Arriba del todo';

  @override
  String get folderMoveNone =>
      'No hay a dónde moverla: las carpetas se anidan hasta tres niveles';

  @override
  String get historyTitle => 'Historial';

  @override
  String get historyNow => 'Ahora';

  @override
  String get historyHint =>
      'El texto anterior se guarda cuando editas la nota tras una pausa.';

  @override
  String get historyNoChanges => 'Mismo texto';

  @override
  String get historyText => 'Texto';

  @override
  String get historyDiff => 'Cambios';

  @override
  String get historyDiffHint =>
      'Tachado: estaba en esta versión. Resaltado: se añadió después';

  @override
  String get historyRestore => 'Restaurar esta versión';

  @override
  String get historyRestored => 'Versión restaurada';

  @override
  String get sortByColor => 'Por color';

  @override
  String qrWifi(String network) {
    return 'Wi-Fi «$network»';
  }

  @override
  String get qrCopyPassword => 'Copiar la contraseña del Wi-Fi';

  @override
  String get qrPasswordCopied => 'Contraseña copiada';

  @override
  String get qrOpenLink => 'Abrir el enlace del código QR';

  @override
  String get qrCopyText => 'Copiar el texto del código QR';

  @override
  String get foundInQr => 'en un código QR';

  @override
  String documentPage(String number) {
    return 'pág. $number';
  }

  @override
  String get titleDateSetting => 'Nombre de fotos y vídeos';

  @override
  String get titleDateShot => 'Por fecha de captura';

  @override
  String get titleDateSaved => 'Por fecha de guardado';

  @override
  String get titleDateHint =>
      'Las fotos y vídeos sin descripción llevan una fecha en el nombre.';

  @override
  String get factPassword => 'Contraseña ••••••';

  @override
  String factPasswordFor(String network) {
    return 'Wi-Fi «$network» ••••••';
  }

  @override
  String get factCopyPassword => 'Copiar contraseña';

  @override
  String factCard(String last) {
    return 'Tarjeta ••$last';
  }

  @override
  String get factCopyCard => 'Copiar número de tarjeta';

  @override
  String factPromo(String code) {
    return 'Código $code';
  }

  @override
  String get factCopyPromo => 'Copiar código';

  @override
  String get factTrack => 'Seguir el paquete';

  @override
  String get factOnMap => 'Abrir en el mapa';

  @override
  String get workEndRow => 'Trabajo hasta';

  @override
  String get toChecklist => 'Como lista de la compra';

  @override
  String get toChecklistHint => 'Convertir en casillas';

  @override
  String get toChecklistDone => 'Lista de la compra lista';

  @override
  String folderTotal(String sum) {
    return 'Total $sum';
  }

  @override
  String get smartSave => 'Carpeta inteligente';

  @override
  String smartSaved(String name) {
    return 'Carpeta inteligente «$name» en la pantalla principal';
  }

  @override
  String get smartEmpty => 'Todavía nada coincide con esta búsqueda';

  @override
  String get smartDelete => 'Eliminar carpeta inteligente';

  @override
  String smartDeleted(String name) {
    return 'Carpeta «$name» eliminada, las notas siguen';
  }

  @override
  String suggestSite(int count, String site) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enlaces',
      one: '$count enlace',
    );
    return '$_temp0 de $site sin carpeta';
  }

  @override
  String suggestScreenshots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capturas',
      one: '$count captura',
    );
    return '$_temp0 sin carpeta';
  }

  @override
  String suggestVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos',
      one: '$count vídeo',
    );
    return '$_temp0 sin carpeta';
  }

  @override
  String suggestFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos',
      one: '$count archivo',
    );
    return '$_temp0 sin carpeta';
  }

  @override
  String suggestVoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas de voz',
      one: '$count nota de voz',
    );
    return '$_temp0 sin carpeta';
  }

  @override
  String suggestSiteBody(String name) {
    return '¿Crear la carpeta «$name»? Los enlaces nuevos de este sitio irán allí solos.';
  }

  @override
  String suggestBody(String name) {
    return '¿Crear la carpeta «$name» y moverlos allí?';
  }

  @override
  String get suggestYes => 'Crear';

  @override
  String get suggestNo => 'No, gracias';

  @override
  String suggestDone(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas',
      one: '$count nota',
    );
    return 'Carpeta «$name»: $_temp0';
  }

  @override
  String get suggestScreenshotsName => 'Capturas';

  @override
  String get suggestVideosName => 'Vídeos';

  @override
  String get suggestFilesName => 'Archivos';

  @override
  String get suggestVoicesName => 'Notas de voz';

  @override
  String get ruleIfPage => 'la página es';

  @override
  String get ruleIfPriceAbove => 'precio mayor';

  @override
  String get ruleIfPriceBelow => 'precio menor';

  @override
  String get ruleValuePrice => 'Importe, p. ej. 1000';

  @override
  String rulePriceAboveValue(String value) {
    return 'más de $value';
  }

  @override
  String rulePriceBelowValue(String value) {
    return 'menos de $value';
  }

  @override
  String get ruleThenRemind => 'recordar';

  @override
  String get remindHourBefore => 'una hora antes';

  @override
  String get remindDayBefore => 'un día antes';

  @override
  String get remindWeekBefore => 'una semana antes';

  @override
  String codeWait(Object seconds) {
    return 'Espera $seconds s';
  }

  @override
  String get codeFingerprint => 'Huella';

  @override
  String get codeErase => 'Borrar';

  @override
  String get codeDone => 'Listo';

  @override
  String get codeWrong => 'Código incorrecto';

  @override
  String get codeCreateTitle => 'Crea un código';

  @override
  String get codeRepeatTitle => 'Repite el código';

  @override
  String get codeCreateHint =>
      'De 6 a 12 cifras: si olvidas el código, las notas ocultas se pierden para siempre.';

  @override
  String get codeMismatch => 'Los códigos no coinciden, créalo de nuevo';

  @override
  String get hiddenOpenReason => 'Abrir carpetas ocultas';

  @override
  String get hiddenOpenTitle => 'Código de las carpetas ocultas';

  @override
  String get codeForgot => 'Olvidé el código';

  @override
  String get codeOldTitle => 'Código actual';

  @override
  String get codeNewTitle => 'Código nuevo';

  @override
  String get codeChanged => 'Código cambiado';

  @override
  String get codeForgetTitle => '¿Quitar el código?';

  @override
  String get codeForgetText =>
      'El bloqueo se apaga y las carpetas ocultas se borran con sus notas. No se podrán recuperar.';

  @override
  String get codeForgetAction => 'Quitar el código y borrar lo oculto';

  @override
  String folderHidden(Object name) {
    return 'La carpeta «$name» está oculta';
  }

  @override
  String folderUnhidden(Object name) {
    return 'La carpeta «$name» vuelve a verse';
  }

  @override
  String get lockReason => 'Desbloquear Stowa';

  @override
  String get lockTitle => 'Introduce el código';

  @override
  String get codeEnterTitle => 'Introduce el código';

  @override
  String get closeAfterNow => 'Al instante';

  @override
  String get closeAfterMinute => 'Tras 1 minuto';

  @override
  String closeAfterMinutes(Object minutes) {
    return 'Tras $minutes minutos';
  }

  @override
  String get privacySection => 'Privacidad';

  @override
  String get codeCreateRow => 'Crear código';

  @override
  String get appLockRow => 'Código al abrir';

  @override
  String get fingerprintRow => 'Huella dactilar';

  @override
  String get closeAfterRow => 'Volver a bloquear';

  @override
  String get hiddenCloseRow => 'Cerrar carpetas ocultas';

  @override
  String get hiddenOpenRow => 'Abrir carpetas ocultas';

  @override
  String get codeChangeRow => 'Cambiar código';

  @override
  String get privacyHint =>
      'Las carpetas ocultas están cifradas y no se pueden leer sin el código.';

  @override
  String get markdownExport => 'Exportar a Markdown';

  @override
  String get markdownNoVault => 'Primero elige la carpeta de la bóveda';

  @override
  String get markdownHiddenAsk => '¿Exportar también las carpetas ocultas?';

  @override
  String get markdownHiddenHint =>
      'Las notas ocultas quedarán como archivos normales y cualquiera que tenga esta carpeta podrá leerlas.';

  @override
  String get markdownWithoutHidden => 'Sin las ocultas';

  @override
  String get markdownWithHidden => 'Con las ocultas';

  @override
  String markdownDone(Object path) {
    return 'Exportado a $path';
  }

  @override
  String get markdownFailed => 'No se pudo escribir en esta carpeta';

  @override
  String get folderUnhide => 'Dejar de ocultar';

  @override
  String get folderHide => 'Ocultar carpeta';

  @override
  String get folderHiddenMark => 'oculta';

  @override
  String get hiddenFolders => 'Carpetas ocultas';

  @override
  String get hiddenReminder => 'Recordatorio de una carpeta oculta';

  @override
  String get aiFirst => 'La IA manda';

  @override
  String get aiFirstHint =>
      'El modelo revisa también lo que la app ordenó sola, así que hace más consultas';

  @override
  String get composerHintNoSearch => 'Suelta lo que sea';

  @override
  String get returnsOff => 'Desactivado';

  @override
  String get crashSetting => 'Informes de errores';

  @override
  String get crashSettingHint =>
      'El desarrollador recibe el error y el modelo del teléfono, sin notas ni nombres de archivos.';

  @override
  String get vaultInFiles => 'Archivos → Stowa';

  @override
  String get vaultFilesHint =>
      'Las notas son archivos .md normales que ves en la app Archivos.';

  @override
  String get itemDateChange => 'Cambiar fecha';

  @override
  String get itemDateNow => 'Ahora';

  @override
  String get itemDatePick => 'Elegir día y hora';

  @override
  String get itemDateChanged => 'Fecha cambiada';

  @override
  String get propertiesTitle => 'Propiedades';

  @override
  String propertiesMore(Object count) {
    return '$count más';
  }

  @override
  String get propertiesLess => 'Contraer';

  @override
  String get propertyAdd => 'Añadir propiedad';

  @override
  String get propertyNew => 'Nueva propiedad';

  @override
  String get propertyEdit => 'Propiedad';

  @override
  String get propertyNameHint => 'Nombre';

  @override
  String get propertyValueHint => 'Valor';

  @override
  String get propertyListHint => 'Un elemento por línea';

  @override
  String get propertyKindText => 'Texto';

  @override
  String get propertyKindList => 'Lista';

  @override
  String get propertyKindNumber => 'Número';

  @override
  String get propertyKindCheckbox => 'Casilla';

  @override
  String get propertyKindDate => 'Fecha';

  @override
  String get propertyNameTaken => 'Esta propiedad ya existe';

  @override
  String get propertyNumberWrong => 'Escribe un número';

  @override
  String get propertyDatePick => 'Elegir día';

  @override
  String get propertyDelete => 'Eliminar propiedad';

  @override
  String get propertyRemoved => 'Propiedad eliminada';

  @override
  String get propertyOtherHint =>
      'Este valor se cambia en el archivo de la nota.';

  @override
  String get propertyYes => 'Sí';

  @override
  String get propertyNo => 'No';

  @override
  String get lookSuggested => 'Encajan con el nombre';

  @override
  String get lookPopular => 'Frecuentes';

  @override
  String get lookAll => 'Todos los iconos';

  @override
  String get iconsNone => 'No hay ese icono, prueba otra palabra.';

  @override
  String get placeKindHome => 'Casa';

  @override
  String get placeKindWork => 'Trabajo';

  @override
  String get placeKindStudy => 'Estudios';

  @override
  String get placeKindShop => 'Tienda';

  @override
  String get placeKindPharmacy => 'Farmacia';

  @override
  String get placeKindFood => 'Cafés y restaurantes';

  @override
  String get placeKindSport => 'Deporte';

  @override
  String get placeKindGuests => 'Amigos y familia';

  @override
  String get placeKindOther => 'Otro';

  @override
  String get placeRemindStudy => 'Recordar en clase';

  @override
  String get placeRemindPharmacy => 'Recordar en la farmacia';

  @override
  String get placeRemindFood => 'Recordar en el café';

  @override
  String get placeRemindSport => 'Recordar en el gimnasio';

  @override
  String get placeRemindGuests => 'Recordar de visita';

  @override
  String get placeRemindOther => 'Recordar en el lugar';

  @override
  String placeRemindDay(String place, String day) {
    return '$place · $day';
  }

  @override
  String get dayToday => 'hoy';

  @override
  String get dayTomorrow => 'mañana';

  @override
  String get placesMissingKind =>
      'Aún no hay ese lugar: te lo recordaré cuando lo añadas en Lugares';

  @override
  String get placesAdd => 'Añadir lugar';

  @override
  String get placesEmpty =>
      'Aún no hay lugares: añade casa, trabajo, tu café favorito o un amigo.';

  @override
  String get placeNewTitle => 'Nuevo lugar';

  @override
  String get placeEditTitle => 'Lugar';

  @override
  String get placeNameHint => 'Nombre: Uni, Sasha, Andy’s';

  @override
  String get placeKindTitle => 'Qué es';

  @override
  String get placeWhereTitle => 'Dónde';

  @override
  String get placeHereNow => 'Estoy aquí ahora';

  @override
  String get placeMapHint =>
      'Mueve el mapa: el lugar está donde el punto del centro.';

  @override
  String get placeKindMore => 'Buscar o crear';

  @override
  String get placeKindSearchHint => 'Busca un tipo o pon el tuyo';

  @override
  String placeKindCreate(String name) {
    return 'Crear «$name»';
  }

  @override
  String get placeIcon => 'Icono';

  @override
  String get lineLanguageHint =>
      'En este idioma no entiendo la hora en palabras — escríbela en cifras: 14:30';

  @override
  String get lineLanguageHide => 'Ocultar';

  @override
  String get placeSearchHint => 'Buscar una dirección o lugar';

  @override
  String get placeSearchNone => 'No se encontró nada';

  @override
  String get placeMapEmpty =>
      'Busca la dirección o mantén pulsado el mapa para poner el punto';

  @override
  String get placeMapMove => 'Mantén pulsado el mapa para mover el punto';

  @override
  String get placePointMoved => 'Punto movido';

  @override
  String get placeNoPoint => 'Sin punto todavía';

  @override
  String get placeKindOwn => 'Tipo propio';

  @override
  String placeRadiusValue(int meters) {
    return '$meters m';
  }

  @override
  String get placeRadiusTitle => 'Radio del recordatorio';

  @override
  String get relatedInText => 'en el texto de la nota';

  @override
  String get relatedBacklink => 'enlaza aquí';

  @override
  String get relatedManual => 'enlazada a mano';

  @override
  String relatedAi(String reason) {
    return 'IA: $reason';
  }

  @override
  String get relatedAiPlain => 'enlazada por la IA';

  @override
  String get relatedUnlink => 'Quitar enlace';

  @override
  String get relatedUnlinked => 'Enlace quitado';

  @override
  String get linkAdd => 'Enlazar con una nota';

  @override
  String get linkAddShort => 'Enlace';

  @override
  String get linkSearchHint => 'Buscar una nota por palabras';

  @override
  String get linkNone => 'No hay una nota así';

  @override
  String linkAdded(String title) {
    return 'Enlazada con «$title»';
  }

  @override
  String linkMissing(String title) {
    return 'No hay una nota «$title»';
  }

  @override
  String get settingsCatalog => 'Catálogo';

  @override
  String get settingsLook => 'Aspecto';

  @override
  String get settingsHelpers => 'Orden y avisos';

  @override
  String get settingsCopies => 'Copias';

  @override
  String get vaultsSection => 'Bóvedas';

  @override
  String get vaultOpenNow => 'Abierta';

  @override
  String get vaultAdd => 'Añadir bóveda';

  @override
  String get vaultAddNew => 'Crear nueva';

  @override
  String get vaultAddNewHint => 'Una carpeta vacía para notas nuevas';

  @override
  String get vaultAddOpen => 'Abrir una carpeta';

  @override
  String get vaultAddOpenHint => 'Una bóveda anterior de Stowa u Obsidian';

  @override
  String get vaultsHint =>
      'Toca otra bóveda para abrirla; los recordatorios llegan solo de la abierta.';

  @override
  String get vaultFolderGone => 'No se encuentra la carpeta';

  @override
  String get vaultForget => 'Quitar de la lista';

  @override
  String get vaultForgetHint => 'Los archivos se quedan en la carpeta';

  @override
  String get vaultForgotten =>
      'Bóveda quitada de la lista; los archivos siguen ahí';

  @override
  String get vaultOpenIt => 'Abrir';

  @override
  String get vaultAlreadyOpen => 'Esta bóveda ya está abierta';

  @override
  String get vaultHasNotes => 'Esta carpeta ya tiene notas';

  @override
  String get vaultOpenSeparately => 'Abrir como bóveda aparte';

  @override
  String get vaultOpenSeparatelyHint => 'La actual se queda en la lista';

  @override
  String get vaultMergeHere => 'Mover aquí y unir';

  @override
  String get vaultMergeHereHint => 'Las notas de ambas quedan en una carpeta';

  @override
  String vaultSwitching(String name) {
    return 'Abriendo «$name»';
  }

  @override
  String get vaultChangeFolder => 'Cambiar carpeta';

  @override
  String vaultAllCount(int count) {
    return 'Todas las bóvedas · $count';
  }

  @override
  String get syncTitle => 'Stowa Sync';

  @override
  String get syncPaid => 'De pago';

  @override
  String get syncSoon => 'Próximamente';

  @override
  String get syncAbout =>
      'Las notas se mantendrán iguales en el móvil, la tableta y el ordenador.';

  @override
  String get syncLater =>
      'La suscripción llegará en una de las próximas actualizaciones.';

  @override
  String get syncOk => 'Entendido';

  @override
  String get itemPin => 'Fijar';

  @override
  String get itemUnpin => 'Desfijar';

  @override
  String get itemPinned => 'Fijada arriba en el inicio';

  @override
  String get itemUnpinned => 'Desfijada';

  @override
  String get homePinned => 'Fijadas';

  @override
  String homePinnedMore(Object count) {
    return '$count más';
  }

  @override
  String get homePinnedLess => 'Mostrar menos';

  @override
  String get catalogReorderHint =>
      'Mantén pulsada una carpeta y arrástrala: en este orden aparecen también en el inicio.';

  @override
  String linkCreate(Object title) {
    return 'Crear nota «$title»';
  }

  @override
  String get linkCreateAction => 'Crear';

  @override
  String homeMoreLines(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count líneas más',
      one: '$count línea más',
    );
    return '$_temp0';
  }

  @override
  String get edgeTitle => 'A mano';

  @override
  String get edgeSwitch => 'Lomos en el borde';

  @override
  String get edgeSwitchHint =>
      'Las notas fijadas esperan en el borde de la pantalla y un toque las abre sobre cualquier app.';

  @override
  String get edgePlace => 'Dónde';

  @override
  String get edgeLeft => 'Izquierda';

  @override
  String get edgeRight => 'Derecha';

  @override
  String get edgeHeight => 'Altura en la pantalla';

  @override
  String get edgeHigher => 'más arriba';

  @override
  String get edgeMiddle => 'en el medio';

  @override
  String get edgeLower => 'más abajo';

  @override
  String get edgeSize => 'Tamaño';

  @override
  String get edgeThin => 'finos';

  @override
  String get edgeNormal => 'normales';

  @override
  String get edgeLarge => 'grandes';

  @override
  String get edgeAlpha => 'Visibilidad';

  @override
  String get edgeHideVideo => 'Ocultar en vídeo a pantalla completa';

  @override
  String get edgeHideVideoHint =>
      'Mientras un vídeo o juego está a pantalla completa, los lomos no estorban.';

  @override
  String get edgeOff => 'Desactivado';

  @override
  String get edgeRecent => 'Recientes';

  @override
  String get edgeOpenApp => 'Abrir Stowa';

  @override
  String get edgeStick => 'Fijar como pegatina';

  @override
  String get edgeSpinesSetup => 'Ajustar los lomos';

  @override
  String get edgeUnstick => 'Quitar pegatina';

  @override
  String get edgeNearby => 'Cerca';

  @override
  String get suggestPaste => 'Pegar del portapapeles';

  @override
  String get edgeGestures => 'Gestos';

  @override
  String get edgeGestureSwipe => 'Desliza hacia abajo para escribir';

  @override
  String get edgeGestureSwipeHint => 'La línea se abre con el teclado listo.';

  @override
  String get edgeGestureHold => 'Mantén pulsado para una nota de voz';

  @override
  String get edgeGestureHoldHint =>
      'La grabación sigue sin el dedo hasta que toques Guardar.';

  @override
  String get edgeGestureDouble => 'Toca dos veces para la última nota';

  @override
  String get edgeGestureDoubleHint =>
      'Un solo toque reacciona entonces un poco más tarde.';

  @override
  String get edgeVoiceChannel => 'Grabación de voz';

  @override
  String get edgeVoiceNow => 'Grabando una nota de voz';
}
