import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/providers.dart';

/// Полоска на карточке, пока файл вещи ложится во вложения. Пропала — файл на
/// месте целиком, оригинал можно удалять. Ход виден, кто бы ни копировал: это
/// окно, фон или окно «Поделиться».
class CopyingBar extends ConsumerWidget {
  const CopyingBar({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fraction = ref.watch(copyFractionProvider(itemId)).value ?? 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Tokens.onSurface.withValues(alpha: 0.22)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: ColoredBox(color: Tokens.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка с полоской копирования поверх нижнего края.
class WithCopyingBar extends StatelessWidget {
  const WithCopyingBar({super.key, required this.itemId, required this.copying, required this.child});

  final String itemId;
  final bool copying;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!copying) return child;
    return Stack(
      children: [
        child,
        Positioned(left: 14, right: 14, bottom: 6, child: CopyingBar(itemId: itemId)),
      ],
    );
  }
}
