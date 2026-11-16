import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/item_screen.dart';

import '../../helpers/test_app.dart';

// хозяин 16.11: «нет умного форматирования формул?» — «Сделай»
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> editing(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(id: 'a', kind: ItemKind.note, title: 'Физика', body: const Value('Физика\nСкорость'), createdAt: world.now, updatedAt: world.now),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const ItemScreen(id: 'a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Править'));
    await tester.pumpAndSettle();
  }

  /// Курсор в поле правки: текст с «|» на месте курсора.
  Future<void> put(WidgetTester tester, String marked) async {
    final caret = marked.indexOf('|');
    tester.testTextInput.updateEditingValue(TextEditingValue(text: marked.replaceFirst('|', ''), selection: TextSelection.collapsed(offset: caret)));
    await tester.pumpAndSettle();
  }

  String field(WidgetTester tester) {
    final value = tester.widget<TextField>(find.byType(TextField).last).controller!.value;
    return value.text.replaceRange(value.selection.baseOffset, value.selection.baseOffset, '|');
  }

  testWidgets('курсор в формуле — над строкой готовая формула; вышел — пропала', (tester) async {
    await editing(tester);
    await put(tester, 'Физика\nСкорость \$v = \\frac{s}{t|}\$');
    expect(find.byKey(const ValueKey('math-preview')), findsOneWidget);
    await put(tester, 'Физика\nСкорость \$v = \\frac{s}{t}\$ и всё|');
    expect(find.byKey(const ValueKey('math-preview')), findsNothing);
  });

  testWidgets('«Следующее поле» видно только в формуле и ведёт из числителя в знаменатель', (tester) async {
    await editing(tester);
    expect(find.byTooltip('Следующее поле формулы'), findsNothing);
    await put(tester, 'Физика\n\$\\frac{s|}{}\$');
    await tester.tap(find.byTooltip('Следующее поле формулы'));
    await tester.pump();
    expect(field(tester), 'Физика\n\$\\frac{s}{|}\$');
  });

  testWidgets('Tab в формуле — к следующему полю', (tester) async {
    await editing(tester);
    await put(tester, 'Физика\n\$\\frac{s|}{}\$');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(field(tester), 'Физика\n\$\\frac{s}{|}\$');
  });

  // хозяин 16.11: «написать 1+6=7, выделить и нажать $ — будет формула?»
  testWidgets('выделил 1+6=7 и набрал доллар — формула, выделение на месте', (tester) async {
    await editing(tester);
    const text = 'Физика\nПример 1+6=7';
    tester.testTextInput.updateEditingValue(const TextEditingValue(text: text, selection: TextSelection(baseOffset: 14, extentOffset: 19)));
    await tester.pump();
    tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'Физика\nПример \$', selection: TextSelection.collapsed(offset: 15)));
    await tester.pumpAndSettle();
    final controller = tester.widget<TextField>(find.byType(TextField).last).controller!;
    expect(controller.text, 'Физика\nПример \$1+6=7\$');
    expect(controller.selection.textInside(controller.text), '1+6=7');
  });

  testWidgets('кнопка «Формула» ставит пару с курсором внутри', (tester) async {
    await editing(tester);
    await put(tester, 'Физика\nСкорость |');
    await tester.tap(find.byTooltip('Формула'));
    await tester.pump();
    expect(field(tester), 'Физика\nСкорость \$|\$');
  });
}
