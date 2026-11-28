import 'package:flutter/widgets.dart';

/// Знак Stowa (S): фигура из design/logo/master/S_logo_master.svg и её копия, повёрнутая на
/// 180° вокруг центра. Рисуется в любой цвет — по теме, а не картинкой.
class StowaMark extends StatelessWidget {
  const StowaMark({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: CustomPaint(painter: _MarkPainter(color)));
}

/// Хранилище зовётся как приложение: вместо первой буквы — знак.
bool isStowaName(String name) => name.trim().toLowerCase() == 'stowa';

/// Контур половинки из мастер-файла (точки в его координатах, холст 1256).
const _half =
    '921,716 913,694 904,678 897,668 879,648 866,637 850,626 823,612 794,602 790,602 776,598 764,597 763,596 739,595 738,594 721,594 720,593 721,591 726,589 728,587 735,584 760,569 771,564 773,562 782,558 784,556 793,552 808,543 806,543 801,546 783,552 780,554 778,554 775,556 748,566 736,572 729,574 708,584 706,584 558,654 556,654 533,665 531,665 491,683 484,685 465,694 458,696 439,705 427,709 413,716 406,718 371,735 360,743 344,759 337,768 327,787 323,798 321,810 320,811 320,816 319,817 319,841 320,842 320,848 327,871 336,888 347,903 363,918 376,927 395,936 412,941 424,942 425,943 729,943 730,942 740,942 741,941 746,941 752,939 757,939 793,928 815,918 817,916 834,907 848,897 867,881 883,864 893,851 904,834 913,816 921,794 921,790 923,785 924,774 925,773 925,766 926,765 926,744 925,743 925,735 924,734 924,729 923,728';

// центр поворота второй половинки и рамка знака целиком
const _pivot = Offset(634.5, 614);
const _frame = Rect.fromLTRB(300, 270, 956, 958);

final Path _mark = () {
  final points = [
    for (final pair in _half.split(' '))
      Offset(double.parse(pair.split(',')[0]), double.parse(pair.split(',')[1])),
  ];
  final half = Path()..addPolygon(points, true);
  // поворот на 180° вокруг центра — это отражение точки через него
  final turned = Path()..addPolygon([for (final point in points) _pivot * 2 - point], true);
  return Path()
    ..addPath(half, Offset.zero)
    ..addPath(turned, Offset.zero);
}();

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _frame.longestSide;
    canvas
      ..translate((size.width - _frame.width * scale) / 2, (size.height - _frame.height * scale) / 2)
      ..scale(scale)
      ..translate(-_frame.left, -_frame.top);
    canvas.drawPath(_mark, Paint()
      ..color = color
      ..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}
