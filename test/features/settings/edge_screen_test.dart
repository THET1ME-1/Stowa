import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/edge_settings.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/settings/edge_preview.dart';
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

  testWidgets('корешки на картинке тянут пальцем вниз — они ниже, подпись это говорит', (tester) async {
    world.edgeSettings = const EdgeSettings(enabled: true, height: 50);
    await open(tester);
    expect(find.text('посередине'), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('edge-preview')), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(world.edgeSettings.height, greaterThan(66));
    expect(find.text('ниже'), findsOneWidget);
    // правка одна, по отпусканию пальца: корешки не дёргаются на каждый пиксель
    expect(world.edge.calls.where((call) => call == 'apply'), hasLength(1));
  });

  testWidgets('размер — три кнопки с корешками, выбранный подписан', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('edge-size-large')));
    await tester.pumpAndSettle();
    expect(world.edgeSettings.size, SpineSize.large);
    expect(find.text('Крупные'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('edge-size-thin')));
    await tester.pumpAndSettle();
    expect(world.edgeSettings.size, SpineSize.thin);
  });

  testWidgets('узкий телефон 320 точек и крупный шрифт — экран ничем не переполнен', (tester) async {
    world.edgeSettings = const EdgeSettings(enabled: true, size: SpineSize.large);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.wrap(const EdgeScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('edge-alpha')), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('заметность — ползунок с процентами', (tester) async {
    await open(tester);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('edge-alpha')), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.drag(find.descendant(of: find.byKey(const ValueKey('edge-alpha')), matching: find.byType(Slider)), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(world.edgeSettings.alpha, 40);
    expect(find.text('40 %'), findsOneWidget);
  });

  // 21.11 хозяин: «при нажатии на процент видимости открывается M3 калькулятор, чтобы вписать своё число»
  testWidgets('касание процента — калькулятор, вписанное число встаёт заметностью', (tester) async {
    world.edgeSettings = const EdgeSettings(enabled: true, alpha: 86);
    await open(tester);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('edge-alpha')), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('86 %'));
    await tester.pumpAndSettle();
    final pad = find.byKey(const ValueKey('number-pad'));
    expect(pad, findsOneWidget);
    expect(find.descendant(of: pad, matching: find.text('Заметность')), findsOneWidget);
    expect(find.descendant(of: pad, matching: find.text('От 40 до 100 %')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pad-7')));
    await tester.tap(find.byKey(const ValueKey('pad-5')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pad-done')));
    await tester.pumpAndSettle();
    expect(pad, findsNothing);
    expect(world.edgeSettings.alpha, 75);
    expect(find.text('75 %'), findsOneWidget);
  });

  testWidgets('на картинке столько корешков, сколько закреплённых заметок', (tester) async {
    for (final (index, title) in ['Пароль', 'Купить', 'Дела'].indexed) {
      await world.db.into(world.db.items).insert(ItemsCompanion.insert(
            id: 'n$index',
            kind: ItemKind.note,
            title: title,
            pinnedAt: Value(world.now),
            createdAt: world.now,
            updatedAt: world.now,
          ));
    }
    await open(tester);
    final preview = tester.widget<EdgePreview>(find.byType(EdgePreview));
    expect(preview.spines, hasLength(3));
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
