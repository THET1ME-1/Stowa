import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/widgets/undo_snack.dart';
import 'package:stowa/features/composer/line_dock.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  testWidgets('на мониторе плашка — пилюля по центру над строкой, а не полоса во всю ширину', (tester) async {
    await open(tester, const Size(1600, 960));
    var undone = false;
    showUndo(ScaffoldMessenger.of(tester.element(find.byType(LineDock))), message: 'Разложил 1 похожую заметку', label: 'Отменить', onUndo: () => undone = true, overDock: true);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    final toast = tester.getRect(find.byKey(const ValueKey('desk-toast')));
    final line = tester.getRect(find.descendant(of: find.byType(LineDock), matching: find.textContaining('Закинь')).first);
    expect(toast.width, lessThan(560), reason: 'по тексту, а не во всю ширину окна');
    expect(toast.bottom, lessThan(line.top), reason: 'над строкой, не на ней');
    // строка стоит по центру своей колонки, колонка — вся ширина между доками
    expect((toast.center.dx - tester.getRect(find.byType(LineDock)).center.dx).abs(), lessThan(2), reason: 'по центру над строкой');

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(undone, isTrue);
    expect(find.byKey(const ValueKey('desk-toast')), findsNothing);
  });

  testWidgets('на мониторе плашка уходит сама, новая сменяет прежнюю', (tester) async {
    await open(tester, const Size(1600, 960));
    final messenger = ScaffoldMessenger.of(tester.element(find.byType(LineDock)));
    showNote(messenger, 'Скопировано');
    await tester.pump(const Duration(milliseconds: 300));
    showNote(messenger, 'Сохранено');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Скопировано'), findsNothing);
    expect(find.text('Сохранено'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Сохранено'), findsNothing);
  });

  testWidgets('на телефоне плашка как была', (tester) async {
    await open(tester, const Size(400, 900));
    showUndo(ScaffoldMessenger.of(tester.element(find.byType(LineDock))), message: 'Удалено', label: 'Отменить', onUndo: () {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const ValueKey('desk-toast')), findsNothing);
  });
}
