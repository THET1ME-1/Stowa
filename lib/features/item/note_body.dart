import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../domain/note_blocks.dart';

const _markWidth = 32.0;

/// Текст заметки на странице вещи: абзацы, заголовки, списки, галочки, цитаты.
/// Касание по тексту открывает правку, по галочке — отмечает дело, по ссылке — открывает её.
class NoteBody extends StatelessWidget {
  const NoteBody({super.key, required this.blocks, required this.onToggle, required this.onEdit, required this.onLink, this.image});

  final List<NoteBlock> blocks;
  final ValueChanged<int> onToggle;
  final VoidCallback onEdit;
  final ValueChanged<String> onLink;

  /// Картинка между абзацами по имени из `![[имя]]`. Нет — тихая плашка с именем файла.
  final Widget Function(String name)? image;

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
        // одна колонка для точки, номера и галочки: текст пунктов начинается ровно
        SizedBox(width: _markWidth, child: mark),
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
            child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Tokens.onSurfaceVariant, shape: BoxShape.circle)),
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
              SizedBox(
                width: _markWidth,
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Icon(symbolIcon(done ? 'check_box' : 'check_box_outline_blank', filled: done), size: 22, color: done ? Tokens.accent : Tokens.onSurfaceVariant),
                  ),
                ),
              ),
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
      ImageBlock(:final name) => image?.call(name) ?? MissingImage(name: name),
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

/// Картинка из текста, которой нет среди вложений (ещё копируется или файл убрали):
/// значок и имя файла, текст вокруг не прыгает.
class MissingImage extends StatelessWidget {
  const MissingImage({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.tile)),
      child: Row(
        children: [
          Icon(symbolIcon('image'), size: 20, color: Tokens.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Tokens.muted)),
          ),
        ],
      ),
    );
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
