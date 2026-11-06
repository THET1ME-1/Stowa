import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/place_cue.dart';

void main() {
  PlaceReminderKind? kindOf(String text) => parsePlaceCue(text)?.kind;
  String? restOf(String text) => parsePlaceCue(text)?.restOf(text);

  test('дом на семи языках: с «напомни» или «когда приду»', () {
    for (final text in [
      'напомни дома купить хлеб',
      'купить хлеб, когда приду домой',
      'дома напомни про счётчики',
      'remind me at home to call mom',
      'call mom when I get home',
      'нагадай вдома полити квіти',
      'полити квіти, коли прийду додому',
      'amintește-mi acasă să sun la bancă',
      'sun la bancă când ajung acasă',
      'przypomnij mi w domu o rachunkach',
      'zapłacić rachunki, jak wrócę do domu',
      'erinnere mich zu Hause an die Rechnung',
      'Rechnung zahlen, wenn ich nach Hause komme',
      'recuérdame en casa regar las plantas',
      'regar las plantas cuando llegue a casa',
    ]) {
      expect(kindOf(text), PlaceReminderKind.home, reason: text);
    }
  });

  test('работа, здесь и магазин', () {
    expect(kindOf('напомни на работе отдать ключи'), PlaceReminderKind.work);
    expect(kindOf('отдать ключи, когда приду на работу'), PlaceReminderKind.work);
    expect(kindOf('remind me at work about the report'), PlaceReminderKind.work);
    expect(kindOf('erinnere mich auf der Arbeit an den Bericht'), PlaceReminderKind.work);
    expect(kindOf('напомни тут купить кофе'), PlaceReminderKind.point);
    expect(kindOf('купить кофе, когда буду здесь'), PlaceReminderKind.point);
    expect(kindOf('remind me here to buy coffee'), PlaceReminderKind.point);
    expect(kindOf('recuérdame aquí comprar café'), PlaceReminderKind.point);
    expect(kindOf('в магазине напомни купить молоко'), PlaceReminderKind.shop);
    expect(kindOf('купить молоко, когда зайду в магазин'), PlaceReminderKind.shop);
    expect(kindOf('remind me at the store to buy milk'), PlaceReminderKind.shop);
    expect(kindOf('przypomnij mi w sklepie o mleku'), PlaceReminderKind.shop);
  });

  test('место без просьбы напомнить — не напоминание', () {
    for (final text in [
      'купил молоко дома',
      'работаю на работе до шести',
      'here is the link',
      'тут лежит паспорт',
      'в магазине скидки на кофе',
      'I left my keys at home',
      'Ich bin zu Hause',
    ]) {
      expect(parsePlaceCue(text), isNull, reason: text);
    }
  });

  test('из заголовка уходят и место, и «напомни»', () {
    expect(restOf('напомни дома купить хлеб'), 'купить хлеб');
    expect(restOf('купить хлеб, когда приду домой'), 'купить хлеб');
    expect(restOf('remind me at home to call mom'), 'to call mom');
    expect(restOf('в магазине напомни купить молоко'), 'купить молоко');
    expect(restOf('Напомни здесь: купить кофе'), 'купить кофе');
  });

  test('где место в тексте: его подчёркивает строка', () {
    final cue = parsePlaceCue('купить хлеб, когда приду домой')!;
    expect('купить хлеб, когда приду домой'.substring(cue.start, cue.end), 'когда приду домой');
  });
}
