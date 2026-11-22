// Сколько стоит одна буква в длинном тексте: разметка, вёрстка настоящим шрифтом и кадр поля ввода.
// Запуск: VAULT_COPY=~/Projects/College TMPDIR=~/.cache/flutter-tmp flutter test tool/typing_cost_test.dart
// Без VAULT_COPY текст собирается из образца с разметкой. Печатает только числа — содержимое
// заметок никуда не уходит. Вёрстку считает движок (C++), её цифры честные; кадр поля — в
// отладочном режиме с проверками, он завышен и годится только для сравнения длин между собой.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/item/markdown_controller.dart';

String _sample(int length) {
  final root = Platform.environment['VAULT_COPY'];
  final out = StringBuffer();
  if (root != null) {
    for (final file in Directory(root).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.md') || file.path.contains('/.obsidian/') || file.path.endsWith('.excalidraw.md')) continue;
      out.writeln(file.readAsStringSync());
      if (out.length >= length) break;
    }
  }
  while (out.length < length) {
    out.write('## Раздел\n- **жирный** пункт про [[Заметку]] и `код` с _курсивом_\nобычный абзац текста конспекта, где длинная мысль переносится на несколько строк экрана телефона.\n');
  }
  return out.toString().substring(0, length);
}

double _median(List<int> micros) {
  final sorted = [...micros]..sort();
  return sorted[sorted.length ~/ 2] / 1000;
}

void main() {
  setUpAll(() async {
    final bytes = File('assets/fonts/Onest.ttf').readAsBytesSync();
    await (FontLoader('Onest')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  const style = TextStyle(fontFamily: 'Onest', fontSize: 16, height: 1.45);
  // каждая буква — новый текст: кэш вёрстки движка не помогает, как при наборе
  const letters = 'абвгдежзиклмнопрстуф';

  for (final length in [1000, 2000, 5000, 10000, 25000, 80000]) {
    testWidgets('$length знаков', (tester) async {
      final base = _sample(length);
      final body = MarkdownController(text: base);
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (inner) {
        context = inner;
        return const SizedBox();
      })));
      final spans = <int>[], layouts = <int>[];
      var text = base;
      final middle = base.length ~/ 2;
      for (var step = 0; step < letters.length; step++) {
        text = '${text.substring(0, middle + step)}${letters[step]}${text.substring(middle + step)}';
        body.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: middle + step + 1));
        var watch = Stopwatch()..start();
        final span = body.buildTextSpan(context: context, style: style, withComposing: false);
        spans.add(watch.elapsedMicroseconds);
        final painter = TextPainter(text: span, textDirection: TextDirection.ltr);
        watch = Stopwatch()..start();
        painter.layout(maxWidth: 340);
        layouts.add(watch.elapsedMicroseconds);
        painter.dispose();
      }
      // ignore: avoid_print
      print('$length знаков: разметка ${_median(spans).toStringAsFixed(2)} мс, вёрстка ${_median(layouts).toStringAsFixed(2)} мс');
    });
  }
}
