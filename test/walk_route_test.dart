// Маршрут по главным экранам на тестовом стенде: тот же, что идёт в симуляторе iPhone.
// Сломанный искатель всплывает здесь за минуту, а не в прогоне на десять.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/walk.dart';
import 'helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(392, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  // две секунды кадрами, а не pumpAndSettle: лоток галереи без плагина крутит ожидание без конца
  Future<void> Function() waitOf(WidgetTester tester) => () async {
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
      };

  testWidgets('проход: каждый шаг маршрута выполняется', (tester) async {
    await open(tester);
    final steps = await walkScreens(tester, shot: (_) async {}, wait: waitOf(tester));

    expect(steps.length, greaterThanOrEqualTo(20));
    expect([for (final step in steps) if (step.error != null) '${step.name}: ${step.error}'], isEmpty);
  });

  testWidgets('проход: снимки названы по порядку', (tester) async {
    await open(tester);
    final shots = <String>[];
    await walkScreens(tester, shot: (name) async => shots.add(name), wait: waitOf(tester));

    expect(shots.toSet().length, shots.length);
    for (final (index, name) in shots.indexed) {
      expect(name, startsWith('${'${index + 1}'.padLeft(2, '0')}-'));
    }
  });
}
