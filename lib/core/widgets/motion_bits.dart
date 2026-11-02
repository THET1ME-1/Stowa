import 'dart:math';

import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// Панель и плашка, как rp-in и rp-out в макете: появляется снизу на 28 точек из
/// 95% размера с пружинкой, уходит вниз на 16 точек к 98% и тает.
Widget riseTransition(Widget child, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final leaving = animation.status == AnimationStatus.reverse;
      final t = animation.value;
      final shift = (leaving ? 16 : 28) * (1 - t);
      final scale = leaving ? 0.98 + 0.02 * t : 0.95 + 0.05 * t;
      return Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, shift),
          child: Transform.scale(scale: scale, alignment: Alignment.bottomCenter, child: child),
        ),
      );
    },
  );
}

/// Значок, как pop в макете: выпрыгивает из 40% с поворотом на −40°.
Widget popTransition(Widget child, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final t = animation.value;
      return Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: -40 * pi / 180 * (1 - t),
          child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
        ),
      );
    },
  );
}

/// Появление, как rw-in в макете: снизу на 14 точек из 97% за 0,36 с с замедлением.
/// [delay] — номер в лесенке, по 26 мс на шаг.
class RiseIn extends StatefulWidget {
  const RiseIn({super.key, required this.child, this.delay = 0, this.duration = const Duration(milliseconds: 360)});

  final Widget child;
  final int delay;
  final Duration duration;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  // задержка лесенки — пустой кусок в начале той же анимации, без таймеров
  late final int _wait = 26 * widget.delay;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration + Duration(milliseconds: _wait),
  );
  late final Animation<double> _value = CurvedAnimation(
    parent: _controller,
    curve: Interval(_wait / (widget.duration.inMilliseconds + _wait), 1, curve: Motion.emphasizedDecelerate),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _value,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _value.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - _value.value)),
          child: Transform.scale(scale: 0.97 + 0.03 * _value.value, child: child),
        ),
      ),
    );
  }
}
