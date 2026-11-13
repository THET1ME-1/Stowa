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

/// Ближайшие напоминания наверху главной. Одно — карточка во всю ширину.
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

class _ReminderCarouselState extends State<ReminderCarousel> {
  final _controller = CarouselController();
  int _lead = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tap(int index) {
    if (index == _lead) return widget.onOpen(widget.items[index]);
    HapticFeedback.selectionClick();
    _controller.animateToItem(index, duration: Motion.medium, curve: Motion.emphasized);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    // снизу щель, как у остальных карточек главной: иначе карточка под ней прилипает
    if (items.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 16),
        child: SizedBox(
          height: _ReminderCard.heightOf(context),
          child: _ReminderCard(
            key: ValueKey('reminder-${items.first.id}'),
            item: items.first,
            now: widget.now,
            fullWidth: double.infinity,
            onTap: () => widget.onOpen(items.first),
            onDone: () => widget.onDone(items.first),
          ),
        ),
      );
    }
    // большая, средняя и узкая, как в галерее M3, только низкие и вытянутые по ширине
    final weights = items.length == 2 ? const [6, 3] : const [6, 3, 1];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen - 4, 0, Space.screen - 4, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final total = weights.fold(0, (sum, weight) => sum + weight);
          final fullWidth = constraints.maxWidth * weights.first / total - 8;
          return SizedBox(
            height: _ReminderCard.heightOf(context),
            // полоса прокрутки у ряда из трёх карточек только мешает
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: CarouselView.weighted(
                controller: _controller,
                flexWeights: weights,
                itemSnapping: true,
                // кнопки внутри карточки должны нажиматься: своя рябь у каждой карточки
                enableSplash: false,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                backgroundColor: Colors.transparent,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.card))),
                onIndexChanged: (index) => _lead = index,
                children: [
                  for (final (index, item) in items.indexed)
                    _ReminderCard(
                      key: ValueKey('reminder-${item.id}'),
                      item: item,
                      now: widget.now,
                      fullWidth: fullWidth,
                      onTap: () => _tap(index),
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

/// Карточка меняет вид по своей ширине: во всю — белая с текстом и галочкой,
/// уже — темнеет, текст тает, остаётся значок со временем, у самой узкой — один будильник.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({super.key, required this.item, required this.now, required this.fullWidth, required this.onTap, required this.onDone});

  final ItemCard item;
  final DateTime now;

  /// Ширина ведущей карточки: на ней раскрытие полное.
  final double fullWidth;
  final VoidCallback onTap;
  final VoidCallback onDone;

  static const _titleSize = 17.0;
  static const _titleHeight = 1.25;
  static const _whenSize = 14.0;
  static const _pad = 14.0;
  static const _button = 36.0;

  /// Высота: строка времени с галочкой и два ряда заголовка. У ряда она одна на все карточки.
  static double heightOf(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    final top = math.max(_button, scale.scale(_whenSize) * 1.5);
    return _pad * 2 + top + 6 + scale.scale(_titleSize) * _titleHeight * 2 + 4;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // 0 — полоска, 1 — ведущая во всю ширину; цвет и текст идут за шириной кадр в кадр
        final open = fullWidth.isInfinite ? 1.0 : ((width - fullWidth * 0.6) / (fullWidth * 0.35)).clamp(0.0, 1.0);
        // серая середина проскакивает быстро: цвет меняется в средней трети раскрытия
        final fill = Color.lerp(Tokens.containerHigh, Tokens.accent, Curves.easeInOutCubic.transform(open))!;
        return Material(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: width >= 150 ? _wide(context, open) : _narrow(context, width)),
        );
      },
    );
  }

  Widget _wide(BuildContext context, double open) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final ink = Color.lerp(Tokens.onSurface, Tokens.onAccent, open)!;
    final soft = Color.lerp(Tokens.onSurfaceVariant, Tokens.onAccentVariant, open)!;
    return Padding(
      padding: const EdgeInsets.all(_pad),
      // текст проявляется, пока карточка раскрывается
      child: Opacity(
        opacity: open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _button,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatReminder(l, item.reminderAt!, now),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium!.copyWith(fontSize: _whenSize, color: soft),
                    ),
                  ),
                  // галочка только у раскрытой: у полуоткрытой её легко задеть, листая
                  if (open > 0.6)
                    IconButton(
                      tooltip: l.homeReminderDone,
                      onPressed: onDone,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: _button, height: _button),
                      style: IconButton.styleFrom(backgroundColor: Color.lerp(Tokens.containerHighest, Tokens.accentTonal, open), foregroundColor: ink),
                      icon: Icon(symbolIcon('check'), size: 20),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium!.copyWith(fontSize: _titleSize, color: ink, height: _titleHeight),
            ),
          ],
        ),
      ),
    );
  }

  /// Узкая: значок и время под ним, у самой узкой — только будильник.
  Widget _narrow(BuildContext context, double width) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(item.reminderAt!), alwaysUse24HourFormat: true);
    if (width < 64) {
      return Center(
        child: Icon(symbolIcon('alarm', filled: true), size: math.min(22, width - 8).clamp(0, 22).toDouble(), color: Tokens.onSurfaceVariant),
      );
    }
    final badge = math.min(52.0, width - 16);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ShapeBadge(
          shape: BadgeShape.cookie9,
          size: badge,
          color: Tokens.containerHighest,
          child: Icon(symbolIcon('alarm', filled: true), size: badge * 0.46, color: Tokens.onSurface),
        ),
        const SizedBox(height: 6),
        Text(
          time,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: Theme.of(context).textTheme.labelMedium!.copyWith(color: Tokens.onSurfaceVariant),
        ),
      ],
    );
  }
}
