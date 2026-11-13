import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/language_guess.dart';

void main() {
  test('язык текста по служебным словам, буквам и письменности', () {
    const cases = {
      'demain je dois appeler la banque et le dentiste': 'fr',
      'domani devo chiamare la banca e anche il dentista': 'it',
      'amanhã ligar para o banco e não esquecer': 'pt',
      'yarın bankayı ve dişçiyi ara lütfen': 'tr',
      'morgen moet ik de bank en de tandarts bellen': 'nl',
      'imorgon ringa banken och tandläkaren': 'sv',
      'zítra zavolat do banky, protože je to důležité': 'cs',
      'holnap felhívni a bankot és a fogorvost': 'hu',
      'завтра мне надо позвонить в банк и стоматологу': 'ru',
      'завтра мені треба подзвонити в банк і стоматологу': 'uk',
      'tomorrow call the bank and the dentist': 'en',
      'morgen die Bank anrufen und den Zahnarzt': 'de',
      'mañana tengo que llamar al banco y al dentista': 'es',
      'jutro muszę zadzwonić do banku i do dentysty': 'pl',
      'mâine să sun la bancă și la dentist': 'ro',
      '明日銀行に電話する': 'ja',
      '明天给银行打电话': 'zh',
      '내일 은행에 전화하기': 'ko',
      'αύριο να πάρω τηλέφωνο την τράπεζα': 'el',
      'غدا اتصل بالبنك': 'ar',
      'מחר להתקשר לבנק': 'he',
      'कल बैंक को फोन करना है': 'hi',
      'พรุ่งนี้โทรหาธนาคาร': 'th',
    };
    for (final MapEntry(key: text, value: language) in cases.entries) {
      expect(guessLanguage(text), language, reason: text);
    }
    // индонезийский и малайский по служебным словам одно и то же
    expect(guessLanguage('besok saya harus telepon bank dan dokter gigi'), 'id');
  });

  test('без служебных слов и особых букв язык не угадывается', () {
    for (final text in ['Linella', '14:30', 'Andy’s Pizza', 'iPhone 15']) {
      expect(guessLanguage(text), isNull, reason: text);
    }
  });

  test('подсказка только для языков, на которых время не понять', () {
    for (final text in [
      'Cras ad mercatum ibo et panem emam quia nihil est domi',
      'སང་ཉིན་ཚོང་ཁང་ལ་འགྲོ་',
    ]) {
      expect(unsupportedLanguage(text), isTrue, reason: text);
    }
  });

  test('семь языков приложения и языки из CLDR — свои, короткое и цифры — не повод', () {
    for (final text in [
      'завтра в 9 позвонить в банк',
      'call the bank tomorrow at nine',
      'mâine să sun la bancă și la dentist',
      'demain à neuf heures appeler la banque',
      'domani alle nove chiamare la banca e il dentista',
      'yarın saat dokuzda bankayı ara lütfen',
      '明天九点给银行打电话',
      'غدا في التاسعة اتصل بالبنك',
      'Linella',
      '14:30',
      'Andy’s Pizza',
    ]) {
      expect(unsupportedLanguage(text), isFalse, reason: text);
    }
  });
}
