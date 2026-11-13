/// Слова и их формы на семи языках Stowa: ru, uk, en, de, es, ro, pl.
///
/// Без словарей и без ИИ: окончания срезаются по спискам каждого языка, как в
/// лёгких стеммерах (Snowball, Savoy). Основа нужна поиску по началу слова:
/// «креветками» → «креветк», и найдутся «креветки» и «креветка».
///
/// Ещё 22 языка — по правилам Snowball (пакет snowball_stemmer): [languageStem] под язык
/// текста и [languageStems] для запроса, язык которого не узнать.
library;

import 'package:snowball_stemmer/snowball_stemmer.dart';

/// Знаки над латинскими буквами снимаются, длина слова не меняется: подсветка
/// найденного считает позиции по свёрнутому тексту.
const _latinFold = {
  'ä': 'a', 'à': 'a', 'á': 'a', 'â': 'a', 'ă': 'a', 'ą': 'a', 'ã': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ę': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ñ': 'n', 'ń': 'n', 'ç': 'c', 'ć': 'c', 'ł': 'l',
  'ś': 's', 'ș': 's', 'ş': 's', 'ț': 't', 'ţ': 't',
  'ź': 'z', 'ż': 'z', 'ý': 'y',
};

/// Нижний регистр, «ё» как «е», латиница без знаков над буквами. Украинские
/// і, ї, є, ґ остаются: это отдельные буквы, а не «и» со значком.
String foldText(String text) {
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final char in lower.split('')) {
    out.write(char == 'ё' ? 'е' : (_latinFold[char] ?? char));
  }
  return out.toString();
}

final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

/// Слова текста в нижнем регистре: режутся только по тому, что не буква и не цифра.
List<String> wordsOf(String text) => [for (final match in _word.allMatches(text.toLowerCase())) match.group(0)!];

/// Слова вместе с местом в тексте: для подсветки.
Iterable<RegExpMatch> wordMatches(String text) => _word.allMatches(text);

enum _Script { cyrillic, latin, other }

_Script _scriptOf(String word) {
  for (final code in word.runes) {
    if (code >= 0x400 && code <= 0x4FF) return _Script.cyrillic;
    if ((code >= 0x61 && code <= 0x7A) || (code >= 0xC0 && code <= 0x24F)) return _Script.latin;
  }
  return _Script.other;
}

/// Русские окончания: глаголы, прилагательные и причастия, существительные.
const _ruEndings = [
  'ившись', 'ывшись', 'вшись', 'ующими', 'ующего', 'ующему', 'ейшими',
  'иями', 'ями', 'ами', 'ыми', 'ими', 'ого', 'его', 'ому', 'ему', 'ией', 'иям', 'ием', 'иях',
  'ейте', 'уйте', 'ешь', 'ишь', 'ать', 'ять', 'ить', 'ыть', 'еть', 'уть', 'ться', 'тся',
  'ила', 'ыла', 'ена', 'ило', 'ыло', 'ено', 'или', 'ыли', 'ены', 'ает', 'яет', 'ует', 'ают', 'яют', 'уют',
  'ость', 'ости', 'ою', 'ею', 'ую', 'юю', 'ая', 'яя', 'ое', 'ее', 'ые', 'ие', 'ой', 'ей', 'ий', 'ый', 'ом', 'ем', 'ам', 'ям', 'ах', 'ях',
  // голых «ла», «ли», «ло» нет: они резали «свёкла» и «школа» как «купила»
  'ов', 'ев', 'ию', 'ью', 'ия', 'ья', 'ье', 'ии', 'ил', 'ыл', 'ет', 'ит', 'ят', 'ют', 'ут', 'ал', 'ял',
  'ся', 'сь', 'а', 'я', 'о', 'е', 'ы', 'и', 'у', 'ю', 'ь', 'й',
];

/// Украинские окончания поверх русских: ів, ові, ою, ями, ти…
const _ukEndings = [
  'ями', 'ами', 'ові', 'еві', 'ими', 'іми', 'ого', 'ому', 'ою', 'ею', 'ям', 'ам', 'ах', 'ях',
  'ити', 'ати', 'іти', 'ють', 'ать', 'ять', 'ить', 'ться', 'ся', 'сь',
  'ів', 'їв', 'ій', 'ий', 'ій', 'ії', 'ія', 'ім', 'им', 'ом', 'ем', 'ів',
  'і', 'ї', 'а', 'я', 'о', 'е', 'и', 'у', 'ю', 'ь', 'й',
];

