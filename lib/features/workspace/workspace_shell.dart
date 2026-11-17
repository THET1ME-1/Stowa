import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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
import '../settings/settings_screen.dart';
import 'workspace_docks.dart';
import 'workspace_home.dart';
import 'workspace_model.dart';

/// От этой ширины окна — рабочее пространство, уже — телефонная главная.
/// Решает ширина, а не платформа: так же будет в сборках для Windows и Linux.
const workspaceFrom = 1000.0;

const _gap = 8.0;
const _blockRadius = 20.0;
const _prefsKey = 'workspace_layout';

/// Фон окна под блоками: темнее поверхности, блоки на нём читаются без линий.
Color get _page => Color.lerp(Tokens.background, const Color(0xFF000000), Tokens.palette.isDark ? 0.4 : 0.1)!;

/// Тон блока: дока и окна.
Color get _block => Tokens.palette.isDark ? Tokens.containerLow : Tokens.containerLowest;

/// Раскладка и действия над ней для всех виджетов пространства. Каждое изменение
/// перерисовывает пространство и сохраняется.
class WorkspaceController extends ChangeNotifier {
  WorkspaceController(this._prefs) : workspace = Workspace.fromJsonOrInitial(_prefs?.getString(_prefsKey));

  final SharedPreferences? _prefs;
  final Workspace workspace;
  Timer? _save;

  /// Строка ввода главной: живёт во вкладке «Главная», у папок и заметок строки свои.
  Widget? composer;

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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  GlobalKey<NavigatorState> _navigatorFor(WsTab tab) => _navigators.putIfAbsent(tab.key, () => GlobalKey<NavigatorState>(debugLabel: tab.key));

  void _toggleTheme() {
    final settings = ref.read(settingsRepositoryProvider);
    final appearance = ref.read(appearanceProvider).value ?? const Appearance();
    settings.setAppearance(appearance.copyWith(choice: Tokens.palette.isDark ? ThemeChoice.light : ThemeChoice.dark)).ignore();
  }

  /// «Найти или записать»: строка живёт на главной — сперва главная, потом фокус.
  void _find() {
    _controller.open(const WsTab.home());
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFind());
  }

  @override
  Widget build(BuildContext context) {
    _controller.composer = widget.composer((id) => _controller.open(WsTab.item(id)));
    return WorkspaceScope(
      controller: _controller,
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
                          Expanded(child: _NodeView(node: ws.root, navigatorFor: _navigatorFor)),
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
    );
  }
}

/// Верхняя полоса: доки слева и справа, раскладки по центру.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ws = controller.workspace;
    final labels = {'normal': l.wsPresetNormal, 'reading': l.wsPresetReading, 'two': l.wsPresetTwo, 'three': l.wsPresetThree};
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _gap),
        child: Row(
          children: [
            _BarIcon(icon: 'left_panel_open', tooltip: l.wsLeftDock, on: ws.leftOpen, onTap: () => controller.update((ws) => ws.leftOpen = !ws.leftOpen)),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(100)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final preset in WsPreset.all)
                        _PresetButton(icon: preset.icon, label: labels[preset.name]!, on: ws.preset == preset.name, onTap: () => controller.update((ws) => ws.arrange(preset))),
                    ],
                  ),
                ),
              ),
            ),
            _BarIcon(icon: 'keyboard', tooltip: l.wsKeys, onTap: () => controller.open(const WsTab.settings('keys'))),
            const SizedBox(width: 4),
            _BarIcon(icon: 'right_panel_open', tooltip: l.wsRightDock, on: ws.rightOpen, onTap: () => controller.update((ws) => ws.rightOpen = !ws.rightOpen)),
          ],
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({required this.icon, required this.label, required this.on, required this.onTap});

  final String icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = on ? Tokens.onAccent : Tokens.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.emphasized,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: on ? Tokens.accent : Colors.transparent, borderRadius: BorderRadius.circular(100)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(symbolIcon(icon), size: 17, color: color),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: Motion.medium,
                curve: Motion.emphasized,
                style: text.labelLarge!.copyWith(color: color, fontWeight: on ? FontWeight.w700 : FontWeight.w500),
                child: Text(label),
              ),
            ],
          ),
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
  const _NodeView({required this.node, required this.navigatorFor});

  final WsNode node;
  final GlobalKey<NavigatorState> Function(WsTab tab) navigatorFor;

  @override
  Widget build(BuildContext context) {
    final node = this.node;
    return switch (node) {
      WsLeaf(:final paneId) => _PaneView(key: ValueKey('pane-$paneId'), paneId: paneId, navigatorFor: navigatorFor),
      WsSplit() => _SplitView(split: node, navigatorFor: navigatorFor),
    };
  }
}

