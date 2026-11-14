import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/edge_settings.dart';
import '../../domain/note_blocks.dart' show toggleCheckLine;
import '../../domain/spine_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/edge_channel.dart';
import '../../services/privacy/hidden_rows.dart' show hiddenFolderIds;
import '../composer/line_dock.dart';
import '../folder/folder_screen.dart';
import '../home/folder_shelf.dart';
import '../home/note_timeline.dart';
import '../item/item_actions.dart';
import '../item/item_screen.dart';
import '../settings/edge_screen.dart';

/// Ширина полки; на узком экране — чуть меньше экрана.
const _shelfWidth = 312.0;

/// Сколько снизу закрывает строка ввода: последние карточки прокручиваются над ней.
const _dockSpace = 150.0;

/// Последних заметок на полке: всё остальное — поиском строки или в самом приложении.
const _recentOnShelf = 10;

/// Отступ полки от края экрана.
const _edgeGap = 8.0;

/// Затемнение за открытой полкой.
const _scrimAlpha = 0.32;

/// Бросок пальцем быстрее этого (долей пути полки в секунду) решает сам, куда ей ехать.
const _flingSpeed = 1.0;

/// Проявление строк полки при открытии: каждая на 25 мс позже предыдущей.
const _riseStep = Duration(milliseconds: 25);
const _riseRows = 16;
final _riseTotal = Motion.long + _riseStep * _riseRows;

/// Полка «Под рукой» в окне поверх других приложений (движок `edgeMain`, окно ставит
/// EdgeService во весь экран, пока полка открыта). Шапка, папки, закреплённые, недавние и
/// та же строка, что в приложении; заметка и настройка корешков открываются в самой полке.
/// Полка выезжает и уезжает здесь, в Dart: служба только сообщает касания и свайп корешков.
/// Движок живёт всё время службы, поэтому полка же шлёт службе цвета корешков.
class EdgeHost extends ConsumerStatefulWidget {
  const EdgeHost({super.key});

  @override
  ConsumerState<EdgeHost> createState() => _EdgeHostState();
}

class _EdgeHostState extends ConsumerState<EdgeHost> with TickerProviderStateMixin {
  final _shelfNavigator = GlobalKey<NavigatorState>();

  // пока база не ответила, считаем скрытое открытым: полка не покажет лишнего
  bool _hiddenOpen = true;

  /// 0 — полка за краем, 1 — на месте.
  late final _reveal = AnimationController(vsync: this);

  /// Проявление строк полки при каждом открытии.
  late final _rise = AnimationController(vsync: this, duration: _riseTotal, value: 1);

  StreamSubscription<EdgeEvent>? _events;

  /// Путь полки от места за краем до места на экране: ширина и отступ от края.
  double _travel = _shelfWidth + _edgeGap;

  /// Полка уже уезжает: окно уберётся, когда она скроется.
  bool _closing = false;

  /// Свайп начался с закрытой полки (открывают) или с открытой (убирают).
  bool _swipeOpens = true;
  double _swipeFrom = 0;

  @override
  void initState() {
    super.initState();
    _events = ref.read(edgeChannelProvider).events.listen(_onEvent);
    // замер плавности в profile-сборке: кадры каждого движения полки в журнал
    if (kProfileMode) {
      SchedulerBinding.instance.addTimingsCallback(_frames);
      _reveal.addStatusListener(_reportFrames);
    }
    // напоминание из набранного на полке встаёт сразу, как в окне виджета
    ref.listenManual(remindersProvider, (previous, next) {
      final reminders = next.value;
      if (reminders != null) ref.read(reminderServiceProvider).sync(reminders, ref.read(clockProvider)());
    });
    ref.listenManual(pinnedItemsProvider, (previous, next) => _sendSpines());
    ref.listenManual(privacyLockProvider, (previous, next) => _sendSpines());
    hiddenFolderIds(ref.read(databaseProvider)).then((folders) {
      if (!mounted) return;
      setState(() => _hiddenOpen = folders.isNotEmpty);
      _sendSpines();
    }).ignore();
  }

