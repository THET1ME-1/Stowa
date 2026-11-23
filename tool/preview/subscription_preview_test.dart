// Кадры подписки: верх настроек «Купить подписку» и «Подписка уже куплена», экран подписки в
// обоих состояниях. Настоящие шрифты, тёмная и светлая.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/subscription_preview_test.dart
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
import 'package:stowa/features/settings/settings_screen.dart';
import 'package:stowa/features/subscription/paywall_screen.dart';
import 'package:stowa/l10n/app_localizations.dart';
import 'package:stowa/services/billing/subscription.dart';
import 'package:stowa/services/sync/sync_crypto.dart';
import 'package:stowa/services/sync/sync_service.dart';

import '../../test/helpers/test_app.dart';

Future<void> _loadFonts() async {
  for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

void main() {
  setUpAll(_loadFonts);
  for (final (theme, choice) in [('dark', ThemeChoice.dark), ('light', ThemeChoice.light)]) {
    for (final owned in [false, true]) {
      testWidgets('подписка $theme ${owned ? 'куплена' : 'нет'}', (tester) async {
        final world = TestWorld();
        addTearDown(world.dispose);
        final account = owned
            ? {
                'email': 'anna@example.com',
                'active': true,
                'paid_until': DateTime.now().toUtc().add(const Duration(days: 40)).toIso8601String(),
                'source': 'lava',
                'plan': 'year',
                'auto_renew': true,
                'cancellable': true,
              }
            : {'email': 'anna@example.com', 'active': false};
        await world.syncAccount.write(SyncAccount(email: 'anna@example.com', token: 't', key: VaultKey.generate().bytes, vaultDb: 'stowa').toJson());
        await world.subscription.write(jsonEncode(Subscription.fromAccount(account).toJson()));
        world.syncHttp = MockClient((request) async {
          if (request.url.path == '/v1/account') return http.Response(jsonEncode(account), 200);
          if (request.url.path == '/v1/billing/plans') {
            return http.Response(jsonEncode({'lava': {'RUB': {'month': 299, 'quarter': 749, 'year': 1990}}}), 200);
          }
          return http.Response('', 404);
        });
        final palette = paletteFor(Appearance(choice: choice), choice == ThemeChoice.light ? Brightness.light : Brightness.dark);
        Tokens.use(palette);
        addTearDown(() => Tokens.use(StowaPalette.graphiteDark));
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        addTearDown(() => tester.pumpWidget(const SizedBox()));

        Future<void> shot(Widget home, Size size, String file) async {
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('shot'),
              child: ProviderScope(
                key: ValueKey(file),
                overrides: world.overrides,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildAppTheme(palette),
                  locale: const Locale('ru'),
                  localizationsDelegates: L.localizationsDelegates,
                  supportedLocales: L.supportedLocales,
                  home: home,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: file);
          final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            Directory('build/previews').createSync(recursive: true);
            File('build/previews/$file.png').writeAsBytesSync(png!.buffer.asUint8List());
          });
        }

        final state = owned ? 'owned' : 'buy';
        await shot(const SettingsScreen(), const Size(392, 850), 'subscription_${theme}_${state}_settings');
        await shot(const PaywallScreen(), const Size(392, 1400), 'subscription_${theme}_${state}_screen');
        await shot(const PaywallScreen(), const Size(320, 1300), 'subscription_${theme}_${state}_screen_320');
      });
    }
  }
}
