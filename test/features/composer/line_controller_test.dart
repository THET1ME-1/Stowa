import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/repositories/folders_repository.dart';
import 'package:stowa/features/composer/line_controller.dart';

TextEditingValue _typed(String text) => TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));

void main() {
  final now = DateTime(2026, 11, 2, 10);
  late LineController line;

  setUp(() => line = LineController(clock: () => now));
  tearDown(() => line.dispose());

  test('дописанный тег с пробелом уходит из текста в чип', () {
    line.value = _typed('купить хлеб #дом ');
    expect(line.text, 'купить хлеб ');
    expect(line.tags, ['дом']);
    expect(line.selection.baseOffset, line.text.length);
  });

  test('тег без пробела после ещё пишется и остаётся в тексте', () {
    line.value = _typed('купить хлеб #до');
    expect(line.text, 'купить хлеб #до');
    expect(line.tags, isEmpty);
  });

  test('цвет вида #FF0000 тегом не становится', () {
    line.value = _typed('фон #FF0000 ');
    expect(line.text, 'фон #FF0000 ');
    expect(line.tags, isEmpty);
  });

  test('повтор тега не даёт второго чипа', () {
    line.value = _typed('#Дом ');
    line.value = _typed('#дом ');
    expect(line.tags, ['дом']);
    expect(line.text, '');
  });

  test('тег из середины строки вырезается, курсор остаётся у места правки', () {
    line.value = const TextEditingValue(text: 'купить #дом хлеб', selection: TextSelection.collapsed(offset: 12));
    expect(line.text, 'купить хлеб');
    expect(line.tags, ['дом']);
    expect(line.selection.baseOffset, 7);
  });

  test('дата в тексте даёт напоминание, крестик его снимает', () {
    line.value = _typed('23 декабря 13:00 зубной');
    expect(line.reminder?.at, DateTime(2026, 12, 23, 13));
    line.dismissReminder();
    expect(line.reminder, isNull);
  });

  test('после отправки строка пустая и снова ищет даты', () {
    line.value = _typed('#дом завтра в 9 ');
    line.dismissReminder();
    line.reset();
    expect(line.text, '');
    expect(line.tags, isEmpty);
    line.value = _typed('завтра в 9 позвонить');
    expect(line.reminder, isNotNull);
  });

  test('убрать чип тега', () {
    line.value = _typed('#дом #кино ');
    line.removeTag('дом');
    expect(line.tags, ['кино']);
  });

  test('@папка с пробелом встаёт чипом папки, незнакомая остаётся текстом', () {
    const refs = FolderCard(id: 'refs', name: 'Референсы', icon: 'palette', shape: 'squircle', count: 0, covers: [], recentTitles: [], createdByAi: false);
    line.resolveFolder = (name) => name == 'референсы' ? refs : null;
    line.value = _typed('лампа @Референсы ');
    expect(line.folder?.id, 'refs');
    expect(line.text, 'лампа ');
    line.value = _typed('почта @нигде ');
    expect(line.text, 'почта @нигде ');
  });

  test('@ с пробелом не хватает папку по началу слова, только по точному имени', () {
    const radio = FolderCard(id: 'radio', name: 'Беспроводные наушники', icon: 'headphones', shape: 'pill', count: 0, covers: [], recentTitles: [], createdByAi: false);
    const car = FolderCard(id: 'car', name: 'Машина', icon: 'directions_car', shape: 'pill', count: 0, covers: [], recentTitles: [], createdByAi: false);
    line.resolveFolder = (name) => [radio, car].where((folder) => folder.name.toLowerCase() == name).firstOrNull;
    line.value = _typed('@Беспроводные ');
    expect(line.folder, isNull);
    expect(line.text, '@Беспроводные ');
    line.value = _typed('@машина ');
    expect(line.folder?.id, 'car');
  });

  test('стирание в начале снимает чипы с конца: теги, потом папка', () {
    const car = FolderCard(id: 'car', name: 'Машина', icon: 'directions_car', shape: 'pill', count: 0, covers: [], recentTitles: [], createdByAi: false);
    line.chooseFolder(car);
    line.addTag('шины');
    expect(line.dropLastChip(), isTrue);
    expect(line.tags, isEmpty);
    expect(line.dropLastChip(), isTrue);
    expect(line.folder, isNull);
    expect(line.dropLastChip(), isFalse);
  });

  test('«Отменить» возвращает текст и чипы', () {
    line.restore(text: 'зубной завтра', tags: ['здоровье']);
    expect(line.text, 'зубной завтра');
    expect(line.tags, ['здоровье']);
    expect(line.selection.baseOffset, line.text.length);
  });

  test('кнопка # вставляет знак через пробел от слова', () {
    line.value = _typed('лампа');
    line.insertAtCaret('#', spaced: true);
    expect(line.text, 'лампа #');
  });

  testWidgets('дата в строке подчёркнута точками', (tester) async {
    line.value = _typed('зубной 23 декабря 13:00');
    late TextSpan span;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      span = line.buildTextSpan(context: context, withComposing: false);
      return const SizedBox();
    })));
    final dotted = <String>[];
    span.visitChildren((child) {
      final style = (child as TextSpan).style;
      if (style?.decorationStyle == TextDecorationStyle.dotted) dotted.add(child.text!);
      return true;
    });
    expect(dotted, ['23 декабря 13:00']);
  });

  testWidgets('день и время порознь подчёркнуты каждый, слова между ними — нет', (tester) async {
    line.value = _typed('Завтра военная кафедра в 14:00');
    late TextSpan span;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      span = line.buildTextSpan(context: context, withComposing: false);
      return const SizedBox();
    })));
    final dotted = <String>[];
    span.visitChildren((child) {
      final style = (child as TextSpan).style;
      if (style?.decorationStyle == TextDecorationStyle.dotted) dotted.add(child.text!);
      return true;
    });
    expect(dotted, ['Завтра', 'в 14:00']);
  });
}
