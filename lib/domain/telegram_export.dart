import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
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
List<ExportedNote> parseTelegramExport(Object? json) => _notes([
  for (final raw in _savedMessages(json))
    if (raw is Map && raw['type'] == 'message') ?_Draft.of(raw),
]);

/// Выгрузка Telegram Desktop в HTML (так она выходит по умолчанию): страницы `messages.html`,
/// `messages2.html` … по порядку — заметки. Не страницы выгрузки — [FormatException].
List<ExportedNote> parseTelegramHtml(List<String> pages) {
  final drafts = <_Draft>[];
  var history = false;
  for (final page in pages) {
    final document = html.parse(page);
    if (document.querySelector('div.history') == null) continue;
    history = true;
    for (final message in document.querySelectorAll('div.message.default')) {
      if (_Draft.ofHtml(message) case final draft?) drafts.add(draft);
    }
  }
  if (!history) throw const FormatException('не выгрузка Telegram');
  return _notes(drafts);
}

// сообщения по порядку — заметки; альбом склеивается в одну
List<ExportedNote> _notes(List<_Draft> messages) {
  final notes = <ExportedNote>[];
  _Draft? album;
  void flush() {
    // сообщение из одного невыгруженного файла остаётся пустой записью: заметкой оно не станет, но в счёт пропавших файлов идёт
    if (album case final draft? when draft.isNotEmpty || draft.missing > 0) notes.add(draft.note());
    album = null;
  }

  for (final message in messages) {
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

  /// Сообщение со страницы HTML. Дата — из подсказки над временем, файлы — ссылки в блоке медиа.
  static _Draft? ofHtml(Element message) {
    final at = _htmlDate(message.querySelector('div.date.details')?.attributes['title'] ?? '');
    if (at == null) return null;
    final files = <ExportedFile>[];
    var missing = 0;
    for (final media in message.querySelectorAll('div.media_wrap > *')) {
      final classes = media.classes;
      // стикер — реакция, а не мысль
      if (classes.contains('sticker_wrap') || classes.contains('media_sticker')) continue;
      final href = media.localName == 'a' ? media.attributes['href'] ?? '' : '';
      if (href.isEmpty || href.contains(':') || href.startsWith('#')) {
        // блок без ссылки: файла в выгрузке нет; контакт, место и опрос файлами не бывают
        if (_fileKinds.any(classes.contains)) missing++;
        continue;
      }
      final status = media.querySelector('.status')?.text ?? '';
      files.add(ExportedFile(path: _decoded(href), mime: lookupMimeType(href) ?? 'application/octet-stream', seconds: _seconds(status)));
    }
    final forwarded = message.querySelector('div.forwarded.body');
    final textBlock = (forwarded ?? message).querySelector('div.text');
    final source = forwarded?.querySelector('.from_name')?.nodes.whereType<Text>().map((node) => node.data).join().trim();
    return _Draft(text: textBlock == null ? '' : _render(textBlock).trim(), files: files, at: at, source: source, missing: missing);
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

// блоки медиа, за которыми стоит файл: без ссылки — Telegram его не выгрузил
const _fileKinds = ['media_photo', 'media_video', 'media_file', 'media_voice_message', 'media_audio_file', 'media_video_message', 'media_animation'];

// «12.07.2024 22:24:21 GMT+02:00»: время человека в его поясе
final _htmlDatePattern = RegExp(r'(\d\d)\.(\d\d)\.(\d{4}) (\d\d):(\d\d):(\d\d)(?: (?:GMT|UTC)([+-])(\d\d):(\d\d))?');

DateTime? _htmlDate(String title) {
  final match = _htmlDatePattern.firstMatch(title);
  if (match == null) return null;
  int part(int index) => int.parse(match.group(index)!);
  final clock = DateTime.utc(part(3), part(2), part(1), part(4), part(5), part(6));
  if (match.group(7) == null) return DateTime(part(3), part(2), part(1), part(4), part(5), part(6));
  final offset = Duration(hours: part(8), minutes: part(9));
  return (match.group(7) == '+' ? clock.subtract(offset) : clock.add(offset)).toLocal();
}

// путь файла в ссылке бывает закодирован («%20»), а бывает как есть — с «%» в самом имени
String _decoded(String href) {
  try {
    return Uri.decodeFull(href);
  } on ArgumentError {
    return href;
  }
}

// «00:12, 40.0 KB» у голосового и ролика — длина
int? _seconds(String status) {
  final match = RegExp(r'^\s*(?:(\d+):)?(\d+):(\d\d)\b').firstMatch(status);
  if (match == null) return null;
  return int.parse(match.group(1) ?? '0') * 3600 + int.parse(match.group(2)!) * 60 + int.parse(match.group(3)!);
}

// текст сообщения со страницы — в разметку Stowa. Перенос строки у Telegram — <br>,
// переводы строк в самом HTML — только отступы вёрстки
String _render(Node node, {bool raw = false}) {
  if (node is Text) return raw ? node.data : node.data.replaceAll('\n', '');
  if (node is! Element) return '';
  final pre = raw || node.localName == 'pre';
  final inner = node.nodes.map((child) => _render(child, raw: pre)).join();
  switch (node.localName) {
    case 'br':
      return '\n';
    case 'strong' || 'b':
      return _wrap(inner, '**');
    case 'em' || 'i':
      return _wrap(inner, '_');
    case 's' || 'strike' || 'del':
      return _wrap(inner, '~~');
    case 'code' || 'pre':
      return _wrap(inner, '`');
    case 'blockquote':
      return inner.split('\n').map((line) => '> $line').join('\n');
    case 'a':
      final href = node.attributes['href'] ?? '';
      // хэштег, упоминание и эмодзи — ссылки без адреса, от них остаётся текст
      if (!href.contains(':')) return inner;
      return inner.trim() == href || href == 'mailto:${inner.trim()}' ? inner : '$inner ($href)';
    default:
      return inner;
  }
}

// пробелы по краям остаются снаружи: «** слово**» разметкой не считается
String _wrap(String text, String mark) {
  final core = text.trim();
  if (core.isEmpty) return text;
  final start = text.indexOf(core);
  return '${text.substring(0, start)}$mark$core$mark${text.substring(start + core.length)}';
}
