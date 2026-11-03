import 'dart:convert';
import 'dart:math';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Длинная сторона картинки, которая уходит модели.
const aiImageSide = 1024;

/// Размер картинки для модели: длинная сторона не больше [aiImageSide], пропорции те же.
(int, int) aiImageSize(int? width, int? height) {
  if (width == null || height == null || width <= 0 || height <= 0) return (aiImageSide, aiImageSide);
  final scale = min(1.0, aiImageSide / max(width, height));
  return ((width * scale).round(), (height * scale).round());
}

/// JPEG качества 80 в base64. Сжимает система, поэтому даже снимок на 12 Мп
/// готов за доли секунды. Не вышло — null, вещь уйдёт модели без пикселей.
Future<String?> imageForAi(String path, {int? width, int? height}) async {
  final (targetWidth, targetHeight) = aiImageSize(width, height);
  try {
    final bytes = await FlutterImageCompress.compressWithFile(path, minWidth: targetWidth, minHeight: targetHeight, quality: 80);
    return bytes == null ? null : base64Encode(bytes);
  } catch (_) {
    return null;
  }
}
