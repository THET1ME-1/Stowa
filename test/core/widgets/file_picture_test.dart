import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mime/mime.dart';
import 'package:stowa/core/widgets/file_picture.dart';

// SVG из хранилища (иконки, схемы, вложения Obsidian) системный декодер не читает:
// без отдельной отрисовки на месте картинки была бы пустая плитка
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('stowa_svg'));
  tearDown(() => root.deleteSync(recursive: true));

  testWidgets('SVG рисует векторный виджет, остальное — обычная картинка', (tester) async {
    final svg = File('${root.path}/схема.SVG')..writeAsStringSync('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="red"/></svg>');
    final png = File('test/fixtures/images/wide.png');
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            SizedBox(width: 100, height: 100, child: FilePicture(svg, fit: BoxFit.cover)),
            SizedBox(width: 100, height: 100, child: FilePicture(png, fit: BoxFit.cover, cacheWidth: 100)),
          ],
        ),
      ),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).image, isA<ResizeImage>());
  });

  testWidgets('кадр загрузки у вектора отдаётся сразу готовым', (tester) async {
    final svg = File('${root.path}/знак.svg')..writeAsStringSync('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 4 4"/>');
    int? shownFrame;
    await tester.pumpWidget(
      MaterialApp(
        home: FilePicture(
          svg,
          frameBuilder: (context, child, frame, sync) {
            shownFrame = frame;
            return child;
          },
        ),
      ),
    );
    expect(shownFrame, 0);
  });

  test('SVG — картинка: тип по расширению, как у вложения', () {
    expect(lookupMimeType('Вложения/схема.svg'), 'image/svg+xml');
    expect(isSvgPath('a/b.Svg'), isTrue);
    expect(isSvgPath('a/b.png'), isFalse);
  });
}
