import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../domain/note_links.dart' show shownTitle;
import '../../core/widgets/shape_badge.dart';
import '../../data/repositories/items_repository.dart';
import '../../l10n/app_localizations.dart';

/// Ближайшие напоминания наверху главной. Одно — белая карточка во всю ширину.
/// Несколько — карусель M3: ведущая широкая по центру, соседние узкими полосками по краям;
/// при прокрутке следующая расширяется, светлеет и проявляет текст. Листается по кругу,
/// один взмах — одна карточка, раз в минуту сама переходит на следующую.
/// Касание полоски выдвигает её в центр, касание ведущей открывает заметку, галочка снимает напоминание.
class ReminderCarousel extends StatefulWidget {
  const ReminderCarousel({super.key, required this.items, required this.now, required this.onOpen, required this.onDone});

  final List<ItemCard> items;
  final DateTime now;
  final ValueChanged<ItemCard> onOpen;
  final ValueChanged<ItemCard> onDone;

  @override
  State<ReminderCarousel> createState() => _ReminderCarouselState();
}

const _titleSize = 17.0;
const _titleHeight = 1.25;
const _whenSize = 14.0;
const _pad = 16.0;
const _button = 40.0;

/// Галочка карусели стоит в строке времени: меньше, чтобы ряд не рос.
const _smallButton = 32.0;

/// Ведущая по центру, слева и справа по полоске соседей, как hero-карусель M3.
const _weights = [1, 6, 1];

/// Где при раскрытии карточки значок уступает место тексту.
const _swap = 0.35;

/// Как часто карусель сама переходит на следующую.
const _autoTurn = Duration(minutes: 1);

/// Сколько пройти пальцем, чтобы сдвинуть на одну карточку: доля ширины карусели.
const _dragPerCard = 0.4;

/// Быстрый взмах листает на одну, даже если палец прошёл меньше половины пути.
const _flingSpeed = 250.0;

// «по кругу»: стартуем далеко от нуля, чтобы листать назад было куда
const _startCycles = 1000;

/// «завтра в 09:00» → «Завтра в 09:00»: время стоит первой строкой карточки.
String _when(L l, DateTime at, DateTime now) {
  final text = formatReminder(l, at, now);
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

TextStyle _titleStyle(BuildContext context, Color color) =>
    Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: _titleSize, color: color, height: _titleHeight);

class _ReminderCarouselState extends State<ReminderCarousel> {
  // первой ведущей стоит первое напоминание, слева от неё по кругу последнее
  late final _controller = CarouselController(initialItem: widget.items.length * _startCycles);
  final _row = GlobalKey();
  Timer? _turn;
  double _dragFrom = 0;
  double _dragged = 0;

  @override
  void initState() {
    super.initState();
    _restartTurn();
  }

  @override
  void dispose() {
    _turn?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // шаг карусели M3 — ширина узкой полоски: на столько сдвигается ряд, когда карточка уходит
  double get _step => _controller.position.viewportDimension * _weights.first / _weights.fold(0, (sum, weight) => sum + weight);

  /// На [cards] карточек вперёд (минус — назад) от той, что сейчас ведущая.
  void _turnBy(int cards, {Duration duration = Motion.medium}) {
    if (!_controller.hasClients) return;
    final from = (_controller.offset / _step).round();
    _controller.animateTo((from + cards) * _step, duration: duration, curve: Motion.emphasized);
  }

  // минута считается заново после каждого листания: карточка не уезжает из-под пальца
  void _restartTurn() {
    _turn?.cancel();
    if (widget.items.length < 2) return;
    _turn = Timer.periodic(_autoTurn, (_) => _turnBy(1, duration: Motion.long));
  }

  // свой взмах вместо прокрутки карусели: у неё шаг — узкая полоска, и один взмах пролетал три-четыре карточки
  void _dragStart(DragStartDetails details) {
    _turn?.cancel();
    _dragFrom = _controller.offset;
    _dragged = 0;
  }

  void _dragUpdate(DragUpdateDetails details) {
    _dragged += details.primaryDelta ?? 0;
    final width = _controller.position.viewportDimension;
    final target = _dragFrom - _dragged / (width * _dragPerCard) * _step;
    // палец тянет не дальше одной карточки в каждую сторону
    _controller.jumpTo(target.clamp(_dragFrom - _step, _dragFrom + _step));
  }

  void _dragEnd(DragEndDetails details) {
    final speed = details.primaryVelocity ?? 0;
    final start = (_dragFrom / _step).round();
    var target = (_controller.offset / _step).round();
    if (speed.abs() > _flingSpeed) target = start + (speed < 0 ? 1 : -1);
    target = target.clamp(start - 1, start + 1);
    _controller.animateTo(target * _step, duration: Motion.medium, curve: Motion.emphasized);
    _restartTurn();
  }

  /// Полоску — в центр: левую назад, правую вперёд.
  void _bring(BuildContext card) {
    HapticFeedback.selectionClick();
    final box = card.findRenderObject() as RenderBox?;
    final row = _row.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || row == null) return;
    final center = box.localToGlobal(box.size.center(Offset.zero)).dx;
    _turnBy(center < row.localToGlobal(row.size.center(Offset.zero)).dx ? -1 : 1);
    _restartTurn();
  }

