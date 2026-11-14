import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/settings/settings_blocks.dart';

void main() {
  Future<void> row(WidgetTester tester, double width) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SettingsSwitchRow(icon: 'fullscreen', title: 'Прятать в полноэкранном видео', subtitle: 'Пояснение', value: true, onChanged: (_) {}),
          ),
        ),
      ),
    ),
  );

  testWidgets('в узкой полке «Под рукой» строка без значка: длинное слово заголовка не рвётся пополам', (tester) async {
    await row(tester, 280);
    expect(find.byType(SettingsIconChip), findsNothing);
  });

  testWidgets('на экране телефона значок на месте', (tester) async {
    await row(tester, 360);
    expect(find.byType(SettingsIconChip), findsOneWidget);
  });
}
