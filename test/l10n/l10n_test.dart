import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kladovka/l10n/app_language.dart';

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map<String, dynamic>;

Iterable<String> _keys(Map<String, dynamic> arb) => arb.keys.where((key) => !key.startsWith('@'));

void main() {
  test('словари заведены на все семь языков', () {
    for (final language in AppLanguage.values) {
      expect(File('lib/l10n/app_${language.code}.arb').existsSync(), isTrue, reason: language.code);
      expect(_arb(language.code)['@@locale'], language.code);
    }
  });

  test('русский и английский заполнены целиком', () {
    final english = _arb('en');
    final russian = _arb('ru');
    for (final key in _keys(english)) {
      expect(russian[key], isA<String>(), reason: 'нет русского для $key');
      expect((russian[key] as String).trim(), isNotEmpty, reason: key);
    }
  });

  test('в английском и прочих языках нет русских букв', () {
    final cyrillic = RegExp('[А-Яа-яЁё]');
    for (final code in ['en', 'ro', 'pl', 'de', 'es']) {
      for (final MapEntry(:key, :value) in _arb(code).entries) {
        if (key.startsWith('@') || value is! String) continue;
        expect(cyrillic.hasMatch(value), isFalse, reason: '$code: $key');
      }
    }
  });

  test('подстановки одни и те же во всех переводах', () {
    final holes = RegExp(r'\{(\w+)');
    final english = _arb('en');
    for (final language in AppLanguage.values) {
      final arb = _arb(language.code);
      for (final key in _keys(arb)) {
        final want = holes.allMatches(english[key] as String).map((m) => m[1]).toSet();
        final got = holes.allMatches(arb[key] as String).map((m) => m[1]).toSet();
        expect(got, want, reason: '${language.code}: $key');
      }
    }
  });

  test('язык устройства подбирается, иначе английский', () {
    expect(AppLanguage.resolve([const Locale('ru', 'MD')]), AppLanguage.ru);
    expect(AppLanguage.resolve([const Locale('ro', 'MD')]), AppLanguage.ro);
    expect(AppLanguage.resolve([const Locale('fr'), const Locale('de')]), AppLanguage.de);
    expect(AppLanguage.resolve([const Locale('ja')]), AppLanguage.en);
    expect(AppLanguage.resolve(const []), AppLanguage.en);
  });

  test('название языка написано на нём самом', () {
    expect(AppLanguage.ru.label, 'Русский');
    expect(AppLanguage.uk.label, 'Українська');
    expect(AppLanguage.ro.label, 'Română');
  });
}
