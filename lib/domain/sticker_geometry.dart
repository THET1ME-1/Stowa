import 'dart:math' as math;
import 'dart:ui';

/// Ширина стикера и сторона круга, в который он сворачивается, в точках экрана.
const stickerWidth = 236.0;
const circleSize = 52.0;

/// Стикер и круг не подходят к краю экрана ближе этого.
const stickerMargin = 8.0;

/// Где висит стикер и свёрнут ли он. Места — левые верхние углы в точках экрана.
class StickerPlace {
  const StickerPlace({required this.id, required this.folded, required this.sticker, required this.circle});

  final String id;
  final bool folded;
  final Offset sticker;
  final Offset circle;

  StickerPlace copyWith({bool? folded, Offset? sticker, Offset? circle}) =>
      StickerPlace(id: id, folded: folded ?? this.folded, sticker: sticker ?? this.sticker, circle: circle ?? this.circle);
}

/// Куда встаёт круг свёрнутого стикера: в его верхний угол у ближнего края экрана,
/// то есть на том же месте, где стоял стикер.
Offset circleOf(Offset sticker, Size screen) {
  final right = sticker.dx + stickerWidth / 2 > screen.width / 2;
  final at = Offset(right ? sticker.dx + stickerWidth - circleSize : sticker.dx, sticker.dy);
  return clampTo(at, const Size.square(circleSize), screen);
}

/// Куда раскрывается круг: туда, где есть место. Круг в правой половине — стикер растёт
/// влево, снизу не хватает высоты — вверх. Свернул и раскрыл на месте — стикер там же.
Offset stickerOf(Offset circle, double height, Size screen) {
  final right = circle.dx + circleSize / 2 > screen.width / 2;
  final x = right ? circle.dx + circleSize - stickerWidth : circle.dx;
  final fitsBelow = circle.dy + height <= screen.height - stickerMargin;
  final y = fitsBelow ? circle.dy : circle.dy + circleSize - height;
  return clampTo(Offset(x, y), Size(stickerWidth, height), screen);
}

/// Место [at] коробки [box], зажатое в экран с отступом. Коробка больше экрана —
/// прижимается к левому верхнему краю: заголовок и «—» остаются видны.
Offset clampTo(Offset at, Size box, Size screen) {
  double clamp(double value, double room) => math.max(stickerMargin, math.min(value, room - stickerMargin));
  return Offset(clamp(at.dx, screen.width - box.width), clamp(at.dy, screen.height - box.height));
}

/// Экран стал другим (поворот, складной): стикер и круг остаются внутри.
StickerPlace fitTo(StickerPlace place, double height, Size screen) => place.copyWith(
  sticker: clampTo(place.sticker, Size(stickerWidth, height), screen),
  circle: clampTo(place.circle, const Size.square(circleSize), screen),
);
