// Кадры маршрута по главным экранам на тестовом стенде: посмотреть глазами до прогона на iPhone.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/walk_preview_test.dart
// Картинки ложатся в build/previews/walk/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../integration_test/walk.dart';
import '../../test/helpers/test_app.dart';

final _out = Directory('build/previews/walk');

void main() {
  setUpAll(() async {
    for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
      final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
      await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });

  testWidgets('маршрут по экранам', (tester) async {
    final world = TestWorld();
    addTearDown(world.dispose);
    tester.view.physicalSize = const Size(392, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: world.app()));
    await tester.pumpAndSettle();

    final steps = await walkScreens(
      tester,
      wait: () async {
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
      },
      shot: (name) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          _out.createSync(recursive: true);
          File(p.join(_out.path, '$name.png')).writeAsBytesSync(png!.buffer.asUint8List());
        });
      },
    );
    for (final step in steps) {
      debugPrint(step.error == null ? 'ok ${step.name}' : 'FAIL ${step.name}: ${step.error}');
    }
  });
}
