import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';

/// Заметка на полосе: где её карточка во всей ленте (от верха прокрутки) и цвет точки.
typedef ScrubMark = ({double top, double height, Color color});

/// День (или «Закреплено») во всей ленте: с какой высоты начинается, как называется и
/// в каких цветах его заметки.
typedef ScrubSection = ({double y, String name, String date, List<Color> colors});

/// Снимок ленты на миг удержания: всё, что нужно полосе, в координатах прокрутки и экрана.
class ScrubMap {
  const ScrubMap({
    required this.marks,
    required this.sections,
    required this.railX,
    required this.trackX,
    required this.viewTop,
    required this.viewHeight,
    required this.trackTop,
    required this.trackBottom,
    required this.dotTop,
    required this.dotBottom,
    required this.dotEdge,
  });

  final List<ScrubMark> marks;
  final List<ScrubSection> sections;

  /// Ось ленты по горизонтали на экране.
  final double railX;

  /// Полоса у самого края, левее заголовков дней: ось съезжает к ней.
  final double trackX;

  /// Окно прокрутки на экране.
  final double viewTop;
  final double viewHeight;

  /// Полоса по высоте экрана: под строкой состояния и над строкой ввода.
  final double trackTop;
  final double trackBottom;

  /// Точка у карточки: не выше заголовка, у низа, но над строкой ввода — как в самой ленте.
  final double dotTop;
  final double dotBottom;
  final double dotEdge;

  double get trackHeight => trackBottom - trackTop;

  /// Где точка заметки сейчас на экране, если лента прокручена на [pixels].
  double dotOnScreen(ScrubMark mark, double pixels) {
    final top = mark.top - pixels + viewTop;
    return top + math.max(dotTop, math.min(mark.height - dotBottom, dotEdge - top));
  }
}

/// Удержание оси ленты: палец ведёт, полоса прокручивает и называет день.
class ScrubSession extends ChangeNotifier {
  ScrubSession(this.fingerY);

  double fingerY;
  bool released = false;

  void move(double y) {
    fingerY = y;
    notifyListeners();
  }

  void release() {
    released = true;
    notifyListeners();
  }
}

/// Ширина капсулы, в которую раздувается ось.
const _capsule = 10.0;

/// Плашка дня держится чуть выше пальца: так палец её не закрывает.
const _bubbleLift = 56.0;

/// Ось ленты, ставшая полосой быстрой прокрутки. Пунктир сливается и раздувается в капсулу,
/// точки заметок ложатся в неё — видна вся лента разом в цветах папок, — светлое окошко
/// показывает видимую часть, у пальца плашка с днём. Отпустили — точки возвращаются к карточкам.
/// Касания полоса не берёт: палец ведёт удержание на самой оси.
class TimelineScrubber extends StatefulWidget {
  const TimelineScrubber({super.key, required this.map, required this.position, required this.session, required this.rail, required this.onGone});

  final ScrubMap map;
  final ScrollPosition position;
  final ScrubSession session;

  /// Насколько видна настоящая ось ленты: гаснет, пока её место занимает полоса.
  final ValueNotifier<double> rail;

  /// Полоса снова стала осью: можно убрать.
  final VoidCallback onGone;

  @override
  State<TimelineScrubber> createState() => _TimelineScrubberState();
}

class _TimelineScrubberState extends State<TimelineScrubber> with SingleTickerProviderStateMixin {
  late final _morph = AnimationController(vsync: this, duration: const Duration(milliseconds: 250), reverseDuration: Motion.short);
  late final _shown = CurvedAnimation(parent: _morph, curve: Motion.emphasizedDecelerate, reverseCurve: Motion.emphasizedAccelerate);
  int _section = 0;

