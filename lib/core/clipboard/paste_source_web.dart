import 'dart:async';
import 'dart:js_interop';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:web/web.dart' as web;

import 'paste_router.dart' show pastedFileName;

/// Файлы, вставленные из буфера сочетанием Ctrl+V. Flutter в браузере берёт из буфера только
/// текст, поэтому картинку («Копировать картинку», снимок экрана, файл из проводника) ловим
/// сами — событием `paste` страницы. Оно приходит и с полем ввода в фокусе, и без него.
Stream<List<XFile>> pastedFilesStream() {
  late final StreamController<List<XFile>> out;
  JSFunction? listener;
  out = StreamController<List<XFile>>.broadcast(
    onListen: () {
      listener = ((web.ClipboardEvent event) => _onPaste(event, out)).toJS;
      web.document.addEventListener('paste', listener);
    },
    onCancel: () {
      if (listener case final listener?) web.document.removeEventListener('paste', listener);
      listener = null;
    },
  );
  return out.stream;
}

void _onPaste(web.ClipboardEvent event, StreamController<List<XFile>> out) {
  final data = event.clipboardData;
  if (data == null) return;
  // есть текст — это вставка текста: браузер вставит его в поле сам. Word, Excel и Google
  // Таблицы кладут рядом с текстом ещё и картинку выделения — её не берём
  if (data.getData('text/plain').trim().isNotEmpty) return;
  final files = [for (var index = 0; index < data.files.length; index++) data.files.item(index)!];
  // некоторые браузеры отдают картинку буфера только списком items
  if (files.isEmpty) {
    for (var index = 0; index < data.items.length; index++) {
      final item = data.items[index];
      if (item.kind == 'file') {
        if (item.getAsFile() case final file?) files.add(file);
      }
    }
  }
  if (files.isEmpty) return;
  // вставку забираем целиком: поле ввода не получит пустую строку
  event.preventDefault();
  final now = DateTime.now();
  () async {
    final pasted = <XFile>[];
    for (final file in files) {
      final bytes = (await file.arrayBuffer().toDart).toDart.asUint8List();
      pasted.add(XFile.fromData(bytes, name: pastedFileName(file.name, file.type, now), mimeType: file.type, length: bytes.length));
    }
    if (pasted.isNotEmpty && !out.isClosed) out.add(pasted);
  }();
}
