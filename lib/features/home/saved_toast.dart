import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';

/// Белая плашка над строкой: что случилось и действие, пока не поздно.
class SavedToast extends StatelessWidget {
  const SavedToast({super.key, required this.icon, required this.message, this.actionLabel, this.onAction});

  final String icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(28)),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(color: Tokens.graphite, shape: BoxShape.circle),
          child: Icon(symbolIcon(icon), size: 20, color: Tokens.onSurface),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium!.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: Tokens.onAccent),
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFE2E2DF),
              foregroundColor: Tokens.onAccent,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
              textStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w600),
            ),
            child: Text(actionLabel!),
          ),
        ],
      ]),
    );
  }
}
