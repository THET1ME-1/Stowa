import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/widgets/stowa_mark.dart';

void main() {
  test('знак вместо буквы — только у хранилища с именем приложения', () {
    expect(isStowaName('Stowa'), isTrue);
    expect(isStowaName(' stowa '), isTrue);
    expect(isStowaName('Учёба'), isFalse);
    expect(isStowaName('Stowa 2'), isFalse);
  });

  testWidgets('знак рисуется в заданный цвет и не вылезает за свой квадрат', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: const Center(child: StowaMark(size: 40, color: Color(0xFFFF0000)))));
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage());
    final bytes = (await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    final width = image!.width;
    var red = 0;
    var outside = 0;
    final left = (width - 40) ~/ 2;
    final top = (image.height - 40) ~/ 2;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        if (bytes.getUint8(i) > 200 && bytes.getUint8(i + 3) > 200) {
          red++;
          if (x < left || x >= left + 40 || y < top || y >= top + 40) outside++;
        }
      }
    }
    // S занимает заметную долю квадрата, но не весь его
    expect(red, inInclusiveRange(500, 1400));
    expect(outside, 0);
  });
}
