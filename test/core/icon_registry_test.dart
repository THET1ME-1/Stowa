import 'package:flutter_test/flutter_test.dart';
import 'package:kladovka/core/icons/icon_registry.dart';

void main() {
  test('иконка тега находится по имени', () {
    expect(symbolIcon('directions_car').fontFamily, 'KladovkaSymbols');
    expect(symbolIcon('directions_car', filled: true).fontFamily, 'KladovkaSymbolsFilled');
    expect(symbolIcon('directions_car').codePoint, isNot(symbolIcon('label').codePoint));
  });

  test('неизвестное имя даёт запасную иконку, а не падение', () {
    expect(symbolIcon('нет_такой'), symbolIcon(symbolFallback));
    expect(symbolIcon(null), symbolIcon(symbolFallback));
  });

  test('ходовые иконки есть в наборе, набор полный', () {
    for (final name in pickableSymbols) {
      expect(hasSymbol(name), isTrue, reason: name);
    }
    expect(symbolNames.length, greaterThan(4000));
  });
}
