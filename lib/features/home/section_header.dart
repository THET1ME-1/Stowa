import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';

/// Заголовок раздела главной: «Только что», «Папки».
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 20, Space.screen - 6, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(title, style: text.titleSmall!.copyWith(color: Tokens.onSurfaceVariant))),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: Tokens.muted,
                minimumSize: const Size(44, 32),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: text.labelMedium!.copyWith(fontSize: 14),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(action!),
                Icon(symbolIcon('chevron_right'), size: 18),
              ]),
            ),
        ],
      ),
    );
  }
}
