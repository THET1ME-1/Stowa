import 'dart:math' as math;
import 'dart:ui';

import 'sticker_geometry.dart';

/// Плашка записи голосового сворачивается в круг стикера: он встаёт у её края, ближнего к
/// краю экрана, по середине высоты. [area] — свободная часть экрана в точках окна.
Rect voiceCircleOf(Rect pill, Rect area) {
  final right = pill.center.dx > area.center.dx;
  final left = right ? pill.right - circleSize : pill.left;
  return _inside(Rect.fromLTWH(left, pill.center.dy - circleSize / 2, circleSize, circleSize), area);
}

/// Куда раскрывается круг: плашка размера [size] растёт к середине экрана, по середине круга.
/// Свернул и раскрыл на месте — плашка там же.
Rect voicePillOf(Rect circle, Size size, Rect area) {
  final right = circle.center.dx > area.center.dx;
  final left = right ? circle.right - size.width : circle.left;
  return voicePillAt(Offset(left, circle.center.dy - size.height / 2), size, area);
}

/// Плашка размера [size] левым верхним углом в [at], зажатая в свободную часть экрана.
Rect voicePillAt(Offset at, Size size, Rect area) => _inside(at & size, area);

Rect _inside(Rect box, Rect area) {
  double clamp(double value, double low, double high) => math.max(low, math.min(value, high));
  final left = clamp(box.left, area.left + stickerMargin, area.right - stickerMargin - box.width);
  final top = clamp(box.top, area.top + stickerMargin, area.bottom - stickerMargin - box.height);
  return Rect.fromLTWH(left, top, box.width, box.height);
}