const _enEndings = ['ingly', 'edly', 'ings', 'ing', 'ies', 'ied', 'ed', 'es', 'ly'];
const _deEndings = ['innen', 'ungen', 'ung', 'ern', 'em', 'en', 'er', 'es', 'e', 'n'];
const _esEndings = [
  'amientos', 'imientos', 'amiento', 'imiento', 'aciones', 'uciones', 'adoras', 'adores', 'ancias',
  'acion', 'ucion', 'adora', 'ador', 'ancia', 'mente', 'idad', 'ables', 'ibles', 'able', 'ible',
  'istas', 'ista', 'osos', 'osas', 'oso', 'osa', 'ando', 'iendo', 'ados', 'idos', 'adas', 'idas',
  'ado', 'ido', 'ada', 'ida', 'es', 'os', 'as', 'ar', 'er', 'ir', 'a', 'o', 'e',
];
const _roEndings = ['urilor', 'ilor', 'elor', 'urile', 'ului', 'iile', 'ile', 'ele', 'uri', 'lor', 'ul', 'ua', 'ea', 'ii', 'ie', 'le', 'ai', 'ei', 'a', 'e', 'i', 'u'];
const _plEndings = [
  'owiach', 'iami', 'iach', 'ami', 'ach', 'owie', 'ego', 'emu', 'ymi', 'imi', 'iom', 'iow',
  'ow', 'om', 'em', 'ie', 'ej', 'ia', 'iu', 'ym', 'im', 'a', 'e', 'i', 'o', 'u', 'y',
];

/// Латиница без особых букв: язык не узнать, поэтому окончания всех пяти.
final _latinEndings = {..._enEndings, ..._deEndings, ..._esEndings, ..._roEndings, ..._plEndings}.toList();

/// Списки отсортированы от длинного к короткому: срезается самое длинное подходящее.
List<String> _longestFirst(Iterable<String> endings) => endings.toSet().toList()..sort((a, b) => b.length.compareTo(a.length));

final _ru = _longestFirst(_ruEndings);
final _uk = _longestFirst([..._ukEndings, ..._ruEndings]);
final _de = _longestFirst(_deEndings);
final _es = _longestFirst(_esEndings);
final _ro = _longestFirst(_roEndings);
final _pl = _longestFirst(_plEndings);
final _latin = _longestFirst(_latinEndings);
final _esPl = _longestFirst([..._esEndings, ..._plEndings]);

/// Короче основа не бывает: «коф» ещё узнаётся, «ко» уже нет.
const _minStem = 3;

const _vowels = 'aeiouy';

// выражения собираются один раз: основа считается для каждого слова каждой заметки
final _roLetters = RegExp('[ăâîșşțţ]');
final _plLetters = RegExp('[ąęłśźżćń]');
final _deLetters = RegExp('[äöüß]');
final _esLetters = RegExp('[ñ¿¡áéíú]');
final _ukLetters = RegExp('[іїєґ]');
final _digit = RegExp(r'\d');

/// Какие окончания у латинского слова: по особым буквам, иначе всех пяти языков.
List<String> _latinEndingsOf(String raw) {
  if (_roLetters.hasMatch(raw)) return _ro;
  if (_plLetters.hasMatch(raw)) return _pl;
  if (_deLetters.hasMatch(raw)) return _de;
  if (_esLetters.hasMatch(raw)) return _es;
  // «ó» пишут и испанцы, и поляки
  if (raw.contains('ó')) return _esPl;
  return _latin;
}

/// Основа слова для поиска по началу: окончание срезано, знаки над буквами сняты.
String stemOf(String word) {
  final raw = word.toLowerCase();
  final folded = foldText(raw);
  if (folded.length <= _minStem || _digit.hasMatch(folded)) return folded;
  switch (_scriptOf(raw)) {
    case _Script.cyrillic:
      final ukrainian = _ukLetters.hasMatch(raw);
      return _cut(folded, ukrainian ? _uk : _ru);
    case _Script.latin:
      final endings = _latinEndingsOf(raw);
      var stem = _cut(folded, endings, latin: true);
      // running → runn → run: удвоенная согласная после срезанного окончания
      if (stem.length > _minStem && stem != folded && stem[stem.length - 1] == stem[stem.length - 2] && !_vowels.contains(stem[stem.length - 1])) {
        stem = stem.substring(0, stem.length - 1);
      }
      return stem;
    case _Script.other:
      return folded;
  }
}

