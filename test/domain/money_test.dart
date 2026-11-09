import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/money.dart';

void main() {
  (double, String) one(String text) {
    final found = findMoney(text);
    expect(found, hasLength(1), reason: text);
    return (found.single.amount, found.single.currency);
  }

  test('валюта после суммы на семи языках', () {
    expect(one('кофе 35 лей'), (35, 'MDL'));
    expect(one('обед 120 lei'), (120, 'MDL'));
    expect(one('ремонт 2 000 ₽'), (2000, 'RUB'));
    expect(one('налог 300 рублей'), (300, 'RUB'));
    expect(one('квиток 450 грн'), (450, 'UAH'));
    expect(one('Miete 850 €'), (850, 'EUR'));
    expect(one('obiad 150 zł'), (150, 'PLN'));
    expect(one('cena 99,99 zł'), (99.99, 'PLN'));
    expect(one('стоит 20 долларов'), (20, 'USD'));
    expect(one('20 евро за вход'), (20, 'EUR'));
  });

  test('знак перед суммой', () {
    expect(one('Netflix \$19.99'), (19.99, 'USD'));
    expect(one('билет €20'), (20, 'EUR'));
    expect(one('£ 5'), (5, 'GBP'));
    expect(one('USD 1,250.50'), (1250.5, 'USD'));
  });

  test('разделители тысяч и дробей', () {
    expect(one('1.500,50 €'), (1500.5, 'EUR'));
    expect(one('1,500.50 \$'), (1500.5, 'USD'));
    expect(one('12 500 лей'), (12500, 'MDL'));
    expect(one('3,5 евро'), (3.5, 'EUR'));
  });

  test('без валюты — не деньги', () {
    expect(findMoney('купить 3 яйца и 500 г муки'), isEmpty);
    expect(findMoney('встреча в 10:30, кабинет 205'), isEmpty);
  });

  test('несколько сумм и где они в тексте', () {
    final found = findMoney('хлеб 12 лей, сыр 80 лей');
    expect(found.map((money) => money.amount), [12, 80]);
    expect('хлеб 12 лей, сыр 80 лей'.substring(found.first.start, found.first.end), '12 лей');
  });

  test('слово, похожее на валюту, — не валюта', () {
    expect(findMoney('5 рублик'), hasLength(1));
    expect(findMoney('глава 5 руководства'), isEmpty);
    expect(findMoney('прочитал 2 леммы'), isEmpty);
  });

  test('итог по валютам: большая сумма первой, вывод как пишут люди', () {
    final total = sumByCurrency([(4200, 'MDL'), (40, 'EUR'), (18950, 'MDL')]);
    expect(total, [(23150.0, 'MDL'), (40.0, 'EUR')]);
    // разряды — неразрывным пробелом: сумма не рвётся на две строки
    String plain(String text) => text.replaceAll(' ', ' ');
    expect(plain(formatTotal(total, 'ru')), '23 150 лей · €40');
    expect(plain(formatTotal([(19.5, 'USD'), (300, 'UAH')], 'en')), r'$19.50 · 300 ₴');
    expect(formatTotal(const [], 'ru'), '');
  });
}
