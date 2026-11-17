import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/widgets/file_count_badge.dart';
import '../../core/widgets/file_picture.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../data/repositories/canvas_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/canvas_layout.dart';
import '../../domain/note_links.dart' show shownTitle;
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../../services/capture_service.dart';
import '../composer/panel_text.dart';
import '../composer/smart_punctuation.dart';
import '../../core/widgets/undo_snack.dart';
import '../item/adult_veil.dart';
import '../item/item_actions.dart' show showItemActions;

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

  final _focus = FocusNode(debugLabel: 'canvas');

  @override
  void dispose() {
    _focus.dispose();
    _transform.dispose();
    super.dispose();
  }

  // ——— мышь и клавиатура (компьютер, браузер); на телефоне этого не происходит ———

  final _stack = GlobalKey();

  /// Карточки, выбранные мышью: щелчком, Shift+щелчком или рамкой. Их двигают стрелки
  /// и перетаскивание, убирает Delete. Пальцем не выбираются: у телефона нет клавиатуры,
  /// а касание — это перетаскивание.
  final _selected = <String>{};

  /// Рамка выбора (Shift+тянуть по пустому месту), в координатах мира холста.
  Rect? _marquee;
  Offset? _marqueeStart;

  // щелчок попал в карточку: тот же щелчок по пустому месту выбор не снимает
  bool _cardHit = false;

  Offset? _local(Offset global) {
    final box = _stack.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  /// Колесо листает холст, Shift+колесо — вбок, Ctrl+колесо (и щипок тачпада в браузере)
  /// масштабирует вокруг курсора: как в Figma и холсте Obsidian.
  void _signal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scroll = event as PointerScrollEvent;
      final keyboard = HardwareKeyboard.instance;
      if (keyboard.isControlPressed || keyboard.isMetaPressed) {
        final focal = _local(scroll.position);
        // щелчок колеса (100 точек) — около 18 %: мягко, без скачков
        if (focal != null) _zoom(exp(-scroll.scrollDelta.dy / 600), focal);
        return;
      }
      final delta = keyboard.isShiftPressed && scroll.scrollDelta.dx == 0 ? Offset(scroll.scrollDelta.dy, 0) : scroll.scrollDelta;
      _transform.value = Matrix4.translationValues(-delta.dx, -delta.dy, 0) * _transform.value;
    });
  }

  /// Приблизить в [factor] раз так, что точка экрана [focal] остаётся на месте.
  void _zoom(double factor, Offset focal) {
    final now = _transform.value.getMaxScaleOnAxis();
    final next = (now * factor).clamp(0.1, 4.0);
    final step = next / now;
    _transform.value = Matrix4.translationValues(focal.dx, focal.dy, 0) * Matrix4.diagonal3Values(step, step, step) * Matrix4.translationValues(-focal.dx, -focal.dy, 0) * _transform.value;
  }

  /// Клавиши холста: доходят сюда, когда фокус у холста (щёлкнули по нему мышью). Холст
  /// забирает их себе: иначе стрелка заодно увела бы фокус в поле ввода.
  KeyEventResult _onFocusKey(FocusNode node, KeyEvent event) => _onKey(event) ? KeyEventResult.handled : KeyEventResult.ignored;

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final key = event.physicalKey;
    final keyboard = HardwareKeyboard.instance;
    final ctrl = keyboard.isControlPressed || keyboard.isMetaPressed;
    final center = _viewport.center(Offset.zero);
    // масштаб с клавиатуры
    {
      final VoidCallback? zoom = switch (key) {
        PhysicalKeyboardKey.equal || PhysicalKeyboardKey.numpadAdd => () => _zoom(1.25, center),
        PhysicalKeyboardKey.minus || PhysicalKeyboardKey.numpadSubtract => () => _zoom(0.8, center),
        PhysicalKeyboardKey.digit0 when ctrl => () => _zoom(1 / _transform.value.getMaxScaleOnAxis(), center),
        PhysicalKeyboardKey.digit1 when keyboard.isShiftPressed => _fitAll,
        _ => null,
      };
      if (zoom != null) {
        zoom();
        return true;
      }
    }
    if (_selected.isEmpty) return false;
    if (key == PhysicalKeyboardKey.escape) {
      setState(_selected.clear);
      return true;
    }
    // Delete и Backspace от раскладки не зависят: по смыслу клавиши надёжнее
    if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
      _trash({..._selected});
      return true;
    }
    final step = keyboard.isShiftPressed ? 50.0 : 10.0;
    final shift = switch (key) {
      PhysicalKeyboardKey.arrowLeft => Offset(-step, 0),
      PhysicalKeyboardKey.arrowRight => Offset(step, 0),
      PhysicalKeyboardKey.arrowUp => Offset(0, -step),
      PhysicalKeyboardKey.arrowDown => Offset(0, step),
      _ => null,
    };
    if (shift == null) return false;
    final saved = ref.read(canvasSpotsProvider(widget.folderId)).value ?? const {};
    final moved = <String, CanvasSpot>{
      for (final id in _selected)
        if (_moving[id] ?? saved[id] case final spot?) id: (x: spot.x + shift.dx, y: spot.y + shift.dy, width: spot.width),
    };
    setState(() => _moving.addAll(moved));
    ref.read(canvasRepositoryProvider).saveAll(widget.folderId, moved).then((_) {
      if (mounted) setState(() => moved.keys.forEach(_moving.remove));
    });
    return true;
  }

  void _fitAll() {
    final saved = ref.read(canvasSpotsProvider(widget.folderId)).value;
    if (saved != null) _fit(_boxes(saved));
  }

  /// Delete: выбранные вещи — в корзину, с одним «Отменить» на все.
  void _trash(Set<String> ids) {
    final l = L.of(context);
    final items = ref.read(itemsRepositoryProvider);
    final now = ref.read(clockProvider)();
    setState(_selected.clear);
    for (final id in ids) {
      items.softDelete(id, now).ignore();
    }
    showUndo(
      ScaffoldMessenger.of(context),
      message: ids.length == 1 ? l.itemDeleted : l.selDeleted(ids.length),
      label: l.undo,
      onUndo: () {
        for (final id in ids) {
          items.restore(id).ignore();
        }
      },
      overDock: true,
    );
  }

  /// Нажали мышью на карточку: Shift — добавить или снять, без Shift — выбрать её одну
  /// (если она уже среди выбранных — оставить всех: их сейчас потащат вместе).
  void _mouseOnCard(String id) {
    _cardHit = true;
    setState(() {
      if (HardwareKeyboard.instance.isShiftPressed) {
        if (!_selected.remove(id)) _selected.add(id);
      } else if (!_selected.contains(id)) {
        _selected
          ..clear()
          ..add(id);
      }
    });
  }

  /// Рамка выбора: всё, что пересекает её, выбирается (с Shift — к уже выбранным).
  void _endMarquee(Map<String, CanvasSpot> saved) {
    final marquee = _marquee;
    setState(() {
      _marquee = null;
      _marqueeStart = null;
      _heldView = null;
      if (marquee == null) return;
      for (final box in _boxes(saved)) {
        if (Rect.fromLTWH(_origin + box.x, _origin + box.y, box.width, box.height).overlaps(marquee)) _selected.add(box.itemId);
      }
    });
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

  /// Записка прямо на холсте: заметка в этой папке там, куда сейчас смотрит экран, или
  /// в точке холста [at] (двойной щелчок мышью по пустому месту).
  Future<void> _addNote({Offset? at}) async {
    final text = await _askNote(context);
    if (text == null || !mounted) return;
    final center = at ?? _transform.toScene(_viewport.center(Offset.zero));
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
    if (hold.resize) {
      final current = _moving[card.id] ?? from;
      setState(() => _moving[card.id] = (x: current.x, y: current.y, width: (current.width + delta.dx).clamp(80.0, 1600.0)));
      return;
    }
    // тянут одну из выбранных — едут все выбранные
    final saved = ref.read(canvasSpotsProvider(widget.folderId)).value ?? const {};
    final group = _selected.contains(card.id) ? _selected : {card.id};
    setState(() {
      for (final id in group) {
        final current = _moving[id] ?? (id == card.id ? from : saved[id]);
        if (current != null) _moving[id] = (x: current.x + delta.dx, y: current.y + delta.dy, width: current.width);
      }
    });
  }

  /// Карточку отпустили: места пишутся в базу (у группы — все разом).
  Future<void> _drop() async {
    final hold = _hold;
    if (hold == null) return;
    setState(() => _hold = null);
    final moved = Map.of(_moving);
    if (moved.isEmpty) return;
    await ref.read(canvasRepositoryProvider).saveAll(widget.folderId, moved);
    if (mounted) setState(() => moved.keys.forEach(_moving.remove));
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
        return Focus(
          focusNode: _focus,
          onKeyEvent: _onFocusKey,
          child: Stack(
          key: _stack,
          children: [
            // сетка рисуется в координатах экрана: точек ровно столько, сколько видно
            Positioned.fill(child: CustomPaint(painter: _DotsPainter(_transform))),
            // слушатель пальцев не отбирает жест у холста: он только считает пальцы
            Listener(
              onPointerDown: _pointerDown,
              onPointerUp: _pointerUp,
              onPointerCancel: _pointerUp,
              child: MouseRegion(
                // мышью пустое место тянут, как лист бумаги
                cursor: _hold == null ? SystemMouseCursors.grab : SystemMouseCursors.grabbing,
                child: InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                minScale: 0.1,
                maxScale: 4,
                // колесо мыши масштабирует здесь только с Ctrl (_signal); щипок пальцами — как был
                scaleFactor: double.maxFinite,
                // палец ведёт карточку или мышь тянет рамку — холст под ними не едет
                panEnabled: _hold == null && _marqueeStart == null,
                onInteractionUpdate: (details) {
                  final held = _heldView;
                  if ((_hold != null || _marqueeStart != null) && details.pointerCount == 1 && held != null) _transform.value = held.clone();
                },
                boundaryMargin: const EdgeInsets.all(_world),
                // слушатель внутри просмотрщика слышит колесо первым: колесо листает, а не масштабирует
                child: Listener(
                  // пустое место холста тоже ловит колесо и щелчки
                  behavior: HitTestBehavior.opaque,
                  onPointerSignal: _signal,
                  // щелчок мышью мимо карточек снимает выбор
                  onPointerDown: (event) {
                    if (event.kind == PointerDeviceKind.mouse) {
                      // щёлкнули мышью по холсту — клавиши теперь ему
                      _focus.requestFocus();
                      if (!_cardHit && HardwareKeyboard.instance.isShiftPressed) {
                        // Shift по пустому месту — рамка выбора вместо сдвига холста
                        setState(() {
                          _marqueeStart = event.localPosition;
                          _marquee = Rect.fromPoints(event.localPosition, event.localPosition);
                          _heldView = _transform.value.clone();
                        });
                      } else if (!_cardHit && _selected.isNotEmpty) {
                        setState(_selected.clear);
                      }
                    }
                    _cardHit = false;
                  },
                  onPointerMove: (event) {
                    final start = _marqueeStart;
                    if (start != null) setState(() => _marquee = Rect.fromPoints(start, event.localPosition));
                  },
                  onPointerUp: (event) {
                    if (_marqueeStart != null) _endMarquee(saved);
                  },
                  child: GestureDetector(
                    // двойной щелчок мышью по пустому месту — записка прямо тут
                    onDoubleTapDown: (details) {
                      if (details.kind == PointerDeviceKind.mouse && !_cardHit) _addNote(at: details.localPosition).ignore();
                    },
                    onDoubleTap: () {},
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
                              selected: _selected.contains(card.id),
                              onOpen: () => widget.onOpen(card.id),
                              onGrab: (pointer, {required resize}) => _grab(card, pointer, resize: resize),
                              onDrag: (pointer, delta) => _drag(card, (x: box.x, y: box.y, width: box.width), pointer, delta),
                              onMouseDown: () => _mouseOnCard(card.id),
                              onMenu: () => showItemActions(context, ref, card),
                            ),
                          ),
                      // рамка выбора: мягкая подложка цвета акцента
                      if (_marquee case final marquee?)
                        Positioned.fromRect(
                          rect: marquee,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: Tokens.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                  ),
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
        ),
        );
      },
    );
  }
}

class _CanvasItem extends StatelessWidget {
  const _CanvasItem({
    required this.card,
    required this.filesRoot,
    required this.lifted,
    required this.selected,
    required this.onOpen,
    required this.onGrab,
    required this.onDrag,
    required this.onMouseDown,
    required this.onMenu,
  });

  final ItemCard card;
  final Directory filesRoot;
  final bool lifted;

  /// Выбрана щелчком мыши: её двигают стрелки и убирает Delete.
  final bool selected;
  final VoidCallback onOpen;

  /// Нажата кнопка мыши над карточкой: выбрать её.
  final VoidCallback onMouseDown;

  /// Правый щелчок: то же меню, что долгое нажатие в ленте.
  final VoidCallback onMenu;

  /// Палец лёг на карточку или на её угол.
  final void Function(int pointer, {required bool resize}) onGrab;

  /// Палец сдвинулся: сдвиг в координатах холста.
  final void Function(int pointer, Offset delta) onDrag;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final thumb = card.thumbPath;
    final Widget face = thumb != null
        ? Stack(
            fit: StackFit.expand,
            children: [
              AdultVeil(
                itemId: card.id,
                child: FilePicture(
                  File(p.join(filesRoot.path, thumb)),
                  fit: BoxFit.cover,
                  cacheWidth: 900,
                  errorBuilder: (_, _, _) => ColoredBox(color: Tokens.containerHigh),
                ),
              ),
              FileCountBadge(count: card.fileCount),
            ],
          )
        : Container(
            padding: const EdgeInsets.all(14),
            color: card.kind == ItemKind.note ? Tokens.containerHigh : Tokens.container,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (card.kind != ItemKind.note) ...[Icon(symbolIcon(kindIcon(card.kind)), size: 18, color: Tokens.muted), const SizedBox(height: 8)],
                Text(shownTitle(card.title), maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
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
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse) onMouseDown();
        // правая кнопка открывает меню, а не тащит
        if (event.buttons & kSecondaryMouseButton == 0) onGrab(event.pointer, resize: false);
      },
      onPointerMove: (event) => onDrag(event.pointer, event.localDelta),
      child: MouseRegion(
        cursor: lifted ? SystemMouseCursors.grabbing : SystemMouseCursors.move,
        child: GestureDetector(
        onDoubleTap: onOpen,
        onSecondaryTap: onMenu,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: AnimatedScale(
                scale: lifted ? 1.02 : 1,
                duration: const Duration(milliseconds: 120),
                child: DecoratedBox(
                  // поднятая или выбранная мышью вещь обведена: видно, что именно тянешь
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.photo),
                    border: lifted || selected ? Border.all(color: Tokens.accent, width: 2) : null,
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
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeDownRight,
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
            ),
          ],
        ),
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
                inputFormatters: [TextInputFormatter.withFunction(smartPunctuation)],
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
