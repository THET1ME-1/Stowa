// Кадры «Мест» и экрана места с настоящими шрифтами, чтобы посмотреть глазами.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/places_preview_test.dart
// Картинки ложатся в build/previews/. Плитки карты в тестах не грузятся — поле карты пустое.
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
import 'package:stowa/features/places/place_edit_screen.dart';
import 'package:stowa/features/places/places_screen.dart';

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
    for (final (id, name, kind, wifi) in [
      ('h', 'Дом', PlaceKind.home, 'HomeNet'),
      ('o', 'Офис на Штефана', PlaceKind.work, null),
      ('u', 'Универ', PlaceKind.study, null),
      ('l', 'Linella на Ботанике', PlaceKind.shop, null),
      ('a', 'Andy’s Pizza', PlaceKind.food, null),
      ('s', 'Саша', PlaceKind.guests, null),
    ]) {
      await world.db.into(world.db.places).insert(PlacesCompanion.insert(id: id, kind: kind, name: name, latitude: 47.0, longitude: 28.8, wifi: Value(wifi), createdAt: world.now));
    }
    return world;
  }

  testWidgets('места', (tester) async {
    final test = await world(tester);
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: test.wrap(const PlacesScreen())));
    await _shot(tester, 'places-1-список');
  });

  testWidgets('новое место', (tester) async {
    // кэш плиток карты спрашивает папку у плагина: в тесте отдаём временную
    final cache = Directory.systemTemp.createTempSync('tiles');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => cache.path);
    final test = await world(tester);
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: test.wrap(const PlaceEditScreen())));
    await tester.enterText(find.byType(TextField), 'Универ');
    await _shot(tester, 'places-2-новое');
    await tester.tap(find.text('Найти или создать'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Да');
    await _shot(tester, 'places-3-поиск');
    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Значок'));
    await tester.pumpAndSettle();
    await _shot(tester, 'places-4-значок');
  });
}
