import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

/// Разрешение на уведомления — в тот момент, когда человек ставит напоминание или включает
/// возврат, а не при открытии приложения. Уже разрешено — Android окна не показывает.
Future<void> askNotifications(WidgetRef ref) => ref.read(notificationPortProvider).ensurePermission();

/// Напоминание по месту: уведомления и место «всегда». Без «всегда» Android не будит Stowa у
/// точки и не отдаёт имя сети, напоминание молча не сработало бы — плашка с «Разрешить».
/// Сразу на системный экран не ведём: там Android 11+ просит выбрать «всегда» самому.
Future<void> askPlaceReminder(WidgetRef ref, ScaffoldMessengerState messenger, L l, {bool overDock = false}) async {
  await askNotifications(ref);
  final channel = ref.read(placeChannelProvider);
  if (await channel.hasBackground()) return;
  showUndo(
    messenger,
    message: l.remindPlaceNeedsAlways,
    label: l.placesPermissionAllow,
    onUndo: () async {
      await channel.askBackground();
      ref.invalidate(placeNeedsAlwaysProvider);
    },
    duration: const Duration(seconds: 8),
    overDock: overDock,
  );
}
