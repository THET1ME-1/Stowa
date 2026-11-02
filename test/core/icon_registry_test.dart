import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/icons/icon_registry.dart';

void main() {
  test('иконка тега находится по имени', () {
    expect(symbolIcon('directions_car').fontFamily, 'StowaSymbols');
    expect(symbolIcon('directions_car', filled: true).fontFamily, 'StowaSymbolsFilled');
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