  /// Две строки заголовка нужны, только если хоть один не влезает в одну: иначе ряд ниже.
  int _titleLines(BuildContext context, double textWidth) {
    final style = _titleStyle(context, Tokens.onAccent);
    final scaler = MediaQuery.textScalerOf(context);
    for (final item in widget.items) {
      final painter = TextPainter(text: TextSpan(text: item.title, style: style), maxLines: 1, textDirection: TextDirection.ltr, textScaler: scaler)
        ..layout(maxWidth: textWidth);
      final wraps = painter.didExceedMaxLines;
      painter.dispose();
      if (wraps) return 2;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    // снизу щель, как у остальных карточек главной: иначе карточка под ней прилипает
    if (items.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 16),
        child: _SingleReminder(
          key: ValueKey('reminder-${items.first.id}'),
          item: items.first,
          now: widget.now,
          onTap: () => widget.onOpen(items.first),
          onDone: () => widget.onDone(items.first),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen - 4, 0, Space.screen - 4, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final total = _weights.fold(0, (sum, weight) => sum + weight);
          final fullWidth = constraints.maxWidth * _weights.reduce(math.max) / total - 8;
          final scale = MediaQuery.textScalerOf(context);
          final lines = _titleLines(context, fullWidth - _pad * 2);
          final top = math.max(_smallButton, scale.scale(_whenSize) * 1.45);
          final height = _pad * 2 + top + 4 + scale.scale(_titleSize) * _titleHeight * lines + 2;
          return GestureDetector(
            key: _row,
            onHorizontalDragStart: _dragStart,
            onHorizontalDragUpdate: _dragUpdate,
            onHorizontalDragEnd: _dragEnd,
            child: SizedBox(
              height: height,
              // полоса прокрутки у ряда из трёх карточек только мешает; тянет ряд свой взмах, а не карусель
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false, dragDevices: const {}),
                child: CarouselView.weighted(
                  controller: _controller,
                  flexWeights: _weights,
                  // по кругу в обе стороны: за последней снова первая, справа не остаётся пустоты
                  infinite: true,
                  // кнопки внутри карточки должны нажиматься: своя рябь у каждой карточки
                  enableSplash: false,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  backgroundColor: Colors.transparent,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.card))),
                  children: [
                    for (final item in items)
                      _ReminderCard(
                        key: ValueKey('reminder-${item.id}'),
                        item: item,
                        now: widget.now,
                        fullWidth: fullWidth,
                        onOpen: () => widget.onOpen(item),
                        onBring: _bring,
                        onDone: () => widget.onDone(item),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Одно напоминание: значок, заголовок, время и галочка, точки по правой половине.
class _SingleReminder extends StatelessWidget {
  const _SingleReminder({super.key, required this.item, required this.now, required this.onTap, required this.onDone});

  final ItemCard item;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      color: Tokens.accent,
      borderRadius: BorderRadius.circular(Radii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: CustomPaint(
          painter: _Dots(Tokens.onAccent),
          child: Padding(
            padding: const EdgeInsets.all(_pad),
            child: Row(
              children: [
                ShapeBadge(
                  shape: BadgeShape.cookie9,
                  size: 52,
                  child: Icon(symbolIcon('alarm', filled: true), color: Tokens.onSurface),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shownTitle(item.title), maxLines: 2, overflow: TextOverflow.ellipsis, style: _titleStyle(context, Tokens.onAccent)),
                      const SizedBox(height: 2),
                      Text(_when(l, item.reminderAt!, now), style: text.bodyMedium!.copyWith(fontSize: _whenSize, color: Tokens.onAccentVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _DoneButton(onDone: onDone, open: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Карточка карусели меняет вид по своей ширине: во всю — белая с текстом, галочкой и точками,
/// уже — темнеет, текст тает, проступает значок со временем, у самой узкой — один будильник.
/// Текст и значок сменяют друг друга цветом, без прозрачности слоя: пустой плашки не бывает,
/// и кадр не перерисовывается целиком.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    super.key,
    required this.item,
    required this.now,
    required this.fullWidth,
    required this.onOpen,
    required this.onBring,
    required this.onDone,
  });

  final ItemCard item;
  final DateTime now;

  /// Ширина ведущей карточки: на ней раскрытие полное.
  final double fullWidth;

  /// Касание раскрытой — открыть заметку, полоски — выдвинуть её в центр.
  final VoidCallback onOpen;
  final ValueChanged<BuildContext> onBring;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // 0 — полоска, 1 — ведущая во всю ширину; цвет и текст идут за шириной кадр в кадр
        final open = ((width - fullWidth * 0.6) / (fullWidth * 0.35)).clamp(0.0, 1.0);
        // серая середина проскакивает быстро: цвет меняется в средней трети раскрытия
        final fill = Color.lerp(Tokens.containerHigh, Tokens.accent, Curves.easeInOutCubic.transform(open))!;
        final card = Material(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open > 0.8 ? onOpen : () => onBring(context),
            // значок гаснет в первой трети раскрытия, текст проступает после: друг на друга не ложатся
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (open < _swap) _narrow(context, width, constraints.maxHeight, 1 - open / _swap),
                if (open > _swap) _wide(context, open, (open - _swap) / (1 - _swap)),
              ],
            ),
          ),
        );
        return open > 0.8 ? KeyedSubtree(key: const ValueKey('reminder-lead'), child: card) : card;
      },
    );
  }

  /// [shown] — насколько проступил текст.
  Widget _wide(BuildContext context, double open, double shown) {
    final l = L.of(context);
    Color faded(Color color) => color.withValues(alpha: color.a * shown);
    final ink = faded(Color.lerp(Tokens.onSurface, Tokens.onAccent, open)!);
    final soft = faded(Color.lerp(Tokens.onSurfaceVariant, Tokens.onAccentVariant, open)!);
    return CustomPaint(
      painter: _Dots(ink),
      child: Padding(
        padding: const EdgeInsets.all(_pad),
        // текст проявляется, пока карточка раскрывается
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _smallButton,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _when(l, item.reminderAt!, now),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: _whenSize, color: soft),
                      ),
                    ),
                    // галочка только у раскрытой: у полуоткрытой её легко задеть, листая
                    if (open > 0.6) _DoneButton(onDone: onDone, open: open, size: _smallButton),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // заголовку вся ширина карточки
              Text(shownTitle(item.title), maxLines: 2, overflow: TextOverflow.ellipsis, style: _titleStyle(context, ink)),
            ],
        ),
      ),
    );
  }

