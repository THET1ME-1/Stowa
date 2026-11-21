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

  /// Причина под «Закинуть»: папки нет
  ///
  /// In en, this message translates to:
  /// **'no folder yet, I\'ll sort it later'**
  String get reasonNone;

  /// Why no folder
  ///
  /// In en, this message translates to:
  /// **'unsorted, as asked'**
  String get reasonAsIs;

  /// Главная кнопка строки: сохранить
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

  /// Команда строки после «/», одно слово без пробелов
  ///
  /// In en, this message translates to:
  /// **'remind'**
  String get cmdRemind;

  /// Команда строки после «/», одно слово без пробелов
  ///
  /// In en, this message translates to:
  /// **'task'**
  String get cmdTask;

  /// Команда строки после «/», одно слово без пробелов
  ///
  /// In en, this message translates to:
  /// **'list'**
  String get cmdList;

  /// Команда строки после «/», одно слово без пробелов
  ///
  /// In en, this message translates to:
  /// **'find'**
  String get cmdFind;

  /// Команда строки после «/»: положить как есть, без разбора; одно слово
  ///
  /// In en, this message translates to:
  /// **'inbox'**
  String get cmdInbox;

  /// Подсказка к команде «напомнить»
  ///
  /// In en, this message translates to:
  /// **'Say when: “tomorrow at 10”, “on fri”'**
  String get cmdRemindHint;

  /// Подсказка к команде «задача»
  ///
  /// In en, this message translates to:
  /// **'Saved with a checkbox'**
  String get cmdTaskHint;

  /// Подсказка к команде «список»
  ///
  /// In en, this message translates to:
  /// **'Every line or comma becomes an item'**
  String get cmdListHint;

  /// Подсказка к команде «найти»
  ///
  /// In en, this message translates to:
  /// **'Only search, save nothing'**
  String get cmdFindHint;

  /// Подсказка к команде «входящие»
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

  /// Tooltip on the recording pill over other apps: folds it into a small circle, recording goes on
  ///
  /// In en, this message translates to:
  /// **'Minimize recording'**
  String get voiceFold;

  /// Accessibility label of the circle a folded recording pill becomes
  ///
  /// In en, this message translates to:
  /// **'Expand recording'**
  String get voiceUnfold;

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
  /// **'Add your own key and notes without a folder sort themselves.'**
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
  /// **'Get a key from your provider: on OpenRouter it is under Keys, and free models are available.'**
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
  /// **'An OpenAI-compatible API address, empty means OpenRouter.'**
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
  /// **'All your notes, folders and files in one file, without the AI key.'**
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
  /// **'The place shows on the note and the map, and only a street-name lookup leaves the phone.'**
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
  /// **'You can close the app, and delete the original once the bar is gone.'**
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
  /// **'While this is off, covers and descriptions of 18+ pages stay hidden.'**
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

  /// Пояснение под заголовком первого экрана «Где хранить заметки»
  ///
  /// In en, this message translates to:
  /// **'Not sure what to pick? Tap “Create”: it\'s a regular folder on your phone.'**
  String get vaultSetupHint;

  /// Первый путь на экране выбора хранилища
  ///
  /// In en, this message translates to:
  /// **'Create a vault'**
  String get vaultCreate;

  /// Пояснение к «Создать хранилище»
  ///
  /// In en, this message translates to:
  /// **'A new folder in phone storage: your notes stay even if you uninstall the app.'**
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
  /// **'No permissions, but uninstalling the app deletes your notes.'**
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
  /// **'To keep notes in a regular folder Android asks for “All files access”, but Stowa only touches its own folder.'**
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
  /// **'Notes are plain .md files that Obsidian can open too.'**
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
  /// **'Pick the Saved Messages export folder from Telegram Desktop.'**
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

  /// Раздел настроек: вечерние уведомления, тихие часы и места
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
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
  /// **'At most one silent notification a day.'**
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
  /// **'Bring saved notes back?'**
  String get returnsAskTitle;

  /// Карточка на главной: что будет
  ///
  /// In en, this message translates to:
  /// **'One silent notification in the evening reminds you of what you saved.'**
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
  /// **'Reminders at a place only work if location is allowed “all the time”.'**
  String get placesPermissionBody;

  /// Кнопка разрешения на место в фоне
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get placesPermissionAllow;

  /// Подсказка под списком мест
  ///
  /// In en, this message translates to:
  /// **'Write “remind me at the pharmacy” and Stowa will remind you there.'**
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
  /// **'Once a week Stowa checks your links and lists pages the site removed here.'**
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
  /// **'The last note picks up where you left off, a random one brings back something you saved.'**
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
  /// **'Vivid tints the background too, Exact keeps it gray.'**
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
  /// **'The earlier text is kept when you edit a note after a break.'**
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

  /// Folder sort: by main color of pictures
  ///
  /// In en, this message translates to:
  /// **'By color'**
  String get sortByColor;

  /// Chip for a Wi-Fi QR code on a photo
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi “{network}”'**
  String qrWifi(String network);

  /// Tooltip of the Wi-Fi QR chip
  ///
  /// In en, this message translates to:
  /// **'Copy Wi-Fi password'**
  String get qrCopyPassword;

  /// Note after copying a Wi-Fi password from a QR code
  ///
  /// In en, this message translates to:
  /// **'Password copied'**
  String get qrPasswordCopied;

  /// Tooltip of the link QR chip
  ///
  /// In en, this message translates to:
  /// **'Open the link from the QR code'**
  String get qrOpenLink;

  /// Tooltip of the text QR chip
  ///
  /// In en, this message translates to:
  /// **'Copy the QR code text'**
  String get qrCopyText;

  /// Search hit: found in a QR code on a photo
  ///
  /// In en, this message translates to:
  /// **'in a QR code'**
  String get foundInQr;

  /// Where in a PDF the search hit is
  ///
  /// In en, this message translates to:
  /// **'page {number}'**
  String documentPage(String number);

  /// Пункт настроек: по какому дню называть фото без подписи
  ///
  /// In en, this message translates to:
  /// **'Photo and video names'**
  String get titleDateSetting;

  /// titleDateShot
  ///
  /// In en, this message translates to:
  /// **'By date taken'**
  String get titleDateShot;

  /// titleDateSaved
  ///
  /// In en, this message translates to:
  /// **'By date saved'**
  String get titleDateSaved;

  /// titleDateHint
  ///
  /// In en, this message translates to:
  /// **'Photos and videos without a caption get a date in their name.'**
  String get titleDateHint;

  /// Кнопка пароля из текста: сам пароль спрятан точками
  ///
  /// In en, this message translates to:
  /// **'Password ••••••'**
  String get factPassword;

  /// Пароль с именем сети рядом
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi “{network}” ••••••'**
  String factPasswordFor(String network);

  /// factCopyPassword
  ///
  /// In en, this message translates to:
  /// **'Copy password'**
  String get factCopyPassword;

  /// Карта лояльности: последние четыре цифры
  ///
  /// In en, this message translates to:
  /// **'Card ••{last}'**
  String factCard(String last);

  /// factCopyCard
  ///
  /// In en, this message translates to:
  /// **'Copy card number'**
  String get factCopyCard;

  /// factPromo
  ///
  /// In en, this message translates to:
  /// **'Promo code {code}'**
  String factPromo(String code);

  /// factCopyPromo
  ///
  /// In en, this message translates to:
  /// **'Copy promo code'**
  String get factCopyPromo;

  /// factTrack
  ///
  /// In en, this message translates to:
  /// **'Track parcel'**
  String get factTrack;

  /// factOnMap
  ///
  /// In en, this message translates to:
  /// **'Open in maps'**
  String get factOnMap;

  /// Конец рабочего дня: «после работы» в строке ставит напоминание на это время
  ///
  /// In en, this message translates to:
  /// **'Work ends at'**
  String get workEndRow;

  /// Кнопка: «купить молоко, хлеб и яйца» превращается в список галочек
  ///
  /// In en, this message translates to:
  /// **'Make a shopping list'**
  String get toChecklist;

  /// toChecklistHint
  ///
  /// In en, this message translates to:
  /// **'Turn items into checkboxes'**
  String get toChecklistHint;

  /// toChecklistDone
  ///
  /// In en, this message translates to:
  /// **'Shopping list ready'**
  String get toChecklistDone;

  /// Сумма цен из заметок папки под её заголовком
  ///
  /// In en, this message translates to:
  /// **'Total {sum}'**
  String folderTotal(String sum);

  /// Кнопка у «Ищу: …»: сохранить запрос умной папкой на главной
  ///
  /// In en, this message translates to:
  /// **'Smart folder'**
  String get smartSave;

  /// smartSaved
  ///
  /// In en, this message translates to:
  /// **'Smart folder “{name}” is on the home screen'**
  String smartSaved(String name);

  /// smartEmpty
  ///
  /// In en, this message translates to:
  /// **'Nothing matches this search yet'**
  String get smartEmpty;

  /// smartDelete
  ///
  /// In en, this message translates to:
  /// **'Delete smart folder'**
  String get smartDelete;

  /// smartDeleted
  ///
  /// In en, this message translates to:
  /// **'Smart folder “{name}” deleted, notes are untouched'**
  String smartDeleted(String name);

  /// suggestSite
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} link} other{{count} links}} from {site} without a folder'**
  String suggestSite(int count, String site);

  /// suggestScreenshots
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} screenshot} other{{count} screenshots}} without a folder'**
  String suggestScreenshots(int count);

  /// suggestVideos
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} video} other{{count} videos}} without a folder'**
  String suggestVideos(int count);

  /// suggestFiles
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} file} other{{count} files}} without a folder'**
  String suggestFiles(int count);

  /// suggestVoices
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} voice note} other{{count} voice notes}} without a folder'**
  String suggestVoices(int count);

  /// suggestSiteBody
  ///
  /// In en, this message translates to:
  /// **'Make a folder “{name}”? New links from this site will go there on their own.'**
  String suggestSiteBody(String name);

  /// suggestBody
  ///
  /// In en, this message translates to:
  /// **'Make a folder “{name}” and move them there?'**
  String suggestBody(String name);

  /// suggestYes
  ///
  /// In en, this message translates to:
  /// **'Make it'**
  String get suggestYes;

  /// suggestNo
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get suggestNo;

  /// suggestDone
  ///
  /// In en, this message translates to:
  /// **'Folder “{name}”: {count, plural, one{{count} note} other{{count} notes}}'**
  String suggestDone(String name, int count);

  /// suggestScreenshotsName
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get suggestScreenshotsName;

  /// suggestVideosName
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get suggestVideosName;

  /// suggestFilesName
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get suggestFilesName;

  /// suggestVoicesName
  ///
  /// In en, this message translates to:
  /// **'Voice notes'**
  String get suggestVoicesName;

  /// Условие правила после «Если»: вид страницы ссылки — рецепт, товар, событие
  ///
  /// In en, this message translates to:
  /// **'page is a'**
  String get ruleIfPage;

  /// ruleIfPriceAbove
  ///
  /// In en, this message translates to:
  /// **'price over'**
  String get ruleIfPriceAbove;

  /// ruleIfPriceBelow
  ///
  /// In en, this message translates to:
  /// **'price under'**
  String get ruleIfPriceBelow;

  /// ruleValuePrice
  ///
  /// In en, this message translates to:
  /// **'Amount, e.g. 1000'**
  String get ruleValuePrice;

  /// rulePriceAboveValue
  ///
  /// In en, this message translates to:
  /// **'over {value}'**
  String rulePriceAboveValue(String value);

  /// rulePriceBelowValue
  ///
  /// In en, this message translates to:
  /// **'under {value}'**
  String rulePriceBelowValue(String value);

  /// ruleThenRemind
  ///
  /// In en, this message translates to:
  /// **'remind'**
  String get ruleThenRemind;

  /// remindHourBefore
  ///
  /// In en, this message translates to:
  /// **'an hour before'**
  String get remindHourBefore;

  /// remindDayBefore
  ///
  /// In en, this message translates to:
  /// **'a day before'**
  String get remindDayBefore;

  /// remindWeekBefore
  ///
  /// In en, this message translates to:
  /// **'a week before'**
  String get remindWeekBefore;

  /// Too many wrong codes: input closed for seconds
  ///
  /// In en, this message translates to:
  /// **'Wait {seconds} s'**
  String codeWait(Object seconds);

  /// Fingerprint key on the code pad
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get codeFingerprint;

  /// Backspace key on the code pad
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get codeErase;

  /// Confirm the code
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get codeDone;

  /// Code check failed
  ///
  /// In en, this message translates to:
  /// **'Wrong code'**
  String get codeWrong;

  /// First step of creating the Stowa code
  ///
  /// In en, this message translates to:
  /// **'Create a code'**
  String get codeCreateTitle;

  /// Second step: repeat the new code
  ///
  /// In en, this message translates to:
  /// **'Repeat the code'**
  String get codeRepeatTitle;

  /// Under the create code title
  ///
  /// In en, this message translates to:
  /// **'6 to 12 digits: if you forget the code, hidden notes are gone for good.'**
  String get codeCreateHint;

  /// Repeated code differs
  ///
  /// In en, this message translates to:
  /// **'Codes don\'t match. Create it again'**
  String get codeMismatch;

  /// Fingerprint prompt text for hidden folders
  ///
  /// In en, this message translates to:
  /// **'Open hidden folders'**
  String get hiddenOpenReason;

  /// Code page title when opening hidden folders
  ///
  /// In en, this message translates to:
  /// **'Code for hidden folders'**
  String get hiddenOpenTitle;

  /// Button under the code pad
  ///
  /// In en, this message translates to:
  /// **'Forgot the code'**
  String get codeForgot;

  /// Change code, step one
  ///
  /// In en, this message translates to:
  /// **'Current code'**
  String get codeOldTitle;

  /// Change code, step two
  ///
  /// In en, this message translates to:
  /// **'New code'**
  String get codeNewTitle;

  /// After changing the code
  ///
  /// In en, this message translates to:
  /// **'Code changed'**
  String get codeChanged;

  /// Forgot code confirmation title
  ///
  /// In en, this message translates to:
  /// **'Remove the code?'**
  String get codeForgetTitle;

  /// Forgot code confirmation text
  ///
  /// In en, this message translates to:
  /// **'The lock turns off and hidden folders are erased together with their notes. They can\'t be brought back.'**
  String get codeForgetText;

  /// Forgot code confirmation button
  ///
  /// In en, this message translates to:
  /// **'Remove code and erase hidden'**
  String get codeForgetAction;

  /// After hiding a folder
  ///
  /// In en, this message translates to:
  /// **'Folder “{name}” is hidden'**
  String folderHidden(Object name);

  /// After unhiding a folder
  ///
  /// In en, this message translates to:
  /// **'Folder “{name}” is visible again'**
  String folderUnhidden(Object name);

  /// Fingerprint prompt text for the app lock
  ///
  /// In en, this message translates to:
  /// **'Unlock Stowa'**
  String get lockReason;

  /// App lock screen title
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get lockTitle;

  /// Code page title to turn on fingerprint
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get codeEnterTitle;

  /// Lock again right after leaving the app
  ///
  /// In en, this message translates to:
  /// **'Right away'**
  String get closeAfterNow;

  /// Lock again after one minute
  ///
  /// In en, this message translates to:
  /// **'After 1 minute'**
  String get closeAfterMinute;

  /// Lock again after 5 or 15 minutes
  ///
  /// In en, this message translates to:
  /// **'After {minutes} minutes'**
  String closeAfterMinutes(Object minutes);

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacySection;

  /// Settings row when there is no code
  ///
  /// In en, this message translates to:
  /// **'Create a code'**
  String get codeCreateRow;

  /// Settings switch: app lock
  ///
  /// In en, this message translates to:
  /// **'Code on launch'**
  String get appLockRow;

  /// Settings switch: fingerprint instead of the code
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get fingerprintRow;

  /// Settings row: when to lock again after leaving
  ///
  /// In en, this message translates to:
  /// **'Lock again'**
  String get closeAfterRow;

  /// Close hidden folders now
  ///
  /// In en, this message translates to:
  /// **'Close hidden folders'**
  String get hiddenCloseRow;

  /// Open hidden folders
  ///
  /// In en, this message translates to:
  /// **'Open hidden folders'**
  String get hiddenOpenRow;

  /// Settings row
  ///
  /// In en, this message translates to:
  /// **'Change code'**
  String get codeChangeRow;

  /// Under the privacy settings
  ///
  /// In en, this message translates to:
  /// **'Hidden folders are encrypted and can\'t be read without the code.'**
  String get privacyHint;

  /// Settings row
  ///
  /// In en, this message translates to:
  /// **'Export to Markdown'**
  String get markdownExport;

  /// Export without a vault
  ///
  /// In en, this message translates to:
  /// **'Choose a vault folder first'**
  String get markdownNoVault;

  /// Export sheet title when hidden folders are open
  ///
  /// In en, this message translates to:
  /// **'Export hidden folders too?'**
  String get markdownHiddenAsk;

  /// Export sheet text
  ///
  /// In en, this message translates to:
  /// **'Hidden notes will become plain files. Anyone with this folder can read them.'**
  String get markdownHiddenHint;

  /// Export button
  ///
  /// In en, this message translates to:
  /// **'Without hidden'**
  String get markdownWithoutHidden;

  /// Export button
  ///
  /// In en, this message translates to:
  /// **'With hidden'**
  String get markdownWithHidden;

  /// After export
  ///
  /// In en, this message translates to:
  /// **'Exported to {path}'**
  String markdownDone(Object path);

  /// Export failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t write to this folder'**
  String get markdownFailed;

  /// Folder menu: hidden folder becomes visible
  ///
  /// In en, this message translates to:
  /// **'Unhide'**
  String get folderUnhide;

  /// Folder menu
  ///
  /// In en, this message translates to:
  /// **'Hide folder'**
  String get folderHide;

  /// Screen reader label of the lock mark
  ///
  /// In en, this message translates to:
  /// **'hidden'**
  String get folderHiddenMark;

  /// Catalog row that opens hidden folders
  ///
  /// In en, this message translates to:
  /// **'Hidden folders'**
  String get hiddenFolders;

  /// Notification title for a hidden note
  ///
  /// In en, this message translates to:
  /// **'Reminder from a hidden folder'**
  String get hiddenReminder;

  /// Settings switch: the AI model re-checks folders guessed by the offline guesser
  ///
  /// In en, this message translates to:
  /// **'AI goes first'**
  String get aiFirst;

  /// Пояснение «ИИ в приоритете»
  ///
  /// In en, this message translates to:
  /// **'The model also checks what was sorted without it.'**
  String get aiFirstHint;

  /// Hint in the capture line when it only saves and does not search (home screen widget window under app lock)
  ///
  /// In en, this message translates to:
  /// **'Drop anything'**
  String get composerHintNoSearch;

  /// Summary under the 'Bring back' settings row when every kind of return is switched off
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get returnsOff;

  /// Переключатель в настройках: отправлять ли разработчику сведения о сбоях приложения
  ///
  /// In en, this message translates to:
  /// **'Error reports'**
  String get crashSetting;

  /// Подсказка под переключателем отчётов об ошибках: что уходит разработчику и чего в отчёте нет
  ///
  /// In en, this message translates to:
  /// **'The developer gets the error and your phone model, never your notes or file names.'**
  String get crashSettingHint;

  /// iPhone only. Where the notes folder is: the system Files app, folder Stowa. Use Apple's own name of the Files app in this language.
  ///
  /// In en, this message translates to:
  /// **'Files → Stowa'**
  String get vaultInFiles;

  /// iPhone only. One-sentence hint under the storage rows in settings.
  ///
  /// In en, this message translates to:
  /// **'Notes are plain .md files that you can see in the Files app.'**
  String get vaultFilesHint;

  /// Пункт меню заметки и заголовок листа: сменить день и время, когда заметка записана
  ///
  /// In en, this message translates to:
  /// **'Change date'**
  String get itemDateChange;

  /// Вариант в листе даты: поставить заметке текущий день и время
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get itemDateNow;

  /// Вариант в листе даты: открыть календарь и часы
  ///
  /// In en, this message translates to:
  /// **'Pick a day and time'**
  String get itemDatePick;

  /// Плашка после смены даты заметки, рядом кнопка «Отменить»
  ///
  /// In en, this message translates to:
  /// **'Date changed'**
  String get itemDateChanged;

  /// Заголовок блока на странице заметки: свойства из шапки файла, как в Obsidian
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get propertiesTitle;

  /// Блок свойств заметки: показать остальные свойства
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String propertiesMore(Object count);

  /// Блок свойств заметки: спрятать лишние свойства обратно
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get propertiesLess;

  /// Строка в блоке свойств и пункт меню заметки
  ///
  /// In en, this message translates to:
  /// **'Add property'**
  String get propertyAdd;

  /// Надпись над полем названия в листе нового свойства
  ///
  /// In en, this message translates to:
  /// **'New property'**
  String get propertyNew;

  /// Надпись над полем названия в листе правки свойства
  ///
  /// In en, this message translates to:
  /// **'Property'**
  String get propertyEdit;

  /// Подсказка в поле названия свойства
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get propertyNameHint;

  /// Подсказка в поле значения свойства
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get propertyValueHint;

  /// Подсказка в поле значения свойства-списка
  ///
  /// In en, this message translates to:
  /// **'One item per line'**
  String get propertyListHint;

  /// Вид свойства заметки: текст
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get propertyKindText;

  /// Вид свойства заметки: список
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get propertyKindList;

  /// Вид свойства заметки: число
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get propertyKindNumber;

  /// Вид свойства заметки: да или нет
  ///
  /// In en, this message translates to:
  /// **'Checkbox'**
  String get propertyKindCheckbox;

  /// Вид свойства заметки: день
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get propertyKindDate;

  /// Ошибка под полем названия свойства: имя занято
  ///
  /// In en, this message translates to:
  /// **'This property already exists'**
  String get propertyNameTaken;

  /// Ошибка под полем значения свойства-числа
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get propertyNumberWrong;

  /// Кнопка в листе свойства-даты, пока день не выбран
  ///
  /// In en, this message translates to:
  /// **'Pick a day'**
  String get propertyDatePick;

  /// Кнопка в листе правки свойства
  ///
  /// In en, this message translates to:
  /// **'Delete property'**
  String get propertyDelete;

  /// Плашка после удаления свойства, рядом «Отменить»
  ///
  /// In en, this message translates to:
  /// **'Property deleted'**
  String get propertyRemoved;

  /// Подсказка в листе свойства с вложенным значением: приложение его только показывает
  ///
  /// In en, this message translates to:
  /// **'This value can be changed in the note file.'**
  String get propertyOtherHint;

  /// Значение свойства-галочки в блоке свойств: стоит
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get propertyYes;

  /// Значение свойства-галочки в блоке свойств: не стоит
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get propertyNo;

  /// Раздел иконок, подобранных по имени папки
  ///
  /// In en, this message translates to:
  /// **'Match the name'**
  String get lookSuggested;

  /// Раздел ходовых иконок
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get lookPopular;

  /// Раздел со всем набором иконок
  ///
  /// In en, this message translates to:
  /// **'All icons'**
  String get lookAll;

  /// Поиск иконки ничего не нашёл
  ///
  /// In en, this message translates to:
  /// **'No such icon, try another word.'**
  String get iconsNone;

  /// Вид места
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get placeKindHome;

  /// Вид места
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get placeKindWork;

  /// Вид места: школа, универ, курсы
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get placeKindStudy;

  /// Вид места
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get placeKindShop;

  /// Вид места
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get placeKindPharmacy;

  /// Вид места
  ///
  /// In en, this message translates to:
  /// **'Cafés and restaurants'**
  String get placeKindFood;

  /// Вид места: зал, бассейн
  ///
  /// In en, this message translates to:
  /// **'Sport'**
  String get placeKindSport;

  /// Вид места: у друга, у мамы
  ///
  /// In en, this message translates to:
  /// **'Friends and family'**
  String get placeKindGuests;

  /// Вид места
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get placeKindOther;

  /// Чип и пункт листа: напоминание у любого места учёбы
  ///
  /// In en, this message translates to:
  /// **'Remind at school'**
  String get placeRemindStudy;

  /// Чип: у любой отмеченной аптеки
  ///
  /// In en, this message translates to:
  /// **'Remind at a pharmacy'**
  String get placeRemindPharmacy;

  /// Чип: у любого кафе или ресторана
  ///
  /// In en, this message translates to:
  /// **'Remind at a café'**
  String get placeRemindFood;

  /// Чип: у любого места спорта
  ///
  /// In en, this message translates to:
  /// **'Remind at the gym'**
  String get placeRemindSport;

  /// Чип: у любого места вида «Гости»
  ///
  /// In en, this message translates to:
  /// **'Remind when visiting'**
  String get placeRemindGuests;

  /// Чип: у любого места вида «Другое»
  ///
  /// In en, this message translates to:
  /// **'Remind at a place'**
  String get placeRemindOther;

  /// Чип напоминания по месту с днём: «Напомнить у магазина · завтра»
  ///
  /// In en, this message translates to:
  /// **'{place} · {day}'**
  String placeRemindDay(String place, String day);

  /// День напоминания по месту
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get dayToday;

  /// День напоминания по месту
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get dayTomorrow;

  /// Плашка: напоминание у вида места, а мест этого вида нет
  ///
  /// In en, this message translates to:
  /// **'No such place yet: I’ll remind you once you add it in Places'**
  String get placesMissingKind;

  /// Кнопка на экране «Места»
  ///
  /// In en, this message translates to:
  /// **'Add a place'**
  String get placesAdd;

  /// Пустой список мест
  ///
  /// In en, this message translates to:
  /// **'No places yet: add home, work, a favourite café or a friend.'**
  String get placesEmpty;

  /// Заголовок экрана добавления места
  ///
  /// In en, this message translates to:
  /// **'New place'**
  String get placeNewTitle;

  /// Заголовок экрана правки места
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get placeEditTitle;

  /// Подсказка в поле имени места
  ///
  /// In en, this message translates to:
  /// **'Name it: Uni, Sasha, Andy’s'**
  String get placeNameHint;

  /// Раздел выбора вида места
  ///
  /// In en, this message translates to:
  /// **'What is it'**
  String get placeKindTitle;

  /// Раздел точки на карте
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get placeWhereTitle;

  /// Кнопка: взять текущее место
  ///
  /// In en, this message translates to:
  /// **'I’m here now'**
  String get placeHereNow;

  /// Подсказка под картой выбора места
  ///
  /// In en, this message translates to:
  /// **'Move the map: the place is where the centre dot is.'**
  String get placeMapHint;

  /// Третья плитка выбора вида места: открывает поиск видов
  ///
  /// In en, this message translates to:
  /// **'Find or create'**
  String get placeKindMore;

  /// Подсказка в поиске вида места
  ///
  /// In en, this message translates to:
  /// **'Find a type or name your own'**
  String get placeKindSearchHint;

  /// Строка в поиске вида: свой вид из набранного
  ///
  /// In en, this message translates to:
  /// **'Create “{name}”'**
  String placeKindCreate(String name);

  /// Подсказка кнопки выбора значка места
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get placeIcon;

  /// Подсказка над строкой, когда текст на языке, где время словами не разбирается
  ///
  /// In en, this message translates to:
  /// **'I can\'t read times in words in this language — write digits: 14:30'**
  String get lineLanguageHint;

  /// Подсказка крестика чипа про язык
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get lineLanguageHide;

  /// Поле поиска поверх карты на экране места
  ///
  /// In en, this message translates to:
  /// **'Find an address or place'**
  String get placeSearchHint;

  /// Поиск адреса ничего не дал
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get placeSearchNone;

  /// Подсказка на карте, пока точки нет
  ///
  /// In en, this message translates to:
  /// **'Find an address or press and hold the map to drop a pin'**
  String get placeMapEmpty;

  /// Подсказка под адресом точки
  ///
  /// In en, this message translates to:
  /// **'Press and hold the map to move the pin'**
  String get placeMapMove;

  /// Плашка после переноса точки долгим нажатием, с «Отменить»
  ///
  /// In en, this message translates to:
  /// **'Pin moved'**
  String get placePointMoved;

  /// Строка адреса под картой, пока точки нет
  ///
  /// In en, this message translates to:
  /// **'No pin yet'**
  String get placeNoPoint;

  /// Последний чип в строке видов места: поиск и создание своего вида
  ///
  /// In en, this message translates to:
  /// **'Custom type'**
  String get placeKindOwn;

  /// Радиус места в метрах на пилюле под картой
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String placeRadiusValue(int meters);

  /// Заголовок листа выбора радиуса места
  ///
  /// In en, this message translates to:
  /// **'Reminder radius'**
  String get placeRadiusTitle;

  /// Почему связано: [[…]] в тексте этой заметки
  ///
  /// In en, this message translates to:
  /// **'linked in the text'**
  String get relatedInText;

  /// Почему связано: та заметка упоминает эту в своём [[…]]
  ///
  /// In en, this message translates to:
  /// **'links here'**
  String get relatedBacklink;

  /// Почему связано: «+ Связь»
  ///
  /// In en, this message translates to:
  /// **'linked by you'**
  String get relatedManual;

  /// Почему связано: причина от модели
  ///
  /// In en, this message translates to:
  /// **'AI: {reason}'**
  String relatedAi(String reason);

  /// Почему связано: модель, без причины
  ///
  /// In en, this message translates to:
  /// **'linked by AI'**
  String get relatedAiPlain;

  /// Подсказка крестика у ручной связи
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get relatedUnlink;

  /// Плашка после снятия ручной связи
  ///
  /// In en, this message translates to:
  /// **'Link removed'**
  String get relatedUnlinked;

  /// Подсказка кнопки «+ Связь» и кнопки в полосе разметки
  ///
  /// In en, this message translates to:
  /// **'Link a note'**
  String get linkAdd;

  /// Подпись кнопки «+ Связь» рядом с «+ Тег»
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get linkAddShort;

  /// Поле поиска в листе «+ Связь»
  ///
  /// In en, this message translates to:
  /// **'Find a note by words'**
  String get linkSearchHint;

  /// Поиск заметки для связи ничего не нашёл
  ///
  /// In en, this message translates to:
  /// **'No such note'**
  String get linkNone;

  /// Плашка после «+ Связь»
  ///
  /// In en, this message translates to:
  /// **'Linked with “{title}”'**
  String linkAdded(String title);

  /// Касание [[…]] в тексте, а такой заметки нет
  ///
  /// In en, this message translates to:
  /// **'There\'s no note “{title}”'**
  String linkMissing(String title);

  /// Раздел настроек: где лежат заметки
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsCatalog;

  /// settingsLook
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get settingsLook;

  /// settingsHelpers
  ///
  /// In en, this message translates to:
  /// **'Sorting and notifications'**
  String get settingsHelpers;

  /// settingsCopies
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get settingsCopies;

  /// vaultsSection
  ///
  /// In en, this message translates to:
  /// **'Vaults'**
  String get vaultsSection;

  /// vaultOpenNow
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get vaultOpenNow;

  /// vaultAdd
  ///
  /// In en, this message translates to:
  /// **'Add a vault'**
  String get vaultAdd;

  /// vaultAddNew
  ///
  /// In en, this message translates to:
  /// **'Create new'**
  String get vaultAddNew;

  /// vaultAddNewHint
  ///
  /// In en, this message translates to:
  /// **'An empty folder for new notes'**
  String get vaultAddNewHint;

  /// vaultAddOpen
  ///
  /// In en, this message translates to:
  /// **'Open a folder'**
  String get vaultAddOpen;

  /// vaultAddOpenHint
  ///
  /// In en, this message translates to:
  /// **'An earlier Stowa vault or an Obsidian vault'**
  String get vaultAddOpenHint;

  /// vaultsHint
  ///
  /// In en, this message translates to:
  /// **'Tap another vault to open it; reminders come only from the open one.'**
  String get vaultsHint;

  /// vaultFolderGone
  ///
  /// In en, this message translates to:
  /// **'Folder not found'**
  String get vaultFolderGone;

  /// vaultForget
  ///
  /// In en, this message translates to:
  /// **'Remove from the list'**
  String get vaultForget;

  /// vaultForgetHint
  ///
  /// In en, this message translates to:
  /// **'The files stay in the folder'**
  String get vaultForgetHint;

  /// vaultForgotten
  ///
  /// In en, this message translates to:
  /// **'Vault removed from the list; the files are still there'**
  String get vaultForgotten;

  /// vaultOpenIt
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get vaultOpenIt;

  /// vaultAlreadyOpen
  ///
  /// In en, this message translates to:
  /// **'This vault is already open'**
  String get vaultAlreadyOpen;

  /// vaultHasNotes
  ///
  /// In en, this message translates to:
  /// **'This folder already has notes'**
  String get vaultHasNotes;

  /// vaultOpenSeparately
  ///
  /// In en, this message translates to:
  /// **'Open as a separate vault'**
  String get vaultOpenSeparately;

  /// vaultOpenSeparatelyHint
  ///
  /// In en, this message translates to:
  /// **'The current one stays in the list'**
  String get vaultOpenSeparatelyHint;

  /// vaultMergeHere
  ///
  /// In en, this message translates to:
  /// **'Move here and merge'**
  String get vaultMergeHere;

  /// vaultMergeHereHint
  ///
  /// In en, this message translates to:
  /// **'Notes from both end up in one folder'**
  String get vaultMergeHereHint;

  /// vaultSwitching
  ///
  /// In en, this message translates to:
  /// **'Opening “{name}”'**
  String vaultSwitching(String name);

  /// vaultChangeFolder
  ///
  /// In en, this message translates to:
  /// **'Change folder'**
  String get vaultChangeFolder;

  /// vaultAllCount
  ///
  /// In en, this message translates to:
  /// **'All vaults · {count}'**
  String vaultAllCount(int count);

  /// syncTitle
  ///
  /// In en, this message translates to:
  /// **'Stowa Sync'**
  String get syncTitle;

  /// syncPaid
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get syncPaid;

  /// syncSoon
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get syncSoon;

  /// syncAbout
  ///
  /// In en, this message translates to:
  /// **'Your notes will stay the same on your phone, tablet and computer by themselves.'**
  String get syncAbout;

  /// syncLater
  ///
  /// In en, this message translates to:
  /// **'The subscription will arrive in one of the next updates.'**
  String get syncLater;

  /// syncOk
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get syncOk;

  /// Пункт меню заметки: закрепить наверху главной
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get itemPin;

  /// Пункт меню закреплённой заметки: снять закрепление
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get itemUnpin;

  /// Плашка после закрепления заметки
  ///
  /// In en, this message translates to:
  /// **'Pinned to the top of Home'**
  String get itemPinned;

  /// Плашка после открепления заметки
  ///
  /// In en, this message translates to:
  /// **'Unpinned'**
  String get itemUnpinned;

  /// Заголовок блока закреплённых заметок над лентой главной
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get homePinned;

  /// Под закреплёнными на главной: показать остальные
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String homePinnedMore(Object count);

  /// Под раскрытыми закреплёнными на главной: снова показать первые
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get homePinnedLess;

  /// Подсказка внизу каталога: как менять порядок папок
  ///
  /// In en, this message translates to:
  /// **'Hold a folder and drag it: Home shows folders in the same order.'**
  String get catalogReorderHint;

  /// Строка в подсказке [[…]], когда заметки с набранным названием нет
  ///
  /// In en, this message translates to:
  /// **'Create note “{title}”'**
  String linkCreate(Object title);

  /// Кнопка в плашке «Такой заметки нет»: завести заметку по ссылке
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get linkCreateAction;

  /// На карточке заметки на главной: сколько строк текста не видно
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} more line} other{{count} more lines}}'**
  String homeMoreLines(num count);

  /// Раздел настроек: заметки у края экрана поверх других приложений
  ///
  /// In en, this message translates to:
  /// **'At hand'**
  String get edgeTitle;

  /// Включатель: цветные корешки заметок у края экрана
  ///
  /// In en, this message translates to:
  /// **'Spines at the edge'**
  String get edgeSwitch;

  /// Подсказка под включателем корешков, одно предложение
  ///
  /// In en, this message translates to:
  /// **'Pinned notes wait at the screen edge, and a tap opens them over any app.'**
  String get edgeSwitchHint;

  /// Заголовок блока: край и место корешков
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get edgePlace;

  /// Заголовок блока с предпросмотром корешков: край, высота, размер, заметность
  ///
  /// In en, this message translates to:
  /// **'Look and place'**
  String get edgeLook;

  /// Подсказка под предпросмотром: высоту корешков меняют, ведя их пальцем на картинке телефона
  ///
  /// In en, this message translates to:
  /// **'Drag the spines on the phone up or down.'**
  String get edgeDragHint;

  /// Корешки у левого края
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get edgeLeft;

  /// Корешки у правого края
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get edgeRight;

  /// Ползунок: где по высоте экрана корешки
  ///
  /// In en, this message translates to:
  /// **'Height on screen'**
  String get edgeHeight;

  /// Значение ползунка высоты
  ///
  /// In en, this message translates to:
  /// **'higher'**
  String get edgeHigher;

  /// Значение ползунка высоты
  ///
  /// In en, this message translates to:
  /// **'middle'**
  String get edgeMiddle;

  /// Значение ползунка высоты
  ///
  /// In en, this message translates to:
  /// **'lower'**
  String get edgeLower;

  /// Ползунок размера корешков
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get edgeSize;

  /// Размер корешков
  ///
  /// In en, this message translates to:
  /// **'thin'**
  String get edgeThin;

  /// Размер корешков
  ///
  /// In en, this message translates to:
  /// **'regular'**
  String get edgeNormal;

  /// Размер корешков
  ///
  /// In en, this message translates to:
  /// **'large'**
  String get edgeLarge;

  /// Ползунок прозрачности корешков
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get edgeAlpha;

  /// Включатель: корешки прячутся, пока видео на весь экран
  ///
  /// In en, this message translates to:
  /// **'Hide in full-screen video'**
  String get edgeHideVideo;

  /// Подсказка под включателем прятанья в видео, одно предложение
  ///
  /// In en, this message translates to:
  /// **'While a video or game is full screen, the spines stay out of the way.'**
  String get edgeHideVideoHint;

  /// Значение строки «Под рукой» в настройках, когда корешки выключены
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get edgeOff;

  /// Раздел полки «Под рукой»: последние заметки
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get edgeRecent;

  /// Кнопка в шапке полки: открыть приложение
  ///
  /// In en, this message translates to:
  /// **'Open Stowa'**
  String get edgeOpenApp;

  /// Кнопка на карточке полки: заметка окошком поверх приложений
  ///
  /// In en, this message translates to:
  /// **'Pin as a sticker'**
  String get edgeStick;

  /// Кнопка-шестерёнка в шапке полки
  ///
  /// In en, this message translates to:
  /// **'Set up the spines'**
  String get edgeSpinesSetup;

  /// Кнопка «×» на стикере поверх приложений
  ///
  /// In en, this message translates to:
  /// **'Remove sticker'**
  String get edgeUnstick;

  /// Раздел полки «Под рукой»: напоминание по месту только что сработало
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get edgeNearby;

  /// Подсказка над строкой в полке «Под рукой»: буфер читается только по касанию
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get suggestPaste;

  /// Раздел экрана «Под рукой»: жесты по корешкам
  ///
  /// In en, this message translates to:
  /// **'Gestures'**
  String get edgeGestures;

  /// Переключатель жеста корешков
  ///
  /// In en, this message translates to:
  /// **'Swipe down to type'**
  String get edgeGestureSwipe;

  /// Пояснение под переключателем, одно предложение
  ///
  /// In en, this message translates to:
  /// **'The line opens with the keyboard ready.'**
  String get edgeGestureSwipeHint;

  /// Переключатель жеста корешков
  ///
  /// In en, this message translates to:
  /// **'Hold for a voice note'**
  String get edgeGestureHold;

  /// Пояснение под переключателем, одно предложение
  ///
  /// In en, this message translates to:
  /// **'Recording keeps going without your finger until you tap Save.'**
  String get edgeGestureHoldHint;

  /// Переключатель жеста корешков
  ///
  /// In en, this message translates to:
  /// **'Double tap for the last note'**
  String get edgeGestureDouble;

  /// Пояснение под переключателем, одно предложение
  ///
  /// In en, this message translates to:
  /// **'A single tap then reacts a little later.'**
  String get edgeGestureDoubleHint;

  /// Имя канала уведомлений: пока идёт запись голоса из «Под рукой»
  ///
  /// In en, this message translates to:
  /// **'Voice recording'**
  String get edgeVoiceChannel;

  /// Уведомление на время записи голоса из «Под рукой»
  ///
  /// In en, this message translates to:
  /// **'Recording a voice note'**
  String get edgeVoiceNow;

  /// Подпись строки «Перенос» в настройках: откуда можно перенести заметки
  ///
  /// In en, this message translates to:
  /// **'Telegram, Google Keep, bookmarks, Obsidian, mymind'**
  String get importSummary;

  /// importKeep
  ///
  /// In en, this message translates to:
  /// **'From Google Keep'**
  String get importKeep;

  /// importBookmarks
  ///
  /// In en, this message translates to:
  /// **'Browser bookmarks'**
  String get importBookmarks;

  /// importObsidian
  ///
  /// In en, this message translates to:
  /// **'From Obsidian'**
  String get importObsidian;

  /// importMymind
  ///
  /// In en, this message translates to:
  /// **'From mymind'**
  String get importMymind;

  /// importScreenHint
  ///
  /// In en, this message translates to:
  /// **'Unzip the export on your phone and pick its folder; for bookmarks, pick the .html file.'**
  String get importScreenHint;

  /// importNotKeep
  ///
  /// In en, this message translates to:
  /// **'No Google Keep notes in this folder: pick the Keep folder from Google Takeout'**
  String get importNotKeep;

  /// importNotBookmarks
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a bookmarks file: export bookmarks from your browser as .html'**
  String get importNotBookmarks;

  /// importNotObsidian
  ///
  /// In en, this message translates to:
  /// **'No .md notes in this folder'**
  String get importNotObsidian;

  /// importNotMymind
  ///
  /// In en, this message translates to:
  /// **'No cards.csv from mymind in this folder'**
  String get importNotMymind;

  /// Итог переноса: вложения, на которые ссылается выгрузка, но которых нет в папке
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} file not found} other{{count} files not found}}'**
  String importFilesNotFound(num count);

  /// Ссылка внизу настроек на страницу политики конфиденциальности
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicy;

  /// Раздел настроек с поддержкой
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get settingsHelp;

  /// Строка настроек и заголовок экрана обращения
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get feedbackRow;

  /// Подпись под строкой «Сообщить о проблеме»
  ///
  /// In en, this message translates to:
  /// **'A bug, an idea or a question, right from here'**
  String get feedbackRowHint;

  /// Строка настроек: открыть почту с адресом поддержки
  ///
  /// In en, this message translates to:
  /// **'Email support'**
  String get supportRow;

  /// Вид обращения
  ///
  /// In en, this message translates to:
  /// **'Bug'**
  String get feedbackKindBug;

  /// Вид обращения
  ///
  /// In en, this message translates to:
  /// **'Idea'**
  String get feedbackKindIdea;

  /// Вид обращения
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get feedbackKindQuestion;

  /// Подсказка в поле текста обращения
  ///
  /// In en, this message translates to:
  /// **'What happened and what you did just before'**
  String get feedbackField;

  /// Переключатель на экране обращения
  ///
  /// In en, this message translates to:
  /// **'Attach app version and phone model'**
  String get feedbackAttach;

  /// Кнопка отправки обращения
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get feedbackSend;

  /// Пояснение под кнопкой отправки
  ///
  /// In en, this message translates to:
  /// **'Your message comes to us. Leave an email if you want a reply.'**
  String get feedbackHint;

  /// Подсказка в необязательном поле почты на экране обращения
  ///
  /// In en, this message translates to:
  /// **'Email for a reply, if you want one'**
  String get feedbackEmail;

  /// Заголовок после отправки обращения
  ///
  /// In en, this message translates to:
  /// **'Sent, thank you'**
  String get feedbackSentTitle;

  /// Под заголовком, когда почту оставили
  ///
  /// In en, this message translates to:
  /// **'We\'ll reply to {email}.'**
  String feedbackSentReply(String email);

  /// Под заголовком, когда почту не оставили
  ///
  /// In en, this message translates to:
  /// **'You didn\'t leave an email, so we can\'t reply, but we\'ll read it.'**
  String get feedbackSentQuiet;

  /// Кнопка после отправки: новое обращение
  ///
  /// In en, this message translates to:
  /// **'Write another'**
  String get feedbackAgain;

  /// Ошибка отправки обращения
  ///
  /// In en, this message translates to:
  /// **'Didn\'t send. Check your connection and tap again.'**
  String get feedbackFailed;

  /// Сервер отбил по дневному пределу
  ///
  /// In en, this message translates to:
  /// **'Too many messages from this phone today. Try tomorrow or use the email in Settings.'**
  String get feedbackTooMany;

  /// Сервер отбил почту для ответа
  ///
  /// In en, this message translates to:
  /// **'The email looks wrong, check the address.'**
  String get feedbackBadEmail;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Canvases'**
  String get kindsCanvas;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Bases'**
  String get kindsBase;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Canvas'**
  String get kindCanvas;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Base'**
  String get kindBase;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'New canvas'**
  String get canvasNew;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'New base'**
  String get baseNew;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Canvas'**
  String get canvasDefaultName;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Base'**
  String get baseDefaultName;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no cards} one{{count} card} other{{count} cards}}'**
  String canvasCards(int count);

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} view} other{{count} views}}'**
  String baseViews(int count);

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get canvasAdd;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get canvasAddText;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get canvasAddNote;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get canvasAddLink;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get canvasAddGroup;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get canvasEdit;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get canvasConnect;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get canvasColor;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get canvasDelete;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Card deleted'**
  String get canvasDeleted;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Arrow deleted'**
  String get canvasEdgeDeleted;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get canvasEdgeLabel;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Tap the card to draw an arrow to'**
  String get canvasConnectHint;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Empty canvas. Double-tap to add a card.'**
  String get canvasEmpty;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'The canvas file is damaged, so Stowa leaves it alone. Open it in Obsidian.'**
  String get canvasBroken;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Card text'**
  String get canvasTextHint;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Link address'**
  String get canvasLinkHint;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Group label'**
  String get canvasGroupHint;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'File not found: {name}'**
  String canvasMissingFile(String name);

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'No color'**
  String get canvasNoColor;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get canvasDone;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Which note to put on the canvas'**
  String get canvasPickNote;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Stowa didn\'t understand some conditions and skipped them.'**
  String get baseUnsupported;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'The base file is damaged. Open it in Obsidian.'**
  String get baseBroken;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'No notes match.'**
  String get baseEmpty;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'The map view is shown as a list.'**
  String get baseMapAsList;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get baseColName;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get baseColCreated;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get baseColModified;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get baseColFolder;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get baseColTags;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get baseColPath;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get baseColLinks;

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} note} other{{count} notes}}'**
  String baseCount(int count);

  /// Холсты и базы Obsidian
  ///
  /// In en, this message translates to:
  /// **'No value'**
  String get baseNoGroup;

  /// Пункт меню папки: завести холст или базу Obsidian
  ///
  /// In en, this message translates to:
  /// **'Canvas or base'**
  String get documentNew;

  /// Рисунок Excalidraw из Obsidian: вид заметки
  ///
  /// In en, this message translates to:
  /// **'Drawing'**
  String get kindDrawing;

  /// Рисунки Excalidraw: вид заметок во множественном числе
  ///
  /// In en, this message translates to:
  /// **'Drawings'**
  String get kindsDrawing;

  /// Кнопка и заголовок листа с подписями рисунка Excalidraw
  ///
  /// In en, this message translates to:
  /// **'Text in drawing'**
  String get drawingTexts;

  /// Плашка после касания подписи рисунка
  ///
  /// In en, this message translates to:
  /// **'Text copied'**
  String get drawingTextCopied;

  /// Подсказка над рисунком Excalidraw: в Stowa он только для просмотра
  ///
  /// In en, this message translates to:
  /// **'You can edit this drawing in Obsidian'**
  String get drawingEditInObsidian;

  /// Подсказка, когда свой разбор рисунка Excalidraw не вышел
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this drawing, open it in Obsidian'**
  String get drawingUnreadable;

  /// Сколько подписей в рисунке Excalidraw
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} label} other{{count} labels}}'**
  String drawingTextCount(int count);

  /// Команда строки после «/»: завести холст Obsidian; одно слово
  ///
  /// In en, this message translates to:
  /// **'canvas'**
  String get cmdCanvas;

  /// Команда строки после «/»: завести базу Obsidian; одно слово
  ///
  /// In en, this message translates to:
  /// **'base'**
  String get cmdBase;

  /// Подсказка к команде «холст»
  ///
  /// In en, this message translates to:
  /// **'A new canvas with this name, opens right away'**
  String get cmdCanvasHint;

  /// Подсказка к команде «база»
  ///
  /// In en, this message translates to:
  /// **'A new base with the folder’s notes, opens right away'**
  String get cmdBaseHint;

  /// Панель базы Obsidian: кнопки над видом
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get baseSort;

  /// No description provided for @baseGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get baseGroup;

  /// No description provided for @baseFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get baseFilter;

  /// No description provided for @baseProperties.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get baseProperties;

  /// No description provided for @baseSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get baseSearch;

  /// No description provided for @baseSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search this base'**
  String get baseSearchHint;

  /// No description provided for @baseCreate.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get baseCreate;

  /// No description provided for @baseShown.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total}'**
  String baseShown(int shown, int total);

  /// No description provided for @baseSortAdd.
  ///
  /// In en, this message translates to:
  /// **'Add sort'**
  String get baseSortAdd;

  /// No description provided for @baseAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get baseAscending;

  /// No description provided for @baseDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get baseDescending;

  /// No description provided for @baseGroupNone.
  ///
  /// In en, this message translates to:
  /// **'No grouping'**
  String get baseGroupNone;

  /// No description provided for @baseFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All views'**
  String get baseFilterAll;

  /// No description provided for @baseFilterThis.
  ///
  /// In en, this message translates to:
  /// **'This view'**
  String get baseFilterThis;

  /// No description provided for @baseFilterEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conditions, every note is shown.'**
  String get baseFilterEmpty;

  /// No description provided for @baseJoinAll.
  ///
  /// In en, this message translates to:
  /// **'All of the following'**
  String get baseJoinAll;

  /// No description provided for @baseJoinAny.
  ///
  /// In en, this message translates to:
  /// **'Any of the following'**
  String get baseJoinAny;

  /// No description provided for @baseJoinNone.
  ///
  /// In en, this message translates to:
  /// **'None of the following'**
  String get baseJoinNone;

  /// No description provided for @baseFilterAdd.
  ///
  /// In en, this message translates to:
  /// **'Add condition'**
  String get baseFilterAdd;

  /// No description provided for @baseFilterAddGroup.
  ///
  /// In en, this message translates to:
  /// **'Add group'**
  String get baseFilterAddGroup;

  /// No description provided for @baseMoveToAll.
  ///
  /// In en, this message translates to:
  /// **'Move to all views'**
  String get baseMoveToAll;

  /// No description provided for @baseMoveToThis.
  ///
  /// In en, this message translates to:
  /// **'Move to this view'**
  String get baseMoveToThis;

  /// No description provided for @baseExpression.
  ///
  /// In en, this message translates to:
  /// **'Expression'**
  String get baseExpression;

  /// No description provided for @baseValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get baseValue;

  /// No description provided for @baseOpIs.
  ///
  /// In en, this message translates to:
  /// **'is'**
  String get baseOpIs;

  /// No description provided for @baseOpIsNot.
  ///
  /// In en, this message translates to:
  /// **'is not'**
  String get baseOpIsNot;

  /// No description provided for @baseOpContains.
  ///
  /// In en, this message translates to:
  /// **'contains'**
  String get baseOpContains;

  /// No description provided for @baseOpNotContains.
  ///
  /// In en, this message translates to:
  /// **'does not contain'**
  String get baseOpNotContains;

  /// No description provided for @baseOpStarts.
  ///
  /// In en, this message translates to:
  /// **'starts with'**
  String get baseOpStarts;

  /// No description provided for @baseOpEnds.
  ///
  /// In en, this message translates to:
  /// **'ends with'**
  String get baseOpEnds;

  /// No description provided for @baseOpEmpty.
  ///
  /// In en, this message translates to:
  /// **'is empty'**
  String get baseOpEmpty;

  /// No description provided for @baseOpNotEmpty.
  ///
  /// In en, this message translates to:
  /// **'is not empty'**
  String get baseOpNotEmpty;

  /// No description provided for @baseOpGreater.
  ///
  /// In en, this message translates to:
  /// **'is greater than'**
  String get baseOpGreater;

  /// No description provided for @baseOpAtLeast.
  ///
  /// In en, this message translates to:
  /// **'is at least'**
  String get baseOpAtLeast;

  /// No description provided for @baseOpLess.
  ///
  /// In en, this message translates to:
  /// **'is less than'**
  String get baseOpLess;

  /// No description provided for @baseOpAtMost.
  ///
  /// In en, this message translates to:
  /// **'is at most'**
  String get baseOpAtMost;

  /// No description provided for @baseOpHasTag.
  ///
  /// In en, this message translates to:
  /// **'has tag'**
  String get baseOpHasTag;

  /// No description provided for @baseOpNotHasTag.
  ///
  /// In en, this message translates to:
  /// **'does not have tag'**
  String get baseOpNotHasTag;

  /// No description provided for @baseOpInFolder.
  ///
  /// In en, this message translates to:
  /// **'is in folder'**
  String get baseOpInFolder;

  /// No description provided for @baseOpNotInFolder.
  ///
  /// In en, this message translates to:
  /// **'is not in folder'**
  String get baseOpNotInFolder;

  /// No description provided for @baseOpHasLink.
  ///
  /// In en, this message translates to:
  /// **'links to'**
  String get baseOpHasLink;

  /// No description provided for @baseFormulaAdd.
  ///
  /// In en, this message translates to:
  /// **'Add formula'**
  String get baseFormulaAdd;

  /// No description provided for @baseFormulaName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get baseFormulaName;

  /// No description provided for @baseFormulaError.
  ///
  /// In en, this message translates to:
  /// **'Not understood: {what}'**
  String baseFormulaError(String what);

  /// No description provided for @baseFormulaEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit formula'**
  String get baseFormulaEdit;

  /// No description provided for @baseFormulaDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete formula'**
  String get baseFormulaDelete;

  /// No description provided for @baseRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get baseRename;

  /// No description provided for @baseRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get baseRemove;

  /// No description provided for @baseColumnHide.
  ///
  /// In en, this message translates to:
  /// **'Hide column'**
  String get baseColumnHide;

  /// No description provided for @baseShownProps.
  ///
  /// In en, this message translates to:
  /// **'Shown'**
  String get baseShownProps;

  /// No description provided for @baseOtherProps.
  ///
  /// In en, this message translates to:
  /// **'Other properties'**
  String get baseOtherProps;

  /// No description provided for @baseSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get baseSummary;

  /// No description provided for @baseSummaryNone.
  ///
  /// In en, this message translates to:
  /// **'No summary'**
  String get baseSummaryNone;

  /// No description provided for @baseSumAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get baseSumAverage;

  /// No description provided for @baseSumMedian.
  ///
  /// In en, this message translates to:
  /// **'Median'**
  String get baseSumMedian;

  /// No description provided for @baseSumMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get baseSumMin;

  /// No description provided for @baseSumMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get baseSumMax;

  /// No description provided for @baseSumSum.
  ///
  /// In en, this message translates to:
  /// **'Sum'**
  String get baseSumSum;

  /// No description provided for @baseSumRange.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get baseSumRange;

  /// No description provided for @baseSumStddev.
  ///
  /// In en, this message translates to:
  /// **'Std. deviation'**
  String get baseSumStddev;

  /// No description provided for @baseSumEarliest.
  ///
  /// In en, this message translates to:
  /// **'Earliest'**
  String get baseSumEarliest;

  /// No description provided for @baseSumLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get baseSumLatest;

  /// No description provided for @baseSumChecked.
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get baseSumChecked;

  /// No description provided for @baseSumUnchecked.
  ///
  /// In en, this message translates to:
  /// **'Unchecked'**
  String get baseSumUnchecked;

  /// No description provided for @baseSumEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get baseSumEmpty;

  /// No description provided for @baseSumFilled.
  ///
  /// In en, this message translates to:
  /// **'Filled'**
  String get baseSumFilled;

  /// No description provided for @baseSumUnique.
  ///
  /// In en, this message translates to:
  /// **'Unique'**
  String get baseSumUnique;

  /// No description provided for @baseViewAdd.
  ///
  /// In en, this message translates to:
  /// **'Add view'**
  String get baseViewAdd;

  /// No description provided for @baseViewLayout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get baseViewLayout;

  /// No description provided for @baseViewCopy.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get baseViewCopy;

  /// No description provided for @baseViewDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete view'**
  String get baseViewDelete;

  /// No description provided for @baseViewSettings.
  ///
  /// In en, this message translates to:
  /// **'View settings'**
  String get baseViewSettings;

  /// No description provided for @baseLayoutTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get baseLayoutTable;

  /// No description provided for @baseLayoutCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get baseLayoutCards;

  /// No description provided for @baseLayoutList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get baseLayoutList;

  /// No description provided for @baseLayoutKanban.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get baseLayoutKanban;

  /// No description provided for @baseLayoutMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get baseLayoutMap;

  /// No description provided for @baseLimit.
  ///
  /// In en, this message translates to:
  /// **'Result limit'**
  String get baseLimit;

  /// No description provided for @baseLimitNone.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get baseLimitNone;

  /// No description provided for @baseImage.
  ///
  /// In en, this message translates to:
  /// **'Image property'**
  String get baseImage;

  /// No description provided for @baseImageNone.
  ///
  /// In en, this message translates to:
  /// **'No image'**
  String get baseImageNone;

  /// No description provided for @baseCardSize.
  ///
  /// In en, this message translates to:
  /// **'Card size'**
  String get baseCardSize;

  /// No description provided for @baseImageRatio.
  ///
  /// In en, this message translates to:
  /// **'Image aspect ratio'**
  String get baseImageRatio;

  /// No description provided for @baseImageFitCover.
  ///
  /// In en, this message translates to:
  /// **'Crop to fill'**
  String get baseImageFitCover;

  /// No description provided for @baseImageFitContain.
  ///
  /// In en, this message translates to:
  /// **'Fit whole'**
  String get baseImageFitContain;

  /// No description provided for @baseKanbanNeedsGroup.
  ///
  /// In en, this message translates to:
  /// **'Pick a property under Group to build the columns.'**
  String get baseKanbanNeedsGroup;

  /// No description provided for @baseUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get baseUntitled;

  /// Колонка и условие базы: расширение файла (file.ext)
  ///
  /// In en, this message translates to:
  /// **'File type'**
  String get baseColExt;

  /// Раздел выбора свойства в базе: свойства из шапки заметок и формулы
  ///
  /// In en, this message translates to:
  /// **'Note properties'**
  String get baseSectionNotes;

  /// Раздел выбора свойства в базе: имя, папка, даты файла
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get baseSectionFile;

  /// Заголовок плиток в меню папки: папка, холст, база
  ///
  /// In en, this message translates to:
  /// **'Create inside'**
  String get folderCreateInside;

  /// Плитка «Создать внутри»: папку
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folderTileFolder;

  /// Плитка «Создать внутри»: холст
  ///
  /// In en, this message translates to:
  /// **'Canvas'**
  String get folderTileCanvas;

  /// Плитка «Создать внутри»: базу
  ///
  /// In en, this message translates to:
  /// **'Base'**
  String get folderTileBase;

  /// Пункт меню папки: имя, цвет, форма и значок на одном экране
  ///
  /// In en, this message translates to:
  /// **'Name and look'**
  String get folderEdit;

  /// Шаг 1 знакомства над строкой главной
  ///
  /// In en, this message translates to:
  /// **'Type anything and tap “Stow”.'**
  String get startStow;

  /// Шаг 2 знакомства
  ///
  /// In en, this message translates to:
  /// **'The same line searches: type a word from your note.'**
  String get startSearch;

  /// Шаг 3 знакомства
  ///
  /// In en, this message translates to:
  /// **'A time in the text is already a reminder.'**
  String get startRemind;

  /// Шаг 4 знакомства
  ///
  /// In en, this message translates to:
  /// **'The @ sign puts a note into a folder, new or existing.'**
  String get startFolder;

  /// Шаг 5 знакомства
  ///
  /// In en, this message translates to:
  /// **'The # sign adds a tag that makes the note easy to find.'**
  String get startTag;

  /// Шаг 6 знакомства
  ///
  /// In en, this message translates to:
  /// **'The / sign opens commands: list, task, canvas.'**
  String get startCommands;

  /// Последняя карточка знакомства
  ///
  /// In en, this message translates to:
  /// **'The tour is over, you can bring it back in settings.'**
  String get startFinish;

  /// Кнопка карточки знакомства: вставить пример в строку
  ///
  /// In en, this message translates to:
  /// **'Try it'**
  String get startTry;

  /// Подсказка кнопки «×» карточки знакомства
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get startSkip;

  /// Пример шага 3: разбор строки должен поставить напоминание
  ///
  /// In en, this message translates to:
  /// **'Call mom tomorrow at 10'**
  String get startRemindExample;

  /// Пример шага 4, с пробелом в конце
  ///
  /// In en, this message translates to:
  /// **'@Shopping '**
  String get startFolderExample;

  /// Пример шага 5, с пробелом в конце
  ///
  /// In en, this message translates to:
  /// **'#idea '**
  String get startTagExample;

  /// Пояснение в панели над строкой после голого #
  ///
  /// In en, this message translates to:
  /// **'Type a word: #idea, #work'**
  String get lineExplainTag;

  /// Пояснение в панели над строкой после голой @
  ///
  /// In en, this message translates to:
  /// **'Type a name: I\'ll pick it if it exists, or create it'**
  String get lineExplainFolder;

  /// Подсказка на странице заметки над нижней панелью
  ///
  /// In en, this message translates to:
  /// **'Below: remind, tag, another folder and share.'**
  String get tipNoteBar;

  /// Подсказка на главной
  ///
  /// In en, this message translates to:
  /// **'Press and hold a note to pin, move or delete it.'**
  String get tipLongPress;

  /// Подсказка в каталоге
  ///
  /// In en, this message translates to:
  /// **'Press and drag a folder to change the order.'**
  String get tipCatalog;

  /// Подсказка на экране папки про меню «три точки»
  ///
  /// In en, this message translates to:
  /// **'The three dots on top: a folder inside, canvas, base, name and color.'**
  String get tipFolderMenu;

  /// Подсказка в папке «Без папки» под кнопкой «Разобрать»
  ///
  /// In en, this message translates to:
  /// **'“Sort” shows notes one by one, and you put each into a folder.'**
  String get tipSort;

  /// Подсказка на холсте
  ///
  /// In en, this message translates to:
  /// **'Double-tap an empty spot to add a card.'**
  String get tipCanvas;

  /// Подсказка на экране базы
  ///
  /// In en, this message translates to:
  /// **'Icons on top: sort, group, filter, columns, search.'**
  String get tipBase;

  /// Подсказка на экране «Разбор ИИ», пока ключа нет
  ///
  /// In en, this message translates to:
  /// **'You get a key from an AI provider, openrouter.ai has free models.'**
  String get tipAiKey;

  /// Подсказка на экране «Под рукой»
  ///
  /// In en, this message translates to:
  /// **'Spines are thin tabs at the screen edge, pull them inward.'**
  String get tipEdge;

  /// Подсказка кнопки «×» у подсказки по месту
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get tipClose;

  /// Переключатель подсказок в разделе «Помощь»
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get hintsToggle;

  /// Строка в разделе «Помощь»
  ///
  /// In en, this message translates to:
  /// **'Restart the tour'**
  String get hintsRestart;

  /// Плашка после «Начать знакомство заново»
  ///
  /// In en, this message translates to:
  /// **'The tour will start on the home screen'**
  String get hintsRestarted;

  /// Раздел экрана «Хранилище»: куда класть фото и файлы
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachmentsSection;

  /// Вариант места вложений
  ///
  /// In en, this message translates to:
  /// **'In a shared folder'**
  String get attachmentsShared;

  /// Вариант места вложений
  ///
  /// In en, this message translates to:
  /// **'Next to the note'**
  String get attachmentsNear;

  /// Вариант места вложений
  ///
  /// In en, this message translates to:
  /// **'In a subfolder next to the note'**
  String get attachmentsSub;

  /// Вариант места вложений
  ///
  /// In en, this message translates to:
  /// **'In the vault root'**
  String get attachmentsRoot;

  /// Пояснение под выбором места вложений
  ///
  /// In en, this message translates to:
  /// **'Applies to new photos and files, old ones stay where they are.'**
  String get attachmentsHint;

  /// Подпись строки, когда в хранилище есть Obsidian
  ///
  /// In en, this message translates to:
  /// **'The same setting as in Obsidian'**
  String get attachmentsWithObsidian;

  /// Поле имени папки вложений
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get attachmentsNameLabel;

  /// Плашка: имя папки вложений не годится
  ///
  /// In en, this message translates to:
  /// **'This name won\'t work: no dot at the start and no “..”.'**
  String get attachmentsNameBad;

  /// Плашка: app.json Obsidian сломан
  ///
  /// In en, this message translates to:
  /// **'Obsidian settings can\'t be read, the choice wasn\'t saved.'**
  String get attachmentsObsidianBroken;

  /// Подсказка кнопки над блоком кода в заметке
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get codeCopy;

  /// Кнопка копирования кода на миг после касания
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get codeCopied;

  /// Под свёрнутым длинным блоком кода; число — строк в блоке
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Show all · {count} line} other{Show all · {count} lines}}'**
  String codeShowAll(int count);

  /// Под раскрытым длинным блоком кода
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get codeCollapse;

  /// Кнопка полосы разметки: обернуть выделенное в $…$
  ///
  /// In en, this message translates to:
  /// **'Formula'**
  String get mdMath;

  /// Кнопка полосы разметки, когда курсор в формуле: перейти, например, из числителя в знаменатель
  ///
  /// In en, this message translates to:
  /// **'Next formula field'**
  String get mdMathNext;

  /// Раздел настроек про поле ввода на главной
  ///
  /// In en, this message translates to:
  /// **'Input field'**
  String get settingsLine;

  /// Что делает Enter в строке
  ///
  /// In en, this message translates to:
  /// **'Enter key'**
  String get enterKeyTitle;

  /// Enter начинает новую строку
  ///
  /// In en, this message translates to:
  /// **'New line'**
  String get enterNewLine;

  /// Enter сразу сохраняет заметку, как кнопка «Закинуть»
  ///
  /// In en, this message translates to:
  /// **'Save the note'**
  String get enterStow;

  /// Пояснение под настройкой Enter, одно предложение
  ///
  /// In en, this message translates to:
  /// **'In the full-screen input field, Enter always starts a new line.'**
  String get enterHint;

  /// Пункт меню заметки: тихое уведомление висит, пока не уберут
  ///
  /// In en, this message translates to:
  /// **'Pin to notifications'**
  String get noticePin;

  /// Пункт меню заметки, уже закреплённой в уведомлениях
  ///
  /// In en, this message translates to:
  /// **'Remove from notifications'**
  String get noticeUnpin;

  /// Плашка после закрепления, с «Отменить»
  ///
  /// In en, this message translates to:
  /// **'Note pinned to notifications'**
  String get noticePinned;

  /// Плашка после снятия, с «Отменить»
  ///
  /// In en, this message translates to:
  /// **'Note removed from notifications'**
  String get noticeUnpinned;

  /// Канал уведомлений Android для заметок, закреплённых в уведомлениях
  ///
  /// In en, this message translates to:
  /// **'Pinned notes'**
  String get noticeChannel;

  /// Кнопка на закреплённом уведомлении
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get noticeRemove;

  /// Заголовок закреплённого уведомления заметки из скрытой папки, без текста
  ///
  /// In en, this message translates to:
  /// **'Pinned note'**
  String get noticeHiddenTitle;

  /// Settings row value when not signed in
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get syncOff;

  /// Пояснение на экране Stowa Sync: что даёт синхронизация
  ///
  /// In en, this message translates to:
  /// **'Your notes stay the same on your phone and on the web, and are encrypted before they leave the device.'**
  String get syncIntro;

  /// syncEmail
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get syncEmail;

  /// syncGetCode
  ///
  /// In en, this message translates to:
  /// **'Get code'**
  String get syncGetCode;

  /// Shown above the code field
  ///
  /// In en, this message translates to:
  /// **'We sent a code to {email}'**
  String syncCodeSent(String email);

  /// syncCode
  ///
  /// In en, this message translates to:
  /// **'Code from the email'**
  String get syncCode;

  /// syncSignIn
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get syncSignIn;

  /// syncResendIn
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds} s'**
  String syncResendIn(int seconds);

  /// syncResend
  ///
  /// In en, this message translates to:
  /// **'Send the code again'**
  String get syncResend;

  /// syncOtherEmail
  ///
  /// In en, this message translates to:
  /// **'Different email'**
  String get syncOtherEmail;

  /// syncWrongCode
  ///
  /// In en, this message translates to:
  /// **'The code is wrong or expired'**
  String get syncWrongCode;

  /// syncMailFailed
  ///
  /// In en, this message translates to:
  /// **'The email didn\'t go out. Check your connection and try again'**
  String get syncMailFailed;

  /// syncNoServer
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server'**
  String get syncNoServer;

  /// syncNow
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// syncRunning
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncRunning;

  /// syncLast
  ///
  /// In en, this message translates to:
  /// **'Synced at {time}'**
  String syncLast(String time);

  /// syncInactive
  ///
  /// In en, this message translates to:
  /// **'Sync isn\'t turned on for this account'**
  String get syncInactive;

  /// Stowa Sync не стал удалять разом много файлов на других устройствах
  ///
  /// In en, this message translates to:
  /// **'Many files disappeared at once, so they weren\'t deleted on your other devices'**
  String get syncMassDelete;

  /// syncVaultUnreadable
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the vault folder'**
  String get syncVaultUnreadable;

  /// syncOffline
  ///
  /// In en, this message translates to:
  /// **'The server is unreachable. Sync will resume on its own'**
  String get syncOffline;

  /// syncOtherVault
  ///
  /// In en, this message translates to:
  /// **'Another vault is being synced'**
  String get syncOtherVault;

  /// syncNoVault
  ///
  /// In en, this message translates to:
  /// **'Choose a vault folder first'**
  String get syncNoVault;

  /// syncSignOut
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get syncSignOut;

  /// Под кнопкой «Выйти» из Stowa Sync: заметки на телефоне или в браузере не пропадут
  ///
  /// In en, this message translates to:
  /// **'Your notes stay on this device.'**
  String get syncSignOutHint;

  /// Side panel with the main places of the app
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get wsSections;

  /// Home tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get wsHome;

  /// Button in the left panel that focuses the input line
  ///
  /// In en, this message translates to:
  /// **'Find or write'**
  String get wsFind;

  /// Split the window to the right
  ///
  /// In en, this message translates to:
  /// **'Split right'**
  String get wsSplitRight;

  /// Split the window downwards
  ///
  /// In en, this message translates to:
  /// **'Split down'**
  String get wsSplitDown;

  /// Close a tab
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get wsCloseTab;

  /// Show or hide the left side panel
  ///
  /// In en, this message translates to:
  /// **'Left panel'**
  String get wsLeftDock;

  /// Show or hide the right side panel
  ///
  /// In en, this message translates to:
  /// **'Right panel'**
  String get wsRightDock;

  /// Side panel with notes saved on this day in earlier years
  ///
  /// In en, this message translates to:
  /// **'A year ago'**
  String get wsYearAgo;

  /// Keyboard shortcuts settings
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get wsKeys;

  /// Toggle light and dark theme
  ///
  /// In en, this message translates to:
  /// **'Switch theme'**
  String get wsTheme;

  /// Where the notes are stored in the web version
  ///
  /// In en, this message translates to:
  /// **'In this browser'**
  String get wsInBrowser;

  /// Sync status: everything is up to date
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get wsSynced;

  /// Sync status: not signed in
  ///
  /// In en, this message translates to:
  /// **'Sync is off'**
  String get wsSyncOff;

  /// No description provided for @wsGroupNav.
  ///
  /// In en, this message translates to:
  /// **'Search and navigation'**
  String get wsGroupNav;

  /// No description provided for @wsGroupNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes and folders'**
  String get wsGroupNotes;

  /// No description provided for @wsGroupTabs.
  ///
  /// In en, this message translates to:
  /// **'Tabs and panes'**
  String get wsGroupTabs;

  /// No description provided for @wsGroupDocks.
  ///
  /// In en, this message translates to:
  /// **'Panels and layouts'**
  String get wsGroupDocks;

  /// No description provided for @wsCmdPalette.
  ///
  /// In en, this message translates to:
  /// **'All commands'**
  String get wsCmdPalette;

  /// No description provided for @wsCmdSwitch.
  ///
  /// In en, this message translates to:
  /// **'Open note by title'**
  String get wsCmdSwitch;

  /// No description provided for @wsCmdHome.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get wsCmdHome;

  /// No description provided for @wsCmdNew.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get wsCmdNew;

  /// No description provided for @wsCmdTrash.
  ///
  /// In en, this message translates to:
  /// **'Move to trash'**
  String get wsCmdTrash;

  /// No description provided for @wsCmdPin.
  ///
  /// In en, this message translates to:
  /// **'Pin note'**
  String get wsCmdPin;

  /// No description provided for @wsCmdMove.
  ///
  /// In en, this message translates to:
  /// **'Move to folder'**
  String get wsCmdMove;

  /// No description provided for @wsCmdReopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen closed tab'**
  String get wsCmdReopen;

  /// No description provided for @wsCmdNext.
  ///
  /// In en, this message translates to:
  /// **'Next tab'**
  String get wsCmdNext;

  /// No description provided for @wsCmdPrev.
  ///
  /// In en, this message translates to:
  /// **'Previous tab'**
  String get wsCmdPrev;

  /// No description provided for @wsCmdNextPane.
  ///
  /// In en, this message translates to:
  /// **'Next pane'**
  String get wsCmdNextPane;

  /// No description provided for @wsCmdPrevPane.
  ///
  /// In en, this message translates to:
  /// **'Previous pane'**
  String get wsCmdPrevPane;

  /// No description provided for @wsCmdClosePane.
  ///
  /// In en, this message translates to:
  /// **'Close pane'**
  String get wsCmdClosePane;

  /// No description provided for @wsCmdTheme.
  ///
  /// In en, this message translates to:
  /// **'Light or dark theme'**
  String get wsCmdTheme;

  /// Between the two keys of a two-step shortcut: G then H
  ///
  /// In en, this message translates to:
  /// **'then'**
  String get wsThen;

  /// No description provided for @wsKeysHint.
  ///
  /// In en, this message translates to:
  /// **'A single key without Ctrl or Alt works when the cursor is not in a text field, and keys are matched by their place on the keyboard in any layout.'**
  String get wsKeysHint;

  /// No description provided for @wsKeysResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all'**
  String get wsKeysResetAll;

  /// No description provided for @wsKeysAdd.
  ///
  /// In en, this message translates to:
  /// **'Add shortcut'**
  String get wsKeysAdd;

  /// No description provided for @wsKeysPress.
  ///
  /// In en, this message translates to:
  /// **'Press a shortcut · Esc to cancel'**
  String get wsKeysPress;

  /// The new shortcut was taken from another command
  ///
  /// In en, this message translates to:
  /// **'Shortcut removed from “{name}”'**
  String wsKeysTaken(String name);

  /// No description provided for @wsKeysBrowser.
  ///
  /// In en, this message translates to:
  /// **'The browser keeps this shortcut for itself'**
  String get wsKeysBrowser;

  /// No description provided for @wsKeysReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get wsKeysReset;

  /// No description provided for @wsKeysRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get wsKeysRemove;

  /// No description provided for @wsChanged.
  ///
  /// In en, this message translates to:
  /// **'changed'**
  String get wsChanged;

  /// No description provided for @wsPaletteHint.
  ///
  /// In en, this message translates to:
  /// **'Command or note title'**
  String get wsPaletteHint;

  /// No description provided for @wsOpenNoteFirst.
  ///
  /// In en, this message translates to:
  /// **'Open a note first'**
  String get wsOpenNoteFirst;

  /// No description provided for @wsAddPanel.
  ///
  /// In en, this message translates to:
  /// **'Panel'**
  String get wsAddPanel;

  /// No description provided for @wsToRight.
  ///
  /// In en, this message translates to:
  /// **'Move to the right panel'**
  String get wsToRight;

  /// No description provided for @wsToLeft.
  ///
  /// In en, this message translates to:
  /// **'Move to the left panel'**
  String get wsToLeft;

  /// No description provided for @wsHidePanel.
  ///
  /// In en, this message translates to:
  /// **'Remove panel'**
  String get wsHidePanel;

  /// No description provided for @wsPanelEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get wsPanelEmpty;

  /// Подпись поверх холста, пока над ним тащат файлы из системы
  ///
  /// In en, this message translates to:
  /// **'Drop to put the files on the canvas'**
  String get canvasDropHint;

  /// Заголовок экрана во второй вкладке браузера: хранилище занято первой вкладкой
  ///
  /// In en, this message translates to:
  /// **'Stowa is already open in another tab'**
  String get tabBusyTitle;

  /// Одно предложение под заголовком экрана второй вкладки: почему Stowa здесь не открылась
  ///
  /// In en, this message translates to:
  /// **'Two tabs at once would damage your notes, so only one works.'**
  String get tabBusyHint;

  /// Кнопка на экране второй вкладки: перенести работу в эту вкладку, прежняя закроет заметки
  ///
  /// In en, this message translates to:
  /// **'Open here'**
  String get tabBusyOpenHere;

  /// Подпись вместо кнопки, пока прежняя вкладка дописывает файлы и освобождает хранилище
  ///
  /// In en, this message translates to:
  /// **'The other tab is closing your notes…'**
  String get tabBusyWaiting;

  /// Вопрос перед восстановлением копии без снимка базы (её делает браузер): файлы копии добавляются к нынешним, ничего не стирается
  ///
  /// In en, this message translates to:
  /// **'Add the notes from the copy made on {date}? Your current notes stay, files with the same name are replaced.'**
  String backupMergeAsk(String date);

  /// Кнопка согласия на восстановление копии без снимка базы: заметки копии добавляются к нынешним
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get backupAdd;

  /// Плашка на главной в браузере, пока человек ни разу не сохранял резервную копию. Одно предложение
  ///
  /// In en, this message translates to:
  /// **'Your notes live only in this browser: save a copy so you don\'t lose them.'**
  String get copyNudgeFirst;

  /// Плашка на главной в браузере, когда с последней резервной копии прошла неделя или набралось много правок
  ///
  /// In en, this message translates to:
  /// **'Your copy of the notes is out of date: save a fresh one.'**
  String get copyNudgeStale;

  /// Кнопка плашки о резервной копии: отложить напоминание на неделю
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get copyNudgeLater;

  /// Плашка на главной в браузере, когда база работает в памяти или в ненадёжном режиме (приватное окно, старый браузер)
  ///
  /// In en, this message translates to:
  /// **'The browser gave no reliable storage: your notes may be gone once the tab is closed.'**
  String get storageWeak;

  /// Пояснение под строкой открытого хранилища в настройках веб-версии. Одно предложение
  ///
  /// In en, this message translates to:
  /// **'Your notes live in this browser\'s storage and do not show up as files on the disk.'**
  String get vaultBrowserHint;

  /// Ход сборки указателя: файлы хранилища без своей заметки
  ///
  /// In en, this message translates to:
  /// **'Checking files: {done} of {total}'**
  String vaultBuildingFiles(int done, int total);

  /// Ход сборки указателя: добытое о заметках и история правок из служебной папки
  ///
  /// In en, this message translates to:
  /// **'Finishing the index: {done} of {total}'**
  String vaultBuildingExtras(int done, int total);

  /// Пустая главная на сайте: заголовок
  ///
  /// In en, this message translates to:
  /// **'Your notes will live here'**
  String get wsEmptyTitle;

  /// Пустая главная на сайте: одно предложение под заголовком
  ///
  /// In en, this message translates to:
  /// **'Drop a thought, link or file into the line below, and Stowa sorts it into folders.'**
  String get wsEmptyBody;

  /// Пустая главная: плитка, ставит курсор в строку
  ///
  /// In en, this message translates to:
  /// **'Write the first note'**
  String get wsEmptyWrite;

  /// Пустая главная: плитка, создаёт папку
  ///
  /// In en, this message translates to:
  /// **'Make a folder'**
  String get wsEmptyFolder;

  /// Пустая главная: плитка, открывает настройки хранилища с восстановлением копии
  ///
  /// In en, this message translates to:
  /// **'Restore a backup'**
  String get wsEmptyRestore;

  /// Свойства заметки на мониторе: строка папки
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get itemPropFolder;

  /// Свойства заметки на мониторе: строка тегов
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get itemPropTags;

  /// Свойства заметки на мониторе: строка напоминания
  ///
  /// In en, this message translates to:
  /// **'Remind'**
  String get itemPropRemind;

  /// Свойства заметки на мониторе: где записана
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get itemPropPlace;

  /// Свойства заметки на мониторе: когда записана
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get itemPropCreated;

  /// Свойства заметки на мониторе: когда и чем снято фото
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get itemPropTaken;

  /// Свойства заметки на мониторе: связи с другими заметками
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get itemPropLinks;

  /// Заметка из одной строки на мониторе: приглашение дописать под заголовком
  ///
  /// In en, this message translates to:
  /// **'Add some text…'**
  String get itemWriteMore;

  /// Граф связей строится: подпись под крутящимся кругом
  ///
  /// In en, this message translates to:
  /// **'Laying out the links…'**
  String get graphLoading;

  /// Шапка папки на мониторе: вложенных папок много, две строки меток, кнопка показать все
  ///
  /// In en, this message translates to:
  /// **'All {count, plural, one{{count} folder} other{{count} folders}}'**
  String folderSubAll(int count);

  /// Шапка папки на мониторе: свернуть метки вложенных папок обратно в две строки
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get folderSubLess;

  /// Строка под датой заметки без места
  ///
  /// In en, this message translates to:
  /// **'Add place'**
  String get itemPlaceAdd;

  /// Подпись пилюли «+ Место» в свойствах заметки
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get itemPlaceAddShort;

  /// Заголовок листа выбора места
  ///
  /// In en, this message translates to:
  /// **'Note place'**
  String get itemPlaceTitle;

  /// itemPlaceShowMap
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get itemPlaceShowMap;

  /// itemPlacePickMap
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get itemPlacePickMap;

  /// itemPlaceRemove
  ///
  /// In en, this message translates to:
  /// **'Remove place'**
  String get itemPlaceRemove;

  /// itemPlaceRemoved
  ///
  /// In en, this message translates to:
  /// **'Place removed'**
  String get itemPlaceRemoved;

  /// Кнопка на карте выбора места заметки
  ///
  /// In en, this message translates to:
  /// **'Put it here'**
  String get itemPlaceSetHere;

  /// itemPlaceMapHint
  ///
  /// In en, this message translates to:
  /// **'Move the map, the pin marks the place'**
  String get itemPlaceMapHint;

  /// placesNoFixBrowser
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t tell where you are. Check that the browser lets Stowa use your location.'**
  String get placesNoFixBrowser;

  /// rulesTab
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get rulesTab;

  /// tagsIntro
  ///
  /// In en, this message translates to:
  /// **'A label across folders: type #word in the line and find those notes from any folder.'**
  String get tagsIntro;

  /// rulesIntro
  ///
  /// In en, this message translates to:
  /// **'A rule sorts new notes for you: it spots a tag, site or word and files the note or adds a tag.'**
  String get rulesIntro;

  /// rulesWhenWorks
  ///
  /// In en, this message translates to:
  /// **'Rules apply to new notes and leave alone what you filed yourself.'**
  String get rulesWhenWorks;

  /// rulesEmpty
  ///
  /// In en, this message translates to:
  /// **'No rules yet: start with an example below.'**
  String get rulesEmpty;

  /// rulesExamples
  ///
  /// In en, this message translates to:
  /// **'Examples'**
  String get rulesExamples;

  /// ruleWhenTag
  ///
  /// In en, this message translates to:
  /// **'Has tag #{tag}'**
  String ruleWhenTag(String tag);

  /// ruleWhenSite
  ///
  /// In en, this message translates to:
  /// **'Link from {site}'**
  String ruleWhenSite(String site);

  /// ruleWhenWord
  ///
  /// In en, this message translates to:
  /// **'Text contains “{word}”'**
  String ruleWhenWord(String word);

  /// ruleWhenKind
  ///
  /// In en, this message translates to:
  /// **'Note type: {kind}'**
  String ruleWhenKind(String kind);

  /// ruleWhenPage
  ///
  /// In en, this message translates to:
  /// **'Page: {page}'**
  String ruleWhenPage(String page);

  /// ruleWhenPriceAbove
  ///
  /// In en, this message translates to:
  /// **'Price over {value}'**
  String ruleWhenPriceAbove(String value);

  /// ruleWhenPriceBelow
  ///
  /// In en, this message translates to:
  /// **'Price under {value}'**
  String ruleWhenPriceBelow(String value);

  /// ruleDoFolder
  ///
  /// In en, this message translates to:
  /// **'to folder “{folder}”'**
  String ruleDoFolder(String folder);

  /// ruleDoTag
  ///
  /// In en, this message translates to:
  /// **'add tag #{tag}'**
  String ruleDoTag(String tag);

  /// ruleDoRemind
  ///
  /// In en, this message translates to:
  /// **'remind {when}'**
  String ruleDoRemind(String when);

  /// ruleCondTag
  ///
  /// In en, this message translates to:
  /// **'Has a tag'**
  String get ruleCondTag;

  /// ruleCondTagHint
  ///
  /// In en, this message translates to:
  /// **'You added a #tag while writing'**
  String get ruleCondTagHint;

  /// ruleCondSite
  ///
  /// In en, this message translates to:
  /// **'Link from a site'**
  String get ruleCondSite;

  /// ruleCondSiteHint
  ///
  /// In en, this message translates to:
  /// **'For example, videos from youtube.com'**
  String get ruleCondSiteHint;

  /// ruleCondWord
  ///
  /// In en, this message translates to:
  /// **'Word in the text'**
  String get ruleCondWord;

  /// ruleCondWordHint
  ///
  /// In en, this message translates to:
  /// **'For example, “buy” or “recipe”'**
  String get ruleCondWordHint;

  /// ruleCondKind
  ///
  /// In en, this message translates to:
  /// **'Note type'**
  String get ruleCondKind;

  /// ruleCondKindHint
  ///
  /// In en, this message translates to:
  /// **'Photo, video, voice, file or link'**
  String get ruleCondKindHint;

  /// ruleCondPage
  ///
  /// In en, this message translates to:
  /// **'Page type'**
  String get ruleCondPage;

  /// ruleCondPageHint
  ///
  /// In en, this message translates to:
  /// **'A link to a recipe, product, event or film'**
  String get ruleCondPageHint;

  /// ruleCondPriceAbove
  ///
  /// In en, this message translates to:
  /// **'Price over'**
  String get ruleCondPriceAbove;

  /// ruleCondPriceAboveHint
  ///
  /// In en, this message translates to:
  /// **'The note has a higher amount'**
  String get ruleCondPriceAboveHint;

  /// ruleCondPriceBelow
  ///
  /// In en, this message translates to:
  /// **'Price under'**
  String get ruleCondPriceBelow;

  /// ruleCondPriceBelowHint
  ///
  /// In en, this message translates to:
  /// **'The note has a lower amount'**
  String get ruleCondPriceBelowHint;

  /// ruleActFolder
  ///
  /// In en, this message translates to:
  /// **'Put in a folder'**
  String get ruleActFolder;

  /// ruleActFolderHint
  ///
  /// In en, this message translates to:
  /// **'The note goes straight into that folder'**
  String get ruleActFolderHint;

  /// ruleActTag
  ///
  /// In en, this message translates to:
  /// **'Add a tag'**
  String get ruleActTag;

  /// ruleActTagHint
  ///
  /// In en, this message translates to:
  /// **'The note gets a tag'**
  String get ruleActTagHint;

  /// ruleActRemind
  ///
  /// In en, this message translates to:
  /// **'Remind in advance'**
  String get ruleActRemind;

  /// ruleActRemindHint
  ///
  /// In en, this message translates to:
  /// **'Events only: before they start'**
  String get ruleActRemindHint;

  /// ruleStepWhen
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get ruleStepWhen;

  /// ruleStepDo
  ///
  /// In en, this message translates to:
  /// **'Then'**
  String get ruleStepDo;

  /// ruleFolderPick
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get ruleFolderPick;

  /// ruleSaveButton
  ///
  /// In en, this message translates to:
  /// **'Save rule'**
  String get ruleSaveButton;

  /// ruleValueTagHint
  ///
  /// In en, this message translates to:
  /// **'for example, work'**
  String get ruleValueTagHint;

  /// ruleValueWordHint
  ///
  /// In en, this message translates to:
  /// **'for example, buy'**
  String get ruleValueWordHint;

  /// ruleValueSiteHint
  ///
  /// In en, this message translates to:
  /// **'for example, youtube.com'**
  String get ruleValueSiteHint;

  /// Имя тега в примере правила, строчными
  ///
  /// In en, this message translates to:
  /// **'video'**
  String get ruleExampleVideoTag;

  /// Слово в примере правила
  ///
  /// In en, this message translates to:
  /// **'buy'**
  String get ruleExampleBuyWord;

  /// Имя тега в примере правила, строчными
  ///
  /// In en, this message translates to:
  /// **'shopping'**
  String get ruleExampleShoppingTag;

  /// tagFolderRow
  ///
  /// In en, this message translates to:
  /// **'File into folder'**
  String get tagFolderRow;

  /// tagFolderNone
  ///
  /// In en, this message translates to:
  /// **'Don\'t file'**
  String get tagFolderNone;

  /// tagFolderHint
  ///
  /// In en, this message translates to:
  /// **'This is a rule: see or turn it off in the Rules tab.'**
  String get tagFolderHint;

  /// tagPinHint
  ///
  /// In en, this message translates to:
  /// **'The tag appears in the row at the top of Home'**
  String get tagPinHint;

  /// Границы под табло калькулятора: «От 40 до 100 %»
  ///
  /// In en, this message translates to:
  /// **'From {min} to {max}'**
  String numberPadRange(String min, String max);

  /// Подсказка у числа рядом с ползунком: касание открывает калькулятор
  ///
  /// In en, this message translates to:
  /// **'Type a number'**
  String get numberPadOpen;

  /// Подсказка у тега и кнопка в листе тега: показать на главной заметки с ним
  ///
  /// In en, this message translates to:
  /// **'Notes with #{tag}'**
  String tagShowNotes(String tag);

  /// Подзаголовок боковой панели браузера в лёгком режиме
  ///
  /// In en, this message translates to:
  /// **'Notes and search go through your open Stowa tab.'**
  String get panelHint;

  /// panelEmpty
  ///
  /// In en, this message translates to:
  /// **'Write a thought or look up a note: the line does both.'**
  String get panelEmpty;

  /// panelLocked
  ///
  /// In en, this message translates to:
  /// **'Search is locked by the app code; you can still write.'**
  String get panelLocked;

  /// panelOpened
  ///
  /// In en, this message translates to:
  /// **'Opened in the Stowa tab'**
  String get panelOpened;

  /// Заголовок списка заметок, записанных из панели за этот раз
  ///
  /// In en, this message translates to:
  /// **'Just saved'**
  String get panelSaved;
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
