import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/item_media.dart' show FileTile;
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/features/item/note_body.dart' show MissingImage;
import 'package:stowa/features/item/pdf_panel.dart';

import '../../helpers/test_app.dart';

// хозяин 22.11: «А у нас есть предосмотр и управление PDF из приложения, как в Obsidian?» —
// страницы, масштаб, «1 из 21» и меню прямо в заметке
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  /// PDF на [pages] страниц в хранилище по пути [relative]. Диск — настоящее время.
  Future<void> putPdf(WidgetTester tester, String relative, int pages) => tester.runAsync(() async {
    final document = pw.Document();
    for (var page = 1; page <= pages; page++) {
      document.addPage(pw.Page(build: (_) => pw.Text('Slide $page')));
    }
    final file = File(p.join(world.files.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(await document.save());
  });

  Future<void> open(WidgetTester tester, {required String body, required List<(String, String)> files}) async {
    await world.db.into(world.db.items).insert(ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Семинар', body: Value(body), createdAt: world.now, updatedAt: world.now));
    for (final (index, (path, mime)) in files.indexed) {
      await world.db.into(world.db.attachments).insert(AttachmentsCompanion.insert(id: 'f$index', itemId: 'a', path: path, mime: mime, size: 1000, position: Value(index)));
    }
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    // pumpAndSettle не годится: пока PDF открывается, крутится индикатор
    for (var step = 0; step < 6; step++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// PDFium открывает документ в своём потоке: настоящее время и кадры по очереди.
  Future<void> loaded(WidgetTester tester) async {
    for (var step = 0; step < 60 && find.textContaining('из ').evaluate().isEmpty; step++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// pdfrx закрывает документ с задержкой: просмотр убрать и дать таймеру дойти ещё в тесте —
  /// висящие таймеры тестовый мир проверяет раньше, чем завершающие шаги.
  Future<void> closeViewer(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  Future<void> frames(WidgetTester tester) async {
    for (var step = 0; step < 8; step++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('приложенный PDF — просмотр в заметке: страницы, «1 из 3», масштаб и меню', (tester) async {
    await putPdf(tester, 'Вложения/Лекция.pdf', 3);
    await open(tester, body: 'Семинар', files: [('Вложения/Лекция.pdf', 'application/pdf')]);
    expect(find.byType(PdfPanel), findsOneWidget);
    await loaded(tester);
    expect(find.text('из 3'), findsOneWidget);
    for (final tip in ['Страницы', 'Крупнее', 'Мельче', 'Страница', 'Ещё']) {
      expect(find.descendant(of: find.byType(PdfPanel), matching: find.byTooltip(tip)), findsOneWidget, reason: tip);
    }
    await tester.tap(find.descendant(of: find.byType(PdfPanel), matching: find.byTooltip('Ещё')));
    await frames(tester);
    expect(find.text('На весь экран'), findsOneWidget);
    expect(find.text('Открыть в программе'), findsOneWidget);
    await closeViewer(tester);
  });

  testWidgets('PDF, вставленный в текст, — просмотр на своём месте, а не «картинка не найдена»', (tester) async {
    await putPdf(tester, 'Вложения/Слайды.pdf', 2);
    await open(tester, body: 'Семинар\n\n![[Слайды.pdf]]\n\nконец', files: [('Вложения/Слайды.pdf', 'application/pdf')]);
    expect(find.byType(MissingImage), findsNothing);
    expect(find.byType(PdfPanel), findsOneWidget);
    await loaded(tester);
    expect(find.text('из 2'), findsOneWidget);
    await closeViewer(tester);
  });

  testWidgets('другой файл, вставленный в текст, — строкой файла', (tester) async {
    File(p.join(world.files.path, 'Вложения', 'смета.xlsx'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    await open(tester, body: 'Семинар\n\n![[смета.xlsx]]', files: [('Вложения/смета.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')]);
    expect(find.byType(MissingImage), findsNothing);
    expect(find.byType(FileTile), findsOneWidget);
  });
}
