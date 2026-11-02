import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../domain/item_kind.dart';
import '../../domain/reminder_parser.dart';
import '../../domain/tag_name.dart';

// тег по тем же правилам, что в тексте вещи, и уже с пробелом после
final _finishedTag = RegExp(r'(?<![\p{L}\p{N}_#])#([\p{L}_][\p{L}\p{N}_]*)(?=\s)', unicode: true);
final _typingTag = RegExp(r'(?<![\p{L}\p{N}_#])#[\p{L}\p{N}_]*$', unicode: true);
final _hexColor = RegExp(r'^[0-9a-fA-F]{6}$');

/// Текст строки ввода. Дописанный `#тег ` уходит из текста в чип над строкой,
/// дата в тексте становится напоминанием, ссылка и тег подсвечиваются на месте.
class LineController extends TextEditingController {
  LineController({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final List<String> _tags = [];
  bool _reminderDismissed = false;
  String? _parsedText;
  ReminderMatch? _parsed;

  List<String> get tags => List.unmodifiable(_tags);

  bool get reminderDismissed => _reminderDismissed;

  /// Напоминание из текста, пока человек его не снял.
  ReminderMatch? get reminder {
    if (_reminderDismissed) return null;
    if (_parsedText != text) {
      _parsedText = text;
      _parsed = parseReminder(text, _clock());
    }
    return _parsed;
  }

  bool get hasContent => text.trim().isNotEmpty || _tags.isNotEmpty;

  @override
  set value(TextEditingValue newValue) {
    super.value = _liftTags(newValue);
  }

  void dismissReminder() {
    _reminderDismissed = true;
    notifyListeners();
  }

  void removeTag(String name) {
    if (_tags.remove(name)) notifyListeners();
  }

  /// Строка после отправки: пусто, без чипов, даты снова ищутся.
  void reset() {
    _tags.clear();
    _reminderDismissed = false;
    clear();
  }

  TextEditingValue _liftTags(TextEditingValue value) {
    // пока клавиатура собирает слово, текст не трогаем
    if (value.composing.isValid && !value.composing.isCollapsed) return value;
    final caret = value.selection.isValid ? value.selection.extentOffset : value.text.length;
    final cuts = <(int, int)>[];
    for (final match in _finishedTag.allMatches(value.text)) {
      final raw = match.group(1)!;
      // курсор у самого конца тега: его ещё пишут посреди строки
      if (match.end == caret || _hexColor.hasMatch(raw)) continue;
      final name = normalizeTagName(raw);
      if (name.isEmpty) continue;
      if (!_tags.contains(name)) _tags.add(name);
      cuts.add((match.start, match.end + 1));
    }
    if (cuts.isEmpty) return value;

    var text = value.text;
    var at = caret;
    for (final (start, end) in cuts.reversed) {
      text = text.replaceRange(start, end, '');
      if (at > start) at = (at - (end - start)).clamp(start, text.length);
    }
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: at));
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final marks = <(int, int, TextStyle)>[];
    final found = reminder;
    if (found != null) {
      marks.add((found.start, found.end, const TextStyle(
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
        decorationThickness: 1.5,
        decorationColor: Tokens.onSurface,
      )));
    }
    for (final match in urlMatches(text)) {
      marks.add((match.start, match.end, const TextStyle(
        color: Tokens.onSurfaceVariant,
        decoration: TextDecoration.underline,
        decorationColor: Tokens.onSurfaceVariant,
      )));
    }
    // тег, который пишется прямо сейчас, подсвечен фоном: ширина букв та же, курсор не прыгает
    if (selection.isValid && selection.isCollapsed) {
      final typing = _typingTag.firstMatch(text.substring(0, selection.extentOffset));
      if (typing != null) {
        marks.add((typing.start, typing.end, TextStyle(backgroundColor: Tokens.onSurface.withValues(alpha: 0.15))));
      }
    }
    if (marks.isEmpty) return super.buildTextSpan(context: context, style: style, withComposing: withComposing);

    marks.sort((a, b) => a.$1.compareTo(b.$1));
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
