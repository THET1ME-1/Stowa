import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/format/duration_format.dart';

void main() {
  test('минуты и секунды, часы только когда есть', () {
    expect(formatClock(const Duration(seconds: 47)), '0:47');
    expect(formatClock(const Duration(minutes: 3, seconds: 33)), '3:33');
    expect(formatClock(const Duration(hours: 1, minutes: 2, seconds: 5)), '1:02:05');
  });
}
