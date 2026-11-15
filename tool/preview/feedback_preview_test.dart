// Кадры «Помощь» и «Сообщить о проблеме» с настоящими шрифтами, тёмная и светлая.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/feedback_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/app_theme.dart';
import 'package:stowa/core/theme/palette.dart';
import 'package:stowa/core/theme/tokens.dart';
import 'package:stowa/domain/appearance.dart';
import 'package:stowa/features/settings/feedback_screen.dart';
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
  for (final (name, choice) in [('feedback_dark', ThemeChoice.dark), ('feedback_light', ThemeChoice.light)]) {
    testWidgets(name, (tester) async {
      final world = TestWorld();
      addTearDown(world.dispose);
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
            home: FeedbackScreen(send: (_) async => FeedbackResult.sent),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      Future<void> shot(String file) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('build/previews').createSync(recursive: true);
          File('build/previews/$file.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }

      await tester.enterText(find.byKey(const ValueKey('feedback-text')), 'После обновления виджет на рабочем столе показывает пустую строку, хотя заметки есть.');
      await tester.enterText(find.byKey(const ValueKey('feedback-email')), 'anna@example.com');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await shot(name);
      await tester.tap(find.byKey(const ValueKey('feedback-send')));
      await tester.pumpAndSettle();
      await shot('${name}_sent');
      expect(tester.takeException(), isNull);
    });
  }
}
