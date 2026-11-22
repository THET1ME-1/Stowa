import 'dart:async';
import 'dart:math';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../core/clipboard/paste_router.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/desk_mode.dart';
import '../../core/widgets/pressable.dart';
import '../../domain/json_canvas.dart' show CanvasSide;
import '../../l10n/app_localizations.dart';
import '../composer/smart_punctuation.dart';

/// Общее у двух холстов — папки (`CanvasView`) и файла `.canvas` (`CanvasFileScreen`):
/// мышь, колесо, клавиши, точки-выходы, стрелки, сетка, кнопки. Поменял здесь —
/// поменялось у обоих, поэтому управление у них одно и то же.

const canvasMinScale = 0.08;
const canvasMaxScale = 4.0;

/// Колесо, масштаб и клавиши масштаба. Состоянию остаётся сказать, как «уместить всё».
mixin CanvasControls<T extends StatefulWidget> on State<T> {
  final transform = TransformationController();

  /// Ключ слоя холста на экране: в его координатах курсор колеса.
  final canvasKey = GlobalKey();
  final canvasFocus = FocusNode(debugLabel: 'canvas');
  Size viewport = Size.zero;

  /// Показать всё разом (Shift+1 и кнопка).
  void fitAll();

  /// Файлы встают карточками: первый — в точку экрана [at], остальные лесенкой.
  /// Так ложатся и брошенные мышью из системы, и вставленные из буфера.
  Future<void> placeFiles(List<XFile> files, Offset at);

  // где мышь была над холстом последний раз — туда встаёт вставленная картинка
  Offset? _pointerAt;
  PasteRouter? _paste;

  /// Холст принимает вставку из буфера (Ctrl+V): открыли его, коснулись, дали фокус —
  /// картинка из буфера встаёт карточкой туда, где мышь, без мыши — посередине.
  void listenPaste(PasteRouter router) {
    _paste = router;
    _claimPaste();
    canvasFocus.addListener(() {
      if (canvasFocus.hasFocus) _claimPaste();
    });
  }

  void _claimPaste() => _paste?.claim(this, (files) => placeFiles(files, _pointerAt ?? viewport.center(Offset.zero)), shown: () => shownOnScreen(this));

  /// Мышь или палец над холстом: состояние зовёт из слушателя холста на нажатие и наведение.
  void trackPointer(PointerEvent event) {
    _pointerAt = localOf(event.position) ?? _pointerAt;
    if (event is PointerDownEvent) _claimPaste();
  }

  @override
  void dispose() {
    _paste?.release(this);
    canvasFocus.dispose();
    transform.dispose();
    super.dispose();
  }

  Offset? localOf(Offset global) {
    final box = canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  /// Колесо листает холст, Shift+колесо — вбок, Ctrl+колесо (и щипок тачпада в браузере)
  /// масштабирует вокруг курсора: как в Figma и холсте Obsidian.
  void canvasSignal(PointerSignalEvent event) {
    // браузер отдаёт Ctrl+колесо масштабом exp(Δ/200) — у просмотрщика это скачок в 65 %
    // и масштабирует сам, мимо очереди сигналов: наш шаг встаёт поверх его, когда он закончит
    if (event is PointerScaleEvent) {
      final focal = localOf(event.position);
      if (focal == null) return;
      zoomAround(event.scale.clamp(1 / 1.18, 1.18), focal);
      final target = transform.value.clone();
      scheduleMicrotask(() => transform.value = target);
      return;
    }
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scroll = event as PointerScrollEvent;
      final keyboard = HardwareKeyboard.instance;
      if (keyboard.isControlPressed || keyboard.isMetaPressed) {
        final focal = localOf(scroll.position);
        // щелчок колеса (100 точек) — около 18 %: мягко, без скачков; браузеры шлют щелчок
        // разной величины, поэтому шаг не больше 18 % за событие
        if (focal != null) zoomAround(exp(-scroll.scrollDelta.dy / 600).clamp(1 / 1.18, 1.18), focal);
        return;
      }
      final delta = keyboard.isShiftPressed && scroll.scrollDelta.dx == 0 ? Offset(scroll.scrollDelta.dy, 0) : scroll.scrollDelta;
      transform.value = Matrix4.translationValues(-delta.dx, -delta.dy, 0) * transform.value;
    });
  }

  /// Приблизить в [factor] раз так, что точка экрана [focal] остаётся на месте.
  void zoomAround(double factor, Offset focal) {
    final now = transform.value.getMaxScaleOnAxis();
    final next = (now * factor).clamp(canvasMinScale, canvasMaxScale);
    final step = next / now;
    // масштаб по всем трём осям, как у InteractiveViewer: иначе getMaxScaleOnAxis видит 1
    transform.value = Matrix4.translationValues(focal.dx, focal.dy, 0) * Matrix4.diagonal3Values(step, step, step) * Matrix4.translationValues(-focal.dx, -focal.dy, 0) * transform.value;
  }

  /// `+`, `-`, Ctrl+0 (100 %), Shift+1 (всё). Взял клавишу — true.
  bool zoomKey(KeyEvent event) {
    final key = event.physicalKey;
    final keyboard = HardwareKeyboard.instance;
    final center = viewport.center(Offset.zero);
    final VoidCallback? zoom = switch (key) {
      PhysicalKeyboardKey.equal || PhysicalKeyboardKey.numpadAdd => () => zoomAround(1.25, center),
      PhysicalKeyboardKey.minus || PhysicalKeyboardKey.numpadSubtract => () => zoomAround(0.8, center),
      PhysicalKeyboardKey.digit0 when keyboard.isControlPressed || keyboard.isMetaPressed => () => zoomAround(1 / transform.value.getMaxScaleOnAxis(), center),
      PhysicalKeyboardKey.digit1 when keyboard.isShiftPressed => fitAll,
      _ => null,
    };
    zoom?.call();
    return zoom != null;
  }
}

