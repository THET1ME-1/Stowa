// Кадры рисунка Excalidraw с настоящими шрифтами: тёмная и светлая.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/drawing_preview_test.dart
// Свои рисунки: DRAWINGS="/путь/к/Схема.excalidraw.md:/путь/к/другому.excalidraw.md" перед командой.
// Картинки ложатся в build/previews/drawing_<номер>_<тема>.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/app_theme.dart';
import 'package:stowa/core/theme/palette.dart';
import 'package:stowa/core/theme/tokens.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/appearance.dart';
import 'package:stowa/domain/excalidraw.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/l10n/app_localizations.dart';

import '../../test/helpers/test_app.dart';

Future<void> _loadFonts() async {
  for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

void main() {
  setUpAll(_loadFonts);
  final own = Platform.environment['DRAWINGS'];
  final files = own == null || own.isEmpty ? ['test/fixtures/excalidraw/Схема.excalidraw.md'] : own.split(':');

  for (final (index, path) in files.indexed) {
    for (final (name, choice) in [('dark', ThemeChoice.dark), ('light', ThemeChoice.light)]) {
      testWidgets('drawing_${index}_$name', (tester) async {
        final world = TestWorld();
        addTearDown(world.dispose);
        final text = File(path).readAsStringSync();
        await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: 'd', kind: ItemKind.drawing, title: excalidrawTitle(path.split('/').last),
          body: Value(excalidrawTexts(text).join('\n')), document: Value(text), createdAt: world.now, updatedAt: world.now,
        ));
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(392, 850);
        addTearDown(tester.view.reset);
        final palette = paletteFor(Appearance(choice: choice), choice == ThemeChoice.light ? Brightness.light : Brightness.dark);
        Tokens.use(palette);
        addTearDown(() => Tokens.use(StowaPalette.graphiteDark));
        addTearDown(() => tester.pumpWidget(const SizedBox()));
        await tester.pumpWidget(RepaintBoundary(
          key: const ValueKey('shot'),
          child: ProviderScope(
            overrides: world.overrides,
            child: MaterialApp(
              theme: buildAppTheme(palette),
              locale: const Locale('ru'),
              localizationsDelegates: L.localizationsDelegates,
              supportedLocales: L.supportedLocales,
              home: const ItemScreen(id: 'd'),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('build/previews').createSync(recursive: true);
          File('build/previews/drawing_${index}_$name.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
        expect(tester.takeException(), isNull);
      });
    }
  }
}
