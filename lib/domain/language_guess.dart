/// На каком языке написан текст: по служебным словам (stopwords-iso, 58 языков), особым буквам
/// и письменности. Без словарей и без ИИ. Нужно разбору времени (свои таблицы или CLDR),
/// формам слов (правила Snowball под язык) и подсказке о языке, которого строка не понимает.
library;

import 'cldr_time_words.dart' show cldrTimeLanguages;
import 'stop_words.dart' show stopWordsByLanguage;
import 'word_forms.dart' show foldText;

/// Языки со своими таблицами времени и мест: языки интерфейса Stowa.
const ownLanguages = {'ru', 'uk', 'en', 'de', 'es', 'pl', 'ro'};

// у stopwords-iso филиппинский — «tl», у CLDR — «fil»; малайский по служебным словам
// от индонезийского не отличить, а время и формы слов у них общие
const _sameLanguage = {'tl': 'fil', 'ms': 'id'};

// у украинского в stopwords-iso нет даже «і» и «мені»
const _extraStopWords = {
  'uk': 'і в у на не мені мене мій моя треба потрібно буде щоб коли',
};

// служебное слово → языки, в которых оно служебное; собирается один раз
final Map<String, List<String>> _stopIndex = () {
  final index = <String, List<String>>{};
  for (final MapEntry(key: language, value: words) in {...stopWordsByLanguage, for (final extra in _extraStopWords.entries) extra.key: '${stopWordsByLanguage[extra.key]} ${extra.value}'}.entries) {
    final code = _sameLanguage[language] ?? language;
    for (final word in words.split(' ')) {
      final folded = foldText(word);
      final languages = index.putIfAbsent(folded, () => []);
      if (!languages.contains(code)) languages.add(code);
    }
  }
  return index;
}();

// буквы, которые пишут только в нескольких языках
const _letters = <String, List<String>>{
  'ı': ['tr', 'az'], 'ğ': ['tr', 'az'], 'ş': ['tr', 'az', 'ro'], 'ç': ['fr', 'pt', 'tr', 'ca', 'az', 'sq'],
  'ã': ['pt'], 'õ': ['pt', 'et'], 'œ': ['fr'], 'ß': ['de'], 'ñ': ['es', 'gl'],
  'ł': ['pl'], 'ż': ['pl'], 'ź': ['pl'], 'ś': ['pl'], 'ć': ['pl', 'hr', 'bs'], 'ń': ['pl'], 'ą': ['pl', 'lt'], 'ę': ['pl', 'lt'],
  'ő': ['hu'], 'ű': ['hu'], 'ř': ['cs'], 'ů': ['cs'], 'ě': ['cs'],
  'ă': ['ro'], 'ș': ['ro'], 'ț': ['ro'], 'ţ': ['ro'],
  'å': ['sv', 'no', 'da'], 'ø': ['no', 'da'], 'æ': ['no', 'da', 'is'], 'ð': ['is'], 'þ': ['is'],
  'ė': ['lt'], 'į': ['lt'], 'ų': ['lt'], 'ā': ['lv', 'mi'], 'ē': ['lv'], 'ī': ['lv'], 'ū': ['lv', 'lt'], 'ķ': ['lv'], 'ļ': ['lv'], 'ņ': ['lv'], 'ģ': ['lv'],
  'ŵ': ['cy'], 'ŷ': ['cy'], 'đ': ['hr', 'bs', 'vi'], 'ơ': ['vi'], 'ư': ['vi'],
  'ё': ['ru'], 'ы': ['ru', 'be'], 'э': ['ru', 'be'], 'ъ': ['ru', 'bg'],
  'ї': ['uk'], 'є': ['uk'], 'ґ': ['uk'], 'і': ['uk', 'be', 'kk'], 'ў': ['be'],
  'ђ': ['sr'], 'ћ': ['sr'], 'џ': ['sr', 'mk'], 'љ': ['sr', 'mk'], 'њ': ['sr', 'mk'], 'ј': ['sr', 'mk'], 'ѓ': ['mk'], 'ќ': ['mk'], 'ѕ': ['mk'],
  'ә': ['kk', 'tt'], 'ғ': ['kk'], 'қ': ['kk'], 'ұ': ['kk'], 'ң': ['kk', 'ky', 'tt'], 'ө': ['kk', 'ky', 'mn', 'tt'], 'ү': ['kk', 'ky', 'mn', 'tt'], 'җ': ['tt'],
};

// вьетнамские буквы с двумя знаками: ạ, ấ, ệ, ữ…
final _vietnamese = RegExp('[Ạ-ỹ]');

