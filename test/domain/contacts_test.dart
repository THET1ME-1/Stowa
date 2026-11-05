import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/contacts.dart';

void main() {
  test('телефоны в разных записях', () {
    expect(findPhones('Мастер: +373 69 123 456').single.dial, '+37369123456');
    expect(findPhones('звонить 069-123-456 после 18').single.dial, '069123456');
    expect(findPhones('Tel. (030) 1234 5678').single.dial, '03012345678');
    expect(findPhones('+48 512 345 678 i +49 151 23456789').map((phone) => phone.dial), ['+48512345678', '+4915123456789']);
  });

  test('даты, суммы, время и номера заказов — не телефоны', () {
    expect(findPhones('встреча 12.11.2026 в 10:30'), isEmpty);
    expect(findPhones('итого 1 250 лей'), isEmpty);
    expect(findPhones('заказ 2026'), isEmpty);
  });

  test('почта', () {
    expect(findEmails('пиши на ivan.petrov+stowa@mail.md, отвечу').single.address, 'ivan.petrov+stowa@mail.md');
    expect(findEmails('без почты @ тут'), isEmpty);
  });

  test('ссылки в тексте, с адресом и без схемы', () {
    final links = findLinks('смотри https://habr.com/ru/articles/1/ и www.youtube.com/watch?v=x.');
    expect(links.map((link) => link.url), ['https://habr.com/ru/articles/1/', 'https://www.youtube.com/watch?v=x']);
  });
}
