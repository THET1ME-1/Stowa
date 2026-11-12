// Проход по главным экранам настоящего приложения в симуляторе iPhone.
// Собирается как точка входа: flutter build ios --simulator --debug --target=integration_test/walk_test.dart.
// Снимает экран не Flutter, а прогон (.github/workflows/ios.yml): так на снимке видны вырез,
// клавиатура и системные окна. Приложение кладёт запрос «<имя>.request» во временную папку
// и ждёт, пока прогон заберёт его и снимет экран.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stowa/main.dart' as app;

import 'walk.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // приложение рисует кадры само, как у человека, а не только по просьбе теста
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('проход по экранам', (tester) async {
    final folder = Directory('${Directory.systemTemp.path}/walk')..createSync(recursive: true);
    final lines = <String>[];
    void finish() => File('${folder.path}/result.txt').writeAsStringSync([...lines, 'done', ''].join('\n'));

    // две секунды настоящего времени: анимация кончилась, база и сеть ответили
    Future<void> wait() async {
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    // снимок симулятора иногда думает секунд двадцать: ждём полминуты
    final missed = <String>{};
    Future<void> shot(String name) async {
      final request = File('${folder.path}/$name.request')..writeAsStringSync('');
      for (var tick = 0; tick < 300 && request.existsSync(); tick++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (!request.existsSync()) return;
      request.deleteSync();
      missed.add(name);
    }

    try {
      await app.main();
      // главная готова, когда на ней встала строка ввода
      for (var tick = 0; tick < 240 && find.byType(TextField).evaluate().isEmpty; tick++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      if (find.byType(TextField).evaluate().isEmpty) throw StateError('главная не открылась за минуту');
      await wait();

      final steps = await walkScreens(tester, shot: shot, wait: wait, device: true);
      for (final step in steps) {
        final error = step.error ?? (missed.contains(step.name) ? 'снимок не сделан' : null);
        lines.add(error == null ? 'ok ${step.name}' : 'FAIL ${step.name}: ${error.split('\n').first}');
      }
    } catch (error) {
      lines.add('FAIL запуск: ${'$error'.split('\n').first}');
      await shot('00-запуск-не-удался');
    } finally {
      finish();
    }
  });
}
