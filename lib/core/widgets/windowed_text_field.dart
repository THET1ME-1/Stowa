import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../domain/text_diff.dart';
import '../../domain/text_pieces.dart';
import '../user_first.dart';

/// Поле для длинного текста, которое на каждую букву верстает только кусок у курсора.
///
/// Flutter перекладывает весь текст поля на каждую букву: около 0,6 мс на тысячу знаков на
/// ноутбуке и в 2–3 раза дольше на телефоне, и заметка в 10 тысяч знаков не даёт 60 кадров в
/// секунду (замер — `tool/typing_cost_test.dart`). Здесь живое поле держит окно: три куска
/// примерно по [pieceLength] знаков вокруг курсора. Остальной текст лежит неподвижными кусками
/// только для чтения, свёрстанными один раз. Неподвижный кусок — тот же `EditableText` с тем же
/// стилем, поэтому строки ложатся пиксель в пиксель, и переезд окна глазу не виден.
///
/// Правда — [document]: весь текст и выделение. Живое поле — [window]: его заводит хозяин,
/// заполняет через [windowFor] до первого показа и красит своим контроллером; неподвижные куски
/// красит такой же контроллер из [pieceController]. Окно едет за курсором, когда тот уходит из
/// среднего куска. Выделение шире курсора раскрывает окно на весь текст: выделять, копировать и
/// заменять можно что угодно, а когда выделение снято, окно снова сужается. Отмена и повтор
/// ведутся по всему тексту ([undoController]), а не по окну.
///
/// Короткий текст (до [wholeLimit] знаков) — одно поле целиком, как обычный `TextField`.
class WindowedTextField extends StatefulWidget {
  const WindowedTextField({
    super.key,
    required this.document,
    required this.window,
    required this.pieceController,
    required this.focusNode,
    required this.style,
    this.decoration,
    this.undoController,
    this.inputFormatters,
    this.contextMenuBuilder,
    this.contentInsertionConfiguration,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType = TextInputType.multiline,
    this.scrollPadding = const EdgeInsets.all(20),
    this.sliver = false,
    this.keepCaret = false,
  });

  /// Текст не длиннее — одно поле целиком.
  static const wholeLimit = 1500;

  /// Примерная длина куска. Окно — три куска, около 1200 знаков: в браузере текст верстает
  /// WebAssembly, и окно в 2200 знаков изредка выходило за кадр, а в 1200 — укладывается.
  static const pieceLength = 400;

  /// Живое поле разрослось вдвое (набрали, вставили) — на паузе оно снова сужается.
  static const windowLimit = 2400;

  final TextEditingController document;
  final TextEditingController window;
  final TextEditingController Function(String text) pieceController;
  final FocusNode focusNode;
  final TextStyle style;
  final InputDecoration? decoration;
  final UndoHistoryController? undoController;
  final List<TextInputFormatter>? inputFormatters;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final ContentInsertionConfiguration? contentInsertionConfiguration;
  final TextCapitalization textCapitalization;
  final TextInputType keyboardType;
  final EdgeInsets scrollPadding;

  /// Слоем прокрутки (`SliverList`): каждый кусок — свой ребёнок списка, верстаются только
  /// видимые. Колонкой при входе в правку верстался весь текст разом — на телефоне секунду и
  /// больше в потоке, через который идёт клавиатура, и она дёргалась, открываясь (тестировщик
  /// 23.11). Живое поле, пока в фокусе, список не выбрасывает и за краем экрана
  /// (`EditableText` держит себя сам, `AutomaticKeepAlive`). Касания неподвижных кусков ловит
  /// [WindowedTouches] над списком.
  ///
  /// Живое поле строится, только когда оно у экрана. Курсор при входе оказался за экраном
  /// (в конце длинной заметки, а смотрят на начало) — он переходит на первый видимый кусок:
  /// иначе фокус ждал бы поля, которого нет, и клавиатура не встала бы, а прокрутка к концу
  /// сверстала бы весь текст.
  final bool sliver;

  /// Курсор остаётся, где его поставили, даже за экраном («Дописать» — в конце): прокрутка
  /// идёт до живого поля.
  final bool keepCaret;

  /// Что покажет живое поле для [document]: им хозяин заполняет [window] до первого показа,
  /// иначе поле заполнило бы его само посреди построения экрана.
  static TextEditingValue windowFor(TextEditingValue document) {
    final plan = _plan(_cut(document.text), document, whole: false);
    return _local(document, plan.start, plan.end);
  }

  @override
  State<WindowedTextField> createState() => _WindowedTextFieldState();
}

/// Касания неподвижных кусков [WindowedTextField] со `sliver: true`: распознаватели стоят над
/// списком прокрутки, а не в куске. Протяжка мышью раскрывает окно на весь текст, кусок, на
/// котором её начали, уходит из дерева — распознаватель в нём умер бы посреди протяжки.
/// Касание мимо неподвижных кусков распознаватели не берут, как и у поля колонкой.
class WindowedTouches extends StatefulWidget {
  const WindowedTouches({super.key, required this.child});

