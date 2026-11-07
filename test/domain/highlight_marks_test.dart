import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/highlight_marks.dart';

void main() {
  test('цитата внутри абзаца — один отрезок по её тексту', () {
    const text = 'Вода важнее зёрен, когда речь о вкусе.';
    final marks = marksIn(text, const [(id: 'h', quote: 'важнее зёрен')]);
    expect([for (final mark in marks) (mark.start, mark.end, mark.id)], [(5, 17, 'h')]);
  });

  test('цитата через два абзаца — в каждом своя часть', () {
    const first = 'Первый абзац кончается так.';
    const second = 'Второй начинается этим, а дальше другое.';
    const quote = (id: 'h', quote: 'кончается так.\nВторой начинается этим');
    expect([for (final mark in marksIn(first, const [quote])) (mark.start, mark.end)], [(13, 27)]);
    expect([for (final mark in marksIn(second, const [quote])) (mark.start, mark.end)], [(0, 22)]);
  });

  test('пересекающиеся цитаты не ломают текст: отрезки по порядку и без наложения', () {
    const text = 'один два три четыре';
    final marks = marksIn(text, const [(id: 'b', quote: 'три четыре'), (id: 'a', quote: 'два три')]);
    expect([for (final mark in marks) (mark.start, mark.end, mark.id)], [(5, 12, 'a'), (12, 19, 'b')]);
  });

  test('чужой текст и пустые строки цитаты не подсвечивают ничего', () {
    expect(marksIn('Совсем другое', const [(id: 'h', quote: 'вода важнее\n\n')]), isEmpty);
  });

  test('место цитаты в статье — по первой её строке, нет её — в конце', () {
    const plain = 'Начало статьи.\n\nВода важнее зёрен.';
    expect(quotePosition(plain, 'Вода важнее\nчто-то ещё'), 16);
    expect(quotePosition(plain, 'не из статьи'), plain.length);
  });
}
