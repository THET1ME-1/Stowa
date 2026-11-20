import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/app_theme.dart';

// хозяин 20.11 про сайт: «уникальные приятные анимации, отклики и переходы экранов».
// На компьютере экран внутри вкладки сменяется общей осью: новый въезжает сбоку и
// проявляется, прежний уходит в другую сторону и гаснет. Без перелёта и без вспышек.
void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Center(child: Text('Stowa Sync'))))),
                child: const Text('Настройки'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Настройки'));
    await tester.pump();
  }

  double opacityOf(WidgetTester tester, Finder finder) {
    var opacity = 1.0;
    for (final fade in tester.widgetList<FadeTransition>(find.ancestor(of: finder, matching: find.byType(FadeTransition)))) {
      opacity *= fade.opacity.value;
    }
    return opacity;
  }

  testWidgets(
    'компьютер: новый экран въезжает сбоку и проявляется, прежний уходит и гаснет',
    variant: TargetPlatformVariant({TargetPlatform.linux, TargetPlatform.windows, TargetPlatform.macOS}),
    (tester) async {
      await open(tester);
      final end = tester.getCenter(find.text('Настройки'));

      await tester.pump(const Duration(milliseconds: 60));
      expect(opacityOf(tester, find.text('Настройки')), lessThan(1), reason: 'прежний гаснет');
      expect(tester.getCenter(find.text('Настройки')).dx, lessThan(end.dx), reason: 'прежний уходит влево');

      await tester.pump(const Duration(milliseconds: 160));
      final midway = tester.getCenter(find.text('Stowa Sync')).dx;
      final shown = opacityOf(tester, find.text('Stowa Sync'));
      expect(shown, inExclusiveRange(0, 1), reason: 'новый проявляется, а не появляется сразу');

      await tester.pumpAndSettle();
      final settled = tester.getCenter(find.text('Stowa Sync')).dx;
      expect(midway, greaterThan(settled), reason: 'въезжает справа');
      expect(midway - settled, lessThanOrEqualTo(30), reason: 'мягко, на несколько десятков точек, а не через весь экран');
      expect(opacityOf(tester, find.text('Stowa Sync')), 1);
    },
  );
}
