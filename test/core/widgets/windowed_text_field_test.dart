import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/widgets/windowed_text_field.dart';
import 'package:stowa/features/composer/smart_punctuation.dart';

// тестировщик 22.11: длинный текст лагает — живое поле держит кусок у курсора, остальное неподвижно

const _style = TextStyle(fontSize: 16, height: 1.5);
const _decoration = InputDecoration(isCollapsed: true, contentPadding: EdgeInsets.zero, border: InputBorder.none);

// строки с номерами: каждая своя, переносится на экране в две
String _long(int lines) => List.generate(lines, (index) => 'строка $index и ещё слова, чтобы она переносилась по ширине поля на экране').join('\n');

class _Field {
  _Field(this.document, this.window, this.focus, this.undo);

  final TextEditingController document;
  final TextEditingController window;
  final FocusNode focus;
  final UndoHistoryController undo;
}

Future<_Field> _pump(WidgetTester tester, String text, {int? caret, List<TextInputFormatter>? formatters}) async {
  final document = TextEditingController(text: text)..selection = TextSelection.collapsed(offset: caret ?? text.length);
  final window = TextEditingController()..value = WindowedTextField.windowFor(document.value);
  final field = _Field(document, window, FocusNode(), UndoHistoryController());
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WindowedTextField(
            document: document,
            window: window,
            pieceController: (text) => TextEditingController(text: text),
            focusNode: field.focus,
            undoController: field.undo,
            inputFormatters: formatters,
            style: _style,
            decoration: _decoration,
          ),
        ),
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    document.dispose();
    window.dispose();
    field.focus.dispose();
    field.undo.dispose();
  });
  return field;
}

// все поля по порядку: неподвижные куски и живое; вместе — весь текст
List<EditableText> _fields(WidgetTester tester) => tester.widgetList<EditableText>(find.byType(EditableText)).toList();

String _composed(WidgetTester tester) => [for (final field in _fields(tester)) field.controller.text].join('\n');

EditableTextState _liveState(WidgetTester tester) => tester.state<EditableTextState>(find.byWidgetPredicate((widget) => widget is EditableText && !widget.readOnly));

Future<void> _type(WidgetTester tester, _Field field, TextEditingValue local) async {
  tester.testTextInput.updateEditingValue(local);
  await tester.pump();
  await tester.pump();
}

Future<void> _focus(WidgetTester tester, _Field field) async {
  field.focus.requestFocus();
  await tester.pump();
}

