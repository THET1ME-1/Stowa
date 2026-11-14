import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/spine_colors.dart';

void main() {
  const plain = Color(0xFF96979D);
  const accent = Color(0xFFF4F4F2);
  const amber = Color(0xFFFEC766);
  const mint = Color(0xFF76D5A4);

  List<Spine> spines(List<PinnedSpine> pinned, {bool locked = false}) => spinesFor(pinned, locked: locked, plain: plain, accent: accent);

  test('корешок — цвет папки закреплённой заметки, сверху вниз в порядке закрепления', () {
    final result = spines([(color: amber, length: 40), (color: mint, length: 40)]);
    expect([for (final one in result) one.color], [amber, mint]);
  });

  test('заметка без папки — нейтральный корешок', () {
    expect(spines([(color: null, length: 10)]).single.color, plain);
  });

  test('не больше пяти корешков', () {
    expect(spines([for (var index = 0; index < 8; index++) (color: amber, length: 10)]), hasLength(5));
  });

  test('длинная заметка — корешок толще, но в пределах 1,6–3', () {
    final result = spines([(color: amber, length: 0), (color: mint, length: 5000)]);
    expect(result.first.weight, 1.6);
    expect(result.last.weight, 3);
  });

  test('закреплённых нет или стоит замок — один корешок цвета акцента: цвета папок не выдают, что внутри', () {
    expect(spines(const []), [const Spine(accent, 1)]);
    expect(spines([(color: amber, length: 10)], locked: true), [const Spine(accent, 1)]);
  });
}
