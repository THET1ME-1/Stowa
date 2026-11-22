import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'paste_router.dart';

/// Картинка с клавиатуры телефона. Gboard и другие клавиатуры вставляют картинку из своего
/// буфера, стикер или GIF прямо в поле ввода (на Android — commitContent), без Ctrl+V; поле
/// должно сказать, что принимает картинки, иначе клавиатура пишет «вставка не поддерживается».
/// Картинка идёт туда же, куда вставка из буфера: место с полем в фокусе уже заявило себя
/// распределителю (текст заметки — на место курсора, строка — вложением).
///
/// [cache] — временная папка самого приложения: оттуда хранитель файлов переносит файл во
/// вложения, а не копирует, и он не остаётся мусором.
ContentInsertionConfiguration keyboardContent(PasteRouter router, {Directory? cache, DateTime Function() clock = DateTime.now}) {
  return ContentInsertionConfiguration(
    onContentInserted: (content) async {
      final bytes = content.data;
      if (bytes == null || bytes.isEmpty) return;
      // имени у картинки клавиатуры нет — по дате, как у фото: подпись «Фото от …»
      final name = pastedFileName('', content.mimeType, clock());
      final folder = Directory(p.join((cache ?? Directory.systemTemp).path, 'keyboard', const Uuid().v4()));
      await folder.create(recursive: true);
      final file = File(p.join(folder.path, name));
      await file.writeAsBytes(bytes, flush: true);
      await router.deliver([XFile(file.path, mimeType: content.mimeType, name: name)]);
    },
  );
}
