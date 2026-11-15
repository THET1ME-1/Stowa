import 'package:flutter/material.dart';

import '../icons/icon_registry.dart';
import '../theme/tokens.dart';

/// «+2» в углу фото: у заметки ещё файлы, кроме показанного. Одного файла — метки нет.
class FileCountBadge extends StatelessWidget {
  const FileCountBadge({super.key, required this.count});

  /// Сколько всего файлов у заметки.
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    return Positioned(
      right: 10,
      bottom: 10,
      child: Container(
        key: const ValueKey('file-count'),
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: Tokens.containerLowest.withValues(alpha: 0.78), borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(symbolIcon('photo_library'), size: 16, color: Tokens.onSurface),
            const SizedBox(width: 4),
            Text('+${count - 1}', style: Theme.of(context).textTheme.labelMedium!.copyWith(color: Tokens.onSurface)),
          ],
        ),
      ),
    );
  }
}
