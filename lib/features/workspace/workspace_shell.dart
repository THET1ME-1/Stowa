import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../domain/appearance.dart';
import '../../domain/return_plan.dart';
import '../../l10n/app_localizations.dart';
import '../folder/folder_screen.dart';
import '../graph/graph_screen.dart';
import '../item/item_screen.dart';
import '../map/map_screen.dart';
import '../returns/return_screen.dart';
import '../../core/widgets/desk_mode.dart';
import '../../core/widgets/undo_snack.dart';
import '../item/item_actions.dart';
import 'workspace_docks.dart';
import 'workspace_home.dart';
import 'workspace_keys.dart';
import 'workspace_model.dart';
import 'workspace_popups.dart';
import 'workspace_settings.dart';

/// От этой ширины окна — рабочее пространство, уже — телефонная главная.
/// Решает ширина, а не платформа: так же будет в сборках для Windows и Linux.
const workspaceFrom = 1000.0;

const _gap = 8.0;

/// Место общей строки внизу центра: капсула 60 и отступы вокруг.
const _lineSpace = 80.0;
const _blockRadius = 20.0;
const _prefsKey = 'workspace_layout';

/// Фон окна под блоками: темнее поверхности, блоки на нём читаются без линий.
Color get _page => Color.lerp(Tokens.background, const Color(0xFF000000), Tokens.palette.isDark ? 0.4 : 0.1)!;

/// Тон блока: дока и окна.
Color get _block => Tokens.palette.isDark ? Tokens.containerLow : Tokens.containerLowest;

/// Раскладка и действия над ней для всех виджетов пространства. Каждое изменение
/// перерисовывает пространство и сохраняется.
class WorkspaceController extends ChangeNotifier {
  WorkspaceController(this._prefs)
    : workspace = Workspace.fromJsonOrInitial(_prefs?.getString(_prefsKey)),
      keys = KeyMap.fromJson(_prefs?.getString(_keysKey));

  static const _keysKey = 'workspace_keys';

  final SharedPreferences? _prefs;
  final Workspace workspace;

  /// Сочетания клавиш: стандартные и свои.
  final KeyMap keys;
  Timer? _save;

  /// Закрытые вкладки, последняя сверху: Alt+Shift+T возвращает.
  final closed = <WsTab>[];

  /// Поменять сочетания; вернёт команду, у которой сочетание сняли.
  String? updateKeys(String? Function(KeyMap keys) change) {
    final taken = change(keys);
    notifyListeners();
    _prefs?.setString(_keysKey, keys.toJson()).ignore();
    return taken;
  }

  void closeTab(String paneId, int index) {
    update((ws) {
      closed.add(ws.pane(paneId).tabs[index]);
      if (closed.length > 20) closed.removeAt(0);
      ws.close(paneId, index);
    });
    // вкладку могли закрыть вместе с открытым листом: после кадра сверяем, что осталось
    WidgetsBinding.instance.addPostFrameCallback((_) => popups.settle());
  }

  void reopen() {
    if (closed.isNotEmpty) open(closed.removeLast());
  }

  /// Общая строка ввода под всеми окнами.
  Widget? composer;

  /// Нижние листы и диалоги, открытые во вкладках: пока есть хоть один, общая строка уходит.
  final popups = WorkspacePopups();

  /// Курсор в общую строку: Ctrl K, «Найти или записать», поиск на экране папки.
  VoidCallback? find;

  /// Куда ещё отдать сохранённое общей строкой. Ставит экран, который на виду в окне с
  /// фокусом (холст-файл кладёт новые заметки карточками); null — просто сохранить.
  CaptureTarget? captureTarget;

  /// Вкладка [tab] из окна [paneId] — та, что сейчас перед глазами: окно с фокусом,
  /// вкладка в нём открыта.
  bool isFront(String paneId, WsTab tab) => workspace.focusedId == paneId && workspace.focusedPane.activeTab == tab;

  void update(void Function(Workspace workspace) change) {
    change(workspace);
    notifyListeners();
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 400), () => _prefs?.setString(_prefsKey, jsonText()).ignore());
  }

  String jsonText() => jsonEncode(workspace.toJson());

  void open(WsTab tab) => update((ws) => ws.open(tab));

  @override
  void dispose() {
    _save?.cancel();
    super.dispose();
  }
}

