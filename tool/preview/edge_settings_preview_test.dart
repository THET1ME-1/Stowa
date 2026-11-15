// Кадры экрана «Под рукой» с настоящими шрифтами: тёмный графит, тёмная с цветом и светлая.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/edge_settings_preview_test.dart
// Картинки ложатся в build/previews/edge_*.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/core/theme/app_theme.dart';
import 'package:stowa/core/theme/palette.dart';
import 'package:stowa/core/theme/tokens.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/l10n/app_localizations.dart';
import 'package:stowa/domain/appearance.dart';
import 'package:stowa/domain/edge_settings.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/settings/edge_screen.dart';

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

  Future<TestWorld> world(WidgetTester tester, Appearance appearance, EdgeSettings settings) async {
    final world = TestWorld()
      ..appearance = appearance
      ..edgeSettings = settings;
    addTearDown(world.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(392, 1180);
    addTearDown(tester.view.reset);
    // закреплённые в цветных папках и одна без папки: корешки в цветах папок
    final folders = [('home', 'Дом', 'amber'), ('work', 'Работа', 'sky'), ('love', 'Личное', 'rose'), ('buy', 'Покупки', 'mint')];
    for (final (index, (id, name, color)) in folders.indexed) {
      await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: id, name: name, icon: 'folder', shape: 'squircle', color: Value(color), sortOrder: Value(index)));
    }
    final notes = [('Пароль от Wi‑Fi', 'home', 40), ('Дела на неделю', 'work', 420), ('Купить', 'buy', 160), ('Мысли', 'love', 600), ('Ссылки', null, 90)];
    for (final (index, (title, folder, length)) in notes.indexed) {
      await world.db.into(world.db.items).insert(ItemsCompanion.insert(
            id: 'n$index',
            kind: ItemKind.note,
            title: title,
            body: Value(title + 'x' * length),
            folderId: Value(folder),
            pinnedAt: Value(world.now.subtract(Duration(minutes: index))),
            createdAt: world.now,
            updatedAt: world.now,
          ));
    }
    return world;
  }

  final cases = <(String, Appearance, EdgeSettings)>[
    ('edge_dark', const Appearance(), const EdgeSettings(enabled: true)),
    ('edge_dark_color', const Appearance(seed: 0xFF5FCDF5), const EdgeSettings(enabled: true, height: 12, size: SpineSize.large)),
    ('edge_light', const Appearance(choice: ThemeChoice.light), const EdgeSettings(enabled: true, side: EdgeSide.left, height: 80, size: SpineSize.thin, alpha: 60)),
    ('edge_off', const Appearance(), const EdgeSettings()),
  ];
  for (final (name, appearance, settings) in cases) {
    testWidgets(name, (tester) async {
      final test = await world(tester, appearance, settings);
      // палитра — как у приложения: светлая и тёмная, графит или от цвета
      final palette = paletteFor(appearance, appearance.choice == ThemeChoice.light ? Brightness.light : Brightness.dark);
      Tokens.use(palette);
      addTearDown(() => Tokens.use(StowaPalette.graphiteDark));
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('shot'),
          child: ProviderScope(
            overrides: test.overrides,
            child: MaterialApp(
              theme: buildAppTheme(palette),
              locale: const Locale('ru'),
              localizationsDelegates: L.localizationsDelegates,
              supportedLocales: L.supportedLocales,
              home: const EdgeScreen(),
            ),
          ),
        ),
      );
      await _shot(tester, name);
      expect(tester.takeException(), isNull);
    });
  }
}
