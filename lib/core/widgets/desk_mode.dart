import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Под этим виджетом — рабочее пространство на мониторе. Его ставит оболочка: ширина окна
/// вкладки тут не признак, при делении окна вкладка бывает узкой, а это всё ещё монитор.
class DeskMode extends InheritedWidget {
  const DeskMode({super.key, required super.child});

  /// Открыто ли это место на мониторе.
  static bool of(BuildContext context) => context.getInheritedWidgetOfExactType<DeskMode>() != null;

  @override
  bool updateShouldNotify(DeskMode oldWidget) => false;
}

/// Шторка снизу на телефоне, окно на мониторе — как палитра в макете веба (`.modal`): у верха
/// экрана по центру, шириной до 560 точек, на затемнённом фоне; Esc и щелчок мимо закрывают.
/// [builder] получает контекст шторки или окна: им же закрывают (`Navigator.pop(sheet, …)`).
Future<T?> showStowaSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool showDragHandle = true,
  Color? backgroundColor,
  // доля высоты экрана для шторки на телефоне; null — сколько займёт содержимое
  double? maxHeightFactor = 0.75,
}) {
  if (DeskMode.of(context)) {
    // окно опускается на место с 10 точек выше, чуть вырастая и проявляясь, как в макете;
    // закрывается быстрее, чем открывается
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Tokens.palette.isDark ? const Color(0xB80C0D0E) : const Color(0x6B1B1C1E),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (context, animation, _, child) {
        if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return FadeTransition(opacity: animation, child: child);
        final drop = CurvedAnimation(parent: animation, curve: Motion.emphasizedDecelerate, reverseCurve: Motion.emphasizedAccelerate);
        return FadeTransition(
          opacity: drop,
          child: AnimatedBuilder(
            animation: drop,
            child: child,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -10 * (1 - drop.value)),
              child: Transform.scale(scale: 0.98 + 0.02 * drop.value, alignment: Alignment.topCenter, child: child),
            ),
          ),
        );
      },
      pageBuilder: (dialog, _, _) {
        final height = MediaQuery.sizeOf(dialog).height;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, height * 0.12, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 560, maxHeight: height * 0.76),
              child: Material(
                key: const ValueKey('desk-sheet'),
                color: backgroundColor ?? Tokens.containerHigh,
                borderRadius: BorderRadius.circular(Radii.card),
                clipBehavior: Clip.antiAlias,
                // окно живёт над оболочкой: признак монитора передаётся заново, иначе выбор из окна
                // («Переложить» → «Новая папка») выехал бы шторкой снизу
                child: Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: DeskMode(child: Builder(builder: builder))),
              ),
            ),
          ),
        );
      },
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: showDragHandle,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: backgroundColor,
    builder: (sheet) => Padding(
      // шторка поднимается над клавиатурой
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: maxHeightFactor == null
          ? SafeArea(top: false, child: builder(sheet))
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * maxHeightFactor),
              child: SafeArea(top: false, child: builder(sheet)),
            ),
    ),
  );
}
