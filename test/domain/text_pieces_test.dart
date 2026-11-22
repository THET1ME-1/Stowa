import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/text_pieces.dart';

void main() {
  List<String> cut(String text, {int target = 20}) => [for (final piece in textPieces(text, target: target)) text.substring(piece.start, piece.end)];

  test('куски покрывают текст целиком, между ними ровно один перенос', () {
    final text = List.generate(30, (index) => 'строка номер $index').join('\n');
    expect(cut(text).join('\n'), text);
    final pieces = textPieces(text, target: 20);
    for (var index = 0; index + 1 < pieces.length; index++) {
      expect(text[pieces[index].end], '\n');
      expect(pieces[index + 1].start, pieces[index].end + 1);
      expect(pieces[index].open, isNull);
    }
  });

  test('длинный листинг режется, кусок посреди него помнит открытую ограду', () {
    final code = ['```dart', for (var index = 0; index < 60; index++) 'final value$index = $index;', '```'].join('\n');
    final text = 'до блока\n$code\nпосле блока';
    final pieces = textPieces(text, target: 40);
    expect([for (final piece in pieces) text.substring(piece.start, piece.end)].join('\n'), text);
    final inside = pieces.where((piece) => piece.open == '```').toList();
    // код режется как обычный текст: кусков внутри блока много, и все короткие
    expect(inside.length, greaterThan(10));
    for (final piece in inside) {
      expect(piece.end - piece.start, lessThan(80));
    }
  });

  test('незакрытая ограда не делает из всего остального один кусок', () {
    final text = ['```', for (var index = 0; index < 200; index++) 'строка $index'].join('\n');
    expect(textPieces(text, target: 20).length, greaterThan(5));
  });

  test('начало посреди блока: ограда закрывает его, а не открывает новый', () {
    const text = 'x = 1\n```\nобычный текст после блока\nи ещё строка';
    final pieces = textPieces(text, target: 5, open: '```');
    expect(pieces.first.open, '```');
    expect(pieces.last.open, isNull);
  });

  test('кусок посреди длинной формулы помнит «\$\$»', () {
    final text = [r'$$', for (var index = 0; index < 40; index++) r'x_' '$index' r' + y \\', r'$$', 'текст'].join('\n');
    expect(textPieces(text, target: 20).any((piece) => piece.open == r'$$'), isTrue);
  });

  test('кусок набирает строки до своей длины и режется по концу строки', () {
    expect(cut('раз\nдва\nтри\nчетыре\nпять', target: 7), ['раз\nдва', 'три\nчетыре', 'пять']);
  });

  test('короткий текст — один кусок, пустой — тоже', () {
    expect(cut('коротко'), ['коротко']);
    expect(cut(''), ['']);
  });

  test('длинная строка без переносов остаётся целой', () {
    final line = 'слово ' * 40;
    expect(cut(line), [line]);
  });

  test('пустые строки и перенос в конце не теряются', () {
    const text = 'первая строка длинная\n\n\nвторая строка длинная\n';
    expect(cut(text).join('\n'), text);
  });

  test('кусок помнит ограду, открытую на его начале, и только её', () {
    final text = ['до блока', '```dart', 'final a = 1;', 'final b = 2;', '```', 'после блока'].join('\n');
    // кусок на каждую строку
    final pieces = textPieces(text, target: 1);
    expect([for (final piece in pieces) piece.open], [null, null, '```', '```', '```', null]);
  });

  test('блок ~~~~ закрывается только тем же знаком не короче', () {
    final text = ['~~~~', 'a', '```', 'b', '~~~', 'c', '~~~~', 'хвост после блока'].join('\n');
    final pieces = textPieces(text, target: 1);
    expect([for (final piece in pieces) piece.open], [null, '~~~~', '~~~~', '~~~~', '~~~~', '~~~~', '~~~~', null]);
  });

  test('формула \$\$ на своих строках не режется посередине', () {
    final text = ['текст перед формулой', r'$$', r'a + b = c \\', r'x^2 + y^2', r'$$', 'текст после формулы'].join('\n');
    final pieces = cut(text, target: 10);
    expect(pieces.join('\n'), text);
    expect(pieces.where((piece) => piece.contains('a + b')).single, contains(r'x^2 + y^2' '\n' r'$$'));
  });

  test('формула в одну строку блок не открывает', () {
    final text = [r'$$x$$', 'обычная строка', 'ещё одна строка'].join('\n');
    expect(cut(text, target: 5), [r'$$x$$', 'обычная строка', 'ещё одна строка']);
  });
}
