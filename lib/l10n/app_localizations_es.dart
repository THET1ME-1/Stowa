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
  String get reasonKind => 'by item type, offline';

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
      other: '$count elementos parecidos ordenados',
      one: '$count elemento parecido ordenado',
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
      'Añade tu propia clave y lo que no tiene carpeta se ordena solo, con etiquetas, título y descripción para buscar. La clave se queda en este teléfono y las peticiones van directo al proveedor.';

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
      other: '$count elementos en espera',
      one: '$count elemento en espera',
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
      'La clave la da el proveedor: en OpenRouter está en Keys. Hay modelos gratis.';

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
      'Dirección de una API compatible con OpenAI. Vacía es OpenRouter.';

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
      other: '$count elementos se borrarán para siempre. No se puede deshacer.',
      one: '$count elemento se borrará para siempre. No se puede deshacer.',
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
      'Todo Stowa en un archivo: elementos, carpetas, etiquetas, reglas y archivos. La clave de IA no se incluye.';

  @override
  String get backupRestore => 'Restaurar copia';

  @override
  String backupRestoreAsk(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count elementos de la copia del $date reemplazan todo lo que tienes ahora.',
      one:
          '$count elemento de la copia del $date reemplaza todo lo que tienes ahora.',
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
      other: '$count elementos movidos a «$folder»',
      one: '$count elemento movido a «$folder»',
    );
    return '$_temp0';
  }

  @override
  String selDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos borrados',
      one: '$count elemento borrado',
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
      'Aún no hay enlaces. Aparecen cuando los elementos comparten palabras o la IA los une.';

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
      'El lugar se añade tras guardar y aparece en la página y en el mapa. Las coordenadas se quedan en el teléfono; solo sale la consulta del nombre de la calle.';

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
      'Puedes cerrar la app, el archivo terminará solo. Cuando desaparezca la barra, puedes borrar el original.';

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
      'Páginas que se marcan a sí mismas como 18+ y sitios para adultos conocidos. Mientras esté desactivado, sus portadas se difuminan y las descripciones se ocultan. El elemento y su búsqueda se quedan.';

  @override
  String get adultHidden =>
      'Descripción oculta: 18+. Puedes activarla en los ajustes.';

  @override
  String get vaultSetupTitle => 'Dónde guardar tus notas';

  @override
  String get vaultSetupHint =>
      'Las notas, fotos y archivos son archivos normales en una carpeta. La ves en el gestor de archivos, la abre Obsidian y la sincroniza Syncthing.';

  @override
  String get vaultCreate => 'Crear una bóveda';

  @override
  String get vaultCreateHint =>
      'Una carpeta nueva en la memoria del teléfono. Tus notas se quedan aunque borres la app.';

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
      'Sin permisos. Si borras la app, se borran las notas.';

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
      'Para guardar notas en una carpeta normal, Android pide «Acceso a todos los archivos». Stowa solo lee y escribe la carpeta de la bóveda.';

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
      'Las notas son archivos .md: Obsidian abre esta carpeta y Syncthing la sincroniza. El índice es una base de búsqueda que la app crea sola.';

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
      'Elige la carpeta de exportación de «Mensajes guardados» de Telegram Desktop, HTML o JSON. Las notas conservan su fecha y un álbum queda como una nota.';

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
}
