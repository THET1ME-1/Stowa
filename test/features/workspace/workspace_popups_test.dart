import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/workspace/workspace_popups.dart';

void main() {
  late WorkspacePopups popups;
  final navigator = GlobalKey<NavigatorState>();

  Future<void> open(WidgetTester tester) async {
    popups = WorkspacePopups();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [popups.watch()],
        home: const Scaffold(body: Text('вкладка')),
      ),
    );
  }

  testWidgets('нижнее окно во вкладке открыто — общая строка ему уступает; закрыли — возвращается', (tester) async {
    await open(tester);
    expect(popups.covering.value, isFalse);
    showModalBottomSheet<void>(context: navigator.currentContext!, builder: (_) => const SizedBox(height: 200, child: Text('окно')));
    await tester.pumpAndSettle();
    expect(popups.covering.value, isTrue);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(popups.covering.value, isFalse);
  });

  testWidgets('обычный экран поверх вкладки строку не прячет', (tester) async {
    await open(tester);
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('заметка'))));
    await tester.pumpAndSettle();
    expect(popups.covering.value, isFalse);
  });

  testWidgets('диалог тоже окно поверх: строка уступает', (tester) async {
    await open(tester);
    showDialog<void>(context: navigator.currentContext!, builder: (_) => const AlertDialog(content: Text('вопрос')));
    await tester.pumpAndSettle();
    expect(popups.covering.value, isTrue);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(popups.covering.value, isFalse);
  });

  testWidgets('два окна друг за другом: строка возвращается, когда закрыты оба', (tester) async {
    await open(tester);
    showModalBottomSheet<void>(context: navigator.currentContext!, builder: (_) => const SizedBox(height: 200));
    await tester.pumpAndSettle();
    showDialog<void>(context: navigator.currentContext!, builder: (_) => const AlertDialog(content: Text('вопрос')));
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(popups.covering.value, isTrue);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(popups.covering.value, isFalse);
  });

  testWidgets('вкладку закрыли вместе с открытым окном — строка не остаётся спрятанной', (tester) async {
    await open(tester);
    showModalBottomSheet<void>(context: navigator.currentContext!, builder: (_) => const SizedBox(height: 200));
    await tester.pumpAndSettle();
    expect(popups.covering.value, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    popups.settle();
    expect(popups.covering.value, isFalse);
  });
}
