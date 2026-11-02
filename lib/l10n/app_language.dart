import 'dart:ui';

/// Языки интерфейса. Словари — `lib/l10n/app_<код>.arb`.
///
/// Шаблон английский: строка, которую ещё не перевели, достаётся человеку
/// по-английски, а не по-русски. Русский и английский заполнены целиком,
/// остальные пополняются по мере перевода.
enum AppLanguage {
  ru('ru', 'Русский'),
  en('en', 'English'),
  uk('uk', 'Українська'),
  ro('ro', 'Română'),
  pl('pl', 'Polski'),
  de('de', 'Deutsch'),
  es('es', 'Español');

  const AppLanguage(this.code, this.label);

  final String code;

  /// Название на самом языке: список выбора читает тот, кто нашего не знает.
  final String label;

  Locale get locale => Locale(code);

  static List<Locale> get supportedLocales => [for (final language in values) language.locale];

  /// Первый из языков устройства, который у нас есть, иначе английский.
  static AppLanguage resolve(Iterable<Locale> deviceLocales) {
    for (final locale in deviceLocales) {
      for (final language in values) {
        if (language.code == locale.languageCode.toLowerCase()) return language;
      }
    }
    return en;
  }
}
