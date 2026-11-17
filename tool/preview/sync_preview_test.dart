// Кадры «Stowa Sync»: почта, код из письма, вошли. Настоящие шрифты, тёмная и светлая.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/sync_preview_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stowa/core/theme/app_theme.dart';
import 'package:stowa/core/theme/palette.dart';
import 'package:stowa/core/theme/tokens.dart';
import 'package:stowa/domain/appearance.dart';
import 'package:stowa/features/settings/sync_screen.dart';
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
  for (final (name, choice) in [('sync_dark', ThemeChoice.dark), ('sync_light', ThemeChoice.light)]) {
    testWidgets(name, (tester) async {
      final world = TestWorld();
      final vault = Directory.systemTemp.createTempSync('stowa_sync_preview');
      addTearDown(() async {
        await world.dispose();
        vault.deleteSync(recursive: true);
      });
      world.vaultRoot = vault;
      world.syncHttp = MockClient((request) async {
        final path = request.url.path;
        if (path == '/v1/auth/start') return http.Response('', 204);
        if (path == '/v1/auth/verify') return http.Response(jsonEncode({'token': 't', 'email': 'anna@example.com', 'active': true}), 200);
        if (path == '/v1/key') return request.method == 'GET' ? http.Response('{"key":null}', 200) : http.Response('', 204);
        if (path == '/v1/changes') return http.Response('{"cursor":0,"more":false,"changes":[]}', 200);
        return http.Response('', 404);
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(392, 850);
      addTearDown(tester.view.reset);
      final palette = paletteFor(Appearance(choice: choice), choice == ThemeChoice.light ? Brightness.light : Brightness.dark);
      Tokens.use(palette);
      addTearDown(() => Tokens.use(StowaPalette.graphiteDark));
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('shot'),
          child: ProviderScope(
            overrides: world.overrides,
            child: MaterialApp(
              theme: buildAppTheme(palette),
              locale: const Locale('ru'),
              localizationsDelegates: L.localizationsDelegates,
              supportedLocales: L.supportedLocales,
              home: const SyncScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> shot(String file) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('build/previews').createSync(recursive: true);
          File('build/previews/$file.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }

      await tester.enterText(find.byKey(const ValueKey('sync-email')), 'anna@example.com');
      await shot('${name}_email');
      await tester.tap(find.byKey(const ValueKey('sync-get-code')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('sync-code')), '4829');
      await shot('${name}_code');
      await tester.enterText(find.byKey(const ValueKey('sync-code')), '482913');
      await tester.pumpAndSettle();
      await shot('${name}_on');
      expect(tester.takeException(), isNull);
    });
  }
}
