import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

/// «Нужно место «всегда»» — только пока есть напоминание по месту, которое без него не сработает.
/// Появляется как следствие действия (поставил «напомни дома»), а не при первом открытии.
class PlaceAlwaysCard extends ConsumerWidget {
  const PlaceAlwaysCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(placeNeedsAlwaysProvider).value != true) return const SizedBox.shrink();
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    Future<void> allow() async {
      await ref.read(placeChannelProvider).askBackground();
      ref.invalidate(placeNeedsAlwaysProvider);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
        decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(28)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(symbolIcon('location_on'), size: 20, color: Tokens.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(child: Text(l.placesPermissionTitle, style: text.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text(l.placesPermissionBody, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: allow, child: Text(l.placesPermissionAllow)),
            ),
          ],
        ),
      ),
    );
  }
}
