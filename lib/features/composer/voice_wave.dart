import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Волна записи голоса: палочка на замер громкости, свежая справа.
/// В узкой строке остаются последние: старые уходят за левый край.
class VoiceWave extends StatelessWidget {
  const VoiceWave({super.key, required this.levels});

  /// Громкость от 0 до 1, от старой к свежей.
  final List<double> levels;

  static const _bar = 3.0;
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: LayoutBuilder(
        builder: (context, box) {
          final fits = (box.maxWidth / (_bar + _gap)).floor().clamp(0, levels.length);
          return Row(
            children: [
              for (final level in levels.sublist(levels.length - fits))
                Padding(
                  padding: const EdgeInsets.only(right: _gap),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    width: _bar,
                    height: 5 + level * 25,
                    decoration: BoxDecoration(color: Tokens.onSurfaceVariant, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