  final _motionFrames = <Duration>[];
  final _buildFrames = <Duration>[];
  final _rasterFrames = <Duration>[];
  bool _measuring = false;

  void _frames(List<FrameTiming> timings) {
    if (!_measuring) return;
    _motionFrames.addAll(timings.map((timing) => timing.totalSpan));
    _buildFrames.addAll(timings.map((timing) => timing.buildDuration));
    _rasterFrames.addAll(timings.map((timing) => timing.rasterDuration));
  }

  // тайминги Flutter присылает пачками с опозданием до 100 мс: итог — чуть позже конца движения
  void _reportFrames(AnimationStatus status) {
    if (status.isAnimating) {
      _measuring = true;
      return;
    }
    Timer(const Duration(milliseconds: 250), () {
      _measuring = false;
      if (_motionFrames.isEmpty) return;
      final sorted = [..._motionFrames]..sort();
      final slow = sorted.where((span) => span > const Duration(milliseconds: 16)).length;
      String worst(List<Duration> spans) => '${spans.reduce((a, b) => a > b ? a : b).inMicroseconds / 1000}';
      debugPrint(
        'StowaEdge frames: ${sorted.length}, slow $slow, median ${sorted[sorted.length ~/ 2].inMicroseconds / 1000} ms, '
        'worst ${sorted.last.inMicroseconds / 1000} ms (build ${worst(_buildFrames)}, raster ${worst(_rasterFrames)})',
      );
      _motionFrames.clear();
      _buildFrames.clear();
      _rasterFrames.clear();
    });
  }

  @override
  void dispose() {
    if (kProfileMode) SchedulerBinding.instance.removeTimingsCallback(_frames);
    _events?.cancel().ignore();
    _reveal.dispose();
    _rise.dispose();
    super.dispose();
  }

  bool get _still => MediaQuery.disableAnimationsOf(context);

  void _onEvent(EdgeEvent event) {
    if (!mounted) return;
    switch (event) {
      case EdgeOpen():
        _open();
      case EdgeDragStart():
        _swipeStart(opens: true);
      case EdgeDrag(:final distance):
        _reveal.value = _swipeFrom + distance / _travel;
      case EdgeDragEnd(:final velocity):
        _settle(velocity / _travel);
      case EdgeDismiss():
        _close();
    }
  }

  /// Касание корешков: полка выезжает за `long`, строки проявляются одна за другой.
  void _open() {
    if (_reveal.value == 0) _riseRowsIn();
    _closing = false;
    if (_still) {
      _reveal.value = 1;
      return;
    }
    _reveal.animateTo(1, duration: Motion.long, curve: Motion.emphasizedDecelerate).ignore();
  }

  void _riseRowsIn() {
    if (_still) {
      _rise.value = 1;
      return;
    }
    _rise.forward(from: 0).ignore();
  }

  void _swipeStart({required bool opens}) {
    _reveal.stop();
    _closing = false;
    _swipeOpens = opens;
    _swipeFrom = _reveal.value;
    if (opens && _reveal.value == 0) _riseRowsIn();
  }

  /// Палец отпустили: бросок решает сам; иначе открывают дальше трети — доезжает,
  /// убирают дальше трети — уезжает, а не дотянули — полка возвращается, где была.
  void _settle(double speed) {
    final value = _reveal.value;
    final bool open;
    if (speed.abs() > _flingSpeed) {
      open = speed > 0;
    } else {
      open = _swipeOpens ? value > 1 / 3 : value > 2 / 3;
    }
    if (!open) return _close();
    if (_still) {
      _reveal.value = 1;
      return;
    }
    // с места пальца без разгона: decelerate начинает быстро, как будто полку отпустили на ходу
    final duration = Motion.medium * (1 - value);
    _reveal.animateTo(1, duration: duration < Motion.tap ? Motion.tap : duration, curve: Motion.emphasizedDecelerate).ignore();
  }

