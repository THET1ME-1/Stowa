// Кадры карусели напоминаний с настоящими шрифтами: в покое и посреди прокрутки.
// Запуск: TMPDIR=~/.cache/flutter-tmp flutter test tool/preview/reminder_preview_test.dart
// Картинки ложатся в build/previews/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';

import '../../test/helpers/test_app.dart';

final _out = Directory('build/previews');

Future<void> _loadFonts() async {
  for (final family in ['Onest', 'Unbounded', 'StowaSymbols', 'StowaSymbolsFilled']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    _out.createSync(recursive: true);
    File(p.join(_out.path, '$name.png')).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _remindAll(TestWorld world, List<(String, String, Duration)> reminders) async {
  for (final (id, title, later) in reminders) {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(
          id: id,
          kind: ItemKind.note,
          title: title,
          body: Value(title),
          sortState: const Value(SortState.sorted),
          reminderAt: Value(world.now.add(later)),
          createdAt: world.now.subtract(const Duration(hours: 2)),
          updatedAt: world.now.subtract(const Duration(hours: 2)),
        ));
  }
}

void main() {
  setUpAll(_loadFonts);

  for (final (name, reminders) in [
    ('reminders-0-одно', [('protein', 'Надо выпить протеин', const Duration(hours: 23))]),
    ('reminders-0-короткие', [('protein', 'Надо выпить протеин', const Duration(hours: 23)), ('gym', 'Зал, ноги', const Duration(hours: 34)), ('call', 'Позвонить маме', const Duration(days: 2))]),
  ]) {
    testWidgets(name, (tester) async {
      final world = TestWorld();
      addTearDown(world.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(392, 850);
      addTearDown(tester.view.reset);
      await _remindAll(world, reminders);
      await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: world.app()));
      await tester.pumpAndSettle();
      await _shot(tester, name);
    });
  }

  testWidgets('карусель напоминаний', (tester) async {
    final world = TestWorld();
    addTearDown(world.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(392, 850);
    addTearDown(tester.view.reset);
    final reminders = [
      ('shirt', 'Закинуть футболку в пакет с тканью', const Duration(hours: 1)),
      ('match', 'Футбольный матч Молдова Казахстан на арене Зимбру', const Duration(hours: 9)),
      ('dentist', 'Зубной, взять снимок', const Duration(days: 2)),
      ('mama', 'Позвонить маме', const Duration(days: 3)),
    ];
    for (final (id, title, later) in reminders) {
      await world.db.into(world.db.items).insert(ItemsCompanion.insert(
            id: id,
            kind: ItemKind.note,
            title: title,
            body: Value(title),
            sortState: const Value(SortState.sorted),
            reminderAt: Value(world.now.add(later)),
            createdAt: world.now.subtract(const Duration(hours: 2)),
            updatedAt: world.now.subtract(const Duration(hours: 2)),
          ));
    }
    await tester.pumpWidget(RepaintBoundary(key: const ValueKey('shot'), child: world.app()));
    await tester.pumpAndSettle();
    await _shot(tester, 'reminders-1-покой');

    final carousel = find.byType(CarouselView);
    // шаг карусели — ширина полоски, восьмая часть ряда
    final half = tester.getSize(carousel).width / 16;
    final gesture = await tester.startGesture(tester.getCenter(carousel));
    for (var step = 0; step < 10; step++) {
      await gesture.moveBy(Offset(-half / 10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _shot(tester, 'reminders-2-половина');
    for (var step = 0; step < 10; step++) {
      await gesture.moveBy(Offset(-half / 10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    await _shot(tester, 'reminders-3-следующая');
  });
}
