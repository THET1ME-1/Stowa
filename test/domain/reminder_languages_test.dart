import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/reminder_parser.dart';

// понедельник, 2 ноября 2026, 10:00
final now = DateTime(2026, 11, 2, 10);

DateTime? at(String text) => parseReminder(text, now)?.at;

void expectAll(Map<String, DateTime> cases) {
  for (final MapEntry(key: text, value: expected) in cases.entries) {
    expect(at(text), expected, reason: text);
  }
}

void expectNone(List<String> texts) {
  for (final text in texts) {
    expect(parseReminder(text, now), isNull, reason: text);
  }
}

void main() {
  test('английский', () {
    expectAll({
      'tomorrow at 9 call the bank': DateTime(2026, 11, 3, 9),
      'call mom at 6 pm': DateTime(2026, 11, 2, 18),
      'call mom at 6pm': DateTime(2026, 11, 2, 18),
      'dentist on Friday at 14:30': DateTime(2026, 11, 6, 14, 30),
      'meeting December 23 at 1 pm': DateTime(2026, 12, 23, 13),
      '23 December 13:00 dentist': DateTime(2026, 12, 23, 13),
      'in 2 hours turn off the oven': DateTime(2026, 11, 2, 12),
      'in half an hour': DateTime(2026, 11, 2, 10, 30),
      'tonight cinema': DateTime(2026, 11, 2, 19),
      'tomorrow morning run': DateTime(2026, 11, 3, 9),
      'at 7 in the evening': DateTime(2026, 11, 2, 19),
      'on the weekend paint the fence': DateTime(2026, 11, 7, 10),
      'after work call mom': DateTime(2026, 11, 2, 18),
      'the day after tomorrow haircut': DateTime(2026, 11, 4, 9),
    });
    expectNone(['2 times more', 'I was 13 years old', 'version 1.5 is out', 'good evening everyone']);
  });

  test('немецкий', () {
    expectAll({
      'morgen um 9 Uhr Bank anrufen': DateTime(2026, 11, 3, 9),
      'um 18 Uhr Training': DateTime(2026, 11, 2, 18),
      'heute Abend Kino': DateTime(2026, 11, 2, 19),
      'um 7 Uhr abends': DateTime(2026, 11, 2, 19),
      'am Freitag um 14:30 Zahnarzt': DateTime(2026, 11, 6, 14, 30),
      'am 23. Dezember um 13 Uhr': DateTime(2026, 12, 23, 13),
      'in 2 Stunden Ofen ausschalten': DateTime(2026, 11, 2, 12),
      'in einer halben Stunde': DateTime(2026, 11, 2, 10, 30),
      'übermorgen Friseur': DateTime(2026, 11, 4, 9),
      'ubermorgen Friseur': DateTime(2026, 11, 4, 9),
      'nach der Arbeit Mama anrufen': DateTime(2026, 11, 2, 18),
      'am Wochenende Zaun streichen': DateTime(2026, 11, 7, 10),
    });
    expectNone(['Guten Abend', '2 mal mehr', 'ich bin 13 Jahre alt']);
  });

  test('испанский', () {
    expectAll({
      'mañana a las 9 llamar al banco': DateTime(2026, 11, 3, 9),
      'manana a las 9 llamar al banco': DateTime(2026, 11, 3, 9),
      'a las 6 de la tarde gimnasio': DateTime(2026, 11, 2, 18),
      'el viernes a las 14:30 dentista': DateTime(2026, 11, 6, 14, 30),
      '23 de diciembre a las 13:00': DateTime(2026, 12, 23, 13),
      'en 2 horas apagar el horno': DateTime(2026, 11, 2, 12),
      'dentro de media hora': DateTime(2026, 11, 2, 10, 30),
      'por la noche cine': DateTime(2026, 11, 2, 21),
      'pasado mañana peluquería': DateTime(2026, 11, 4, 9),
      'mañana por la mañana correr': DateTime(2026, 11, 3, 9),
      'después del trabajo llamar a mamá': DateTime(2026, 11, 2, 18),
    });
    expectNone(['buenas noches', '5 o 6 manzanas', 'tengo 13 años']);
  });

  test('польский', () {
    expectAll({
      'jutro o 9 zadzwonić do banku': DateTime(2026, 11, 3, 9),
      'o 18 trening': DateTime(2026, 11, 2, 18),
      'o 7 wieczorem': DateTime(2026, 11, 2, 19),
      'w piątek o 14:30 dentysta': DateTime(2026, 11, 6, 14, 30),
      '23 grudnia o 13:00': DateTime(2026, 12, 23, 13),
      'za 2 godziny wyłączyć piekarnik': DateTime(2026, 11, 2, 12),
      'za pół godziny': DateTime(2026, 11, 2, 10, 30),
      'pojutrze fryzjer': DateTime(2026, 11, 4, 9),
      'jutro rano bieganie': DateTime(2026, 11, 3, 9),
      'po pracy zadzwonić do mamy': DateTime(2026, 11, 2, 18),
    });
    expectNone(['2 razy więcej', 'mam 13 lat', 'dzień dobry']);
  });

  test('румынский', () {
    expectAll({
      'mâine la 9 sun la bancă': DateTime(2026, 11, 3, 9),
      'maine la ora 9': DateTime(2026, 11, 3, 9),
      'la 6 seara sala': DateTime(2026, 11, 2, 18),
      'vineri la 14:30 dentist': DateTime(2026, 11, 6, 14, 30),
      '23 decembrie la 13:00': DateTime(2026, 12, 23, 13),
      'peste 2 ore oprește cuptorul': DateTime(2026, 11, 2, 12),
      'peste o jumătate de oră': DateTime(2026, 11, 2, 10, 30),
      'poimâine frizer': DateTime(2026, 11, 4, 9),
      'diseară film': DateTime(2026, 11, 2, 19),
      'după muncă sun-o pe mama': DateTime(2026, 11, 2, 18),
    });
    expectNone(['bună seara', 'am 13 ani', 'de 2 ori mai mult']);
  });

  test('украинский', () {
    expectAll({
      'завтра о 9 подзвонити в банк': DateTime(2026, 11, 3, 9),
      'о 6 вечора тренування': DateTime(2026, 11, 2, 18),
      'у пʼятницю о 14:30 стоматолог': DateTime(2026, 11, 6, 14, 30),
      "у п'ятницю о 14:30 стоматолог": DateTime(2026, 11, 6, 14, 30),
      '23 грудня о 13:00': DateTime(2026, 12, 23, 13),
      'через 2 години вимкнути духовку': DateTime(2026, 11, 2, 12),
      'через пів години': DateTime(2026, 11, 2, 10, 30),
      'післязавтра перукар': DateTime(2026, 11, 4, 9),
      'завтра вранці пробіжка': DateTime(2026, 11, 3, 9),
      'ввечері кіно': DateTime(2026, 11, 2, 19),
      'після роботи подзвонити мамі': DateTime(2026, 11, 2, 18),
    });
    expectNone(['мені 13 років', 'у 2 рази більше']);
  });

  test('из заголовка уходят время и «напомни» на любом из языков', () {
    String rest(String text) => parseReminder(text, now)!.restOf(text);
    expect(rest('remind me tomorrow at 9 to call the bank'), 'to call the bank');
    expect(rest('erinnere mich morgen um 9 Uhr an die Bank'), 'an die Bank');
    expect(rest('recuérdame mañana a las 9 llamar al banco'), 'llamar al banco');
    expect(rest('przypomnij mi jutro o 9 zadzwonić do banku'), 'zadzwonić do banku');
    expect(rest('amintește-mi mâine la 9 să sun la bancă'), 'să sun la bancă');
    expect(rest('нагадай завтра о 9 подзвонити в банк'), 'подзвонити в банк');
  });
}
