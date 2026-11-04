import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../data/repositories/canvas_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/canvas_layout.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../../services/capture_service.dart';
import '../composer/panel_text.dart';

/// Мир холста: вещи лежат в нём со сдвигом, чтобы отрицательные координаты тоже помещались.
const _origin = 10000.0;
const _world = 20000.0;

/// Шаг точечной сетки на фоне.
const _dotStep = 32.0;

/// Ширина вещи, впервые попавшей на холст: картинка крупнее, текст уже.
double canvasDefaultWidth(ItemCard card) => card.thumbPath != null ? 260 : 220;

/// Высота по ширине: картинка в своей пропорции, текст и ссылка — карточкой чуть ниже квадрата.
double canvasHeight(ItemCard card, double width) => width * (card.thumbPath != null ? (card.thumbRatio ?? 1) : 0.8);

/// Холст как PureRef: вещи свободно на бесконечной точечной сетке. Тянешь — двигается,
/// угол — меняет размер, двойное касание открывает, щипок приближает.
/// Положение пишется в базу, когда палец отпущен.
class CanvasView extends ConsumerStatefulWidget {
  const CanvasView({super.key, required this.folderId, required this.cards, required this.onOpen, this.bottomInset = 0});

  final String folderId;
  final List<ItemCard> cards;
  final ValueChanged<String> onOpen;

  /// Низ холста закрыт строкой ввода: «уместить» показывает вещи выше неё.
  final double bottomInset;

  @override
  ConsumerState<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends ConsumerState<CanvasView> {
  final _transform = TransformationController();

  /// Положения, пока палец ещё ведёт вещь: база получит их при отпускании.
  final _moving = <String, CanvasSpot>{};
  final _placing = <String>{};
  Size _viewport = Size.zero;
  bool _fitted = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }


  List<CanvasBox> _boxes(Map<String, CanvasSpot> saved) => [
    for (final card in widget.cards)
      if (_moving[card.id] ?? saved[card.id] case final spot?) CanvasBox(itemId: card.id, x: spot.x, y: spot.y, width: spot.width, height: canvasHeight(card, spot.width)),
  ];

  /// Вещи без места на холсте встают справа от разложенных.
  void _placeMissing(Map<String, CanvasSpot> saved) {
    final missing = [
      for (final card in widget.cards)
        if (!saved.containsKey(card.id) && !_placing.contains(card.id)) card,
    ];
    if (missing.isEmpty) return;
    _placing.addAll(missing.map((card) => card.id));
    final placed = placeNew(_boxes(saved), [for (final card in missing) CanvasSize(itemId: card.id, width: canvasDefaultWidth(card), height: canvasHeight(card, canvasDefaultWidth(card)))]);
    ref
        .read(canvasRepositoryProvider)
        .saveAll(widget.folderId, {for (final box in placed) box.itemId: (x: box.x, y: box.y, width: box.width)})
        .whenComplete(() => _placing.removeAll(missing.map((card) => card.id)));
  }

  /// Показать всё разом: рамка вокруг вещей посередине экрана.
  void _fit(List<CanvasBox> boxes) {
    if (_viewport.isEmpty) return;
    if (boxes.isEmpty) {
      _transform.value = Matrix4.translationValues(-_origin + 24, -_origin + 24, 0);
      return;
    }
    final bounds = canvasBounds(boxes, margin: 24);
    final visible = Size(_viewport.width, max(120, _viewport.height - widget.bottomInset));
    final scale = min(visible.width / bounds.width, visible.height / bounds.height).clamp(0.1, 1.2);
    final dx = (visible.width - bounds.width * scale) / 2 - (_origin + bounds.left) * scale;
    final dy = (visible.height - bounds.height * scale) / 2 - (_origin + bounds.top) * scale;
    // масштаб по всем трём осям, как у InteractiveViewer: иначе getMaxScaleOnAxis видит 1
    _transform.value = Matrix4.translationValues(dx, dy, 0) * Matrix4.diagonal3Values(scale, scale, scale);
  }

  /// Записка прямо на холсте: заметка в этой папке там, куда сейчас смотрит экран.
  Future<void> _addNote() async {
    final text = await _askNote(context);
    if (text == null || !mounted) return;
    final center = _transform.toScene(_viewport.center(Offset.zero));
    final id = await ref.read(captureServiceProvider).capture(CaptureInput(text: text, forcedFolderId: widget.folderId));
    await ref.read(canvasRepositoryProvider).save(widget.folderId, id, (x: center.dx - _origin - 110, y: center.dy - _origin - 88, width: 220));
  }

