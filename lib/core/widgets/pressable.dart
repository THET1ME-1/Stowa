import 'package:flutter/widgets.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Всё, на что можно нажать без кнопки: карточки, пилюли, плитки.
///
/// Мышь над ним — рука вместо стрелки, а сам он плавно приподнимается на [lift] точек и
/// чуть светлеет, как плитка в макете сайта. Нажатие вдавливает его до [pressedScale] сразу
/// под пальцем или кнопкой мыши и отпускает мягко. До него доходит Tab, Enter и пробел
/// нажимают; фокус с клавиатуры виден рамкой. Подсветка и рамка идут по скруглению
/// [radius]; без него — только подъём. Человек выключил анимацию в системе — всё без движения.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.pressedScale = 0.96, this.radius, this.lift = 2});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Насколько сжимается в самой глубокой точке нажатия.
  final double pressedScale;

  /// Скругление того, что внутри: по нему светлеет при наведении и рисуется рамка фокуса.
  final BorderRadius? radius;

  /// На сколько точек приподнимается под мышью.
  final double lift;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with TickerProviderStateMixin {
  late final AnimationController _hover = AnimationController(vsync: this, duration: Motion.short, reverseDuration: Motion.medium);
  late final AnimationController _press = AnimationController(vsync: this, duration: Motion.tap, reverseDuration: const Duration(milliseconds: 260));
  bool _focused = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void dispose() {
    _hover.dispose();
    _press.dispose();
    super.dispose();
  }

  void _down() {
    if (widget.onTap != null) _press.forward();
  }

  // короткий щелчок не успевает вдавить: дожать до дна и только потом отпустить,
  // иначе отклика не видно
  void _release() => _press.forward().whenCompleteOrCancel(() {
    if (mounted) _press.reverse();
  });

  void _tap() {
    _release();
    widget.onTap?.call();
  }

  void _hovering(bool on) {
    if (!_enabled) return;
    on ? _hover.forward() : _hover.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final radius = widget.radius;
    final animated = AnimatedBuilder(
      animation: Listenable.merge([_hover, _press]),
      child: widget.child,
      builder: (context, child) {
        // фокус с клавиатуры поднимает так же, как мышь: видно, где ты
        final hover = _focused ? 1.0 : Motion.emphasized.transform(_hover.value);
        final press = Motion.emphasized.transform(_press.value);
        Widget out = child!;
        if (radius != null) {
          out = DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              color: Tokens.onSurface.withValues(alpha: 0.05 * hover + 0.05 * press),
              border: _focused ? Border.all(color: Tokens.onSurface.withValues(alpha: 0.85), width: 2) : null,
            ),
            child: out,
          );
        }
        if (still) return out;
        return Transform.translate(
          offset: Offset(0, -widget.lift * hover * (1 - press)),
          child: Transform.scale(scale: 1 - (1 - widget.pressedScale) * press, child: out),
        );
      },
    );
    // наведение — своей областью: подсветка детектора ждёт режима «мышь», и первое
    // наведение после касания пропадало бы
    return FocusableActionDetector(
      enabled: _enabled,
      mouseCursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (on) => setState(() => _focused = on),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (widget.onTap != null) _tap();
            return null;
          },
        ),
      },
      child: MouseRegion(
        onEnter: (_) => _hovering(true),
        onExit: (_) => _hovering(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onTap == null ? null : (_) => _down(),
          onTapCancel: widget.onTap == null ? null : () => _press.reverse(),
          onTap: widget.onTap == null ? null : _tap,
          onLongPress: widget.onLongPress,
          child: animated,
        ),
      ),
    );
  }
}
