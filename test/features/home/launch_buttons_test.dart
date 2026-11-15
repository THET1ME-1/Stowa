import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

/// Виджет iPhone умеет только открыть приложение ссылкой: строка, микрофон и камера
/// приходят главному окну через `stowa/launch` и выполняются его строкой.
void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  /// Приложение открыли кнопкой виджета [action].
  void launchedWith(WidgetTester tester, String action) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('stowa/launch'), (call) async {
      return call.method == 'initial' ? action : null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('stowa/launch'), null));
  }

  /// Плагин записи без телефона: доступ есть, вызовы пишутся.
  List<String> fakeRecorder(WidgetTester tester) {
    final calls = <String>[];
    const channel = MethodChannel('com.llfbandit.record/messages');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'create':
          final id = (call.arguments as Map)['recorderId'];
          tester.binding.defaultBinaryMessenger.setMockStreamHandler(
            EventChannel('com.llfbandit.record/events/$id'),
            MockStreamHandler.inline(onListen: (arguments, events) {}),
          );
          return null;
        case 'hasPermission':
          return true;
        case 'getAmplitude':
          return {'current': -40.0, 'max': -20.0};
        default:
          return null;
      }
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    return calls;
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    // запись идёт в папку на диске: поддельное время теста туда не дотягивается
    for (var frame = 0; frame < 10; frame++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('«Закинь что угодно» в виджете — Stowa открывается со строкой в фокусе', (tester) async {
    launchedWith(tester, 'compose');
    await open(tester);
    final fields = tester.widgetList<EditableText>(find.byType(EditableText));
    expect(fields.any((field) => field.focusNode.hasFocus), isTrue);
  });

  testWidgets('микрофон в виджете — запись начинается сразу', (tester) async {
    final recorder = fakeRecorder(tester);
    launchedWith(tester, 'voice');
    await open(tester);
    expect(recorder, contains('start'));
  });
}
