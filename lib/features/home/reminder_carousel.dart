import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/shape_badge.dart';
import '../../data/repositories/items_repository.dart';
import '../../l10n/app_localizations.dart';

/// Ближайшие напоминания наверху главной. Одно — белая карточка во всю ширину.
/// Несколько — карусель: ведущая по центру, по краям видны соседние, листается по кругу,
/// один взмах — одна карточка, раз в минуту сама переходит на следующую.
/// Соседние меньше и темнее; пока листаешь, следующая растёт и светлеет.
/// Касание соседней выдвигает её в центр, касание ведущей открывает заметку, галочка снимает напоминание.
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

/// Доля ширины на одну карточку: по краям остаётся место соседним.
const _pageFraction = 0.8;

/// Соседняя карточка меньше ведущей.
const _sideScale = 0.9;

/// Как часто карусель сама переходит на следующую.
const _autoTurn = Duration(minutes: 1);

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
  late final _pages = PageController(viewportFraction: _pageFraction, initialPage: widget.items.length * _startCycles);
  Timer? _turn;

  @override
  void initState() {
    super.initState();
    _restartTurn();
  }

  @override
  void dispose() {
    _turn?.cancel();
    _pages.dispose();
    super.dispose();
  }

  // минута считается заново после каждого листания: карточка не уезжает из-под пальца
  void _restartTurn() {
    _turn?.cancel();
    if (widget.items.length < 2) return;
    _turn = Timer.periodic(_autoTurn, (_) {
      if (!_pages.hasClients) return;
      _pages.nextPage(duration: Motion.long, curve: Motion.emphasized);
    });
  }

  double get _page => _pages.hasClients && _pages.position.haveDimensions ? _pages.page! : _pages.initialPage.toDouble();

  void _bring(int page) {
    HapticFeedback.selectionClick();
    _pages.animateToPage(page, duration: Motion.medium, curve: Motion.emphasized);
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
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth * _pageFraction - 8;
          final scale = MediaQuery.textScalerOf(context);
          final lines = _titleLines(context, cardWidth - _pad * 2);
          final top = math.max(_smallButton, scale.scale(_whenSize) * 1.45);
          final height = _pad * 2 + top + 4 + scale.scale(_titleSize) * _titleHeight * lines + 2;
          return SizedBox(
            height: height,
            // рука листает — минута автолистания начинается заново
            child: NotificationListener<ScrollStartNotification>(
              onNotification: (notification) {
                if (notification.dragDetails != null) _restartTurn();
                return false;
              },
              child: PageView.builder(
                controller: _pages,
                // ушедшая карточка уезжает за край экрана, а не обрезается
                clipBehavior: Clip.none,
                itemBuilder: (context, page) {
                  final item = items[page % items.length];
                  return AnimatedBuilder(
                    animation: _pages,
                    builder: (context, _) {
                      // 1 — карточка по центру, 0 — соседняя
                      final open = (1 - (_page - page).abs()).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Transform.scale(
                          scale: lerpDouble(_sideScale, 1, open)!,
                          child: _ReminderCard(
                            key: open > 0.5 ? const ValueKey('reminder-lead') : ValueKey('reminder-${item.id}'),
                            item: item,
                            now: widget.now,
                            open: open,
                            onTap: open > 0.5 ? () => widget.onOpen(item) : () => _bring(page),
                            onDone: () => widget.onDone(item),
                          ),
                        ),
                      );
                    },
                  );
                },
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
                      Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _titleStyle(context, Tokens.onAccent)),
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

/// Карточка карусели: время, галочка и заголовок у всех, у ведущей ([open] 1) — белая,
/// у соседней ([open] 0) — на подложке. Цвета тянутся за прокруткой, без прозрачности слоя.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({super.key, required this.item, required this.now, required this.open, required this.onTap, required this.onDone});

  final ItemCard item;
  final DateTime now;
  final double open;
  final VoidCallback onTap;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final shade = Curves.easeInOutCubic.transform(open);
    final fill = Color.lerp(Tokens.containerHigh, Tokens.accent, shade)!;
    final ink = Color.lerp(Tokens.onSurface, Tokens.onAccent, shade)!;
    final soft = Color.lerp(Tokens.onSurfaceVariant, Tokens.onAccentVariant, shade)!;
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(Radii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: CustomPaint(
          painter: _Dots(ink.withValues(alpha: ink.a * shade)),
          child: Padding(
            padding: const EdgeInsets.all(_pad),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: _smallButton,
                  child: Row(
                    children: [
                      Icon(symbolIcon('alarm', filled: true), size: 16, color: soft),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _when(l, item.reminderAt!, now),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: _whenSize, color: soft),
                        ),
                      ),
                      // галочка только у ведущей: у соседней её легко задеть, листая
                      if (open > 0.5) _DoneButton(onDone: onDone, open: open, size: _smallButton),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _titleStyle(context, ink)),
              ],
            ),
          ),
        ),
      ),
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
