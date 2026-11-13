// Кадр подсказки про чужой язык над строкой ввода, с настоящими шрифтами.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/language_hint_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../test/helpers/test_app.dart';

Future<void> _loadFonts() async {
  for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('подсказка про язык', (tester) async {
    final world = TestWorld();
    addTearDown(world.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(392, 850);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: world.app()));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'demain appeler la banque et le dentiste');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/previews').createSync(recursive: true);
      File(p.join('build/previews', 'language-hint.png')).writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
