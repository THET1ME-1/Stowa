import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'markdown_edit.dart';
import 'math_edit.dart' show mathAround;

/// Полоса разметки: заголовок, жирный, курсив, зачёркнутый, список, чек-лист, цитата, код.
/// Одна и та же в строке на весь экран и в правке заметки. С [undo] — ещё «Отменить» и «Вернуть».
class MarkdownBar extends StatelessWidget {
  const MarkdownBar({super.key, required this.onAction, this.undo, this.field});

  final ValueChanged<MarkdownAction> onAction;
  final UndoHistoryController? undo;

  /// Поле, которое правит полоса: курсор в формуле — первой кнопкой «к следующему полю».
  final TextEditingController? field;

  // курсор вошёл в формулу или вышел из неё — полоса пересобирается
  @override
  Widget build(BuildContext context) => field == null ? _bar(context) : ListenableBuilder(listenable: field!, builder: (context, _) => _bar(context));

  Widget _bar(BuildContext context) {
    final l = L.of(context);
    Widget button(String icon, String tooltip, VoidCallback? onTap) => IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        fixedSize: const Size(30, 40),
        minimumSize: const Size(30, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        foregroundColor: Tokens.onSurface,
        disabledForegroundColor: Tokens.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(symbolIcon(icon), size: 21),
    );
    final divider = SizedBox(height: 22, child: VerticalDivider(width: 1, thickness: 1, color: Tokens.outline));
    List<Widget> history(UndoHistoryValue value) => [
      divider,
      button('undo', l.mdUndo, value.canUndo ? undo!.undo : null),
      button('redo', l.mdRedo, value.canRedo ? undo!.redo : null),
    ];
    final value = field?.value;
    final inMath = value != null && value.selection.isValid && mathAround(value.text, value.selection.extentOffset) != null;
    Widget row(List<Widget> tail) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // в формуле нужнее всего «дальше»: из числителя в знаменатель, из скобки — за неё
        if (inMath) ...[button('keyboard_tab', l.mdMathNext, () => onAction(MarkdownAction.mathNext)), divider],
        button('format_h1', l.mdHeading, () => onAction(MarkdownAction.heading)),
        button('format_bold', l.mdBold, () => onAction(MarkdownAction.bold)),
        button('format_italic', l.mdItalic, () => onAction(MarkdownAction.italic)),
        button('format_strikethrough', l.mdStrike, () => onAction(MarkdownAction.strike)),
        divider,
        button('format_list_bulleted', l.mdBullets, () => onAction(MarkdownAction.bullets)),
        button('check_box', l.mdChecklist, () => onAction(MarkdownAction.checklist)),
        button('format_quote', l.mdQuote, () => onAction(MarkdownAction.quote)),
        button('code', l.mdCode, () => onAction(MarkdownAction.code)),
        button('functions', l.mdMath, () => onAction(MarkdownAction.math)),
        // [[ ]] с курсором внутри: сразу появляется список заметок
        button('add_link', l.linkAdd, () => onAction(MarkdownAction.link)),
        ...tail,
      ],
    );
    // кнопки расходятся по всей ширине, а на узком экране листаются
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: undo == null ? row(const []) : ValueListenableBuilder(valueListenable: undo!, builder: (context, value, _) => row(history(value))),
          ),
        ),
      ),
    );
  }
}
