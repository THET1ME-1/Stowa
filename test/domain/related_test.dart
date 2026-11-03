import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/related.dart';

void main() {
  final docs = [
    const RelatedDoc(id: 'borsch', text: 'Борщ со свёклой, рецепт бабушки'),
    const RelatedDoc(id: 'beet', text: 'Свёкла на рынке подешевела, купить на борщ'),
    const RelatedDoc(id: 'bread', text: 'Купить хлеб'),
    const RelatedDoc(id: 'bank', text: 'Позвонить в банк про карту'),
    const RelatedDoc(id: 'gc1', text: 'Сборщик мусора', site: 'habr.com'),
    const RelatedDoc(id: 'gc2', text: 'Как устроен Flutter', site: 'habr.com'),
    const RelatedDoc(id: 'mail', text: 'Письмо от банка'),
    const RelatedDoc(id: 'gift', text: 'Идея для подарка'),
  ];

  test('связаны вещи с общими редкими словами, причина — эти слова', () {
    final related = findRelated('borsch', docs);
    expect(related.map((one) => one.id), ['beet']);
    expect(related.single.words, containsAll(['Борщ', 'свёклой']));
  });

  test('общий сайт тоже связь', () {
    final related = findRelated('gc1', docs);
    expect(related.map((one) => one.id), ['gc2']);
    expect(related.single.sameSite, isTrue);
  });

  test('одно частое слово («купить») связью не считается', () {
    expect(findRelated('bread', docs), isEmpty);
  });

  test('отклонённую связь не предлагаем', () {
    expect(findRelated('borsch', docs, rejected: {'beet'}), isEmpty);
  });
}
