import 'dart:convert';
import 'dart:math';

// рамка страницы: «/MediaBox [x0 y0 x1 y1]», числа бывают дробные и отрицательные
final _mediaBox = RegExp(r'/MediaBox\s*\[\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\]');
final _rotate = RegExp(r'/Rotate\s+(-?\d+)');

/// Размер первой страницы PDF в пунктах, как её видят (поворот `/Rotate` учтён): холст ставит
/// документ в пропорциях его страницы. Не PDF или рамки нет — null.
({int width, int height})? pdfPageSize(List<int> bytes) {
  if (bytes.length < 5 || latin1.decode(bytes.sublist(0, 5)) != '%PDF-') return null;
  // рамка у первой страницы или у дерева страниц — в начале файла; дальше идут потоки
  final head = latin1.decode(bytes.length > 4 * 1024 * 1024 ? bytes.sublist(0, 4 * 1024 * 1024) : bytes, allowInvalid: true);
  final box = _mediaBox.firstMatch(head);
  if (box == null) return null;
  final [x0, y0, x1, y1] = [for (var group = 1; group <= 4; group++) double.tryParse(box.group(group)!) ?? 0];
  final width = (x1 - x0).abs().round();
  final height = (y1 - y0).abs().round();
  if (width == 0 || height == 0) return null;
  // поворот ищется рядом с рамкой, в том же словаре страницы
  final around = head.substring(max(0, box.start - 400), min(head.length, box.end + 400));
  final turn = (int.tryParse(_rotate.firstMatch(around)?.group(1) ?? '') ?? 0) % 180;
  return turn.abs() == 90 ? (width: height, height: width) : (width: width, height: height);
}