/// Приём сохранённого общей строкой: [owner] — кто поставил (снимает только он),
/// [onSaved] получает id новых заметок.
class CaptureTarget {
  const CaptureTarget({required this.owner, required this.onSaved});

  final Object owner;
  final void Function(List<String> ids) onSaved;
}

/// Вкладка и её окно — экрану внутри вкладки: на виду ли он сейчас.
class WsTabScope extends InheritedWidget {
  const WsTabScope({super.key, required this.paneId, required this.tab, required super.child});

  final String paneId;
  final WsTab tab;

  static WsTabScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<WsTabScope>();

  @override
  bool updateShouldNotify(WsTabScope old) => old.paneId != paneId || old.tab != tab;
}

class WorkspaceScope extends InheritedNotifier<WorkspaceController> {
  const WorkspaceScope({super.key, required WorkspaceController controller, required super.child}) : super(notifier: controller);

  static WorkspaceController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<WorkspaceScope>()!.notifier!;

  static WorkspaceController? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<WorkspaceScope>()?.notifier;
}

/// Рабочее пространство широкого экрана: полоса раскладок сверху, левый док, окна
/// с вкладками, правый док; строка ввода — внизу центра, как на телефоне.
class WorkspaceShell extends ConsumerStatefulWidget {
  const WorkspaceShell({super.key, required this.composer, required this.onFind});

  /// Строка ввода главной; [open] — открыть найденную заметку вкладкой.
  final Widget Function(ValueChanged<String> open) composer;

  /// «Найти или записать»: фокус в строку.
  final VoidCallback onFind;

