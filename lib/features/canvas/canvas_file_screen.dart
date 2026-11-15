import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/file_picture.dart';
import '../../core/widgets/marked_text.dart';
import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/canvas_layout.dart';
import '../../domain/json_canvas.dart';
import '../../l10n/app_localizations.dart';
import '../../services/vault/vault_layout.dart';
import '../folder/folder_sheets.dart' show showRenameSheet;
import '../item/item_screen.dart' show itemRoute;
import '../item/link_sheet.dart';

/// Мир холста: узлы Obsidian лежат вокруг нуля, в мире — со сдвигом на его середину.
const _world = 40000.0;
const _origin = 20000.0;
const _saveDelay = Duration(milliseconds: 600);
const _dotStep = 24.0;

/// Заметка, на которую смотрит карточка-файл холста.
final _fileItemProvider = FutureProvider.autoDispose.family<Item?, String>((ref, path) async {
  final id = await ref.watch(documentsRepositoryProvider).itemAt(path);
  if (id == null) return null;
  final db = ref.watch(databaseProvider);
  return (db.select(db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
});

/// Цвет узла или стрелки: готовый Obsidian — цвет папок Stowa, свой — как есть.
Color? canvasColorOf(String? color) {
  final preset = canvasPresetKey(color);
  if (preset != null) return FolderPalette.colors[preset];
  final hex = canvasHex(color);
  return hex == null ? null : Color(hex);
}

/// Холст Obsidian (`.canvas`) на весь экран: смотреть, двигать, связывать, править.
/// Правка уходит в файл сама через [_saveDelay] после последнего движения.
class CanvasFileScreen extends ConsumerStatefulWidget {
  const CanvasFileScreen({super.key, required this.item});

  final Item item;

  @override
  ConsumerState<CanvasFileScreen> createState() => _CanvasFileScreenState();
}

class _CanvasFileScreenState extends ConsumerState<CanvasFileScreen> {
  final _transform = TransformationController();
  late CanvasDoc _doc;

  /// Текст, который лежит в базе: свой ли пришёл назад, или файл правили снаружи.
  /// Задаётся в initState: ленивое `late` прочиталось бы впервые уже с новой версией.
  String? _stored;

  @override
  void initState() {
    super.initState();
    _stored = widget.item.document;
    _doc = CanvasDoc.parse(_stored ?? '');
  }
  Timer? _save;
  String? _selected;
  String? _selectedEdge;
  bool _connecting = false;
  Size _viewport = Size.zero;
  bool _fitted = false;
  final _pointers = <int>{};
  ({int pointer, String id, bool resize})? _hold;
  Matrix4? _heldView;
  Offset? _doubleTapAt;

  bool get _editable => !_doc.broken;

  @override
  void didUpdateWidget(CanvasFileScreen old) {
    super.didUpdateWidget(old);
    final incoming = widget.item.document;
    // файл поправили снаружи (Obsidian, другой телефон), а своих несохранённых правок нет
    if (incoming != _stored && _save == null && _hold == null) {
      _stored = incoming;
      _doc = CanvasDoc.parse(incoming ?? '');
    }
  }

  @override
  void dispose() {
    if (_save?.isActive ?? false) {
      _save!.cancel();
      _flush();
    }
    _transform.dispose();
    super.dispose();
  }

  void _change(CanvasDoc next) {
    if (!_editable) return;
    setState(() => _doc = next);
    _save?.cancel();
    _save = Timer(_saveDelay, _flush);
  }

  void _flush() {
    _save = null;
    _stored = _doc.encode();
    ref.read(documentsRepositoryProvider).save(widget.item.id, _doc).ignore();
  }

  Offset _scene(Offset local) => _transform.toScene(local) - const Offset(_origin, _origin);

  Offset get _center => _scene(_viewport.center(Offset.zero));

  void _fit() {
    if (_viewport.isEmpty) return;
    if (_doc.nodes.isEmpty) {
      _transform.value = Matrix4.translationValues(_viewport.width / 2 - _origin, _viewport.height / 3 - _origin, 0);
      return;
    }
    final bounds = canvasBounds([for (final node in _doc.nodes) CanvasBox(itemId: node.id, x: node.x.toDouble(), y: node.y.toDouble(), width: node.width.toDouble(), height: node.height.toDouble())], margin: 32);
    final visible = Size(_viewport.width, max(120, _viewport.height - 96));
    final scale = min(visible.width / bounds.width, visible.height / bounds.height).clamp(0.08, 1.2);
    final dx = (visible.width - bounds.width * scale) / 2 - (_origin + bounds.left) * scale;
    final dy = (visible.height - bounds.height * scale) / 2 - (_origin + bounds.top) * scale;
    // масштаб по трём осям, как у InteractiveViewer: иначе getMaxScaleOnAxis видит 1
    _transform.value = Matrix4.translationValues(dx, dy, 0) * Matrix4.diagonal3Values(scale, scale, scale);
  }

  // ── пальцы ──

  void _grab(String id, int pointer, {required bool resize}) {
    if (!_editable || _hold != null || _pointers.length > 1 || _connecting) return;
    _heldView = _transform.value.clone();
    setState(() => _hold = (pointer: pointer, id: id, resize: resize));
  }

  // сдвиг пальца приходит в координатах холста: на масштаб делить не нужно
  void _drag(String id, int pointer, Offset delta) {
    final hold = _hold;
    if (hold == null || hold.pointer != pointer || hold.id != id) return;
    final node = _doc.node(id);
    if (node == null) return;
    setState(() {
      if (hold.resize) {
        _doc = _doc.updateNode(id, {'width': max(60, node.width + delta.dx), 'height': max(40, node.height + delta.dy)});
      } else {
        // группа едет вместе с тем, что лежало в ней, когда её взяли
        for (final moving in {id, ..._carried}) {
          final one = _doc.node(moving);
          if (one != null) _doc = _doc.updateNode(moving, {'x': one.x + delta.dx, 'y': one.y + delta.dy});
        }
      }
      _moved = true;
    });
  }

  bool _moved = false;

  /// Палец отпустили: координаты целые, группа подтягивает содержимое, правка пишется.
  void _drop() {
    final hold = _hold;
    if (hold == null) return;
    _hold = null;
    if (!_moved) return setState(() {});
    _moved = false;
    var next = _doc;
    for (final id in {hold.id, ..._carried}) {
      final node = next.node(id);
      if (node != null) next = next.updateNode(id, {'x': node.x.round(), 'y': node.y.round(), 'width': node.width.round(), 'height': node.height.round()});
    }
    _carried = const {};
    _change(next);
  }

  /// Что лежало в группе, когда её взяли: едет вместе с ней.
  Set<String> _carried = const {};

  void _pointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_pointers.length > 1) _drop();
  }

  void _pointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_hold?.pointer == event.pointer) _drop();
  }

  // ── действия ──

  void _tapNode(CanvasNode node) {
    if (_connecting && _selected != null) {
      final from = _selected!;
      setState(() => _connecting = false);
      _change(_doc.connect(from, node.id));
      return;
    }
    setState(() {
      _selected = node.id;
      _selectedEdge = null;
    });
  }

  Future<void> _add() async {
    final l = L.of(context);
    final what = await showOptionsSheet<CanvasNodeType>(
      context,
      title: l.canvasAdd,
      options: [
        SheetChoice(value: CanvasNodeType.text, title: l.canvasAddText, icon: 'notes'),
        SheetChoice(value: CanvasNodeType.file, title: l.canvasAddNote, icon: 'description'),
        SheetChoice(value: CanvasNodeType.link, title: l.canvasAddLink, icon: 'link'),
        SheetChoice(value: CanvasNodeType.group, title: l.canvasAddGroup, icon: 'select_all'),
      ],
    );
    if (what == null || !mounted) return;
    final at = _center;
    switch (what) {
      case CanvasNodeType.text:
        await _addText(at - const Offset(130, 70));
      case CanvasNodeType.file:
        final target = await pickLinkTarget(context, ref, exceptId: widget.item.id);
        if (target == null) return;
        final path = await ref.read(documentsRepositoryProvider).pathOf(target.id);
        if (path == null || !mounted) return;
        _select(_doc.addFile(path, x: at.dx - 200, y: at.dy - 150));
      case CanvasNodeType.link:
        final url = await _askText(context, hint: l.canvasLinkHint, multiline: false);
        if (url == null || url.trim().isEmpty) return;
        final full = url.contains('://') ? url.trim() : 'https://${url.trim()}';
        _select(_doc.addLink(full, x: at.dx - 200, y: at.dy - 60));
      case CanvasNodeType.group:
        final label = await _askText(context, hint: l.canvasGroupHint, multiline: false, initial: l.canvasAddGroup);
        if (label == null) return;
        _select(_doc.addGroup(label.trim(), x: at.dx - 300, y: at.dy - 200));
      case CanvasNodeType.unknown:
        return;
    }
  }

  /// Новый узел — последний (или первая группа): он и выбирается.
  void _select(CanvasDoc next) {
    final added = next.nodes.firstWhere((node) => _doc.node(node.id) == null);
    _change(next);
    setState(() {
      _selected = added.id;
      _selectedEdge = null;
    });
  }

  Future<void> _addText(Offset topLeft) async {
    final text = await _askText(context, hint: L.of(context).canvasTextHint);
    if (text == null || text.trim().isEmpty || !mounted) return;
    _select(_doc.addText(text.trim(), x: topLeft.dx, y: topLeft.dy));
  }

  Future<void> _edit(CanvasNode node) async {
    final l = L.of(context);
    switch (node.type) {
      case CanvasNodeType.text:
        final text = await _askText(context, hint: l.canvasTextHint, initial: node.text);
        if (text != null) _change(_doc.updateNode(node.id, {'text': text}));
      case CanvasNodeType.link:
        final url = await _askText(context, hint: l.canvasLinkHint, initial: node.url, multiline: false);
        if (url != null && url.trim().isNotEmpty) _change(_doc.updateNode(node.id, {'url': url.trim()}));
      case CanvasNodeType.group:
        final label = await _askText(context, hint: l.canvasGroupHint, initial: node.label, multiline: false);
        if (label != null) _change(_doc.updateNode(node.id, {'label': label.trim().isEmpty ? null : label.trim()}));
      case CanvasNodeType.file || CanvasNodeType.unknown:
        return;
    }
  }

  Future<void> _open(CanvasNode node) async {
    if (node.type == CanvasNodeType.link && node.url != null) {
      await launchUrl(Uri.parse(node.url!), mode: LaunchMode.externalApplication).catchError((_) => false);
      return;
    }
    final file = node.file;
    if (file == null) return;
    final id = await ref.read(documentsRepositoryProvider).itemAt(file);
    if (id != null && mounted) await Navigator.of(context).push(itemRoute(id));
  }

  Future<void> _color({CanvasNode? node, CanvasEdge? edge}) async {
    final picked = await _pickColor(context, node?.color ?? edge?.color);
    if (picked == null) return;
    final value = picked.isEmpty ? null : picked;
    _change(node != null ? _doc.updateNode(node.id, {'color': value}) : _doc.updateEdge(edge!.id, {'color': value}));
  }

  void _delete({CanvasNode? node, CanvasEdge? edge}) {
    final l = L.of(context);
    final before = _doc;
    _change(node != null ? _doc.removeNode(node.id) : _doc.removeEdge(edge!.id));
    setState(() {
      _selected = null;
      _selectedEdge = null;
    });
    showUndo(ScaffoldMessenger.of(context), message: node != null ? l.canvasDeleted : l.canvasEdgeDeleted, label: l.undo, onUndo: () => _change(before));
  }

  Future<void> _rename() async {
    final name = await showRenameSheet(context, widget.item.title);
    if (name == null || name.trim().isEmpty) return;
    await ref.read(documentsRepositoryProvider).rename(widget.item.id, name.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final filesRoot = ref.watch(filesRootProvider);
    final selected = _selected == null ? null : _doc.node(_selected!);
    final selectedEdge = _selectedEdge == null ? null : _doc.edge(_selectedEdge!);
    final groups = [for (final node in _doc.nodes) if (node.type == CanvasNodeType.group) node];
    final cards = [for (final node in _doc.nodes) if (node.type != CanvasNodeType.group) node];

    Widget place(CanvasNode node) => Positioned(
      key: ValueKey(node.id),
      left: _origin + node.x,
      top: _origin + node.y,
      width: node.width.toDouble(),
      height: node.height.toDouble(),
      child: _NodeView(
        node: node,
        filesRoot: filesRoot,
        selected: node.id == _selected,
        editable: _editable,
        onTap: () => _tapNode(node),
        onDoubleTap: () => node.type == CanvasNodeType.text || node.type == CanvasNodeType.group ? _edit(node) : _open(node),
        onGrab: (pointer, {required resize}) {
          if (_hold != null) return;
          _carried = !resize && node.type == CanvasNodeType.group
              ? {for (final other in _doc.nodes) if (other.id != node.id && other.inside(node)) other.id}
              : const {};
          _grab(node.id, pointer, resize: resize);
        },
        onDrag: (pointer, delta) => _drag(node.id, pointer, delta),
      ),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 6),
              child: Row(
                children: [
                  _RoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.maybePop(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('canvas-title'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: _rename,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleLarge),
                          Text('${l.kindCanvas} · ${l.canvasCards(cards.length)}', style: text.bodySmall),
                        ],
                      ),
                    ),
                  ),
                  _RoundButton(icon: 'fit_screen', tooltip: l.canvasFit, onTap: _fit),
                ],
              ),
            ),
            if (_doc.broken)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: _Banner(text: l.canvasBroken, icon: 'error'),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _viewport = constraints.biggest;
                  // первый показ — всё целиком: размер окна известен только здесь
                  if (!_fitted && !_viewport.isEmpty) {
                    _fitted = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _fit() : null);
                  }
                  return Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _DotsPainter(_transform))),
                      Listener(
                        onPointerDown: _pointerDown,
                        onPointerUp: _pointerUp,
                        onPointerCancel: _pointerUp,
                        child: InteractiveViewer(
                          key: const ValueKey('canvas-board'),
                          transformationController: _transform,
                          constrained: false,
                          minScale: 0.08,
                          maxScale: 4,
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
                                // пустое место: касание снимает выбор, двойное — новая карточка там
                                Positioned.fill(
                                  child: GestureDetector(
                                    key: const ValueKey('canvas-empty'),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => setState(() {
                                      _selected = null;
                                      _selectedEdge = null;
                                      _connecting = false;
                                    }),
                                    onDoubleTapDown: (details) => _doubleTapAt = details.localPosition - const Offset(_origin, _origin),
                                    onDoubleTap: _editable ? () => _addText((_doubleTapAt ?? Offset.zero) - const Offset(20, 20)) : null,
                                  ),
                                ),
                                // группы под стрелками, карточки над ними: так рисует и Obsidian
                                for (final node in groups) place(node),
                                Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _EdgesPainter(_doc, selected: _selectedEdge, fallback: Tokens.onSurfaceVariant, accent: Tokens.accent)))),
                                for (final node in cards) place(node),
                                for (final edge in _doc.edges) _edgeHandle(edge, text),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_doc.nodes.isEmpty && !_doc.broken)
                        Positioned(
                          left: Space.screen * 2,
                          right: Space.screen * 2,
                          top: 0,
                          bottom: 120,
                          child: IgnorePointer(
                            child: Center(child: Text(l.canvasEmpty, textAlign: TextAlign.center, style: text.bodyMedium!.copyWith(color: Tokens.muted))),
                          ),
                        ),
                      if (_connecting)
                        Positioned(top: 8, left: Space.screen, right: Space.screen, child: _Banner(text: l.canvasConnectHint, icon: 'arrow_right_alt')),
                      Positioned(
                        left: Space.screen,
                        right: Space.screen,
                        bottom: MediaQuery.paddingOf(context).bottom + 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: selected != null
                                    ? _NodeActions(
                                        node: selected,
                                        onEdit: selected.type == CanvasNodeType.file ? null : () => _edit(selected),
                                        onOpen: selected.type == CanvasNodeType.file || selected.type == CanvasNodeType.link ? () => _open(selected) : null,
                                        onConnect: () => setState(() => _connecting = true),
                                        onColor: () => _color(node: selected),
                                        onDelete: () => _delete(node: selected),
                                      )
                                    : selectedEdge != null
                                    ? _EdgeActions(
                                        onLabel: () async {
                                          final label = await _askText(context, hint: l.canvasEdgeLabel, initial: selectedEdge.label, multiline: false);
                                          if (label != null) _change(_doc.updateEdge(selectedEdge.id, {'label': label.trim().isEmpty ? null : label.trim()}));
                                        },
                                        onColor: () => _color(edge: selectedEdge),
                                        onDelete: () => _delete(edge: selectedEdge),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                            if (_editable) ...[
                              const SizedBox(width: 12),
                              FloatingActionButton(
                                key: const ValueKey('canvas-add'),
                                heroTag: null,
                                tooltip: l.canvasAdd,
                                backgroundColor: Tokens.accent,
                                foregroundColor: Tokens.onAccent,
                                elevation: 0,
                                onPressed: _add,
                                child: Icon(symbolIcon('add')),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Подпись стрелки посередине — она же место, за которое стрелку выбирают.
  Widget _edgeHandle(CanvasEdge edge, TextTheme text) {
    final from = _doc.node(edge.fromNode)!, to = _doc.node(edge.toNode)!;
    final mid = edgeCurve(from, to, edge).point(0.5);
    final selected = edge.id == _selectedEdge;
    final color = canvasColorOf(edge.color);
    final label = edge.label;
    return Positioned(
      left: _origin + mid.dx - 120,
      top: _origin + mid.dy - 22,
      width: 240,
      height: 44,
      child: Center(
        child: GestureDetector(
          key: ValueKey('edge-${edge.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            _selectedEdge = edge.id;
            _selected = null;
            _connecting = false;
          }),
          child: label.isEmpty
              ? Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  child: Container(
                    width: selected ? 14 : 8,
                    height: selected ? 14 : 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? Tokens.accent : (color ?? Tokens.onSurfaceVariant)),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Tokens.background,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: selected ? Tokens.accent : (color ?? Tokens.outline), width: selected ? 2 : 1),
                  ),
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelMedium),
                ),
        ),
      ),
    );
  }
}