  /// Узкая: значок и время под ним, у самой узкой — только будильник; [shown] — насколько видна.
  Widget _narrow(BuildContext context, double width, double height, double shown) {
    Color faded(Color color) => color.withValues(alpha: color.a * shown);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(item.reminderAt!), alwaysUse24HourFormat: true);
    final timeStyle = Theme.of(context).textTheme.labelMedium!.copyWith(color: faded(Tokens.onSurfaceVariant));
    // под значком строка времени: значок не выше, чем осталось над ней
    final badge = math.min(52.0, math.min(width - 16, height - 40));
    if (width < 64 || badge < 28) {
      return Center(child: Icon(symbolIcon('alarm', filled: true), size: math.min(22.0, math.max(0.0, width - 8)), color: faded(Tokens.onSurfaceVariant)));
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ShapeBadge(
          shape: BadgeShape.cookie9,
          size: badge,
          color: faded(Tokens.containerHighest),
          child: Icon(symbolIcon('alarm', filled: true), size: badge * 0.46, color: faded(Tokens.onSurface)),
        ),
        const SizedBox(height: 4),
        Text(time, maxLines: 1, overflow: TextOverflow.clip, style: timeStyle),
      ],
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onDone, required this.open, this.size = _button});

  final VoidCallback onDone;
  final double open;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: L.of(context).homeReminderDone,
      onPressed: onDone,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      style: IconButton.styleFrom(
        backgroundColor: Color.lerp(Tokens.containerHighest, Tokens.accentTonal, open),
        foregroundColor: Color.lerp(Tokens.onSurface, Tokens.onAccent, open),
      ),
      icon: Icon(symbolIcon('check'), size: size * 0.55),
    );
  }
}

/// Точки по правой половине карточки: от края середины крошечные, к правому краю крупнее.
class _Dots extends CustomPainter {
  _Dots(this.color);

  final Color color;

  static const _step = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0) return;
    final paint = Paint()..color = color.withValues(alpha: color.a * 0.09);
    final start = size.width / 2;
    for (var x = size.width - _step / 2; x > start; x -= _step) {
      final grow = (x - start) / (size.width - start);
      final radius = 0.4 + grow * 2.1;
      for (var y = _step / 2; y < size.height; y += _step) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Dots oldDelegate) => oldDelegate.color != color;
}
