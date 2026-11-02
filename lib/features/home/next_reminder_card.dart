import 'package:flutter/material.dart';

import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/shape_badge.dart';
import '../../data/repositories/items_repository.dart';
import '../../l10n/app_localizations.dart';

/// Белая карточка ближайшего напоминания: что, когда и сколько ещё впереди.
class NextReminderCard extends StatelessWidget {
  const NextReminderCard({super.key, required this.item, required this.more, required this.now, this.onDone, this.onTap});

  final ItemCard item;
  final int more;
  final DateTime now;
  final VoidCallback? onDone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final when = formatReminder(l, item.reminderAt!, now);
    final sub = more > 0 ? '$when · ${l.homeMoreToday(more)}' : when;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
      child: Material(
        color: Tokens.accent,
        borderRadius: BorderRadius.circular(Radii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.screen),
            child: Row(children: [
              ShapeBadge(
                shape: BadgeShape.cookie9,
                size: 52,
                child: Icon(symbolIcon('alarm', filled: true), color: Tokens.onSurface),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium!.copyWith(fontSize: 17, color: Tokens.onAccent, height: 1.25),
                  ),
                  const SizedBox(height: 2),
                  Text(sub, style: text.bodyMedium!.copyWith(fontSize: 14, color: Tokens.onAccentVariant)),
                ]),
              ),
              if (onDone != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: l.homeReminderDone,
                  onPressed: onDone,
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFE2E2DF), foregroundColor: Tokens.onAccent),
                  icon: Icon(symbolIcon('check')),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
