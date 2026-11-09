import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/text_places.dart';

void main() {
  List<String> values(String text, TextPlaceKind kind) => [for (final place in findTextPlaces(text)) if (place.kind == kind) place.value];

  group('адрес', () {
    test('улица и дом на семи языках', () {
      expect(values('Встреча: ул. Пушкина 12, кв 5', TextPlaceKind.address), ['ул. Пушкина 12']);
      expect(values('улица Николая Зелинского, 7а — второй подъезд', TextPlaceKind.address), ['улица Николая Зелинского, 7а']);
      expect(values('вул. Хрещатик 22', TextPlaceKind.address), ['вул. Хрещатик 22']);
      expect(values('Oficiul: bd. Ștefan cel Mare 134', TextPlaceKind.address), ['bd. Ștefan cel Mare 134']);
      expect(values('str. Mihai Eminescu 50/1', TextPlaceKind.address), ['str. Mihai Eminescu 50/1']);
      expect(values('ul. Marszałkowska 10', TextPlaceKind.address), ['ul. Marszałkowska 10']);
      expect(values('Wir wohnen Hauptstraße 5b', TextPlaceKind.address), ['Hauptstraße 5b']);
      expect(values('quedamos en calle Mayor 3', TextPlaceKind.address), ['calle Mayor 3']);
      expect(values('Office at 221 Baker Street, London', TextPlaceKind.address), ['221 Baker Street']);
    });

    test('без номера дома — не адрес', () {
      expect(values('гуляли по улице весь вечер', TextPlaceKind.address), isEmpty);
      expect(values('ул. Пушкина', TextPlaceKind.address), isEmpty);
    });
  });

  test('трек-номер: UPU, Cainiao, YunExpress', () {
    expect(values('Трек RR123456785CN пришёл', TextPlaceKind.tracking), ['RR123456785CN']);
    expect(values('посылка LP00123456789012 с AliExpress', TextPlaceKind.tracking), ['LP00123456789012']);
    expect(values('YT1234567890123456', TextPlaceKind.tracking), ['YT1234567890123456']);
    expect(values('модель RTX4090TI', TextPlaceKind.tracking), isEmpty);
  });

  test('промокод после слова на семи языках', () {
    expect(values('Промокод: SALE20 на всё', TextPlaceKind.promoCode), ['SALE20']);
    expect(values('promo code WINTER-25', TextPlaceKind.promoCode), ['WINTER-25']);
    expect(values('cod promoțional REDUCERE10', TextPlaceKind.promoCode), ['REDUCERE10']);
    expect(values('Gutscheincode HERBST15', TextPlaceKind.promoCode), ['HERBST15']);
    expect(values('промокод на скидку потерял', TextPlaceKind.promoCode), isEmpty);
  });

  group('пароль', () {
    test('после слова, с именем сети рядом', () {
      final found = findTextPlaces('Пароль от Wi-Fi\nСеть Keenetic, пароль zelenyi-chai-77').where((place) => place.kind == TextPlaceKind.password).toList();
      expect([for (final one in found) (one.value, one.label)], [('zelenyi-chai-77', 'Keenetic')]);
      expect(values('wifi на даче: сеть Dacha_5G пароль: sunflower2026', TextPlaceKind.password), ['sunflower2026']);
      expect(values('password: hunter22', TextPlaceKind.password), ['hunter22']);
      expect(values('hasło: Kot123!', TextPlaceKind.password), ['Kot123!']);
      expect(values('пароль от почты Qwerty123', TextPlaceKind.password), ['Qwerty123']);
    });

    test('без двоеточия простое слово паролем не считается', () {
      expect(values('пароль простой, не забуду', TextPlaceKind.password), isEmpty);
      expect(values('Пароль от Wi-Fi', TextPlaceKind.password), isEmpty);
    });
  });

  test('карта лояльности: номер после слова карты, без пробелов', () {
    expect(values('Карта Ашана 1234 5678 9012 3456', TextPlaceKind.loyaltyCard), ['1234567890123456']);
    expect(values('бонусная карта: 2900123456789', TextPlaceKind.loyaltyCard), ['2900123456789']);
    expect(values('Kaufland card 123456789012', TextPlaceKind.loyaltyCard), ['123456789012']);
    expect(values('карта местности 1:50000', TextPlaceKind.loyaltyCard), isEmpty);
  });

  test('места не перекрываются: номер карты — не трек и не что-то ещё', () {
    final found = findTextPlaces('Карта Linella 2900123456789, трек RR123456785CN, промокод SALE20');
    expect([for (final one in found) one.kind], [TextPlaceKind.loyaltyCard, TextPlaceKind.tracking, TextPlaceKind.promoCode]);
  });
}
