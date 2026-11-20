import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/note_blocks.dart';
import 'package:stowa/features/item/note_body.dart';

import '../../helpers/test_app.dart';

// хозяин 20.11 со снимка ленты: «добавить поддержку callout разных видов, сейчас это просто код»
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> show(WidgetTester tester, String body, {ValueChanged<int>? onToggle}) async {
    await tester.pumpWidget(
      world.wrap(SingleChildScrollView(child: NoteBody(blocks: parseNoteBlocks(body), onToggle: onToggle ?? (_) {}, onEdit: () {}, onLink: (_) {}))),
    );
    await tester.pump();
  }

  testWidgets('выноска — цветной блок со значком вида и заголовком, текст внутри разметкой, без «[!abstract]»', (tester) async {
    await show(tester, '> [!abstract] Описание\n> Добро пожаловать в Рапгар\n> - город торговцев');
    expect(find.textContaining('[!abstract]'), findsNothing);
    final callout = find.byKey(const ValueKey('callout-abstract'));
    expect(callout, findsOneWidget);
    expect(find.descendant(of: callout, matching: find.text('Описание')), findsOneWidget);
    expect(find.descendant(of: callout, matching: find.text('Добро пожаловать в Рапгар')), findsOneWidget);
    expect(find.descendant(of: callout, matching: find.text('город торговцев')), findsOneWidget);
    // у разных видов разный цвет подложки
    await show(tester, '> [!warning] Осторожно\n> горячо');
    final warning = tester.widget<Container>(find.byKey(const ValueKey('callout-warning')));
    await show(tester, '> [!success] Готово\n> всё');
    final success = tester.widget<Container>(find.byKey(const ValueKey('callout-success')));
    expect((warning.decoration as BoxDecoration).color, isNot((success.decoration as BoxDecoration).color));
  });

  testWidgets('«-» — свёрнута: виден заголовок, касание раскрывает текст и сворачивает обратно', (tester) async {
    await show(tester, '> [!faq]- Как проехать?\n> Автобусом 22');
    expect(find.text('Как проехать?'), findsOneWidget);
    expect(find.text('Автобусом 22'), findsNothing);
    await tester.tap(find.text('Как проехать?'));
    await tester.pumpAndSettle();
    expect(find.text('Автобусом 22'), findsOneWidget);
    await tester.tap(find.text('Как проехать?'));
    await tester.pumpAndSettle();
    expect(find.text('Автобусом 22'), findsNothing);
  });

  testWidgets('галочка в выноске отмечает свою строку всего текста', (tester) async {
    int? toggled;
    await show(tester, 'Дела\n\n> [!todo] На неделю\n> - [ ] позвонить', onToggle: (line) => toggled = line);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('callout-todo')), matching: find.byType(InkWell)).last);
    await tester.pump();
    expect(toggled, 3);
  });
}