  /// Полка уезжает за край; окно служба уберёт, когда та скроется. Корешки возвращаются сразу.
  void _close() {
    if (_closing) return;
    _closing = true;
    final channel = ref.read(edgeChannelProvider);
    channel.closing().ignore();
    FocusManager.instance.primaryFocus?.unfocus();
    void gone() {
      if (!_closing || !mounted) return;
      _closing = false;
      // следующее открытие — снова сама полка, а не заметка, на которой ушли
      _shelfNavigator.currentState?.popUntil((route) => route.isFirst);
      channel.close().ignore();
    }

    if (_still || _reveal.value == 0) {
      _reveal.value = 0;
      return gone();
    }
    final duration = Motion.medium * _reveal.value;
    _reveal.animateTo(0, duration: duration < Motion.tap ? Motion.tap : duration, curve: Motion.emphasizedAccelerate).then((_) => gone(), onError: (_) {});
  }

  /// Свайп по самой полке: она идёт за пальцем к краю.
  void _shelfDragStart(DragStartDetails details) => _swipeStart(opens: false);

  void _shelfDrag(DragUpdateDetails details, {required bool right}) {
    final inward = right ? -details.delta.dx : details.delta.dx;
    _reveal.value += inward / _travel;
  }

  void _shelfDragEnd(DragEndDetails details, {required bool right}) {
    final dx = details.velocity.pixelsPerSecond.dx;
    _settle((right ? -dx : dx) / _travel);
  }

  /// С кодом на вход или открытым скрытым полка только записывает: заметки обошли бы замок.
  bool get _guarded {
    final lock = ref.read(privacyLockProvider).value ?? ref.read(startLockProvider);
    return (lock?.appLock ?? false) || _hiddenOpen;
  }