void main() {
  testWidgets('короткий текст — одно поле целиком, как обычное', (tester) async {
    final field = await _pump(tester, 'короткая заметка\nв две строки');
    expect(_fields(tester), hasLength(1));
    expect(field.window.text, 'короткая заметка\nв две строки');
  });

  testWidgets('длинный текст: живое поле держит кусок у курсора, остальное лежит неподвижно', (tester) async {
    final text = _long(300);
    final field = await _pump(tester, text, caret: text.length ~/ 2);
    expect(field.window.text.length, lessThan(WindowedTextField.windowLimit));
    expect(_fields(tester).length, greaterThan(3));
    expect(_composed(tester), text);
    // курсор в окне на своём месте
    final start = text.indexOf(field.window.text);
    expect(field.window.selection.baseOffset + start, text.length ~/ 2);
  });

  for (final (name, decoration) in [('без рамки', _decoration), ('collapsed', const InputDecoration.collapsed(hintText: null))]) {
    testWidgets('неподвижные куски ложатся строка в строку, как одно поле ($name)', (tester) async {
      final text = _long(300);
      final middle = text.length ~/ 2;
      // обычное поле с тем же текстом
      final plain = TextEditingController(text: text);
      addTearDown(plain.dispose);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TextField(controller: plain, maxLines: null, style: _style, decoration: decoration)))));
      final plainEditable = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
      final plainHeight = tester.getSize(find.byType(TextField)).height;
      Offset plainCaret(int offset) => plainEditable.localToGlobal(plainEditable.getLocalRectForCaret(TextPosition(offset: offset)).topLeft);
      final expected = [for (final offset in [middle, middle + 40, text.length]) plainCaret(offset)];

      final document = TextEditingController(text: text)..selection = TextSelection.collapsed(offset: middle);
      final window = TextEditingController()..value = WindowedTextField.windowFor(document.value);
      final focus = FocusNode();
      addTearDown(() {
        document.dispose();
        window.dispose();
        focus.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WindowedTextField(document: document, window: window, pieceController: (text) => TextEditingController(text: text), focusNode: focus, style: _style, decoration: decoration),
            ),
          ),
        ),
      );
      expect(_fields(tester).length, greaterThan(3));
      expect(tester.getSize(find.byType(WindowedTextField)).height, moreOrLessEquals(plainHeight));
      // место строк в окне и в последнем неподвижном куске то же, что у обычного поля
      final start = text.indexOf(window.text);
      final live = _liveState(tester).renderEditable;
      expect(live.localToGlobal(live.getLocalRectForCaret(TextPosition(offset: middle - start)).topLeft), offsetMoreOrLessEquals(expected[0]));
      expect(live.localToGlobal(live.getLocalRectForCaret(TextPosition(offset: middle + 40 - start)).topLeft), offsetMoreOrLessEquals(expected[1]));
      final last = tester.state<EditableTextState>(find.byType(EditableText).last).renderEditable;
      expect(last.localToGlobal(last.getLocalRectForCaret(TextPosition(offset: _fields(tester).last.controller.text.length)).topLeft), offsetMoreOrLessEquals(expected[2]));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('буква в окне ложится в весь текст на своё место', (tester) async {
    final text = _long(300);
    final field = await _pump(tester, text, caret: text.length ~/ 2);
    await _focus(tester, field);
    final local = field.window.value;
    final caret = local.selection.baseOffset;
    await _type(tester, field, TextEditingValue(text: local.text.replaceRange(caret, caret, 'Ж'), selection: TextSelection.collapsed(offset: caret + 1)));
    final middle = text.length ~/ 2;
    expect(field.document.text, text.replaceRange(middle, middle, 'Ж'));
    expect(field.document.selection, TextSelection.collapsed(offset: middle + 1));
    expect(_composed(tester), field.document.text);
  });

  testWidgets('курсор ушёл из среднего куска — окно переезжает к нему, текст прежний', (tester) async {
    final text = _long(300);
    final field = await _pump(tester, text, caret: text.length ~/ 2);
    await _focus(tester, field);
    final before = field.window.text;
    final start = text.indexOf(before);
    // курсор в начало окна: это соседний кусок сверху
    await _type(tester, field, field.window.value.copyWith(selection: const TextSelection.collapsed(offset: 0)));
    expect(field.window.text, isNot(before));
    expect(field.document.text, text);
    expect(field.document.selection, TextSelection.collapsed(offset: start));
    expect(_composed(tester), text);
    expect(text.indexOf(field.window.text) + field.window.selection.baseOffset, start);
  });

  testWidgets('окно разрослось от набора — на паузе снова сужается, текст на местах', (tester) async {
    final text = _long(300);
    final field = await _pump(tester, text, caret: text.length ~/ 2);
    await _focus(tester, field);
    // пишут без пауз: несколько тысяч знаков в одном месте
    final part = '${List.filled(30, 'новая строка набранного текста, ещё немного слов').join('\n')}\n';
    for (var round = 0; round < 6; round++) {
      final local = field.window.value;
      final at = local.selection.baseOffset;
      await _type(tester, field, TextEditingValue(text: local.text.replaceRange(at, at, part), selection: TextSelection.collapsed(offset: at + part.length)));
    }
    expect(field.window.text.length, greaterThan(WindowedTextField.windowLimit));
    final typed = field.document.text;
    expect(typed.length, text.length + part.length * 6);
    // пауза в наборе
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(field.window.text.length, lessThan(WindowedTextField.windowLimit));
    expect(field.document.text, typed);
    expect(_composed(tester), typed);
    // курсор там же, где кончилось набранное, и окно стоит вокруг него
    final caret = text.length ~/ 2 + part.length * 6;
    expect(field.document.selection, TextSelection.collapsed(offset: caret));
    final start = caret - field.window.selection.baseOffset;
    expect(typed.substring(start, start + field.window.text.length), field.window.text);
  });

  testWidgets('пока клавиатура собирает слово, окно не переезжает', (tester) async {
    final text = _long(300);
    final field = await _pump(tester, text, caret: text.length ~/ 2);
    await _focus(tester, field);
    final before = field.window.text;
    await _type(tester, field, TextEditingValue(text: 'сл${before.substring(0)}', selection: const TextSelection.collapsed(offset: 2), composing: const TextRange(start: 0, end: 2)));
    expect(field.window.text, startsWith('сл'));
    expect(field.window.text.length, before.length + 2);
    // слово собрано — теперь переезжает
    await _type(tester, field, field.window.value.copyWith(composing: TextRange.empty));
    expect(field.window.text.startsWith('сл') && field.window.text.length == before.length + 2, isFalse);
    expect(_composed(tester), field.document.text);
  });

  testWidgets('касание неподвижного куска ставит курсор под палец', (tester) async {
    final text = _long(300);
    final field = await _pump(tester, text, caret: 0);
    // последний кусок далеко внизу: прокручиваем к нему
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    // неподвижный кусок, чья десятая буква на экране
    late EditableText piece;
    late Offset at;
    for (final field in _fields(tester).where((field) => field.readOnly)) {
      final editable = tester.state<EditableTextState>(find.byWidget(field)).renderEditable;
      final box = editable.getBoxesForSelection(const TextSelection(baseOffset: 10, extentOffset: 11)).first;
      at = editable.localToGlobal(Offset(box.left + 1, (box.top + box.bottom) / 2));
      piece = field;
      if (at.dy > 100 && at.dy < 500) break;
    }
    final pieceStart = text.indexOf(piece.controller.text);
    await tester.tapAt(at);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(field.focus.hasFocus, isTrue);
    expect(field.document.selection, TextSelection.collapsed(offset: pieceStart + 10));
    expect(text.indexOf(field.window.text) + field.window.selection.baseOffset, pieceStart + 10);
    expect(_composed(tester), text);
  });

  group('неподвижный кусок под пальцем и мышью', () {
    // неподвижный кусок, чья первая строка посреди экрана, и середина её слова «строка»: у края
    // экрана поле довезло бы курсор в видимую часть, и под мышью оказалось бы другое слово
    Future<({int start, Offset at})> target(WidgetTester tester) async {
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      for (final piece in _fields(tester).where((field) => field.readOnly)) {
        final editable = tester.state<EditableTextState>(find.byWidget(piece)).renderEditable;
        final text = piece.controller.text;
        // строки куска с начала: каждая начинается словом «строка»
        for (var line = 0; line >= 0 && line < text.length; line = text.indexOf('\n', line) < 0 ? -1 : text.indexOf('\n', line) + 1) {
          final at = editable.localToGlobal(editable.getBoxesForSelection(TextSelection(baseOffset: line + 2, extentOffset: line + 3)).first.toRect().center);
          if (at.dy > 150 && at.dy < 450) return (start: _long(300).indexOf(text) + line, at: at);
        }
      }
      throw StateError('нет строки посреди экрана');
    }

    testWidgets('долгое нажатие выделяет слово', (tester) async {
      final text = _long(300);
      final field = await _pump(tester, text, caret: 0);
      final hit = await target(tester);
      await tester.longPressAt(hit.at);
      await tester.pump();
      await tester.pump();
      final word = field.document.selection;
      expect(text.substring(word.start, word.end), 'строка');
      expect(word.start, hit.start);
      expect(field.window.text, text);
      expect(field.focus.hasFocus, isTrue);
    });

    testWidgets('двойной щелчок мышью выделяет слово', (tester) async {
      final text = _long(300);
      final field = await _pump(tester, text, caret: 0);
      final hit = await target(tester);
      await tester.tapAt(hit.at, kind: PointerDeviceKind.mouse);
      // курсор у края экрана поле довозит в видимую часть; прокрутка в это время касаний не берёт
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tapAt(hit.at, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await tester.pump();
      final word = field.document.selection;
      expect(text.substring(word.start, word.end), 'строка');
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('протяжка мышью выделяет от точки до точки, через куски', (tester) async {
      final text = _long(300);
      final field = await _pump(tester, text, caret: 0);
      final hit = await target(tester);
      final gesture = await tester.startGesture(hit.at, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await tester.pump();
      await gesture.moveBy(const Offset(0, 160));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump();
      final selection = field.document.selection;
      expect(selection.isCollapsed, isFalse);
      expect(selection.baseOffset, inInclusiveRange(hit.start + 2, hit.start + 3));
      expect(selection.extentOffset, greaterThan(selection.baseOffset + 100));
      expect(field.window.text, text);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('правила набора в окне', () {
    final punctuation = [TextInputFormatter.withFunction(smartPunctuation)];

    Future<void> typeDashes(WidgetTester tester, _Field field) async {
      for (var letter = 0; letter < 2; letter++) {
        final local = field.window.value;
        final at = local.selection.baseOffset;
        await _type(tester, field, TextEditingValue(text: local.text.replaceRange(at, at, '-'), selection: TextSelection.collapsed(offset: at + 1)));
      }
    }

    testWidgets('в обычном тексте «--» становится тире', (tester) async {
      final text = _long(300);
      final caret = text.length ~/ 2;
      final field = await _pump(tester, text, caret: caret, formatters: punctuation);
      await _focus(tester, field);
      await typeDashes(tester, field);
      expect(field.document.text.substring(caret, caret + 1), '—');
    });

    testWidgets('посреди длинного листинга окно знает, что оно в коде: «--» остаётся', (tester) async {
      // внутри блока кусок режется по 2800 знаков: курсор посередине, и окно не видит ни одной ограды
      final code = ['```js', for (var index = 0; index < 600; index++) 'let value$index = $index; // строка кода', '```'].join('\n');
      final text = 'Лаба\n$code\nвывод';
      final caret = text.indexOf('let value300 ');
      final field = await _pump(tester, text, caret: caret, formatters: punctuation);
      await _focus(tester, field);
      expect(field.window.text, isNot(contains('```')));
      await typeDashes(tester, field);
      expect(field.document.text.substring(caret, caret + 2), '--');
      expect(_composed(tester), field.document.text);
    });
  });

  testWidgets('выделение шире курсора раскрывает окно на весь текст', (tester) async {
    final text = _long(300);
    final field = await _pump(tester, text, caret: text.length ~/ 2);
    await _focus(tester, field);
    final start = text.indexOf(field.window.text);
    await _type(tester, field, field.window.value.copyWith(selection: const TextSelection(baseOffset: 5, extentOffset: 30)));
    expect(field.window.text, text);
    expect(field.document.selection, TextSelection(baseOffset: start + 5, extentOffset: start + 30));
    expect(_fields(tester), hasLength(1));
    // выделение сняли и пишут дальше — окно снова сужается
    await _type(tester, field, field.window.value.copyWith(selection: TextSelection.collapsed(offset: start + 30)));
    expect(_fields(tester).length, greaterThan(3));
    expect(_composed(tester), text);
  });

  testWidgets('«Выделить всё» из меню выделяет весь текст, а не окно', (tester) async {
    final text = _long(300);
    final field = await _pump(tester, text, caret: text.length ~/ 2);
    await _focus(tester, field);
    _liveState(tester).selectAll(SelectionChangedCause.toolbar);
    await tester.pump();
    await tester.pump();
    expect(field.document.selection, TextSelection(baseOffset: 0, extentOffset: text.length));
    expect(field.window.text, text);
  });

  testWidgets('Ctrl+A и Ctrl+End смотрят на весь текст', (tester) async {
    final text = _long(300);
    final field = await _pump(tester, text, caret: text.length ~/ 2);
    await _focus(tester, field);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump();
    expect(field.document.selection, TextSelection.collapsed(offset: text.length));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump();
    expect(field.document.selection, TextSelection(baseOffset: 0, extentOffset: text.length));
  });

  testWidgets('отмена и повтор — по всему тексту, и после переезда окна', (tester) async {
    final text = _long(300);
    final field = await _pump(tester, text, caret: text.length ~/ 2);
    await _focus(tester, field);
    final local = field.window.value;
    final caret = local.selection.baseOffset;
    await _type(tester, field, TextEditingValue(text: local.text.replaceRange(caret, caret, 'Ж'), selection: TextSelection.collapsed(offset: caret + 1)));
    await tester.pump(const Duration(milliseconds: 600));
    expect(field.undo.value.canUndo, isTrue);
    final typed = field.document.text;
    // курсор далеко: окно уехало в конец
    field.document.selection = TextSelection.collapsed(offset: typed.length);
    await tester.pump();
    field.undo.undo();
    await tester.pump();
    await tester.pump();
    expect(field.document.text, text);
    expect(_composed(tester), text);
    expect(field.undo.value.canRedo, isTrue);
    field.undo.redo();
    await tester.pump();
    await tester.pump();
    expect(field.document.text, typed);
    expect(_composed(tester), typed);
  });

  testWidgets('Ctrl+Z отменяет правку всего текста, а не окна', (tester) async {
    final text = _long(300);
    final field = await _pump(tester, text, caret: text.length ~/ 2);
    await _focus(tester, field);
    final local = field.window.value;
    final caret = local.selection.baseOffset;
    await _type(tester, field, TextEditingValue(text: local.text.replaceRange(caret, caret, 'Ж'), selection: TextSelection.collapsed(offset: caret + 1)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump();
    expect(field.document.text, text);
  });

  testWidgets('правка снаружи мимо окна: всё на местах', (tester) async {
    final text = _long(300);
    final field = await _pump(tester, text, caret: text.length);
    field.document.value = field.document.value.copyWith(text: 'Начало\n$text', selection: TextSelection.collapsed(offset: text.length + 7));
    await tester.pump();
    expect(_composed(tester), 'Начало\n$text');
    expect(field.document.text.substring(field.document.selection.baseOffset - field.window.selection.baseOffset), startsWith(field.window.text));
  });

  testWidgets('правка снаружи у курсора (разметка, ссылка) идёт в окно', (tester) async {
    final text = _long(300);
    final middle = text.length ~/ 2;
    final field = await _pump(tester, text, caret: middle);
    final before = field.window.text.length;
    field.document.value = TextEditingValue(text: text.replaceRange(middle, middle, '**'), selection: TextSelection.collapsed(offset: middle + 1));
    await tester.pump();
    expect(field.window.text.length, before + 2);
    expect(_composed(tester), field.document.text);
  });

  testWidgets('длинный текст стёрли до короткого — снова одно поле; короткий дорос — окно', (tester) async {
    final text = _long(300);
    final field = await _pump(tester, text, caret: text.length ~/ 2);
    await _focus(tester, field);
    // выделили всё и написали поверх
    _liveState(tester).selectAll(SelectionChangedCause.keyboard);
    await tester.pump();
    await tester.pump();
    await _type(tester, field, const TextEditingValue(text: 'осталось чуть-чуть', selection: TextSelection.collapsed(offset: 18)));
    expect(field.document.text, 'осталось чуть-чуть');
    expect(_fields(tester), hasLength(1));
    expect(field.document.text.length, lessThan(WindowedTextField.wholeLimit));
    final grown = '${field.window.text}\n${_long(200)}';
    await _type(tester, field, TextEditingValue(text: grown, selection: TextSelection.collapsed(offset: grown.length)));
    expect(_fields(tester).length, greaterThan(3));
    expect(_composed(tester), field.document.text);
    expect(field.document.text, grown);
  });
}
