import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/workspace/workspace_keys.dart';

void main() {
  test('сочетание берётся по месту клавиши: русская «л» на месте K — это Ctrl+K', () {
    expect(chordOf(PhysicalKeyboardKey.keyK, ctrl: true), 'Ctrl+K');
    expect(chordOf(PhysicalKeyboardKey.bracketLeft, ctrl: true), 'Ctrl+[');
    expect(chordOf(PhysicalKeyboardKey.keyN, alt: true, shift: true), 'Alt+Shift+N');
    expect(chordOf(PhysicalKeyboardKey.digit2, alt: true, shift: true), 'Alt+Shift+2');
    expect(chordOf(PhysicalKeyboardKey.slash, shift: true), '?');
    expect(chordOf(PhysicalKeyboardKey.delete), 'Delete');
    expect(chordOf(PhysicalKeyboardKey.shiftLeft, shift: true), isNull);
  });

  test('у команды стандартные сочетания, пока свои не заданы', () {
    final keys = KeyMap();
    expect(keys.of('find'), ['Ctrl+K', '/']);
    expect(keys.commandFor('Ctrl+K'), 'find');
    expect(keys.commandFor('/'), 'find');
  });

  test('добавить, заменить, убрать и вернуть как было', () {
    final keys = KeyMap();
    keys.add('find', 'Alt+S');
    expect(keys.of('find'), ['Ctrl+K', '/', 'Alt+S']);
    keys.replace('new', 0, 'Alt+J');
    expect(keys.of('new'), ['Alt+J', 'Alt+N']);
    keys.remove('new', 1);
    expect(keys.of('new'), ['Alt+J']);
    expect(keys.changed, {'find', 'new'});
    keys.reset('new');
    expect(keys.of('new'), ['N', 'Alt+N']);
    keys.resetAll();
    expect(keys.changed, isEmpty);
  });

  test('сочетание другой команды снимается с неё и называет её', () {
    final keys = KeyMap();
    final taken = keys.add('find', 'Ctrl+P');
    expect(taken, 'palette');
    expect(keys.of('palette'), isEmpty);
    expect(keys.commandFor('Ctrl+P'), 'find');
  });

  test('сочетания браузера взять нельзя', () {
    final keys = KeyMap();
    expect(() => keys.add('find', 'Ctrl+T'), throwsA(isA<BrowserChord>()));
    expect(() => keys.add('find', 'Ctrl+W'), throwsA(isA<BrowserChord>()));
    expect(keys.of('find'), ['Ctrl+K', '/']);
  });

  test('свои сочетания переживают перезапуск', () {
    final keys = KeyMap()..add('find', 'Alt+S');
    final back = KeyMap.fromJson(keys.toJson());
    expect(back.of('find'), ['Ctrl+K', '/', 'Alt+S']);
    expect(KeyMap.fromJson('{сломано').of('find'), ['Ctrl+K', '/']);
  });

  test('двойное сочетание: G, затем H', () {
    final keys = KeyMap();
    expect(keys.startsSequence('G'), isTrue);
    expect(keys.commandFor('G H'), 'home');
    expect(keys.startsSequence('K'), isFalse);
  });

  test('одиночная клавиша без Ctrl и Alt — только вне поля ввода', () {
    expect(needsFreeFocus('N'), isTrue);
    expect(needsFreeFocus('?'), isTrue);
    expect(needsFreeFocus('Shift+N'), isTrue);
    expect(needsFreeFocus('Delete'), isTrue);
    expect(needsFreeFocus('Ctrl+K'), isFalse);
    expect(needsFreeFocus('Alt+N'), isFalse);
  });
}