class _SplitView extends StatelessWidget {
  const _SplitView({required this.split, required this.navigatorFor});

  final WsSplit split;
  final GlobalKey<NavigatorState> Function(WsTab tab) navigatorFor;

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
              child: _NodeView(node: split.children[i], navigatorFor: navigatorFor),
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
  const _PaneView({super.key, required this.paneId, required this.navigatorFor});

  final String paneId;
  final GlobalKey<NavigatorState> Function(WsTab tab) navigatorFor;

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
                    // экраны внутри меряют себя по окну, а не по всему экрану
                    final media = MediaQuery.of(context).copyWith(
                      size: constraints.biggest,
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                      viewInsets: EdgeInsets.zero,
                    );
                    return MediaQuery(
                      data: media,
                      child: Theme(
                        data: Theme.of(context).copyWith(scaffoldBackgroundColor: _block),
                        child: Stack(
                          children: [
                            for (final tab in pane.tabs)
                              _TabLayer(
                                key: ValueKey('tab-${tab.key}'),
                                visible: tab == active,
                                child: _TabBody(tab: tab, navigatorKey: navigatorFor(tab)),
                              ),
                          ],
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
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: TickerMode(
          enabled: visible,
          child: AnimatedOpacity(
            duration: Motion.medium,
            curve: Motion.emphasized,
            opacity: visible ? 1 : 0,
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
        onGenerateInitialRoutes: (navigator, initial) => [
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            pageBuilder: (context, _, _) => _screen(context, controller),
          ),
        ],
      ),
    );
  }

  Widget _screen(BuildContext context, WorkspaceController controller) => switch (tab.kind) {
    'home' => const _HomeTab(),
    'inbox' => const FolderScreen(folderId: null),
    'folder' => FolderScreen(folderId: tab.id),
    'item' => ItemScreen(id: tab.id!),
    'settings' => const SettingsScreen(),
    'map' => const MapScreen(),
    'graph' => GraphScreen(title: L.of(context).graphTitle),
    'later' => const ReturnScreen(kind: ReturnKind.watchLater),
    _ => const SizedBox.shrink(),
  };
}

/// Главная: плитка и строка ввода над ней колонкой по центру.
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final controller = WorkspaceScope.of(context);
    return Scaffold(
      body: Stack(
        children: [
          WorkspaceHome(
            onOpen: (id) => controller.open(WsTab.item(id)),
            onFolder: (id) => controller.open(id == null ? const WsTab.inbox() : WsTab.folder(id)),
          ),
          if (controller.composer case final composer?) Positioned.fill(child: composer),
        ],
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
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (index, tab) in pane.tabs.indexed)
                  _TabChip(
                    key: ValueKey('chip-${tab.key}'),
                    tab: tab,
                    active: index == pane.active,
                    first: index == 0,
                    onTap: () => controller.update((ws) => ws.activate(paneId, index)),
                    onClose: () => controller.update((ws) => ws.close(paneId, index)),
                  ),
              ],
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
  const _TabChip({super.key, required this.tab, required this.active, required this.first, required this.onTap, required this.onClose});

  final WsTab tab;
  final bool active;

  /// Первая вкладка стоит над левым краем блока: дуги слева у неё нет, угол блока прямой.
  final bool first;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final (icon, label, color) = _look(l, ref);
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

  (String, String, Color?) _look(L l, WidgetRef ref) {
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