  /// Тронутые вещи по порядку: последняя рисуется поверх остальных.
  final _front = <String>[];

  void _raise(String id) {
    if (_front.lastOrNull == id) return;
    _front
      ..remove(id)
      ..add(id);
  }

  /// Пальцы на холсте прямо сейчас.
  final _pointers = <int>{};

  /// Палец, который ведёт карточку: двигает её или тянет угол. Пока он есть,
  /// холст стоит; лёг второй палец — карточка отпускается, жест уходит масштабу.
  ({int pointer, String itemId, bool resize})? _hold;

  /// Вид холста в миг, когда палец взял карточку. Холст узнаёт о хватке только со
  /// следующим кадром, а палец успевает сдвинуться раньше: вид возвращается сюда.
  Matrix4? _heldView;

  /// Палец лёг на карточку. Тянуть её можно, только если он на холсте один.
  void _grab(ItemCard card, int pointer, {required bool resize}) {
    if (_hold != null || _pointers.isNotEmpty) return;
    _raise(card.id);
    _heldView = _transform.value.clone();
    setState(() => _hold = (pointer: pointer, itemId: card.id, resize: resize));
  }

  // сдвиг пальца приходит уже в координатах холста: делить на масштаб не нужно
  void _drag(ItemCard card, CanvasSpot from, int pointer, Offset delta) {
    final hold = _hold;
    if (hold == null || hold.pointer != pointer || hold.itemId != card.id) return;
    final current = _moving[card.id] ?? from;
    setState(
      () => _moving[card.id] = hold.resize
          ? (x: current.x, y: current.y, width: (current.width + delta.dx).clamp(80.0, 1600.0))
          : (x: current.x + delta.dx, y: current.y + delta.dy, width: current.width),
    );
  }

  /// Карточку отпустили: место пишется в базу.
  Future<void> _drop() async {
    final hold = _hold;
    if (hold == null) return;
    setState(() => _hold = null);
    final spot = _moving[hold.itemId];
    if (spot == null) return;
    await ref.read(canvasRepositoryProvider).save(widget.folderId, hold.itemId, spot);
    if (mounted) setState(() => _moving.remove(hold.itemId));
  }

