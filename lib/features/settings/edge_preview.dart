import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../domain/edge_settings.dart';
import '../../domain/spine_colors.dart';

/// Подложка корешков — тот же графит, что рисует `EdgeHandle.kt`, в любой теме.
const _backing = Color(0xFF141517);

/// Вид корешков, который можно плавно перевести в другой: край, размер подложки в точках,
/// заметность. [right] — 1 справа, 0 слева, между ними корешки перетекают с края на край.
class SpineLook {
  const SpineLook({required this.right, required this.width, required this.height, required this.alpha});

  factory SpineLook.of(EdgeSettings settings) => SpineLook(
    right: settings.side == EdgeSide.right ? 1 : 0,
    width: settings.size.width,
    height: settings.size.height,
    alpha: settings.alpha / 100,
  );

  final double right;
  final double width;
  final double height;
  final double alpha;

  SpineLook lerp(SpineLook to, double t) => SpineLook(
    right: lerpDouble(right, to.right, t)!,
    width: lerpDouble(width, to.width, t)!,
    height: lerpDouble(height, to.height, t)!,
    alpha: lerpDouble(alpha, to.alpha, t)!,
  );
}

class _LookTween extends Tween<SpineLook> {
  _LookTween({super.end});

  @override
  SpineLook lerp(double t) => begin!.lerp(end!, t);
}

/// Подложка с корешками в [rect] — раскладка `EdgeHandle.onDraw`: поля 5 и 7 точек, зазор 4,
/// скругление корешка 4, у подложки 10 и только со стороны экрана. [unit] — пикселей в точке
/// вдоль корешков, [across] — поперёк (схемы утолщают корешки, не раздувая зазоров).
void paintSpineHandle(
  Canvas canvas,
  Rect rect, {
  required bool right,
  required List<Spine> spines,
  required double alpha,
  required double unit,
  double? across,
}) {
  if (alpha <= 0.004 || spines.isEmpty) return;
  final wide = across ?? unit;
  final outer = Radius.circular(math.min(10 * wide, rect.width * 0.7));
  final shape = right
      ? RRect.fromRectAndCorners(rect, topLeft: outer, bottomLeft: outer)
      : RRect.fromRectAndCorners(rect, topRight: outer, bottomRight: outer);
  canvas.drawRRect(shape, Paint()..color = _backing.withValues(alpha: alpha * 0.86));
  final padX = 5 * wide;
  final padY = 7 * unit;
  final gap = 4 * unit;
  final total = math.max(spines.fold<double>(0, (sum, spine) => sum + spine.weight), 0.001);
  final room = rect.height - padY * 2 - gap * (spines.length - 1);
  var top = rect.top + padY;
  for (final spine in spines) {
    final length = room * spine.weight / total;
    final bar = RRect.fromLTRBR(rect.left + padX, top, rect.right - padX, top + length, Radius.circular(math.min(4 * wide, length / 2)));
    canvas.drawRRect(bar, Paint()..color = spine.color.withValues(alpha: alpha));
    top += length + gap;
  }
}

/// Предпросмотр «Под рукой»: слева весь телефон — у какого края и на какой высоте корешки,
/// справа лупа в настоящий размер — какие они: цвета закреплённых заметок, толщина, заметность.
/// Высоту меняют, ведя пальцем по телефону; правка уходит одна, когда палец отпущен.
class EdgePreview extends StatefulWidget {
  const EdgePreview({
    super.key,
    required this.settings,
    required this.spines,
    required this.screen,
    required this.heightLabel,
    required this.onHeight,
  });

  final EdgeSettings settings;
  final List<Spine> spines;

  /// Экран этого телефона в точках: по нему считается место корешков, как у службы.
  final Size screen;

  /// «выше», «посередине», «ниже» — по высоте.
  final String Function(int height) heightLabel;

  final ValueChanged<int> onHeight;

