import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/file_picture.dart';
import '../../core/widgets/hint_banner.dart';
import '../../domain/hints.dart' show Tip;
import '../../core/widgets/marked_text.dart';
import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/canvas_layout.dart';
import '../../domain/json_canvas.dart';
import '../../domain/note_section.dart';
import '../../l10n/app_localizations.dart';
import '../../services/vault/vault_layout.dart';
import '../folder/folder_sheets.dart' show showRenameSheet;
import '../item/item_screen.dart' show itemRoute;
import '../item/link_sheet.dart';
import '../../services/capture_service.dart';
import 'canvas_kit.dart';

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

class _CanvasFileScreenState extends ConsumerState<CanvasFileScreen> with CanvasControls {
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

  /// Выбранные карточки: касанием — одна, мышью — щелчком, Shift+щелчком или рамкой.
  /// Их двигают стрелки и перетаскивание, убирает Delete; у одной — полоса действий.
  final _selected = <String>{};
  String? _selectedEdge;
  bool _connecting = false;
  bool _fitted = false;
  final _pointers = <int>{};
  ({int pointer, String id, bool resize})? _hold;
  Matrix4? _heldView;

  /// Заметки, положенные на холст в этот раз: узел → id заметки. Угадыватель может
  /// переложить заметку, пока холст ждёт записи, — путь берётся свежий при записи.
  final _placed = <String, String>{};

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
    final documents = ref.read(documentsRepositoryProvider);
    final id = widget.item.id;
    final placed = Map.of(_placed);
    var doc = _doc;
    _stored = doc.encode();
    () async {
      // свежий путь положенных заметок: их могли разложить по папкам, пока холст ждал
      for (final MapEntry(key: nodeId, value: itemId) in placed.entries) {
        final path = await documents.writtenPathOf(itemId) ?? await documents.pathOf(itemId);
        if (path != null && doc.node(nodeId)?.file != path) doc = doc.updateNode(nodeId, {'file': path});
      }
      await documents.save(id, doc);
    }().ignore();
  }

  /// Точка экрана → координаты файла (мир без сдвига на середину).
  Offset _scene(Offset local) => transform.toScene(local) - const Offset(_origin, _origin);

  Offset get _center => _scene(viewport.center(Offset.zero));

  Rect _rectOf(CanvasNode node) => Rect.fromLTWH(_origin + node.x, _origin + node.y, node.width.toDouble(), node.height.toDouble());

  @override
  void fitAll() {
    if (viewport.isEmpty) return;
    if (_doc.nodes.isEmpty) {
      transform.value = Matrix4.translationValues(viewport.width / 2 - _origin, viewport.height / 3 - _origin, 0);
      return;
    }
    final bounds = canvasBounds([for (final node in _doc.nodes) CanvasBox(itemId: node.id, x: node.x.toDouble(), y: node.y.toDouble(), width: node.width.toDouble(), height: node.height.toDouble())], margin: 32);
    final visible = Size(viewport.width, max(120, viewport.height - 96));
    final scale = min(visible.width / bounds.width, visible.height / bounds.height).clamp(canvasMinScale, 1.2);
    final dx = (visible.width - bounds.width * scale) / 2 - (_origin + bounds.left) * scale;
    final dy = (visible.height - bounds.height * scale) / 2 - (_origin + bounds.top) * scale;
    // масштаб по трём осям, как у InteractiveViewer: иначе getMaxScaleOnAxis видит 1
    transform.value = Matrix4.translationValues(dx, dy, 0) * Matrix4.diagonal3Values(scale, scale, scale);
  }

  // ——— клавиши: доходят, когда фокус у холста (щёлкнули по нему мышью) ———

  KeyEventResult _onFocusKey(FocusNode node, KeyEvent event) => _onKey(event) ? KeyEventResult.handled : KeyEventResult.ignored;

  bool _onKey(KeyEvent event) {
    if (!isKeyPress(event)) return false;
    if (zoomKey(event)) return true;
    if (event.physicalKey == PhysicalKeyboardKey.escape && (_selected.isNotEmpty || _selectedEdge != null || _connecting)) {
      setState(_clearSelection);
      return true;
    }
    if (!_editable) return false;
    if (_selectedEdge case final id?) {
      if (isDeleteKey(event)) {
        _delete(edge: _doc.edge(id));
        return true;
      }
    }
    if (_selected.isEmpty) return false;
    if (isDeleteKey(event)) {
      _deleteNodes({..._selected});
      return true;
    }
    final shift = arrowShift(event);
    if (shift == null) return false;
    var next = _doc;
    for (final id in _withContents(_selected)) {
      final node = next.node(id);
      if (node != null) next = next.updateNode(id, {'x': (node.x + shift.dx).round(), 'y': (node.y + shift.dy).round()});
    }
    _change(next);
    return true;
  }

  void _clearSelection() {
    _selected.clear();
    _selectedEdge = null;
    _connecting = false;
  }

  /// Что едет вместе с [ids]: группа — с тем, что лежит в ней целиком.
  Set<String> _withContents(Iterable<String> ids) => {
    for (final id in ids) ...[
      id,
      if (_doc.node(id) case final group? when group.type == CanvasNodeType.group)
        for (final other in _doc.nodes)
          if (other.id != group.id && other.inside(group)) other.id,
    ],
  };

  // ——— мышь ———

  /// Рамка выбора (Shift+тянуть по пустому месту), в координатах мира холста.
  Rect? _marquee;
  Offset? _marqueeStart;

  // нажатие попало в карточку: то же нажатие по пустому месту выбор не снимает
  bool _cardHit = false;

  /// Карточка под мышью: у неё проявляются точки-выходы.
  String? _hover;

  /// Провод, который тянут из точки-выхода: откуда, с какой стороны и где курсор.
  ({String from, CanvasSide side, Offset start, Offset normal, Offset end})? _wire;

  /// Стрелки, нарисованные сейчас: по ним щелчок находит выбранную.
  List<CanvasLink> _links = const [];

  String? _edgeAt(Offset world) {
    final reach = 10 / transform.value.getMaxScaleOnAxis();
    return _links.where((link) => link.near(world, reach)).map((link) => link.key).firstOrNull;
  }

  /// Узел под точкой мира: карточки выше групп.
  CanvasNode? _nodeAt(Offset world, {double margin = 0, String? except}) {
    bool hits(CanvasNode node) => node.id != except && _rectOf(node).inflate(margin).contains(world);
    return _doc.nodes.where((node) => node.type != CanvasNodeType.group && hits(node)).lastOrNull ?? _doc.nodes.where((node) => node.type == CanvasNodeType.group && hits(node)).lastOrNull;
  }

  void _mouseOnNode(String id) {
    _cardHit = true;
    setState(() {
      selectOnMouse(_selected, id);
      _selectedEdge = null;
    });
  }

  void _endMarquee() {
    final marquee = _marquee;
    setState(() {
      _marquee = null;
      _marqueeStart = null;
      _heldView = null;
      if (marquee == null) return;
      for (final node in _doc.nodes) {
        if (node.type != CanvasNodeType.group && _rectOf(node).overlaps(marquee)) _selected.add(node.id);
      }
    });
  }

  void _startWire(String from, CanvasSide side, Offset start, Offset normal) {
    if (!_editable) return;
    _cardHit = true;
    setState(() {
      _wire = (from: from, side: side, start: start, normal: normal, end: start);
      _heldView = transform.value.clone();
    });
  }

  /// Провод отпустили: на другой карточке — стрелка от выбранной стороны, на пустом месте —
  /// новая заметка там, уже со стрелкой (как в Obsidian).
  Future<void> _endWire() async {
    final wire = _wire;
    setState(() {
      _wire = null;
      _heldView = null;
    });
    if (wire == null || (wire.end - wire.start).distance < 12) return;
    final target = _nodeAt(wire.end, except: wire.from);
    if (target != null) {
      _change(_doc.connect(wire.from, target.id, fromSide: wire.side, toSide: sideFacing(_rectOf(target), wire.start)));
      return;
    }
    final added = await _addNote(at: wire.end);
    if (added == null || !mounted) return;
    final node = _doc.node(added)!;
    _change(_doc.connect(wire.from, added, fromSide: wire.side, toSide: sideFacing(_rectOf(node), wire.start)));
  }

  // ——— пальцы и перетаскивание ———

  /// Карточки, которые едут сейчас: взятая, выбранные вместе с ней и содержимое групп.
  Set<String> _carried = const {};
  bool _moved = false;

  void _grab(String id, int pointer, {required bool resize}) {
    if (!_editable || _hold != null || _pointers.isNotEmpty || _connecting) return;
    _carried = resize ? {id} : _withContents(_selected.contains(id) ? _selected : {id});
    _heldView = transform.value.clone();
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
        for (final moving in _carried) {
          final one = _doc.node(moving);
          if (one != null) _doc = _doc.updateNode(moving, {'x': one.x + delta.dx, 'y': one.y + delta.dy});
        }
      }
      _moved = true;
    });
  }

  /// Отпустили: координаты целые, правка пишется.
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

  void _pointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    // второй палец: это щипок, карточку больше не тащим
    if (_pointers.length > 1) _drop();
  }

  void _pointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_hold?.pointer == event.pointer) _drop();
  }

  // ——— действия ———

  /// Касание карточки. Мышь выбирает ещё на нажатии (с Shift — добавляет), поэтому
  /// касание мышью только завершает «Связать».
  void _tapNode(CanvasNode node, PointerDeviceKind kind) {
    if (_connecting && _selected.length == 1) {
      final from = _selected.single;
      setState(() => _connecting = false);
      _change(_doc.connect(from, node.id));
      return;
    }
    if (kind == PointerDeviceKind.mouse) return;
    setState(() {
      _selected
        ..clear()
        ..add(node.id);
      _selectedEdge = null;
    });
  }

  Future<void> _add() async {
    final l = L.of(context);
    final what = await showOptionsSheet<String>(
      context,
      title: l.canvasAdd,
      options: [
        SheetChoice(value: 'note', title: l.canvasNote, icon: 'sticky_note_2'),
        SheetChoice(value: 'file', title: l.canvasAddNote, icon: 'description'),
        SheetChoice(value: 'text', title: l.canvasAddText, icon: 'notes'),
        SheetChoice(value: 'link', title: l.canvasAddLink, icon: 'link'),
        SheetChoice(value: 'group', title: l.canvasAddGroup, icon: 'select_all'),
      ],
    );
    if (what == null || !mounted) return;
    final at = _center;
    switch (what) {
      case 'note':
        await _addNote();
      case 'text':
        await _addText(at - const Offset(130, 70));
      case 'file':
        final target = await pickLinkTarget(context, ref, exceptId: widget.item.id);
        if (target == null) return;
        final path = await ref.read(documentsRepositoryProvider).pathOf(target.id);
        if (path == null || !mounted) return;
        final spot = _spot(at - const Offset(200, 150), 400, 300);
        _select(_doc.addFile(path, x: spot.dx, y: spot.dy));
      case 'link':
        final url = await _askText(context, hint: l.canvasLinkHint, multiline: false);
        if (url == null || url.trim().isEmpty) return;
        final full = url.contains('://') ? url.trim() : 'https://${url.trim()}';
        final spot = _spot(at - const Offset(200, 60), 400, 120);
        _select(_doc.addLink(full, x: spot.dx, y: spot.dy));
      case 'group':
        final label = await _askText(context, hint: l.canvasGroupHint, multiline: false, initial: l.canvasAddGroup);
        if (label == null) return;
        _select(_doc.addGroup(label.trim(), x: at.dx - 300, y: at.dy - 200));
    }
  }

  /// Записка: обычная заметка хранилища — её разложат по папкам угадыватель и ИИ, — а на
  /// холсте карточка-файл. [at] — точка мира, куда положить (без неё — середина экрана).
  /// Вернёт id узла; отказались — null.
  Future<String?> _addNote({Offset? at}) async {
    if (!_editable) return null;
    final text = await askCanvasNote(context);
    if (text == null || !mounted) return null;
    final center = at == null ? _center : at - const Offset(_origin, _origin);
    final id = await ref.read(captureServiceProvider).capture(CaptureInput(text: text));
    final path = await _pathOf(id);
    if (path == null || !mounted) return null;
    final spot = _spot(center - const Offset(150, 100), 300, 200);
    final next = _doc.addFile(path, x: spot.dx, y: spot.dy, width: 300, height: 200);
    final node = next.nodes.last;
    _placed[node.id] = id;
    _select(next, reveal: at == null);
    return node.id;
  }

  /// Путь новой заметки: писатель кладёт файл чуть позже сохранения, а угадыватель успевает
  /// разложить её по папке — ждём файла до 3 с, потом путь по папке и названию.
  Future<String?> _pathOf(String id) async {
    final documents = ref.read(documentsRepositoryProvider);
    for (var attempt = 0; attempt < 12; attempt++) {
      final written = await documents.writtenPathOf(id);
      if (written != null) return written;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return documents.pathOf(id);
  }

  /// Новый узел — последний (или первая группа): он и выбирается.
  void _select(CanvasDoc next, {bool reveal = true}) {
    final added = next.nodes.firstWhere((node) => _doc.node(node.id) == null);
    _change(next);
    setState(() {
      _selected
        ..clear()
        ..add(added.id);
      _selectedEdge = null;
    });
    if (reveal) _reveal(added);
  }

  /// Свободное место под новую карточку рядом с [wanted] (её левым верхним углом).
  Offset _spot(Offset wanted, double width, double height) {
    final spot = freeCanvasSpot(_doc.nodes, x: wanted.dx, y: wanted.dy, width: width, height: height);
    return Offset(spot.x.toDouble(), spot.y.toDouble());
  }

  /// Новая карточка видна целиком: окно сдвигается к ней, а крупная уменьшается до ширины экрана.
  void _reveal(CanvasNode node) {
    if (viewport.isEmpty) return;
    final scale = transform.value.getMaxScaleOnAxis();
    final visible = Size(viewport.width, max(120, viewport.height - 96));
    final topLeft = MatrixUtils.transformPoint(transform.value, Offset(node.x + _origin, node.y + _origin));
    final shown = Rect.fromLTWH(topLeft.dx, topLeft.dy, node.width * scale, node.height * scale);
    if (Offset.zero & visible case final view when view.contains(shown.topLeft) && view.contains(shown.bottomRight)) return;
    final next = min(scale, min((visible.width - 32) / node.width, (visible.height - 32) / node.height)).clamp(canvasMinScale, 1.2).toDouble();
    final center = Offset(node.x + node.width / 2 + _origin, node.y + node.height / 2 + _origin);
    final dx = visible.width / 2 - center.dx * next;
    final dy = visible.height / 2 - center.dy * next;
    transform.value = Matrix4.translationValues(dx, dy, 0) * Matrix4.diagonal3Values(next, next, next);
  }

  Future<void> _addText(Offset topLeft) async {
    final text = await _askText(context, hint: L.of(context).canvasTextHint);
    if (text == null || text.trim().isEmpty || !mounted) return;
    final at = _spot(topLeft, 260, 140);
    _select(_doc.addText(text.trim(), x: at.dx, y: at.dy));
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

  /// Убрать карточки (и их стрелки) одним «Отменить». Заметка за карточкой остаётся в хранилище.
  void _deleteNodes(Set<String> ids) {
    final l = L.of(context);
    final before = _doc;
    var next = _doc;
    for (final id in ids) {
      next = next.removeNode(id);
    }
    _change(next);
    setState(_clearSelection);
    showUndo(ScaffoldMessenger.of(context), message: ids.length == 1 ? l.canvasDeleted : l.selDeleted(ids.length), label: l.undo, onUndo: () => _change(before), overDock: true);
  }

  void _delete({CanvasNode? node, CanvasEdge? edge}) {
    if (node != null) return _deleteNodes({node.id});
    if (edge == null) return;
    final l = L.of(context);
    final before = _doc;
    _change(_doc.removeEdge(edge.id));
    setState(_clearSelection);
    showUndo(ScaffoldMessenger.of(context), message: l.canvasEdgeDeleted, label: l.undo, onUndo: () => _change(before), overDock: true);
  }

  /// Правый щелчок и долгое нажатие: те же действия, что у полосы выбранной карточки.
  Future<void> _nodeMenu(CanvasNode node) async {
    if (!_editable) return;
    final l = L.of(context);
    final canOpen = node.type == CanvasNodeType.file || node.type == CanvasNodeType.link;
    final canEdit = node.type != CanvasNodeType.file && node.type != CanvasNodeType.unknown;
    final what = await showOptionsSheet<String>(
      context,
      options: [
        if (canOpen) SheetChoice(value: 'open', title: l.catalogOpenFolder, icon: 'open_in_new'),
        if (canEdit) SheetChoice(value: 'edit', title: l.canvasEdit, icon: 'edit'),
        SheetChoice(value: 'connect', title: l.canvasConnect, icon: 'arrow_right_alt'),
        SheetChoice(value: 'color', title: l.canvasColor, icon: 'palette'),
        SheetChoice(value: 'delete', title: l.canvasDelete, icon: 'delete', danger: true),
      ],
    );
    if (what == null || !mounted) return;
    switch (what) {
      case 'open':
        await _open(node);
      case 'edit':
        await _edit(node);
      case 'connect':
        setState(() {
          _selected
            ..clear()
            ..add(node.id);
          _connecting = true;
        });
      case 'color':
        await _color(node: node);
      case 'delete':
        _deleteNodes({node.id});
    }
  }

  Future<void> _rename() async {
    final name = await showRenameSheet(context, widget.item.title, label: L.of(context).baseColName);
    if (name == null || name.trim().isEmpty) return;
    await ref.read(documentsRepositoryProvider).rename(widget.item.id, name.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final filesRoot = ref.watch(filesRootProvider);
    final selected = _selected.length == 1 ? _doc.node(_selected.single) : null;
    final selectedEdge = _selectedEdge == null ? null : _doc.edge(_selectedEdge!);
    final groups = [for (final node in _doc.nodes) if (node.type == CanvasNodeType.group) node];
    final cards = [for (final node in _doc.nodes) if (node.type != CanvasNodeType.group) node];
    final hover = _wire?.from ?? _hover;
    // стрелки файла: свои стороны, цвета и концы, как их записал Obsidian
    _links = [
      for (final edge in _doc.edges)
        if ((_doc.node(edge.fromNode), _doc.node(edge.toNode)) case (final from?, final to?))
          if (edgeCurve(from, to, edge) case final curve)
            CanvasLink(
              edge.fromNode,
              edge.toNode,
              curve.start + const Offset(_origin, _origin),
              curve.c1 + const Offset(_origin, _origin),
              curve.c2 + const Offset(_origin, _origin),
              curve.end + const Offset(_origin, _origin),
              key: edge.id,
              selected: edge.id == _selectedEdge,
              arrow: edge.toEnd == CanvasEnd.arrow,
              backArrow: edge.fromEnd == CanvasEnd.arrow,
              color: canvasColorOf(edge.color),
            ),
    ];

    Widget place(CanvasNode node) => Positioned(
      key: ValueKey(node.id),
      left: _origin + node.x,
      top: _origin + node.y,
      width: node.width.toDouble(),
      height: node.height.toDouble(),
      child: _NodeView(
        node: node,
        filesRoot: filesRoot,
        selected: _selected.contains(node.id),
        lifted: _hold?.id == node.id,
        editable: _editable,
        onTap: (kind) => _tapNode(node, kind),
        onDoubleTap: () => node.type == CanvasNodeType.text || node.type == CanvasNodeType.group ? _edit(node) : _open(node),
        onMouseDown: () => _mouseOnNode(node.id),
        onMenu: () => _nodeMenu(node),
        onGrab: (pointer, {required resize}) => _grab(node.id, pointer, resize: resize),
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
                  if (Navigator.canPop(context)) ...[
                    _RoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.maybePop(context)),
                    const SizedBox(width: 12),
                  ],
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
                  viewport = constraints.biggest;
                  // первый показ — всё целиком: размер окна известен только здесь
                  if (!_fitted && !viewport.isEmpty) {
                    _fitted = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? fitAll() : null);
                  }
                  return Focus(
                    focusNode: canvasFocus,
                    onKeyEvent: _onFocusKey,
                    child: Stack(
                      key: canvasKey,
                      children: [
                        Positioned.fill(child: CustomPaint(painter: CanvasDotsPainter(transform, step: _dotStep))),
                        // слушатель пальцев не отбирает жест у холста: он только считает пальцы
                        Listener(
                          onPointerDown: _pointerDown,
                          onPointerUp: _pointerUp,
                          onPointerCancel: _pointerUp,
                          child: MouseRegion(
                            // мышью пустое место тянут, как лист бумаги
                            cursor: _hold == null ? SystemMouseCursors.grab : SystemMouseCursors.grabbing,
                            child: InteractiveViewer(
                              key: const ValueKey('canvas-board'),
                              transformationController: transform,
                              constrained: false,
                              minScale: canvasMinScale,
                              maxScale: canvasMaxScale,
                              // колесо масштабирует только с Ctrl (canvasSignal); щипок пальцами — как был
                              scaleFactor: double.maxFinite,
                              // палец ведёт карточку, мышь тянет рамку или провод — холст под ними не едет
                              panEnabled: _hold == null && _marqueeStart == null && _wire == null,
                              onInteractionUpdate: (details) {
                                final held = _heldView;
                                if ((_hold != null || _marqueeStart != null || _wire != null) && details.pointerCount == 1 && held != null) transform.value = held.clone();
                              },
                              boundaryMargin: const EdgeInsets.all(_world),
                              // слушатель внутри просмотрщика слышит колесо первым: колесо листает
                              child: Listener(
                                behavior: HitTestBehavior.opaque,
                                onPointerSignal: canvasSignal,
                                onPointerDown: (event) {
                                  if (event.kind == PointerDeviceKind.mouse) {
                                    // щёлкнули мышью по холсту — клавиши теперь ему
                                    canvasFocus.requestFocus();
                                    final edge = _cardHit ? null : _edgeAt(event.localPosition);
                                    if (!_cardHit && HardwareKeyboard.instance.isShiftPressed) {
                                      // Shift по пустому месту — рамка выбора вместо сдвига холста
                                      setState(() {
                                        _marqueeStart = event.localPosition;
                                        _marquee = Rect.fromPoints(event.localPosition, event.localPosition);
                                        _heldView = transform.value.clone();
                                      });
                                    } else if (edge != null) {
                                      setState(() {
                                        _selectedEdge = edge;
                                        _selected.clear();
                                      });
                                    } else if (!_cardHit && (_selected.isNotEmpty || _selectedEdge != null)) {
                                      setState(_clearSelection);
                                    }
                                  }
                                  _cardHit = false;
                                },
                                // мышь над карточкой — у неё проявляются точки-выходы
                                onPointerHover: (event) {
                                  final under = _editable ? _nodeAt(event.localPosition, margin: 18)?.id : null;
                                  if (under != _hover) setState(() => _hover = under);
                                },
                                onPointerMove: (event) {
                                  final start = _marqueeStart;
                                  if (start != null) setState(() => _marquee = Rect.fromPoints(start, event.localPosition));
                                  final wire = _wire;
                                  if (wire != null) setState(() => _wire = (from: wire.from, side: wire.side, start: wire.start, normal: wire.normal, end: event.localPosition));
                                },
                                onPointerUp: (event) {
                                  if (_marqueeStart != null) _endMarquee();
                                  if (_wire != null) _endWire().ignore();
                                },
                                child: GestureDetector(
                                  // правый щелчок по стрелке — убрать её
                                  onSecondaryTapDown: (details) {
                                    final edge = _edgeAt(details.localPosition);
                                    if (edge != null && _editable) _delete(edge: _doc.edge(edge));
                                  },
                                  child: SizedBox(
                                    width: _world,
                                    height: _world,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        // пустое место: касание снимает выбор, двойное — новая заметка там
                                        Positioned.fill(
                                          child: GestureDetector(
                                            key: const ValueKey('canvas-empty'),
                                            behavior: HitTestBehavior.opaque,
                                            // мышь снимает выбор ещё на нажатии (там же — щелчок по стрелке)
                                            onTapUp: (details) {
                                              if (details.kind != PointerDeviceKind.mouse) setState(_clearSelection);
                                            },
                                            onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
                                            onDoubleTap: _editable ? () => _addNote(at: _doubleTapAt).ignore() : null,
                                          ),
                                        ),
                                        // группы под стрелками, карточки над ними: так рисует и Obsidian
                                        for (final node in groups) place(node),
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: CustomPaint(key: const ValueKey('canvas-links'), painter: CanvasLinksPainter(_links, ink: Tokens.onSurfaceVariant, accent: Tokens.accent, view: transform)),
                                          ),
                                        ),
                                        for (final node in cards) place(node),
                                        // стрелки карточки под мышью и выбранных — поверх карточек
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: CustomPaint(
                                              key: const ValueKey('canvas-links-over'),
                                              painter: CanvasLinksPainter(
                                                [
                                                  for (final link in _links)
                                                    if (link.selected || {link.from, link.to}.any((id) => id == hover || _selected.contains(id))) link.lit(),
                                                ],
                                                ink: Tokens.accent,
                                                accent: Tokens.accent,
                                                view: transform,
                                              ),
                                            ),
                                          ),
                                        ),
                                        for (final edge in _doc.edges) _edgeHandle(edge, text),
                                        if (_wire case final wire?)
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: CustomPaint(
                                                painter: CanvasLinksPainter([CanvasLink.wire(wire.from, wire.start, wire.normal, wire.end)], ink: Tokens.accent, accent: Tokens.accent, view: transform),
                                              ),
                                            ),
                                          ),
                                        if (hover != null)
                                          if (_doc.node(hover) case final node?)
                                            ...canvasSocketDots(id: hover, rect: _rectOf(node), view: transform, onStart: (side, point, normal) => _startWire(hover, side, point, normal)),
                                        if (_marquee case final marquee?) canvasMarquee(marquee),
                                      ],
                                    ),
                                  ),
                                ),
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
                          Positioned(top: 8, left: Space.screen, right: 72, child: _Banner(text: l.canvasConnectHint, icon: 'arrow_right_alt'))
                        // двойное касание по пустому месту нигде не нарисовано
                        else if (_editable)
                          const Positioned(top: 8, left: Space.screen, right: 72, child: HintBanner(tip: Tip.canvas)),
                        Positioned(
                          top: 12,
                          right: Space.screen,
                          child: CanvasTools(view: transform, onFit: fitAll, onNote: _editable ? () => _addNote().ignore() : null),
                        ),
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
                                  child: selected != null && _editable
                                      ? _NodeActions(
                                          node: selected,
                                          onEdit: selected.type == CanvasNodeType.file ? null : () => _edit(selected),
                                          onOpen: selected.type == CanvasNodeType.file || selected.type == CanvasNodeType.link ? () => _open(selected) : null,
                                          onConnect: () => setState(() => _connecting = true),
                                          onColor: () => _color(node: selected),
                                          onDelete: () => _delete(node: selected),
                                        )
                                      : selectedEdge != null && _editable
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
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Offset? _doubleTapAt;


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
            _selected.clear();
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

class _NodeView extends ConsumerWidget {
  const _NodeView({
    required this.node,
    required this.filesRoot,
    required this.selected,
    required this.lifted,
    required this.editable,
    required this.onTap,
    required this.onDoubleTap,
    required this.onMouseDown,
    required this.onMenu,
    required this.onGrab,
    required this.onDrag,
  });

  final CanvasNode node;
  final Directory filesRoot;
  final bool selected;

  /// Её сейчас тянут.
  final bool lifted;
  final bool editable;
  final ValueChanged<PointerDeviceKind> onTap;
  final VoidCallback onDoubleTap;

  /// Нажата кнопка мыши над карточкой: выбрать её (с Shift — добавить).
  final VoidCallback onMouseDown;

  /// Правый щелчок и долгое нажатие: меню карточки.
  final VoidCallback onMenu;
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
      CanvasNodeType.file => _FileFace(path: node.file ?? '', subpath: node.subpath, filesRoot: filesRoot, missing: l.canvasMissingFile(node.file ?? '')),
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
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse) onMouseDown();
        // правая кнопка открывает меню, а не тащит
        if (event.buttons & kSecondaryMouseButton == 0) onGrab(event.pointer, resize: false);
      },
      onPointerMove: (event) => onDrag(event.pointer, event.localDelta),
      child: MouseRegion(
        cursor: !editable ? SystemMouseCursors.basic : (lifted ? SystemMouseCursors.grabbing : SystemMouseCursors.move),
        child: GestureDetector(
          key: ValueKey('node-${node.id}'),
          onTapUp: (details) => onTap(details.kind),
          onDoubleTap: onDoubleTap,
          onSecondaryTap: onMenu,
          onLongPress: onMenu,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedScale(
                  scale: lifted && !group ? 1.02 : 1,
                  duration: const Duration(milliseconds: 120),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(group ? 24 : 16),
                      border: Border.all(color: lifted ? Tokens.accent : border, width: selected || lifted ? 2.5 : (group || color != null ? 2 : 0)),
                    ),
                    child: face,
                  ),
                ),
              ),
              // угол: тянешь — карточка меняет размер
              if (editable)
                Positioned(
                  right: -14,
                  bottom: -14,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    // угол глубже карточки и слышит палец первым: дальше карточка его уже не возьмёт
                    onPointerDown: (event) => onGrab(event.pointer, resize: true),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: Container(
                        key: ValueKey('resize-${node.id}'),
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        child: selected
                            ? Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(color: Tokens.accent, shape: BoxShape.circle),
                                child: Icon(symbolIcon('open_in_full'), size: 14, color: Tokens.onAccent),
                              )
                            : Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(color: Tokens.accent, shape: BoxShape.circle, border: Border.all(color: Tokens.background, width: 2)),
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
  const _FileFace({required this.path, required this.filesRoot, required this.missing, this.subpath});

  final String path;

  /// `#Заголовок` или `#^метка`: на карточке только этот раздел, как в Obsidian.
  final String? subpath;
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
                Expanded(
                  child: Text(
                    [found.title, ?sectionTitle(subpath)].join(' › '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRect(
                child: MarkedText.note(noteSection(found.body, subpath), style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4), maxLines: 200, overflow: TextOverflow.fade),
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
