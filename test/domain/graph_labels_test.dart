import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/graph_labels.dart';

void main() {
  GraphLabel label(String id, double x, double y, {double width = 80, int degree = 1}) => (id: id, x: x, y: y, width: width, degree: degree);

  test('подписи, которые не наезжают друг на друга, показываются все', () {
    final shown = pickGraphLabels([label('a', 0, 0), label('b', 200, 0), label('c', 0, 40)]);
    expect(shown, {'a', 'b', 'c'});
  });

  test('из двух наехавших остаётся подпись узла, у которого больше связей', () {
    final shown = pickGraphLabels([label('слабый', 100, 100, degree: 1), label('узел', 120, 104, degree: 7), label('в стороне', 400, 100)]);
    expect(shown, {'узел', 'в стороне'});
  });

  test('при равных связях остаётся та, что раньше в списке', () {
    expect(pickGraphLabels([label('первая', 0, 0, degree: 2), label('вторая', 10, 2, degree: 2)]), {'первая'});
  });

  test('подписи рядом по вертикали, но на разных строках, друг другу не мешают', () {
    expect(pickGraphLabels([label('верх', 0, 0), label('низ', 0, graphLabelHeight + 2)]), {'верх', 'низ'});
  });

  test('подписей не больше предела: остаются у самых связных', () {
    final many = [for (var index = 0; index < 50; index++) label('n$index', index * 300.0, 0, degree: index)];
    final shown = pickGraphLabels(many, limit: 10);
    expect(shown, {for (var index = 40; index < 50; index++) 'n$index'});
  });

  test('две тысячи узлов в куче: подписей остаётся столько, сколько помещается', () {
    final crowd = [for (var index = 0; index < 2000; index++) label('n$index', (index % 50) * 8.0, (index ~/ 50) * 4.0, degree: index % 9)];
    final shown = pickGraphLabels(crowd);
    expect(shown.length, lessThan(60));
    expect(shown, isNotEmpty);
  });

  test('пустой список', () {
    expect(pickGraphLabels(const []), isEmpty);
  });
}