String _cut(String word, List<String> endings, {bool latin = false}) {
  for (final ending in endings) {
    if (word.length - ending.length >= _minStem && word.endsWith(ending)) return word.substring(0, word.length - ending.length);
  }
  // одиночное «s» срезается только после согласной: shrimps → shrimp, но Haus остаётся Haus
  if (latin && word.length - 1 >= _minStem && word.endsWith('s')) {
    final before = word[word.length - 2];
    if (!_vowels.contains(before) && before != 's') return word.substring(0, word.length - 1);
  }
  return word;
}

// ---------------------------------------------------------------------------
// Чужие языки по правилам Snowball. Свои семь языков режет список окончаний выше:
// на нём стоят основы индекса и тесты поиска, менять их под Snowball незачем.

const _snowball = {
  'fr': Algorithm.french, 'it': Algorithm.italian, 'pt': Algorithm.portuguese, 'nl': Algorithm.dutch,
  'sv': Algorithm.swedish, 'no': Algorithm.norwegian, 'da': Algorithm.danish, 'fi': Algorithm.finnish,
  'hu': Algorithm.hungarian, 'tr': Algorithm.turkish, 'ca': Algorithm.catalan, 'eu': Algorithm.basque,
  'ga': Algorithm.irish, 'lt': Algorithm.lithuanian, 'id': Algorithm.indonesian, 'el': Algorithm.greek,
  'hy': Algorithm.armenian, 'ar': Algorithm.arabic, 'hi': Algorithm.hindi, 'ne': Algorithm.nepali,
  'ta': Algorithm.tamil, 'sr': Algorithm.serbian, 'hr': Algorithm.serbian, 'bs': Algorithm.serbian,
  'yi': Algorithm.yiddish,
};

// языки по письму: для запроса, язык которого по одному слову не узнать
const _latinSnowball = ['fr', 'it', 'pt', 'nl', 'sv', 'no', 'da', 'fi', 'hu', 'tr', 'ca', 'eu', 'ga', 'lt', 'id', 'hr'];
final _scriptSnowball = <(RegExp, List<String>)>[
  (RegExp('[Ͱ-Ͽἀ-῿]'), ['el']),
  (RegExp('[԰-֏]'), ['hy']),
  (RegExp('[؀-ۿ]'), ['ar']),
  (RegExp('[ऀ-ॿ]'), ['hi', 'ne']),
  (RegExp('[஀-௿]'), ['ta']),
  (RegExp('[֐-׿]'), ['yi']),
  (RegExp('[ђћџљњј]'), ['sr']),
];

final _stemmers = <String, SnowballStemmer>{};

// основа считается для каждого слова каждой найденной заметки: помнится
final _languageStemMemo = <String, String>{};
const _languageStemMemoSize = 20000;

/// Есть ли у языка правила Snowball сверх своих семи языков.
bool hasLanguageStems(String? language) => _snowball.containsKey(language);

/// Основа слова по правилам Snowball этого языка: «talossa» → «talo» (финский),
/// «chevaux» → «cheval» (французский). Нет правил — null.
String? languageStem(String word, String language) {
  final algorithm = _snowball[language];
  if (algorithm == null) return null;
  final key = '$language $word';
  if (_languageStemMemo.length >= _languageStemMemoSize) _languageStemMemo.clear();
  return _languageStemMemo[key] ??= _stemmers.putIfAbsent(language, () => SnowballStemmer(algorithm)).stem(word.toLowerCase());
}

/// Основы слова по правилам всех языков его письма, только срезанные и от 4 букв:
/// поиск по началу найдёт «talo» по запросу «talossa», не зная, что это финский.
Set<String> languageStems(String word) {
  final lower = word.toLowerCase();
  final languages = _scriptOf(lower) == _Script.latin
      ? _latinSnowball
      : [for (final (pattern, languages) in _scriptSnowball) if (pattern.hasMatch(lower)) ...languages];
  return {
    for (final language in languages)
      if (languageStem(lower, language) case final stem? when stem.length >= 4 && stem.length < lower.length && lower.startsWith(stem)) stem,
  };
}
