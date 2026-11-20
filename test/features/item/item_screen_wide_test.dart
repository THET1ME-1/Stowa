import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_dock.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/features/workspace/workspace_model.dart';
import 'package:stowa/features/workspace/workspace_shell.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  testWidgets('монитор: вместо телефонной шапки и панели — тонкая строка: путь папки и значки с подсказками', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'dom', name: 'Дом', icon: 'home', shape: 'gem'));
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'rem', name: 'Ремонт', icon: 'build', shape: 'gem', parentId: const Value('dom')));
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Ремонт кухни', body: const Value('Ремонт кухни\nзамер 3,2 × 2,6'), folderId: const Value('rem'), createdAt: world.now, updatedAt: world.now),
    );
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    final shell = WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!;
    shell.open(const WsTab.item('n'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('item-folder-badge')), findsNothing, reason: 'телефонной пилюли папки нет');
    final bar = find.byKey(const ValueKey('desk-bar'));
    final screen = tester.getRect(find.byType(ItemScreen));
    expect(tester.getRect(bar).top - screen.top, lessThan(24));
    expect(tester.getRect(bar).height, lessThanOrEqualTo(48));
    // путь папки: родитель и сама папка
    expect(find.descendant(of: bar, matching: find.text('Дом')), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.text('Ремонт')), findsOneWidget);
    // действия — значками с подсказками, «Дописать» — небольшой кнопкой
    for (final tip in ['Напомнить', 'Добавить тег', 'Переложить в папку', 'Поделиться', 'Править', 'Ещё']) {
      expect(find.descendant(of: bar, matching: find.byTooltip(tip)), findsOneWidget, reason: tip);
    }
    final append = tester.getRect(find.descendant(of: bar, matching: find.text('Дописать')));
    expect(append.height, lessThanOrEqualTo(40));

    // путь ведёт в папку: открывается вкладка папки
    await tester.tap(find.descendant(of: bar, matching: find.text('Дом')));
    await tester.pumpAndSettle();
    expect(shell.workspace.panes.expand((pane) => pane.tabs).map((tab) => tab.key), contains('folder:dom'));
  });

  testWidgets('широкий экран: панель заметки под шапкой, низ у общей строки, текст колонкой', (tester) async {
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Схема курсовой работы', body: const Value('Схема курсовой работы'), createdAt: world.now, updatedAt: world.now),
    );
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    final line = find.byType(LineDock);
    WorkspaceScope.maybeOf(tester.element(line))!.open(const WsTab.item('n'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('view-dock')), findsNothing, reason: 'телефонной панели действий на мониторе нет');
    final bar = tester.getRect(find.byKey(const ValueKey('desk-bar')));
    final screen = tester.getRect(find.byType(ItemScreen));
    // строка действий — у верха окна и шириной с колонку текста
    expect(bar.top - screen.top, lessThan(24));
    expect(bar.width, lessThanOrEqualTo(772));
    // текст колонкой, строка ввода с ним не пересекается
    final body = tester.getRect(find.byKey(const ValueKey('item-body-card')));
    expect(body.width, lessThanOrEqualTo(760));
    final capsule = tester.getRect(find.descendant(of: line, matching: find.textContaining('Закинь')).first);
    expect(body.bottom, lessThan(capsule.top));
  });
}
