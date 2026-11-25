// Кадры экрана «Разбор ИИ» с выключателем и настоящими шрифтами, чтобы посмотреть глазами.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/ai_switch_preview_test.dart
// Картинки ложатся в build/previews/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/core/theme/palette.dart';
import 'package:stowa/core/theme/tokens.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/ai_providers.dart';
import 'package:stowa/features/settings/settings_screen.dart';

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
  tearDown(() => Tokens.use(StowaPalette.graphiteDark));

  // состояние → что сделать с настройками до показа
  final states = <String, Future<void> Function(SettingsRepository)>{
    'работает': (settings) async {
      await settings.saveKey('sk-ant-good');
      await settings.setProvider(anthropic, model: 'claude-sonnet-5-5');
    },
    'выключен': (settings) async {
      await settings.saveKey('sk-ant-good');
      await settings.setProvider(anthropic, model: 'claude-sonnet-5-5');
      await settings.setAiEnabled(false);
    },
    'пауза': (settings) async {
      await settings.saveKey('sk-ant-good');
      await settings.pause('payment');
    },
    'ключ-не-принят': (settings) async {
      await settings.saveKey('sk-ant-bad');
      await settings.pause('auth');
    },
    'без-ключа': (_) async {},
  };

  for (final MapEntry(key: name, value: prepare) in states.entries) {
    for (final light in [false, true]) {
      testWidgets('$name ${light ? 'светлая' : 'тёмная'}', (tester) async {
        // кадры лежат в tool/, а не в test/: анализатор не узнаёт в них тест
        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore());
        await prepare(settings);
        if (light) Tokens.use(StowaPalette.graphiteLight);
        final world = TestWorld()..settings = settings;
        addTearDown(world.dispose);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(392, 850);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: world.wrap(const AiScreen())));
        await tester.pumpAndSettle();
        await _shot(tester, 'ai-$name-${light ? 'светлая' : 'тёмная'}');
      });
    }
  }
}