  @override
  ConsumerState<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends ConsumerState<WorkspaceShell> {
  late final WorkspaceController _controller = WorkspaceController(_prefs());

  // у каждой вкладки свой навигатор: переходы внутри неё живут, пока она открыта
  final _navigators = <String, GlobalKey<NavigatorState>>{};

  SharedPreferences? _prefs() {
    try {
      return ref.read(preferencesProvider);
    } on Object {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _sequenceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  GlobalKey<NavigatorState> _navigatorFor(WsTab tab) => _navigators.putIfAbsent(tab.key, () => GlobalKey<NavigatorState>(debugLabel: tab.key));

  // ——— сочетания клавиш ———

  // первая клавиша двойного сочетания («G», затем «H»)
  String? _sequence;
  Timer? _sequenceTimer;

  /// Курсор в поле ввода: одиночные клавиши — это набор текста, а не команды.
  static bool get _typing => FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() != null;

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    // поверх пространства открыт лист, меню или палитра — клавиши им
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final keyboard = HardwareKeyboard.instance;
    final chord = chordOf(event.physicalKey, ctrl: keyboard.isControlPressed || keyboard.isMetaPressed, alt: keyboard.isAltPressed, shift: keyboard.isShiftPressed);
    if (chord == null) return false;
    if (keyCapture case final capture?) {
      capture(chord);
      return true;
    }
    if (needsFreeFocus(chord) && _typing) return false;
    final keys = _controller.keys;
    if (_sequence case final first?) {
      _sequence = null;
      _sequenceTimer?.cancel();
      if (keys.commandFor('$first $chord') case final id?) {
        _run(id);
        return true;
      }
    }
    if (needsFreeFocus(chord) && keys.startsSequence(chord)) {
      _sequence = chord;
      _sequenceTimer?.cancel();
      _sequenceTimer = Timer(const Duration(milliseconds: 1200), () => _sequence = null);
      return true;
    }
    final id = keys.commandFor(chord);
    if (id == null) return false;
    // команды заметки без открытой заметки клавишу не забирают: Delete на холсте — его
    if (const {'trash', 'pin', 'move'}.contains(id) && _noteId == null) return false;
    _run(id);
    return true;
  }

  /// Заметка в открытой вкладке окна с фокусом: для «Удалить», «Закрепить», «Переложить».
  String? get _noteId {
    final tab = _controller.workspace.focusedPane.activeTab;
    return tab?.kind == 'item' ? tab!.id : null;
  }

  void _say(String message) => showNote(ScaffoldMessenger.of(context), message);

  void _run(String id) {
    final l = L.of(context);
    final ws = _controller.workspace;
    final pane = ws.focusedPane;
    final panes = ws.panes;
    switch (id) {
      case 'find' || 'new':
        _find();
      case 'palette' || 'switch':
        final items = [...?ref.read(pinnedItemsProvider).value, ...?ref.read(recentItemsProvider).value];
        showPalette(
          context,
          keys: _controller.keys,
          notes: id == 'switch',
          items: [for (final card in {for (final card in items) card.id: card}.values) (id: card.id, title: card.title)],
          onCommand: _run,
          onItem: (itemId) => _controller.open(WsTab.item(itemId)),
        ).ignore();
      case 'home':
        _controller.open(const WsTab.home());
      case 'keys':
        _controller.open(const WsTab.settings('keys'));
      case 'settings':
        _controller.open(const WsTab.settings());
      case 'trash' || 'pin' || 'move':
        final noteId = _noteId;
        if (noteId == null) return _say(l.wsOpenNoteFirst);
        final item = ref.read(itemProvider(noteId)).value?.item;
        if (item == null) return;
        if (id == 'trash') {
          final items = ref.read(itemsRepositoryProvider);
          items.softDelete(noteId, ref.read(clockProvider)()).ignore();
          _controller.closeTab(pane.id, pane.active);
          showUndo(ScaffoldMessenger.of(context), message: l.itemDeleted, label: l.undo, onUndo: () => items.restore(noteId));
        } else if (id == 'pin') {
          togglePinned(context, ref, id: noteId, pinned: item.pinnedAt != null).ignore();
        } else {
          moveItemById(context, ref, id: noteId, from: item.folderId).ignore();
        }
      case 'close':
        _controller.closeTab(pane.id, pane.active);
      case 'reopen':
        _controller.reopen();
      case 'next' || 'prev':
        if (pane.tabs.length > 1) {
          final step = id == 'next' ? 1 : -1;
          _controller.update((ws) => ws.activate(pane.id, (pane.active + step) % pane.tabs.length));
        }
      case 'splitRight' || 'splitDown':
        _controller.update((ws) => ws.split(pane.id, id == 'splitRight' ? WsAxis.row : WsAxis.column));
      case 'nextPane' || 'prevPane':
        if (panes.length > 1) {
          final at = panes.indexWhere((one) => one.id == pane.id);
          final step = id == 'nextPane' ? 1 : -1;
          _controller.update((ws) => ws.focus(panes[(at + step) % panes.length].id));
        }
      case 'closePane':
        if (panes.length > 1) {
          _controller.update((ws) {
            while (ws.panes.any((one) => one.id == pane.id)) {
              ws.close(pane.id, 0);
            }
          });
        }
      case 'left':
        _controller.update((ws) => ws.leftOpen = !ws.leftOpen);
      case 'right':
        _controller.update((ws) => ws.rightOpen = !ws.rightOpen);
      case 'theme':
        _toggleTheme();
    }
  }

  void _toggleTheme() {
    final settings = ref.read(settingsRepositoryProvider);
    final appearance = ref.read(appearanceProvider).value ?? const Appearance();
    settings.setAppearance(appearance.copyWith(choice: Tokens.palette.isDark ? ThemeChoice.light : ThemeChoice.dark)).ignore();
  }

  /// «Найти или записать»: строка живёт на главной — сперва главная, потом фокус.
  /// Курсор в общую строку; открытые вкладки остаются как были.
  void _find() => widget.onFind();

  @override
  Widget build(BuildContext context) {
    _controller.composer = widget.composer((id) => _controller.open(WsTab.item(id)));
    _controller.find = _find;
    // под оболочкой — монитор: шторки открываются окнами, плашки — пилюлей над строкой
    return WorkspaceScope(
      controller: _controller,
      child: DeskMode(
        child: Builder(
          builder: (context) {
          final ws = WorkspaceScope.of(context).workspace;
          // вкладки, которых больше нет, отпускают свои навигаторы
          final open = {for (final pane in ws.panes) ...pane.tabs.map((tab) => tab.key)};
          _navigators.removeWhere((key, _) => !open.contains(key));
          return ColoredBox(
            color: _page,
            child: SafeArea(
              child: Column(
                children: [
                  _TopBar(controller: _controller),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(_gap, 0, _gap, _gap),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SideDock(
                            open: ws.leftOpen,
                            width: ws.leftWidth,
                            left: true,
                            onResize: (width) => _controller.update((ws) => ws.leftWidth = width.clamp(220, 420)),
                            child: LeftDock(onFind: _find, onTheme: _toggleTheme),
                          ),
                          // окна и одна общая строка под ними: она ищет по всему хранилищу
                          // и записывает новое, сколько бы окон ни было открыто
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(child: _NodeView(node: ws.root, navigatorFor: _navigatorFor, atBottom: true)),
                                // окно вкладки (нижний лист, диалог) открывается под строкой: пока оно
                                // на экране, строка плавно уходит и не перекрывает его кнопки
                                if (_controller.composer case final composer?)
                                  Positioned.fill(
                                    child: ValueListenableBuilder<bool>(
                                      valueListenable: _controller.popups.covering,
                                      builder: (context, covered, line) => IgnorePointer(
                                        ignoring: covered,
                                        child: AnimatedOpacity(opacity: covered ? 0 : 1, duration: Motion.medium, curve: Motion.emphasized, child: line),
                                      ),
                                      child: composer,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _SideDock(
                            open: ws.rightOpen,
                            width: ws.rightWidth,
                            left: false,
                            onResize: (width) => _controller.update((ws) => ws.rightWidth = width.clamp(240, 460)),
                            child: const RightDock(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          },
        ),
      ),
    );
  }
}

/// Верхняя полоса: показать и спрятать доки, сочетания клавиш. Раскладку окон человек
/// собирает сам, перетаскивая вкладки.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ws = controller.workspace;
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _gap),
        child: Row(
          children: [
            _BarIcon(icon: 'left_panel_open', tooltip: l.wsLeftDock, on: ws.leftOpen, onTap: () => controller.update((ws) => ws.leftOpen = !ws.leftOpen)),
            const Spacer(),
            _BarIcon(icon: 'keyboard', tooltip: l.wsKeys, onTap: () => controller.open(const WsTab.settings('keys'))),
            const SizedBox(width: 4),
            _BarIcon(icon: 'right_panel_open', tooltip: l.wsRightDock, on: ws.rightOpen, onTap: () => controller.update((ws) => ws.rightOpen = !ws.rightOpen)),
          ],
        ),
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({required this.icon, required this.tooltip, required this.onTap, this.on = false});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.emphasized,
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: on ? Tokens.containerHigh : Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: Icon(symbolIcon(icon), size: 20, color: on ? Tokens.onSurface : Tokens.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// Док сбоку: выезжает и уезжает шириной и прозрачностью, содержимое не переверстывается
/// на ходу. Зазор между доком и центром тянет его ширину.
class _SideDock extends StatelessWidget {
  const _SideDock({required this.open, required this.width, required this.left, required this.onResize, required this.child});

  final bool open;
  final double width;
  final bool left;
  final ValueChanged<double> onResize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final block = ClipRect(
      child: OverflowBox(
        alignment: left ? Alignment.centerLeft : Alignment.centerRight,
        minWidth: width,
        maxWidth: width,
        child: AnimatedOpacity(
          duration: Motion.medium,
          curve: Motion.emphasized,
          opacity: open ? 1 : 0,
          child: DecoratedBox(
            decoration: BoxDecoration(color: _block, borderRadius: BorderRadius.circular(_blockRadius)),
            child: ClipRRect(borderRadius: BorderRadius.circular(_blockRadius), child: child),
          ),
        ),
      ),
    );
    final gutter = _Gutter(
      axis: Axis.horizontal,
      enabled: open,
      onDrag: (delta) => onResize(width + (left ? delta : -delta)),
    );
    return AnimatedContainer(
      duration: Motion.long,
      curve: Motion.emphasized,
      width: open ? width + _gap : 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: left ? [Expanded(child: block), gutter] : [gutter, Expanded(child: block)],
      ),
    );
  }
}

/// Зазор между блоками: за него тянут границу.
class _Gutter extends StatelessWidget {
  const _Gutter({required this.axis, required this.onDrag, this.enabled = true});

  final Axis axis;
  final ValueChanged<double> onDrag;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    return MouseRegion(
      cursor: !enabled ? MouseCursor.defer : (horizontal ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: enabled && horizontal ? (details) => onDrag(details.delta.dx) : null,
        onVerticalDragUpdate: enabled && !horizontal ? (details) => onDrag(details.delta.dy) : null,
        child: SizedBox(width: horizontal ? _gap : null, height: horizontal ? null : _gap),
      ),
    );
  }
}

/// Дерево окон центра: окно или деление с долями.
class _NodeView extends StatelessWidget {
  const _NodeView({required this.node, required this.navigatorFor, required this.atBottom});

  final WsNode node;
  final GlobalKey<NavigatorState> Function(WsTab tab) navigatorFor;

  /// Нижний край у низа центра: там общая строка, окно оставляет под неё место.
  final bool atBottom;

  @override
  Widget build(BuildContext context) {
    final node = this.node;
    return switch (node) {
      WsLeaf(:final paneId) => _PaneView(key: ValueKey('pane-$paneId'), paneId: paneId, navigatorFor: navigatorFor, atBottom: atBottom),
      WsSplit() => _SplitView(split: node, navigatorFor: navigatorFor, atBottom: atBottom),
    };
  }
}

class _SplitView extends StatelessWidget {
  const _SplitView({required this.split, required this.navigatorFor, required this.atBottom});

  final WsSplit split;
  final GlobalKey<NavigatorState> Function(WsTab tab) navigatorFor;
  final bool atBottom;

  @override
  Widget build(BuildContext context) {
    final controller = WorkspaceScope.of(context);
    final row = split.axis == WsAxis.row;
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = (row ? constraints.maxWidth : constraints.maxHeight) - _gap * (split.children.length - 1);
        final children = <Widget>[];
        for (var i = 0; i < split.children.length; i++) {
          if (i > 0) {
            final index = i - 1;
            children.add(
              _Gutter(
                axis: row ? Axis.horizontal : Axis.vertical,
                onDrag: (delta) {
                  final pair = split.ratios[index] + split.ratios[index + 1];
                  final share = (split.ratios[index] * total + delta) / (pair * total);
                  controller.update((ws) => ws.resize(split, index, share));
                },
              ),
            );
          }
          children.add(
            Flexible(
              flex: (split.ratios[i] * 1000).round(),
              // в ряду низа касаются все, в столбце — только нижнее окно
              child: _NodeView(node: split.children[i], navigatorFor: navigatorFor, atBottom: atBottom && (row || i == split.children.length - 1)),
            ),
          );
        }
        return Flex(direction: row ? Axis.horizontal : Axis.vertical, crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
      },
    );
  }
}

/// Окно: вкладки на фоне, открытая сливается с блоком; содержимое всех вкладок живёт,
/// видна одна — смена вкладки затуханием.
class _PaneView extends StatelessWidget {
  const _PaneView({super.key, required this.paneId, required this.navigatorFor, required this.atBottom});

  final String paneId;
  final GlobalKey<NavigatorState> Function(WsTab tab) navigatorFor;
  final bool atBottom;

  @override
  Widget build(BuildContext context) {
    final controller = WorkspaceScope.of(context);
    final ws = controller.workspace;
    final pane = ws.pane(paneId);
    final active = pane.activeTab;
    return Listener(
      onPointerDown: (_) {
        if (ws.focusedId != paneId) controller.update((ws) => ws.focus(paneId));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TabStrip(paneId: paneId),
          Expanded(
            // открыта первая вкладка — она стоит над левым краем блока, и угол там прямой:
            // вкладка перетекает в блок без ступеньки
            child: AnimatedContainer(
              duration: Motion.medium,
              curve: Motion.emphasized,
              decoration: BoxDecoration(color: _block, borderRadius: _blockCorners(firstActive: pane.active == 0)),
              child: ClipRRect(
                borderRadius: _blockCorners(firstActive: pane.active == 0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // экраны внутри меряют себя по окну, а не по всему экрану; у нижних окон
                    // низ занят общей строкой — как вырез экрана телефона, его обходят сами
                    final under = EdgeInsets.only(bottom: atBottom ? _lineSpace : 0);
                    final media = MediaQuery.of(context).copyWith(
                      size: constraints.biggest,
                      padding: under,
                      viewPadding: under,
                      viewInsets: EdgeInsets.zero,
                    );
                    return MediaQuery(
                      data: media,
                      child: Theme(
                        data: Theme.of(context).copyWith(scaffoldBackgroundColor: _block),
                        child: _PaneDrop(
                          paneId: paneId,
                          child: Stack(
                            children: [
                              for (final tab in pane.tabs)
                                _TabLayer(
                                  key: ValueKey('tab-${tab.key}'),
                                  visible: tab == active,
                                  child: WsTabScope(paneId: paneId, tab: tab, child: _TabBody(tab: tab, navigatorKey: navigatorFor(tab))),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BorderRadius _blockCorners({required bool firstActive}) => BorderRadius.only(
  topLeft: Radius.circular(firstActive ? 0 : _blockRadius),
  topRight: const Radius.circular(_blockRadius),
  bottomLeft: const Radius.circular(_blockRadius),
  bottomRight: const Radius.circular(_blockRadius),
);

/// Вогнутый угол у основания открытой вкладки: квадрат цвета блока, из которого вынут
/// круг цвета фона, — вкладка расходится в блок плавной дугой, как в Chrome.
class _Flare extends StatelessWidget {
  const _Flare({required this.left});

  /// Дуга слева от вкладки (иначе справа).
  final bool left;

  static const size = 12.0;

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size.square(size), painter: _FlarePainter(left: left, block: _block, page: _page));
}

class _FlarePainter extends CustomPainter {
  _FlarePainter({required this.left, required this.block, required this.page});

  final bool left;
  final Color block;
  final Color page;

  @override
  void paint(Canvas canvas, Size size) {
    final corner = Path()..addRect(Offset.zero & size);
    final hole = Path()..addOval(Rect.fromCircle(center: Offset(left ? 0 : size.width, 0), radius: size.width));
    canvas.drawPath(Path.combine(PathOperation.difference, corner, hole), Paint()..color = block);
  }

  @override
  bool shouldRepaint(_FlarePainter old) => old.left != left || old.block != block || old.page != page;
}

/// Слой вкладки: скрытая не рисует анимаций и не ловит нажатий, смена — затуханием.
class _TabLayer extends StatelessWidget {
  const _TabLayer({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // затухание стоит над TickerMode: под выключенными часами оно застывало, и ушедшая
    // вкладка, лежащая в стопке выше, оставалась видна поверх открытой
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          duration: Motion.medium,
          curve: Motion.emphasized,
          opacity: visible ? 1 : 0,
          child: TickerMode(
            enabled: visible,
            child: ExcludeFocus(excluding: !visible, child: child),
          ),
        ),
      ),
    );
  }
}

/// Что внутри вкладки: свой навигатор с экраном приложения.
class _TabBody extends ConsumerWidget {
  const _TabBody({required this.tab, required this.navigatorKey});

  final WsTab tab;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = WorkspaceScope.of(context);
    return HeroControllerScope.none(
      child: Navigator(
        key: navigatorKey,
        observers: [controller.popups.watch()],
        onGenerateInitialRoutes: (navigator, initial) => [
          // первый экран вкладки не въезжает: начальные маршруты навигатор показывает без перехода
          MaterialPageRoute<void>(builder: (context) => _screen(context, controller)),
        ],
      ),
    );
  }

  Widget _screen(BuildContext context, WorkspaceController controller) => switch (tab.kind) {
    'home' => const _HomeTab(),
    'inbox' => const FolderScreen(folderId: null),
    'folder' => FolderScreen(folderId: tab.id),
    'item' => ItemScreen(id: tab.id!),
    'settings' => const _SettingsTab(),
    'map' => const MapScreen(),
    'graph' => GraphScreen(title: L.of(context).graphTitle),
    'later' => const ReturnScreen(kind: ReturnKind.watchLater),
    _ => const SizedBox.shrink(),
  };
}

/// Настройки. Страница навигатора строится один раз, а раздел меняется: он берётся
/// из раскладки при каждой перерисовке.
class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    final ws = WorkspaceScope.of(context).workspace;
    final tab = [for (final pane in ws.panes) ...pane.tabs].where((tab) => tab.kind == 'settings').firstOrNull;
    return Scaffold(body: WorkspaceSettings(section: tab?.id));
  }
}

/// Главная: плитка заметок. Строка ввода — общая, под всеми окнами.
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final controller = WorkspaceScope.of(context);
    return Scaffold(
      body: WorkspaceHome(
        bottomSpace: MediaQuery.paddingOf(context).bottom + 24,
        onOpen: (id) => controller.open(WsTab.item(id)),
        onFolder: (id) => controller.open(id == null ? const WsTab.inbox() : WsTab.folder(id)),
      ),
    );
  }
}

/// Что тащат: вкладку номер [index] окна [paneId].
class _TabDrag {
  const _TabDrag(this.paneId, this.index, this.tab);

  final String paneId;
  final int index;
  final WsTab tab;
}

/// Вкладка под курсором, пока её тащат.
class _TabGhost extends ConsumerWidget {
  const _TabGhost({required this.tab});

  final WsTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final (icon, label, color) = _TabChip.lookOf(L.of(context), ref, tab);
    return Material(
      color: Tokens.containerHigh,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(symbolIcon(icon, filled: color != null), size: 18, color: color ?? Tokens.onSurface),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelLarge!.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Окно как цель перетаскивания вкладки: края — новое окно в ту сторону, середина —
/// вкладка переезжает сюда. Подсвечивается место, куда встанет.
class _PaneDrop extends StatefulWidget {
  const _PaneDrop({required this.paneId, required this.child});

  final String paneId;
  final Widget child;

  @override
  State<_PaneDrop> createState() => _PaneDropState();
}

class _PaneDropState extends State<_PaneDrop> {
  WsDrop? _zone;

  WsDrop _zoneAt(Offset global) {
    final box = context.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(global);
    final x = local.dx / box.size.width;
    final y = local.dy / box.size.height;
    // ближний край в пределах четверти окна
    final edges = {WsDrop.left: x, WsDrop.right: 1 - x, WsDrop.top: y, WsDrop.bottom: 1 - y};
    final nearest = edges.entries.reduce((a, b) => a.value <= b.value ? a : b);
    return nearest.value < 0.25 ? nearest.key : WsDrop.center;
  }

  @override
  Widget build(BuildContext context) {
    final controller = WorkspaceScope.of(context);
    return DragTarget<_TabDrag>(
      onMove: (details) {
        final zone = _zoneAt(details.offset);
        if (zone != _zone) setState(() => _zone = zone);
      },
      onLeave: (_) => setState(() => _zone = null),
      onAcceptWithDetails: (details) {
        final zone = _zone ?? WsDrop.center;
        setState(() => _zone = null);
        controller.update((ws) => ws.drop(details.data.paneId, details.data.index, widget.paneId, zone));
      },
      builder: (context, _, _) => LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final zone = _zone;
          final rect = switch (zone) {
            WsDrop.left => Rect.fromLTWH(0, 0, w / 2, h),
            WsDrop.right => Rect.fromLTWH(w / 2, 0, w / 2, h),
            WsDrop.top => Rect.fromLTWH(0, 0, w, h / 2),
            WsDrop.bottom => Rect.fromLTWH(0, h / 2, w, h / 2),
            _ => Rect.fromLTWH(0, 0, w, h),
          };
          return Stack(
            children: [
              Positioned.fill(child: widget.child),
              // будущее окно: мягкая подложка цвета акцента, переезжает за курсором
              AnimatedPositioned.fromRect(
                duration: Motion.medium,
                curve: Motion.emphasized,
                rect: rect.deflate(6),
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: Motion.medium,
                    curve: Motion.emphasized,
                    opacity: zone == null ? 0 : 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Tokens.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(_blockRadius - 4)),
                    ),
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

/// Вкладки окна и кнопки деления.
class _TabStrip extends ConsumerWidget {
  const _TabStrip({required this.paneId});

  final String paneId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final controller = WorkspaceScope.of(context);
    final pane = controller.workspace.pane(paneId);
    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            // пустое место полосы: вкладка встаёт последней
            child: DragTarget<_TabDrag>(
              onAcceptWithDetails: (details) => controller.update((ws) => ws.drop(details.data.paneId, details.data.index, paneId, WsDrop.center, at: pane.tabs.length)),
              builder: (context, _, _) => ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (index, tab) in pane.tabs.indexed)
                    // вкладку тянут мышью: по полосе — порядок, на окно — переезд или новое окно
                    DragTarget<_TabDrag>(
                      key: ValueKey('chip-${tab.key}'),
                      onWillAcceptWithDetails: (details) => details.data.tab != tab,
                      onAcceptWithDetails: (details) => controller.update((ws) => ws.drop(details.data.paneId, details.data.index, paneId, WsDrop.center, at: index)),
                      builder: (context, candidates, _) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // куда встанет: полоска перед вкладкой
                          AnimatedContainer(
                            duration: Motion.short,
                            curve: Motion.emphasized,
                            width: candidates.isEmpty ? 0 : 3,
                            height: 24,
                            margin: EdgeInsets.only(right: candidates.isEmpty ? 0 : 4, bottom: 8),
                            decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(2)),
                          ),
                          Draggable<_TabDrag>(
                            data: _TabDrag(paneId, index, tab),
                            dragAnchorStrategy: pointerDragAnchorStrategy,
                            feedback: _TabGhost(tab: tab),
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: _TabChip(tab: tab, active: index == pane.active, first: index == 0, onTap: () {}, onClose: () {}),
                            ),
                            child: _TabChip(
                              tab: tab,
                              active: index == pane.active,
                              first: index == 0,
                              onTap: () => controller.update((ws) => ws.activate(paneId, index)),
                              onClose: () => controller.closeTab(paneId, index),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4),
            child: Row(
              children: [
                _BarIcon(icon: 'splitscreen_right', tooltip: l.wsSplitRight, onTap: () => controller.update((ws) => ws.split(paneId, WsAxis.row))),
                _BarIcon(icon: 'splitscreen_bottom', tooltip: l.wsSplitDown, onTap: () => controller.update((ws) => ws.split(paneId, WsAxis.column))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends ConsumerWidget {
  const _TabChip({required this.tab, required this.active, required this.first, required this.onTap, required this.onClose});

  final WsTab tab;
  final bool active;

  /// Первая вкладка стоит над левым краем блока: дуги слева у неё нет, угол блока прямой.
  final bool first;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final (icon, label, color) = lookOf(l, ref, tab);
    return GestureDetector(
      onTap: onTap,
      // средняя кнопка мыши закрывает вкладку, как в браузере
      onTertiaryTapUp: (_) => onClose(),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        // у открытой вкладки по бокам место под вогнутые дуги
        child: AnimatedPadding(
          duration: Motion.medium,
          curve: Motion.emphasized,
          padding: EdgeInsets.only(left: active && !first ? _Flare.size : 0, right: active ? _Flare.size + 2 : 4),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _chip(context, l, icon, label, color),
              if (!first) Positioned(left: -_Flare.size, bottom: 0, child: _fade(const _Flare(left: true))),
              Positioned(right: -_Flare.size, bottom: 0, child: _fade(const _Flare(left: false))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fade(Widget child) => AnimatedOpacity(duration: Motion.medium, curve: Motion.emphasized, opacity: active ? 1 : 0, child: child);

  Widget _chip(BuildContext context, L l, String icon, String label, Color? color) {
    final text = Theme.of(context).textTheme;
    return AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.emphasized,
          constraints: const BoxConstraints(maxWidth: 240),
          height: active ? 44 : 36,
          margin: EdgeInsets.only(bottom: active ? 0 : 4),
          padding: const EdgeInsets.only(left: 12, right: 6),
          decoration: BoxDecoration(
            color: active ? _block : Colors.transparent,
            borderRadius: active ? const BorderRadius.vertical(top: Radius.circular(14)) : BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(symbolIcon(icon, filled: color != null), size: 18, color: color ?? (active ? Tokens.onSurface : Tokens.onSurfaceVariant)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge!.copyWith(color: active ? Tokens.onSurface : Tokens.onSurfaceVariant, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: l.wsCloseTab,
                child: InkResponse(
                  onTap: onClose,
                  radius: 14,
                  child: Padding(padding: const EdgeInsets.all(3), child: Icon(symbolIcon('close'), size: 16, color: Tokens.muted)),
                ),
              ),
            ],
          ),
        );
  }

  /// Значок, подпись и цвет значка вкладки (у папки — её цвет).
  static (String, String, Color?) lookOf(L l, WidgetRef ref, WsTab tab) {
    switch (tab.kind) {
      case 'home':
        return ('home', l.wsHome, null);
      case 'inbox':
        return ('inbox', l.folderNone, null);
      case 'folder':
        final folders = ref.watch(foldersProvider).value ?? const [];
        final folder = folders.where((folder) => folder.id == tab.id).firstOrNull;
        return (folder?.icon ?? 'folder', folder?.name ?? '', folder == null ? null : FolderPalette.ink(folder.color));
      case 'item':
        final item = ref.watch(itemProvider(tab.id!)).value?.item;
        return ('description', item?.title ?? '', null);
      case 'settings':
        return ('settings', l.settingsTitle, null);
      case 'map':
        return ('map', l.mapTitle, null);
      case 'graph':
        return ('hub', l.graphTitle, null);
      case 'later':
        return ('schedule', l.returnWatchTitle, null);
    }
    return ('tab', tab.kind, null);
  }
}