  void _pointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    // второй палец: это щипок, карточку больше не тащим
    if (_pointers.length > 1) _drop();
  }

  void _pointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_hold?.pointer == event.pointer) _drop();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final saved = ref.watch(canvasSpotsProvider(widget.folderId)).value;
    final filesRoot = ref.watch(filesRootProvider);
    if (saved == null) return const SizedBox.expand();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _placeMissing(saved);
      // первый показ — всё целиком, но только когда места есть у всех вещей
      final boxes = _boxes(saved);
      if (!_fitted && !_viewport.isEmpty && boxes.length == widget.cards.length) {
        _fitted = true;
        _fit(boxes);
      }
    });
    final boxes = _boxes(saved);
    final cards = {for (final card in widget.cards) card.id: card};
    // нетронутые снизу в своём порядке, тронутые сверху — последняя выше всех
    final layered = [...boxes.where((box) => !_front.contains(box.itemId)), for (final id in _front) ...boxes.where((box) => box.itemId == id)];

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        return Stack(
          children: [
            // сетка рисуется в координатах экрана: точек ровно столько, сколько видно
            Positioned.fill(child: CustomPaint(painter: _DotsPainter(_transform))),
            // слушатель пальцев не отбирает жест у холста: он только считает пальцы
            Listener(
              onPointerDown: _pointerDown,
              onPointerUp: _pointerUp,
              onPointerCancel: _pointerUp,
              child: InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                minScale: 0.1,
                maxScale: 4,
                // палец ведёт карточку — холст под ним не едет
                panEnabled: _hold == null,
                onInteractionUpdate: (details) {
                  final held = _heldView;
                  if (_hold != null && details.pointerCount == 1 && held != null) _transform.value = held.clone();
                },
                boundaryMargin: const EdgeInsets.all(_world),
                child: SizedBox(
                  width: _world,
                  height: _world,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final box in layered)
                        if (cards[box.itemId] case final card?)
                          Positioned(
                            key: ValueKey(box.itemId),
                            left: _origin + box.x,
                            top: _origin + box.y,
                            width: box.width,
                            height: box.height,
                            child: _CanvasItem(
                              card: card,
                              filesRoot: filesRoot,
                              lifted: _hold?.itemId == card.id,
                              onOpen: () => widget.onOpen(card.id),
                              onGrab: (pointer, {required resize}) => _grab(card, pointer, resize: resize),
                              onDrag: (pointer, delta) => _drag(card, (x: box.x, y: box.y, width: box.width), pointer, delta),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: Space.screen,
              child: Column(
                children: [
                  // масштаб пилюлей: касание возвращает 100 %
                  ValueListenableBuilder(
                    valueListenable: _transform,
                    builder: (context, matrix, _) => _Tool(label: '${(matrix.getMaxScaleOnAxis() * 100).round()}%', tooltip: l.canvasFit, onTap: () => _fit(boxes)),
                  ),
                  const SizedBox(height: 8),
                  _Tool(icon: 'fit_screen', tooltip: l.canvasFit, onTap: () => _fit(boxes)),
                  const SizedBox(height: 8),
                  _Tool(icon: 'sticky_note_2', tooltip: l.canvasNote, onTap: _addNote),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CanvasItem extends StatelessWidget {
  const _CanvasItem({required this.card, required this.filesRoot, required this.lifted, required this.onOpen, required this.onGrab, required this.onDrag});

  final ItemCard card;
  final Directory filesRoot;
  final bool lifted;
  final VoidCallback onOpen;

  /// Палец лёг на карточку или на её угол.
  final void Function(int pointer, {required bool resize}) onGrab;

  /// Палец сдвинулся: сдвиг в координатах холста.
  final void Function(int pointer, Offset delta) onDrag;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final thumb = card.thumbPath;
    final Widget face = thumb != null
        ? Image.file(
            File(p.join(filesRoot.path, thumb)),
            fit: BoxFit.cover,
            cacheWidth: 900,
            errorBuilder: (_, _, _) => const ColoredBox(color: Tokens.containerHigh),
          )
        : Container(
            padding: const EdgeInsets.all(14),
            color: card.kind == ItemKind.note ? Tokens.containerHigh : Tokens.container,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (card.kind != ItemKind.note) ...[Icon(symbolIcon(kindIcon(card.kind)), size: 18, color: Tokens.muted), const SizedBox(height: 8)],
                Text(card.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                if (card.body.trim().isNotEmpty && card.body.trim() != card.title) ...[
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      card.body,
                      overflow: TextOverflow.fade,
                      style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          );

    // слушатели касаний, а не распознаватель перетаскивания: тот забирал бы палец
    // у холста, и щипок с пальцем на карточке не масштабировал бы
    return Listener(
      onPointerDown: (event) => onGrab(event.pointer, resize: false),
      onPointerMove: (event) => onDrag(event.pointer, event.localDelta),
      child: GestureDetector(
        onDoubleTap: onOpen,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: AnimatedScale(
                scale: lifted ? 1.02 : 1,
                duration: const Duration(milliseconds: 120),
                child: DecoratedBox(
                  // поднятая вещь обведена: видно, что именно тянешь
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.photo),
                    border: lifted ? Border.all(color: Tokens.accent, width: 2) : null,
                  ),
                  child: ClipRRect(borderRadius: BorderRadius.circular(Radii.photo), child: face),
                ),
              ),
            ),
            // угол: тянешь — вещь растёт с теми же пропорциями
            Positioned(
              right: -6,
              bottom: -6,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                // угол глубже карточки и слышит палец первым: дальше карточка его уже не возьмёт
                onPointerDown: (event) => onGrab(event.pointer, resize: true),
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Tokens.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Tokens.background, width: 2),
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

class _Tool extends StatelessWidget {
  const _Tool({required this.tooltip, required this.onTap, this.icon, this.label});

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

/// Точки сетки, сдвинутые и растянутые вместе с холстом.
class _DotsPainter extends CustomPainter {
  _DotsPainter(this.transform) : super(repaint: transform);

  final TransformationController transform;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = transform.value;
    final scale = matrix.getMaxScaleOnAxis();
    var step = _dotStep * scale;
    // сильно отдалили — точки реже, иначе фон рябит
    while (step < 14) {
      step *= 2;
    }
    final offset = Offset(matrix.getTranslation().x % step, matrix.getTranslation().y % step);
    final paint = Paint()..color = Tokens.outline;
    final radius = (1.4 * scale).clamp(0.8, 2.0);
    for (var x = offset.dx; x < size.width; x += step) {
      for (var y = offset.dy; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => oldDelegate.transform != transform;
}

Future<String?> _askNote(BuildContext context) {
  final l = L.of(context);
  final field = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: field,
                autofocus: true,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: l.canvasNoteHint),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(context, field.text.trim().isEmpty ? null : field.text.trim()), child: Text(l.canvasNote)),
            ],
          ),
        ),
      ),
    ),
  );
}
