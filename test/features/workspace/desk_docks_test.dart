import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/composer/line_dock.dart';
import 'package:stowa/features/workspace/workspace_docks.dart';
import 'package:stowa/features/workspace/workspace_model.dart';
import 'package:stowa/features/workspace/workspace_shell.dart';

import '../../helpers/test_app.dart';

// хозяин 20.11: «думай над нормальным адаптивом сайта под сайт». На ноутбуке в 1100 точек
// два дока съедали две трети окна, заметке оставалось 400 точек. Как в макете: док,
// которому нет места, выезжает поверх по кнопке, а не сжимает середину
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<WorkspaceController> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    return WorkspaceScope.maybeOf(tester.element(find.byType(LineDock)))!;
  }

  bool shown(WidgetTester tester, Type dock) => find.byType(dock).hitTestable().evaluate().isNotEmpty;

  testWidgets('ноутбук 1100: середине не меньше 620 точек, правый док выезжает поверх по кнопке', (tester) async {
    await open(tester, const Size(1100, 800));
    final center = tester.getRect(find.byKey(const ValueKey('tab-home:')));
    expect(center.width, greaterThanOrEqualTo(620));
    expect(shown(tester, RightDock), isFalse);

    await tester.tap(find.byTooltip('Правая панель'));
    await tester.pumpAndSettle();
    expect(shown(tester, RightDock), isTrue, reason: 'выехал поверх');
    expect(tester.getRect(find.byKey(const ValueKey('tab-home:'))).width, center.width, reason: 'середина не сжалась');

    // щелчок мимо — док уезжает
    await tester.tapAt(tester.getRect(find.byKey(const ValueKey('tab-home:'))).centerLeft + const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(shown(tester, RightDock), isFalse);
  });

  testWidgets('узкое окно 1000 и растянутый левый док: он выезжает поверх, а открытая из него вкладка его убирает', (tester) async {
    final shell = await open(tester, const Size(1000, 760));
    expect(shown(tester, LeftDock), isTrue, reason: 'обычной ширины помещается');
    shell.update((ws) => ws.leftWidth = 420);
    await tester.pumpAndSettle();
    expect(shown(tester, LeftDock), isFalse, reason: 'растянутый съел бы середину');
    await tester.tap(find.byTooltip('Левая панель'));
    await tester.pumpAndSettle();
    expect(shown(tester, LeftDock), isTrue);
    shell.open(const WsTab.later());
    await tester.pumpAndSettle();
    expect(shown(tester, LeftDock), isFalse, reason: 'выбрал раздел — док ушёл');
  });

  testWidgets('монитор 1600: оба дока на месте, кнопка прячет и показывает в строку', (tester) async {
    final shell = await open(tester, const Size(1600, 960));
    expect(shown(tester, LeftDock), isTrue);
    expect(shown(tester, RightDock), isTrue);
    await tester.tap(find.byTooltip('Правая панель'));
    await tester.pumpAndSettle();
    expect(shell.workspace.rightOpen, isFalse);
    expect(shown(tester, RightDock), isFalse);
  });
}
