import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../data/repositories/folders_repository.dart';
import '../../domain/item_kind.dart';
import '../../domain/line_query.dart';
import '../../domain/place_cue.dart';
import '../../domain/reminder_parser.dart';
import '../../domain/tag_name.dart';

// тег и папка по тем же правилам, что в тексте вещи, и уже с пробелом после
final _finishedMark = RegExp(r'(?<![\p{L}\p{N}_#@])([#@])([\p{L}\p{N}_][^\s#@]*)(?=\s)', unicode: true);
// то же, но и в самом конце строки: при сохранении пробела после метки может не быть
final _anyMark = RegExp(r'(?<![\p{L}\p{N}_#@])([#@])([\p{L}\p{N}_][^\s#@]*)(?=\s|$)', unicode: true);
final _typingMark =RegExp(r'(?<![\p{L}\p{N}_#@])[#@][^\s#@]*$', unicode: true);
final _hexColor = RegExp(r'^[0-9a-fA-F]{6}$');
final _tagName = RegExp(r'^[\p{L}_][\p{L}\p{N}_]*$', unicode: true);
final _commandMark = RegExp(r'^/\S+');
final _markdown = RegExp(r'^(#{1,3} |- \[[ xX]\] |- |> )|\*\*|~~|`', multiLine: true);

/// Текст строки ввода. Дописанный `#тег ` и `@папка ` уходят из текста в чипы
/// над строкой, дата становится напоминанием, ссылка, команда и разметка
/// подсвечиваются на месте.
class LineController extends TextEditingController {
  LineController({DateTime Function()? clock, int Function()? workEnd, this.resolveFolder, this.folderMarks = true}) : _clock = clock ?? DateTime.now, _workEnd = workEnd ?? (() => defaultWorkEnd);

  /// Строка знает папки. Нет — «@слово» остаётся обычным текстом: так под замком в окне виджета.
  final bool folderMarks;

  final DateTime Function() _clock;

  /// Конец рабочего дня для «после работы», в минутах от полуночи.
  final int Function() _workEnd;

  /// Папка по точному имени в нижнем регистре: `@машина ` становится чипом «Машина».
  FolderCard? Function(String query)? resolveFolder;

  final List<String> _tags = [];
  FolderCard? _folder;
  bool _reminderDismissed = false;
  bool _placeDismissed = false;
  String? _parsedText;
  ReminderMatch? _parsed;
  String? _cueText;
  PlaceCue? _cue;

  List<String> get tags => List.unmodifiable(_tags);

  FolderCard? get folder => _folder;

  bool get reminderDismissed => _reminderDismissed;

  bool get hasChips => _tags.isNotEmpty || _folder != null;

  /// Напоминание из текста, пока человек его не снял.
  ReminderMatch? get reminder {
    if (_reminderDismissed) return null;
    if (_parsedText != text) {
      _parsedText = text;
      _parsed = parseReminder(text, _clock(), workEnd: _workEnd());
    }
    return _parsed;
  }

  bool get placeDismissed => _placeDismissed;

  /// Место из текста («напомни дома»), пока человек его не снял.
  PlaceCue? get placeCue {
    if (_placeDismissed) return null;
    if (_cueText != text) {
      _cueText = text;
      _cue = parsePlaceCue(text);
    }
    return _cue;
  }

  @override
  set value(TextEditingValue newValue) {
    super.value = _liftMarks(newValue);
  }

  void dismissReminder() {
    _reminderDismissed = true;
    notifyListeners();
  }

  void dismissPlace() {
    _placeDismissed = true;
    notifyListeners();
  }

  void addTag(String raw) {
    final name = normalizeTagName(raw);
    if (name.isEmpty || _tags.contains(name)) return;
    _tags.add(name);
    notifyListeners();
  }

  void removeTag(String name) {
    if (_tags.remove(name)) notifyListeners();
  }

  void chooseFolder(FolderCard? folder) {
    _folder = folder;
    notifyListeners();
  }

  /// Стирание в самом начале строки снимает последний чип.
  bool dropLastChip() {
    if (_tags.isNotEmpty) {
      _tags.removeLast();
    } else if (_folder != null) {
      _folder = null;
    } else {
      return false;
    }
    notifyListeners();
    return true;
  }

  /// Заменить кусок текста и поставить курсор за вставкой.
  void replaceRange(int start, int end, String insert) {
    final tail = text.substring(end).replaceFirst(RegExp(r'^ '), insert.endsWith(' ') ? '' : ' ');
    final next = text.substring(0, start) + insert + tail;
    value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
  }