/// Кривая стрелки: от середины стороны наружу и к середине стороны другого узла.
({Offset start, Offset c1, Offset c2, Offset end, Offset Function(double) point}) edgeCurve(CanvasNode from, CanvasNode to, CanvasEdge edge) {
  final sides = facingSides(from, to);
  final fromSide = edge.fromSide ?? sides.$1, toSide = edge.toSide ?? sides.$2;
  final start = _anchor(from, fromSide), end = _anchor(to, toSide);
  final reach = ((end - start).distance * 0.35).clamp(40.0, 220.0);
  final c1 = start + _normal(fromSide) * reach, c2 = end + _normal(toSide) * reach;
  Offset point(double t) {
    final u = 1 - t;
    return start * (u * u * u) + c1 * (3 * u * u * t) + c2 * (3 * u * t * t) + end * (t * t * t);
  }

  return (start: start, c1: c1, c2: c2, end: end, point: point);
}

Offset _anchor(CanvasNode node, CanvasSide side) {
  final x = node.x.toDouble(), y = node.y.toDouble(), w = node.width.toDouble(), h = node.height.toDouble();
  return switch (side) {
    CanvasSide.top => Offset(x + w / 2, y),
    CanvasSide.right => Offset(x + w, y + h / 2),
    CanvasSide.bottom => Offset(x + w / 2, y + h),
    CanvasSide.left => Offset(x, y + h / 2),
  };
}