/// Нажата клавиша, а не отпущена (повтор при удержании тоже считается).
bool isKeyPress(KeyEvent event) => event is KeyDownEvent || event is KeyRepeatEvent;

/// Delete и Backspace от раскладки не зависят: по смыслу клавиши надёжнее.
bool isDeleteKey(KeyEvent event) => event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace;

/// Стрелка: сдвиг выбранного на 10, с Shift — на 50. Не стрелка — null.
Offset? arrowShift(KeyEvent event) {
  final step = HardwareKeyboard.instance.isShiftPressed ? 50.0 : 10.0;
  return switch (event.physicalKey) {
    PhysicalKeyboardKey.arrowLeft => Offset(-step, 0),
    PhysicalKeyboardKey.arrowRight => Offset(step, 0),
    PhysicalKeyboardKey.arrowUp => Offset(0, -step),
    PhysicalKeyboardKey.arrowDown => Offset(0, step),
    _ => null,
  };
}

/// Нажали мышью на карточку: Shift — добавить или снять, без Shift — выбрать её одну
/// (если она уже среди выбранных — оставить всех: их сейчас потащат вместе).
void selectOnMouse(Set<String> selected, String id) {
  if (HardwareKeyboard.instance.isShiftPressed) {
    if (!selected.remove(id)) selected.add(id);
  } else if (!selected.contains(id)) {
    selected
      ..clear()
      ..add(id);
  }
}

/// Точки-выходы карточки: середины четырёх сторон и куда из них смотрит провод.
List<(CanvasSide, Offset, Offset)> canvasSockets(Rect rect) => [
  (CanvasSide.left, rect.centerLeft, const Offset(-1, 0)),
  (CanvasSide.right, rect.centerRight, const Offset(1, 0)),
  (CanvasSide.top, rect.topCenter, const Offset(0, -1)),
  (CanvasSide.bottom, rect.bottomCenter, const Offset(0, 1)),
];

