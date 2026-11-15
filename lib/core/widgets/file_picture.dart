import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SVG ли файл: по расширению, как и тип вложения.
bool isSvgPath(String path) => path.toLowerCase().endsWith('.svg');

/// Картинка из файла на экране. Растровую рисует `Image.file`, SVG — `flutter_svg`:
/// системный декодер векторную картинку не читает, и вместо неё была бы пустая плитка.
/// Параметры те же, что у `Image.file`, поэтому замена в любом месте — одно слово.
class FilePicture extends StatelessWidget {
  const FilePicture(
    this.file, {
    super.key,
    this.fit,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.alignment = Alignment.center,
    this.errorBuilder,
    this.frameBuilder,
  });

  final File file;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final AlignmentGeometry alignment;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageFrameBuilder? frameBuilder;

  @override
  Widget build(BuildContext context) {
    if (!isSvgPath(file.path)) {
      return Image.file(
        file,
        fit: fit,
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        alignment: alignment,
        errorBuilder: errorBuilder,
        frameBuilder: frameBuilder,
      );
    }
    final error = errorBuilder;
    final picture = SvgPicture.file(
      file,
      fit: fit ?? BoxFit.contain,
      width: width,
      height: height,
      alignment: alignment,
      errorBuilder: error == null ? null : (context, problem, stack) => error(context, problem, stack),
    );
    // у вектора нет кадров загрузки: отдаём готовый сразу
    return frameBuilder?.call(context, picture, 0, true) ?? picture;
  }
}
