import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_dock.dart';
import 'package:stowa/features/folder/canvas_view.dart';
import 'package:stowa/features/home/folder_shelf.dart' show FolderPill;
import 'package:stowa/features/item/item_screen.dart';

import '../helpers/test_app.dart';

/// Картинка 1×1, как её отдаёт браузер после «Копировать картинку».
List<XFile> _copied() => [
  XFile.fromData(base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='), name: 'image.png', mimeType: 'image/png'),
];

// хозяин 22.11: «скопировал картинку и хочу вставить сразу в холст через Ctrl+V — не работает.
// Даже в инпут не вставляется… в текст заметки она тоже не вставляется»
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> note(String body, {String? title}) => world.db.into(world.db.items).insert(
    ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: title ?? body, body: Value(body), createdAt: world.now, updatedAt: world.now),
  );

  Future<int> attachmentsOf(String id) async => (await (world.db.select(world.db.attachments)..where((a) => a.itemId.equals(id))).get()).length;

  testWidgets('в тексте заметки картинка встаёт туда, где курсор', (tester) async {
    await note('Плитка\nклей', title: 'Плитка');
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField).last);
    // курсор после «Плитка»
    field.controller!.selection = const TextSelection.collapsed(offset: 6);
    await world.paste(tester, _copied());
    expect(field.controller!.text, matches(RegExp(r'^Плитка\n!\[\[[^\]]+\.png\]\]\nклей$')));
    expect(await attachmentsOf('a'), 1);
  });

  testWidgets('заметка открыта, но не правится: картинка встаёт в конец текста', (tester) async {
    await note('Мысль');
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    await world.paste(tester, _copied());
    expect(find.textContaining(RegExp(r'Мысль\n!\[\[[^\]]+\.png\]\]')), findsOneWidget);
    expect(await attachmentsOf('a'), 1);
  });

  testWidgets('на холсте картинка встаёт карточкой, без строки', (tester) async {
    final db = world.db;
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'ideas', name: 'Идеи', icon: 'lightbulb', shape: 'pill'));
    await db.into(db.items).insert(
      ItemsCompanion.insert(id: 'i0', kind: ItemKind.note, title: 'Кухня', body: const Value('Кухня'), folderId: const Value('ideas'), sortState: const Value(SortState.sorted), createdAt: world.now, updatedAt: world.now),
    );
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(FolderPill), matching: find.text('Идеи')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Холст'));
    await tester.pumpAndSettle();
    // работают с холстом: коснулись пустого места
    await tester.tapAt(tester.getBottomRight(find.byType(CanvasView)) - const Offset(40, 160));
    await tester.pumpAndSettle();
    await world.paste(tester, _copied());
    final items = await db.select(db.items).get();
    final pasted = items.singleWhere((item) => item.id != 'i0');
    expect(pasted.folderId, 'ideas');
    // заметка-картинка: файл ложится к ней очередью следом, как при броске мышью
    expect(pasted.kind, ItemKind.image);
    final spots = await db.select(db.canvasPositions).get();
    expect(spots.map((spot) => spot.itemId), contains(pasted.id));
  });

  // хозяин 22.11: «А на андроид такая вставка с клавиатуры работает?» — Gboard вставляет
  // картинку из своего буфера через поле ввода (commitContent), без Ctrl+V
  testWidgets('Android: клавиатура вставила картинку в текст заметки — встала на место курсора', (tester) async {
    await note('Плитка\nклей', title: 'Плитка');
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField).last);
    field.controller!.selection = const TextSelection.collapsed(offset: 6);
    await world.fromKeyboard(tester, find.byType(TextField).last, _copied().single);
    expect(field.controller!.text, matches(RegExp(r'^Плитка\n!\[\[IMG-[\d-]+\.png\]\]\nклей$')));
    expect(await attachmentsOf('a'), 1);
  });

  testWidgets('Android: клавиатура вставила картинку в строку — вложение', (tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    final line = find.descendant(of: find.byType(LineDock).first, matching: find.byType(TextField)).first;
    await tester.tap(line);
    await tester.pumpAndSettle();
    await world.fromKeyboard(tester, line, _copied().single);
    expect(tester.state<LineDockState>(find.byType(LineDock).first).holdsMedia, isTrue);
  });

  testWidgets('на главной картинка ложится в строку вложением', (tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await world.paste(tester, _copied());
    expect(tester.state<LineDockState>(find.byType(LineDock).first).holdsMedia, isTrue);
  });
}
