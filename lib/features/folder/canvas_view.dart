import 'dart:async';
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
import '../../data/db/database.dart' show Link;
import '../../data/providers.dart';
import '../../data/repositories/canvas_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/canvas_layout.dart';
import '../../domain/note_links.dart' show shownTitle, wikiTitles;
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../canvas/canvas_kit.dart';
import '../composer/picked_files.dart' show pickedFromXFile;
import 'package:image_picker/image_picker.dart' show XFile;
import '../../services/capture_service.dart';
import '../composer/panel_text.dart';
import '../../core/widgets/undo_snack.dart';
import '../item/adult_veil.dart';
import '../item/item_actions.dart' show showItemActions;

/// Мир холста: вещи лежат в нём со сдвигом, чтобы отрицательные координаты тоже помещались.
const _origin = 10000.0;
const _world = 20000.0;

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

class _CanvasViewState extends ConsumerState<CanvasView> with CanvasControls {

  /// Положения, пока палец ещё ведёт вещь: база получит их при отпускании.
  final _moving = <String, CanvasSpot>{};
  final _placing = <String>{};
  bool _fitted = false;

  // ——— мышь и клавиатура (компьютер, браузер); на телефоне этого не происходит ———

  /// Карточки, выбранные мышью: щелчком, Shift+щелчком или рамкой. Их двигают стрелки
  /// и перетаскивание, убирает Delete. Пальцем не выбираются: у телефона нет клавиатуры,
  /// а касание — это перетаскивание.
  final _selected = <String>{};

  /// Рамка выбора (Shift+тянуть по пустому месту), в координатах мира холста.
  Rect? _marquee;
  Offset? _marqueeStart;

  // щелчок попал в карточку: тот же щелчок по пустому месту выбор не снимает
  bool _cardHit = false;

  @override
  void initState() {
    super.initState();
    // картинка из буфера (Ctrl+V) встаёт на холст карточкой, без строки
    listenPaste(ref.read(pasteRouterProvider));
  }

  /// Клавиши холста: доходят сюда, когда фокус у холста (щёлкнули по нему мышью). Холст
  /// забирает их себе: иначе стрелка заодно увела бы фокус в поле ввода.
  KeyEventResult _onFocusKey(FocusNode node, KeyEvent event) => _onKey(event) ? KeyEventResult.handled : KeyEventResult.ignored;

