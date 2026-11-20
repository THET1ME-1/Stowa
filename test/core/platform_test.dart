import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/platform.dart';

int _sum(int upTo) {
  var total = 0;
  for (var number = 1; number <= upTo; number++) {
    total += number;
  }
  return total;
}

void main() {
  group('счёт в стороне от главного потока', () {
    test('отдаёт ответ работы', () async {
      expect(await aside(() => _sum(1000)), 500500);
    });

    test('ошибка работы доходит до того, кто ждал', () async {
      await expectLater(aside<int>(() => throw const FormatException('битый файл')), throwsFormatException);
    });

    test('работа может быть и асинхронной', () async {
      expect(await aside(() async => _sum(10)), 55);
    });
  });
}
