import 'package:flutter/material.dart';

import '../theme/shapes.dart';

/// Значок папки или тега: иконка на фигуре M3 Expressive.
class ShapeBadge extends StatelessWidget {
  const ShapeBadge({super.key, required this.shape, required this.size, required this.child, this.color});

  final BadgeShape shape;
  final double size;
  final Widget child;

  /// Заливка фигуры, по умолчанию графит темы.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? Theme.of(context).colorScheme.secondaryContainer;
    return SizedBox.square(
      dimension: size,
      child: ClipPath(
        clipper: BadgeShapeClipper(shape),
        child: ColoredBox(
          color: fill,
          child: Center(child: child),
        ),
      ),
    );
  }
}