  final Widget child;

  @override
  State<WindowedTouches> createState() => _WindowedTouchesState();
}

class _WindowedTouchesState extends State<WindowedTouches> {
  Map<Type, GestureRecognizerFactory> _gestures = const {};

  // поле приходит посреди построения и уходит посреди разборки дерева: меняем после кадра
  void _use(Map<Type, GestureRecognizerFactory> gestures) {
    if (identical(gestures, _gestures)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !identical(gestures, _gestures)) setState(() => _gestures = gestures);
    });
  }

  void _drop(Map<Type, GestureRecognizerFactory> gestures) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(gestures, _gestures)) setState(() => _gestures = const {});
    });
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(behavior: HitTestBehavior.translucent, gestures: _gestures, child: widget.child);
}

/// Кусок текста и блок (код, формула), открытый на его начале.
typedef _Cut = ({String text, String? open});

/// Куски документа: длинный режется по [textPieces], короткий — одним куском.
List<_Cut> _cut(String text) => text.length <= WindowedTextField.wholeLimit ? [(text: text, open: null)] : _pieces(text, null);

/// Куски любого текста по [textPieces]: так режется и окно, когда переезжает, — от блока [open],
/// открытого на его начале.
List<_Cut> _pieces(String text, String? open) => [
  for (final piece in textPieces(text, target: WindowedTextField.pieceLength, open: open)) (text: text.substring(piece.start, piece.end), open: piece.open),
];

/// Какие куски идут в окно: средний — с курсором, по одному соседу с боков.
({int first, int last, int middle, int start, int end, int middleStart, int middleEnd}) _plan(List<_Cut> cuts, TextEditingValue document, {required bool whole}) {
  final selection = document.selection;
  // выделение шире курсора — окно на весь текст
  final texts = whole || document.text.length <= WindowedTextField.wholeLimit || (selection.isValid && !selection.isCollapsed) ? [document.text] : [for (final cut in cuts) cut.text];
  final ranges = <(int, int)>[];
  var at = 0;
  for (final text in texts) {
    ranges.add((at, at + text.length));
    at += text.length + 1;
  }
  final caret = selection.isValid ? selection.extentOffset.clamp(0, document.text.length) : document.text.length;
  var middle = ranges.indexWhere((range) => caret <= range.$2);
  if (middle < 0) middle = ranges.length - 1;
  final first = math.max(0, middle - 1);
  final last = math.min(ranges.length - 1, middle + 1);
  return (first: first, last: last, middle: middle, start: ranges[first].$1, end: ranges[last].$2, middleStart: ranges[middle].$1 - ranges[first].$1, middleEnd: ranges[middle].$2 - ranges[first].$1);
}

/// Кусок документа `[start, end)` своим отсчётом: выделение и набор сдвинуты к его началу.
TextEditingValue _local(TextEditingValue document, int start, int end) {
  final composing = document.composing;
  return TextEditingValue(
    text: document.text.substring(start, end),
    selection: _moved(document.selection, -start),
    composing: composing.isValid && composing.start >= start && composing.end <= end ? _movedRange(composing, -start) : TextRange.empty,
  );
}

TextSelection _moved(TextSelection selection, int by) => selection.isValid ? selection.copyWith(baseOffset: selection.baseOffset + by, extentOffset: selection.extentOffset + by) : selection;

TextRange _movedRange(TextRange range, int by) => range.isValid ? TextRange(start: range.start + by, end: range.end + by) : range;

class _WindowedTextFieldState extends State<WindowedTextField> with UndoManagerClient {
  // неподвижные куски выше и ниже окна
  final _above = <_Piece>[];
  final _below = <_Piece>[];
  final _liveKey = GlobalKey();

  // где окно начинается в документе, его текст и весь текст на прошлой правке
  var _start = 0;
  var _windowText = '';
  var _docText = '';

  // блоки (код, формула), открытые на начале и на конце окна: правилам набора их подставляют,
  // иначе посреди длинного листинга «--» стало бы тире
  String? _windowOpen;
  String? _windowClose;

  // средний кусок окна его же отсчётом: курсор ушёл из него — окно переезжает
  var _middleStart = 0;
  var _middleEnd = 0;

  // своя запись в документ или окно: слушатели её не разбирают
  var _syncing = false;
  // отмена или повтор: в историю не пишется
  var _applying = false;
  var _settleQueued = false;
  // «Выделить всё» из меню выделило окно — раскрытое окно выделит весь текст
  var _selectAll = false;
  Timer? _shrinkTimer;
  late _History _history;
  TextStyle? _pieceStyle;

