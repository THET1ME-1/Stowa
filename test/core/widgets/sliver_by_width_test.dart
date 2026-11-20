import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/widgets/sliver_by_width.dart';

// хозяин 20.11: «пролистывание главной и папок лагает в 30 фпс». SliverLayoutBuilder звал
// построитель на каждый кадр прокрутки: плитка заново раскладывала сотни карточек
void main() {
  Widget host(ValueChanged<double> onBuild, {double width = 800}) => MaterialApp(
    home: Center(
      child: SizedBox(
        width: width,
        height: 600,
        child: CustomScrollView(
          slivers: [
            SliverByWidth(
              builder: (context, extent) {
                onBuild(extent);
                return SliverList.builder(itemCount: 200, itemBuilder: (context, index) => SizedBox(height: 80, child: Text('Строка $index')));
              },
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('прокрутка не строит заново, смена ширины строит', (tester) async {
    final widths = <double>[];
    await tester.pumpWidget(host(widths.add));
    expect(widths, [800]);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Строка 0'), findsNothing, reason: 'прокрутилось');
    expect(widths, [800], reason: 'прокрутка без новой раскладки');

    await tester.pumpWidget(host(widths.add, width: 600));
    expect(widths.last, 600);
  });
}
