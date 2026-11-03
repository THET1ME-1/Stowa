import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/icons/icon_words.dart';

void main() {
  test('иконку находит русское слово в любой форме', () {
    expect(searchIcons('машина'), contains('directions_car'));
    expect(searchIcons('Машины'), contains('directions_car'));
    expect(searchIcons('кофе'), contains('local_cafe'));
    expect(searchIcons('кино'), contains('movie'));
    expect(searchIcons('деньги'), contains('savings'));
    expect(searchIcons('подарки'), contains('redeem'));
  });

  test('английское имя ищется как раньше, пустой запрос — ничего', () {
    expect(searchIcons('car'), contains('directions_car'));
    expect(searchIcons('  '), isEmpty);
  });

  test('найденное по-русски идёт раньше случайных совпадений', () {
    expect(searchIcons('дом').first, 'home');
  });
}
