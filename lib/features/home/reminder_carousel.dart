import 'dart:math' as math;

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
/// Несколько — карусель M3: ведущая карточка широкая, следующие узкими полосками;
/// при прокрутке следующая расширяется, светлеет и проявляет текст.
/// Касание узкой выдвигает её вперёд, касание ведущей открывает заметку, галочка снимает напоминание.
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

/// «завтра в 09:00» → «Завтра в 09:00»: время стоит первой строкой карточки.
String _when(L l, DateTime at, DateTime now) {
  final text = formatReminder(l, at, now);
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

TextStyle _titleStyle(BuildContext context, Color color) =>
    Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: _titleSize, color: color, height: _titleHeight);

class _ReminderCarouselState extends State<ReminderCarousel> {
  final _controller = CarouselController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Полоску — в центр.
  void _bring(int index) {
    HapticFeedback.selectionClick();
    _controller.animateToItem(index, duration: Motion.medium, curve: Motion.emphasized);
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
    // ведущая по центру, слева и справа по полоске соседей, как hero-карусель M3
    const weights = [1, 6, 1];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen - 4, 0, Space.screen - 4, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final total = weights.fold(0, (sum, weight) => sum + weight);
          final fullWidth = constraints.maxWidth * weights.reduce(math.max) / total - 8;
          final scale = MediaQuery.textScalerOf(context);
          final lines = _titleLines(context, fullWidth - _pad * 2);
          final top = math.max(_smallButton, scale.scale(_whenSize) * 1.45);
          final height = _pad * 2 + top + 4 + scale.scale(_titleSize) * _titleHeight * lines + 2;
          return SizedBox(
            height: height,
            // полоса прокрутки у ряда из трёх карточек только мешает
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: CarouselView.weighted(
                controller: _controller,
                flexWeights: weights,
                itemSnapping: true,
                // по кругу в обе стороны: за последней снова первая, справа не остаётся пустоты
                infinite: true,
                // кнопки внутри карточки должны нажиматься: своя рябь у каждой карточки
                enableSplash: false,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                backgroundColor: Colors.transparent,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.card))),
                children: [
                  for (final (index, item) in items.indexed)
                    _ReminderCard(
                      key: ValueKey('reminder-${item.id}'),
                      item: item,
                      now: widget.now,
                      fullWidth: fullWidth,
                      onOpen: () => widget.onOpen(item),
                      onBring: () => _bring(index),
                      onDone: () => widget.onDone(item),
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

/// Карточка карусели меняет вид по своей ширине: во всю — белая с текстом, галочкой и точками,
/// уже — темнеет, текст тает, остаётся значок со временем, у самой узкой — один будильник.
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
  final VoidCallback onBring;
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
        return Material(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open > 0.8 ? onOpen : onBring,
            child: width >= 150 ? _wide(context, open) : _narrow(context, width, constraints.maxHeight),
          ),
        );
      },
    );
  }

  Widget _wide(BuildContext context, double open) {
    final l = L.of(context);
    final ink = Color.lerp(Tokens.onSurface, Tokens.onAccent, open)!;
    final soft = Color.lerp(Tokens.onSurfaceVariant, Tokens.onAccentVariant, open)!;
    return CustomPaint(
      painter: _Dots(ink.withValues(alpha: ink.a * open)),
      child: Padding(
        padding: const EdgeInsets.all(_pad),
        // текст проявляется, пока карточка раскрывается
        child: Opacity(
          opacity: open,
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
              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _titleStyle(context, ink)),
            ],
          ),
        ),
      ),
    );
  }

  /// Узкая: значок и время под ним, у самой узкой — только будильник.
  Widget _narrow(BuildContext context, double width, double height) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(item.reminderAt!), alwaysUse24HourFormat: true);
    final timeStyle = Theme.of(context).textTheme.labelMedium!.copyWith(color: Tokens.onSurfaceVariant);
    // под значком строка времени: значок не выше, чем осталось над ней
    final badge = math.min(52.0, math.min(width - 16, height - 40));
    if (width < 64 || badge < 28) {
      return Center(child: Icon(symbolIcon('alarm', filled: true), size: math.min(22.0, math.max(0.0, width - 8)), color: Tokens.onSurfaceVariant));
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ShapeBadge(
          shape: BadgeShape.cookie9,
          size: badge,
          color: Tokens.containerHighest,
          child: Icon(symbolIcon('alarm', filled: true), size: badge * 0.46, color: Tokens.onSurface),
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
