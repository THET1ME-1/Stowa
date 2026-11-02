import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource, XFile;
import 'package:mime/mime.dart';

import '../../services/capture_service.dart';

const _unknownMime = 'application/octet-stream';

/// Тип файла по расширению, иначе по подсказке системы. Незнакомый формат
/// тоже принимается: вещь ляжет файлом, а не потеряется.
String mimeFor(String path, {String? hint}) {
  final byName = lookupMimeType(path);
  if (byName != null) return byName;
  if (hint != null && hint.contains('/')) return hint;
  return _unknownMime;
}

Future<PickedFile> pickedFrom(String path, {String? hint}) async {
  return PickedFile(path: path, mime: mimeFor(path, hint: hint), size: await File(path).length());
}

final _images = ImagePicker();

Future<List<PickedFile>> _fromXFiles(Iterable<XFile> files) {
  return Future.wait([for (final file in files) pickedFrom(file.path, hint: file.mimeType)]);
}

/// Фото и видео из галереи, сразу несколько.
Future<List<PickedFile>> pickGalleryMedia() async => _fromXFiles(await _images.pickMultipleMedia());

Future<List<PickedFile>> pickCameraPhoto() async {
  final photo = await _images.pickImage(source: ImageSource.camera);
  return photo == null ? const [] : _fromXFiles([photo]);
}

Future<List<PickedFile>> pickCameraVideo() async {
  final video = await _images.pickVideo(source: ImageSource.camera);
  return video == null ? const [] : _fromXFiles([video]);
}

/// Любые файлы: документы, текст, архивы, всё, что даст система.
Future<List<PickedFile>> pickAnyFiles() async {
  final files = await FilePicker.pickFiles();
  final paths = [for (final file in files) file.path].nonNulls;
  return Future.wait([for (final path in paths) pickedFrom(path)]);
}
