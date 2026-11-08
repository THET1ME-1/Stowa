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

  /// Подсказка при сохранении фото без текста
  ///
  /// In en, this message translates to:
  /// **'you can add a caption and tags later'**
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
  /// **'by note type, offline'**
  String get reasonKind;

  /// Почему вещь ляжет без папки: ни правила, ни похожего
  ///
  /// In en, this message translates to:
  /// **'no folder yet, I\'ll sort it once similar things appear'**
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
  /// **'{count, plural, one{{count} note} other{{count} notes}}'**
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

  /// Плашка после записи голосового
  ///
  /// In en, this message translates to:
  /// **'Voice note saved'**
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
  /// **'Color and icon'**
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
  /// **'Delete “{name}”? Its notes stay without a folder.'**
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

  /// Подпись голосового без текста
  ///
  /// In en, this message translates to:
  /// **'No transcript'**
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
  /// **'Remove #{name} from {count, plural, one{{count} note} other{{count} notes}}? The notes stay.'**
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
  /// **'note type'**
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
  /// **'Tap a folder to put it there. Down to skip, up to delete'**
  String get sortHint;

  /// Icon search hint; names are English Material Symbols names
  ///
  /// In en, this message translates to:
  /// **'Find an icon: car, home, food'**
  String get iconSearch;

  /// Item action
  ///
  /// In en, this message translates to:
  /// **'Move to folder'**
  String get itemMove;

  /// Folder sort
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sortNewest;

  /// Folder sort
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get sortOldest;

  /// Folder sort
  ///
  /// In en, this message translates to:
  /// **'By name'**
  String get sortByName;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get sortTooltip;

  /// Notification button
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reminderDoneAction;

  /// Notification button
  ///
  /// In en, this message translates to:
  /// **'In an hour'**
  String get reminderSnoozeAction;

  /// Folder picker row
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get folderPickNew;

  /// Snackbar after Done on the reminder card
  ///
  /// In en, this message translates to:
  /// **'Reminder cleared'**
  String get reminderCleared;

  /// Title of a photo saved without text
  ///
  /// In en, this message translates to:
  /// **'Photo, {date}'**
  String untitledPhoto(String date);

  /// Title of a screenshot saved without text
  ///
  /// In en, this message translates to:
  /// **'Screenshot, {date}'**
  String untitledScreenshot(String date);

  /// Title of a video saved without text
  ///
  /// In en, this message translates to:
  /// **'Video, {date}'**
  String untitledVideo(String date);

  /// Title of an audio file saved without text
  ///
  /// In en, this message translates to:
  /// **'Recording, {date}'**
  String untitledAudio(String date);

  /// Title of a file saved without text
  ///
  /// In en, this message translates to:
  /// **'File, {date}'**
  String untitledFile(String date);

  /// Share window when nothing could be read
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: the app didn\'t give access'**
  String get shareFailed;

  /// Snackbar after deleting a rule
  ///
  /// In en, this message translates to:
  /// **'Rule deleted'**
  String get ruleDeleted;

  /// Pencil button on the item page
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get itemEdit;

  /// Round button that ends editing
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get itemEditDone;

  /// Empty title field
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get itemTitleHint;

  /// Empty body field
  ///
  /// In en, this message translates to:
  /// **'Text, lists, - [ ] tasks'**
  String get itemBodyHint;

  /// Edit bar: attach a photo
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get itemAddPhoto;

  /// Edit bar: set a reminder
  ///
  /// In en, this message translates to:
  /// **'Remind'**
  String get itemRemind;

  /// Reminder sheet action
  ///
  /// In en, this message translates to:
  /// **'Change time'**
  String get itemReminderChange;

  /// Reminder sheet action
  ///
  /// In en, this message translates to:
  /// **'Remove reminder'**
  String get itemReminderRemove;

  /// Quiet hint after autosave
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get itemSaved;

  /// Кнопка «⋮» в шапке вещи
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get itemMore;

  /// Кнопка внизу страницы: открыть правку с курсором в конце
  ///
  /// In en, this message translates to:
  /// **'Add more'**
  String get itemAppend;

  /// Отправить вещь в другое приложение
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get itemShare;

  /// Подпись в шапке, пока идёт правка
  ///
  /// In en, this message translates to:
  /// **'Saves as you type'**
  String get itemAutosave;

  /// Сколько фото у вещи, в шапке
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} photo} other{{count} photos}}'**
  String itemPhotos(num count);

  /// Короткая подпись на пилюле «добавить тег»
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get tagAddShort;

  /// Главная кнопка у ссылки: открыть страницу
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get itemOpenLink;

  /// Главная кнопка у ролика
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get itemWatch;

  /// Плашка, если в системе нет приложения для файла
  ///
  /// In en, this message translates to:
  /// **'No app can open this file'**
  String get fileOpenFailed;

  /// Плашка, если ссылка не открылась
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link'**
  String get linkOpenFailed;

  /// Номер фото в просмотре
  ///
  /// In en, this message translates to:
  /// **'{index} of {count}'**
  String photoCounter(Object count, Object index);

  /// Сохранить фото в галерею телефона
  ///
  /// In en, this message translates to:
  /// **'To gallery'**
  String get photoToGallery;

  /// Плашка после сохранения фото
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get photoSaved;

  /// Плашка, если галерея не дала сохранить
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: no access to the gallery'**
  String get photoSaveFailed;

  /// Закрыть просмотр фото
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get photoClose;

  /// Подсказка кнопки скорости голосового
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get voiceSpeed;

  /// Плашка: алгоритм разложил «Без папки» после того, как человек переложил похожее
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} similar note sorted} other{{count} similar notes sorted}}'**
  String autoSorted(num count);

  /// Заголовок блока похожих вещей на странице вещи
  ///
  /// In en, this message translates to:
  /// **'Related'**
  String get relatedTitle;

  /// Почему вещи связаны: общие слова
  ///
  /// In en, this message translates to:
  /// **'in common: {words}'**
  String relatedWords(Object words);

  /// Почему вещи связаны: ссылки на один сайт
  ///
  /// In en, this message translates to:
  /// **'same site, {site}'**
  String relatedSite(Object site);

  /// Кнопка убрать вещь из связанных
  ///
  /// In en, this message translates to:
  /// **'Not related'**
  String get relatedHide;

  /// Плашка после отклонения связи
  ///
  /// In en, this message translates to:
  /// **'Won\'t show them together again'**
  String get relatedHidden;

  /// Toast after the AI sorted an item
  ///
  /// In en, this message translates to:
  /// **'Put in “{folder}”'**
  String aiSortedInto(String folder);

  /// Toast action: pick another folder
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get aiOtherFolder;

  /// aiPausedAuth
  ///
  /// In en, this message translates to:
  /// **'Sorting paused: key rejected'**
  String get aiPausedAuth;

  /// aiPausedPayment
  ///
  /// In en, this message translates to:
  /// **'Sorting paused: the key is out of credit'**
  String get aiPausedPayment;

  /// aiPausedAction
  ///
  /// In en, this message translates to:
  /// **'Check key'**
  String get aiPausedAction;

  /// settingsTitle
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// settingsAi
  ///
  /// In en, this message translates to:
  /// **'AI sorting'**
  String get settingsAi;

  /// aiStateOff
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get aiStateOff;

  /// aiStateOffHint
  ///
  /// In en, this message translates to:
  /// **'Add your own key and notes without a folder sort themselves, with tags, a title and a description for search. The key stays on this phone; requests go straight to the provider.'**
  String get aiStateOffHint;

  /// aiStateOn
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get aiStateOn;

  /// aiStateWait
  ///
  /// In en, this message translates to:
  /// **'The provider asks to wait until {time}'**
  String aiStateWait(String time);

  /// aiQueued
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} note waiting} other{{count} notes waiting}}'**
  String aiQueued(int count);

  /// aiSortNow
  ///
  /// In en, this message translates to:
  /// **'Sort now'**
  String get aiSortNow;

  /// aiKey
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get aiKey;

  /// aiKeyNone
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get aiKeyNone;

  /// aiKeySet
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get aiKeySet;

  /// aiKeyPaste
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get aiKeyPaste;

  /// aiKeySave
  ///
  /// In en, this message translates to:
  /// **'Save and check'**
  String get aiKeySave;

  /// aiKeyRemove
  ///
  /// In en, this message translates to:
  /// **'Remove key'**
  String get aiKeyRemove;

  /// aiKeyWhere
  ///
  /// In en, this message translates to:
  /// **'Get a key from your provider: on OpenRouter it is under Keys. Free models are available.'**
  String get aiKeyWhere;

  /// aiCheckOk
  ///
  /// In en, this message translates to:
  /// **'The key works'**
  String get aiCheckOk;

  /// aiCheckAuth
  ///
  /// In en, this message translates to:
  /// **'The provider rejected the key'**
  String get aiCheckAuth;

  /// aiCheckPayment
  ///
  /// In en, this message translates to:
  /// **'The key has no credit'**
  String get aiCheckPayment;

  /// aiCheckRate
  ///
  /// In en, this message translates to:
  /// **'The provider asks to wait'**
  String get aiCheckRate;

  /// aiCheckNetwork
  ///
  /// In en, this message translates to:
  /// **'Can’t reach the provider'**
  String get aiCheckNetwork;

  /// aiCheckServer
  ///
  /// In en, this message translates to:
  /// **'The provider returned an error'**
  String get aiCheckServer;

  /// aiProvider
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get aiProvider;

  /// aiProviderHint
  ///
  /// In en, this message translates to:
  /// **'An OpenAI-compatible API address. Empty means OpenRouter.'**
  String get aiProviderHint;

  /// aiSortModel
  ///
  /// In en, this message translates to:
  /// **'Sorting model'**
  String get aiSortModel;

  /// aiSpeechModel
  ///
  /// In en, this message translates to:
  /// **'Voice transcription'**
  String get aiSpeechModel;

  /// aiSpeechOff
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get aiSpeechOff;

  /// aiModelsSearch
  ///
  /// In en, this message translates to:
  /// **'Find a model'**
  String get aiModelsSearch;

  /// aiModelFree
  ///
  /// In en, this message translates to:
  /// **'free'**
  String get aiModelFree;

  /// aiModelVision
  ///
  /// In en, this message translates to:
  /// **'sees photos'**
  String get aiModelVision;

  /// aiModelsNeedKey
  ///
  /// In en, this message translates to:
  /// **'The model list opens once a key is set'**
  String get aiModelsNeedKey;

  /// aiModelsFailed
  ///
  /// In en, this message translates to:
  /// **'The model list didn’t load'**
  String get aiModelsFailed;

  /// aiModelOwn
  ///
  /// In en, this message translates to:
  /// **'Custom: “{name}”'**
  String aiModelOwn(String name);

  /// settingsOrder
  ///
  /// In en, this message translates to:
  /// **'Organizing'**
  String get settingsOrder;

  /// settingsLanguage
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// languageSystem
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// App name is not translated
  ///
  /// In en, this message translates to:
  /// **'Stowa {version}'**
  String settingsVersion(String version);

  /// trashTitle
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trashTitle;

  /// trashEmpty
  ///
  /// In en, this message translates to:
  /// **'Trash is empty'**
  String get trashEmpty;

  /// trashHint
  ///
  /// In en, this message translates to:
  /// **'Deleted notes stay here for 30 days, then they are erased with their files.'**
  String get trashHint;

  /// trashDaysLeft
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day left} other{{count} days left}}'**
  String trashDaysLeft(int count);

  /// trashFrom
  ///
  /// In en, this message translates to:
  /// **'from “{folder}”'**
  String trashFrom(String folder);

  /// trashPurge
  ///
  /// In en, this message translates to:
  /// **'Erase forever'**
  String get trashPurge;

  /// trashPurgeAll
  ///
  /// In en, this message translates to:
  /// **'Empty trash'**
  String get trashPurgeAll;

  /// trashPurgeAllAsk
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} note will be erased forever. This can’t be undone.} other{{count} notes will be erased forever. This can’t be undone.}}'**
  String trashPurgeAllAsk(int count);

  /// trashRestored
  ///
  /// In en, this message translates to:
  /// **'Restored “{title}”'**
  String trashRestored(String title);

  /// trashPurged
  ///
  /// In en, this message translates to:
  /// **'Erased forever'**
  String get trashPurged;

  /// settingsData
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// backupSave
  ///
  /// In en, this message translates to:
  /// **'Save a backup'**
  String get backupSave;

  /// backupSaveHint
  ///
  /// In en, this message translates to:
  /// **'All of Stowa in one file: notes, folders, tags, rules and files. Your AI key is not included.'**
  String get backupSaveHint;

  /// backupRestore
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get backupRestore;

  /// backupRestoreAsk
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} note from the {date} backup will replace everything you have now.} other{{count} notes from the {date} backup will replace everything you have now.}}'**
  String backupRestoreAsk(int count, String date);

  /// backupReplace
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get backupReplace;

  /// backupRestored
  ///
  /// In en, this message translates to:
  /// **'Restored from backup'**
  String get backupRestored;

  /// backupNotStowa
  ///
  /// In en, this message translates to:
  /// **'This is not a Stowa backup'**
  String get backupNotStowa;

  /// backupTooNew
  ///
  /// In en, this message translates to:
  /// **'A newer Stowa made this backup. Update the app first'**
  String get backupTooNew;

  /// backupFailed
  ///
  /// In en, this message translates to:
  /// **'The backup failed'**
  String get backupFailed;

  /// Badge on a folder the AI created
  ///
  /// In en, this message translates to:
  /// **'new'**
  String get folderNewBadge;

  /// aiSortingNow
  ///
  /// In en, this message translates to:
  /// **'Sorting…'**
  String get aiSortingNow;

  /// aiLog
  ///
  /// In en, this message translates to:
  /// **'Request log'**
  String get aiLog;

  /// aiLogEmpty
  ///
  /// In en, this message translates to:
  /// **'No requests to the provider yet'**
  String get aiLogEmpty;

  /// aiLogCluster
  ///
  /// In en, this message translates to:
  /// **'New folders from “No folder”'**
  String get aiLogCluster;

  /// aiCheckTimeout
  ///
  /// In en, this message translates to:
  /// **'The model didn’t answer in time'**
  String get aiCheckTimeout;

  /// tgTitle
  ///
  /// In en, this message translates to:
  /// **'Your Telegram bot'**
  String get tgTitle;

  /// tgNone
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get tgNone;

  /// tgHowTo
  ///
  /// In en, this message translates to:
  /// **'1. Open @BotFather in Telegram and send /⁠newbot.\n2. Name your bot and BotFather will send a token.\n3. Paste the token here.\n4. Write anything to your bot: from then on it listens only to you, and whatever you forward to it lands in Stowa.'**
  String get tgHowTo;

  /// tgConnect
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get tgConnect;

  /// tgOwner
  ///
  /// In en, this message translates to:
  /// **'Listens only to {name}'**
  String tgOwner(String name);

  /// tgWaitingOwner
  ///
  /// In en, this message translates to:
  /// **'Write anything to the bot so it remembers you'**
  String get tgWaitingOwner;

  /// tgOpenBot
  ///
  /// In en, this message translates to:
  /// **'Open the bot'**
  String get tgOpenBot;

  /// tgDisconnect
  ///
  /// In en, this message translates to:
  /// **'Disconnect the bot'**
  String get tgDisconnect;

  /// tgBadToken
  ///
  /// In en, this message translates to:
  /// **'Telegram rejected the token'**
  String get tgBadToken;

  /// tgOffline
  ///
  /// In en, this message translates to:
  /// **'Can’t reach Telegram'**
  String get tgOffline;

  /// tgPulled
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} message picked up} other{{count} messages picked up}}'**
  String tgPulled(int count);

  /// settingsOutside
  ///
  /// In en, this message translates to:
  /// **'From outside'**
  String get settingsOutside;

  /// selCount
  ///
  /// In en, this message translates to:
  /// **'Selected: {count}'**
  String selCount(int count);

  /// selClear
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get selClear;

  /// selAll
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selAll;

  /// selMove
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get selMove;

  /// selTag
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get selTag;

  /// selUntag
  ///
  /// In en, this message translates to:
  /// **'Untag'**
  String get selUntag;

  /// selDelete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get selDelete;

  /// selMoved
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} note moved to “{folder}”} other{{count} notes moved to “{folder}”}}'**
  String selMoved(int count, String folder);

  /// selDeleted
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} note deleted} other{{count} notes deleted}}'**
  String selDeleted(int count);

  /// selTagged
  ///
  /// In en, this message translates to:
  /// **'Tagged #{tag}'**
  String selTagged(String tag);

  /// selUntagged
  ///
  /// In en, this message translates to:
  /// **'Removed #{tag}'**
  String selUntagged(String tag);

  /// tagPickTitle
  ///
  /// In en, this message translates to:
  /// **'Which tag'**
  String get tagPickTitle;

  /// folderCanvas
  ///
  /// In en, this message translates to:
  /// **'Canvas'**
  String get folderCanvas;

  /// canvasFit
  ///
  /// In en, this message translates to:
  /// **'Fit everything'**
  String get canvasFit;

  /// canvasNote
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get canvasNote;

  /// canvasNoteHint
  ///
  /// In en, this message translates to:
  /// **'What to write on the canvas'**
  String get canvasNoteHint;

  /// graphTitle
  ///
  /// In en, this message translates to:
  /// **'Link graph'**
  String get graphTitle;

  /// graphEmpty
  ///
  /// In en, this message translates to:
  /// **'No links yet. They appear when notes start sharing words or the AI links them.'**
  String get graphEmpty;

  /// graphFailed
  ///
  /// In en, this message translates to:
  /// **'The graph didn’t build'**
  String get graphFailed;

  /// copyPartlyFailed
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} file wasn’t saved: the app didn’t give access} other{{count} files weren’t saved: the app didn’t give access}}'**
  String copyPartlyFailed(int count);

  /// mapTitle
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapTitle;

  /// mapEmpty
  ///
  /// In en, this message translates to:
  /// **'Nothing has a place yet. New notes remember where you saved them and show up here.'**
  String get mapEmpty;

  /// mapWhereAmI
  ///
  /// In en, this message translates to:
  /// **'Where am I'**
  String get mapWhereAmI;

  /// mapPlaceUnnamed
  ///
  /// In en, this message translates to:
  /// **'Unnamed place'**
  String get mapPlaceUnnamed;

  /// placeSetting
  ///
  /// In en, this message translates to:
  /// **'Remember where it was saved'**
  String get placeSetting;

  /// placeSettingHint
  ///
  /// In en, this message translates to:
  /// **'The place is added after saving and shows on the note page and the map. Coordinates stay on the phone; only a street-name lookup goes out.'**
  String get placeSettingHint;

  /// Над найденным: что поиск понял из запроса, например «видео · вчера»
  ///
  /// In en, this message translates to:
  /// **'Looking for: {what}'**
  String panelLooking(Object what);

  /// Подпись у найденного: слово нашлось в названии места, где вещь сохранена
  ///
  /// In en, this message translates to:
  /// **'by place'**
  String get foundAtPlace;

  /// На странице вещи, пока её файл копируется во вложения
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} file is being saved} other{{count} files are being saved}}'**
  String fileSaving(num count);

  /// Пояснение под «Сохраняю файл»
  ///
  /// In en, this message translates to:
  /// **'You can close the app, the file will finish on its own. Once the bar is gone, the original can be deleted.'**
  String get fileSavingHint;

  /// Подпись у найденного: слово нашлось в тексте приложенного документа
  ///
  /// In en, this message translates to:
  /// **'in the file'**
  String get foundInFile;

  /// Подпись у найденного: слово нашлось в авторе или описании страницы ссылки
  ///
  /// In en, this message translates to:
  /// **'on the page'**
  String get foundOnPage;

  /// Подпись у найденного: слово нашлось в камере из EXIF
  ///
  /// In en, this message translates to:
  /// **'in photo details'**
  String get foundInPhotoInfo;

  /// Где в таблице нашлось: имя листа
  ///
  /// In en, this message translates to:
  /// **'sheet “{name}”'**
  String documentSheet(Object name);

  /// Где в презентации нашлось: номер слайда
  ///
  /// In en, this message translates to:
  /// **'slide {number}'**
  String documentSlide(Object number);

  /// Где в книге EPUB нашлось: номер главы
  ///
  /// In en, this message translates to:
  /// **'chapter {number}'**
  String documentChapter(Object number);

  /// Подсказка у телефона из текста вещи
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get factCall;

  /// Подсказка у почты из текста вещи
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get factWrite;

  /// Подсказка у суммы из текста вещи
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get factCopy;

  /// Под заголовком фото: дата съёмки из EXIF, например «Снято 3 мая 2024»
  ///
  /// In en, this message translates to:
  /// **'Taken {date}'**
  String photoTaken(Object date);

  /// Подпись у найденного: слово прозвучало в ролике в это время
  ///
  /// In en, this message translates to:
  /// **'in subtitles · {time}'**
  String foundInSubtitles(Object time);

  /// Подпись у найденного: слово в названии главы ролика
  ///
  /// In en, this message translates to:
  /// **'in chapters · {time}'**
  String foundInChapters(Object time);

  /// Подпись у найденного: слово в ингредиентах рецепта
  ///
  /// In en, this message translates to:
  /// **'in ingredients'**
  String get foundInIngredients;

  /// Подпись у найденного: слово в месте или адресе события, заведения
  ///
  /// In en, this message translates to:
  /// **'by address'**
  String get foundAtAddress;

  /// Подпись у найденного: слово в хэштегах автора
  ///
  /// In en, this message translates to:
  /// **'in hashtags'**
  String get foundInHashtags;

  /// Подсказка у кнопки с временем: открыть ролик с этой секунды
  ///
  /// In en, this message translates to:
  /// **'Watch from here'**
  String get watchFromHere;

  /// Вид страницы ссылки
  ///
  /// In en, this message translates to:
  /// **'recipe'**
  String get pageRecipe;

  /// Вид страницы ссылки
  ///
  /// In en, this message translates to:
  /// **'product'**
  String get pageProduct;

  /// Вид страницы ссылки
  ///
  /// In en, this message translates to:
  /// **'event'**
  String get pageEvent;

  /// Вид страницы ссылки: заведение, магазин, музей
  ///
  /// In en, this message translates to:
  /// **'place'**
  String get pagePlace;

  /// Вид страницы ссылки
  ///
  /// In en, this message translates to:
  /// **'movie'**
  String get pageMovie;

  /// Вид страницы ссылки
  ///
  /// In en, this message translates to:
  /// **'book'**
  String get pageBook;

  /// Вид страницы ссылки
  ///
  /// In en, this message translates to:
  /// **'video'**
  String get pageVideo;

  /// Вид страницы ссылки
  ///
  /// In en, this message translates to:
  /// **'article'**
  String get pageArticle;

  /// Сколько готовить рецепт
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minutesShort(Object count);

  /// Сколько порций в рецепте
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} serving} other{{count} servings}}'**
  String servings(num count);

  /// Сколько читать статью
  ///
  /// In en, this message translates to:
  /// **'{count} min read'**
  String readingMinutes(Object count);

  /// Товар есть
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get inStock;

  /// Товара нет
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get outOfStock;

  /// Кнопка под ингредиентами рецепта
  ///
  /// In en, this message translates to:
  /// **'To shopping list'**
  String get toShoppingList;

  /// Заголовок заметки-списка с ингредиентами рецепта
  ///
  /// In en, this message translates to:
  /// **'Buy: {name}'**
  String shoppingFor(Object name);

  /// Плашка после «В список покупок»
  ///
  /// In en, this message translates to:
  /// **'Shopping list is ready'**
  String get shoppingReady;

  /// Заголовок списка глав ролика
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get chaptersTitle;

  /// Подпись перед хэштегами автора ролика или поста, которые можно поставить тегами
  ///
  /// In en, this message translates to:
  /// **'Author’s tags'**
  String get authorTags;

  /// Вид страницы ссылки: сериал или аниме-сериал
  ///
  /// In en, this message translates to:
  /// **'series'**
  String get pageSeries;

  /// Вид страницы ссылки: манга, манхва, комикс
  ///
  /// In en, this message translates to:
  /// **'comic'**
  String get pageComic;

  /// Переключатель в настройках: показывать ли обложки и описания страниц для взрослых
  ///
  /// In en, this message translates to:
  /// **'Show 18+'**
  String get adultSetting;

  /// Пояснение под переключателем 18+
  ///
  /// In en, this message translates to:
  /// **'Pages that mark themselves as 18+, and well-known adult sites. While this is off, their covers are blurred and descriptions hidden. The note and its search stay.'**
  String get adultSettingHint;

  /// Вместо описания страницы 18+, пока показ выключен
  ///
  /// In en, this message translates to:
  /// **'Description hidden: 18+. You can turn it on in settings.'**
  String get adultHidden;

  /// Заголовок экрана первого запуска
  ///
  /// In en, this message translates to:
  /// **'Where to keep your notes'**
  String get vaultSetupTitle;

  /// Пояснение под заголовком экрана первого запуска
  ///
  /// In en, this message translates to:
  /// **'Notes, photos and files live as plain files in a folder. You can see it in a file manager, open it in Obsidian and sync it with Syncthing.'**
  String get vaultSetupHint;

  /// Первый путь на экране выбора хранилища
  ///
  /// In en, this message translates to:
  /// **'Create a vault'**
  String get vaultCreate;

  /// Пояснение к «Создать хранилище»
  ///
  /// In en, this message translates to:
  /// **'A new folder in phone storage. Your notes stay even if you uninstall the app.'**
  String get vaultCreateHint;

  /// Кнопка «Создать хранилище»
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get vaultCreateButton;

  /// Второй путь на экране выбора хранилища
  ///
  /// In en, this message translates to:
  /// **'Open folder as vault'**
  String get vaultOpen;

  /// Пояснение к «Открыть папку как хранилище»
  ///
  /// In en, this message translates to:
  /// **'Your old Stowa vault after a reinstall, or an Obsidian vault.'**
  String get vaultOpenHint;

  /// Кнопка «Открыть папку как хранилище»
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get vaultOpenButton;

  /// Третий путь на экране выбора хранилища
  ///
  /// In en, this message translates to:
  /// **'Keep inside the app'**
  String get vaultInApp;

  /// Пояснение к «Хранить внутри приложения»
  ///
  /// In en, this message translates to:
  /// **'No permissions. Uninstalling the app deletes your notes.'**
  String get vaultInAppHint;

  /// Кнопка «Хранить внутри приложения»
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get vaultInAppButton;

  /// Предупреждение перед выбором хранилища внутри приложения
  ///
  /// In en, this message translates to:
  /// **'Your notes will live inside the app and disappear if you uninstall it. You can move them to a regular folder later in settings.'**
  String get vaultInAppWarning;

  /// Кнопка подтверждения хранилища внутри приложения
  ///
  /// In en, this message translates to:
  /// **'Keep inside'**
  String get vaultInAppConfirm;

  /// Поле имени нового хранилища
  ///
  /// In en, this message translates to:
  /// **'Vault name'**
  String get vaultName;

  /// Строка выбора папки для нового хранилища
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get vaultPlace;

  /// Заголовок листа с просьбой о разрешении
  ///
  /// In en, this message translates to:
  /// **'File access needed'**
  String get vaultAccessTitle;

  /// Пояснение к разрешению «Доступ ко всем файлам»
  ///
  /// In en, this message translates to:
  /// **'To keep notes in a regular folder, Android asks for “All files access”. Stowa only reads and writes the vault folder.'**
  String get vaultAccessHint;

  /// Кнопка перехода к системному разрешению
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get vaultAccessGrant;

  /// Плашка: разрешение не дали
  ///
  /// In en, this message translates to:
  /// **'Without file access a vault in phone storage can’t work'**
  String get vaultAccessDenied;

  /// Ход переноса хранилища
  ///
  /// In en, this message translates to:
  /// **'Moving: {done} of {total}'**
  String vaultMoving(int done, int total);

  /// Ход сборки указателя из папки
  ///
  /// In en, this message translates to:
  /// **'Building the index: {done} of {total}'**
  String vaultBuilding(int done, int total);

  /// Перенос не сошёлся при сверке
  ///
  /// In en, this message translates to:
  /// **'Not everything moved, missing: {count}. Your notes stayed where they were.'**
  String vaultMoveFailed(int count);

  /// Заголовок экрана, когда папки хранилища нет
  ///
  /// In en, this message translates to:
  /// **'Vault not found'**
  String get vaultMissingTitle;

  /// Пояснение на экране «Хранилище не найдено»
  ///
  /// In en, this message translates to:
  /// **'The folder {path} is gone or Stowa lost file access. The notes in the app are safe.'**
  String vaultMissingHint(String path);

  /// Кнопка на экране «Хранилище не найдено»
  ///
  /// In en, this message translates to:
  /// **'Grant access'**
  String get vaultGrantAccess;

  /// Кнопка выбора другой папки хранилища
  ///
  /// In en, this message translates to:
  /// **'Choose a folder'**
  String get vaultChooseAgain;

  /// Раздел настроек
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get vaultSection;

  /// Строка настроек: где лежит хранилище
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get vaultFolder;

  /// Значение строки «Папка», когда хранилище внутри приложения
  ///
  /// In en, this message translates to:
  /// **'Inside the app'**
  String get vaultInsideApp;

  /// Строка настроек
  ///
  /// In en, this message translates to:
  /// **'Move to another folder'**
  String get vaultMoveTo;

  /// Строка настроек: собрать базу поиска заново из папки
  ///
  /// In en, this message translates to:
  /// **'Rebuild the index'**
  String get vaultRebuild;

  /// Пояснение под разделом «Хранилище»
  ///
  /// In en, this message translates to:
  /// **'Notes are .md files: Obsidian opens this folder and Syncthing syncs it. The index is a search database the app builds by itself.'**
  String get vaultSettingHint;

  /// Плашка после переноса
  ///
  /// In en, this message translates to:
  /// **'Vault moved'**
  String get vaultMoved;

  /// Плашка после сборки указателя
  ///
  /// In en, this message translates to:
  /// **'Index rebuilt'**
  String get vaultRebuilt;

  /// Полоска на главной, пока из папки хранилища забирается много заметок
  ///
  /// In en, this message translates to:
  /// **'Syncing notes {done} of {total}'**
  String vaultSyncing(int done, int total);

  /// Строка на странице заметки: та же ссылка или картинка уже есть в другой заметке
  ///
  /// In en, this message translates to:
  /// **'Same one is in the “{folder}” folder since {date}'**
  String repeatIn(String folder, String date);

  /// То же, когда у другой заметки нет папки
  ///
  /// In en, this message translates to:
  /// **'Same one is unfiled since {date}'**
  String repeatNoFolder(String date);

  /// Раздел настроек: перенос заметок из других мест
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get settingsImport;

  /// Строка настроек: перенос «Избранного» из выгрузки Telegram
  ///
  /// In en, this message translates to:
  /// **'From Telegram'**
  String get importTelegram;

  /// Подсказка под разделом «Перенос»
  ///
  /// In en, this message translates to:
  /// **'Pick a Saved Messages export folder from Telegram Desktop, HTML or JSON. Notes keep their dates, an album becomes one note.'**
  String get importTelegramHint;

  /// Ход переноса
  ///
  /// In en, this message translates to:
  /// **'Importing {done} of {total}'**
  String importProgress(int done, int total);

  /// Итог переноса
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} note imported} other{{count} notes imported}}'**
  String importDone(int count);

  /// Добавка к итогу: сколько сообщений уже переносили
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} was already here} other{{count} were already here}}'**
  String importRepeated(int count);

  /// Перенос не начался: выбрана не та папка
  ///
  /// In en, this message translates to:
  /// **'No Telegram export in this folder: messages.html or result.json is needed'**
  String get importNotTelegram;

  /// Добавка к итогу переноса: Telegram не выгрузил часть файлов
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} file was left out of the export} other{{count} files were left out of the export}} — turn files on in the export settings and import again'**
  String importMissing(int count);

  /// Добавка к итогу: файлы новой выгрузки легли к заметкам, перенесённым раньше без них
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} earlier note got its files} other{{count} earlier notes got their files}}'**
  String importFilled(int count);

  /// Канал уведомлений: что из сохранённого вернуть
  ///
  /// In en, this message translates to:
  /// **'Coming back'**
  String get returnChannel;

  /// Заголовок уведомления и экрана очереди
  ///
  /// In en, this message translates to:
  /// **'Watch later'**
  String get returnWatchTitle;

  /// Сколько роликов в очереди
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} video} other{{count} videos}}'**
  String returnVideos(int count);

  /// Сколько статей в очереди
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} article} other{{count} articles}}'**
  String returnArticles(int count);

  /// Сколько минут займёт очередь
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} minute} other{{count} minutes}}'**
  String returnMinutes(int count);

  /// Два куска через «и»: «3 ролика и статья»
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String returnAnd(String first, String second);

  /// Текст уведомления очереди: «3 ролика и статья — 24 минуты»
  ///
  /// In en, this message translates to:
  /// **'{what} — {minutes}'**
  String returnWatchBody(String what, String minutes);

  /// «В этот день»: сколько лет назад
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{A year ago} other{{count} years ago}}'**
  String returnYearsAgo(int count);

  /// «В этот день»: месяц назад
  ///
  /// In en, this message translates to:
  /// **'A month ago'**
  String get returnMonthAgo;

  /// «В этот день»: неделю назад
  ///
  /// In en, this message translates to:
  /// **'A week ago'**
  String get returnWeekAgo;

  /// «В этот день», одна заметка
  ///
  /// In en, this message translates to:
  /// **'“{title}”'**
  String returnDayOne(String title);

  /// «В этот день», несколько заметок
  ///
  /// In en, this message translates to:
  /// **'“{title}” and {count} more'**
  String returnDayMore(String title, int count);

  /// Экран и настройка «В этот день»
  ///
  /// In en, this message translates to:
  /// **'On this day'**
  String get returnOnThisDay;

  /// Заголовок сводки недели
  ///
  /// In en, this message translates to:
  /// **'Your week in Stowa'**
  String get returnWeekTitle;

  /// Сводка: сколько сохранено
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} note this week} other{{count} notes this week}}'**
  String returnWeekSaved(int count);

  /// Сводка: сколько не открыто
  ///
  /// In en, this message translates to:
  /// **'{count} unopened'**
  String returnWeekUnopened(int count);

  /// Сводка: сколько без папки
  ///
  /// In en, this message translates to:
  /// **'{count} without a folder'**
  String returnWeekUnsorted(int count);

  /// Раздел экрана сводки
  ///
  /// In en, this message translates to:
  /// **'Not opened yet'**
  String get returnWeekUnopenedTitle;

  /// Раздел экрана сводки
  ///
  /// In en, this message translates to:
  /// **'Without a folder'**
  String get returnWeekUnsortedTitle;

  /// Уведомление покупок у отмеченного магазина
  ///
  /// In en, this message translates to:
  /// **'At {shop}'**
  String returnShopTitle(String shop);

  /// Покупки: первые пункты и сколько ещё
  ///
  /// In en, this message translates to:
  /// **'{items} and {count} more'**
  String returnShopMore(String items, int count);

  /// Экран и настройка покупок у магазина
  ///
  /// In en, this message translates to:
  /// **'To buy'**
  String get returnShopping;

  /// Раздел настроек: что из сохранённого возвращать уведомлениями
  ///
  /// In en, this message translates to:
  /// **'Bring back'**
  String get settingsReturns;

  /// Переключатель сводки недели
  ///
  /// In en, this message translates to:
  /// **'Weekly summary'**
  String get returnWeekSetting;

  /// Переключатель покупок у магазина
  ///
  /// In en, this message translates to:
  /// **'Shopping near a store'**
  String get returnShoppingSetting;

  /// Строка: с какого часа вечером можно напомнить
  ///
  /// In en, this message translates to:
  /// **'In the evening at'**
  String get returnEveningRow;

  /// Строка: когда не беспокоить
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get returnQuietRow;

  /// Строка: в какой день недели сводка
  ///
  /// In en, this message translates to:
  /// **'Summary day'**
  String get returnWeekDayRow;

  /// Подсказка под разделом «Возвращать»
  ///
  /// In en, this message translates to:
  /// **'At most one notification a day, silent, and nothing during quiet hours. Reminders you set yourself by time or place don’t count.'**
  String get returnSettingsHint;

  /// Промежуток времени: «22:00–08:00»
  ///
  /// In en, this message translates to:
  /// **'{from}–{to}'**
  String returnRange(String from, String to);

  /// Выбор начала тихих часов
  ///
  /// In en, this message translates to:
  /// **'Quiet from'**
  String get returnQuietFrom;

  /// Выбор конца тихих часов
  ///
  /// In en, this message translates to:
  /// **'Quiet until'**
  String get returnQuietTo;

  /// Пустая очередь «посмотреть потом»
  ///
  /// In en, this message translates to:
  /// **'The queue is empty: you’ve seen everything recent.'**
  String get returnWatchEmpty;

  /// Пустой экран «В этот день»
  ///
  /// In en, this message translates to:
  /// **'Nothing was saved on this day before.'**
  String get returnDayEmpty;

  /// Пустая сводка недели
  ///
  /// In en, this message translates to:
  /// **'Nothing saved this week.'**
  String get returnWeekEmpty;

  /// Пустой экран покупок
  ///
  /// In en, this message translates to:
  /// **'Nothing to buy: every list is checked off.'**
  String get returnShoppingEmpty;

  /// Коротко минуты на пилюле главной
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String returnMinutesShort(int count);

  /// Карточка на главной: спросить про уведомления
  ///
  /// In en, this message translates to:
  /// **'Bring saved things back?'**
  String get returnsAskTitle;

  /// Карточка на главной: что будет
  ///
  /// In en, this message translates to:
  /// **'One silent notification in the evening: what to watch, what you saved on this day a year ago, a weekly summary. Never more than once a day.'**
  String get returnsAskBody;

  /// Кнопка карточки: разрешить уведомления
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get returnsAskOn;

  /// Кнопка карточки: скрыть
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get returnsAskLater;

  /// Чип и пункт: напоминание дома
  ///
  /// In en, this message translates to:
  /// **'Remind at home'**
  String get placeRemindHome;

  /// Чип и пункт: напоминание на работе
  ///
  /// In en, this message translates to:
  /// **'Remind at work'**
  String get placeRemindWork;

  /// Чип и пункт: напоминание в этой точке
  ///
  /// In en, this message translates to:
  /// **'Remind me here'**
  String get placeRemindHere;

  /// Чип и пункт: напоминание у любого отмеченного магазина
  ///
  /// In en, this message translates to:
  /// **'Remind at a store'**
  String get placeRemindShop;

  /// Напоминание в точке с названием
  ///
  /// In en, this message translates to:
  /// **'Remind at {place}'**
  String placeRemindAt(String place);

  /// Крестик на чипе места
  ///
  /// In en, this message translates to:
  /// **'No place reminder'**
  String get composerRemovePlace;

  /// Экран и строка настроек: дом, работа, магазины
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get placesTitle;

  /// Место: дом
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get placesHome;

  /// Место: работа
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get placesWork;

  /// Раздел мест: магазины
  ///
  /// In en, this message translates to:
  /// **'Stores'**
  String get placesShops;

  /// Место ещё не отмечено
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get placesNotSet;

  /// Сеть дома или работы
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi: {name}'**
  String placesWifi(String name);

  /// Отметить дом там, где телефон сейчас
  ///
  /// In en, this message translates to:
  /// **'I’m home now'**
  String get placesImHome;

  /// Отметить работу там, где телефон сейчас
  ///
  /// In en, this message translates to:
  /// **'I’m at work now'**
  String get placesImWork;

  /// Отметить магазин там, где телефон сейчас
  ///
  /// In en, this message translates to:
  /// **'I’m at a store — save it'**
  String get placesImShop;

  /// Подсказка дома по сохранённым заметкам
  ///
  /// In en, this message translates to:
  /// **'Looks like home is {name}'**
  String placesGuessHome(String name);

  /// Подсказка работы по сохранённым заметкам
  ///
  /// In en, this message translates to:
  /// **'Looks like work is {name}'**
  String placesGuessWork(String name);

  /// Убрать отмеченное место
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get placesRemove;

  /// Окно названия магазина
  ///
  /// In en, this message translates to:
  /// **'Store name'**
  String get placesShopName;

  /// Кнопка окна названия магазина
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get placesSave;

  /// Место не определилось
  ///
  /// In en, this message translates to:
  /// **'Couldn’t find where you are. Check that location is on and allowed for Stowa.'**
  String get placesNoFix;

  /// Карточка разрешения на место в фоне
  ///
  /// In en, this message translates to:
  /// **'Location “all the time” is needed'**
  String get placesPermissionTitle;

  /// Зачем место «всегда»
  ///
  /// In en, this message translates to:
  /// **'Android wakes Stowa at the right spot and shows the Wi-Fi name only if location is allowed “all the time”. Coordinates stay on your phone.'**
  String get placesPermissionBody;

  /// Кнопка разрешения на место в фоне
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get placesPermissionAllow;

  /// Подсказка внизу экрана мест
  ///
  /// In en, this message translates to:
  /// **'Places are used for “remind me at home”, “at work” and “at a store”. Notes tagged #buy come up at your saved stores, at most once a day.'**
  String get placesHint;

  /// Сколько магазинов отмечено
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} store} other{{count} stores}}'**
  String placesShopsCount(int count);

  /// Пункт листа «Напомнить»: выбрать день и время
  ///
  /// In en, this message translates to:
  /// **'At a time'**
  String get itemRemindTime;

  /// Сменить место напоминания
  ///
  /// In en, this message translates to:
  /// **'Another place'**
  String get itemPlaceChange;

  /// Напоминание дома, а дом не отмечен
  ///
  /// In en, this message translates to:
  /// **'Home isn’t set yet: Stowa will remind you once you set it in Places'**
  String get placesMissingHome;

  /// Напоминание на работе, а работа не отмечена
  ///
  /// In en, this message translates to:
  /// **'Work isn’t set yet: Stowa will remind you once you set it in Places'**
  String get placesMissingWork;

  /// Напоминание в магазине, а магазинов нет
  ///
  /// In en, this message translates to:
  /// **'No stores yet: save at least one in Places'**
  String get placesMissingShop;

  /// Канал уведомлений Android: напоминания дома, на работе, в магазине, в точке
  ///
  /// In en, this message translates to:
  /// **'Place reminders'**
  String get placeChannel;

  /// Плашка после напоминания по месту, когда нет разрешения на место «всегда»
  ///
  /// In en, this message translates to:
  /// **'I\'ll remind you there if location is allowed all the time'**
  String get remindPlaceNeedsAlways;

  /// Подпись ряда цветов в листе вида папки
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get lookColor;

  /// Пилюля на главной: показать остальные папки
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String homeFoldersMore(Object count);

  /// Под пунктами списка в ленте главной: сколько пунктов не показано
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String homeChecksMore(Object count);

  /// Кнопка на главной и заголовок экрана: все папки и заметки деревом
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get catalogTitle;

  /// Подсказка кнопки каталога
  ///
  /// In en, this message translates to:
  /// **'Expand all'**
  String get catalogExpand;

  /// Подсказка кнопки каталога
  ///
  /// In en, this message translates to:
  /// **'Collapse all'**
  String get catalogCollapse;

  /// Подсказка стрелки у папки в каталоге
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get catalogOpenFolder;

  /// Подпись под именем приложения на главной
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} folder} other{{count} folders}}'**
  String foldersCount(num count);

  /// Кнопка открыть статью в читалке; count — минут чтения
  ///
  /// In en, this message translates to:
  /// **'Read · {count} min'**
  String readerOpen(Object count);

  /// Открыть статью на сайте
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get readerOriginal;

  /// Сделать выделенный текст цитатой
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get readerQuote;

  /// Скопировать выделенный текст
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get readerCopy;

  /// Написать пометку к цитате
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get readerNote;

  /// Подсказка в поле пометки
  ///
  /// In en, this message translates to:
  /// **'Note for this quote'**
  String get readerNoteHint;

  /// Убрать цитату
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get readerRemove;

  /// Плашка после удаления цитаты
  ///
  /// In en, this message translates to:
  /// **'Quote removed'**
  String get readerRemoved;

  /// Сайт удалил страницу, а у нас копия
  ///
  /// In en, this message translates to:
  /// **'Original removed · copy saved'**
  String get readerGone;

  /// В читалке нет копии статьи
  ///
  /// In en, this message translates to:
  /// **'The article text wasn\'t saved. You can open it on the site.'**
  String get readerNoCopy;

  /// На месте картинки статьи, которую не скачивали
  ///
  /// In en, this message translates to:
  /// **'Image not saved'**
  String get readerImageOff;

  /// Блок цитат на странице заметки
  ///
  /// In en, this message translates to:
  /// **'Quotes'**
  String get highlightsTitle;

  /// Метка мёртвой ссылки без копии статьи
  ///
  /// In en, this message translates to:
  /// **'Link no longer opens'**
  String get linkGone;

  /// Экран и пункт настроек
  ///
  /// In en, this message translates to:
  /// **'Broken links'**
  String get deadLinksTitle;

  /// Пояснение над списком битых ссылок
  ///
  /// In en, this message translates to:
  /// **'Once a week on Wi-Fi, Stowa checks your saved links. Pages the site removed end up here.'**
  String get deadLinksAbout;

  /// Битых ссылок нет
  ///
  /// In en, this message translates to:
  /// **'All links open'**
  String get deadLinksEmpty;

  /// Проверить все ссылки сейчас
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get deadLinksCheck;

  /// Идёт проверка ссылок
  ///
  /// In en, this message translates to:
  /// **'Checking links…'**
  String get deadLinksChecking;

  /// Оставить заметку с копией, убрать из списка битых
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get deadLinksKeep;

  /// Удалить заметку с мёртвой ссылкой в корзину
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deadLinksDelete;

  /// Плашка после удаления
  ///
  /// In en, this message translates to:
  /// **'Note moved to trash'**
  String get deadLinksDeleted;

  /// Сколько битых ссылок, подпись пункта настроек
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} doesn\'t open} other{{count} don\'t open}}'**
  String deadLinksCount(int count);

  /// Раздел настроек
  ///
  /// In en, this message translates to:
  /// **'Articles'**
  String get settingsArticles;

  /// Включатель скачивания картинок статей
  ///
  /// In en, this message translates to:
  /// **'Article images'**
  String get articleImages;

  /// Подпись включателя картинок статей
  ///
  /// In en, this message translates to:
  /// **'Download on Wi-Fi to read articles with images offline'**
  String get articleImagesAbout;

  /// Где нашлось: в сохранённом тексте статьи
  ///
  /// In en, this message translates to:
  /// **'in the article'**
  String get foundInArticle;

  /// Где нашлось: в цитате или пометке к ней
  ///
  /// In en, this message translates to:
  /// **'in a quote'**
  String get foundInQuote;

  /// Раздел настроек: что открывается при запуске
  ///
  /// In en, this message translates to:
  /// **'On launch'**
  String get settingsStart;

  /// Строка настроек: что открывать при запуске
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get startOpen;

  /// При запуске открывать главную
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get startHome;

  /// При запуске открывать последнюю открытую заметку
  ///
  /// In en, this message translates to:
  /// **'Last note'**
  String get startLast;

  /// При запуске открывать случайную заметку
  ///
  /// In en, this message translates to:
  /// **'Random note'**
  String get startRandom;

  /// Пояснение под выбором запуска
  ///
  /// In en, this message translates to:
  /// **'Last picks up where you left off. Random brings back something you saved each time you open the app, so it sticks better.'**
  String get startHint;

  /// Раздел настроек: тема, цвет, AMOLED
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// Заголовок раздела режима темы
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get appearanceTheme;

  /// Режим темы
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Режим темы
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Режим темы
  ///
  /// In en, this message translates to:
  /// **'Same as system'**
  String get themeSystem;

  /// Режим темы
  ///
  /// In en, this message translates to:
  /// **'By time of day'**
  String get themeByTime;

  /// Подсказка под режимом «по времени»
  ///
  /// In en, this message translates to:
  /// **'Dark from 20:00 to 7:00'**
  String get themeByTimeHint;

  /// Заголовок раздела цвета темы
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get appearanceColor;

  /// Цвет темы по умолчанию: серые ступени
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get colorGraphite;

  /// Выбор своего цвета темы
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get colorCustom;

  /// Цвет темы взят с обоев, коротко для подписи
  ///
  /// In en, this message translates to:
  /// **'From wallpaper'**
  String get colorFromWallpaper;

  /// Насыщенность цветной темы
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get colorIntensity;

  /// Цвет красит и поверхности
  ///
  /// In en, this message translates to:
  /// **'Vivid'**
  String get intensityVibrant;

  /// Акцент ровно выбранный цвет, поверхности серые
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get intensityFaithful;

  /// Пояснение к насыщенности
  ///
  /// In en, this message translates to:
  /// **'Vivid tints the background too. Exact keeps it gray and paints buttons in exactly your color.'**
  String get intensityHint;

  /// Material You: цвет темы с обоев
  ///
  /// In en, this message translates to:
  /// **'Wallpaper colors'**
  String get wallpaperColors;

  /// Подпись к цветам из обоев
  ///
  /// In en, this message translates to:
  /// **'The theme follows your phone wallpaper'**
  String get wallpaperColorsHint;

  /// AMOLED: чистый чёрный в тёмной теме
  ///
  /// In en, this message translates to:
  /// **'Black background'**
  String get amoledTitle;

  /// Подпись к чёрному фону
  ///
  /// In en, this message translates to:
  /// **'Pure black for AMOLED screens, saves battery'**
  String get amoledHint;

  /// Применить свой цвет
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get pickerApply;

  /// Цвет темы
  ///
  /// In en, this message translates to:
  /// **'Coral'**
  String get colorCoral;

  /// Цвет темы
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get colorAmber;

  /// Цвет темы
  ///
  /// In en, this message translates to:
  /// **'Lime'**
  String get colorLime;

  /// Цвет темы
  ///
  /// In en, this message translates to:
  /// **'Mint'**
  String get colorMint;

  /// Цвет темы
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get colorTeal;

  /// Цвет темы
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// Цвет темы
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get colorViolet;

  /// Цвет темы
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get colorRose;

  /// Folder menu: create a subfolder
  ///
  /// In en, this message translates to:
  /// **'New folder inside'**
  String get folderNewInside;

  /// Folder menu: put this folder inside another one
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get folderMoveTo;

  /// Move target: make the folder top-level
  ///
  /// In en, this message translates to:
  /// **'To the top'**
  String get folderMoveTop;

  /// Move sheet: no valid targets
  ///
  /// In en, this message translates to:
  /// **'Nowhere to move: folders nest up to three levels'**
  String get folderMoveNone;

  /// Note menu item and screen title: earlier versions of the note
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// History: the current state of the note
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get historyNow;

  /// History screen: how versions are made
  ///
  /// In en, this message translates to:
  /// **'The earlier text is kept when you edit the note after a break. The last 50 versions or all from 30 days are kept.'**
  String get historyHint;

  /// History: version text equals current, only the title differs
  ///
  /// In en, this message translates to:
  /// **'Same text'**
  String get historyNoChanges;

  /// Version screen tab: full text of the version
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get historyText;

  /// Version screen tab: what changed between the version and now
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get historyDiff;

  /// Version screen: legend of the diff
  ///
  /// In en, this message translates to:
  /// **'Struck out: was in this version. Highlighted: added since'**
  String get historyDiffHint;

  /// Version screen button
  ///
  /// In en, this message translates to:
  /// **'Restore this version'**
  String get historyRestore;

  /// Snackbar after restoring a version
  ///
  /// In en, this message translates to:
  /// **'Version restored'**
  String get historyRestored;
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
