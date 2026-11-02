import 'package:flutter/animation.dart';

/// Движение M3 Expressive. Свои числа в экранах не заводить.
abstract final class Motion {
  static const emphasized = Cubic(0.2, 0, 0, 1);
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);
  static const emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);

  /// Пространственная пружина с лёгким перелётом, как в макете строки.
  static const spatial = Cubic(0.34, 1.22, 0.5, 1);

  static const tap = Duration(milliseconds: 120);
  static const short = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 350);
  static const long = Duration(milliseconds: 450);
}
