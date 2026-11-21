// Кадры тегов и правил с настоящими шрифтами: вкладки, лист правила, список условий, лист тега,
// на 360 и 320 точек. Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/tags_preview_test.dart
// Картинки ложатся в build/previews/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/rules_repository.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/tags/tags_screen.dart';
import 'package:stowa/services/capture_service.dart';

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

  Future<TestWorld> world(WidgetTester tester, double width) async {
    final world = TestWorld();
    addTearDown(world.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);
    for (final (id, name, icon) in [('study', 'Учёба', 'school'), ('film', 'Фильмы', 'movie'), ('food', 'Рецепты', 'restaurant')]) {
      await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: id, name: name, icon: icon, shape: 'pill'));
    }
    final tags = TagsRepository(world.db, clock: () => world.now);
    final capture = CaptureService(world.db, tags: tags, filesRoot: world.files, clock: () => world.now);
    for (final text in ['Конспект по сетям #учёба', 'Лабораторная №3 #учёба', 'Дюна, пересмотреть #кино', 'Борщ на скорую руку #рецепт', 'Купить фильтр для воды #покупки']) {
      await capture.capture(CaptureInput(text: text));
    }
    await tags.ensure('путешествия');
    await RulesRepository(world.db).save(condition: RuleConditionKind.hasTag, conditionValue: 'учёба', action: RuleActionKind.toFolder, actionValue: 'study');
    return world;
  }

  Future<void> open(WidgetTester tester, TestWorld test) async {
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: test.wrap(const TagsScreen())));
    await tester.pumpAndSettle();
  }

  for (final width in [360.0, 320.0]) {
    final w = width.toInt();

    testWidgets('$w: вкладка тегов и лист тега', (tester) async {
      final test = await world(tester, width);
      await open(tester, test);
      await _shot(tester, 'tags-$w-1-теги');
      await tester.tap(find.text('#учёба'));
      await _shot(tester, 'tags-$w-2-лист-тега');
    });

    testWidgets('$w: вкладка правил, лист правила, список условий', (tester) async {
      final test = await world(tester, width);
      await open(tester, test);
      await tester.tap(find.text('Правила'));
      await _shot(tester, 'tags-$w-3-правила');
      await tester.tap(find.text('Есть тег #учёба'));
      await _shot(tester, 'tags-$w-4-правило');
      await tester.tap(find.byKey(const ValueKey('rule-when')));
      await _shot(tester, 'tags-$w-5-условия');
      await tester.tap(find.text('Ссылка с сайта'));
      await tester.pumpAndSettle();
      await _shot(tester, 'tags-$w-6-сайт');
    });

    testWidgets('$w: новое правило пустым', (tester) async {
      final test = await world(tester, width);
      await open(tester, test);
      await tester.tap(find.text('Правила'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Новое правило'));
      await _shot(tester, 'tags-$w-7-новое');
    });
  }
}
