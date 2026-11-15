import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/drawing/drawing_screen.dart';
import 'package:stowa/features/drawing/excalidraw_painter.dart';
import 'package:stowa/features/item/item_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());
  final sample = File('test/fixtures/excalidraw/Схема.excalidraw.md').readAsStringSync();

  Future<void> open(WidgetTester tester, String document) async {
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'd', kind: ItemKind.drawing, title: 'Схема', body: const Value('Вход'), document: Value(document), createdAt: world.now, updatedAt: world.now),
    );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'd')));
    await tester.pumpAndSettle();
  }

  testWidgets('рисунок открывается своим экраном: лист с рисунком и подсказка про Obsidian', (tester) async {
    await open(tester, sample);
    expect(find.byType(DrawingScreen), findsOneWidget);
    expect(find.text('Рисунок · 2 подписи'), findsOneWidget);
    expect(find.text('Изменить рисунок можно в Obsidian'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is ExcalidrawPainter), findsOneWidget);
  });

  testWidgets('«Текст рисунка» показывает подписи, касание копирует', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await open(tester, sample);
    await tester.tap(find.byKey(const ValueKey('drawing-texts')));
    await tester.pumpAndSettle();
    expect(find.text('f(x) = x²\nвторая строка'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('drawing-text-1')));
    await tester.pumpAndSettle();
    expect(copied, 'f(x) = x²\nвторая строка');
    expect(find.text('Подпись скопирована'), findsOneWidget);
  });

  testWidgets('рисунок не прочитался — говорим об этом и показываем подписи', (tester) async {
    await open(tester, '---\nexcalidraw-plugin: parsed\n---\n# Excalidraw Data\n## Text Elements\nТолько текст ^abcdefgh\n\n%%\n## Drawing\n```compressed-json\nAAAA\n```\n%%');
    expect(find.text('Рисунок не прочитался, открой его в Obsidian'), findsOneWidget);
    expect(find.text('Только текст'), findsOneWidget);
  });
}
