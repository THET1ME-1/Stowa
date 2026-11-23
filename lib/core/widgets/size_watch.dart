import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Сообщает размер, который получил [child], и ничего не перестраивает.
///
/// [LayoutBuilder] строит своё поддерево заново на каждую смену размера, а размер окна меняется
/// на каждом кадре выезда клавиатуры. Холст в LayoutBuilder строился заново со всеми карточками
/// каждый кадр. Здесь размер только раскладывается и передаётся в [onSize] после раскладки.
class SizeWatch extends SingleChildRenderObjectWidget {
  const SizeWatch({super.key, required this.onSize, super.child});

  /// Зовётся на раскладке, когда размер сменился: только запомнить, не перестраивать.
  final ValueChanged<Size> onSize;

  @override
  RenderSizeWatch createRenderObject(BuildContext context) => RenderSizeWatch(onSize);

  @override
  void updateRenderObject(BuildContext context, RenderSizeWatch renderObject) => renderObject.onSize = onSize;
}

class RenderSizeWatch extends RenderProxyBox {
  RenderSizeWatch(this.onSize);

  ValueChanged<Size> onSize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reported) return;
    _reported = size;
    onSize(size);
  }
}
