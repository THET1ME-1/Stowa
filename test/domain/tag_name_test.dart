import 'package:flutter_test/flutter_test.dart';
import 'package:kladovka/domain/inline_tags.dart';
import 'package:kladovka/domain/tag_name.dart';

void main() {
  test('один тег разными буквами — одно имя', () {
    expect(normalizeTagName('#Машина '), 'машина');
    expect(normalizeTagName('МАШИНА'), 'машина');
    expect(normalizeTagName('  ремонт кухни '), 'ремонт_кухни');
    expect(normalizeTagName('##идея'), 'идея');
    expect(normalizeTagName('Ёлка'), 'ёлка');
  });

  test('теги из текста без повторов и в порядке появления', () {
    expect(extractInlineTags('купить #Шины и #шины, #машина!'), ['шины', 'машина']);
    expect(extractInlineTags('#togetherly виджет погоды #идея'), ['togetherly', 'идея']);
  });

  test('хекс-цвет, середина слова и заголовок Markdown — не теги', () {
    expect(extractInlineTags('цвет #FF0000 и почта a#b'), isEmpty);
    expect(extractInlineTags('# Заголовок'), isEmpty);
    expect(extractInlineTags('номер #42'), isEmpty);
  });
}
