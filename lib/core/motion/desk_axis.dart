import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Переход экранов на компьютере — общая ось M3: новый экран въезжает справа на
/// [_shift] точек и проявляется, прежний уходит на столько же влево и гаснет раньше,
/// чем проявится новый. Назад — то же в обратную сторону. На телефоне экран растёт из
/// карточки ([UnfoldPageTransitionsBuilder]); мышью растить не из чего, а пролёт через
/// весь широкий экран утомляет.
class DeskAxisTransitionsBuilder extends PageTransitionsBuilder {
  const DeskAxisTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _DeskAxis(animation: animation, secondary: secondaryAnimation, child: child);
}

const _shift = 30.0;

class _DeskAxis extends StatelessWidget {
  const _DeskAxis({required this.animation, required this.secondary, required this.child});

  final Animation<double> animation;
  final Animation<double> secondary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // анимация выключена в системе — только затухание, без сдвига
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return FadeTransition(opacity: animation, child: child);
    final slideIn = CurvedAnimation(parent: animation, curve: Motion.emphasizedDecelerate, reverseCurve: Motion.emphasizedAccelerate);
    final slideOut = CurvedAnimation(parent: secondary, curve: Motion.emphasizedDecelerate, reverseCurve: Motion.emphasizedAccelerate);
    // сквозное затухание: прежний гаснет в первой трети, новый проявляется в остальном,
    // два экрана не просвечивают друг сквозь друга
    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.3, 1, curve: Motion.emphasizedDecelerate),
      reverseCurve: const Interval(0.3, 1, curve: Motion.emphasizedAccelerate),
    );
    final fadeOut = CurvedAnimation(
      parent: secondary,
      curve: const Interval(0, 0.3, curve: Motion.emphasizedAccelerate),
      reverseCurve: const Interval(0, 0.3, curve: Motion.emphasizedDecelerate),
    );
    return FadeTransition(
      opacity: fadeIn,
      child: FadeTransition(
        opacity: ReverseAnimation(fadeOut),
        child: AnimatedBuilder(
          animation: Listenable.merge([slideIn, slideOut]),
          child: child,
          builder: (context, child) => Transform.translate(offset: Offset(_shift * (1 - slideIn.value) - _shift * slideOut.value, 0), child: child),
        ),
      ),
    );
  }
}
