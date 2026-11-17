import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
    final picture = SvgPicture(
      _SvgFile(file),
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

/// SVG из файла хранилища. Свой загрузчик вместо `SvgPicture.file`: тот ждёт файл
/// `dart:io`, а в браузере файлы хранилища — свои, и читаются они не синхронно.
class _SvgFile extends SvgLoader<Uint8List> {
  const _SvgFile(this.file);

  final File file;

  @override
  Future<Uint8List?> prepareMessage(BuildContext? context) => file.readAsBytes();

  @override
  String provideSvg(Uint8List? message) => utf8.decode(message ?? Uint8List(0), allowMalformed: true);

  // как у SvgFileLoader: сравнение по самому файлу, а не по пути, иначе правка
  // картинки на том же месте показывала бы прежнюю из кэша
  @override
  int get hashCode => file.hashCode;

  @override
  bool operator ==(Object other) => other is _SvgFile && other.file == file;
}
