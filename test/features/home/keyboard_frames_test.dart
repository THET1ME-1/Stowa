import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/json_canvas.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_dock.dart';
import 'package:stowa/features/folder/folder_cards.dart';
import 'package:stowa/features/folder/folder_screen.dart';
import 'package:stowa/features/home/folder_shelf.dart';
import 'package:stowa/features/home/note_timeline.dart';
import 'package:stowa/features/item/item_screen.dart';

import '../../helpers/test_app.dart';

/// Клавиатура выезжает кадр за кадром, и на каждом кадре меняется высота окна и отступ системной
/// полосы. Экраны со строкой ввода не должны от этого пересобираться: на телефоне вся главная
/// строилась заново каждый кадр, и выезд клавиатуры дёргался (хозяин 23.11, запись экрана рядом
/// с Telegram: «Дёргание да, 10 фпс да»). Замер записи — `tool/keyboard_motion.py`.
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  const navBar = 132.0;
  const keyboard = 835.0;

  Future<void> phone(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    tester.view.viewPadding = const FakeViewPadding(bottom: navBar);
    tester.view.padding = const FakeViewPadding(bottom: navBar);
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  Finder field() => find.descendant(of: find.byType(LineDock), matching: find.byType(TextField));

  /// Кадры выезда (или ухода) клавиатуры. Отдаёт, что из [heavy] строилось за это время.
  Future<Map<String, int>> slide(WidgetTester tester, Set<String> heavy, {required bool up}) async {
    final built = <String, int>{};
    debugOnRebuildDirtyWidget = (element, _) {
      final name = element.widget.runtimeType.toString();
      if (heavy.contains(name)) built.update(name, (count) => count + 1, ifAbsent: () => 1);
    };
    try {
      for (var frame = 1; frame <= 20; frame++) {
        final shown = Curves.easeOutCubic.transform(frame / 20);
        final inset = keyboard * (up ? shown : 1 - shown);
        // так считает движок: полоса снизу уходит под клавиатуру
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        tester.view.padding = FakeViewPadding(bottom: (navBar - inset).clamp(0, navBar));
        await tester.pump(const Duration(milliseconds: 8));
      }
    } finally {
      debugOnRebuildDirtyWidget = null;
    }
    return built;
  }

  /// Строку в фокус, клавиатура выезжает и уходит; строка едет за ней, остальное стоит.
  Future<void> typeAndHide(WidgetTester tester, Set<String> heavy) async {
    await tester.tap(field());
    await tester.pumpAndSettle();
    expect(await slide(tester, heavy, up: true), isEmpty);
    // строка доехала до клавиатуры
    final open = tester.getBottomLeft(field()).dy;
    expect(open, lessThan((2400 - keyboard) / 2.75));
    // «назад» на Android прячет клавиатуру, а фокус оставляет
    expect(await slide(tester, heavy, up: false), isEmpty);
    expect(tester.getBottomLeft(field()).dy, greaterThan(open + 200));
  }

  const line = {'LineDock', 'TextField', 'LinePanel'};

  testWidgets('главная: выезд клавиатуры не пересобирает ленту и строку', (tester) async {
    for (var index = 0; index < 12; index++) {
      final at = world.now.subtract(Duration(hours: index * 5));
      await world.db.into(world.db.items).insert(
        ItemsCompanion.insert(id: 'n$index', kind: ItemKind.note, title: 'Заметка $index', body: Value('Текст заметки $index'), sortState: const Value(SortState.sorted), createdAt: at, updatedAt: at),
      );
    }
    await phone(tester, world.app());
    expect(find.byType(NoteCard), findsWidgets);
    await typeAndHide(tester, {...line, '_Feed', 'NoteTimeline', 'NoteCard'});
  });

  testWidgets('папка: выезд клавиатуры не пересобирает экран папки и карточки', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'food', name: 'Рецепты', icon: 'restaurant', shape: 'cookie9'));
    for (final (index, title) in ['Борщ как у бабушки', 'Тарт с малиной', 'Плов в казане', 'Сырники'].indexed) {
      final at = world.now.subtract(Duration(minutes: 10 - index));
      await world.db.into(world.db.items).insert(
        ItemsCompanion.insert(id: 'r$index', kind: ItemKind.note, title: title, body: Value(title), folderId: const Value('food'), sortState: const Value(SortState.sorted), createdAt: at, updatedAt: at),
      );
    }
    await phone(tester, world.app());
    await tester.tap(find.descendant(of: find.byType(FolderPill), matching: find.text('Рецепты')));
    await tester.pumpAndSettle();
    expect(find.byType(FolderScreen), findsOneWidget);
    expect(find.byType(FolderItemCard), findsWidgets);
    await typeAndHide(tester, {...line, 'FolderScreen', 'FolderItemCard'});
  });

  testWidgets('холст-файл: выезд клавиатуры не пересобирает холст и его карточки', (tester) async {
    var doc = CanvasDoc.empty();
    for (var index = 0; index < 6; index++) {
      doc = doc.addText('карточка $index', x: index * 320, y: 0);
    }
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'c', kind: ItemKind.canvas, title: 'План', document: Value(doc.encode()), body: Value(doc.plainText()), createdAt: world.now, updatedAt: world.now),
    );
    await phone(tester, world.wrap(const ItemScreen(id: 'c')));
    expect(find.text('карточка 0'), findsOneWidget);
    await typeAndHide(tester, {...line, 'CanvasFileScreen', '_NodeView'});
  });
}
