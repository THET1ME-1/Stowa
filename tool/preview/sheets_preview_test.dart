// Кадры листов снизу с настоящими шрифтами: меню заметки из ленты, «⋮» заметки, день сводки,
// «Напомнить». Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/sheets_preview_test.dart
// Картинки ложатся в build/previews/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/features/settings/returns_screen.dart';

import '../../test/helpers/test_app.dart';

final _out = Directory('build/previews');

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

  Future<TestWorld> world(WidgetTester tester) async {
    final world = TestWorld();
    addTearDown(world.dispose);
    world.placeChannel.background = true;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(392, 850);
    addTearDown(tester.view.reset);
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'blood', kind: ItemKind.note, title: 'Сдать кровь', body: const Value('Сдать кровь\nнатощак, до 10 утра'), createdAt: world.now, updatedAt: world.now),
    );
    for (final (id, name, kind) in [('h', 'Дом', PlaceKind.home), ('u', 'Универ', PlaceKind.study), ('l', 'Linella', PlaceKind.shop)]) {
      await world.db.into(world.db.places).insert(PlacesCompanion.insert(id: id, kind: kind, name: name, latitude: 47.0, longitude: 28.8, createdAt: world.now));
    }
    return world;
  }

  testWidgets('меню заметки из ленты', (tester) async {
    final test = await world(tester);
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: test.app()));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Сдать кровь').first);
    await _shot(tester, 'sheets-1-лента');
  });

  testWidgets('страница заметки: «⋮» и «Напомнить»', (tester) async {
    final test = await world(tester);
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: test.wrap(const ItemScreen(id: 'blood'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё'));
    await _shot(tester, 'sheets-2-меню');
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Напомнить'));
    await _shot(tester, 'sheets-3-напомнить');
  });

  testWidgets('день сводки', (tester) async {
    final test = await world(tester);
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: test.wrap(const ReturnsScreen())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('День сводки'), 100);
    await tester.tap(find.text('День сводки'));
    await _shot(tester, 'sheets-4-день');
  });
}
