import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/edge_settings.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  // HyperOS убил Stowa вместе с корешками: открыли — они встают с первого раза, а не со второго
  testWidgets('корешки включены — открытие Stowa поднимает их сразу', (tester) async {
    world.edgeSettings = const EdgeSettings(enabled: true);
    await open(tester);
    expect(world.edge.calls, contains('start'));
  });

  testWidgets('корешки выключены — открытие Stowa их не трогает', (tester) async {
    await open(tester);
    expect(world.edge.calls, isNot(contains('start')));
  });
}
