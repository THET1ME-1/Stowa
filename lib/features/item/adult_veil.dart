import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/providers.dart';

/// Прятать ли обложку и описание вещи: страница сказала «18+», а человек показ не включал.
bool adultHidden(WidgetRef ref, String itemId) {
  if (ref.watch(showAdultProvider).value ?? false) return false;
  return ref.watch(adultItemsProvider).value?.contains(itemId) ?? false;
}

/// Обложка вещи 18+ — размытой, с пометкой «18+». Включил показ в настройках — видна как есть.
class AdultVeil extends ConsumerWidget {
  const AdultVeil({super.key, required this.itemId, required this.child, this.compact = false});

  final String itemId;
  final Widget child;

  /// Маленькая картинка в строке: пометка мельче.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!adultHidden(ref, itemId)) return child;
    return Stack(
      key: ValueKey('adult-veil-$itemId'),
      fit: StackFit.passthrough,
      children: [
        ClipRect(
          child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: compact ? 8 : 28, sigmaY: compact ? 8 : 28), child: child),
        ),
        Positioned.fill(child: ColoredBox(color: Tokens.background.withValues(alpha: 0.35))),
        Positioned.fill(
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 10, vertical: compact ? 2 : 5),
              decoration: BoxDecoration(color: Tokens.background.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(compact ? 8 : 14)),
              child: Text('18+', style: TextStyle(fontSize: compact ? 11 : 15, fontWeight: FontWeight.w800, color: Tokens.onSurface)),
            ),
          ),
        ),
      ],
    );
  }
}
