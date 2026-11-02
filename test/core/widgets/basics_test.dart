import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/shapes.dart';
import 'package:stowa/core/widgets/pressable.dart';
import 'package:stowa/core/widgets/shape_badge.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('значок обрезан своей формой и держит размер', (tester) async {
    await tester.pumpWidget(_wrap(const ShapeBadge(shape: BadgeShape.cookie9, size: 52, child: Icon(Icons.alarm))));
    expect(tester.getSize(find.byType(ShapeBadge)), const Size(52, 52));
    final clip = tester.widget<ClipPath>(find.byType(ClipPath));
    expect((clip.clipper! as BadgeShapeClipper).shape, BadgeShape.cookie9);
    expect(find.byIcon(Icons.alarm), findsOneWidget);
  });

  double scaleOf(WidgetTester tester) =>
      tester.widget<ScaleTransition>(find.descendant(of: find.byType(Pressable), matching: find.byType(ScaleTransition))).scale.value;

  testWidgets('касание даёт толчок: сжался и вернулся, обработчик позван', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(Pressable(pressedScale: 0.9, onTap: () => taps++, child: const SizedBox(width: 100, height: 60))));
    await tester.tap(find.byType(Pressable));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 104));
    expect(scaleOf(tester), closeTo(0.9, 0.01));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(scaleOf(tester), 1);
  });

  testWidgets('без обработчика касание ничего не сжимает', (tester) async {
    await tester.pumpWidget(_wrap(const Pressable(child: SizedBox(width: 100, height: 60))));
    await tester.tap(find.byType(Pressable));
    await tester.pump(const Duration(milliseconds: 100));
    expect(scaleOf(tester), 1);
  });
}
