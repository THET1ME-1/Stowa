import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/sticker_geometry.dart';
import 'package:stowa/domain/voice_geometry.dart';

void main() {
  // свободная часть экрана 392 × 873: под строкой состояния 24
  const area = Rect.fromLTWH(0, 24, 392, 849);

  test('плашка справа сворачивается в круг у своего правого края, по середине высоты', () {
    const pill = Rect.fromLTWH(80, 300, 300, 64);
    final circle = voiceCircleOf(pill, area);
    expect(circle.size, const Size.square(circleSize));
    expect(circle.right, pill.right);
    expect(circle.center.dy, pill.center.dy);
  });

  test('плашка слева сворачивается в круг у своего левого края', () {
    const pill = Rect.fromLTWH(12, 300, 300, 64);
    expect(voiceCircleOf(pill, area).left, pill.left);
  });

  test('свернул и раскрыл на месте — плашка там же', () {
    for (final pill in const [Rect.fromLTWH(80, 300, 300, 64), Rect.fromLTWH(12, 500, 300, 64)]) {
      final circle = voiceCircleOf(pill, area);
      expect(voicePillOf(circle, pill.size, area), pill);
    }
  });

  test('круг утащили к правому краю — плашка растёт влево и остаётся на экране', () {
    final circle = Rect.fromLTWH(area.right - stickerMargin - circleSize, 400, circleSize, circleSize);
    final pill = voicePillOf(circle, const Size(300, 64), area);
    expect(pill.right, circle.right);
    expect(pill.left, greaterThanOrEqualTo(area.left + stickerMargin));
  });

  test('круг у самого низа — плашка не уходит под край', () {
    final circle = Rect.fromLTWH(20, area.bottom - stickerMargin - circleSize, circleSize, circleSize);
    final pill = voicePillOf(circle, const Size(300, 64), area);
    expect(pill.bottom, lessThanOrEqualTo(area.bottom - stickerMargin));
    expect(pill.left, circle.left);
  });

  test('плашку тянут за край — она остаётся в свободной части экрана', () {
    const size = Size(300, 64);
    expect(voicePillAt(const Offset(-50, 0), size, area).topLeft, Offset(area.left + stickerMargin, area.top + stickerMargin));
    expect(voicePillAt(const Offset(500, 2000), size, area).bottomRight, Offset(area.right - stickerMargin, area.bottom - stickerMargin));
  });
}
