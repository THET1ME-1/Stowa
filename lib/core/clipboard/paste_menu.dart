import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'clipboard_images.dart';
import 'paste_router.dart';

/// Меню поля ввода по долгому нажатию на Android: «Вставить» вставляет и картинку из буфера —
/// туда же, куда Ctrl+V и клавиатура (текст заметки — на место курсора, строка — вложением).
/// В буфере текст — вставка текста, как была. В буфере одна картинка — Flutter «Вставить» не
/// показывает (ему нечего вставить), меню добавляет её само.
///
/// На других системах — меню Flutter как есть: на iPhone картинку вставляет клавиатура,
/// в браузере — событие вставки страницы.
EditableTextContextMenuBuilder pasteMenu(ClipboardImages images, PasteRouter router) {
  return (context, state) {
    if (defaultTargetPlatform != TargetPlatform.android) return AdaptiveTextSelectionToolbar.editableText(editableTextState: state);
    final items = [...state.contextMenuButtonItems];

    Future<void> paste(VoidCallback? text) async {
      state.hideToolbar();
      final image = await images.read();
      if (image == null) {
        text?.call();
        return;
      }
      await router.deliver([image]);
    }

    final index = items.indexWhere((item) => item.type == ContextMenuButtonType.paste);
    if (index >= 0) {
      final original = items[index];
      items[index] = original.copyWith(onPressed: () => paste(original.onPressed).ignore());
    } else if (images.ready.value && !state.widget.readOnly) {
      // «Вставить» — перед «Выделить всё», как у Flutter
      final at = items.indexWhere((item) => item.type == ContextMenuButtonType.selectAll);
      items.insert(at < 0 ? items.length : at, ContextMenuButtonItem(type: ContextMenuButtonType.paste, onPressed: () => paste(null).ignore()));
    }
    return AdaptiveTextSelectionToolbar.buttonItems(anchors: state.contextMenuAnchors, buttonItems: items);
  };
}
