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

  test('не картинка — null, а не падение', () {
    expect(imageSizeOf([1, 2, 3, 4]), isNull);
    expect(imageSizeOf(const []), isNull);
  });
}
