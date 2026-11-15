import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/image_size.dart';

void main() {
  ({int width, int height})? sizeOf(String name) => imageSizeOf(File('test/fixtures/images/$name').readAsBytesSync());

  test('размер из заголовка: jpeg, png, gif, webp', () {
    for (final name in ['wide.jpg', 'wide.png', 'wide.gif', 'wide.webp', 'wide_lossless.webp']) {
      expect(sizeOf(name), (width: 30, height: 20), reason: name);
    }
  });

  test('снимок, повёрнутый в EXIF, отдаёт размер как на экране', () {
    expect(sizeOf('rotated.jpg'), (width: 20, height: 30));
  });

  test('SVG: размер из width и height, без них или в процентах — из viewBox', () {
    ({int width, int height})? svg(String text) => imageSizeOf(text.codeUnits);
    expect(svg('<?xml version="1.0"?>\n<svg xmlns="http://www.w3.org/2000/svg" width="120" height="80px">'), (width: 120, height: 80));
    expect(svg("<svg viewBox='0 0 300 150' xmlns='http://www.w3.org/2000/svg'><rect/></svg>"), (width: 300, height: 150));
    expect(svg('<svg width="100%" height="100%" viewBox="0,0,64,32">'), (width: 64, height: 32));
    expect(svg('<svg xmlns="http://www.w3.org/2000/svg">'), isNull);
    expect(svg('<html><body>не картинка</body></html>'), isNull);
  });

  test('не картинка — null, а не падение', () {
    expect(imageSizeOf([1, 2, 3, 4]), isNull);
    expect(imageSizeOf(const []), isNull);
  });
}
