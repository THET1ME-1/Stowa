import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kladovka/app.dart';

void main() {
  testWidgets('приложение открывается по-русски на графите', (tester) async {
    await tester.pumpWidget(const KladovkaApp(locale: Locale('ru')));
    await tester.pumpAndSettle();
    expect(find.text('Кладовка'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.scaffoldBackgroundColor, const Color(0xFF141517));
  });

  testWidgets('непереведённый язык показывает английский, а не русский', (tester) async {
    await tester.pumpWidget(const KladovkaApp(locale: Locale('pl')));
    await tester.pumpAndSettle();
    expect(find.text('Folders'), findsWidgets);
  });
}
