import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/word_forms.dart';

/// Все формы из списка дают одну основу, и каждая форма начинается с неё —
/// поиск по началу слова найдёт любую.
void sameStem(List<String> forms) {
  final stems = {for (final form in forms) stemOf(form)};
  expect(stems, hasLength(1), reason: '$forms → $stems');
  for (final form in forms) {
    expect(foldText(form).startsWith(stems.single), isTrue, reason: '$form не начинается с ${stems.single}');
  }
}

void main() {
  group('буквы всех семи языков', () {
    test('слово не режется на особых буквах', () {
      expect(wordsOf('Straße, zdjęcie, țară, niño, їжак, Ёжик'), ['straße', 'zdjęcie', 'țară', 'niño', 'їжак', 'ёжик']);
    });

    test('свёртка убирает знаки над буквами и не меняет длину', () {
      for (final word in ['Häuser', 'zdjęcia', 'țărilor', 'niños', 'ёлка', 'ąęłóśźżćń']) {
        expect(foldText(word).length, word.length);
      }
      expect(foldText('Häuser'), 'hauser');
      expect(foldText('ąęłóśźżćń'), 'aeloszzcn');
      expect(foldText('ёлка'), 'елка');
      expect(foldText('țărilor'), 'tarilor');
    });

    test('украинские буквы остаются собой', () {
      expect(foldText('їжак і євро ґанок'), 'їжак і євро ґанок');
    });
  });

  group('формы слов', () {
    test('русский', () {
      // «креветок» с беглой гласной окончанием не срезать; его ловит поиск по началу «кревет…»
      sameStem(['креветки', 'креветками', 'креветка', 'креветке']);
      sameStem(['рецепт', 'рецепта', 'рецепты', 'рецептами']);
      sameStem(['купить', 'купил', 'купила', 'купили']);
      sameStem(['красный', 'красная', 'красное', 'красными']);
      // существительное на «-ла» — не прошедшее время глагола
      sameStem(['свёкла', 'свёклой', 'свёклу', 'свёклы']);
      sameStem(['школа', 'школы', 'школе', 'школой']);
    });

    test('украинский', () {
      sameStem(['рецепт', 'рецепти', 'рецептів', 'рецептами']);
      sameStem(['кава', 'кави', 'каву', 'кавою']);
    });

    test('английский', () {
      sameStem(['recipe', 'recipes']);
      sameStem(['running', 'runs', 'run']);
      sameStem(['shrimp', 'shrimps']);
    });

    test('немецкий', () {
      sameStem(['Haus', 'Häuser', 'Häusern', 'Hauses']);
      sameStem(['Rezept', 'Rezepte', 'Rezepten']);
    });

    test('испанский', () {
      sameStem(['receta', 'recetas']);
      sameStem(['camarón', 'camarones']);
    });

    test('румынский', () {
      sameStem(['rețetă', 'rețete', 'rețetele', 'rețetelor']);
      sameStem(['țară', 'țări', 'țările', 'țărilor']);
    });

    test('польский', () {
      sameStem(['przepis', 'przepisy', 'przepisów', 'przepisami']);
      sameStem(['zdjęcie', 'zdjęcia', 'zdjęciami']);
    });

    test('короткие слова и числа не режутся', () {
      expect(stemOf('кот'), 'кот');
      expect(stemOf('bus'), 'bus');
      expect(stemOf('2025'), '2025');
    });

    test('несклоняемое остаётся началом слова', () {
      expect('кофе'.startsWith(stemOf('кофе')), isTrue);
      expect(stemOf('кофе').length, greaterThanOrEqualTo(3));
    });
  });

  group('чужие языки по Snowball', () {
    test('основа под язык текста', () {
      expect(languageStem('talossa', 'fi'), languageStem('talo', 'fi'));
      expect(languageStem('chevaux', 'fr'), languageStem('cheval', 'fr'));
      expect(languageStem('kitapları', 'tr'), languageStem('kitap', 'tr'));
      expect(languageStem('casas', 'pt'), languageStem('casa', 'pt'));
      // свои семь языков и неизвестные — без Snowball
      expect(languageStem('домами', 'ru'), isNull);
      expect(languageStem('word', 'xx'), isNull);
    });

    test('основы запроса для поиска по началу: всех языков его письма, только срезанные', () {
      expect(languageStems('talossa'), contains('talo'));
      expect(languageStems('kitapları'), contains('kitap'));
      for (final stem in languageStems('talossa')) {
        expect('talossa'.startsWith(stem), isTrue, reason: stem);
        expect(stem.length, greaterThanOrEqualTo(4), reason: stem);
      }
    });
  });
}
