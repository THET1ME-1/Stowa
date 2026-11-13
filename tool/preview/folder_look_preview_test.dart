// Кадры экрана «Цвет и значок» с настоящими шрифтами, чтобы посмотреть глазами.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/folder_look_preview_test.dart
// Картинки ложатся в build/previews/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/repositories/folders_repository.dart';
import 'package:stowa/features/folder/folder_look_screen.dart';

import '../../test/helpers/test_app.dart';

final _out = Directory('build/previews');

const _folder = FolderCard(id: 'food', name: 'Рецепты', icon: 'restaurant', shape: 'cookie9', count: 12, covers: [], recentTitles: [], createdByAi: false);

Future<void> _loadFonts() async {
  for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    _out.createSync(recursive: true);
    File(p.join(_out.path, '$name.png')).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  Future<void> open(WidgetTester tester, Size size) async {
    final world = TestWorld();
    addTearDown(world.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: world.wrap(const FolderLookScreen(folder: _folder))));
    await tester.pumpAndSettle();
  }

  testWidgets('телефон', (tester) async {
    await open(tester, const Size(392, 850));
    await _shot(tester, 'look-1-телефон');
    await tester.tap(find.byKey(const ValueKey('color-teal')));
    await tester.tap(find.byKey(const ValueKey('shape-gem')));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const ValueKey('look-scroll')), const Offset(0, -900));
    await _shot(tester, 'look-2-листаю');
  });

  testWidgets('узкий', (tester) async {
    await open(tester, const Size(320, 680));
    await _shot(tester, 'look-3-узкий');
  });

  testWidgets('планшет', (tester) async {
    await open(tester, const Size(1000, 700));
    await _shot(tester, 'look-4-планшет');
  });
}
