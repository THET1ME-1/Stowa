import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/app.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/sticker_geometry.dart';
import 'package:stowa/features/edge/sticker_host.dart';
import 'package:stowa/services/sticker_channel.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> note(String id, String title, String body) async {
    final at = world.now.subtract(const Duration(hours: 1));
    await world.db.into(world.db.items).insert(
      ItemsCompanion.insert(
        id: id,
        kind: ItemKind.note,
        title: title,
        body: Value(body),
        sortState: const Value(SortState.sorted),
        createdAt: at,
        updatedAt: at,
      ),
    );
  }

  // стикер справа от середины экрана 411 × 860
  const right = Rect.fromLTWH(160, 120, stickerWidth, 200);

  Future<FakeStickerChannel> open(WidgetTester tester, {Rect window = right, double? stickerHeight}) async {
    final channel = FakeStickerChannel(window: window, stickerHeight: stickerHeight);
    tester.view.physicalSize = window.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: world.overrides,
        child: StowaApp(locale: const Locale('ru'), lockable: false, home: StickerHost(noteId: 'list', channel: channel)),
      ),
    );
    await tester.pumpAndSettle();
    // окно встало по высоте содержимого — как сделал бы Kotlin
    tester.view.physicalSize = channel.window.size;
    await tester.pumpAndSettle();
    return channel;
  }

  /// Kotlin довёл окно до нового места: вид стикера — по размеру окна.
  Future<void> follow(WidgetTester tester, FakeStickerChannel channel) async {
    tester.view.physicalSize = channel.window.size;
    await tester.pumpAndSettle();
  }

  testWidgets('заголовок и пункты, галочка ставится прямо на стикере', (tester) async {
    await note('list', 'Купить', 'Купить\n- [ ] молоко\n- [ ] хлеб');
    await open(tester);
    expect(find.text('Купить'), findsOneWidget);
    expect(find.text('молоко'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sticker-check-1')));
    await tester.pumpAndSettle();
    final body = (await world.db.select(world.db.items).getSingle()).body;
    expect(body, 'Купить\n- [x] молоко\n- [ ] хлеб');
  });

  testWidgets('окно встаёт по высоте содержимого', (tester) async {
    await note('list', 'Купить', 'Купить\n- [ ] молоко');
    final channel = await open(tester);
    expect(channel.calls, contains('frame'));
    expect(channel.window.width, stickerWidth);
    expect(channel.window.height, isNot(200));
    expect(channel.window.topLeft, right.topLeft);
  });

  testWidgets('«—»: стикер справа сворачивается в круг в своём правом верхнем углу', (tester) async {
    await note('list', 'Купить', 'Купить\n- [ ] молоко\n- [ ] хлеб\n- [x] сыр');
    final channel = await open(tester);
    await tester.tap(find.byTooltip('Свернуть'));
    await tester.pumpAndSettle();
    expect(channel.calls, contains('morph'));
    expect(channel.window, Rect.fromLTWH(right.left + stickerWidth - circleSize, right.top, circleSize, circleSize));
    await follow(tester, channel);
    // в круге — сколько пунктов осталось
    expect(find.text('2'), findsOneWidget);
    expect(find.text('молоко'), findsNothing);
  });

  testWidgets('касание круга раскрывает стикер на том же месте', (tester) async {
    await note('list', 'Купить', 'Купить\n- [ ] молоко');
    final channel = await open(tester);
    final height = channel.window.height;
    await tester.tap(find.byTooltip('Свернуть'));
    await tester.pumpAndSettle();
    await follow(tester, channel);
    await tester.tap(find.byKey(const ValueKey('sticker-circle')));
    await tester.pumpAndSettle();
    expect(channel.window, Rect.fromLTWH(right.left, right.top, stickerWidth, height));
  });

  testWidgets('круг утащили вниз — раскрывается вверх и остаётся на экране', (tester) async {
    await note('list', 'Купить', 'Купить\n- [ ] молоко');
    final channel = await open(tester);
    final height = channel.window.height;
    await tester.tap(find.byTooltip('Свернуть'));
    await tester.pumpAndSettle();
    await follow(tester, channel);
    const bottom = Offset(8, 860 - stickerMargin - circleSize);
    channel.window = Rect.fromLTWH(bottom.dx, bottom.dy, circleSize, circleSize);
    channel.send(const StickerMoved(bottom));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sticker-circle')));
    await tester.pumpAndSettle();
    expect(channel.window.bottom, bottom.dy + circleSize);
    expect(channel.window.height, height);
  });

  testWidgets('поднятый после перезапуска свёрнутым раскрывается на прежнюю высоту', (tester) async {
    await note('list', 'Купить', 'Купить\n- [ ] молоко');
    const circle = Rect.fromLTWH(344, 120, circleSize, circleSize);
    final channel = await open(tester, window: circle, stickerHeight: 140);
    expect(find.byKey(const ValueKey('sticker-circle')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sticker-circle')));
    await tester.pumpAndSettle();
    expect(channel.window, const Rect.fromLTWH(160, 120, stickerWidth, 140));
  });

  testWidgets('«×» гасит стикер и снимает его', (tester) async {
    await note('list', 'Купить', 'Купить\n- [ ] молоко');
    final channel = await open(tester);
    await tester.tap(find.byTooltip('Снять стикер'));
    await tester.pump();
    expect(channel.calls, isNot(contains('remove')));
    await tester.pumpAndSettle();
    expect(channel.calls.last, 'remove');
  });

  testWidgets('заметку удалили — стикер снимается сам', (tester) async {
    await note('list', 'Купить', 'Купить\n- [ ] молоко');
    final channel = await open(tester);
    await world.db.delete(world.db.items).go();
    await tester.pumpAndSettle();
    expect(channel.calls, contains('remove'));
  });

  testWidgets('касание заголовка открывает заметку в Stowa', (tester) async {
    await note('list', 'Купить', 'Купить\n- [ ] молоко');
    final channel = await open(tester);
    await tester.tap(find.text('Купить'));
    await tester.pumpAndSettle();
    expect(channel.calls, contains('openApp:list'));
  });
}
