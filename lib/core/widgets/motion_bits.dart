import 'dart:math';

import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

// Движение двигает и проявляет готовый слой: FadeTransition и MatrixTransition не
// перерисовывают содержимое на каждом кадре, поэтому на телефоне кадры не пропускаются.

/// Пружина перелетает за единицу, прозрачность так не умеет — обрезаем.
class UnitClamp extends Animatable<double> {
  const UnitClamp();

  @override
  double transform(double t) => t.clamp(0.0, 1.0);
}

/// Панель и плашка, как rp-in и rp-out в макете: появляется снизу на 28 точек из
/// 95% размера с пружинкой, уходит вниз на 16 точек к 98% и тает.
Widget riseTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation.drive(const UnitClamp()),
    child: MatrixTransition(
      animation: animation,
      alignment: Alignment.bottomCenter,
      onTransform: (t) {
        final leaving = animation.status == AnimationStatus.reverse;
        final shift = (leaving ? 16 : 28) * (1 - t);
        final scale = leaving ? 0.98 + 0.02 * t : 0.95 + 0.05 * t;
        return Matrix4.translationValues(0, shift, 0)..scaleByDouble(scale, scale, 1, 1);
      },
      child: child,
    ),
  );
}

/// Значок, как pop в макете: выпрыгивает из 40% с поворотом на −40°.
Widget popTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation.drive(const UnitClamp()),
    child: MatrixTransition(
      animation: animation,
      onTransform: (t) {
        final scale = 0.4 + 0.6 * t;
        return Matrix4.rotationZ(-40 * pi / 180 * (1 - t))..scaleByDouble(scale, scale, 1, 1);
      },
      child: child,
    ),
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
    return FadeTransition(
      opacity: _value,
      child: MatrixTransition(
        animation: _value,
        onTransform: (t) {
          final scale = 0.97 + 0.03 * t;
          return Matrix4.translationValues(0, 14 * (1 - t), 0)..scaleByDouble(scale, scale, 1, 1);
        },
        child: widget.child,
      ),
    );
  }
}

/// Край, который тает в цвет фона: наложенный градиент вместо маски. Маска
/// перерисовывает слой на каждом кадре и рвёт анимацию, градиент почти бесплатен.
class EdgeFade extends StatelessWidget {
  const EdgeFade({super.key, required this.color, this.toRight = false, this.toTop = false});

  final Color color;

  /// Тает к правому краю: строка листается вбок.
  final bool toRight;

  /// Тает к верху: список листается вверх.
  final bool toTop;

  @override
  Widget build(BuildContext context) {
    final (begin, end) = toTop ? (Alignment.bottomCenter, Alignment.topCenter) : (Alignment.centerLeft, Alignment.centerRight);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: begin, end: end, colors: [color.withValues(alpha: 0), color]),
        ),
      ),
    );
  }
}