  // протяжка мышью, начатая на неподвижном куске
  Offset? _dragFrom;
  var _dragScroll = 0.0;
  var _dragReady = false;

  // после касания неподвижного куска второе касание (двойное) достаётся ему же, а не живому
  // полю, которое за это время встало под палец
  var _swallowing = false;
  Timer? _swallowTimer;
  final _tapClock = Stopwatch()..start();
  Duration? _lastTap;
  Offset? _lastTapAt;

  bool get _whole => _above.isEmpty && _below.isEmpty;

  // распознаватели над списком прокрутки (поле слоем прокрутки)
  _WindowedTouchesState? _outer;

  @override
  void initState() {
    super.initState();
    _history = _History(widget.document.value);
    _listen(widget);
    _docText = widget.document.text;
    final plan = _plan(_cut(_docText), widget.document.value, whole: false);
    _place(_cut(_docText), plan, widget.document.value, rebuild: false);
    // значения отмены и повтора — после кадра: их слушают кнопки, которые сейчас строятся
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publish();
      if (widget.sliver) _arrive(0);
    });
  }

  /// Поле слоем прокрутки встало, а живого поля нет на экране: курсор — на первый видимый
  /// кусок, а с [WindowedTextField.keepCaret] — прокрутка к живому полю.
  void _arrive(int tries) {
    if (!mounted || _liveKey.currentContext != null) return;
    if (!widget.keepCaret) {
      if (_firstOnScreen() case final offset?) _select(TextSelection.collapsed(offset: offset));
      return;
    }
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null || tries > 40) return;
    // кусок выше окна построен — живое поле ниже, иначе выше
    final below = _above.any((piece) => piece.key.currentContext != null);
    position.jumpTo(below ? position.maxScrollExtent : position.minScrollExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _arrive(tries + 1));
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Начало первого неподвижного куска на экране, в отсчёте всего текста.
  int? _firstOnScreen() {
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return null;
    final top = viewport.localToGlobal(Offset.zero).dy;
    final bottom = top + viewport.size.height;
    bool shown(_Piece piece) {
      final box = piece.key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return false;
      final at = box.localToGlobal(Offset.zero).dy;
      return at + box.size.height > top && at < bottom;
    }

    var start = 0;
    for (final piece in _above) {
      if (shown(piece)) return start;
      start += piece.text.length + 1;
    }
    start = _start + _windowText.length + 1;
    for (final piece in _below) {
      if (shown(piece)) return start;
      start += piece.text.length + 1;
    }
    return null;
  }

  void _listen(WindowedTextField of) {
    of.document.addListener(_onDocument);
    of.window.addListener(_onWindow);
    of.undoController?.onUndo.addListener(undo);
    of.undoController?.onRedo.addListener(redo);
    of.focusNode.addListener(_onFocus);
  }

  void _unlisten(WindowedTextField of) {
    of.document.removeListener(_onDocument);
    of.window.removeListener(_onWindow);
    of.undoController?.onUndo.removeListener(undo);
    of.undoController?.onRedo.removeListener(redo);
    of.focusNode.removeListener(_onFocus);
  }

  @override
  void didUpdateWidget(WindowedTextField old) {
    super.didUpdateWidget(old);
    if (old.document == widget.document && old.window == widget.window && old.undoController == widget.undoController && old.focusNode == widget.focusNode) return;
    _unlisten(old);
    _listen(widget);
    _history.dispose();
    _history = _History(widget.document.value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _docText = widget.document.text;
      _arrangeFresh(widget.document.value);
      _publish();
    });
  }

  @override
  void dispose() {
    _outer?._drop(_gestures);
    _unlisten(widget);
    _shrinkTimer?.cancel();
    _swallowTimer?.cancel();
    _history.dispose();
    if (UndoManager.client == this) UndoManager.client = null;
    for (final piece in [..._above, ..._below]) {
      piece.dispose();
    }
    super.dispose();
  }

  // ——— куски и окно ———

  /// Раскладка заново по всему тексту: правка пришла снаружи и мимо окна.
  void _arrangeFresh(TextEditingValue doc) {
    final cuts = _cut(doc.text);
    _place(cuts, _plan(cuts, doc, whole: _dragFrom != null), doc);
  }

  /// Окно переезжает к курсору: неподвижные куски остаются как были, режется только окно.
  void _recenter(TextEditingValue doc) {
    final cuts = [
      for (final piece in _above) (text: piece.text, open: piece.open),
      ..._pieces(_windowText, _windowOpen),
      for (final piece in _below) (text: piece.text, open: piece.open),
    ];
    _place(cuts, _plan(cuts, doc, whole: _dragFrom != null), doc);
  }

  /// Окно на весь текст.
  void _placeWhole(TextEditingValue doc) {
    final cuts = [(text: doc.text, open: null)];
    _place(cuts, _plan(cuts, doc, whole: true), doc);
  }

  void _place(List<_Cut> cuts, ({int first, int last, int middle, int start, int end, int middleStart, int middleEnd}) plan, TextEditingValue doc, {bool rebuild = true}) {
    final whole = plan.start == 0 && plan.end == doc.text.length;
    // свои куски с тем же текстом берутся снова: их вёрстка уже готова
    String keyOf(String text, String? open) => '$open\u0000$text';
    final pool = <String, List<_Piece>>{};
    for (final piece in [..._above, ..._below]) {
      (pool[keyOf(piece.text, piece.open)] ??= []).add(piece);
    }
    _Piece take(_Cut cut) {
      final same = pool[keyOf(cut.text, cut.open)];
      if (same != null && same.isNotEmpty) return same.removeLast();
      return _Piece(cut.text, cut.open, widget.pieceController(cut.text));
    }

    final above = whole ? <_Piece>[] : [for (var index = 0; index < plan.first; index++) take(cuts[index])];
    final below = whole ? <_Piece>[] : [for (var index = plan.last + 1; index < cuts.length; index++) take(cuts[index])];
    final unused = [for (final same in pool.values) ...same];
    _above
      ..clear()
      ..addAll(above);
    _below
      ..clear()
      ..addAll(below);
    _windowOpen = whole ? null : cuts[plan.first].open;
    _windowClose = whole || plan.last + 1 >= cuts.length ? null : cuts[plan.last + 1].open;
    _start = plan.start;
    _middleStart = whole ? 0 : plan.middleStart;
    _middleEnd = whole ? doc.text.length : plan.middleEnd;
    _docText = doc.text;
    _setWindow(_local(doc, plan.start, plan.end));
    if (unused.isNotEmpty) {
      // куски ещё в дереве до конца кадра
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final piece in unused) {
          piece.dispose();
        }
      });
    }
    if (rebuild && mounted) setState(() {});
  }

  void _setWindow(TextEditingValue local) {
    _windowText = local.text;
    if (widget.window.value == local) return;
    _syncing = true;
    widget.window.value = local;
    _syncing = false;
  }

  /// Правка в живом поле: документ собирается из неподвижных кусков и окна.
  void _onWindow() {
    if (_syncing) return;
    // буква или курсор — человек занят: фон и пересчёты ждут (UserFirst)
    userFirst.type();
    final local = widget.window.value;
    var text = _docText;
    if (local.text != _windowText) {
      final edit = editedRange(_windowText, local.text);
      text = _docText.replaceRange(_start, _start + _windowText.length, local.text);
      _moveMiddle(edit);
      _windowText = local.text;
    }
    final changed = text != _docText;
    _docText = text;
    final doc = TextEditingValue(text: text, selection: _moved(local.selection, _start), composing: _movedRange(local.composing, _start));
    _syncing = true;
    widget.document.value = doc;
    _syncing = false;
    if (changed) _record(doc);
    _watch();
  }

  /// Правка документа снаружи (разметка, ссылка, картинка, отмена): в окно, если она в нём.
  void _onDocument() {
    if (_syncing) return;
    final doc = widget.document.value;
    final before = _docText;
    if (doc.text != before && !_applying) _record(doc);
    if (_whole) {
      _docText = doc.text;
      _setWindow(doc);
      _watch();
      return;
    }
    final end = _start + _windowText.length;
    final selection = doc.selection;
    bool covers(int until) => !selection.isValid || (selection.start >= _start && selection.end <= until);
    if (doc.text == before) {
      if (covers(end) && selection.isCollapsed) {
        _setWindow(_local(doc, _start, end));
        _watch();
      } else {
        _recenter(doc);
      }
      return;
    }
    final edit = editedRange(before, doc.text);
    final until = end + edit.delta;
    if (edit.start >= _start && edit.end <= end && covers(until) && selection.isCollapsed) {
      _docText = doc.text;
      _moveMiddle(EditedRange(edit.start - _start, edit.end - _start, edit.delta));
      _setWindow(_local(doc, _start, until));
      _watch();
      return;
    }
    _arrangeFresh(doc);
  }

  // средний кусок растёт и сдвигается вместе с правкой окна
  void _moveMiddle(EditedRange edit) {
    if (edit.end <= _middleStart && edit.start < _middleStart) {
      _middleStart += edit.delta;
      _middleEnd += edit.delta;
    } else if (edit.start <= _middleEnd) {
      _middleEnd = math.max(_middleStart, _middleEnd + edit.delta);
    }
  }

  /// Нужно ли окну переехать: решается после кадра, чтобы не мешать полю посреди его правки.
  void _watch() {
    final selection = widget.window.value.selection;
    if (!selection.isValid) return;
    final long = _docText.length > WindowedTextField.wholeLimit;
    if (!selection.isCollapsed) {
      if (_whole) return;
      // меню «Выделить всё» выделяет только окно — значит, просили весь текст
      if (selection.start == 0 && selection.end == _windowText.length) _selectAll = true;
      return _later();
    }
    if (_whole ? long && _dragFrom == null : !long) return _later();
    if (!_whole && (selection.extentOffset < _middleStart || selection.extentOffset > _middleEnd)) return _later();
    if (!_whole && _windowText.length > WindowedTextField.windowLimit) {
      _shrinkTimer?.cancel();
      _shrinkTimer = Timer(const Duration(milliseconds: 400), () => _settle(shrink: true));
    }
  }

  void _later() {
    if (_settleQueued) return;
    _settleQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settleQueued = false;
      _settle();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _settle({bool shrink = false}) {
    if (!mounted || _dragFrom != null) return;
    final doc = widget.document.value;
    final selection = doc.selection;
    if (selection.isValid && !selection.isCollapsed) {
      if (!_whole) _expand(doc);
      return;
    }
    if (doc.text.length <= WindowedTextField.wholeLimit) {
      if (!_whole) _placeWhole(doc);
      return;
    }
    // пока клавиатура собирает слово, окно не трогаем: она потеряла бы его
    if (!doc.composing.isCollapsed) return;
    if (_whole) return _arrangeFresh(doc);
    final caret = selection.isValid ? selection.extentOffset - _start : _middleStart;
    final away = caret < _middleStart || caret > _middleEnd;
    if (away || (shrink && _windowText.length > WindowedTextField.windowLimit)) _recenter(doc);
  }

  /// Окно на весь текст: выделение шире курсора.
  void _expand(TextEditingValue doc) {
    // на телефоне выделение живёт с меню над ним: поле его прячет, когда текст меняется
    final toolbar = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
    if (_selectAll) {
      _selectAll = false;
      doc = doc.copyWith(selection: TextSelection(baseOffset: 0, extentOffset: doc.text.length));
      _syncing = true;
      widget.document.value = doc;
      _syncing = false;
    }
    _placeWhole(doc);
    if (toolbar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _live?.showToolbar();
      });
    }
  }

  EditableTextState? get _live {
    EditableTextState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is EditableTextState) {
        found = element.state as EditableTextState;
        return;
      }
      element.visitChildren(visit);
    }

    _liveKey.currentContext?.visitChildElements(visit);
    return found;
  }

  /// Выделение или курсор по всему тексту; окно переедет само.
  void _select(TextSelection selection) {
    final doc = widget.document.value;
    widget.document.value = doc.copyWith(selection: selection, composing: TextRange.empty);
  }

  void _toBoundary(bool forward, {required bool collapse}) {
    final doc = widget.document.value;
    final target = forward ? doc.text.length : 0;
    final base = collapse || !doc.selection.isValid ? target : doc.selection.baseOffset;
    _select(TextSelection(baseOffset: base, extentOffset: target));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _live?.bringIntoView(TextPosition(offset: target - _start));
    });
  }

  // ——— касания неподвижных кусков ———

  /// Что под точкой: начало куска в документе, место в документе и его вёрстка.
  ({int start, int offset, RenderEditable editable})? _hit(Offset global) {
    ({int start, int offset, RenderEditable editable})? check(RenderEditable? editable, int start) {
      if (editable == null || !editable.attached || !editable.hasSize) return null;
      final local = editable.globalToLocal(global);
      if (local.dy < 0 || local.dy >= editable.size.height) return null;
      return (start: start, offset: start + editable.getPositionForPoint(global).offset, editable: editable);
    }

    var start = 0;
    for (final piece in _above) {
      if (check(piece.key.currentState?.renderEditable, start) case final hit?) return hit;
      start += piece.text.length + 1;
    }
    if (_swallowing) {
      if (check(_live?.renderEditable, _start) case final hit?) return hit;
    }
    start = _start + _windowText.length + 1;
    for (final piece in _below) {
      if (check(piece.key.currentState?.renderEditable, start) case final hit?) return hit;
      start += piece.text.length + 1;
    }
    return null;
  }

  bool _onStatic(Offset global) => _hit(global) != null;

  void _swallow() {
    _swallowTimer?.cancel();
    if (!_swallowing) setState(() => _swallowing = true);
    _swallowTimer = Timer(kDoubleTapTimeout, () {
      if (mounted) setState(() => _swallowing = false);
    });
  }

  void _tapAt(Offset global, {bool menu = false}) {
    final hit = _hit(global);
    if (hit == null) return;
    _swallow();
    _select(TextSelection.collapsed(offset: hit.offset));
    widget.focusNode.requestFocus();
    if (menu) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _live?.showToolbar();
      });
    }
  }

  void _wordAt(Offset global, SelectionChangedCause cause, {required bool toolbar}) {
    final hit = _hit(global);
    if (hit == null) return;
    final word = hit.editable.getWordBoundary(TextPosition(offset: hit.offset - hit.start));
    _select(TextSelection(baseOffset: hit.start + word.start, extentOffset: hit.start + word.end));
    widget.focusNode.requestFocus();
    // окно раскроется на весь текст к следующему кадру: тогда то же слово выделит само поле —
    // с ручками и меню, как своё
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final live = _live;
      if (!mounted || live == null) return;
      live.renderEditable.selectWordsInRange(from: global, cause: cause);
      if (toolbar) live.showToolbar();
    });
  }

  void _touchTap(TapUpDetails details) {
    final now = _tapClock.elapsed;
    final last = _lastTap;
    final twice = last != null && now - last < kDoubleTapTimeout && (details.globalPosition - _lastTapAt!).distance < kDoubleTapSlop;
    _lastTap = twice ? null : now;
    _lastTapAt = details.globalPosition;
    if (twice) {
      _wordAt(details.globalPosition, SelectionChangedCause.doubleTap, toolbar: true);
    } else {
      _tapAt(details.globalPosition);
    }
  }

  void _mouseTap(TapDragUpDetails details) {
    if (details.consecutiveTapCount >= 2) {
      _wordAt(details.globalPosition, SelectionChangedCause.doubleTap, toolbar: false);
    } else {
      _tapAt(details.globalPosition);
    }
  }

  double get _scrollPixels => Scrollable.maybeOf(context)?.position.pixels ?? 0;

  void _dragStart(TapDragStartDetails details) {
    final hit = _hit(details.globalPosition);
    if (hit == null) return;
    _dragFrom = details.globalPosition;
    _dragScroll = _scrollPixels;
    _dragReady = false;
    _select(TextSelection.collapsed(offset: hit.offset));
    // тянут выделение: окно сразу на весь текст, протяжка дойдёт куда угодно
    if (!_whole) _placeWhole(widget.document.value);
    widget.focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _dragReady = true);
  }

  void _dragUpdate(TapDragUpdateDetails details) {
    final from = _dragFrom;
    final live = _live;
    if (from == null || !_dragReady || !_whole || live == null) return;
    live.renderEditable.selectPositionAt(from: from - Offset(0, _scrollPixels - _dragScroll), to: details.globalPosition, cause: SelectionChangedCause.drag);
  }

  void _dragEnd() {
    _dragFrom = null;
    _later();
  }

  late final Map<Type, GestureRecognizerFactory> _gestures = {
    _StaticMouse: GestureRecognizerFactoryWithHandlers<_StaticMouse>(
      () => _StaticMouse(_onStatic),
      (recognizer) => recognizer
        // выделение тянется от точки нажатия, а не от места, где мышь сдвинулась
        ..dragStartBehavior = DragStartBehavior.down
        ..onTapUp = _mouseTap
        ..onDragStart = _dragStart
        ..onDragUpdate = _dragUpdate
        ..onDragEnd = (_) => _dragEnd(),
    ),
    _StaticTap: GestureRecognizerFactoryWithHandlers<_StaticTap>(() => _StaticTap(_onStatic), (recognizer) => recognizer.onTapUp = _touchTap),
    _StaticMenu: GestureRecognizerFactoryWithHandlers<_StaticMenu>(() => _StaticMenu(_onStatic), (recognizer) => recognizer.onSecondaryTapUp = (details) => _tapAt(details.globalPosition, menu: true)),
    _StaticLongPress: GestureRecognizerFactoryWithHandlers<_StaticLongPress>(
      () => _StaticLongPress(_onStatic),
      (recognizer) => recognizer.onLongPressStart = (details) => _wordAt(details.globalPosition, SelectionChangedCause.longPress, toolbar: true),
    ),
  };

  // ——— отмена и повтор по всему тексту ———

  void _record(TextEditingValue doc) {
    _history.record(doc, _publish);
    _publish();
  }

  void _apply(TextEditingValue? value) {
    if (value == null) return;
    // курсор — у места отменённой правки, как в редакторах, а не где он стоял тогда: с первым
    // шагом истории запомнился курсор входа в правку, а он бывает в конце длинной заметки —
    // окно уехало бы за экран
    if (value.text != _docText) {
      final edit = editedRange(_docText, value.text);
      value = value.copyWith(selection: TextSelection.collapsed(offset: edit.end + edit.delta), composing: TextRange.empty);
    }
    _applying = true;
    widget.document.value = value;
    _applying = false;
    _publish();
  }

  void _publish() {
    if (!mounted) return;
    widget.undoController?.value = UndoHistoryValue(canUndo: _history.canUndo, canRedo: _history.canRedo);
    if (defaultTargetPlatform == TargetPlatform.iOS && UndoManager.client == this) {
      UndoManager.setUndoState(canUndo: _history.canUndo, canRedo: _history.canRedo);
    }
  }

  @override
  void undo() => _apply(_history.undo());

  @override
  void redo() => _apply(_history.redo());

  @override
  bool get canUndo => _history.canUndo;

  @override
  bool get canRedo => _history.canRedo;

  @override
  void handlePlatformUndo(UndoDirection direction) => direction == UndoDirection.undo ? undo() : redo();

  // на iPhone отмена встряхиванием идёт сюда, а не истории окна: та не знает про весь текст
  void _onFocus() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (widget.focusNode.hasFocus) {
      scheduleMicrotask(() {
        if (!mounted || !widget.focusNode.hasFocus) return;
        UndoManager.client = this;
        _publish();
      });
    } else if (UndoManager.client == this) {
      UndoManager.client = null;
    }
  }

  // ——— вид ———

  // каждый кусок на своём слое: буква в окне не перерисовывает весь текст
  Widget _view(_Piece piece) => piece.view ??= RepaintBoundary(
    key: ObjectKey(piece),
    child: MouseRegion(
      cursor: SystemMouseCursors.text,
      child: EditableText(
        key: piece.key,
        controller: piece.controller,
        focusNode: piece.focus,
        readOnly: true,
        showCursor: false,
        enableInteractiveSelection: false,
        rendererIgnoresPointer: true,
        maxLines: null,
        style: _pieceStyle!,
        cursorColor: const Color(0x00000000),
        backgroundCursorColor: const Color(0x00000000),
      ),
    ),
  );

  /// Что подставить правилам набора вокруг окна: строку, открывающую блок, сверху и
  /// закрывающую снизу, — если окно начинается или кончается посреди блока.
  (String, String) _context() => (_windowOpen == null ? '' : '$_windowOpen\n', _windowClose == null ? '' : '\n${blockCloser(_windowClose!)}');

  @override
  Widget build(BuildContext context) {
    // тот же стиль, что поле складывает из темы и своего: строки ложатся одинаково
    final pieceStyle = (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).merge(widget.style);
    if (pieceStyle != _pieceStyle) {
      _pieceStyle = pieceStyle;
      for (final piece in [..._above, ..._below]) {
        piece.view = null;
      }
    }
    final live = KeyedSubtree(
      key: _liveKey,
      child: RepaintBoundary(
        child: IgnorePointer(
          ignoring: _swallowing,
          child: Actions(
            // клавиши правки, которые смотрят на весь текст, а не на окно
            actions: <Type, Action<Intent>>{
              UndoTextIntent: CallbackAction<UndoTextIntent>(onInvoke: (_) => undo()),
              RedoTextIntent: CallbackAction<RedoTextIntent>(onInvoke: (_) => redo()),
              SelectAllTextIntent: CallbackAction<SelectAllTextIntent>(onInvoke: (_) => _select(TextSelection(baseOffset: 0, extentOffset: _docText.length))),
              ExtendSelectionToDocumentBoundaryIntent: CallbackAction<ExtendSelectionToDocumentBoundaryIntent>(onInvoke: (intent) => _toBoundary(intent.forward, collapse: intent.collapseSelection)),
            },
            child: TextField(
              controller: widget.window,
              focusNode: widget.focusNode,
              maxLines: null,
              keyboardType: widget.keyboardType,
              contentInsertionConfiguration: widget.contentInsertionConfiguration,
              contextMenuBuilder: widget.contextMenuBuilder ?? (context, state) => AdaptiveTextSelectionToolbar.editableText(editableTextState: state),
              inputFormatters: [for (final formatter in widget.inputFormatters ?? const <TextInputFormatter>[]) _InContext(formatter, _context)],
              textCapitalization: widget.textCapitalization,
              scrollPadding: widget.scrollPadding,
              style: widget.style,
              decoration: widget.decoration,
            ),
          ),
        ),
      ),
    );
    // касание доходит и туда, где живое поле на миг глухо (второе касание двойного);
    // где кусок не неподвижный, распознаватели касание не берут сами
    Widget touches(Widget child) => TextFieldTapRegion(
      child: RawGestureDetector(behavior: HitTestBehavior.translucent, gestures: _gestures, child: child),
    );
    if (widget.sliver) {
      final outer = _outer = context.findAncestorStateOfType<_WindowedTouchesState>();
      outer?._use(_gestures);
      // распознаватели над списком есть — куску остаётся только быть частью поля для касаний мимо
      Widget part(Widget child) => outer == null ? touches(child) : TextFieldTapRegion(child: child);
      // ключ — снаружи: список узнаёт ребёнка по нему, когда окно переезжает и номера сдвигаются
      return SliverList.list(
        children: [
          for (final piece in _above) KeyedSubtree(key: ObjectKey(piece), child: part(_view(piece))),
          KeyedSubtree(key: const ValueKey('live'), child: part(live)),
          for (final piece in _below) KeyedSubtree(key: ObjectKey(piece), child: part(_view(piece))),
        ],
      );
    }
    return touches(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final piece in _above) _view(piece), live, for (final piece in _below) _view(piece)],
      ),
    );
  }
}

