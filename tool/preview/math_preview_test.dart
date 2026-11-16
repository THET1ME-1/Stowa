// Кадры заметки с формулами LaTeX, тёмная и светлая тема, со шрифтами KaTeX из пакета.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/math_preview_test.dart
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
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/l10n/app_localizations.dart';

import '../../test/helpers/test_app.dart';

Future<void> _load(String family, List<File> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
    await _load(family, [File('assets/fonts/$family.ttf')]);
  }
  final mono = File('/usr/share/fonts/truetype/noto/NotoSansMono-Regular.ttf');
  if (mono.existsSync()) await _load('monospace', [mono]);
  // шрифты KaTeX пакет объявляет сам; в тестах их надо подгрузить руками
  final packages = Directory('${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev').listSync().whereType<Directory>().where((dir) => dir.path.contains('flutter_math_fork-')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final fonts = Directory('${packages.last.path}/lib/katex_fonts/fonts').listSync().whereType<File>().where((file) => file.path.endsWith('.ttf'));
  final byFamily = <String, List<File>>{};
  for (final file in fonts) {
    final name = file.uri.pathSegments.last.split('-').first;
    byFamily.putIfAbsent(name, () => []).add(file);
  }
  for (final MapEntry(key: family, value: files) in byFamily.entries) {
    await _load('packages/flutter_math_fork/$family', files);
  }
}

const _body = r'''Погрешности
Абсолютная погрешность $\Delta x = |x - x^*|$, относительная — $\delta = \frac{\Delta x}{|x|}$. Цена прибора $5 и $10 — это не формула.

$$
\Delta y^* = |y - y^*| \quad \text{где} \quad y^* = f(a_1, a_2, \dots, a_n)
$$

Для функции нескольких переменных:

$$\Delta y \approx \sum_{i=1}^{n} \left| \frac{\partial f}{\partial x_i} \right| \Delta x_i$$

$$
PDV = \sum (\text{длина кабеля} \times \text{задержка на 1 м}) + \text{пара адаптеров} + \text{повторители}
$$

$$
\begin{cases} x + y = 5 \\ x - y = 1 \end{cases} \Longrightarrow \sqrt{x^2 + y^2} \approx 4{,}47
$$

$$
\frac{a}{b
$$''';

void main() {
  setUpAll(_loadFonts);
  for (final (name, choice) in [('math_dark', ThemeChoice.dark), ('math_light', ThemeChoice.light)]) {
    testWidgets(name, (tester) async {
      final world = TestWorld();
      addTearDown(world.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(392, 1300);
      addTearDown(tester.view.reset);
      final palette = paletteFor(Appearance(choice: choice), choice == ThemeChoice.light ? Brightness.light : Brightness.dark);
      Tokens.use(palette);
      addTearDown(() => Tokens.use(StowaPalette.graphiteDark));
      await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Погрешности', body: const Value(_body), createdAt: world.now, updatedAt: world.now));
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
            home: const ItemScreen(id: 'a'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/previews').createSync(recursive: true);
        File('build/previews/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
      expect(tester.takeException(), isNull);
    });
  }
}
