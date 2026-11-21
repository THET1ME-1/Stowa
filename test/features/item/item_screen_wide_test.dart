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

  testWidgets('монитор, правка: «Готово» в верхней строке, под ней одна тонкая полоса разметки', (tester) async {
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Схема курсовой', body: const Value('Схема курсовой\nвведение'), createdAt: world.now, updatedAt: world.now),
    );
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!.open(const WsTab.item('n'));
    await tester.pumpAndSettle();
    final bar = find.byKey(const ValueKey('desk-bar'));
    await tester.tap(find.descendant(of: bar, matching: find.byTooltip('Править')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('edit-dock')), findsNothing, reason: 'телефонной панели правки нет');
    final done = find.descendant(of: bar, matching: find.text('Готово'));
    expect(tester.getRect(done).height, lessThanOrEqualTo(40));
    final strip = tester.getRect(find.byKey(const ValueKey('desk-edit-bar')));
    expect(strip.height, lessThanOrEqualTo(56));
    expect(strip.width, lessThanOrEqualTo(772));
    for (final tip in ['Жирный', 'Отменить', 'Фото']) {
      expect(find.descendant(of: find.byKey(const ValueKey('desk-edit-bar')), matching: find.byTooltip(tip)), findsOneWidget, reason: tip);
    }

    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desk-edit-bar')), findsNothing);
    expect(find.descendant(of: bar, matching: find.text('Дописать')), findsOneWidget);
  });

  // хозяин 20.11: «адаптив под сайт, а не как телефон». Страница заметки как в макете: крупный
  // заголовок, свойства таблицей (подпись слева, значение справа), черта и текст без карточки
  testWidgets('монитор: своё название крупно, свойства таблицей, текст без карточки', (tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'rem', name: 'Ремонт', icon: 'build', shape: 'gem'));
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Ремонт кухни', body: const Value('Замер стен\n3,2 × 2,6'), folderId: const Value('rem'), createdAt: world.now, updatedAt: world.now),
    );
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!.open(const WsTab.item('n'));
    await tester.pumpAndSettle();

    final page = find.byType(ItemScreen);
    final title = find.descendant(of: page, matching: find.text('Ремонт кухни'));
    expect(tester.widget<Text>(title).style!.fontSize, greaterThanOrEqualTo(30));
    expect(find.descendant(of: page, matching: find.textContaining('Замер стен', findRichText: true)), findsOneWidget);

    final props = find.byKey(const ValueKey('desk-props'));
    for (final label in ['Папка', 'Теги', 'Создана', 'Связи']) {
      expect(find.descendant(of: props, matching: find.text(label)), findsOneWidget, reason: label);
    }
    expect(find.descendant(of: props, matching: find.text('Ремонт')), findsOneWidget);
    expect(tester.getRect(props).top, greaterThan(tester.getRect(title).bottom), reason: 'свойства под заголовком');

    final body = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('item-body-card')));
    expect(body.decoration, isNull, reason: 'текст без карточки');
    expect(tester.getRect(find.byKey(const ValueKey('item-body-card'))).top, greaterThan(tester.getRect(props).bottom));

    // строка папки — щелчок переложить
    await tester.tap(find.descendant(of: props, matching: find.text('Ремонт')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desk-sheet')), findsOneWidget);
  });

  // 21.11 проход по сайту: заметка из графа, «Посмотреть потом», связанных открывалась
  // телефонным экраном поверх вкладки, а кнопки «назад» на мониторе нет — тупик
  testWidgets('монитор: openItem открывает заметку своей вкладкой, телефон — экраном', (tester) async {
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Схема курсовой', body: const Value('Схема курсовой'), createdAt: world.now, updatedAt: world.now),
    );
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    final shell = WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!;
    shell.open(const WsTab.later());
    await tester.pumpAndSettle();
    final inLater = tester.element(find.byKey(const ValueKey('tab-later:')));
    openItem(inLater, 'n').ignore();
    await tester.pumpAndSettle();
    expect(shell.workspace.focusedPane.activeTab?.key, 'item:n', reason: 'своя вкладка');

    tester.view.physicalSize = const Size(400, 900);
    await tester.pumpAndSettle();
    openItem(tester.element(find.byType(LineDock)), 'n').ignore();
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsOneWidget, reason: 'телефон — экраном');
  });

  // 21.11 хозяин со снимка: «на сайте все тексты — заголовок, хотя это текст. На телефоне верно».
  // Название из первой строки над текстом не показывается: строка остаётся текстом, как на телефоне
  testWidgets('монитор: название из первой строки — не заголовок, строка остаётся текстом', (tester) async {
    const first = 'Купить молоко и хлеб по дороге домой';
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: first, body: const Value('$first\nЗабрать посылку'), createdAt: world.now, updatedAt: world.now),
    );
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!.open(const WsTab.item('n'));
    await tester.pumpAndSettle();

    final page = find.byType(ItemScreen);
    expect(find.descendant(of: page, matching: find.text(first)), findsNothing, reason: 'крупного заголовка нет');
    final body = find.byKey(const ValueKey('item-body-card'));
    expect(find.descendant(of: body, matching: find.textContaining(first, findRichText: true)), findsOneWidget, reason: 'первая строка в тексте');
    expect(find.descendant(of: body, matching: find.textContaining('Забрать посылку', findRichText: true)), findsOneWidget);
    expect(find.byKey(const ValueKey('desk-props')), findsOneWidget);
    expect(find.text('Дописать текст…'), findsNothing);
  });

  testWidgets('монитор: заметка без текста — приглашение дописать, щелчок открывает правку', (tester) async {
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Купить молоко', body: const Value(''), createdAt: world.now, updatedAt: world.now),
    );
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!.open(const WsTab.item('n'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дописать текст…'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desk-edit-bar')), findsOneWidget);
  });

  testWidgets('широкий экран: панель заметки под шапкой, низ у общей строки, текст колонкой', (tester) async {
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'n', kind: ItemKind.note, title: 'Схема курсовой работы', body: const Value('Схема курсовой работы\nвведение и три главы'), createdAt: world.now, updatedAt: world.now),
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