  bool _onKey(KeyEvent event) {
    if (!isKeyPress(event)) return false;
    final key = event.physicalKey;
    if (zoomKey(event)) return true;
    if (_selectedLink case final link?) {
      if (isDeleteKey(event)) {
        _unlink(link);
        return true;
      }
      if (key == PhysicalKeyboardKey.escape) {
        setState(() => _selectedLink = null);
        return true;
      }
    }
    if (_selected.isEmpty) return false;
    if (key == PhysicalKeyboardKey.escape) {
      setState(_selected.clear);
      return true;
    }
    if (isDeleteKey(event)) {
      _trash({..._selected});
      return true;
    }
    final shift = arrowShift(event);
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

  @override
  void fitAll() {
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
    setState(() => selectOnMouse(_selected, id));
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
    if (viewport.isEmpty) return;
    if (boxes.isEmpty) {
      transform.value = Matrix4.translationValues(-_origin + 24, -_origin + 24, 0);
      return;
    }
    final bounds = canvasBounds(boxes, margin: 24);
    final visible = Size(viewport.width, max(120, viewport.height - widget.bottomInset));
    final scale = min(visible.width / bounds.width, visible.height / bounds.height).clamp(0.1, 1.2);
    final dx = (visible.width - bounds.width * scale) / 2 - (_origin + bounds.left) * scale;
    final dy = (visible.height - bounds.height * scale) / 2 - (_origin + bounds.top) * scale;
    // масштаб по всем трём осям, как у InteractiveViewer: иначе getMaxScaleOnAxis видит 1
    transform.value = Matrix4.translationValues(dx, dy, 0) * Matrix4.diagonal3Values(scale, scale, scale);
  }

  /// Записка прямо на холсте: заметка в этой папке там, куда сейчас смотрит экран, или
  /// в точке холста [at] (двойной щелчок мышью по пустому месту).
  /// Вернёт id новой заметки; отказались — null.
  Future<String?> _addNote({Offset? at}) async {
    final text = await askCanvasNote(context);
    if (text == null || !mounted) return null;
    final center = at ?? transform.toScene(viewport.center(Offset.zero));
    final id = await ref.read(captureServiceProvider).capture(CaptureInput(text: text, forcedFolderId: widget.folderId));
    await _putAt(id, (x: center.dx - _origin - 110, y: center.dy - _origin - 88, width: 220));
    return id;
  }

  /// Место заметки, которое выбрал человек: записка на холсте, брошенный файл. Заметка
  /// появляется на холсте раньше, чем её место доходит из базы, и расстановка новых
  /// ([_placeMissing]) ставила её справа от остальных, затирая выбранное. Поэтому заметка
  /// сразу числится расставленной.
  Future<void> _putAt(String id, CanvasSpot spot) async {
    _placing.add(id);
    try {
      await ref.read(canvasRepositoryProvider).save(widget.folderId, id, spot);
    } catch (_) {
      // место не записалось — пусть встанет хоть куда-нибудь
      _placing.remove(id);
      rethrow;
    }
  }

  // ——— стрелки-связи ———

  /// Карточка под мышью: у неё проявляются точки-выходы.
  String? _hoverCard;

  /// Провод, который тянут из точки-выхода: откуда, куда смотрит выход и где курсор
  /// (всё в координатах мира холста).
  ({String from, Offset start, Offset normal, Offset end})? _wire;

  /// Стрелка, выбранная щелчком: её убирает Delete.
  (String, String)? _selectedLink;

  /// Стрелки, нарисованные сейчас: по ним щелчок находит выбранную.
  List<CanvasLink> _links = const [];

  (String, String)? _linkAt(Offset world) {
    final reach = 10 / transform.value.getMaxScaleOnAxis();
    return _links.where((link) => !link.written && link.near(world, reach)).map((link) => (link.from, link.to)).firstOrNull;
  }

  void _startWire(String from, Offset start, Offset normal) {
    _cardHit = true;
    setState(() {
      _wire = (from: from, start: start, normal: normal, end: start);
      _heldView = transform.value.clone();
    });
  }

  /// Провод отпустили: на другой карточке — связь, на пустом месте — новая записка, уже
  /// связанная (как в Obsidian).
  Future<void> _endWire(Map<String, CanvasSpot> saved) async {
    final wire = _wire;
    setState(() {
      _wire = null;
      _heldView = null;
    });
    if (wire == null || (wire.end - wire.start).distance < 12) return;
    final items = ref.read(itemsRepositoryProvider);
    final target = _boxes(saved).where((box) => box.itemId != wire.from && _rectOf(box).contains(wire.end)).firstOrNull;
    final to = target?.itemId ?? await _addNote(at: wire.end);
    if (to != null) await items.link(wire.from, to);
  }

  Rect _rectOf(CanvasBox box) => Rect.fromLTWH(_origin + box.x, _origin + box.y, box.width, box.height);

  /// Убрать связь, с «Отменить». Связь от ИИ помечается отклонённой: иначе он вернул бы её.
  void _unlink((String, String) pair) {
    final l = L.of(context);
    final items = ref.read(itemsRepositoryProvider);
    final (from, to) = pair;
    final stored = ref.read(noteLinksProvider).value?.where((link) => link.fromId == from && link.toId == to).firstOrNull;
    setState(() => _selectedLink = null);
    if (stored?.source == LinkSource.ai) {
      items.rejectRelated(from, to).ignore();
    } else {
      items.unlink(from, to).ignore();
    }
    showUndo(ScaffoldMessenger.of(context), message: l.relatedUnlinked, label: l.undo, onUndo: () => items.link(from, to), overDock: true);
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
    _heldView = transform.value.clone();
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
    trackPointer(event);
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
    final saved = ref.watch(canvasSpotsProvider(widget.folderId)).value;
    final filesRoot = ref.watch(filesRootProvider);
    if (saved == null) return const SizedBox.expand();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _placeMissing(saved);
      // первый показ — всё целиком, но только когда места есть у всех вещей
      final boxes = _boxes(saved);
      if (!_fitted && !viewport.isEmpty && boxes.length == widget.cards.length) {
        _fitted = true;
        _fit(boxes);
      }
    });
    final boxes = _boxes(saved);
    final cards = {for (final card in widget.cards) card.id: card};
    // нетронутые снизу в своём порядке, тронутые сверху — последняя выше всех
    final layered = [...boxes.where((box) => !_front.contains(box.itemId)), for (final id in _front) ...boxes.where((box) => box.itemId == id)];
    // стрелки — связи, у которых оба конца лежат на этом холсте
    final rects = {for (final box in boxes) box.itemId: _rectOf(box)};
    final stored = [for (final link in ref.watch(noteLinksProvider).value ?? const <Link>[]) (link.fromId, link.toId)];
    // [[Название]] в тексте — тоже связь, как в графе; снимается правкой текста, не клавишей
    final byTitle = {for (final card in widget.cards.reversed) card.title.trim().toLowerCase(): card.id};
    final written = <(String, String)>{
      for (final card in widget.cards)
        for (final title in wikiTitles(card.body))
          if (byTitle[title.toLowerCase()] case final other? when other != card.id) (card.id, other),
    };
    final pairs = {...stored, ...written.where((pair) => !stored.contains(pair) && !stored.contains((pair.$2, pair.$1)))};
    _links = [
      for (final (fromId, toId) in pairs)
        if ((rects[fromId], rects[toId]) case (final from?, final to?))
          CanvasLink.between(fromId, toId, from, to, selected: _selectedLink == (fromId, toId), written: written.contains((fromId, toId)) && !stored.contains((fromId, toId))),
    ];
    final hover = _wire?.from ?? _hoverCard;

