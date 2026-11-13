import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/tokens.dart';
import 'package:stowa/core/widgets/sheet_options.dart';

void main() {
  Future<String?> open(WidgetTester tester, {String? selected}) async {
    String? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  answer = await showOptionsSheet<String>(
                    context,
                    title: 'Сдать кровь',
                    selected: selected,
                    options: const [
                      SheetChoice(value: 'open', title: 'Открыть', icon: 'open_in_new'),
                      SheetChoice(value: 'mon', title: 'Понедельник', mark: 'Пн'),
                      SheetChoice(value: 'delete', title: 'Удалить', icon: 'delete', danger: true),
                    ],
                  );
                },
                child: const Text('лист'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('лист'));
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('строки — отдельные блоки с круглым значком, крайние скруглены крупно', (tester) async {
    await open(tester);
    expect(find.text('Сдать кровь'), findsOneWidget);
    final rows = [for (final title in ['Открыть', 'Понедельник', 'Удалить']) tester.getRect(find.ancestor(of: find.text(title), matching: find.byType(SheetOption)))];
    // щель между блоками
    expect(rows[1].top - rows[0].bottom, closeTo(4, 0.5));
    expect(rows[2].top - rows[1].bottom, closeTo(4, 0.5));
    // в круге надпись, если значка по смыслу нет
    expect(find.text('Пн'), findsOneWidget);
    final first = tester.widget<SheetOption>(find.ancestor(of: find.text('Открыть'), matching: find.byType(SheetOption)));
    expect(first.radius, const BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(8)));
  });

  testWidgets('касание отдаёт значение и закрывает лист', (tester) async {
    String? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answer = await showOptionsSheet<String>(context, options: const [SheetChoice(value: 'open', title: 'Открыть', icon: 'open_in_new')]),
            child: const Text('лист'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('лист'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(answer, 'open');
    expect(find.text('Открыть'), findsNothing);
  });

  testWidgets('выбранное — с галочкой, опасное — красным', (tester) async {
    await open(tester, selected: 'mon');
    expect(find.descendant(of: find.ancestor(of: find.text('Понедельник'), matching: find.byType(SheetOption)), matching: find.byKey(const ValueKey('sheet-check'))), findsOneWidget);
    expect(find.byKey(const ValueKey('sheet-check')), findsOneWidget);
    expect(tester.widget<Text>(find.text('Удалить')).style!.color, Tokens.error);
  });
}
