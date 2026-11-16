import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../core/theme/tokens.dart';
import 'code_block_view.dart';

/// Формула `$$…$$` своей строкой: по центру, широкая листается вбок. Формулу, которую
/// разбор не понял, показывает исходником в блоке кода с подписью LaTeX — как Obsidian
/// показывает ошибку, только без красного текста посреди заметки.
class MathBlockView extends StatelessWidget {
  const MathBlockView({super.key, required this.tex, this.onTap});

  final String tex;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final broken = _broken(tex);
    if (broken) return CodeBlockView(code: tex, language: 'latex', onTap: onTap);
    return GestureDetector(
      key: const ValueKey('math-block'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ConstrainedBox(
            // узкая — по центру строки, широкая — с левого края и вбок
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Center(
              child: Math.tex(tex, mathStyle: MathStyle.display, textStyle: TextStyle(fontSize: 18, color: Tokens.onSurface)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Формула внутри строки текста, по базовой линии. Не поняли — исходник моноширинным.
Widget inlineMath(String tex, TextStyle style) => Math.tex(
  tex,
  mathStyle: MathStyle.text,
  textStyle: style.copyWith(fontSize: (style.fontSize ?? 16) * 1.05),
  onErrorFallback: (_) => Text(r'$' '$tex' r'$', style: style.copyWith(fontFamily: 'monospace', color: Tokens.onSurfaceVariant)),
);

// разбор KaTeX ловится заранее: блок-исходник выглядит лучше, чем ошибка внутри формулы
bool _broken(String tex) {
  try {
    return Math.tex(tex).parseError != null;
  } on Object {
    return true;
  }
}
