import 'dart:math';
import 'dart:ui' show Rect;

/// Вещь на холсте: где лежит и какого размера.
class CanvasBox {
  const CanvasBox({required this.itemId, required this.x, required this.y, required this.width, required this.height});

  final String itemId;
  final double x;
  final double y;
  final double width;
  final double height;
}

/// Вещь, которой на холсте ещё нет: размер по её содержимому.
class CanvasSize {
  const CanvasSize({required this.itemId, required this.width, required this.height});

  final String itemId;
  final double width;
  final double height;
}

/// Высота колонки новых вещей: дальше очередь переносится вправо.
const canvasColumnHeight = 1400.0;

/// Новые вещи встают колонками справа от всего, что уже лежит, сверху вниз.
/// Справа от занятого пусто, поэтому пересечься не с чем.
List<CanvasBox> placeNew(List<CanvasBox> existing, List<CanvasSize> newItems, {double gap = 24}) {
  final startX = existing.isEmpty ? 0.0 : existing.map((box) => box.x + box.width).reduce(max) + gap;
  final top = existing.isEmpty ? 0.0 : existing.map((box) => box.y).reduce(min);
  final placed = <CanvasBox>[];
  var x = startX;
  var y = top;
  var columnWidth = 0.0;
  for (final item in newItems) {
    if (y > top && y + item.height > top + canvasColumnHeight) {
      x += columnWidth + gap;
      y = top;
      columnWidth = 0;
    }
    placed.add(CanvasBox(itemId: item.itemId, x: x, y: y, width: item.width, height: item.height));
    y += item.height + gap;
    columnWidth = max(columnWidth, item.width);
  }
  return placed;
}

/// Рамка вокруг всех вещей с полями: «уместить» показывает её целиком.
Rect canvasBounds(List<CanvasBox> boxes, {double margin = 40}) {
  if (boxes.isEmpty) return Rect.zero;
  final left = boxes.map((box) => box.x).reduce(min);
  final top = boxes.map((box) => box.y).reduce(min);
  final right = boxes.map((box) => box.x + box.width).reduce(max);
  final bottom = boxes.map((box) => box.y + box.height).reduce(max);
  return Rect.fromLTRB(left - margin, top - margin, right + margin, bottom + margin);
}
