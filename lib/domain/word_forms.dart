/// Слова и их формы на семи языках Stowa: ru, uk, en, de, es, ro, pl.
///
/// Без словарей и без ИИ: окончания срезаются по спискам каждого языка, как в
/// лёгких стеммерах (Snowball, Savoy). Основа нужна поиску по началу слова:
/// «креветками» → «креветк», и найдутся «креветки» и «креветка».
library;

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
  'ов', 'ев', 'ию', 'ью', 'ия', 'ья', 'ье', 'ии', 'ил', 'ыл', 'ет', 'ит', 'ят', 'ют', 'ут', 'ал', 'ял', 'ла', 'ли', 'ло',
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
final _en = _longestFirst(_enEndings);
final _de = _longestFirst(_deEndings);
final _es = _longestFirst(_esEndings);
final _ro = _longestFirst(_roEndings);
final _pl = _longestFirst(_plEndings);
final _latin = _longestFirst(_latinEndings);
final _esPl = _longestFirst([..._esEndings, ..._plEndings]);

/// Короче основа не бывает: «коф» ещё узнаётся, «ко» уже нет.
const _minStem = 3;

const _vowels = 'aeiouy';

/// Какие окончания у латинского слова: по особым буквам, иначе всех пяти языков.
List<String> _latinEndingsOf(String raw) {
  if (RegExp('[ăâîșşțţ]').hasMatch(raw)) return _ro;
  if (RegExp('[ąęłśźżćń]').hasMatch(raw)) return _pl;
  if (RegExp('[äöüß]').hasMatch(raw)) return _de;
  if (RegExp('[ñ¿¡áéíú]').hasMatch(raw)) return _es;
  // «ó» пишут и испанцы, и поляки
  if (raw.contains('ó')) return _esPl;
  return _latin;
}

/// Основа слова для поиска по началу: окончание срезано, знаки над буквами сняты.
String stemOf(String word) {
  final raw = word.toLowerCase();
  final folded = foldText(raw);
  if (folded.length <= _minStem || RegExp(r'\d').hasMatch(folded)) return folded;
  switch (_scriptOf(raw)) {
    case _Script.cyrillic:
      final ukrainian = RegExp('[іїєґ]').hasMatch(raw);
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