  @override
  State<EdgePreview> createState() => _EdgePreviewState();
}

class _EdgePreviewState extends State<EdgePreview> {
  static const _tall = 272.0;
  static const _bezel = 5.0;

  /// Высота под пальцем, пока его ведут; отпустили — ждём, пока настройка её подтвердит.
  double? _drag;
  int? _pending;

  @override
  void didUpdateWidget(EdgePreview old) {
    super.didUpdateWidget(old);
    if (_pending != null && widget.settings.height == _pending) {
      _pending = null;
      _drag = null;
    }
  }

  double get _height => _drag ?? widget.settings.height.toDouble();

  /// Сколько пикселей телефона проходят корешки от самого верха до самого низа.
  double _rangePx(double phoneHeight) {
    final screen = widget.screen;
    final box = spineBox(screen, widget.settings.copyWith(height: 0));
    final lowest = spineBox(screen, widget.settings.copyWith(height: 100));
    return (lowest.top - box.top) * (phoneHeight - _bezel * 2) / screen.height;
  }

  void _move(double dy, double phoneHeight) {
    final range = _rangePx(phoneHeight);
    if (range <= 0) return;
    final next = (_height + dy / range * 100).clamp(0.0, 100.0);
    // щелчок на крае хода: дальше корешки не уедут
    if ((next == 0 || next == 100) && next != _height) HapticFeedback.selectionClick();
    setState(() => _drag = next);
  }

  void _release() {
    final value = _drag?.round();
    if (value == null) return;
    if (value == widget.settings.height) {
      setState(() => _drag = null);
      return;
    }
    _pending = value;
    widget.onHeight(value);
  }

  void _step(int delta) => widget.onHeight((widget.settings.height + delta).clamp(0, 100));

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final screen = widget.screen;
    final phoneWidth = (_tall * screen.width / screen.height).clamp(96.0, 168.0);
    final height = _height;
    final label = widget.heightLabel(height.round());