/// Сторона карточки [rect], ближайшая к точке [point]: в неё входит провод.
CanvasSide sideFacing(Rect rect, Offset point) {
  final delta = point - rect.center;
  if (delta.dx.abs() / max(1, rect.width) >= delta.dy.abs() / max(1, rect.height)) return delta.dx >= 0 ? CanvasSide.right : CanvasSide.left;
  return delta.dy >= 0 ? CanvasSide.bottom : CanvasSide.top;
}

/// Точки-выходы вокруг карточки под мышью. Одного размера на экране при любом масштабе.
/// Ключ точки — `socket-<id>-<сторона>`.
List<Widget> canvasSocketDots({required String id, required Rect rect, required ValueListenable<Matrix4> view, required void Function(CanvasSide side, Offset point, Offset normal) onStart}) => [
  for (final (side, point, normal) in canvasSockets(rect))
    Positioned(
      left: point.dx,
      top: point.dy,
      child: ValueListenableBuilder(
        valueListenable: view,
        builder: (context, matrix, child) => Transform.scale(scale: 1 / matrix.getMaxScaleOnAxis(), alignment: Alignment.topLeft, child: child),
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: SizedBox(
            key: ValueKey('socket-$id-${side.name}'),
            width: 22,
            height: 22,
            child: Listener(
              onPointerDown: (event) {
                if (event.kind == PointerDeviceKind.mouse) onStart(side, point, normal);
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.precise,
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: Tokens.accent, shape: BoxShape.circle, border: Border.all(color: Tokens.background, width: 2)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
];

/// Рамка выбора: мягкая подложка цвета акцента.
Widget canvasMarquee(Rect rect) => Positioned.fromRect(
  rect: rect,
  child: IgnorePointer(
    child: DecoratedBox(decoration: BoxDecoration(color: Tokens.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6))),
  ),
);

/// Стрелка холста — кривая Безье от стороны одной карточки к стороне другой, как провод
/// между нодами в Blender. Координаты — мира холста.
class CanvasLink {
  const CanvasLink(
    this.from,
    this.to,
    this.start,
    this.c1,
    this.c2,
    this.end, {
    this.key,
    this.selected = false,
    this.arrow = true,
    this.backArrow = false,
    this.color,
    this.written = false,
  });

  /// Между карточками: выходят стороны, которые смотрят друг на друга.
  factory CanvasLink.between(String from, String to, Rect a, Rect b, {bool selected = false, bool written = false}) {
    final delta = b.center - a.center;
    final across = delta.dx.abs() >= delta.dy.abs();
    final (start, out) = across ? (delta.dx >= 0 ? (a.centerRight, const Offset(1, 0)) : (a.centerLeft, const Offset(-1, 0))) : (delta.dy >= 0 ? (a.bottomCenter, const Offset(0, 1)) : (a.topCenter, const Offset(0, -1)));
    final (end, into) = across ? (delta.dx >= 0 ? (b.centerLeft, const Offset(-1, 0)) : (b.centerRight, const Offset(1, 0))) : (delta.dy >= 0 ? (b.topCenter, const Offset(0, -1)) : (b.bottomCenter, const Offset(0, 1)));
    final reach = max(40.0, (end - start).distance * 0.4);
    return CanvasLink(from, to, start, start + out * reach, end + into * reach, end, selected: selected, written: written);
  }

  /// Провод, который тянут мышью: из выхода к курсору.
  factory CanvasLink.wire(String from, Offset start, Offset normal, Offset end) {
    final reach = max(40.0, (end - start).distance * 0.4);
    return CanvasLink(from, '', start, start + normal * reach, end, end, arrow: false);
  }

  final String from;
  final String to;
  final Offset start;
  final Offset c1;
  final Offset c2;
  final Offset end;

  /// Своё имя стрелки (у холста-файла — id стрелки в файле).
  final String? key;
  final bool selected;

  /// Наконечник у конца; без него — точка (провод в руке).
  final bool arrow;

  /// Наконечник и у начала (стрелка в обе стороны в Obsidian).
  final bool backArrow;

  /// Свой цвет стрелки; без него — цвет холста.
  final Color? color;

  /// Связь из текста `[[…]]`: выбрать и снять клавишей её нельзя, только правкой заметки.
  final bool written;

  CanvasLink lit() => CanvasLink(from, to, start, c1, c2, end, key: key, selected: true, arrow: arrow, backArrow: backArrow, color: color, written: written);

  Offset point(double t) {
    final u = 1 - t;
    return start * (u * u * u) + c1 * (3 * u * u * t) + c2 * (3 * u * t * t) + end * (t * t * t);
  }

  /// Середина кривой: за неё удобно взяться щелчком.
  Offset get middle => point(0.5);

  /// Точка [world] ближе [reach] к кривой.
  bool near(Offset world, double reach) {
    for (var step = 0; step <= 32; step++) {
      if ((point(step / 32) - world).distance <= reach) return true;
    }
    return false;
  }
}

/// Рисует стрелки холста: кривая и наконечник у конца, выбранная — цветом акцента и толще.
class CanvasLinksPainter extends CustomPainter {
  CanvasLinksPainter(this.links, {required this.ink, required this.accent, this.view}) : super(repaint: view);

  final List<CanvasLink> links;
  final Color ink;
  final Color accent;

  /// Вид холста: толщина линий и наконечник одни на экране при любом масштабе.
  final ValueListenable<Matrix4>? view;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = 1 / (view?.value.getMaxScaleOnAxis() ?? 1);
    for (final link in links) {
      final color = link.selected ? accent : link.color ?? ink;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = (link.selected ? 3.5 : 2.5) * unit
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(link.start.dx, link.start.dy)
        ..cubicTo(link.c1.dx, link.c1.dy, link.c2.dx, link.c2.dy, link.end.dx, link.end.dy);
      canvas.drawPath(path, paint);
      if (!link.arrow) {
        canvas.drawCircle(link.end, 5 * unit, Paint()..color = color);
        continue;
      }
      _head(canvas, link.end, link.end - link.point(0.96), color, unit);
      if (link.backArrow) _head(canvas, link.start, link.start - link.point(0.04), color, unit);
    }
  }

  // наконечник по касательной у конца
  void _head(Canvas canvas, Offset tip, Offset along, Color color, double unit) {
    final direction = along.distance == 0 ? const Offset(1, 0) : along / along.distance;
    final side = Offset(-direction.dy, direction.dx);
    final back = direction * 12 * unit, wide = side * 6 * unit;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((tip - back + wide).dx, (tip - back + wide).dy)
        ..lineTo((tip - back - wide).dx, (tip - back - wide).dy)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(CanvasLinksPainter old) => old.links != links || old.ink != ink || old.accent != accent;
}

/// Точки сетки, сдвинутые и растянутые вместе с холстом.
class CanvasDotsPainter extends CustomPainter {
  CanvasDotsPainter(this.transform, {this.step = 32}) : super(repaint: transform);

  final TransformationController transform;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = transform.value;
    final scale = matrix.getMaxScaleOnAxis();
    var gap = step * scale;
    // сильно отдалили — точки реже, иначе фон рябит
    while (gap < 14) {
      gap *= 2;
    }
    final offset = Offset(matrix.getTranslation().x % gap, matrix.getTranslation().y % gap);
    final paint = Paint()..color = Tokens.outline;
    final radius = (1.4 * scale).clamp(0.8, 2.0);
    for (var x = offset.dx; x < size.width; x += gap) {
      for (var y = offset.dy; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CanvasDotsPainter oldDelegate) => oldDelegate.transform != transform || oldDelegate.step != step;
}

/// Кнопка в столбике справа сверху: значок или надпись (масштаб).
class CanvasTool extends StatelessWidget {
  const CanvasTool({super.key, required this.tooltip, required this.onTap, this.icon, this.label});

  final String? icon;
  final String? label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        pressedScale: 0.9,
        onTap: onTap,
        child: Container(
          height: 44,
          constraints: const BoxConstraints(minWidth: 44),
          padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(22)),
          child: label != null
              ? Text(label!, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 13, fontFeatures: const [FontFeature.tabularFigures()]))
              : Icon(symbolIcon(icon!), size: 22, color: Tokens.onSurface),
        ),
      ),
    );
  }
}

