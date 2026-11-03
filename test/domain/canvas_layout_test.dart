import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/canvas_layout.dart';

bool overlaps(CanvasBox a, CanvasBox b) => a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;

void main() {
  test('пустой холст начинается с (0, 0)', () {
    final placed = placeNew(const [], const [CanvasSize(itemId: 'a', width: 240, height: 180)]);
    expect(placed.single.x, 0);
    expect(placed.single.y, 0);
  });

  test('новые вещи встают справа от занятого и не пересекаются ни с чем', () {
    const existing = [CanvasBox(itemId: 'old', x: 0, y: 0, width: 300, height: 200), CanvasBox(itemId: 'old2', x: 100, y: 250, width: 200, height: 400)];
    final placed = placeNew(existing, [for (var index = 0; index < 12; index++) CanvasSize(itemId: 'n$index', width: 240, height: 100.0 + index * 20)]);
    for (final box in placed) {
      expect(box.x, greaterThanOrEqualTo(300 + 24));
      for (final other in [...existing, ...placed]) {
        if (other.itemId != box.itemId) expect(overlaps(box, other), isFalse, reason: '${box.itemId} и ${other.itemId}');
      }
    }
  });

  test('длинная очередь переносится в следующую колонку, а не уходит вниз бесконечно', () {
    final placed = placeNew(const [], [for (var index = 0; index < 20; index++) CanvasSize(itemId: 'n$index', width: 200, height: 300)]);
    final bottom = placed.map((box) => box.y + box.height).reduce((a, b) => a > b ? a : b);
    expect(bottom, lessThanOrEqualTo(canvasColumnHeight + 300));
    expect(placed.map((box) => box.x).toSet().length, greaterThan(1));
  });

  test('уместить: рамка вокруг всего с полями', () {
    const boxes = [CanvasBox(itemId: 'a', x: -100, y: 50, width: 200, height: 100), CanvasBox(itemId: 'b', x: 400, y: 300, width: 100, height: 100)];
    final bounds = canvasBounds(boxes, margin: 20);
    expect(bounds.left, -120);
    expect(bounds.top, 30);
    expect(bounds.right, 520);
    expect(bounds.bottom, 420);
  });
}
