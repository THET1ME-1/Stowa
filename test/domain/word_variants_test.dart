import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/word_variants.dart';

void main() {
  group('транслит', () {
    test('латиница → кириллица', () {
      expect(toCyrillic('kofe'), 'кофе');
      expect(toCyrillic('zhurnal'), 'журнал');
      expect(toCyrillic('shchuka'), 'щука');
      expect(toCyrillic('chay'), 'чай');
      expect(toCyrillic('yabloko'), 'яблоко');
      expect(toCyrillic('kupit'), 'купит');
    });

    test('кириллица → латиница', () {
      expect(toLatin('кофе'), 'kofe');
      expect(toLatin('журнал'), 'zhurnal');
      expect(toLatin('купить'), 'kupit');
      expect(toLatin('щука'), 'shchuka');
      expect(toLatin('їжак'), 'yizhak');
      expect(toLatin('яблоко'), 'yabloko');
    });
  });

  group('не та раскладка', () {
    test('русское слово, набранное в английской раскладке', () {
      expect(swapLayouts('rjat'), contains('кофе'));
      expect(swapLayouts('ghbdtn'), contains('привет'));
    });

    test('английское слово, набранное в русской раскладке', () {
      expect(swapLayouts('ащещ'), contains('foto'));
      expect(swapLayouts('зфыеф'), contains('pasta'));
    });

    test('украинское: «і», «ї», «є» стоят на своих клавишах', () {
      expect(swapLayouts('ckjdj'), contains('слово'));
      expect(swapLayouts('ghbdsn'), contains('привіт'));
    });

    test('цифры и смешанное не перекладываются', () {
      expect(swapLayouts('2025'), isEmpty);
    });
  });

  group('варианты слова', () {
    test('само слово первым и с полным весом', () {
      final variants = variantsOf('кофе');
      expect(variants.first.text, 'кофе');
      expect(variants.first.weight, 1.0);
      expect(variants.map((variant) => variant.text), contains('kofe'));
    });

    test('варианты не повторяются и все ниже самого слова', () {
      final variants = variantsOf('rjat');
      expect(variants.map((variant) => variant.text).toSet(), hasLength(variants.length));
      expect(variants.skip(1).every((variant) => variant.weight < 1), isTrue);
      expect(variants.map((variant) => variant.text), contains('кофе'));
    });
  });
}
