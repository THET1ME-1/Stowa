import 'dart:convert';

import 'package:flutter/services.dart';

/// Команда рабочего пространства: группа, значок и стандартные сочетания. Название —
/// в словаре по [id] (`workspace_commands.dart`).
class WsCommand {
  const WsCommand(this.id, this.group, this.icon, this.defaults);

  final String id;
  final String group;
  final String icon;
  final List<String> defaults;
}

/// Сочетания подобраны так, чтобы не спорить с браузером: Ctrl+N, Ctrl+T, Ctrl+W, Ctrl+Tab
/// и Ctrl+1…9 он оставляет себе, а Ctrl+Alt+буква в польской и румынской раскладке — AltGr.
const wsCommands = [
  WsCommand('find', 'nav', 'search', ['Ctrl+K', '/']),
  WsCommand('palette', 'nav', 'terminal', ['Ctrl+P']),
  WsCommand('switch', 'nav', 'description', ['Ctrl+O']),
  WsCommand('home', 'nav', 'home', ['G H']),
  WsCommand('keys', 'nav', 'keyboard', ['?', 'Ctrl+/']),
  WsCommand('new', 'notes', 'edit_square', ['N', 'Alt+N']),
  WsCommand('trash', 'notes', 'delete', ['Delete', 'Alt+Backspace']),
  WsCommand('pin', 'notes', 'keep', ['P', 'Alt+P']),
  WsCommand('move', 'notes', 'drive_file_move', ['M', 'Alt+M']),
  WsCommand('close', 'tabs', 'close', ['Alt+W']),
  WsCommand('reopen', 'tabs', 'undo', ['Alt+Shift+T']),
  WsCommand('next', 'tabs', 'arrow_forward', ['Alt+]']),
  WsCommand('prev', 'tabs', 'arrow_back', ['Alt+[']),
  WsCommand('splitRight', 'tabs', 'splitscreen_right', ['Ctrl+\\']),
  WsCommand('splitDown', 'tabs', 'splitscreen_bottom', ['Ctrl+Shift+\\']),
  WsCommand('nextPane', 'tabs', 'switch_left', ['Alt+Shift+→']),
  WsCommand('prevPane', 'tabs', 'switch_right', ['Alt+Shift+←']),
  WsCommand('closePane', 'tabs', 'cancel', ['Alt+Shift+W']),
  WsCommand('left', 'docks', 'left_panel_open', ['Ctrl+[']),
  WsCommand('right', 'docks', 'right_panel_open', ['Ctrl+]']),
  WsCommand('theme', 'docks', 'dark_mode', ['Alt+Shift+L']),
  WsCommand('settings', 'docks', 'settings', ['Ctrl+,']),
];

const wsGroups = ['nav', 'notes', 'tabs', 'docks'];

/// Занятое браузером: нажатие до страницы не доходит или уводит со страницы.
final browserChords = {
  'Ctrl+N', 'Ctrl+Shift+N', 'Ctrl+T', 'Ctrl+Shift+T', 'Ctrl+W', 'Ctrl+Shift+W', 'Ctrl+Tab', 'Ctrl+Shift+Tab', 'Ctrl+L', 'Ctrl+R', 'Ctrl+Shift+R', 'Ctrl+Q', 'Ctrl+H', 'Ctrl+J', 'Ctrl+D', 'Ctrl+Shift+Delete',
  for (var i = 1; i <= 9; i++) 'Ctrl+$i',
};

/// Сочетание занято браузером.
class BrowserChord implements Exception {
  const BrowserChord(this.chord);

  final String chord;
}

final _names = <PhysicalKeyboardKey, String>{
  PhysicalKeyboardKey.bracketLeft: '[',
  PhysicalKeyboardKey.bracketRight: ']',
  PhysicalKeyboardKey.backslash: '\\',
  PhysicalKeyboardKey.slash: '/',
  PhysicalKeyboardKey.comma: ',',
  PhysicalKeyboardKey.period: '.',
  PhysicalKeyboardKey.minus: '-',
  PhysicalKeyboardKey.equal: '=',
  PhysicalKeyboardKey.backspace: 'Backspace',
  PhysicalKeyboardKey.delete: 'Delete',
  PhysicalKeyboardKey.arrowRight: '→',
  PhysicalKeyboardKey.arrowLeft: '←',
  PhysicalKeyboardKey.arrowUp: '↑',
  PhysicalKeyboardKey.arrowDown: '↓',
  PhysicalKeyboardKey.enter: 'Enter',
  PhysicalKeyboardKey.escape: 'Esc',
  PhysicalKeyboardKey.space: 'Space',
  PhysicalKeyboardKey.tab: 'Tab',
};