/// Столбик кнопок холста: масштаб пилюлей (касание — всё целиком), «уместить», «записка»
/// и свои кнопки холста ниже.
class CanvasTools extends StatelessWidget {
  const CanvasTools({super.key, required this.view, required this.onFit, required this.onNote, this.more = const []});

  final ValueListenable<Matrix4> view;
  final VoidCallback onFit;
  final VoidCallback? onNote;
  final List<Widget> more;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      children: [
        ValueListenableBuilder(
          valueListenable: view,
          builder: (context, matrix, _) => CanvasTool(label: '${(matrix.getMaxScaleOnAxis() * 100).round()}%', tooltip: l.canvasFit, onTap: onFit),
        ),
        const SizedBox(height: 8),
        CanvasTool(icon: 'fit_screen', tooltip: l.canvasFit, onTap: onFit),
        if (onNote != null) ...[const SizedBox(height: 8), CanvasTool(key: const ValueKey('canvas-note'), icon: 'sticky_note_2', tooltip: l.canvasNote, onTap: onNote!)],
        for (final one in more) ...[const SizedBox(height: 8), one],
      ],
    );
  }
}

/// Лист записки: текст новой заметки, которая встанет на холст.
Future<String?> askCanvasNote(BuildContext context) {
  final l = L.of(context);
  final field = TextEditingController();
  return showStowaSheet<String>(
    context,
    maxHeightFactor: null,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('canvas-note-field'),
                controller: field,
                autofocus: true,
                minLines: 2,
                maxLines: 6,
                inputFormatters: [TextInputFormatter.withFunction(smartPunctuation)],
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: l.canvasNoteHint),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('canvas-note-done'),
                onPressed: () => Navigator.pop(context, field.text.trim().isEmpty ? null : field.text.trim()),
                child: Text(l.canvasNote),
              ),
            ],
          ),
        ),
    ),
  );
}

