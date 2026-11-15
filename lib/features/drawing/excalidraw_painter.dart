import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/excalidraw.dart';

/// Рисует сцену Excalidraw в её собственных координатах: фигуры, линии со стрелками,
/// рисунок рукой, подписи, рамки. Картинки рисует экран отдельными виджетами — им
/// нужна загрузка файла. Линии чистые, без «карандашной» дрожи Excalidraw: смысл тот же.
class ExcalidrawPainter extends CustomPainter {
  const ExcalidrawPainter(this.scene, {required this.origin, this.fontFamily});

  final ExcalidrawScene scene;

  /// Левый верхний угол рисунка: он ложится в (0, 0) холста.
  final Offset origin;

  /// Шрифт подписей; рукописного Excalidraw в приложении нет.
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(-origin.dx, -origin.dy);
    for (final element in scene.elements) {
      if (element.type == 'image') continue;
      canvas.save();
      if (element.angle != 0) {
        final box = element.bounds;
        final center = element.isLinear ? Offset((box.left + box.right) / 2, (box.top + box.bottom) / 2) : Offset(element.x + element.width / 2, element.y + element.height / 2);
        canvas.translate(center.dx, center.dy);
        canvas.rotate(element.angle);
        canvas.translate(-center.dx, -center.dy);
      }
      _paint(canvas, element);
      canvas.restore();
    }
  }

  void _paint(Canvas canvas, ExcalidrawElement element) {
    switch (element.type) {
      case 'rectangle' || 'embeddable' || 'iframe':
        _shape(canvas, element, _rectangle(element));
      case 'diamond':
        _shape(canvas, element, _diamond(element));
      case 'ellipse':
        _shape(canvas, element, Path()..addOval(Rect.fromLTWH(element.x, element.y, element.width, element.height)));
      case 'line' || 'arrow':
        _line(canvas, element);
      case 'freedraw':
        _freedraw(canvas, element);
      case 'text':
        _text(canvas, element);
      case 'frame' || 'magicframe':
        _frame(canvas, element);
    }
  }

  Paint _stroke(ExcalidrawElement element, {double? width}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width ?? element.strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true
    ..color = _color(element.stroke, element.opacity);

  Color _color(int argb, double opacity) {
    final color = Color(argb);
    return color.withValues(alpha: color.a * opacity);
  }

  Path _rectangle(ExcalidrawElement element) {
    final rect = Rect.fromLTWH(element.x, element.y, element.width, element.height);
    if (!element.rounded) return Path()..addRect(rect);
    // скругление Excalidraw: четверть меньшей стороны, но не больше 32
    final radius = math.min(32.0, math.min(rect.width.abs(), rect.height.abs()) * 0.25);
    return Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  }

  Path _diamond(ExcalidrawElement element) {
    final x = element.x, y = element.y, w = element.width, h = element.height;
    return Path()
      ..moveTo(x + w / 2, y)
      ..lineTo(x + w, y + h / 2)
      ..lineTo(x + w / 2, y + h)
      ..lineTo(x, y + h / 2)
      ..close();
  }

  void _shape(Canvas canvas, ExcalidrawElement element, Path path) {
    if (element.fill case final fill?) _fill(canvas, element, path, fill);
    canvas.drawPath(_dashed(path, element), _stroke(element));
  }

  // заливка: сплошная или штриховкой, как у Excalidraw по умолчанию
  void _fill(Canvas canvas, ExcalidrawElement element, Path path, int fill) {
    final color = _color(fill, element.opacity);
    if (element.fillStyle == 'solid') {
      canvas.drawPath(path, Paint()..color = color);
      return;
    }
    final bounds = path.getBounds();
    final gap = math.max(4.0, element.strokeWidth * 4);
    final paint = Paint()
      ..color = color
      ..strokeWidth = math.max(1.0, element.strokeWidth / 2)
      ..style = PaintingStyle.stroke;
    canvas.save();
    canvas.clipPath(path);
    void hatch(double angle) {
      final reach = bounds.width + bounds.height;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final normal = Offset(-direction.dy, direction.dx);
      for (var offset = -reach; offset <= reach; offset += gap) {
        final middle = bounds.center + normal * offset;
        canvas.drawLine(middle - direction * reach, middle + direction * reach, paint);
      }
    }

    hatch(-0.715);
    if (element.fillStyle == 'cross-hatch') hatch(0.715);
    canvas.restore();
  }

  // пунктир и точки — кусками пути
  Path _dashed(Path path, ExcalidrawElement element) {
    if (element.strokeStyle == 'solid') return path;
    final dash = element.strokeStyle == 'dotted' ? 0.0 : 8 + element.strokeWidth * 2;
    final gap = element.strokeStyle == 'dotted' ? 4 + element.strokeWidth * 2 : 8 + element.strokeWidth * 2;
    final result = Path();
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += dash + gap) {
        result.addPath(metric.extractPath(at, math.min(metric.length, at + math.max(dash, 0.1))), Offset.zero);
      }
    }
    return result;
  }

  List<Offset> _points(ExcalidrawElement element) => [for (final (px, py) in element.points) Offset(element.x + px, element.y + py)];

  void _line(Canvas canvas, ExcalidrawElement element) {
    final points = _points(element);
    if (points.length < 2) return;
    final path = element.rounded && points.length > 2 ? _smooth(points) : (Path()..addPolygon(points, false));
    // замкнутая линия с заливкой — многоугольник
    final closed = element.type == 'line' && (points.first - points.last).distance < 1;
    if (closed && element.fill != null) _fill(canvas, element, Path()..addPolygon(points, true), element.fill!);
    canvas.drawPath(_dashed(path, element), _stroke(element));
    if (element.type != 'arrow') return;
    final paint = _stroke(element);
    if (element.endArrowhead case final head?) _arrowhead(canvas, paint, head, points.last, _towards(points, fromEnd: true), element.strokeWidth);
    if (element.startArrowhead case final head?) _arrowhead(canvas, paint, head, points.first, _towards(points, fromEnd: false), element.strokeWidth);
  }

  // откуда идёт линия к своему концу: соседняя точка, не совпадающая с концом
  Offset _towards(List<Offset> points, {required bool fromEnd}) {
    final ordered = fromEnd ? points.reversed.toList() : points;
    final tip = ordered.first;
    for (final point in ordered.skip(1)) {
      if ((point - tip).distance > 0.5) return point;
    }
    return ordered.last;
  }

  void _arrowhead(Canvas canvas, Paint paint, String kind, Offset tip, Offset from, double strokeWidth) {
    final along = tip - from;
    final length = along.distance;
    if (length == 0) return;
    final direction = along / length;
    final size = math.min(length * 0.5, 14 + strokeWidth * 4);
    Offset wing(double turn) {
      final cos = math.cos(turn), sin = math.sin(turn);
      final back = Offset(-direction.dx * cos + direction.dy * sin, -direction.dx * sin - direction.dy * cos);
      return tip + back * size;
    }

    switch (kind) {
      case 'triangle' || 'triangle_outline':
        final triangle = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(wing(0.45).dx, wing(0.45).dy)
          ..lineTo(wing(-0.45).dx, wing(-0.45).dy)
          ..close();
        canvas.drawPath(triangle, kind == 'triangle' ? (Paint()..color = paint.color) : paint);
      case 'dot' || 'circle' || 'circle_outline':
        final circle = Paint()..color = paint.color;
        if (kind == 'circle_outline') circle.style = PaintingStyle.stroke;
        canvas.drawCircle(tip - direction * (size * 0.3), size * 0.3, circle);
      case 'bar':
        final normal = Offset(-direction.dy, direction.dx) * (size * 0.6);
        canvas.drawLine(tip - normal, tip + normal, paint);
      default:
        canvas.drawLine(tip, wing(0.45), paint);
        canvas.drawLine(tip, wing(-0.45), paint);
    }
  }

  // плавная кривая через все точки: Catmull-Rom кубиками
  Path _smooth(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 0; index < points.length - 1; index++) {
      final before = index == 0 ? points[index] : points[index - 1];
      final start = points[index];
      final end = points[index + 1];
      final after = index + 2 < points.length ? points[index + 2] : end;
      final first = start + (end - before) / 6;
      final second = end - (after - start) / 6;
      path.cubicTo(first.dx, first.dy, second.dx, second.dy, end.dx, end.dy);
    }
    return path;
  }

  // рисунок рукой: Excalidraw обводит его кистью с нажимом, здесь — ровная кисть той же толщины
  void _freedraw(Canvas canvas, ExcalidrawElement element) {
    final points = _points(element);
    if (points.isEmpty) return;
    canvas.drawPath(freehandPath(points), _stroke(element, width: element.strokeWidth * 2.2));
  }

  void _text(Canvas canvas, ExcalidrawElement element) {
    if (element.text.trim().isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: element.text,
        style: TextStyle(
          color: _color(element.stroke, element.opacity),
          fontSize: element.fontSize,
          height: element.lineHeight,
          fontFamily: element.fontFamily == 3 ? 'monospace' : fontFamily,
          // моноширинного может не оказаться: тогда буквы шрифта приложения, а не квадратики
          fontFamilyFallback: [?fontFamily],
        ),
      ),
      textAlign: switch (element.textAlign) {
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        _ => TextAlign.left,
      },
      textDirection: TextDirection.ltr,
    // переносы строк Excalidraw уже вписал в текст: свои не нужны
    )..layout(minWidth: element.width, maxWidth: double.infinity);
    painter.paint(canvas, Offset(element.x, element.y));
    painter.dispose();
  }

  void _frame(Canvas canvas, ExcalidrawElement element) {
    final rect = Rect.fromLTWH(element.x, element.y, element.width, element.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFBBBBBB));
    final name = element.name;
    if (name == null || name.isEmpty) return;
    final label = TextPainter(
      text: TextSpan(text: name, style: TextStyle(color: const Color(0xFF808080), fontSize: 14, fontFamily: fontFamily)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(element.width, 1));
    label.paint(canvas, Offset(element.x, element.y - label.height - 4));
    label.dispose();
  }

  @override
  bool shouldRepaint(ExcalidrawPainter old) => old.scene != scene || old.origin != origin || old.fontFamily != fontFamily;
}

/// Тёмная тема Excalidraw: лист и линии инвертированы на 93% с поворотом оттенка на 180°,
/// как в Obsidian. Цвета в файле хранятся светлыми.
const ColorFilter excalidrawDarkFilter = ColorFilter.matrix(_darkMatrix);

// поворот оттенка на 180° (матрица hue-rotate из CSS), умноженный на инверсию 93%:
// сдвиг 0,93 × 255 одинаков у всех строк, потому что строки поворота в сумме дают 1
const List<double> _darkMatrix = [
  0.49364, -1.2298, -0.12384, 0, 237.15, //
  -0.36636, -0.3698, -0.12384, 0, 237.15,
  -0.36636, -1.2298, 0.73616, 0, 237.15,
  0, 0, 0, 1, 0,
];

/// Плавный путь рисунка рукой по точкам.
ui.Path freehandPath(List<Offset> points) {
  final path = ui.Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  if (points.length == 1) {
    path.lineTo(points.first.dx + 0.01, points.first.dy);
    return path;
  }
  for (var index = 1; index < points.length - 1; index++) {
    final middle = (points[index] + points[index + 1]) / 2;
    path.quadraticBezierTo(points[index].dx, points[index].dy, middle.dx, middle.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  return path;
}