final _letters = {
  for (var i = 0; i < 26; i++) PhysicalKeyboardKey(PhysicalKeyboardKey.keyA.usbHidUsage + i): String.fromCharCode(0x41 + i),
};

final _digits = {
  for (var i = 0; i < 9; i++) PhysicalKeyboardKey(PhysicalKeyboardKey.digit1.usbHidUsage + i): '${i + 1}',
  PhysicalKeyboardKey.digit0: '0',
};

/// Сочетание по месту клавиши, а не по букве: «Ctrl+K» и на русской раскладке.
/// Нажатие самого Ctrl, Alt или Shift — не сочетание.
String? chordOf(PhysicalKeyboardKey key, {bool ctrl = false, bool alt = false, bool shift = false}) {
  var name = _names[key] ?? _letters[key] ?? _digits[key];
  if (name == null) return null;
  if (shift && name == '/') return ctrl || alt ? '${ctrl ? 'Ctrl+' : ''}${alt ? 'Alt+' : ''}?' : '?';
  return [if (ctrl) 'Ctrl', if (alt) 'Alt', if (shift) 'Shift', name].join('+');
}

/// Сочетание без Ctrl и Alt (одна клавиша, с Shift) работает только вне поля ввода:
/// иначе им нельзя было бы набрать букву.
bool needsFreeFocus(String chord) => !chord.contains('Ctrl+') && !chord.contains('Alt+');

/// Сочетания команд: стандартные и свои поверх них.
class KeyMap {
  KeyMap([Map<String, List<String>>? custom]) : _custom = {...?custom};

  final Map<String, List<String>> _custom;

  factory KeyMap.fromJson(String? text) {
    if (text == null) return KeyMap();
    try {
      final map = jsonDecode(text) as Map<String, dynamic>;
      return KeyMap({for (final MapEntry(:key, :value) in map.entries) key: [for (final chord in value as List) chord as String]});
    } on Object {
      return KeyMap();
    }
  }

  String toJson() => jsonEncode(_custom);

  /// Команды, у которых сочетания свои.
  Set<String> get changed => _custom.keys.toSet();

  List<String> of(String id) => _custom[id] ?? wsCommands.firstWhere((command) => command.id == id).defaults;

  String? commandFor(String chord) {
    for (final command in wsCommands) {
      if (of(command.id).contains(chord)) return command.id;
    }
    return null;
  }

  /// С этой клавиши начинается двойное сочетание («G», затем «H»).
  bool startsSequence(String chord) => wsCommands.any((command) => of(command.id).any((one) => one.startsWith('$chord ')));

  void _set(String id, List<String> chords) {
    final defaults = wsCommands.firstWhere((command) => command.id == id).defaults;
    if (chords.length == defaults.length && chords.indexed.every((pair) => defaults[pair.$1] == pair.$2)) {
      _custom.remove(id);
    } else {
      _custom[id] = chords;
    }
  }

  /// Снять [chord] с другой команды; вернуть её id, если снято.
  String? _free(String chord, String keep) {
    final owner = commandFor(chord);
    if (owner == null || owner == keep) return null;
    _set(owner, [...of(owner)]..remove(chord));
    return owner;
  }

  void _check(String chord) {
    if (browserChords.contains(chord)) throw BrowserChord(chord);
  }

  /// Добавить ещё одно сочетание. Вернёт команду, у которой его сняли.
  String? add(String id, String chord) {
    _check(chord);
    final taken = _free(chord, id);
    if (!of(id).contains(chord)) _set(id, [...of(id), chord]);
    return taken;
  }

  /// Заменить сочетание номер [index]. Вернёт команду, у которой его сняли.
  String? replace(String id, int index, String chord) {
    _check(chord);
    final taken = _free(chord, id);
    final chords = [...of(id)];
    chords[index] = chord;
    _set(id, chords.toSet().toList());
    return taken;
  }

  void remove(String id, int index) => _set(id, [...of(id)]..removeAt(index));

  void reset(String id) => _custom.remove(id);

  void resetAll() => _custom.clear();
}
