import 'package:mime/mime.dart';

/// Файл сообщения: путь внутри папки выгрузки.
class ExportedFile {
  const ExportedFile({required this.path, required this.mime, this.seconds});

  final String path;
  final String mime;

  /// Длина голосового, ролика или кружка, если Telegram её записал.
  final int? seconds;
}

/// Будущая заметка из выгрузки: текст в разметке Stowa, файлы и дата сообщения.
class ExportedNote {
  const ExportedNote({required this.text, required this.files, required this.at, this.filesMissing = 0});

  final String text;
  final List<ExportedFile> files;
  final DateTime at;

  /// Файлы, которые Telegram не выгрузил: в настройках выгрузки они были выключены.
  final int filesMissing;
}

// альбом приходит сообщениями подряд, отправленными в одну секунду
const _albumGap = 1;

/// Выгрузка Telegram Desktop в JSON — заметки по порядку. Принимает выгрузку одного чата
/// и выгрузку всех данных (из неё берётся «Избранное»). Не выгрузка — [FormatException].
List<ExportedNote> parseTelegramExport(Object? json) {
  final messages = _savedMessages(json);
  final notes = <ExportedNote>[];
  _Draft? album;
  void flush() {
    if (album case final draft? when draft.isNotEmpty) notes.add(draft.note());
    album = null;
  }

  for (final raw in messages) {
    if (raw is! Map || raw['type'] != 'message') continue;
    final message = _Draft.of(raw);
    if (message == null) continue;
    final current = album;
    if (current != null && current.takes(message)) {
      current.add(message);
      continue;
    }
    flush();
    album = message;
  }
  flush();
  return notes;
}

List<Object?> _savedMessages(Object? json) {
  if (json is! Map) throw const FormatException('не выгрузка Telegram');
  if (json['messages'] case final List messages) return messages;
  final chats = json['chats'];
  if (chats is Map && chats['list'] is List) {
    for (final chat in chats['list'] as List) {
      if (chat is Map && chat['type'] == 'saved_messages' && chat['messages'] is List) return chat['messages'] as List;
    }
    return const [];
  }
  throw const FormatException('не выгрузка Telegram');
}

class _Draft {
  _Draft({required this.text, required this.files, required this.at, required this.source, required this.missing});

  String text;
  final List<ExportedFile> files;
  final DateTime at;
  final String? source;
  int missing;

  bool get isNotEmpty => text.trim().isNotEmpty || files.isNotEmpty;

  static _Draft? of(Map raw) {
    final unix = int.tryParse('${raw['date_unixtime'] ?? ''}');
    if (unix == null) return null;
    // стикер — реакция, а не мысль
    if (raw['media_type'] == 'sticker') return null;
    final files = <ExportedFile>[];
    var missing = 0;
    void take(Object? path, String? mime) {
      if (path is! String || path.isEmpty) return;
      if (path.startsWith('(')) {
        missing++;
        return;
      }
      files.add(ExportedFile(path: path, mime: mime ?? lookupMimeType(path) ?? 'application/octet-stream', seconds: (raw['duration_seconds'] as num?)?.toInt()));
    }

    take(raw['photo'], null);
    take(raw['file'], raw['mime_type'] as String?);
    return _Draft(
      text: _text(raw),
      files: files,
      at: DateTime.fromMillisecondsSinceEpoch(unix * 1000),
      source: raw['forwarded_from'] as String?,
      missing: missing,
    );
  }

  /// Следующее сообщение — часть того же альбома: оба с файлами, одна секунда,
  /// один источник пересылки, подпись не больше чем у одного.
  bool takes(_Draft next) =>
      files.isNotEmpty &&
      next.files.isNotEmpty &&
      next.at.difference(at).inSeconds.abs() <= _albumGap &&
      next.source == source &&
      (text.trim().isEmpty || next.text.trim().isEmpty);

  void add(_Draft next) {
    files.addAll(next.files);
    missing += next.missing;
    if (text.trim().isEmpty) text = next.text;
  }

  ExportedNote note() => ExportedNote(text: text.trim(), files: files, at: at, filesMissing: missing);
}

// текст сообщения в разметке Stowa: оформление Telegram лежит в text_entities
String _text(Map raw) {
  final entities = raw['text_entities'];
  if (entities is! List) {
    final text = raw['text'];
    return text is String ? text : '';
  }
  final out = StringBuffer();
  for (final entity in entities) {
    if (entity is! Map) continue;
    final text = '${entity['text'] ?? ''}';
    out.write(switch (entity['type']) {
      'bold' => _wrap(text, '**'),
      'italic' => _wrap(text, '_'),
      'strikethrough' => _wrap(text, '~~'),
      'code' || 'pre' => _wrap(text, '`'),
      'text_link' when entity['href'] is String && entity['href'] != text => '$text (${entity['href']})',
      _ => text,
    });
  }
  return out.toString();
}

// пробелы по краям остаются снаружи: «** слово**» разметкой не считается
String _wrap(String text, String mark) {
  final core = text.trim();
  if (core.isEmpty) return text;
  final start = text.indexOf(core);
  return '${text.substring(0, start)}$mark$core$mark${text.substring(start + core.length)}';
}
