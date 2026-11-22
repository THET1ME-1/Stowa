// Сколько стоит одна буква в длинном тексте: разметка, вёрстка настоящим шрифтом и кадр поля
// ввода — одного поля на весь текст и поля с окном (WindowedTextField).
// Запуск: VAULT_COPY=~/Projects/College TMPDIR=~/.cache/flutter-tmp flutter test tool/typing_cost_test.dart
// Без VAULT_COPY текст собирается из образца с разметкой. Печатает только числа — содержимое
// заметок никуда не уходит. Вёрстку считает движок (C++), её цифры честные; кадр поля — в
// отладочном режиме с проверками и семантикой, он завышен и годится только для сравнения
// между собой. 22.11.2026 на College: одно поле 18 / 18 / 52 / 389 мс на 1, 5, 25 и 80 тысяч
// знаков, окно 13 / 11 / 13 / 15 мс.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/widgets/windowed_text_field.dart';
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
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));
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

    for (final windowed in [false, true]) {
      testWidgets('$length знаков, кадр буквы: ${windowed ? 'поле с окном' : 'одно поле'}', (tester) async {
        tester.view.physicalSize = const Size(400, 880);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final base = _sample(length);
        final document = MarkdownController(text: base)..selection = TextSelection.collapsed(offset: base.length ~/ 2);
        final window = MarkdownController()..value = WindowedTextField.windowFor(document.value);
        final focus = FocusNode();
        final field = windowed
            ? WindowedTextField(document: document, window: window, pieceController: (text) => MarkdownController(text: text), focusNode: focus, style: style)
            : TextField(controller: document, focusNode: focus, maxLines: null, style: style);
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: field))));
        focus.requestFocus();
        await tester.pump();
        final live = windowed ? window : document;
        final frames = <int>[];
        for (var step = 0; step < letters.length; step++) {
          final value = live.value;
          final caret = value.selection.baseOffset;
          tester.testTextInput.updateEditingValue(TextEditingValue(text: value.text.replaceRange(caret, caret, letters[step]), selection: TextSelection.collapsed(offset: caret + 1)));
          final watch = Stopwatch()..start();
          await tester.pump(const Duration(milliseconds: 16));
          frames.add(watch.elapsedMicroseconds);
        }
        expect(document.text.length, base.length + letters.length);
        // ignore: avoid_print
        print('$length знаков, ${windowed ? 'поле с окном' : 'одно поле'}: кадр ${_median(frames).toStringAsFixed(1)} мс, живое поле ${live.text.length} знаков');
        await tester.pumpWidget(const SizedBox());
        document.dispose();
        window.dispose();
        focus.dispose();
      });
    }
  }
}
