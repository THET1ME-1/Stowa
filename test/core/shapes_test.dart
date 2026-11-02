import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/shapes.dart';

void main() {
  const size = Size(100, 100);

  test('каждая форма вписана в свой квадрат', () {
    for (final shape in BadgeShape.values) {
      final bounds = badgeShapePath(shape, size).getBounds();
      expect(bounds.left, greaterThanOrEqualTo(-0.01), reason: shape.name);
      expect(bounds.top, greaterThanOrEqualTo(-0.01), reason: shape.name);
      expect(bounds.right, lessThanOrEqualTo(100.01), reason: shape.name);
      expect(bounds.bottom, lessThanOrEqualTo(100.01), reason: shape.name);
      expect(bounds.width, greaterThan(90), reason: shape.name);
    }
  });

  test('у печеньки на девять зубцов впадины между зубцами', () {
    final path = badgeShapePath(BadgeShape.cookie9, size);
    // как в макете: впадина смотрит вправо, зубец повёрнут на половину шага
    expect(path.contains(const Offset(50 + 49, 50)), isFalse);
    const lobe = math.pi / 9;
    final inside = Offset(50 + 49 * math.cos(lobe), 50 + 49 * math.sin(lobe));
    expect(path.contains(inside), isTrue);
  });

  test('сквиркл полнее круга по углам', () {
    final path = badgeShapePath(BadgeShape.squircle, size);
    const corner = Offset(50 + 38, 50 + 38); // за кругом радиуса 50
    expect(path.contains(corner), isTrue);
  });
}
