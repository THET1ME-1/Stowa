import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/note_blocks.dart';
import 'package:stowa/features/item/note_body.dart';

import '../../helpers/test_app.dart';

// хозяин 20.11: «почему таблица не отформатирована как таблица» — и на телефоне, и на сайте
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> show(WidgetTester tester, String body, {double width = 400}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(world.wrap(SingleChildScrollView(child: NoteBody(blocks: parseNoteBlocks(body), onToggle: (_) {}, onEdit: () {}, onLink: (_) {}))));
    await tester.pump();
  }

  const schedule = 'Расписание\n| День | Время | Кабинет |\n|---|:---:|---|\n| Пятница | 11:30–13:00 | 122/4 |\n| Пятница | 13:15–14:45 | 302 |';

  testWidgets('таблица — ячейками со шапкой, без черт и строки разделителя', (tester) async {
    await show(tester, schedule);
    final table = find.byKey(const ValueKey('note-table'));
    expect(table, findsOneWidget);
    expect(find.textContaining('|'), findsNothing);
    expect(find.textContaining('---'), findsNothing);
    for (final cell in ['День', 'Время', 'Кабинет', '11:30–13:00', '122/4', '302']) {
      expect(find.descendant(of: table, matching: find.text(cell)), findsOneWidget, reason: cell);
    }
    // ячейки одного столбца стоят друг под другом
    expect(tester.getRect(find.text('122/4')).left, closeTo(tester.getRect(find.text('302')).left, 1));
  });

  testWidgets('широкая таблица на узком экране не ломает страницу — листается вбок', (tester) async {
    await show(tester, '| ${List.generate(8, (i) => 'Столбец номер $i').join(' | ')} |\n|${List.filled(8, '---').join('|')}|\n| ${List.generate(8, (i) => 'значение $i').join(' | ')} |', width: 360);
    expect(tester.takeException(), isNull);
    expect(find.descendant(of: find.byKey(const ValueKey('note-table')), matching: find.byType(SingleChildScrollView)), findsOneWidget);
  });
}
