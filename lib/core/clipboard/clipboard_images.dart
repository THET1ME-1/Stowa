import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:mime/mime.dart' show extensionFromMime;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../platform.dart' show isAndroid;
import 'paste_router.dart' show pastedFileName;

/// Картинка в буфере Android: «Копировать изображение» в Chrome, «Копировать» в галерее.
/// Flutter берёт из буфера только текст — картинку отдаёт канал `stowa/clipboard`.
/// Вне Android картинки буфера приходят иначе: в браузере — событием вставки страницы,
/// на iPhone — с клавиатуры.
class ClipboardImages {
  ClipboardImages({this.cache});

  /// Временная папка самого приложения: оттуда хранитель файлов переносит файл во вложения.
  final Directory? cache;

  static const _channel = MethodChannel('stowa/clipboard');

  /// Есть ли в буфере картинка. Смотрит только описание буфера, содержимое не читает —
  /// Android 12+ не показывает «Вставлено из буфера».
  Future<bool> has() async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasImage') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Есть ли картинка — по последней проверке ([refresh]): меню поля строится сразу и ждать
  /// ответа Android не может.
  final ready = ValueNotifier<bool>(false);

  /// Проверить буфер заново: поле получило фокус, человек вернулся в приложение.
  Future<void> refresh() async => ready.value = await has();

  /// Картинка из буфера файлом. В буфере текст или ничего — null.
  Future<XFile?> read() async {
    if (!isAndroid) return null;
    final Map<String, Object?>? answer;
    try {
      answer = await _channel.invokeMapMethod<String, Object?>('image');
    } catch (_) {
      return null;
    }
    final bytes = answer?['bytes'];
    final mime = answer?['mime'];
    if (bytes is! Uint8List || bytes.isEmpty || mime is! String) return null;
    // имя из галереи остаётся, безымянная картинка (Chrome) — по дате, как фото
    var name = pastedFileName(p.basename((answer?['name'] as String?) ?? ''), mime, DateTime.now());
    if (p.extension(name).isEmpty) {
      if (extensionFromMime(mime) case final extension? when extension.isNotEmpty) name = '$name.$extension';
    }
    final folder = Directory(p.join((cache ?? Directory.systemTemp).path, 'clipboard', const Uuid().v4()));
    await folder.create(recursive: true);
    final file = File(p.join(folder.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path, mimeType: mime, name: name);
  }
}
