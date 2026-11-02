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
