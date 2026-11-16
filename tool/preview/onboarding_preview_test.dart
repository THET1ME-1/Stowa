// Кадры знакомства: шаги над строкой, пояснения голых # и @, подсказки по месту; тёмная,
// светлая и 320 точек с крупным шрифтом.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/onboarding_preview_test.dart
// Картинки ложатся в build/previews/onboarding/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/hints_repository.dart';
import 'package:stowa/domain/appearance.dart';
import 'package:stowa/domain/hints.dart';
import 'package:stowa/domain/models.dart';

import '../../test/helpers/test_app.dart';

final _out = Directory('build/previews/onboarding');

void main() {
  setUpAll(() async {
    for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
      final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
      await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required HintsState hints,
    bool notes = true,
    bool folders = false,
    ThemeChoice theme = ThemeChoice.dark,
    Size size = const Size(392, 850),
    double scale = 1,
    Future<void> Function(TestWorld world)? act,
  }) async {
    final world = TestWorld()
      ..hints = HintsRepository.memory(hints)
      ..appearance = Appearance(choice: theme);
    addTearDown(world.dispose);
    final db = world.db;
    if (folders) {
      await db.into(db.folders).insert(FoldersCompanion.insert(id: 'f1', name: 'Покупки', icon: 'shopping_cart', shape: 'squircle'));
      await db.into(db.folders).insert(FoldersCompanion.insert(id: 'f2', name: 'Книги', icon: 'menu_book', shape: 'pill', sortOrder: const Value(1)));
    }
    if (notes) {
      for (final (i, title) in ['Купить молоко и хлеб', 'Посмотреть фильм Дюна 2', 'Идея: приложение для рецептов'].indexed) {
        await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'n$i', kind: ItemKind.note, title: title, body: Value(title), folderId: Value(folders && i == 0 ? 'f1' : null), createdAt: world.now, updatedAt: world.now,
        ));
      }
    }
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: world.app()));
    Future<void> wait() async {
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    await wait();
    if (act != null) {
      await act(world);
      await wait();
    }
    expect(tester.takeException(), isNull, reason: name);
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      _out.createSync(recursive: true);
      File('${_out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  for (final step in StartStep.values) {
    testWidgets('шаг ${step.name}', (tester) => shoot(tester, 'step_${step.index}_${step.name}', hints: HintsState(step: step), notes: step != StartStep.stow));
  }
  testWidgets('шаг светлая', (tester) => shoot(tester, 'step_light', hints: const HintsState(step: StartStep.folder), theme: ThemeChoice.light));
  testWidgets('шаг 320 крупный', (tester) => shoot(tester, 'step_320', hints: const HintsState(step: StartStep.tag), size: const Size(320, 640), scale: 1.3));

  Future<void> typeLine(WidgetTester tester, String text) async {
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 300));
  }

  final open = HintsState.finished.copyWith(closed: const {});
  testWidgets('голая решётка', (tester) => shoot(tester, 'explain_tag', hints: open, act: (_) => typeLine(tester, '#')));
  testWidgets('голая собака', (tester) => shoot(tester, 'explain_folder', hints: open, folders: true, act: (_) => typeLine(tester, '@')));
  testWidgets('команды', (tester) => shoot(tester, 'commands', hints: open, act: (_) => typeLine(tester, '/')));
  testWidgets('подсказка заметки', (tester) => shoot(tester, 'tip_note', hints: open, act: (_) => tester.tap(find.text('Купить молоко и хлеб').first)));
  testWidgets('подсказка долгого нажатия', (tester) => shoot(tester, 'tip_long_press', hints: open, act: (world) async {
    for (var i = 0; i < 3; i++) {
      await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'x$i', kind: ItemKind.note, title: 'Заметка $i', createdAt: world.now, updatedAt: world.now));
    }
  }));
  testWidgets('подсказка каталога', (tester) => shoot(tester, 'tip_catalog', hints: open, folders: true, act: (_) => tester.tap(find.byTooltip('Каталог'))));
  testWidgets('подсказка папки', (tester) => shoot(tester, 'tip_folder', hints: open, folders: true, act: (_) => tester.tap(find.text('Покупки').first)));
}
