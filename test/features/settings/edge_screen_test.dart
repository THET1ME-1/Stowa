import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/edge_settings.dart';
import 'package:stowa/features/settings/edge_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const EdgeScreen()));
    await tester.pumpAndSettle();
  }

  Switch mainSwitch(WidgetTester tester) => tester.widget<Switch>(find.descendant(of: find.byKey(const ValueKey('edge-switch')), matching: find.byType(Switch)));

  testWidgets('жесты корешков: три переключателя, каждый пишется сразу и доходит до корешков', (tester) async {
    world.edgeSettings = const EdgeSettings(enabled: true);
    await open(tester);
    for (final key in ['edge-gesture-swipe', 'edge-gesture-hold', 'edge-gesture-double']) {
      // список ленивый: нижние строки строятся, когда до них докрутили
      await tester.scrollUntilVisible(find.byKey(ValueKey(key)), 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }
    expect(world.edgeSettings.swipeDownTypes, isFalse);
    expect(world.edgeSettings.holdRecords, isFalse);
    expect(world.edgeSettings.doubleTapLast, isTrue);
    expect(world.edge.calls.where((call) => call == 'apply'), hasLength(3));
  });

  testWidgets('включатель без права ведёт к праву и остаётся выключенным', (tester) async {
    world.edge.canDrawAnswer = false;
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('edge-switch')));
    await tester.pumpAndSettle();
    expect(world.edge.calls, ['canDraw', 'askDraw']);
    expect(mainSwitch(tester).value, isFalse);
  });

  testWidgets('включатель с правом: корешки включены и служба запущена', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('edge-switch')));
    await tester.pumpAndSettle();
    expect(world.edge.calls, ['canDraw', 'start']);
    expect(mainSwitch(tester).value, isTrue);
  });

  testWidgets('«Слева» при включённых — настройка записана и служба переставляет корешки', (tester) async {
    world.edgeSettings = const EdgeSettings(enabled: true);
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('edge-side-left')));
    await tester.pumpAndSettle();
    expect(world.edgeSettings.side, EdgeSide.left);
    expect(world.edge.calls, ['apply']);
  });

  testWidgets('ползунки высоты, размера и заметности пишут настройки и подписывают значение', (tester) async {
    await open(tester);
    expect(find.text('посередине'), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('edge-height')), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(world.edgeSettings.height, greaterThan(66));
    expect(find.text('ниже'), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('edge-size')), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(world.edgeSettings.size, SpineSize.large);
    expect(find.text('крупные'), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('edge-alpha')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(world.edgeSettings.alpha, 40);
    expect(find.text('40 %'), findsOneWidget);
  });

  testWidgets('в настройках строка «Под рукой» с итогом ведёт на экран', (tester) async {
    world.edgeSettings = const EdgeSettings(enabled: true, side: EdgeSide.left, size: SpineSize.large);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Под рукой'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Слева · крупные'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('settings-edge')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-edge')));
    await tester.pumpAndSettle();
    expect(find.byType(EdgeScreen), findsOneWidget);
  });
}
