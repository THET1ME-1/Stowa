import 'package:flutter/material.dart';

import '../icons/icon_registry.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Переключатель, как .seg в макете: выбранное — белая пилюля, крайние сегменты
/// скруглены снаружи, внутренние стыки почти прямые.
class PillSegments<T> extends StatelessWidget {
  const PillSegments({super.key, required this.options, required this.selected, required this.onChanged, this.height = 44});

  final List<({T value, String label, String? icon})> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final round = Radius.circular(height / 2);
    const tight = Radius.circular(8);
    return Row(
      children: [
        for (final (index, option) in options.indexed) ...[
          if (index > 0) const SizedBox(width: 2),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option.value),
              child: AnimatedContainer(
                duration: Motion.short,
                height: height,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: option.value == selected ? Tokens.accent : Tokens.containerHigh,
                  borderRadius: option.value == selected
                      ? BorderRadius.all(round)
                      : BorderRadius.horizontal(left: index == 0 ? round : tight, right: index == options.length - 1 ? round : tight),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (option.icon != null) ...[
                      Icon(symbolIcon(option.icon), size: 19, color: option.value == selected ? Tokens.onAccent : Tokens.onSurfaceVariant),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge!.copyWith(fontSize: 14, color: option.value == selected ? Tokens.onAccent : Tokens.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
