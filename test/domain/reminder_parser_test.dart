import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/reminder_parser.dart';

// понедельник, 2 ноября 2026, 10:00
final now = DateTime(2026, 11, 2, 10);

DateTime? at(String text) => parseReminder(text, now)?.at;

void main() {
  test('число, месяц и время', () {
    expect(at('23 декабря 13:00 зубной'), DateTime(2026, 12, 23, 13));
    expect(at('зубной 23 дек в 13:30'), DateTime(2026, 12, 23, 13, 30));
  });

  test('прошедшая дата этого года уходит на следующий', () {
    final match = parseReminder('5 января день рождения', now)!;
    expect(match.at, DateTime(2027, 1, 5, 9));
    expect(match.hasTime, isFalse);
  });

  test('сегодня, завтра, послезавтра', () {
    expect(at('завтра в 10 позвонить в сервис'), DateTime(2026, 11, 3, 10));
    expect(at('послезавтра стрижка'), DateTime(2026, 11, 4, 9));
    expect(at('сегодня вечером кино'), DateTime(2026, 11, 2, 19));
    expect(at('завтра утром пробежка'), DateTime(2026, 11, 3, 9));
  });

  test('день недели', () {
    expect(at('в пятницу купить торт'), DateTime(2026, 11, 6, 9));
    expect(at('во вторник в 18:00 бассейн'), DateTime(2026, 11, 3, 18));
    // понедельник сегодня: время впереди — сегодня, иначе через неделю
    expect(at('в понедельник в 15:00'), DateTime(2026, 11, 2, 15));
    expect(at('в пн в 8:00'), DateTime(2026, 11, 9, 8));
  });

  test('только время: сегодня, а если прошло — завтра', () {
    expect(at('в 15:30 встреча'), DateTime(2026, 11, 2, 15, 30));
    expect(at('в 8:00 будильник'), DateTime(2026, 11, 3, 8));
    expect(at('в 7 вечера ужин'), DateTime(2026, 11, 2, 19));
    expect(at('к 12 забрать посылку'), DateTime(2026, 11, 2, 12));
    expect(at('в полдень обед'), DateTime(2026, 11, 2, 12));
  });

  test('через сколько-то', () {
    expect(at('через 2 часа выключить духовку'), DateTime(2026, 11, 2, 12));
    expect(at('через полчаса'), DateTime(2026, 11, 2, 10, 30));
    expect(at('через 15 минут'), DateTime(2026, 11, 2, 10, 15));
    expect(at('через неделю отчёт'), DateTime(2026, 11, 9, 9));
    expect(at('через 3 дня'), DateTime(2026, 11, 5, 9));
  });

  test('число через точку', () {
    expect(at('12.11 в 9 стрижка'), DateTime(2026, 11, 12, 9));
    expect(at('05.01.2027 техосмотр'), DateTime(2027, 1, 5, 9));
  });

  test('не дата — не напоминание', () {
    expect(parseReminder('в 2 раза больше', now), isNull);
    expect(parseReminder('мне в 13 лет подарили', now), isNull);
    expect(parseReminder('версия 1.5 вышла', now), isNull);
    expect(parseReminder('код домофона 4512', now), isNull);
    expect(parseReminder('30 ноль', now), isNull);
  });

  test('найденный кусок и текст без него', () {
    final match = parseReminder('23 декабря 13:00 зубной', now)!;
    expect('23 декабря 13:00 зубной'.substring(match.start, match.end), '23 декабря 13:00');
    expect(match.restOf('23 декабря 13:00 зубной'), 'зубной');
    final asked = parseReminder('напомни завтра купить хлеб', now)!;
    expect(asked.restOf('напомни завтра купить хлеб'), 'купить хлеб');
    expect(parseReminder('позвонить маме завтра в 10', now)!.restOf('позвонить маме завтра в 10'), 'позвонить маме');
  });

  test('регистр и ё не мешают', () {
    expect(at('Завтра В 10'), DateTime(2026, 11, 3, 10));
    expect(at('в субботу'), DateTime(2026, 11, 7, 9));
    expect(at('в четверг'), DateTime(2026, 11, 5, 9));
  });
}