  // куда листают: новая надпись въезжает с той стороны, куда идёт палец
  var _down = true;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_follow);
    widget.position.addListener(_repaint);
    _shown.addListener(_fadeRail);
    _section = _sectionAt(_share);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      MediaQuery.disableAnimationsOf(context) ? _morph.value = 1 : _morph.forward().ignore();
    });
  }

  @override
  void dispose() {
    widget.session.removeListener(_follow);
    widget.position.removeListener(_repaint);
    _shown.removeListener(_fadeRail);
    _shown.dispose();
    _morph.dispose();
    super.dispose();
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  // точки полосы и есть точки ленты: настоящие гаснут ровно настолько, насколько те улетели
  void _fadeRail() => widget.rail.value = 1 - _shown.value.clamp(0.0, 1.0);

  double get _total => widget.position.maxScrollExtent + widget.position.viewportDimension;

  /// Доля ленты под пальцем: верх полосы — начало, низ — самый старый день.
  double get _share => ((widget.session.fingerY - widget.map.trackTop) / widget.map.trackHeight).clamp(0.0, 1.0);

  /// Палец на полосе — та же доля ленты в середине экрана.
  void _follow() {
    final session = widget.session;
    if (session.released) {
      session.removeListener(_follow);
      if (MediaQuery.disableAnimationsOf(context)) return widget.onGone();
      _morph.reverse().then((_) => widget.onGone()).ignore();
      return;
    }
    final position = widget.position;
    final share = _share;
    position.jumpTo((share * _total - position.viewportDimension / 2).clamp(0.0, position.maxScrollExtent));
    final section = _sectionAt(share);
    if (section != _section) {
      _down = section > _section;
      _section = section;
      HapticFeedback.selectionClick();
    }
    setState(() {});
  }

  /// День под пальцем: последний, чьё начало на полосе выше пальца.
  int _sectionAt(double share) {
    final line = share * _total;
    var found = 0;
    for (final (index, section) in widget.map.sections.indexed) {
      if (section.y <= line) found = index;
    }
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final map = widget.map;
    final sections = map.sections;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _shown,
        builder: (context, _) {
          final shown = _shown.value.clamp(0.0, 1.0);
          final fingerY = widget.session.fingerY.clamp(map.trackTop, map.trackBottom);
          return Stack(
            key: const ValueKey('timeline-scrubber'),
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScrubPainter(
                    shown: shown,
                    map: map,
                    pixels: widget.position.pixels,
                    total: _total,
                    fingerY: fingerY,
                    scrim: Tokens.background,
                    rail: Tokens.outline,
                    capsule: Tokens.containerHighest,
                    window: Tokens.onSurface,
                  ),
                ),
              ),
              if (sections.isNotEmpty)
                Positioned(
                  left: map.trackX + _capsule / 2 + 12,
                  top: (fingerY - _bubbleLift - 22).clamp(map.trackTop - 8, map.trackBottom - 44),
                  child: Opacity(
                    opacity: shown,
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * shown,
                      alignment: Alignment.centerLeft,
                      child: _DayBubble(section: sections[_section.clamp(0, sections.length - 1)], index: _section, down: _down),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Плашка дня у пальца: контрастная, как подсказка. День, дата и точки папок этого дня;
/// день сменился — надпись прокручивается барабаном в сторону движения пальца.
class _DayBubble extends StatelessWidget {
  const _DayBubble({required this.section, required this.index, required this.down});

  final ScrubSection section;
  final int index;
  final bool down;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ink = Tokens.background;
    final current = ValueKey(index);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Tokens.onSurface, borderRadius: BorderRadius.circular(22)),
      child: AnimatedSize(
        duration: Motion.short,
        curve: Motion.emphasized,
        alignment: Alignment.centerLeft,
        child: ClipRect(
          child: AnimatedSwitcher(
            duration: Motion.short,
            switchInCurve: Motion.emphasizedDecelerate,
            switchOutCurve: Motion.emphasizedAccelerate,
            layoutBuilder: (shown, gone) => Stack(alignment: Alignment.centerLeft, children: [...gone, ?shown]),
            transitionBuilder: (child, animation) {
              // новая надпись приходит снизу, когда листают вниз; старая уходит наверх
              final incoming = child.key == current;
              final from = (incoming ? 1 : -1) * (down ? 0.7 : -0.7);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: Tween(begin: Offset(0, from), end: Offset.zero).animate(animation), child: child),
              );
            },
            child: Row(
              key: current,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(section.name, style: text.titleMedium!.copyWith(color: ink, fontWeight: FontWeight.w700)),
                if (section.date.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(section.date, style: text.bodyMedium!.copyWith(color: ink.withValues(alpha: 0.7))),
                ],
                if (section.colors.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  for (final color in section.colors.take(6))
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 3),
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrubPainter extends CustomPainter {
  _ScrubPainter({
    required this.shown,
    required this.map,
    required this.pixels,
    required this.total,
    required this.fingerY,
    required this.scrim,
    required this.rail,
    required this.capsule,
    required this.window,
  });

  /// 0 — обычная ось ленты, 1 — полоса.
  final double shown;
  final ScrubMap map;
  final double pixels;
  final double total;
  final double fingerY;
  final Color scrim;
  final Color rail;
  final Color capsule;
  final Color window;

  double _onTrack(double y) => map.trackTop + y / total * map.trackHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final t = shown;
    // ось съезжает к краю экрана, на место полосы
    final x = lerpDouble(map.railX, map.trackX, t)!;
    // лента отходит на второй план, полоса остаётся в фокусе
    canvas.drawRect(Offset.zero & size, Paint()..color = scrim.withValues(alpha: 0.5 * t));

    // пунктир сливается: промежутки уходят за первую треть, потом линия раздувается в капсулу
    final merge = (t / 0.35).clamp(0.0, 1.0);
    final width = lerpDouble(1.5, _capsule, Curves.easeOut.transform(t))!;
    final fill = Color.lerp(rail, capsule, merge)!;
    final gap = 4.5 * (1 - merge);
    if (gap > 0.3) {
      final line = Paint()
        ..color = fill.withValues(alpha: fill.a * merge)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      final dash = 2.5 + 4.5 * merge;
      for (var y = map.trackTop; y < map.trackBottom; y += dash + gap) {
        canvas.drawLine(Offset(x, y), Offset(x, math.min(y + dash, map.trackBottom)), line);
      }
    } else {
      final half = width / 2;
      canvas.drawRRect(
        RRect.fromLTRBR(x - half, map.trackTop - half, x + half, map.trackBottom + half, Radius.circular(half)),
        Paint()..color = fill,
      );
    }

    // окошко видимой части: светлая вставка в капсуле
    final inner = math.max(0.0, width / 2 - 2);
    if (inner > 0) {
      final top = _onTrack(pixels);
      final bottom = math.max(_onTrack(pixels + map.viewHeight), top + inner * 2);
      canvas.drawRRect(
        RRect.fromLTRBR(x - inner, top, x + inner, bottom, Radius.circular(inner)),
        Paint()..color = window.withValues(alpha: 0.3 * t),
      );
    }

    // точки слетаются с карточек в капсулу; у пальца крупнее, как под лупой
    final ring = Color.lerp(scrim, capsule, t)!;
    for (final mark in map.marks) {
      final y = lerpDouble(map.dotOnScreen(mark, pixels), _onTrack(mark.top + mark.height - map.dotBottom), t)!;
      final near = (1 - (y - fingerY).abs() / 44).clamp(0.0, 1.0);
      final scale = 1 + 0.5 * Curves.easeOut.transform(near) * t;
      final center = Offset(x, y);
      canvas.drawCircle(center, lerpDouble(6, 4, t)! * scale, Paint()..color = ring);
      canvas.drawCircle(center, lerpDouble(3.5, 2.75, t)! * scale, Paint()..color = mark.color);
    }
  }

  @override
  bool shouldRepaint(_ScrubPainter old) => true;
}
