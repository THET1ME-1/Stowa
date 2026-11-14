import 'telegram_export.dart' show ExportedFile;

export 'telegram_export.dart' show ExportedFile;

/// Будущая заметка из чужой выгрузки (Google Keep, закладки, Obsidian, mymind): текст в
/// разметке Stowa, файлы от папки выгрузки и дата, когда её написали там.
class ImportedNote {
  const ImportedNote({required this.text, this.title, this.files = const [], required this.at, this.tags = const [], this.pinned = false, this.folder = const []});

  final String text;

  /// Свой заголовок, когда в тексте его нет: название закладки, имя файла Obsidian.
  final String? title;
  final List<ExportedFile> files;
  final DateTime at;

  /// Ярлыки Keep, папка закладки, теги mymind.
  final List<String> tags;

  /// Закреплена там — закреплена и здесь.
  final bool pinned;

  /// Путь папки Obsidian от корня выгрузки: подпапки становятся папками Stowa.
  final List<String> folder;
}