/// Файлы из системы, брошенные мышью на холст: пока их несут — мягкая рамка с подсказкой,
/// отпустили — [onFiles] с файлами (папки пропускаются) и точкой в координатах [child].
class CanvasDropZone extends StatefulWidget {
  const CanvasDropZone({super.key, required this.onFiles, required this.child, this.enabled = true});

  final void Function(List<DropItem> files, Offset at) onFiles;
  final Widget child;
  final bool enabled;

  @override
  State<CanvasDropZone> createState() => _CanvasDropZoneState();
}

class _CanvasDropZoneState extends State<CanvasDropZone> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DropTarget(
      enable: widget.enabled,
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: (details) {
        setState(() => _over = false);
        final files = [for (final file in details.files) if (file is! DropItemDirectory) file];
        if (files.isNotEmpty) widget.onFiles(files, details.localPosition);
      },
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _over ? 1 : 0,
                duration: Motion.medium,
                curve: Motion.emphasized,
                child: Container(
                  key: const ValueKey('canvas-drop'),
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Tokens.accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(Radii.tile),
                    border: Border.all(color: Tokens.accent.withValues(alpha: 0.5), width: 2),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
                    decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: BorderRadius.circular(100)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(symbolIcon('upload_file'), size: 20, color: Tokens.onSurface),
                        const SizedBox(width: 10),
                        Flexible(child: Text(L.of(context).canvasDropHint, style: text.labelLarge)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
