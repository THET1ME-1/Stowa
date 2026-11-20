import 'package:flutter/widgets.dart';

/// Сливер, которому нужна ширина ленты: плитка решает по ней, сколько колонок.
///
/// [SliverLayoutBuilder] зовёт построитель на каждый кадр прокрутки: вместе с прокруткой
/// меняются и его ограничения. Плитка на сотни карточек тогда каждый кадр заново
/// раскладывает их по колонкам и перестраивает видимые, и прокрутка дёргается. Здесь
/// построенное запоминается и отдаётся тем же самым, пока не сменилась ширина или сам
/// виджет: Flutter такое поддерево не трогает. Потомки по-прежнему сами слушают тему и
/// провайдеры.
class SliverByWidth extends StatefulWidget {
  const SliverByWidth({super.key, required this.builder});

  final Widget Function(BuildContext context, double width) builder;

  @override
  State<SliverByWidth> createState() => _SliverByWidthState();
}

class _SliverByWidthState extends State<SliverByWidth> {
  double? _width;
  Widget? _built;

  @override
  void didUpdateWidget(SliverByWidth oldWidget) {
    super.didUpdateWidget(oldWidget);
    // новый построитель — новые карточки или настройки: строить заново
    _built = null;
  }

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.crossAxisExtent;
      if (_built case final built? when width == _width) return built;
      _width = width;
      return _built = widget.builder(context, width);
    },
  );
}