Offset _normal(CanvasSide side) => switch (side) {
  CanvasSide.top => const Offset(0, -1),
  CanvasSide.right => const Offset(1, 0),
  CanvasSide.bottom => const Offset(0, 1),
  CanvasSide.left => const Offset(-1, 0),
};

class _EdgesPainter extends CustomPainter {
  _EdgesPainter(this.doc, {required this.selected, required this.fallback, required this.accent});

  final CanvasDoc doc;
  final String? selected;
  final Color fallback;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(_origin, _origin);
    for (final edge in doc.edges) {
      final from = doc.node(edge.fromNode), to = doc.node(edge.toNode);
      if (from == null || to == null) continue;
      final curve = edgeCurve(from, to, edge);
      final color = edge.id == selected ? accent : canvasColorOf(edge.color) ?? fallback;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = edge.id == selected ? 3.5 : 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
        Path()
          ..moveTo(curve.start.dx, curve.start.dy)
          ..cubicTo(curve.c1.dx, curve.c1.dy, curve.c2.dx, curve.c2.dy, curve.end.dx, curve.end.dy),
        paint,
      );
      if (edge.toEnd == CanvasEnd.arrow) _arrow(canvas, curve.c2, curve.end, color);
      if (edge.fromEnd == CanvasEnd.arrow) _arrow(canvas, curve.c1, curve.start, color);
    }
  }

  void _arrow(Canvas canvas, Offset from, Offset tip, Color color) {
    final direction = tip - from;
    if (direction.distance == 0) return;
    final unit = direction / direction.distance;
    final side = Offset(-unit.dy, unit.dx);
    const length = 14.0, half = 7.0;
    final base = tip - unit * length;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((base + side * half).dx, (base + side * half).dy)
        ..lineTo((base - side * half).dx, (base - side * half).dy)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_EdgesPainter old) => old.doc != doc || old.selected != selected || old.fallback != fallback;
}

