import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Прежний переход Stowa: экран въезжает справа. Им идут экраны, которым
/// расти не из чего, — открытые уведомлением, ссылкой или кодом, а не касанием.
class StowaSlideTransitionsBuilder extends PageTransitionsBuilder {
  const StowaSlideTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Duration get reverseTransitionDuration => Motion.medium;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  );
}