/// Неподвижный кусок: свой контроллер для раскраски, фокус ему не нужен.
class _Piece {
  _Piece(this.text, this.open, this.controller);

  final String text;

  /// Блок (код, формула), открытый на начале куска.
  final String? open;
  final TextEditingController controller;
  final focus = FocusNode(canRequestFocus: false, skipTraversal: true);
  final key = GlobalKey<EditableTextState>();
  Widget? view;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

/// История всего текста, как у поля Flutter: правки подряд за полсекунды — один шаг.
class _History {
  _History(TextEditingValue first) : _stack = [first];

  static const _pause = Duration(milliseconds: 500);
  static const _limit = 300;

  final List<TextEditingValue> _stack;
  var _index = 0;
  TextEditingValue? _waiting;
  Timer? _timer;

  bool get canUndo => _index > 0 || (_waiting != null && _waiting!.text != _stack[_index].text);

  bool get canRedo => _waiting == null && _index < _stack.length - 1;

  void record(TextEditingValue value, VoidCallback changed) {
    _waiting = value;
    _timer ??= Timer(_pause, () {
      _timer = null;
      _flush();
      changed();
    });
  }

  void _flush() {
    final value = _waiting;
    _waiting = null;
    if (value == null || value.text == _stack[_index].text) return;
    _stack
      ..removeRange(_index + 1, _stack.length)
      ..add(value);
    if (_stack.length > _limit) _stack.removeAt(0);
    _index = _stack.length - 1;
  }

