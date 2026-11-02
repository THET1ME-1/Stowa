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

  testWidgets('нажатие слегка сжимает и зовёт обработчик', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(Pressable(onTap: () => taps++, child: const SizedBox(width: 100, height: 60))));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump(const Duration(milliseconds: 150));
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    expect(scale, lessThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('без обработчика нажатие ничего не сжимает', (tester) async {
    await tester.pumpWidget(_wrap(const Pressable(child: SizedBox(width: 100, height: 60))));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await gesture.up();
  });
}
