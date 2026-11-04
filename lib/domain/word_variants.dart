/// Как ещё могли написать слово: транслитом или в чужой раскладке.
///
/// «Kupit kofe» находит «Купить кофе», «кофе» находит «kofe», а «rjat»,
/// набранное без переключения раскладки, находит «кофе».
library;

import 'word_forms.dart';

/// Вариант слова для поиска. Вес ниже единицы: совпадение по варианту
/// ставится ниже совпадения по самому слову.
class WordVariant {
  const WordVariant(this.text, this.weight);

  final String text;
  final double weight;
}

const _translitWeight = 0.9;
const _layoutWeight = 0.85;

// сначала многобуквенные сочетания: «shch» раньше «sh» и «ch»
const _latinToCyrillic = [
  ('shch', 'щ'), ('sch', 'щ'), ('zh', 'ж'), ('kh', 'х'), ('ts', 'ц'), ('ch', 'ч'), ('sh', 'ш'),
  ('yu', 'ю'), ('ya', 'я'), ('yo', 'е'), ('ye', 'е'), ('ju', 'ю'), ('ja', 'я'), ('jo', 'е'),
  ('a', 'а'), ('b', 'б'), ('v', 'в'), ('w', 'в'), ('g', 'г'), ('d', 'д'), ('e', 'е'), ('z', 'з'),
  ('i', 'и'), ('j', 'й'), ('k', 'к'), ('l', 'л'), ('m', 'м'), ('n', 'н'), ('o', 'о'), ('p', 'п'),
  ('r', 'р'), ('s', 'с'), ('t', 'т'), ('u', 'у'), ('f', 'ф'), ('h', 'х'), ('q', 'к'), ('x', 'кс'),
];

const _cyrillicToLatin = {
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ж': 'zh', 'з': 'z', 'и': 'i',
  'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's',
  'т': 't', 'у': 'u', 'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch',
  'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
  'і': 'i', 'ї': 'yi', 'є': 'ye', 'ґ': 'g',
};

const _latinVowels = 'aeiouy';

/// Транслит в кириллицу: «kofe» → «кофе». «y» после гласной — «й», иначе «ы»;
/// «c» перед e, i, y — «ц», иначе «к».
String toCyrillic(String latin) {
  final word = foldText(latin);
  final out = StringBuffer();
  var index = 0;
  while (index < word.length) {
    final char = word[index];
    if (char == 'y') {
      final afterVowel = index > 0 && _latinVowels.contains(word[index - 1]);
      final pair = index + 1 < word.length ? word.substring(index, index + 2) : '';
      if (!['ya', 'yu', 'yo', 'ye'].contains(pair)) {
        out.write(afterVowel ? 'й' : 'ы');
        index++;
        continue;
      }
    }
    if (char == 'c' && (index + 1 >= word.length || word[index + 1] != 'h')) {
      final next = index + 1 < word.length ? word[index + 1] : '';
      out.write('eiy'.contains(next) && next.isNotEmpty ? 'ц' : 'к');
      index++;
      continue;
    }
    final match = _latinToCyrillic.where((pair) => word.startsWith(pair.$1, index)).firstOrNull;
    if (match == null) {
      out.write(char);
      index++;
    } else {
      out.write(match.$2);
      index += match.$1.length;
    }
  }
  return out.toString();
}

/// Транслит в латиницу: «кофе» → «kofe», «їжак» → «yizhak».
String toLatin(String cyrillic) => [for (final char in foldText(cyrillic).split('')) _cyrillicToLatin[char] ?? char].join();

// раскладки по клавишам: латиница → русская и украинская
const _qwerty = r"qwertyuiop[]asdfghjkl;'zxcvbnm,.`";
const _ru = 'йцукенгшщзхъфывапролджэячсмитьбюё';
const _uk = "йцукенгшщзхїфівапролджєячсмитьбю'";

final _toRu = {for (var index = 0; index < _qwerty.length; index++) _qwerty[index]: _ru[index]};
final _toUk = {for (var index = 0; index < _qwerty.length; index++) _qwerty[index]: _uk[index]};
final _fromRu = {for (final entry in _toRu.entries) entry.value: entry.key};
final _fromUk = {for (final entry in _toUk.entries) entry.value: entry.key};

/// Слово, набранное не в той раскладке: «rjat» → «кофе», «ащещ» → «foto».
/// Украинская раскладка добавляется, когда отличается от русской.
/// Слово с цифрами или с буквами вне раскладки не перекладывается.
List<String> swapLayouts(String token) {
  final lower = token.toLowerCase();
  if (lower.isEmpty || RegExp(r'\d').hasMatch(lower)) return const [];
  String? through(Map<String, String> map) {
    final out = StringBuffer();
    for (final char in lower.split('')) {
      final mapped = map[char];
      if (mapped == null) return null;
      out.write(mapped);
    }
    return out.toString();
  }

  return {?through(_toRu), ?through(_toUk), ?through(_fromRu), ?through(_fromUk)}.where((variant) => variant != lower).toList();
}

/// Само слово и его варианты, без повторов. Само слово — первым и с весом 1.
List<WordVariant> variantsOf(String word) {
  final own = foldText(word);
  final seen = <String>{own};
  final variants = [WordVariant(own, 1)];
  void add(String text, double weight) {
    final folded = foldText(text);
    if (folded.length >= 2 && seen.add(folded)) variants.add(WordVariant(folded, weight));
  }

  final cyrillic = RegExp('[а-яіїєґ]').hasMatch(own);
  add(cyrillic ? toLatin(own) : toCyrillic(own), _translitWeight);
  for (final swapped in swapLayouts(word)) {
    add(swapped, _layoutWeight);
  }
  return variants;
}