  /// Вставить у курсора, отделив пробелом от слова перед ним.
  void insertAtCaret(String insert, {bool spaced = true}) {
    final at = selection.isValid ? selection.extentOffset : text.length;
    final before = text.substring(0, at);
    final glue = spaced && before.isNotEmpty && !before.endsWith(' ') && !before.endsWith('\n') ? ' ' : '';
    final next = before + glue + insert + text.substring(at);
    value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at + glue.length + insert.length),
    );
  }

  /// Вернуть строку как была: «Отменить» после «Закинуть».
  void restore({required String text, required List<String> tags, FolderCard? folder, bool reminderDismissed = false, bool placeDismissed = false}) {
    _tags
      ..clear()
      ..addAll(tags);
    _folder = folder;
    _reminderDismissed = reminderDismissed;
    _placeDismissed = placeDismissed;
    value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Перед сохранением: каждый `#тег` из текста уходит в чипы, первое `@имя` — в папку,
  /// даже если человек не нажал пробел и не выбрал её в подсказках.
  /// Вернёт имя папки, которой ещё нет: её создаёт строка.
  String? takeMarks() {
    String? newFolder;
    final cuts = <(int, int)>[];
    for (final match in _anyMark.allMatches(text)) {
      final raw = match.group(2)!;
      if (match.group(1) == '#') {
        if (_hexColor.hasMatch(raw) || !_tagName.hasMatch(raw)) continue;
        final name = normalizeTagName(raw);
        if (name.isEmpty) continue;
        if (!_tags.contains(name)) _tags.add(name);
      } else {
        // папка уже выбрана чипом или строка о папках не знает — «@слово» остаётся текстом
        if (!folderMarks || _folder != null || newFolder != null) continue;
        final found = resolveFolder?.call(normalizeQuery(raw));
        if (found != null) {
          _folder = found;
        } else {
          newFolder = raw;
        }
      }
      // вместе с меткой уходит один пробел за ней, а в конце строки — перед ней; отступы списков целы
      final spaceAfter = match.end < text.length && text[match.end] == ' ';
      final taken = cuts.isEmpty ? 0 : cuts.last.$2;
      final spaceBefore = !spaceAfter && match.start - 1 >= taken && text[match.start - 1] == ' ';
      cuts.add((spaceBefore ? match.start - 1 : match.start, spaceAfter ? match.end + 1 : match.end));
    }
    if (cuts.isEmpty) return null;
    var cleaned = text;
    for (final (start, end) in cuts.reversed) {
      cleaned = cleaned.replaceRange(start, end, '');
    }
    cleaned = cleaned.trim();
    value = TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
    return newFolder;
  }

  /// Строка после отправки: пусто, без чипов, даты снова ищутся.
  void reset() {
    _tags.clear();
    _folder = null;
    _reminderDismissed = false;
    _placeDismissed = false;
    clear();
  }

  TextEditingValue _liftMarks(TextEditingValue value) {
    // пока клавиатура собирает слово, текст не трогаем
    if (value.composing.isValid && !value.composing.isCollapsed) return value;
    final caret = value.selection.isValid ? value.selection.extentOffset : value.text.length;
    final cuts = <(int, int)>[];
    for (final match in _finishedMark.allMatches(value.text)) {
      // курсор у самого конца: слово ещё пишут посреди строки
      if (match.end == caret) continue;
      final raw = match.group(2)!;
      if (match.group(1) == '#') {
        if (_hexColor.hasMatch(raw) || !_tagName.hasMatch(raw)) continue;
        final name = normalizeTagName(raw);
        if (name.isEmpty) continue;
        if (!_tags.contains(name)) _tags.add(name);
      } else {
        final found = resolveFolder?.call(normalizeQuery(raw));
        if (found == null) continue;
        _folder = found;
      }
      cuts.add((match.start, match.end + 1));
    }
    if (cuts.isEmpty) return value;

    var text = value.text;
    var at = caret;
    for (final (start, end) in cuts.reversed) {
      text = text.replaceRange(start, end, '');
      if (at > start) at = (at - (end - start)).clamp(start, text.length);
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: at),
    );
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final marks = <(int, int, TextStyle)>[];
    final command = _commandMark.firstMatch(text);
    if (command != null) {
      marks.add((0, command.end, TextStyle(color: Tokens.onAccent, backgroundColor: Tokens.accent)));
    }
    final found = reminder;
    final cue = placeCue;
    // день и время могут стоять порознь: подчёркнут каждый кусок, слова между ними — нет; место — так же
    for (final (from, to) in [...?found?.parts, if (cue != null) (cue.start, cue.end)]) {
      marks.add((
        from,
        to,
        TextStyle(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
          decorationThickness: 1.5,
          decorationColor: Tokens.onSurface,
        ),
      ));
    }
    for (final match in urlMatches(text)) {
      marks.add((
        match.start,
        match.end,
        TextStyle(color: Tokens.onSurfaceVariant, decoration: TextDecoration.underline, decorationColor: Tokens.onSurfaceVariant),
      ));
    }
    for (final match in _markdown.allMatches(text)) {
      marks.add((match.start, match.end, TextStyle(color: Tokens.muted)));
    }
    // тег или папка, которые пишутся сейчас, подсвечены фоном: ширина букв та же, курсор не прыгает
    if (selection.isValid && selection.isCollapsed && selection.extentOffset <= text.length) {
      final typing = _typingMark.firstMatch(text.substring(0, selection.extentOffset));
      if (typing != null && (folderMarks || text[typing.start] == '#')) {
        marks.add((typing.start, typing.end, TextStyle(backgroundColor: Tokens.onSurface.withValues(alpha: 0.15))));
      }
    }
    if (marks.isEmpty) return super.buildTextSpan(context: context, style: style, withComposing: withComposing);

    marks.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : b.$2.compareTo(a.$2));
    final children = <TextSpan>[];
    var at = 0;
    for (final (start, end, mark) in marks) {
      // пересечения не красим дважды: первая метка главнее
      if (start < at) continue;
      if (start > at) children.add(TextSpan(text: text.substring(at, start)));
      children.add(TextSpan(text: text.substring(start, end), style: mark));
      at = end;
    }
    if (at < text.length) children.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: children);
  }
}