// письменности, по которым язык ясен сразу; арабская и деванагари уточняются служебными словами
final _scripts = <(RegExp, String)>[
  (RegExp(r'[぀-ヿ]'), 'ja'),
  (RegExp(r'[가-힯ᄀ-ᇿ]'), 'ko'),
  (RegExp(r'[一-鿿㐀-䶿]'), 'zh'),
  (RegExp(r'[Ͱ-Ͽἀ-῿]'), 'el'),
  (RegExp(r'[԰-֏]'), 'hy'),
  (RegExp(r'[Ⴀ-ჿ]'), 'ka'),
  (RegExp(r'[֐-׿]'), 'he'),
  (RegExp(r'[؀-ۿݐ-ݿ]'), 'ar'),
  (RegExp(r'[ऀ-ॿ]'), 'hi'),
  (RegExp(r'[ঀ-৿]'), 'bn'),
  (RegExp(r'[਀-੿]'), 'pa'),
  (RegExp(r'[઀-૿]'), 'gu'),
  (RegExp(r'[଀-୿]'), 'or'),
  (RegExp(r'[஀-௿]'), 'ta'),
  (RegExp(r'[ఀ-౿]'), 'te'),
  (RegExp(r'[ಀ-೿]'), 'kn'),
  (RegExp(r'[ഀ-ൿ]'), 'ml'),
  (RegExp(r'[඀-෿]'), 'si'),
  (RegExp(r'[฀-๿]'), 'th'),
  (RegExp(r'[຀-໿]'), 'lo'),
  (RegExp(r'[ༀ-࿿]'), 'bo'),
  (RegExp(r'[က-႟]'), 'my'),
  (RegExp(r'[ក-៿]'), 'km'),
  (RegExp(r'[ሀ-፿]'), 'am'),
  (RegExp(r'[Ꭰ-᏿ꭰ-ꮿ]'), 'chr'),
];

// внутри одной письменности: персидский и урду пишут арабскими буквами, маратхи и непальский — деванагари
const _sameScript = {
  'ar': {'ar', 'fa', 'ur', 'ps', 'ku'},
  'hi': {'hi', 'mr'},
};

// буквы не латиницы и не кириллицы
final _otherScript = RegExp(r'[^\P{L}\p{Script=Latin}\p{Script=Cyrillic}]', unicode: true);

final _word = RegExp(r'\p{L}+', unicode: true);

/// Язык текста: код ISO 639 («fr», «ja», «fil») или null, если признаков мало.
String? guessLanguage(String text) {
  final lower = text.toLowerCase();
  final scores = <String, double>{};
  // слово своё у одного языка весит 1, общее у многих («la», «de») — чуть больше половины:
  // так три общих слова французского перевешивают одно общее с испанским
  void add(Iterable<String> languages, double weight) {
    for (final language in languages) {
      scores[language] = (scores[language] ?? 0) + weight * (0.5 + 0.5 / languages.length);
    }
  }

  for (final match in _word.allMatches(lower)) {
    final languages = _stopIndex[foldText(match.group(0)!)];
    if (languages != null) add(languages, 1);
  }

  if (_otherScript.allMatches(lower).length >= 2) {
    // японский узнаётся по кане раньше иероглифов: они у него общие с китайским
    for (final (pattern, language) in _scripts) {
      if (!pattern.hasMatch(lower)) continue;
      final family = _sameScript[language];
      if (family == null) return language;
      final best = _best({for (final MapEntry(:key, :value) in scores.entries) if (family.contains(key)) key: value});
      return best ?? language;
    }
    return null;
  }

  // особая буква весит одно служебное слово, не больше двух на язык
  final seen = <String>{};
  for (final char in lower.split('')) {
    final languages = _letters[char];
    if (languages != null && seen.add(char)) add(languages, 1);
  }
  if (_vietnamese.hasMatch(lower)) add(['vi'], 2);
  return _best(scores);
}

// самый вероятный язык: от одного своего слова и заметно впереди второго
String? _best(Map<String, double> scores) {
  final ranked = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  if (ranked.isEmpty || ranked.first.value < 1) return null;
  if (ranked.length > 1 && ranked.first.value - ranked[1].value < 0.5) return null;
  return ranked.first.key;
}

/// Текст скорее на языке, где строка не поймёт и время: ни своих таблиц, ни CLDR.
/// Короткое и без служебных слов («Linella», «купить хлеб») — не повод так думать.
bool unsupportedLanguage(String text) {
  final language = guessLanguage(text);
  if (language == null) return false;
  if (ownLanguages.contains(language) || cldrTimeLanguages.contains(language)) return false;
  // по письменности язык ясен и в двух словах, по служебным словам — от трёх
  final otherScript = _otherScript.allMatches(text).length >= 2;
  return otherScript || _word.allMatches(text).length >= 3;
}
