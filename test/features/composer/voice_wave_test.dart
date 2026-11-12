import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/composer/voice_session.dart';
import 'package:stowa/features/composer/voice_wave.dart';

void main() {
  // громкость растёт слева направо: самая свежая палочка — самая высокая
  final levels = [for (var bar = 0; bar < waveBars; bar++) (bar + 1) / waveBars];

  Future<void> pumpWave(WidgetTester tester, double width) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(width: width, child: VoiceWave(levels: levels)),
      ),
    ),
  );

  testWidgets('волна записи: в узкой строке остаются свежие палочки, а не старые', (tester) async {
    // на iPhone шириной 402 волне достаётся около 90 точек: палочка с отступом — 6
    await pumpWave(tester, 90);
    expect(tester.takeException(), isNull);
    final bars = find.byType(AnimatedContainer);
    expect(bars, findsNWidgets(15));
    expect(tester.getSize(bars.last).height, 30);
  });

  testWidgets('волна записи: в широкой строке видны все палочки', (tester) async {
    await pumpWave(tester, 400);
    expect(tester.takeException(), isNull);
    expect(find.byType(AnimatedContainer), findsNWidgets(waveBars));
  });
}
