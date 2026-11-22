import 'package:image_picker/image_picker.dart' show XFile;

/// Файлы, вставленные из буфера сочетанием Ctrl+V. Вне браузера картинки из буфера приходят
/// иначе (клавиатура телефона — через поле ввода), поэтому здесь поток пустой.
Stream<List<XFile>> pastedFilesStream() => const Stream.empty();
