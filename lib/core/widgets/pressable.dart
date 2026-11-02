import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// Отклик на нажатие, как в макете: короткий толчок — сжался и вернулся за 0,26 с.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.pressedScale = 0.96});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Насколько сжимается в самой глубокой точке толчка.
  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _tap() {
    _pulse.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    // до самой глубокой точки — 40% времени, обратно — остальное
    final scale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: widget.pressedScale).chain(CurveTween(curve: Motion.emphasized)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: widget.pressedScale, end: 1.0).chain(CurveTween(curve: Motion.emphasized)),
        weight: 60,
      ),
    ]).animate(_pulse);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap == null ? null : _tap,
      onLongPress: widget.onLongPress,
      child: ScaleTransition(scale: scale, child: widget.child),
    );
  }
}
