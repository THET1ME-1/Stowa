import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';

/// Белая плашка над строкой: что легло, и «Отменить», пока не поздно.
class SavedToast extends StatelessWidget {
  const SavedToast({super.key, required this.message, required this.undoLabel, required this.onUndo});

  final String message;
  final String undoLabel;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        Icon(symbolIcon('check_circle', filled: true), size: 20, color: Tokens.onAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium!.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: Tokens.onAccent),
          ),
        ),
        TextButton(
          onPressed: onUndo,
          style: TextButton.styleFrom(
            foregroundColor: Tokens.onAccent,
            textStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w700),
          ),
          child: Text(undoLabel),
        ),
      ]),
    );
  }
}
