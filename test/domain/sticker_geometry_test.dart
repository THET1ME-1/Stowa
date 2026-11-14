import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/sticker_geometry.dart';

void main() {
  // телефон 411 × 914 точек, книжный и альбомный
  const phone = Size(411, 914);
  const landscape = Size(914, 411);
  const height = 180.0;

  bool inside(Offset at, Size box, Size screen) =>
      at.dx >= stickerMargin - 0.001 &&
      at.dy >= stickerMargin - 0.001 &&
      at.dx + box.width <= screen.width - stickerMargin + 0.001 &&
      at.dy + box.height <= screen.height - stickerMargin + 0.001;

  const circle = Size.square(circleSize);
  const sticker = Size(stickerWidth, height);

  test('стикер справа от середины сворачивается в свой правый верхний угол', () {
    const at = Offset(160, 300);
    expect(circleOf(at, phone), const Offset(160 + stickerWidth - circleSize, 300));
  });

  test('стикер слева сворачивается в свой левый верхний угол', () {
    const at = Offset(20, 300);
    expect(circleOf(at, phone), const Offset(20, 300));
  });

  test('круг у правого края раскрывается влево и не выходит за экран', () {
    const at = Offset(411 - stickerMargin - circleSize, 200);
    final opened = stickerOf(at, height, phone);
    // правый край стикера — там же, где правый край круга
    expect(opened.dx + stickerWidth, at.dx + circleSize);
    expect(opened.dy, at.dy);
    expect(inside(opened, sticker, phone), isTrue);
  });

  test('круг слева раскрывается вправо', () {
    const at = Offset(stickerMargin, 200);
    expect(stickerOf(at, height, phone), at);
  });

  test('круг внизу раскрывается вверх: низ стикера — низ круга', () {
    const at = Offset(stickerMargin, 914 - stickerMargin - circleSize);
    final opened = stickerOf(at, height, phone);
    expect(opened.dy + height, at.dy + circleSize);
    expect(inside(opened, sticker, phone), isTrue);
  });

  test('свернул и раскрыл на месте — стикер там же, где был', () {
    for (final at in const [Offset(20, 100), Offset(160, 400), Offset(stickerMargin, 600)]) {
      expect(stickerOf(circleOf(at, phone), height, phone), at);
    }
  });

  test('место за экраном зажимается внутрь, даже если стикер больше экрана', () {
    expect(clampTo(const Offset(-50, 2000), sticker, phone), Offset(stickerMargin, 914 - stickerMargin - height));
    expect(clampTo(const Offset(30, 30), const Size(1000, 100), phone).dx, stickerMargin);
  });

  test('поворот в альбомный: и стикеры, и круги остаются внутри экрана', () {
    final places = [
      const StickerPlace(id: 'a', folded: false, sticker: Offset(160, 700), circle: Offset(344, 700)),
      const StickerPlace(id: 'b', folded: true, sticker: Offset(20, 850), circle: Offset(20, 850)),
    ];
    for (final place in places) {
      final fitted = fitTo(place, height, landscape);
      expect(fitted.id, place.id);
      expect(fitted.folded, place.folded);
      expect(inside(fitted.sticker, sticker, landscape), isTrue);
      expect(inside(fitted.circle, circle, landscape), isTrue);
    }
  });

  test('высокий стикер в альбомном прижимается к верху, а не уходит выше экрана', () {
    const tall = 600.0;
    final fitted = fitTo(const StickerPlace(id: 'a', folded: false, sticker: Offset(100, 300), circle: Offset(100, 300)), tall, landscape);
    expect(fitted.sticker.dy, stickerMargin);
  });
}