class _NodeView extends ConsumerWidget {
  const _NodeView({
    required this.node,
    required this.filesRoot,
    required this.selected,
    required this.editable,
    required this.onTap,
    required this.onDoubleTap,
    required this.onGrab,
    required this.onDrag,
  });

  final CanvasNode node;
  final Directory filesRoot;
  final bool selected;
  final bool editable;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final void Function(int pointer, {required bool resize}) onGrab;
  final void Function(int pointer, Offset delta) onDrag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final color = canvasColorOf(node.color);
    final group = node.type == CanvasNodeType.group;
    final border = selected ? Tokens.accent : (color ?? (group ? Tokens.outline : Colors.transparent));
    final Widget face = switch (node.type) {
      CanvasNodeType.text => Padding(
        padding: const EdgeInsets.all(14),
        child: ClipRect(child: MarkedText.note(node.text, style: text.bodyMedium!.copyWith(height: 1.4), maxLines: 400, overflow: TextOverflow.fade)),
      ),
      CanvasNodeType.link => _LinkFace(url: node.url ?? ''),
      CanvasNodeType.file => _FileFace(path: node.file ?? '', filesRoot: filesRoot, missing: l.canvasMissingFile(node.file ?? '')),
      CanvasNodeType.group => Align(
        alignment: Alignment.topLeft,
        child: node.label.isEmpty
            ? const SizedBox.shrink()
            : Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: color == null ? Tokens.containerHighest : FolderPalette.tint(color, 0.5), borderRadius: BorderRadius.circular(100)),
                child: Text(node.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelLarge),
              ),
      ),
      CanvasNodeType.unknown => const SizedBox.shrink(),
    };
    final fill = group
        ? (color ?? Tokens.onSurface).withValues(alpha: 0.06)
        : color == null
        ? Tokens.containerHigh
        : FolderPalette.tint(color, 0.22);

    // слушатель пальцев, а не распознаватель перетаскивания: тот забирал бы палец у холста
    return Listener(
      onPointerDown: (event) => onGrab(event.pointer, resize: false),
      onPointerMove: (event) => onDrag(event.pointer, event.localDelta),
      child: GestureDetector(
        key: ValueKey('node-${node.id}'),
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(group ? 24 : 16),
                  border: Border.all(color: border, width: selected ? 2.5 : (group || color != null ? 2 : 0)),
                ),
                child: face,
              ),
            ),
            if (selected && editable)
              Positioned(
                right: -14,
                bottom: -14,
                child: Listener(
                  onPointerDown: (event) => onGrab(event.pointer, resize: true),
                  child: Container(
                    key: ValueKey('resize-${node.id}'),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: Tokens.accent, shape: BoxShape.circle),
                    child: Icon(symbolIcon('open_in_full'), size: 14, color: Tokens.onAccent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LinkFace extends StatelessWidget {
  const _LinkFace({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: BorderRadius.circular(12)),
            child: Icon(symbolIcon('link'), color: Tokens.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(host, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                Text(url, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'bmp', 'avif'};

class _FileFace extends ConsumerWidget {
  const _FileFace({required this.path, required this.filesRoot, required this.missing});

  final String path;
  final Directory filesRoot;
  final String missing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final extension = path.contains('.') ? path.substring(path.lastIndexOf('.') + 1).toLowerCase() : '';
    if (_imageExtensions.contains(extension)) {
      return FilePicture(
        File(vaultAbsolute(filesRoot.path, path)),
        fit: BoxFit.cover,
        cacheWidth: 900,
        errorBuilder: (_, _, _) => _plain(text, 'broken_image', missing),
      );
    }
    if (extension != 'md' && extension != 'canvas' && extension != 'base') return _plain(text, 'draft', path.split('/').last);
    final item = ref.watch(_fileItemProvider(path));
    return switch (item) {
      AsyncData(value: final found?) => Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(symbolIcon('description'), size: 18, color: Tokens.muted),
                const SizedBox(width: 8),
                Expanded(child: Text(found.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRect(
                child: MarkedText.note(found.body, style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4), maxLines: 200, overflow: TextOverflow.fade),
              ),
            ),
          ],
        ),
      ),
      AsyncData() => _plain(text, 'help', missing),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _plain(TextTheme text, String icon, String label) => Center(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(symbolIcon(icon), color: Tokens.muted),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: text.bodySmall),
        ],
      ),
    ),
  );
}

/// Полоса действий выбранной карточки, плавающая пилюля как у страницы заметки.
class _NodeActions extends StatelessWidget {
  const _NodeActions({required this.node, required this.onEdit, required this.onOpen, required this.onConnect, required this.onColor, required this.onDelete});

  final CanvasNode node;
  final VoidCallback? onEdit;
  final VoidCallback? onOpen;
  final VoidCallback onConnect;
  final VoidCallback onColor;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return _Pill(
      children: [
        if (onOpen != null) _PillButton(key: const ValueKey('node-open'), icon: 'open_in_new', tooltip: l.catalogOpenFolder, onTap: onOpen!),
        if (onEdit != null) _PillButton(key: const ValueKey('node-edit'), icon: 'edit', tooltip: l.canvasEdit, onTap: onEdit!),
        _PillButton(key: const ValueKey('node-connect'), icon: 'arrow_right_alt', tooltip: l.canvasConnect, onTap: onConnect),
        _PillButton(key: const ValueKey('node-color'), icon: 'palette', tooltip: l.canvasColor, onTap: onColor),
        _PillButton(key: const ValueKey('node-delete'), icon: 'delete', tooltip: l.canvasDelete, onTap: onDelete),
      ],
    );
  }
}

