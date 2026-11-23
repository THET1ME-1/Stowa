import 'package:flutter/widgets.dart';

/// Отступ снизу: [lift] плюс системная полоса навигации.
///
/// Полоса читается здесь, а не на экране целиком. Пока клавиатура выезжает, полоса уходит под
/// неё, и отступ меняется на первых кадрах. Экран, который читает полосу сам, на этих кадрах
/// строится заново со всеми карточками, и на телефоне выезд клавиатуры дёргается. Здесь
/// перестраивается только сам отступ.
class AboveSystemBar extends StatelessWidget {
  const AboveSystemBar({super.key, required this.lift, this.child});

  final double lift;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: lift + MediaQuery.paddingOf(context).bottom),
    child: child,
  );
}