  TextEditingValue? undo() {
    _timer?.cancel();
    _timer = null;
    _flush();
    if (_index == 0) return null;
    return _stack[--_index];
  }

  TextEditingValue? redo() {
    if (_waiting != null || _index >= _stack.length - 1) return null;
    return _stack[++_index];
  }

  void dispose() => _timer?.cancel();
}

const _touchKinds = {PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.invertedStylus, PointerDeviceKind.unknown};

// распознаватели берут только касания неподвижных кусков: у живого поля свои

class _StaticMouse extends TapAndPanGestureRecognizer {
  _StaticMouse(this.allow) : super(supportedDevices: const {PointerDeviceKind.mouse});

  final bool Function(Offset global) allow;

  @override
  bool isPointerAllowed(PointerEvent event) => allow(event.position) && super.isPointerAllowed(event);
}

class _StaticTap extends TapGestureRecognizer {
  _StaticTap(this.allow) : super(supportedDevices: _touchKinds);

  final bool Function(Offset global) allow;

  @override
  bool isPointerAllowed(PointerDownEvent event) => allow(event.position) && super.isPointerAllowed(event);
}

class _StaticMenu extends TapGestureRecognizer {
  _StaticMenu(this.allow) : super(supportedDevices: const {PointerDeviceKind.mouse});

