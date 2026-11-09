import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/shopping.dart';

void main() {
  test('первая строка начинается словом «купить» на семи языках', () {
    expect(isShoppingStart('купить молоко'), isTrue);
    expect(isShoppingStart('Купить: хлеб'), isTrue);
    expect(isShoppingStart('buy eggs, milk'), isTrue);
    expect(isShoppingStart('kaufen Brot'), isTrue);
    expect(isShoppingStart('Купил молоко'), isFalse);
    expect(isShoppingStart('купите слона'), isFalse);
    expect(isShoppingStart('не забыть купить'), isFalse);
  });

  test('пункты из строки через запятые и «и», и из строк ниже', () {
    expect(shoppingItems('купить молоко, хлеб и яйца'), ['молоко', 'хлеб', 'яйца']);
    expect(shoppingItems('Купить:\nмолоко\n- хлеб\n• сыр 200 г'), ['молоко', 'хлеб', 'сыр 200 г']);
    expect(shoppingItems('buy eggs and milk'), ['eggs', 'milk']);
    expect(shoppingItems('купить молоко'), ['молоко']);
  });

  test('список галочками: заголовок словом человека, пункты строками', () {
    expect(shoppingChecklist('купить молоко, хлеб и яйца'), 'Купить:\n- [ ] молоко\n- [ ] хлеб\n- [ ] яйца');
    expect(shoppingChecklist('Buy eggs and milk'), 'Buy:\n- [ ] eggs\n- [ ] milk');
  });

  test('уже галочки, один пункт или не покупки — переделывать нечего', () {
    expect(shoppingChecklist('Купить:\n- [ ] молоко\n- [ ] хлеб'), isNull);
    expect(shoppingChecklist('купить молоко'), isNull);
    expect(shoppingChecklist('позвонить маме, папе и бабушке'), isNull);
  });
}
