import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource, XFile;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/fs/web_files.dart' show webCacheDirectory;
import '../../core/platform.dart';
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
  return PickedFile(
    path: path,
    mime: mimeFor(path, hint: hint),
    size: await File(path).length(),
  );
}

final _images = ImagePicker();

/// Файл от галереи, выбора файлов или перетаскивания. С путём на диске — как есть; без него
/// (браузер: у файла только байты в памяти страницы) — байтами во временную папку приложения
/// под своим именем, дальше он идёт обычным путём вложения.
Future<PickedFile> pickedFromXFile(XFile file, {Directory? cache, bool? hasPath}) async {
  if (hasPath ?? (!isWeb && file.path.isNotEmpty)) return pickedFrom(file.path, hint: file.mimeType);
  // в браузере имя у файла есть, а путь — ссылка «blob:…» в память страницы
  final named = file.name.trim().isNotEmpty ? file.name : (file.path.isEmpty || file.path.startsWith('blob:') ? '' : file.path);
  var name = named.trim().isEmpty ? 'file' : p.basename(named);
  // картинка из буфера бывает без имени, а на компьютере XFile.fromData имя теряет: без
  // расширения Obsidian и сама Stowa не узнали бы в файле картинку — расширение по типу
  if (p.extension(name).isEmpty && file.mimeType != null) {
    if (extensionFromMime(file.mimeType!) case final extension? when extension.isNotEmpty) name = '$name.$extension';
  }
  final folder = Directory(p.join((cache ?? (isWeb ? webCacheDirectory : Directory.systemTemp)).path, 'picked', const Uuid().v4()));
  await folder.create(recursive: true);
  final target = File(p.join(folder.path, name));
  await target.writeAsBytes(await file.readAsBytes(), flush: true);
  return pickedFrom(target.path, hint: file.mimeType);
}

Future<List<PickedFile>> _fromXFiles(Iterable<XFile> files) {
  return Future.wait([for (final file in files) pickedFromXFile(file)]);
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
  return Future.wait([
    for (final file in files)
      if (file.path case final path? when !isWeb) pickedFrom(path) else pickedFromXFile(file.xFile),
  ]);
}
