import '../features/composer/picked_files.dart';

/// Что прислали через «Поделиться».
enum SharedKind { text, url, image, video, file }

class SharedPiece {
  const SharedPiece({required this.value, required this.kind, this.mime});

  /// Текст, адрес или путь к файлу.
  final String value;
  final SharedKind kind;
  final String? mime;
}

/// Присланное в один заход становится одной вещью: текст и ссылки — её текстом,
/// всё остальное — вложениями.
({String text, List<({String path, String mime})> files, bool isEmpty}) sharedToCapture(List<SharedPiece> pieces) {
  final lines = <String>[];
  final files = <({String path, String mime})>[];
  for (final piece in pieces) {
    switch (piece.kind) {
      case SharedKind.text || SharedKind.url:
        if (piece.value.trim().isNotEmpty) lines.add(piece.value.trim());
      case SharedKind.image || SharedKind.video || SharedKind.file:
        files.add((path: piece.value, mime: mimeFor(piece.value, hint: piece.mime)));
    }
  }
  final text = lines.join('\n');
  return (text: text, files: files, isEmpty: text.isEmpty && files.isEmpty);
}
