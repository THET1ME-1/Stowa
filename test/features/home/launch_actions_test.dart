import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/services/launch_actions.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester, {String? initial}) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(launchChannel, (call) async => call.method == 'initial' ? initial : null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(launchChannel, null));
    await tester.pumpWidget(world.app());
    await tester.pump(const Duration(milliseconds: 600));
    // повторный показ клавиатуры идёт через 450 мс после фокуса
    await tester.pump(const Duration(seconds: 1));
  }

  bool lineFocused(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText).first).focusNode.hasFocus;

  testWidgets('касание строки виджета открывает приложение сразу в строке с клавиатурой', (tester) async {
    await open(tester, initial: 'compose');
    expect(lineFocused(tester), isTrue);
  });

  testWidgets('обычный запуск строку не трогает', (tester) async {
    await open(tester);
    expect(lineFocused(tester), isFalse);
  });

  testWidgets('касание пришло, пока приложение в фоне, — строка встаёт, когда оно выйдет вперёд', (tester) async {
    await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      launchChannel.name,
      launchChannel.codec.encodeMethodCall(const MethodCall('open', 'compose')),
      (_) {},
    );
    await tester.pump();
    expect(lineFocused(tester), isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(lineFocused(tester), isTrue);
  });

  testWidgets('виджет нажали, когда приложение уже открыто на другом экране, — возврат на главную в строку', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      launchChannel.name,
      launchChannel.codec.encodeMethodCall(const MethodCall('open', 'compose')),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(find.text('Разбор ИИ'), findsNothing);
    expect(lineFocused(tester), isTrue);
  });
}
