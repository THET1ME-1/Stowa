import 'imported_note.dart';

/// Заметка Google Keep из Takeout (один `.json` на заметку). Корзина, пустая заметка и
/// чужой JSON — null.
ImportedNote? parseKeepNote(Map<Object?, Object?> json) {
  final created = json['createdTimestampUsec'] ?? json['userEditedTimestampUsec'];
  if (created is! num || json['isTrashed'] == true) return null;

  final title = _string(json['title']);
  final lines = <String>[
    if (title.isNotEmpty) title,
    if (_string(json['textContent']) case final text when text.isNotEmpty) text,
    // список Keep — пункты с галочками, как их пишет Stowa
    for (final item in _maps(json['listContent']))
      if (_string(item['text']) case final text when text.isNotEmpty) '- [${item['isChecked'] == true ? 'x' : ' '}] $text',
  ];
  // ссылка, к которой Keep сам нарисовал карточку, — строкой в конце, если её нет в тексте
  for (final annotation in _maps(json['annotations'])) {
    final url = _string(annotation['url']);
    if (url.isNotEmpty && !lines.any((line) => line.contains(url))) lines.add(url);
  }
  final files = [
    for (final attachment in _maps(json['attachments']))
      if (_string(attachment['filePath']) case final path when path.isNotEmpty)
        ExportedFile(path: path, mime: _string(attachment['mimetype']).isEmpty ? 'application/octet-stream' : _string(attachment['mimetype'])),
  ];
  final text = lines.join('\n').trim();
  if (text.isEmpty && files.isEmpty) return null;

  return ImportedNote(
    text: text,
    files: files,
    at: DateTime.fromMicrosecondsSinceEpoch(created.toInt()),
    tags: [
      for (final label in _maps(json['labels']))
        if (_string(label['name']) case final name when name.isNotEmpty) name,
    ],
    pinned: json['isPinned'] == true,
  );
}

String _string(Object? value) => value is String ? value.trim() : '';

Iterable<Map<Object?, Object?>> _maps(Object? value) => value is List ? value.whereType<Map<Object?, Object?>>() : const [];
