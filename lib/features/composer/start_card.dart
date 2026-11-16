import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../domain/hints.dart';
import '../../l10n/app_localizations.dart';

const _stepIcons = {
  StartStep.stow: 'edit',
  StartStep.search: 'search',
  StartStep.remind: 'alarm',
  StartStep.folder: 'folder',
  StartStep.tag: 'sell',
  StartStep.commands: 'bolt',
  StartStep.finish: 'celebration',
};

/// Сколько шагов знакомства с делом (без финальной карточки).
const startStepCount = 6;

String startStepText(L l, StartStep step) => switch (step) {
  StartStep.stow => l.startStow,
  StartStep.search => l.startSearch,
  StartStep.remind => l.startRemind,
  StartStep.folder => l.startFolder,
  StartStep.tag => l.startTag,
  StartStep.commands => l.startCommands,
  StartStep.finish => l.startFinish,
};

/// Карточка шага знакомства над строкой главной: значок, одна фраза, «Попробовать» и «×».
/// Точки снизу — сколько шагов пройдено; у финальной их нет.
class StartCard extends StatelessWidget {
  const StartCard({super.key, required this.step, required this.onSkip, this.onTry});

  final StartStep step;
  final VoidCallback onSkip;

  /// Вставить пример в строку; null — кнопки нет (первый шаг и финал).
  final VoidCallback? onTry;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final finish = step == StartStep.finish;
    return Container(
      key: ValueKey('start-${step.name}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(24)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Tokens.accent.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(symbolIcon(_stepIcons[step]!), size: 20, color: Tokens.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(startStepText(l, step), style: text.titleSmall!.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3)),
                if (onTry != null) ...[
                  const SizedBox(height: 10),
                  Material(
                    color: Tokens.containerHigh,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: const ValueKey('start-try'),
                      onTap: onTry,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(symbolIcon('touch_app'), size: 18, color: Tokens.onSurface),
                            const SizedBox(width: 6),
                            Text(l.startTry, style: text.labelLarge!.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (!finish) ...[
                  const SizedBox(height: 12),
                  // точки шагов: пройденные и нынешний — акцентом
                  Row(
                    children: [
                      for (var i = 0; i < startStepCount; i++)
                        Container(
                          width: i == step.index ? 16 : 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: i <= step.index ? Tokens.accent : Tokens.outline.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('start-skip'),
            tooltip: l.startSkip,
            onPressed: onSkip,
            icon: Icon(symbolIcon('close'), size: 20, color: Tokens.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
