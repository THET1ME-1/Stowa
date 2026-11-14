import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/features/settings/import_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester, {Size size = const Size(400, 800), double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(world.wrap(const ImportScreen()));
    await tester.pumpAndSettle();
  }

  // перенос читает диск и пишет базу: настоящее время, кадры между
  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 40; round++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump();
    }
  }

  testWidgets('пять источников и подсказка', (tester) async {
    await open(tester);
    for (final title in ['Из Telegram', 'Из Google Keep', 'Закладки браузера', 'Из Obsidian', 'Из mymind']) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('Google Keep: папка Takeout — заметки и итог плашкой', (tester) async {
    final keep = Directory(p.join(world.files.path, 'Takeout', 'Keep'))..createSync(recursive: true);
    File(p.join(keep.path, 'Борщ.json')).writeAsStringSync(jsonEncode({'title': 'Борщ', 'textContent': 'свёкла', 'createdTimestampUsec': 1683885600000000}));
    world.pickedFolder = keep.parent.path;
    await open(tester);
    await tester.tap(find.text('Из Google Keep'));
    await settle(tester);
    expect(find.text('Перенёс 1 заметку'), findsOneWidget);
    final items = await tester.runAsync(() => world.db.select(world.db.items).get()) ?? <Item>[];
    expect(items.single.title, 'Борщ');
  });

  testWidgets('Google Keep: в папке нет его заметок — так и сказано', (tester) async {
    world.pickedFolder = world.files.path;
    await open(tester);
    await tester.tap(find.text('Из Google Keep'));
    await settle(tester);
    expect(find.text('В этой папке нет заметок Google Keep: нужна папка Keep из Google Takeout'), findsOneWidget);
  });

  testWidgets('закладки — файлом .html', (tester) async {
    final file = File(p.join(world.files.path, 'bookmarks.html'))
      ..writeAsStringSync('<!DOCTYPE NETSCAPE-Bookmark-file-1><DL><p><DT><A HREF="https://eda.ru/borsch" ADD_DATE="1683885600">Борщ</A></DL>');
    world.pickedFile = file.path;
    await open(tester);
    await tester.tap(find.text('Закладки браузера'));
    await settle(tester);
    expect(find.text('Перенёс 1 заметку'), findsOneWidget);
  });

  testWidgets('320 точек и крупный шрифт: экран влезает', (tester) async {
    await open(tester, size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
