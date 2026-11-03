import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_ro.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('pl'),
    Locale('ro'),
    Locale('ru'),
    Locale('uk'),
  ];

  /// Название приложения
  ///
  /// In en, this message translates to:
  /// **'Stowa'**
  String get appName;

  /// Пустая строка снизу на главной
  ///
  /// In en, this message translates to:
  /// **'Drop anything or search'**
  String get composerHint;

  /// Раздел последних вещей на главной
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get homeRecent;

  /// Раздел папок на главной
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get homeFolders;

  /// Главная без единой вещи
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Drop the first thing into the line below.'**
  String get homeEmpty;

  /// Подпись над ближайшим напоминанием
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get homeNext;

  /// Сколько ещё напоминаний после ближайшего
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String homeMoreToday(Object count);

  /// Отметить напоминание сделанным
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get homeReminderDone;

  /// Ссылка «все» у раздела
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get homeAll;

  /// Вещь ещё не разложена по папкам
  ///
  /// In en, this message translates to:
  /// **'No folder'**
  String get folderNone;

  /// Подпись под вещью, которую разбирает ИИ
  ///
  /// In en, this message translates to:
  /// **'sorting'**
  String get itemSorting;

  /// Метка папки, которую завёл ИИ
  ///
  /// In en, this message translates to:
  /// **'new'**
  String get folderNew;

  /// Напоминание сегодня
  ///
  /// In en, this message translates to:
  /// **'today at {time}'**
  String remindToday(Object time);

  /// Напоминание завтра
  ///
  /// In en, this message translates to:
  /// **'tomorrow at {time}'**
  String remindTomorrow(Object time);

  /// Напоминание в другой день
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String remindOn(Object date, Object time);

  /// Кнопка сохранить в строке
  ///
  /// In en, this message translates to:
  /// **'Stow'**
  String get composerStow;

  /// Чип напоминания над строкой
  ///
  /// In en, this message translates to:
  /// **'Remind {when}'**
  String composerRemind(Object when);

  /// Подсказка к крестику на чипе напоминания
  ///
  /// In en, this message translates to:
  /// **'No reminder'**
  String get composerRemoveReminder;

  /// Кнопка плюс в строке
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get composerAttach;

  /// Кнопка решётки в строке
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get composerAddTag;

  /// Заголовок панели над строкой
  ///
  /// In en, this message translates to:
  /// **'It goes'**
  String get composerGoesTo;

  /// Attach sheet: pick photos and videos from the gallery
  ///
  /// In en, this message translates to:
  /// **'Photos and videos'**
  String get attachGallery;

  /// Attach sheet: open the camera for a photo
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get attachCamera;

  /// Attach sheet: pick any files
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get attachFile;

  /// Сообщение после сохранения
  ///
  /// In en, this message translates to:
  /// **'Stowed'**
  String get savedToast;

  /// Сообщение после сохранения с напоминанием
  ///
  /// In en, this message translates to:
  /// **'Stowed, reminder {when}'**
  String savedWithReminder(Object when);

  /// Отменить сохранение
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// Ошибка сохранения
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save, the text is back in the line'**
  String get saveFailed;

  /// Убрать вложение из строки
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAttachment;

  /// Attach sheet: hint under the gallery option
  ///
  /// In en, this message translates to:
  /// **'Several at once'**
  String get attachGalleryHint;

  /// Attach sheet: open the camera for a video
  ///
  /// In en, this message translates to:
  /// **'Record a video'**
  String get attachVideo;

  /// Attach sheet: hint under the files option
  ///
  /// In en, this message translates to:
  /// **'Any format: documents, text, archives'**
  String get attachFileHint;

  /// Toast when a picker fails to return files
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open it. Try again'**
  String get attachFailed;

  /// Panel header while typing #
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get panelTags;

  /// Panel header while typing @
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get panelFolders;

  /// Panel header while typing /
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get panelCommands;

  /// Panel header: search results count
  ///
  /// In en, this message translates to:
  /// **'Found {count}'**
  String panelFound(int count);

  /// Panel header: no results
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get panelNothing;

  /// Panel header: similar items exist
  ///
  /// In en, this message translates to:
  /// **'Something similar is here'**
  String get panelSimilar;

  /// Panel header: no similar items
  ///
  /// In en, this message translates to:
  /// **'Nothing like it yet, this is new'**
  String get panelFresh;

  /// Kind filter: everything
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// Kind filter
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get kindsNote;

  /// Kind filter
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get kindsLink;

  /// Kind filter
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get kindsVideo;

  /// Kind filter
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get kindsImage;

  /// Kind filter
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get kindsFile;

  /// Kind filter
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get kindsVoice;

  /// Where line in a result
  ///
  /// In en, this message translates to:
  /// **'note'**
  String get kindNote;

  /// Where line in a result
  ///
  /// In en, this message translates to:
  /// **'link'**
  String get kindLink;

  /// Where line in a result
  ///
  /// In en, this message translates to:
  /// **'video'**
  String get kindVideo;

  /// Where line in a result
  ///
  /// In en, this message translates to:
  /// **'photo'**
  String get kindImage;

  /// Where line in a result
  ///
  /// In en, this message translates to:
  /// **'file'**
  String get kindFile;

  /// Where line in a result
  ///
  /// In en, this message translates to:
  /// **'voice note'**
  String get kindVoice;

  /// Where the match was found
  ///
  /// In en, this message translates to:
  /// **'in the transcript'**
  String get foundInTranscript;

  /// Where the match was found
  ///
  /// In en, this message translates to:
  /// **'on the picture'**
  String get foundOnImage;

  /// Where the match was found
  ///
  /// In en, this message translates to:
  /// **'in the description'**
  String get foundInDescription;

  /// Short date
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get dateToday;

  /// Short date
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get dateYesterday;

  /// Save row: what is saved
  ///
  /// In en, this message translates to:
  /// **'Stow it'**
  String get saveWhatNote;

  /// Save row: what is saved
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get saveWhatLink;

  /// Save row: what is saved
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get saveWhatVideo;

  /// Save row: photos
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} photo} other{{count} photos}}'**
  String saveWhatPhotos(int count);

  /// Save row: files
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} file} other{{count} files}}'**
  String saveWhatFiles(int count);

  /// Save row for /task
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get saveWhatTask;

  /// Save row for /list
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count}-item list} other{{count}-item list}}'**
  String saveWhatList(int count);

  /// Save row title with folder
  ///
  /// In en, this message translates to:
  /// **'{what} to “{folder}”'**
  String saveInto(String what, String folder);

  /// Save row title without folder
  ///
  /// In en, this message translates to:
  /// **'{what}, I’ll pick a folder'**
  String saveNoFolder(String what);

  /// Save row for /remind
  ///
  /// In en, this message translates to:
  /// **'Remind {when}'**
  String saveRemind(String when);

  /// Save row for /remind without a date
  ///
  /// In en, this message translates to:
  /// **'Remind'**
  String get saveRemindBare;

  /// Save row for /inbox
  ///
  /// In en, this message translates to:
  /// **'No folder, as is'**
  String get saveAsIs;

  /// Save row subtitle
  ///
  /// In en, this message translates to:
  /// **'remind {when}'**
  String saveRemindAt(String when);

  /// Save row subtitle for /remind without date
  ///
  /// In en, this message translates to:
  /// **'when? add “tomorrow at 10”'**
  String get saveRemindWhen;

  /// Save row subtitle for photos without text
  ///
  /// In en, this message translates to:
  /// **'your AI key will add a caption and tags'**
  String get savePhotosHint;

  /// Why the folder
  ///
  /// In en, this message translates to:
  /// **'you picked the folder'**
  String get reasonChosen;

  /// Why the folder
  ///
  /// In en, this message translates to:
  /// **'by tag #{tag}, offline'**
  String reasonTag(String tag);

  /// Why the folder
  ///
  /// In en, this message translates to:
  /// **'by the word “{word}”, offline'**
  String reasonWord(String word);

  /// Why the folder
  ///
  /// In en, this message translates to:
  /// **'by a link to {domain}, offline'**
  String reasonDomain(String domain);

  /// Why the folder
  ///
  /// In en, this message translates to:
  /// **'by item type, offline'**
  String get reasonKind;

  /// Why the folder
  ///
  /// In en, this message translates to:
  /// **'your AI key will pick the folder'**
  String get reasonNone;

  /// Why no folder
  ///
  /// In en, this message translates to:
  /// **'unsorted, as asked'**
  String get reasonAsIs;

  /// Send button label
  ///
  /// In en, this message translates to:
  /// **'Stow'**
  String get actionStow;

  /// Send button label
  ///
  /// In en, this message translates to:
  /// **'Remind'**
  String get actionRemind;

  /// Send button label
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get actionOpen;

  /// Send button label
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get actionInsert;

  /// Send button label
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get actionCreate;

  /// Add the thought to a similar note
  ///
  /// In en, this message translates to:
  /// **'Append'**
  String get actionAppend;

  /// Count of items
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} item} other{{count} items}}'**
  String itemsCount(int count);

  /// New tag row
  ///
  /// In en, this message translates to:
  /// **'Create #{name}'**
  String tagCreate(String name);

  /// New tag row subtitle
  ///
  /// In en, this message translates to:
  /// **'pick an icon later'**
  String get tagCreateHint;

  /// Line command word, lowercase, one word
  ///
  /// In en, this message translates to:
  /// **'remind'**
  String get cmdRemind;

  /// Line command word, lowercase, one word
  ///
  /// In en, this message translates to:
  /// **'task'**
  String get cmdTask;

  /// Line command word, lowercase, one word
  ///
  /// In en, this message translates to:
  /// **'list'**
  String get cmdList;

  /// Line command word, lowercase, one word
  ///
  /// In en, this message translates to:
  /// **'find'**
  String get cmdFind;

  /// Line command word, lowercase, one word
  ///
  /// In en, this message translates to:
  /// **'inbox'**
  String get cmdInbox;

  /// Command description
  ///
  /// In en, this message translates to:
  /// **'Say when: “tomorrow at 10”, “on fri”'**
  String get cmdRemindHint;

  /// Command description
  ///
  /// In en, this message translates to:
  /// **'Saved with a checkbox'**
  String get cmdTaskHint;

  /// Command description
  ///
  /// In en, this message translates to:
  /// **'Every line or comma becomes an item'**
  String get cmdListHint;

  /// Command description
  ///
  /// In en, this message translates to:
  /// **'Only search, save nothing'**
  String get cmdFindHint;

  /// Command description
  ///
  /// In en, this message translates to:
  /// **'Keep as is, unsorted'**
  String get cmdInboxHint;

  /// Toast after saving
  ///
  /// In en, this message translates to:
  /// **'Went to “{folder}”'**
  String savedInto(String folder);

  /// Toast after saving
  ///
  /// In en, this message translates to:
  /// **'Went to “{folder}”, will remind {when}'**
  String savedIntoRemind(String folder, String when);

  /// Toast after appending
  ///
  /// In en, this message translates to:
  /// **'Added to “{title}”'**
  String appendedTo(String title);

  /// Toast after recording
  ///
  /// In en, this message translates to:
  /// **'Voice note saved, your AI key will transcribe it'**
  String get voiceSaved;

  /// Title of a voice item
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get voiceTitle;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Cancel recording'**
  String get voiceCancel;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'No microphone access'**
  String get voiceDenied;

  /// Tooltip for the mic button
  ///
  /// In en, this message translates to:
  /// **'Record a voice note'**
  String get voiceRecord;

  /// Suggestion chip
  ///
  /// In en, this message translates to:
  /// **'Link from clipboard'**
  String get suggestClip;

  /// Suggestion chip
  ///
  /// In en, this message translates to:
  /// **'Screenshot'**
  String get suggestShot;

  /// Suggestion age
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(int count);

  /// Suggestion age
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// Tray tab
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get trayGallery;

  /// Tray tab
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get trayCamera;

  /// Tray tab
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get trayFile;

  /// Tray tab
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get trayLink;

  /// Tray tab: record a video
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get trayVideo;

  /// Tray without permission
  ///
  /// In en, this message translates to:
  /// **'Allow photo access to pick right here'**
  String get trayAccess;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get trayAllow;

  /// Tray without photos
  ///
  /// In en, this message translates to:
  /// **'The gallery is empty'**
  String get trayEmpty;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'No link in the clipboard'**
  String get trayNoLink;

  /// Placeholder of the full editor
  ///
  /// In en, this message translates to:
  /// **'Write in Markdown, attach files with plus'**
  String get fullHint;

  /// Destination chip in the full editor
  ///
  /// In en, this message translates to:
  /// **'I’ll pick a folder'**
  String get fullPickFolder;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get fullExpand;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get fullCollapse;

  /// Folder picker title
  ///
  /// In en, this message translates to:
  /// **'Where to put it'**
  String get folderPickTitle;

  /// Markdown toolbar
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get mdHeading;

  /// Markdown toolbar
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get mdBold;

  /// Markdown toolbar
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get mdItalic;

  /// Markdown toolbar
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get mdStrike;

  /// Markdown toolbar
  ///
  /// In en, this message translates to:
  /// **'Bullets'**
  String get mdBullets;

  /// Markdown toolbar
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get mdChecklist;

  /// Markdown toolbar
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get mdQuote;

  /// Markdown toolbar
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get mdCode;

  /// Markdown toolbar
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get mdUndo;

  /// Markdown toolbar
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get mdRedo;

  /// Tooltip on a chip
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeChip;

  /// Tooltip on a suggested tag chip
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get pinTag;

  /// Item page action
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get itemCopy;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get itemCopied;

  /// Item page action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get itemDelete;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get itemDeleted;

  /// Item page block
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get itemTranscript;

  /// Item page block
  ///
  /// In en, this message translates to:
  /// **'What is in the picture'**
  String get itemDescription;

  /// Item page block
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get itemFiles;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Moved to “{folder}”'**
  String itemMoved(String folder);

  /// Recent card while AI sorts
  ///
  /// In en, this message translates to:
  /// **'sorting'**
  String get itemSortingBadge;

  /// Why the folder: a character name already lives there
  ///
  /// In en, this message translates to:
  /// **'by the name “{name}”, offline'**
  String reasonName(String name);

  /// Why the folder: rare words already live there
  ///
  /// In en, this message translates to:
  /// **'by the words “{words}”, offline'**
  String reasonSimilar(String words);

  /// New folder row after @
  ///
  /// In en, this message translates to:
  /// **'Create folder “{name}”'**
  String folderCreate(String name);

  /// New folder row subtitle
  ///
  /// In en, this message translates to:
  /// **'change the icon and shape later'**
  String get folderCreateHint;

  /// Folder view: photo board
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get folderBoard;

  /// Folder view: mixed list
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get folderList;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Search in folder'**
  String get folderSearch;

  /// Tooltip for the folder menu
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get folderMore;

  /// Folder menu
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get folderRename;

  /// Folder menu
  ///
  /// In en, this message translates to:
  /// **'Icon and shape'**
  String get folderLook;

  /// Folder menu
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get folderDelete;

  /// Rename field label
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderNameLabel;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Delete confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”? Its items stay without a folder.'**
  String folderDeleteAsk(String name);

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Folder deleted'**
  String get folderDeleted;

  /// Undo a deletion
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreAction;

  /// Empty folder
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Drop something into the line below and it lands here.'**
  String get folderEmpty;

  /// Line hint inside a folder
  ///
  /// In en, this message translates to:
  /// **'Drop it here'**
  String get dropHere;

  /// Look sheet section
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get lookIcon;

  /// Look sheet section
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get lookShape;

  /// Voice card without transcript
  ///
  /// In en, this message translates to:
  /// **'No transcript yet: your AI key will make it'**
  String get voiceNoTranscript;

  /// Voice card caption
  ///
  /// In en, this message translates to:
  /// **'Voice note, transcribed'**
  String get voiceTranscribed;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get voicePlay;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get voicePause;

  /// Android notification channel name
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminderChannel;

  /// Share sheet title
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get shareSaved;

  /// Share sheet subtitle
  ///
  /// In en, this message translates to:
  /// **'in “{folder}”'**
  String shareInFolder(String folder);

  /// Share sheet subtitle
  ///
  /// In en, this message translates to:
  /// **'no folder yet'**
  String get shareNoFolder;

  /// Share sheet label above folders
  ///
  /// In en, this message translates to:
  /// **'Or somewhere else'**
  String get shareOther;

  /// Chip: create a folder
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get shareNewFolder;

  /// Share sheet field
  ///
  /// In en, this message translates to:
  /// **'Add a few words'**
  String get shareAddWords;

  /// Share sheet button
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get shareDone;

  /// Tags screen title
  ///
  /// In en, this message translates to:
  /// **'Tags and folders'**
  String get tagsTitle;

  /// Segment
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsTab;

  /// Segment
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get foldersTab;

  /// Section
  ///
  /// In en, this message translates to:
  /// **'On the home screen'**
  String get tagsPinned;

  /// Hint
  ///
  /// In en, this message translates to:
  /// **'Hold and drag to reorder'**
  String get tagsPinnedHint;

  /// Section
  ///
  /// In en, this message translates to:
  /// **'All tags'**
  String get tagsAll;

  /// Empty
  ///
  /// In en, this message translates to:
  /// **'No tags yet. Type #tag in the line or create one here.'**
  String get tagsNone;

  /// Section
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get rulesTitle;

  /// Empty
  ///
  /// In en, this message translates to:
  /// **'No rules yet: the line sorts by words already in your folders.'**
  String get rulesNone;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'New rule'**
  String get ruleNew;

  /// Rule card without folder
  ///
  /// In en, this message translates to:
  /// **'stays where it is'**
  String get ruleStays;

  /// Sheet title
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get tagNew;

  /// Sheet title when editing
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get tagEdit;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'tag name'**
  String get tagNameHint;

  /// Icon kind
  ///
  /// In en, this message translates to:
  /// **'Icons'**
  String get iconSymbols;

  /// Icon kind
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get iconEmoji;

  /// Icon kind
  ///
  /// In en, this message translates to:
  /// **'Own picture'**
  String get iconImage;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Pick a picture'**
  String get iconPickImage;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'One emoji'**
  String get emojiHint;

  /// Section in the tag sheet
  ///
  /// In en, this message translates to:
  /// **'Put into folder'**
  String get tagToFolder;

  /// Switch
  ///
  /// In en, this message translates to:
  /// **'Pin to home'**
  String get tagPin;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Create tag'**
  String get tagCreateButton;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Delete tag'**
  String get tagDelete;

  /// Confirm
  ///
  /// In en, this message translates to:
  /// **'Remove #{name} from {count, plural, one{{count} item} other{{count} items}}? The items stay.'**
  String tagDeleteAsk(String name, int count);

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Tag #{name} deleted'**
  String tagDeleted(String name);

  /// Sheet title
  ///
  /// In en, this message translates to:
  /// **'Rule'**
  String get ruleSheetTitle;

  /// Rule sheet section
  ///
  /// In en, this message translates to:
  /// **'If'**
  String get ruleIf;

  /// Rule sheet section
  ///
  /// In en, this message translates to:
  /// **'Then'**
  String get ruleThen;

  /// Condition kind
  ///
  /// In en, this message translates to:
  /// **'has tag'**
  String get ruleIfTag;

  /// Condition kind
  ///
  /// In en, this message translates to:
  /// **'link to site'**
  String get ruleIfDomain;

  /// Condition kind
  ///
  /// In en, this message translates to:
  /// **'has word'**
  String get ruleIfWord;

  /// Condition kind
  ///
  /// In en, this message translates to:
  /// **'item type'**
  String get ruleIfKind;

  /// Action kind
  ///
  /// In en, this message translates to:
  /// **'into folder'**
  String get ruleThenFolder;

  /// Action kind
  ///
  /// In en, this message translates to:
  /// **'add tag'**
  String get ruleThenTag;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'tag without #'**
  String get ruleValueTag;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'tiktok.com'**
  String get ruleValueDomain;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'word'**
  String get ruleValueWord;

  /// Switch
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get ruleEnabled;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Delete rule'**
  String get ruleDelete;

  /// Home bar button
  ///
  /// In en, this message translates to:
  /// **'Tags, folders and rules'**
  String get settingsTooltip;

  /// Tooltip / button
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get tagAdd;

  /// Button: sort unsorted items one by one
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortMode;

  /// Sort mode
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get sortSkip;

  /// Sort mode counter
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String sortLeft(int count);

  /// Sort mode finished
  ///
  /// In en, this message translates to:
  /// **'All sorted'**
  String get sortDone;

  /// Sort mode hint
  ///
  /// In en, this message translates to:
  /// **'Tap a folder to put it there, swipe down to skip'**
  String get sortHint;

  /// Icon search hint; names are English Material Symbols names
  ///
  /// In en, this message translates to:
  /// **'Find an icon: car, home, food'**
  String get iconSearch;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'pl',
    'ro',
    'ru',
    'uk',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return LDe();
    case 'en':
      return LEn();
    case 'es':
      return LEs();
    case 'pl':
      return LPl();
    case 'ro':
      return LRo();
    case 'ru':
      return LRu();
    case 'uk':
      return LUk();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