    // файлы из системы, брошенные мышью: каждый — заметка этой папки там, где отпустили
    return CanvasDropZone(
      onFiles: (files, at) => placeFiles(files, at).ignore(),
      child: LayoutBuilder(
      builder: (context, constraints) {
        viewport = constraints.biggest;
        return Focus(
          focusNode: canvasFocus,
          onKeyEvent: _onFocusKey,
          child: Stack(
          key: canvasKey,
          children: [
            // сетка рисуется в координатах экрана: точек ровно столько, сколько видно
            Positioned.fill(child: CustomPaint(painter: CanvasDotsPainter(transform))),
            // слушатель пальцев не отбирает жест у холста: он только считает пальцы
            Listener(
              onPointerDown: _pointerDown,
              onPointerHover: trackPointer,
              onPointerUp: _pointerUp,
              onPointerCancel: _pointerUp,
              child: MouseRegion(
                // мышью пустое место тянут, как лист бумаги
                cursor: _hold == null ? SystemMouseCursors.grab : SystemMouseCursors.grabbing,
                child: InteractiveViewer(
                transformationController: transform,
                constrained: false,
                minScale: 0.1,
                maxScale: 4,
                // колесо мыши масштабирует здесь только с Ctrl (_signal); щипок пальцами — как был
                scaleFactor: double.maxFinite,
                // палец ведёт карточку, мышь тянет рамку или провод — холст под ними не едет
                panEnabled: _hold == null && _marqueeStart == null && _wire == null,
                onInteractionUpdate: (details) {
                  final held = _heldView;
                  if ((_hold != null || _marqueeStart != null || _wire != null) && details.pointerCount == 1 && held != null) transform.value = held.clone();
                },
                boundaryMargin: const EdgeInsets.all(_world),
                // слушатель внутри просмотрщика слышит колесо первым: колесо листает, а не масштабирует
                child: Listener(
                  // пустое место холста тоже ловит колесо и щелчки
                  behavior: HitTestBehavior.opaque,
                  onPointerSignal: canvasSignal,
                  // щелчок мышью мимо карточек снимает выбор
                  onPointerDown: (event) {
                    if (event.kind == PointerDeviceKind.mouse) {
                      // щёлкнули мышью по холсту — клавиши теперь ему
                      canvasFocus.requestFocus();
                      final link = _cardHit ? null : _linkAt(event.localPosition);                      if (!_cardHit && HardwareKeyboard.instance.isShiftPressed) {
                        // Shift по пустому месту — рамка выбора вместо сдвига холста
                        setState(() {
                          _marqueeStart = event.localPosition;
                          _marquee = Rect.fromPoints(event.localPosition, event.localPosition);
                          _heldView = transform.value.clone();
                        });
                      } else if (link != null) {
                        // щелчок по стрелке выбирает её
                        setState(() {
                          _selectedLink = link;
                          _selected.clear();
                        });
                      } else if (!_cardHit && (_selected.isNotEmpty || _selectedLink != null)) {
                        setState(() {
                          _selected.clear();
                          _selectedLink = null;
                        });
                      } else if (_cardHit && _selectedLink != null) {
                        setState(() => _selectedLink = null);
                      }
                    }
                    _cardHit = false;
                  },
                  // мышь над карточкой — у неё проявляются точки-выходы
                  onPointerHover: (event) {
                    final under = boxes.where((box) => _rectOf(box).inflate(18).contains(event.localPosition)).lastOrNull?.itemId;
                    if (under != _hoverCard) setState(() => _hoverCard = under);
                  },
                  onPointerMove: (event) {
                    final start = _marqueeStart;
                    if (start != null) setState(() => _marquee = Rect.fromPoints(start, event.localPosition));
                    final wire = _wire;
                    if (wire != null) setState(() => _wire = (from: wire.from, start: wire.start, normal: wire.normal, end: event.localPosition));
                  },
                  onPointerUp: (event) {
                    if (_marqueeStart != null) _endMarquee(saved);
                    if (_wire != null) _endWire(saved).ignore();
                  },
                  child: GestureDetector(
                    // двойной щелчок мышью по пустому месту — записка прямо тут
                    onDoubleTapDown: (details) {
                      if (details.kind == PointerDeviceKind.mouse && !_cardHit) _addNote(at: details.localPosition).ignore();
                    },
                    onDoubleTap: () {},
                    // правый щелчок по стрелке — убрать связь
                    onSecondaryTapDown: (details) {
                      final link = _linkAt(details.localPosition);
                      if (link != null) _unlink(link);
                    },
                    child: SizedBox(
                  width: _world,
                  height: _world,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // стрелки под карточками: кривые, как провода нод в Blender
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(key: const ValueKey('canvas-links'), painter: CanvasLinksPainter(_links, ink: Tokens.muted, accent: Tokens.accent, view: transform)),
                        ),
                      ),
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
                      // связи карточки под мышью и выбранных — поверх карточек, как в Blender:
                      // в плотной раскладке иначе видны одни наконечники
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            key: const ValueKey('canvas-links-over'),
                            painter: CanvasLinksPainter(
                              [
                                for (final link in _links)
                                  if (link.selected || {link.from, link.to}.any((id) => id == hover || _selected.contains(id)))
                                    link.lit(),
                              ],
                              ink: Tokens.accent,
                              accent: Tokens.accent,
                              view: transform,
                            ),
                          ),
                        ),
                      ),
                      // провод, который тянут сейчас, — поверх карточек
                      if (_wire case final wire?)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: CanvasLinksPainter([CanvasLink.wire(wire.from, wire.start, wire.normal, wire.end)], ink: Tokens.accent, accent: Tokens.accent, view: transform),
                            ),
                          ),
                        ),
                      // точки-выходы карточки под мышью: из любой тянут провод
                      if (hover != null)
                        if (boxes.where((box) => box.itemId == hover).firstOrNull case final box?)
                          ...canvasSocketDots(id: hover, rect: _rectOf(box), view: transform, onStart: (side, point, normal) => _startWire(hover, point, normal)),
                      if (_marquee case final marquee?) canvasMarquee(marquee),
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
              child: CanvasTools(view: transform, onFit: () => _fit(boxes), onNote: _addNote),
            ),
          ],
        ),
        );
      },
      ),
    );
  }

  /// Каждый файл — заметка этой папки там, куда его бросили или вставили.
  @override
  Future<void> placeFiles(List<XFile> files, Offset at) async {
    final l = L.of(context);
    final world = transform.toScene(at);
    final capture = ref.read(captureServiceProvider);
    for (final (index, file) in files.indexed) {
      final picked = await pickedFromXFile(file);
      final id = await capture.capture(
        CaptureInput(files: [picked], forcedFolderId: widget.folderId, untitled: (time) => untitledFor(l, mime: picked.mime, fileName: p.basename(picked.path), at: time)),
      );
      // несколько файлов — лесенкой, первый под курсором
      await _putAt(id, (x: world.dx - _origin - 120 + index * 32, y: world.dy - _origin - 90 + index * 32, width: 240));
    }
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
