import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/composer/line_dock.dart';
import 'package:stowa/features/returns/return_screen.dart';
import 'package:stowa/features/workspace/workspace_model.dart';
import 'package:stowa/features/workspace/workspace_shell.dart';

import '../../helpers/test_app.dart';

// хозяин 20.11 со снимка папки на мониторе: «где адаптация под сайт, нафига мне дизайн приложения на сайте»
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<WorkspaceController> open(WidgetTester tester) async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'k', name: 'Курсы', icon: 'school', shape: 'gem'));
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'g', name: 'Года', icon: 'calendar_month', shape: 'gem', parentId: const Value('k')));
    for (final title in ['Основы программирования', 'История права']) {
      await world.db.into(world.db.items).insert(
        ItemsCompanion.insert(id: title, kind: ItemKind.note, title: title, body: Value('$title\nтемы'), folderId: const Value('k'), createdAt: world.now, updatedAt: world.now),
      );
    }
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    final shell = WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!;
    shell.open(const WsTab.folder('k'));
    await tester.pumpAndSettle();
    return shell;
  }

  testWidgets('монитор: шапка папки как в макете — имя, счёт, компактный переключатель и значки, без круглых кнопок', (tester) async {
    await open(tester);
    final header = find.byKey(const ValueKey('desk-folder-header'));
    expect(header, findsOneWidget);
    expect(find.descendant(of: header, matching: find.text('Курсы')), findsOneWidget);
    expect(find.descendant(of: header, matching: find.textContaining('2 заметки')), findsOneWidget);
    // переключатель видов — компактный, а не три кнопки во всю ширину
    final views = tester.getRect(find.byKey(const ValueKey('desk-views')));
    expect(views.height, lessThanOrEqualTo(40));
    expect(views.width, lessThan(420));
    for (final tip in ['Искать в папке', 'Порядок', 'Ещё']) {
      final button = tester.getRect(find.descendant(of: header, matching: find.byTooltip(tip)));
      expect(button.height, lessThanOrEqualTo(40), reason: tip);
    }
  });

  testWidgets('монитор: «Посмотреть потом» с крупным заголовком, как у папки, а не мелким телефонным', (tester) async {
    final shell = await open(tester);
    shell.open(const WsTab.later());
    await tester.pumpAndSettle();
    final title = tester.widget<Text>(find.descendant(of: find.byType(ReturnScreen), matching: find.text('Посмотреть потом')));
    expect(title.style!.fontSize, greaterThanOrEqualTo(28));
  });

  testWidgets('монитор: вложенная папка — небольшая метка, касание открывает её вкладкой', (tester) async {
    final shell = await open(tester);
    final chip = find.byKey(const ValueKey('desk-subfolder-g'));
    expect(tester.getRect(chip).height, lessThanOrEqualTo(36));
    expect(tester.getRect(chip).width, lessThan(300), reason: 'не пилюля во всю ширину');
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(shell.workspace.panes.expand((pane) => pane.tabs).map((tab) => tab.key), contains('folder:g'));
  });
}
