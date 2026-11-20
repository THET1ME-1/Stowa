import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/widgets/pressable.dart';

// хозяин 20.11 про сайт: «без одной плавной анимации, отклика и эффектов при наведении. НОЛЬ»
void main() {
  Widget host({required VoidCallback onTap}) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Pressable(
          onTap: onTap,
          radius: BorderRadius.circular(16),
          child: const SizedBox(key: ValueKey('box'), width: 200, height: 120, child: Text('Заметка')),
        ),
      ),
    ),
  );

  testWidgets('мышь над карточкой — рука вместо стрелки, карточка плавно приподнимается и уходит обратно', (tester) async {
    await tester.pumpWidget(host(onTap: () {}));
    final rest = tester.getRect(find.byKey(const ValueKey('box'))).top;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('box'))));
    await tester.pump();
    expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.click);
    // посередине движения карточка ещё в пути: подъём идёт плавно, а не скачком
    await tester.pump(const Duration(milliseconds: 60));
    final midway = tester.getRect(find.byKey(const ValueKey('box'))).top;
    expect(midway, lessThan(rest));
    await tester.pumpAndSettle();
    final lifted = tester.getRect(find.byKey(const ValueKey('box'))).top;
    expect(lifted, lessThan(midway));
    expect(rest - lifted, inInclusiveRange(1, 4));

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey('box'))).top, rest);
  });

  testWidgets('с клавиатуры: Tab доходит до карточки, Enter открывает', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(onTap: () => taps++));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(Focus.of(tester.element(find.byKey(const ValueKey('box')))).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('без обработчика нажатия — обычная стрелка и никакого подъёма', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: Pressable(child: SizedBox(key: ValueKey('box'), width: 200, height: 120)))),
    );
    final rest = tester.getRect(find.byKey(const ValueKey('box'))).top;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('box'))));
    await tester.pumpAndSettle();
    expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);
    expect(tester.getRect(find.byKey(const ValueKey('box'))).top, rest);
  });
}