  final bool Function(Offset global) allow;

  @override
  bool isPointerAllowed(PointerDownEvent event) => allow(event.position) && super.isPointerAllowed(event);
}

class _StaticLongPress extends LongPressGestureRecognizer {
  _StaticLongPress(this.allow) : super(supportedDevices: _touchKinds);

  final bool Function(Offset global) allow;

  @override
  bool isPointerAllowed(PointerDownEvent event) => allow(event.position) && super.isPointerAllowed(event);
}

/// Правило набора, которое видит окно в его блоке: сверху подставлена строка, открывающая
/// блок, снизу — закрывающая. Правило тронуло подставленное — правка проходит без него.
class _InContext extends TextInputFormatter {
  _InContext(this.inner, this.context);

  final TextInputFormatter inner;
  final (String, String) Function() context;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final (before, after) = context();
    if (before.isEmpty && after.isEmpty) return inner.formatEditUpdate(oldValue, newValue);
    TextEditingValue wrap(TextEditingValue value) =>
        TextEditingValue(text: '$before${value.text}$after', selection: _moved(value.selection, before.length), composing: _movedRange(value.composing, before.length));
    final result = inner.formatEditUpdate(wrap(oldValue), wrap(newValue));
    if (result.text.length < before.length + after.length || !result.text.startsWith(before) || !result.text.endsWith(after)) return newValue;
    final text = result.text.substring(before.length, result.text.length - after.length);
    final selection = result.selection;
    final composing = result.composing;
    return TextEditingValue(
      text: text,
      selection: selection.isValid
          ? selection.copyWith(baseOffset: (selection.baseOffset - before.length).clamp(0, text.length), extentOffset: (selection.extentOffset - before.length).clamp(0, text.length))
          : selection,
      composing: composing.isValid && composing.start >= before.length && composing.end <= before.length + text.length ? _movedRange(composing, -before.length) : TextRange.empty,
    );
  }
}