class _EdgeActions extends StatelessWidget {
  const _EdgeActions({required this.onLabel, required this.onColor, required this.onDelete});

  final VoidCallback onLabel;
  final VoidCallback onColor;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return _Pill(
      children: [
        _PillButton(key: const ValueKey('edge-label'), icon: 'title', tooltip: l.canvasEdgeLabel, onTap: onLabel),
        _PillButton(key: const ValueKey('edge-color'), icon: 'palette', tooltip: l.canvasColor, onTap: onColor),
        _PillButton(key: const ValueKey('edge-delete'), icon: 'delete', tooltip: l.canvasDelete, onTap: onDelete),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: BorderRadius.circular(100)),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({super.key, required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(symbolIcon(icon)), style: IconButton.styleFrom(fixedSize: const Size.square(48)));
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(symbolIcon(icon)),
      style: IconButton.styleFrom(backgroundColor: Tokens.containerHigh, fixedSize: const Size.square(44)),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.icon});

  final String text;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(symbolIcon(icon), size: 20, color: Tokens.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.transform) : super(repaint: transform);

  final TransformationController transform;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = transform.value;
    final scale = matrix.getMaxScaleOnAxis();
    var step = _dotStep * scale;
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

/// Лист с полем: текст карточки (много строк) или подпись и адрес (одна строка).
Future<String?> _askText(BuildContext context, {required String hint, String? initial, bool multiline = true}) {
  final l = L.of(context);
  final field = TextEditingController(text: initial ?? '');
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheet) => Padding(
      padding: EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, MediaQuery.viewInsetsOf(sheet).bottom + Space.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('canvas-text-field'),
            controller: field,
            autofocus: true,
            minLines: multiline ? 4 : 1,
            maxLines: multiline ? 12 : 1,
            keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Tokens.containerHigh,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.tile), borderSide: BorderSide.none),
            ),
            onSubmitted: multiline ? null : (value) => Navigator.pop(sheet, value),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('canvas-text-done'),
            onPressed: () => Navigator.pop(sheet, field.text),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: Tokens.accent, foregroundColor: Tokens.onAccent),
            child: Text(l.canvasDone),
          ),
        ],
      ),
    ),
  );
}

/// Цвет узла или стрелки: «без цвета» (пустая строка) и шесть готовых Obsidian.
Future<String?> _pickColor(BuildContext context, String? current) {
  final l = L.of(context);
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen * 2),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        alignment: WrapAlignment.center,
        children: [
          Tooltip(
            message: l.canvasNoColor,
            child: InkWell(
              key: const ValueKey('color-none'),
              customBorder: const CircleBorder(),
              onTap: () => Navigator.pop(sheet, ''),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Tokens.outline, width: 2)),
                child: Icon(symbolIcon('block'), color: Tokens.muted),
              ),
            ),
          ),
          for (final MapEntry(key: preset, value: key) in canvasPresets.entries)
            InkWell(
              key: ValueKey('color-$preset'),
              customBorder: const CircleBorder(),
              onTap: () => Navigator.pop(sheet, preset),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FolderPalette.colors[key],
                  border: current == preset ? Border.all(color: Tokens.accent, width: 3) : null,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