    return TweenAnimationBuilder<SpineLook>(
      tween: _LookTween(end: SpineLook.of(widget.settings)),
      duration: still ? Duration.zero : Motion.medium,
      curve: Motion.emphasized,
      builder: (context, look, _) => SizedBox(
        height: _tall,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              slider: true,
              label: label,
              value: '${height.round()} %',
              increasedValue: '${(height.round() + 10).clamp(0, 100)} %',
              decreasedValue: '${(height.round() - 10).clamp(0, 100)} %',
              onIncrease: () => _step(10),
              onDecrease: () => _step(-10),
              child: GestureDetector(
                key: const ValueKey('edge-preview'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) => setState(() => _drag = _height),
                onVerticalDragUpdate: (details) => _move(details.delta.dy, _tall),
                onVerticalDragEnd: (_) => _release(),
                onVerticalDragCancel: _release,
                child: SizedBox(
                  width: phoneWidth,
                  child: CustomPaint(
                    painter: _PhonePainter(
                      look: look,
                      height: height,
                      dragging: _drag != null && _pending == null,
                      spines: widget.spines,
                      screen: screen,
                      enabled: widget.settings.enabled,
                      body: Tokens.containerHighest,
                      wallTop: Tokens.background,
                      wallBottom: Tokens.containerLow,
                      ink: Tokens.onSurface,
                      accent: Tokens.accent,
                      onAccent: Tokens.onAccent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(
                  painter: _LoupePainter(
                    look: look,
                    spines: widget.spines,
                    enabled: widget.settings.enabled,
                    wallTop: Tokens.background,
                    wallBottom: Tokens.containerLow,
                    ink: Tokens.onSurface,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AnimatedSwitcher(
                        duration: still ? Duration.zero : Motion.short,
                        child: Text(
                          label,
                          key: ValueKey(label),
                          style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Tokens.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Телефон целиком: рамка, обои в цвет темы, значки рабочего стола и корешки на своём месте.
class _PhonePainter extends CustomPainter {
  _PhonePainter({
    required this.look,
    required this.height,
    required this.dragging,
    required this.spines,
    required this.screen,
    required this.enabled,
    required this.body,
    required this.wallTop,
    required this.wallBottom,
    required this.ink,
    required this.accent,
    required this.onAccent,
  });

  final SpineLook look;
  final double height;
  final bool dragging;
  final List<Spine> spines;
  final Size screen;
  final bool enabled;
  final Color body;
  final Color wallTop;
  final Color wallBottom;
  final Color ink;
  final Color accent;
  final Color onAccent;

  @override
  void paint(Canvas canvas, Size size) {
    const bezel = _EdgePreviewState._bezel;
    final frame = Offset.zero & size;
    canvas.drawRRect(RRect.fromRectAndRadius(frame, const Radius.circular(24)), Paint()..color = body);
    final glass = frame.deflate(bezel);
    final glassShape = RRect.fromRectAndRadius(glass, const Radius.circular(19));
    canvas.save();
    canvas.clipRRect(glassShape);
    canvas.drawRect(
      glass,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [wallTop, wallBottom]).createShader(glass),
    );

    final unit = glass.height / screen.height;
    // вырез камеры
    final island = Rect.fromCenter(center: Offset(glass.center.dx, glass.top + 14 * unit + 3), width: glass.width * 0.26, height: 7);
    canvas.drawRRect(RRect.fromRectAndRadius(island, const Radius.circular(4)), Paint()..color = const Color(0xFF000000).withValues(alpha: 0.7));

    // значки рабочего стола: сетка 4 × 5 и док внизу
    final icon = glass.width * 0.14;
    final columnGap = (glass.width - icon * 4) / 5;
    final iconPaint = Paint()..color = ink.withValues(alpha: 0.075);
    for (var row = 0; row < 5; row++) {
      for (var column = 0; column < 4; column++) {
        final left = glass.left + columnGap + column * (icon + columnGap);
        final top = glass.top + glass.height * 0.13 + row * (icon + columnGap * 1.35);
        canvas.drawRRect(RRect.fromLTRBR(left, top, left + icon, top + icon, Radius.circular(icon * 0.3)), iconPaint);
      }
    }
    final dock = Rect.fromLTWH(glass.left + columnGap * 0.55, glass.bottom - icon - columnGap * 2.2, glass.width - columnGap * 1.1, icon + columnGap * 1.3);
    canvas.drawRRect(RRect.fromRectAndRadius(dock, Radius.circular(icon * 0.45)), Paint()..color = ink.withValues(alpha: 0.05));
    for (var column = 0; column < 4; column++) {
      final left = glass.left + columnGap + column * (icon + columnGap);
      final top = dock.center.dy - icon / 2;
      canvas.drawRRect(RRect.fromLTRBR(left, top, left + icon, top + icon, Radius.circular(icon * 0.3)), iconPaint);
    }

    // корешки: середина — где у службы (`spineBox`); сами чуть толще и длиннее настоящих,
    // иначе на маленьком телефоне их не найти. Как они выглядят на деле, показывает лупа
    final margin = ((screen.height - look.height) / 2).clamp(0.0, 80.0);
    final room = math.max(screen.height - margin * 2 - look.height, 0.0);
    final middle = glass.top + (margin + room * height / 100 + look.height / 2) * unit;
    const thicker = 2.2;
    const longer = 1.25;
    final width = look.width * unit * thicker;
    final tall = look.height * unit * longer;
    final top = (middle - tall / 2).clamp(glass.top + 4, glass.bottom - tall - 4);
    final alpha = look.alpha * (enabled ? 1 : 0.35);

    // ход корешков вдоль края, пока их ведут пальцем
    if (dragging) {
      final guide = Paint()
        ..color = ink.withValues(alpha: 0.28)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final x = look.right >= 0.5 ? glass.right - width - 5 : glass.left + width + 5;
      final first = glass.top + (margin + look.height / 2) * unit;
      final last = glass.top + (screen.height - margin - look.height / 2) * unit;
      canvas.drawLine(Offset(x, first), Offset(x, last), guide);
    }

    final along = unit * longer;
    final across = unit * thicker;
    paintSpineHandle(canvas, Rect.fromLTWH(glass.right - width, top, width, tall), right: true, spines: spines, alpha: alpha * look.right, unit: along, across: across);
    paintSpineHandle(canvas, Rect.fromLTWH(glass.left, top, width, tall), right: false, spines: spines, alpha: alpha * (1 - look.right), unit: along, across: across);

    // ручка рядом с корешками: их можно тянуть вверх и вниз
    final handleX = look.right >= 0.5 ? glass.right - width - 14 : glass.left + width + 14;
    _grip(canvas, Offset(handleX, top + tall / 2), dragging);
    canvas.restore();
  }

  /// Капсула цвета акцента со стрелками вверх и вниз; пока тянут — крупнее.
  void _grip(Canvas canvas, Offset center, bool active) {
    final scale = active ? 1.15 : 1.0;
    final pill = RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 15 * scale, height: 26 * scale), const Radius.circular(8));
    canvas.drawRRect(pill, Paint()..color = accent);
    final arrow = Paint()
      ..color = onAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final direction in [-1.0, 1.0]) {
      final tip = center + Offset(0, direction * 7 * scale);
      final path = Path()
        ..moveTo(tip.dx - 3.5 * scale, tip.dy - direction * 3 * scale)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + 3.5 * scale, tip.dy - direction * 3 * scale);
      canvas.drawPath(path, arrow);
    }
  }

  @override
  bool shouldRepaint(_PhonePainter old) =>
      old.look != look ||
      old.height != height ||
      old.dragging != dragging ||
      old.spines != spines ||
      old.enabled != enabled ||
      old.body != body ||
      old.ink != ink ||
      old.accent != accent;
}

/// Лупа: край экрана крупно, корешки в полтора раза больше настоящих — видно цвета и толщину.
class _LoupePainter extends CustomPainter {
  _LoupePainter({required this.look, required this.spines, required this.enabled, required this.wallTop, required this.wallBottom, required this.ink});

  final SpineLook look;
  final List<Spine> spines;
  final bool enabled;
  final Color wallTop;
  final Color wallBottom;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas.drawRect(
      area,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [wallTop, wallBottom]).createShader(area),
    );
    // до подписи внизу — место под корешки; самые крупные помещаются целиком
    final usable = size.height - 52;
    final unit = math.min(1.6, usable / SpineSize.large.height);
    final width = look.width * unit;
    final tall = look.height * unit;
    final top = (usable - tall) / 2 + 8;
    final alpha = look.alpha * (enabled ? 1 : 0.35);

    // строки чужого приложения под корешками: так видно, что это край экрана
    final lines = Paint()..color = ink.withValues(alpha: 0.07);
    for (var row = 0; row < 7; row++) {
      final y = 22.0 + row * 26;
      if (y > usable) break;
      final short = row.isOdd ? 0.55 : 0.8;
      final from = look.right >= 0.5 ? 16.0 : size.width * (1 - short) - 16;
      canvas.drawRRect(RRect.fromLTRBR(from, y, from + size.width * short - 32, y + 9, const Radius.circular(5)), lines);
    }

    paintSpineHandle(canvas, Rect.fromLTWH(size.width - width, top, width, tall), right: true, spines: spines, alpha: alpha * look.right, unit: unit);
    paintSpineHandle(canvas, Rect.fromLTWH(0, top, width, tall), right: false, spines: spines, alpha: alpha * (1 - look.right), unit: unit);
  }

  @override
  bool shouldRepaint(_LoupePainter old) => old.look != look || old.spines != spines || old.enabled != enabled || old.ink != ink;
}
