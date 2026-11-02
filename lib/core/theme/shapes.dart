import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Формы значков M3 Expressive. Те же, что в макете (функция shape_path).
enum BadgeShape { cookie9, cookie6, squircle, gem, pill }

const _steps = 180;

/// Контур формы под размер. Считается по радиусу от центра, как в макете,
/// поэтому любая форма вписана в свой квадрат.
Path badgeShapePath(BadgeShape shape, Size size) {
  final half = math.min(size.width, size.height) / 2;
  final center = size.center(Offset.zero);
  final path = Path();
  for (var step = 0; step < _steps; step++) {
    final angle = step / _steps * math.pi * 2;
    final radius = half * _radiusFactor(shape, angle);
    final point = center + Offset(radius * math.cos(angle), radius * math.sin(angle));
    if (step == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

double _radiusFactor(BadgeShape shape, double angle) {
  double cookie(int lobes, double depth, [double phase = 0]) =>
      1 - depth * (1 + math.cos(lobes * angle - phase)) / 2;
  double superellipse(double power) {
    final cos = math.cos(angle).abs();
    final sin = math.sin(angle).abs();
    return 1 / math.pow(math.pow(cos, power) + math.pow(sin, power), 1 / power);
  }

  return switch (shape) {
    BadgeShape.cookie9 => cookie(9, 0.09),
    BadgeShape.cookie6 => cookie(6, 0.12),
    BadgeShape.gem => cookie(5, 0.07, math.pi / 2),
    BadgeShape.squircle => superellipse(4),
    BadgeShape.pill => 0.98 * superellipse(2.4),
  };
}

/// Обрезка ребёнка по форме значка.
class BadgeShapeClipper extends CustomClipper<Path> {
  const BadgeShapeClipper(this.shape);

  final BadgeShape shape;

  @override
  Path getClip(Size size) => badgeShapePath(shape, size);

  @override
  bool shouldReclip(BadgeShapeClipper oldClipper) => oldClipper.shape != shape;
}
