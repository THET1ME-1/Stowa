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
import 'package:stowa/data/providers.dart';
import 'package:stowa/domain/appearance.dart';
import 'package:stowa/features/settings/sync_screen.dart';
import 'package:stowa/l10n/app_localizations.dart';
import 'package:stowa/services/sync/sync_progress.dart';

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

      // ход прохода: значок крутится, settle не дождётся — кадр через полсекунды
      final service = ProviderScope.containerOf(tester.element(find.byType(SyncScreen))).read(syncServiceProvider);
      Future<void> moving(String file, SyncProgress progress) async {
        service.track(progress);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File('build/previews/$file.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }

      const mb = 1024 * 1024;
      await moving('${name}_folder', const SyncProgress(SyncStage.folder, done: 1840, total: 3873));
      await moving('${name}_receive', const SyncProgress(SyncStage.receive, done: 1214, total: 3873, bytesDone: 211 * mb, bytesTotal: 633 * mb, file: 'Конспекты/Физика/Лекция 12. Электромагнитная индукция.md'));
      await moving('${name}_send', const SyncProgress(SyncStage.send, done: 3, total: 12, bytesDone: 2 * mb, bytesTotal: 18 * mb, file: 'Вложения/IMG_2045.jpg'));
      await moving('${name}_place', const SyncProgress(SyncStage.place));
      service.track(null);
      service.status.value = service.status.value.copyWith(lastAt: DateTime(2026, 11, 21, 14, 32), received: 12, sent: 3);
      await shot('${name}_done');

      // узкий телефон: 320 точек
      tester.view.physicalSize = const Size(320, 700);
      await moving('${name}_receive_320', const SyncProgress(SyncStage.receive, done: 1214, total: 3873, bytesDone: 211 * mb, bytesTotal: 633 * mb, file: 'Конспекты/Физика/Лекция 12. Электромагнитная индукция.md'));
      service.track(null);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
