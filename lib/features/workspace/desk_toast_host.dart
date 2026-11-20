import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';

/// Плашки рабочего пространства: пилюля цвета акцента по центру над общей строкой
/// (макет веба, `.toast`). Встаёт прямо в `Stack` окон: сама отдаёт `Positioned`.
/// Пока она на экране, `showUndo` и `showNote` идут сюда, а не в `SnackBar`.
class DeskToastHost extends StatefulWidget {
  const DeskToastHost({super.key, required this.bottom});

  /// Отступ от низа окон: над общей строкой.
  final double bottom;

  @override
  State<DeskToastHost> createState() => _DeskToastHostState();
}

class _DeskToastHostState extends State<DeskToastHost> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    deskToasts.attach();
    deskToasts.addListener(_changed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    deskToasts.removeListener(_changed);
    deskToasts.detach();
    super.dispose();
  }

  // новая плашка сменяет прежнюю и уходит сама через свой срок
  void _changed() {
    _timer?.cancel();
    final toast = deskToasts.value;
    if (toast != null) _timer = Timer(toast.duration, () => deskToasts.hide(toast));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final toast = deskToasts.value;
    return Positioned(
      left: 16,
      right: 16,
      bottom: widget.bottom,
      child: Center(
        child: AnimatedSwitcher(
          duration: Motion.short,
          switchInCurve: Motion.emphasizedDecelerate,
          switchOutCurve: Motion.emphasizedAccelerate,
          // плашка мягко поднимается на 12 точек и проявляется, уходит обратно
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation), child: child),
          ),
          child: toast == null ? const SizedBox.shrink() : _Pill(key: ObjectKey(toast), toast: toast),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.toast});

  final DeskToast toast;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(color: Tokens.onAccent, fontSize: 14, height: 1.3);
    final label = toast.label;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Material(
        key: const ValueKey('desk-toast'),
        color: Tokens.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, label == null ? 16 : 10, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(toast.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: style)),
              if (label != null) ...[
                const SizedBox(width: 14),
                Material(
                  color: Tokens.onAccent.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      deskToasts.hide(toast);
                      toast.onTap?.call();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(label, style: style.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