  /// Цвета корешков у края: закреплённые заметки цветом их папок; под замком — один корешок.
  void _sendSpines() {
    final pinned = ref.read(pinnedItemsProvider).value ?? const <ItemCard>[];
    final spines = spinesFor(
      [for (final card in pinned) (color: card.folderColor, length: card.title.length + card.body.length)],
      locked: _guarded,
      plain: Tokens.muted,
      accent: Tokens.accent,
    );
    ref.read(edgeChannelProvider).spines(spines).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(privacyLockProvider).value ?? ref.read(startLockProvider);
    final guarded = (lock?.appLock ?? false) || _hiddenOpen;
    final settings = ref.watch(edgeSettingsProvider).value ?? const EdgeSettings();
    final right = settings.side == EdgeSide.right;
    final width = math.min(_shelfWidth, MediaQuery.sizeOf(context).width - _edgeGap * 2);
    _travel = width + _edgeGap;
    final shelf = Container(
      key: const ValueKey('edge-shelf'),
      width: width,
      margin: EdgeInsets.only(top: 12, bottom: 12, left: right ? 0 : _edgeGap, right: right ? _edgeGap : 0),
      decoration: BoxDecoration(color: Tokens.background, borderRadius: BorderRadius.circular(Radii.card)),
      clipBehavior: Clip.antiAlias,
      // свой навигатор: заметка и настройка корешков открываются внутри скруглённой полки,
      // системное «назад» сперва листает его
      child: _ShelfScope(
        right: right,
        guarded: guarded,
        rise: _rise,
        onClose: _close,
        onDragStart: _shelfDragStart,
        onDrag: (details) => _shelfDrag(details, right: right),
        onDragEnd: (details) => _shelfDragEnd(details, right: right),
        child: NavigatorPopHandler(
          onPopWithResult: (_) => _shelfNavigator.currentState?.maybePop(),
          child: Navigator(
            key: _shelfNavigator,
            // страница строится один раз; край и замок она берёт из _ShelfScope
            onGenerateRoute: (settings) => PageRouteBuilder(settings: settings, pageBuilder: (context, animation, secondary) => const _ShelfHome()),
          ),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _reveal,
        child: shelf,
        builder: (context, shelf) {
          final shown = _reveal.value;
          return Stack(
            children: [
              // затемнение густеет вместе с полкой; касание мимо полки её убирает
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('edge-scrim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: ColoredBox(color: Colors.black.withValues(alpha: _scrimAlpha * shown)),
                ),
              ),
              // окно во весь экран, затемнение и под строкой состояния; полка — между полосами
              SafeArea(
                child: Align(
                  alignment: right ? Alignment.centerRight : Alignment.centerLeft,
                  child: Transform.translate(offset: Offset((right ? 1 : -1) * (1 - shown) * _travel, 0), child: shelf),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Что первой странице полки нужно от хозяина: край, замок, проявление строк и жесты.
class _ShelfScope extends InheritedWidget {
  const _ShelfScope({
    required this.right,
    required this.guarded,
    required this.rise,
    required this.onClose,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
    required super.child,
  });

  final bool right;
  final bool guarded;
  final Animation<double> rise;
  final VoidCallback onClose;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDrag;
  final GestureDragEndCallback onDragEnd;

  static _ShelfScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ShelfScope>()!;

  @override
  bool updateShouldNotify(_ShelfScope old) => right != old.right || guarded != old.guarded;
}

/// Первая страница полки: шапка, папки, заметки и строка. Свайп к краю по ней убирает полку.
class _ShelfHome extends StatelessWidget {
  const _ShelfHome();

  @override
  Widget build(BuildContext context) {
    final scope = _ShelfScope.of(context);
    void open(String id) => Navigator.of(context).push(itemRoute(id));
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // строку не оборачиваем: по её полю палец ходит вбок, двигая курсор
          GestureDetector(
            onHorizontalDragStart: scope.onDragStart,
            onHorizontalDragUpdate: scope.onDrag,
            onHorizontalDragEnd: scope.onDragEnd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Rise(animation: scope.rise, row: 0, child: _Header(right: scope.right, onClose: scope.onClose)),
                if (!scope.guarded) Expanded(child: _Shelf(onOpen: open, rise: scope.rise)) else const Spacer(),
              ],
            ),
          ),
          Positioned.fill(
            child: LineDock(
              onOpenItem: open,
              writeOnly: scope.guarded,
              elsewhere: LineElsewhere(
                handOff: (action, text) => ProviderScope.containerOf(context).read(edgeChannelProvider).handOff(action, text).ignore(),
                micGranted: () => ProviderScope.containerOf(context).read(edgeChannelProvider).micGranted(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Строка полки поднимается и проявляется при открытии: каждая на 25 мс позже предыдущей.
class _Rise extends StatelessWidget {
  const _Rise({required this.animation, required this.row, required this.child, this.fade = true});

  final Animation<double> animation;
  final int row;
  final Widget child;

  /// Карточки только поднимаются: полупрозрачная карточка рисуется отдельным слоем, и
  /// восемь таких разом на открытии давали кадры по 40–50 мс (эмулятор с видеокартой, 14.11).
  final bool fade;

  @override
  Widget build(BuildContext context) {
    final total = _riseTotal.inMicroseconds;
    final start = (_riseStep * math.min(row, _riseRows)).inMicroseconds / total;
    final end = start + Motion.long.inMicroseconds / total;
    final shown = CurvedAnimation(parent: animation, curve: Interval(start, math.min(end, 1), curve: Motion.emphasizedDecelerate));
    return AnimatedBuilder(
      animation: shown,
      child: child,
      builder: (context, child) {
        final risen = Transform.translate(offset: Offset(0, 16 * (1 - shown.value)), child: child);
        return fade ? Opacity(opacity: shown.value, child: risen) : risen;
      },
    );
  }
}

/// «Stowa», настройка корешков, открыть приложение, свернуть.
class _Header extends ConsumerWidget {
  const _Header({required this.right, required this.onClose});

  final bool right;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final channel = ref.read(edgeChannelProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Expanded(child: Text(l.appName, style: Theme.of(context).textTheme.titleLarge!.copyWith(fontFamily: 'Unbounded', fontSize: 18, fontWeight: FontWeight.w600))),
          _RoundButton(icon: 'settings', tooltip: l.edgeSpinesSetup, onTap: () => Navigator.of(context).push(edgeRoute())),
          const SizedBox(width: 6),
          _RoundButton(icon: 'north_east', tooltip: l.edgeOpenApp, onTap: () => channel.openApp(null)),
          const SizedBox(width: 6),
          _RoundButton(icon: right ? 'last_page' : 'first_page', tooltip: l.fullCollapse, onTap: onClose),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.9,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
          child: Icon(symbolIcon(icon), size: 20, color: Tokens.onSurface),
        ),
      ),
    );
  }
}

/// Папки, «Закреплено», «Недавние» — те же карточки, что на главной.
class _Shelf extends ConsumerWidget {
  const _Shelf({required this.onOpen, required this.rise});

  final ValueChanged<String> onOpen;
  final Animation<double> rise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final folders = ref.watch(foldersProvider).value ?? const [];
    final pinned = ref.watch(pinnedItemsProvider).value ?? const <ItemCard>[];
    final recent = (ref.watch(recentItemsProvider).value ?? const <ItemCard>[]).take(_recentOnShelf).toList();
    final filesRoot = ref.watch(filesRootProvider);
    final now = ref.read(clockProvider)();
    final items = ref.read(itemsRepositoryProvider);

    Widget card(ItemCard item) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NoteCard(
        key: ValueKey('edge-card-${item.id}'),
        item: item,
        dated: true,
        filesRoot: filesRoot,
        now: now,
        onOpen: () => onOpen(item.id),
        onMove: () => moveItem(context, ref, item),
        onAct: () => showItemActions(context, ref, item),
        onToggle: (line) {
          final body = toggleCheckLine(item.body, line);
          if (body != item.body) items.setBody(item.id, body, ref.read(clockProvider)()).ignore();
        },
        trailing: _StickButton(item: item),
      ),
    );

    // строки по порядку сверху: каждая проявляется на шаг позже предыдущей (шапка — нулевая)
    final rows = <Widget>[
      if (pinned.isNotEmpty) ...[_SectionLabel(icon: 'keep', filled: true, text: l.homePinned), for (final item in pinned) card(item)],
      if (recent.isNotEmpty) ...[_SectionLabel(icon: 'schedule', text: l.edgeRecent), for (final item in recent) card(item)],
    ];
    final first = folders.isNotEmpty ? 2 : 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, _dockSpace),
      children: [
        if (folders.isNotEmpty)
          _Rise(
            animation: rise,
            row: 1,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: FolderShelf(
                folders: [for (final folder in folders) if (folder.parentId == null) folder],
                onOpen: (folder) => Navigator.of(context).push(folderRoute(folder.id)),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final (index, row) in rows.indexed) _Rise(animation: rise, row: first + index, fade: row is _SectionLabel, child: row)],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text, this.filled = false});

  final String icon;
  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(color: Tokens.muted);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          Icon(symbolIcon(icon, filled: filled), size: 16, color: Tokens.muted),
          const SizedBox(width: 6),
          Text(text, style: style),
        ],
      ),
    );
  }
}

/// Кнопка в углу карточки: повесить заметку стикером поверх приложений.
class _StickButton extends ConsumerWidget {
  const _StickButton({required this.item});

  final ItemCard item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = item.folderColor;
    return Tooltip(
      message: L.of(context).edgeStick,
      child: Pressable(
        onTap: () => ref.read(edgeChannelProvider).pinSticker(item.id),
        pressedScale: 0.9,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: (color ?? Tokens.muted).withValues(alpha: 0.18), shape: BoxShape.circle),
          child: Icon(symbolIcon('picture_in_picture_alt'), size: 18, color: color ?? Tokens.onSurfaceVariant),
        ),
      ),
    );
  }
}
