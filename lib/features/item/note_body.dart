import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import 'note_blocks.dart';

/// Текст заметки на странице вещи: абзацы, заголовки, списки, галочки, цитаты.
/// Касание по тексту открывает правку, по галочке — отмечает дело, по ссылке — открывает её.
class NoteBody extends StatelessWidget {
  const NoteBody({super.key, required this.blocks, required this.onToggle, required this.onEdit, required this.onLink});

  final List<NoteBlock> blocks;
  final ValueChanged<int> onToggle;
  final VoidCallback onEdit;
  final ValueChanged<String> onLink;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final body = text.bodyLarge!.copyWith(fontSize: 16, height: 1.55, color: Tokens.onSurface);
    final children = <Widget>[];
    NoteBlock? previous;
    for (final block in blocks) {
      // между абзацами воздух, пункты одного списка держатся вместе
      final listy = block is BulletBlock || block is NumberedBlock || block is CheckBlock;
      final wasListy = previous is BulletBlock || previous is NumberedBlock || previous is CheckBlock;
      final gap = previous == null ? 0.0 : (listy && wasListy ? 2.0 : (block is HeadingBlock ? 20.0 : 12.0));
      children.add(SizedBox(height: gap));
      children.add(_block(context, block, body));
      previous = block;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _block(BuildContext context, NoteBlock block, TextStyle body) {
    final text = Theme.of(context).textTheme;
    Widget line(String value, {TextStyle? style}) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onEdit,
      child: RichLine(text: value, style: style ?? body, onLink: onLink),
    );
    Widget marked(Widget mark, String value) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 26, child: mark),
        Expanded(child: line(value)),
      ],
    );
    return switch (block) {
      ParagraphBlock(:final text) => line(text),
      HeadingBlock(:final level, text: final value) => line(
        value,
        style: (level == 1 ? text.titleLarge! : text.titleMedium!).copyWith(
          fontFamily: 'Unbounded',
          fontWeight: FontWeight.w700,
          fontSize: switch (level) { 1 => 21, 2 => 18, _ => 16 },
          height: 1.3,
          color: Tokens.onSurface,
        ),
      ),
      BulletBlock(text: final value) => marked(
        Padding(
          padding: const EdgeInsets.only(top: 10, left: 6),
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Tokens.onSurfaceVariant, shape: BoxShape.circle)),
          ),
        ),
        value,
      ),
      NumberedBlock(:final number, text: final value) => marked(
        Text('$number.', style: body.copyWith(color: Tokens.muted, fontFeatures: const [FontFeature.tabularFigures()])),
        value,
      ),
      CheckBlock(text: final value, :final done, line: final index) => InkWell(
        onTap: () => onToggle(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(symbolIcon(done ? 'check_box' : 'check_box_outline_blank', filled: done), size: 22, color: done ? Tokens.accent : Tokens.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichLine(
                  text: value,
                  style: body.copyWith(color: done ? Tokens.muted : Tokens.onSurface, decoration: done ? TextDecoration.lineThrough : null, decorationColor: Tokens.muted),
                  onLink: onLink,
                ),
              ),
            ],
          ),
        ),
      ),
      QuoteBlock(text: final value) => GestureDetector(
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.tile)),
          child: RichLine(text: value, style: body.copyWith(color: Tokens.onSurfaceVariant), onLink: onLink),
        ),
      ),
    };
  }
}

/// Строка со строчной разметкой: жирный, курсив, зачёркнутый, код, живые ссылки.
class RichLine extends StatefulWidget {
  const RichLine({super.key, required this.text, required this.style, required this.onLink});

  final String text;
  final TextStyle style;
  final ValueChanged<String> onLink;

  @override
  State<RichLine> createState() => _RichLineState();
}

class _RichLineState extends State<RichLine> {
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final tap in _taps) {
      tap.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final tap in _taps) {
      tap.dispose();
    }
    _taps.clear();
    final spans = <InlineSpan>[];
    for (final piece in parseInline(widget.text)) {
      final url = piece.url;
      TapGestureRecognizer? tap;
      if (url != null) {
        tap = TapGestureRecognizer()..onTap = () => widget.onLink(url);
        _taps.add(tap);
      }
      spans.add(
        TextSpan(
          text: piece.text,
          recognizer: tap,
          style: TextStyle(
            fontWeight: piece.bold ? FontWeight.w700 : null,
            fontStyle: piece.italic ? FontStyle.italic : null,
            decoration: piece.strike ? TextDecoration.lineThrough : (url != null ? TextDecoration.underline : null),
            decorationColor: url != null ? Tokens.onSurfaceVariant : null,
            fontFamily: piece.code ? 'monospace' : null,
            backgroundColor: piece.code ? Tokens.containerHigh : null,
          ),
        ),
      );
    }
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}
