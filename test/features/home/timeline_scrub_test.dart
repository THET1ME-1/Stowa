import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:stowa/core/theme/tokens.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/home/note_timeline.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  const inset = 150.0;
  const screen = Size(400, 800);
  // ось ленты: на ней держат палец
  const rail = Space.screen + 6;

  // двадцать заметок, по одной в день: лента длинная, дней много
  List<ItemCard> notes() => [
    for (var day = 0; day < 20; day++)
      ItemCard(
        id: 'n$day',
        title: 'Заметка $day',
        body: 'строка первая\nстрока вторая',
        kind: ItemKind.note,
        folderId: null,
        sortState: SortState.sorted,
        createdAt: world.now.subtract(Duration(days: day)),
      ),
  ];

  Future<ScrollController> open(WidgetTester tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      world.wrap(
        Scaffold(
          body: CustomScrollView(
            controller: scroll,
            slivers: [
              SliverToBoxAdapter(
                child: NoteTimeline(
                  items: notes(),
                  filesRoot: Directory.systemTemp,
                  now: world.now,
                  bottomInset: inset,
                  onOpen: (_) {},
                  onMove: (_) {},
                  onAct: (_) {},
                  onToggle: (_, _) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return scroll;
  }

  Finder scrubber() => find.byKey(const ValueKey('timeline-scrubber'));

  testWidgets('удержание на оси: лента становится полосой, палец ведёт её до самого старого дня и обратно', (tester) async {
    final scroll = await open(tester);
    final finger = await tester.startGesture(const Offset(rail, 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(scrubber(), findsOneWidget);

    // низ полосы — конец ленты, в плашке у пальца — самый старый день
    await finger.moveTo(const Offset(rail, 790));
    await tester.pump();
    expect(scroll.offset, scroll.position.maxScrollExtent);
    final oldest = DateFormat.MMMMd('ru').format(world.now.subtract(const Duration(days: 19)));
    expect(find.descendant(of: scrubber(), matching: find.textContaining(oldest)), findsOneWidget);

    // верх полосы — начало ленты, «Сегодня»
    await finger.moveTo(const Offset(rail, 0));
    await tester.pump();
    expect(scroll.offset, 0);
    expect(find.descendant(of: scrubber(), matching: find.textContaining('Сегодня')), findsOneWidget);

    await finger.up();
    await tester.pumpAndSettle();
    expect(scrubber(), findsNothing);
  });

  testWidgets('день под пальцем сменился — короткая отдача', (tester) async {
    final clicks = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') clicks.add(call.arguments as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await open(tester);
    final finger = await tester.startGesture(const Offset(rail, 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    clicks.clear();
    for (var y = 100.0; y <= 600; y += 25) {
      await finger.moveTo(Offset(rail, y));
      await tester.pump();
    }
    expect(clicks.where((type) => type == 'HapticFeedbackType.selectionClick').length, greaterThan(3));
    await finger.up();
    await tester.pumpAndSettle();
  });

  testWidgets('короткое касание и обычная прокрутка по оси полосу не включают', (tester) async {
    final scroll = await open(tester);
    await tester.tapAt(const Offset(rail, 300));
    await tester.pumpAndSettle();
    expect(scrubber(), findsNothing);

    await tester.dragFrom(const Offset(rail, 500), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(scrubber(), findsNothing);
    expect(scroll.offset, greaterThan(100));
  });
}
