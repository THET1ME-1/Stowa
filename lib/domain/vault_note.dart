/// Вещь Stowa как файл `.md` в хранилище: свойства между `---`, текст,
/// вложения строками `![[путь]]` в конце. Тот же файл открывает Obsidian.
library;

import 'dart:convert';

import 'package:yaml/yaml.dart';

import 'inline_tags.dart';
import 'models.dart';
import 'tag_name.dart';

/// Цитата статьи в файле: выделенный текст, пометка, когда выделена, где в статье.
class VaultHighlight {
  const VaultHighlight({required this.quote, required this.at, this.note, this.position = 0});

  final String quote;
  final String? note;
  final DateTime at;
  final int position;
}

/// Всё, что из вещи пишется в файл. Добытое сетью и ИИ лежит отдельно, в `.stowa/facts/`.
class VaultNote {
  const VaultNote({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.created,
    required this.updated,
    this.tags = const [],
    this.url,
    this.previewSite,
    this.previewAuthor,
    this.previewText,
    this.cover,
    this.durationSeconds,
    this.reminder,
    this.latitude,
    this.longitude,
    this.placeName,
    this.remindPlace,
    this.sortedBy,
    this.attachments = const [],
    this.highlights = const [],
    this.extra = const {},
  });

  /// Пустой — заметка написана снаружи (Obsidian) и ещё не стала вещью.
  final String id;
  final ItemKind kind;
  final String title;
  final String body;
  final DateTime created;
  final DateTime updated;
  final List<String> tags;
  final String? url;
  final String? previewSite;
  final String? previewAuthor;
  final String? previewText;

  /// Путь обложки от корня хранилища.
  final String? cover;
  final int? durationSeconds;
  final DateTime? reminder;
  final double? latitude;
  final double? longitude;
  final String? placeName;

  /// Напомнить по месту: дома, на работе, в магазине или в точке.
  final PlaceReminder? remindPlace;

  /// Кто положил в папку: ручное решение должно пережить переустановку.
  final SortedBy? sortedBy;

  /// Пути вложений от корня хранилища, по порядку.
  final List<String> attachments;

  /// Цитаты статьи: их выделил человек, поэтому они в файле, а не среди фактов.
  final List<VaultHighlight> highlights;

  /// Чужие свойства (Obsidian и другие): возвращаются в файл как были.
  final Map<String, Object?> extra;
}

const _known = {'id', 'kind', 'title', 'created', 'updated', 'tags', 'url', 'preview', 'cover', 'duration', 'reminder', 'place', 'remind_place', 'sorted_by', 'highlights'};

// символы, которые Android, Windows (через Syncthing) или Obsidian не пускают в имя
final _forbidden = RegExp(r'[/\\:*?"<>|#^\[\]\x00-\x1F]');

/// Имя файла из заголовка: без запрещённых символов и точек по краям,
/// не длиннее 200 байт UTF-8 (предел Android — 255), пустое — «Без названия».
String vaultFileName(String title) {
  var name = title.replaceAll(_forbidden, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  name = name.replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');
  final kept = StringBuffer();
  var bytes = 0;
  for (final rune in name.runes) {
    final char = String.fromCharCode(rune);
    bytes += utf8.encode(char).length;
    if (bytes > 200) break;
    kept.write(char);
  }
  name = kept.toString().replaceAll(RegExp(r'[.\s]+$'), '');
  return name.isEmpty ? 'Без названия' : name;
}

/// Текст файла. [fileName] — имя, под которым файл ляжет: заголовок пишется
/// свойством, только когда из имени его не вернуть.
String writeVaultNote(VaultNote note, {required String fileName}) {
  final lines = <String>[];
  // своё пустое свойство в файл не идёт
  void put(String key, Object? value) {
    if (value == null) return;
    if (value is String && value.isEmpty) return;
    if (value is List && value.isEmpty) return;
    if (value is Map && value.isEmpty) return;
    lines.addAll(vaultProperty(key, value));
  }

  final preview = <String, Object?>{'site': ?note.previewSite, 'author': ?note.previewAuthor, 'text': ?note.previewText};
  final place = <String, Object?>{'lat': ?note.latitude, 'lon': ?note.longitude, 'name': ?note.placeName};
  put('id', note.id);
  put('kind', note.kind.name);
  if (_stem(fileName) != note.title) put('title', note.title);
  put('created', _time(note.created));
  put('updated', _time(note.updated));
  put('tags', note.tags);
  put('url', note.url);
  put('preview', preview);
  put('cover', note.cover);
  put('duration', note.durationSeconds);
  put('reminder', note.reminder == null ? null : _time(note.reminder!));
  put('place', place);
  if (note.remindPlace case final remind?) {
    put('remind_place', <String, Object?>{'kind': remind.kind.name, 'lat': ?remind.latitude, 'lon': ?remind.longitude, 'name': ?remind.name});
  }
  if (note.sortedBy != null && note.sortedBy != SortedBy.none) put('sorted_by', note.sortedBy!.name);
  put('highlights', [
    for (final one in note.highlights) <String, Object?>{'quote': one.quote, 'note': ?one.note, 'at': _time(one.at), if (one.position != 0) 'pos': one.position},
  ]);
  // чужое возвращается и пустым: человек завёл свойство и ещё не заполнил
  for (final MapEntry(:key, :value) in note.extra.entries) {
    lines.addAll(vaultProperty(key, value));
  }

  final text = StringBuffer();
  if (lines.isNotEmpty) text.write('---\n${lines.join('\n')}\n---\n');
  final body = note.body.trimRight();
  if (body.isNotEmpty) text.write('$body\n');
  if (note.attachments.isNotEmpty) {
    if (body.isNotEmpty) text.write('\n');
    for (final path in note.attachments) {
      text.write('![[$path]]\n');
    }
  }
  return text.toString();
}

/// Строки одного свойства так, как их пишет Obsidian: список столбиком, вложенное
/// с отступом в два пробела, строка без кавычек, когда YAML прочтёт её строкой.
List<String> vaultProperty(String key, Object? value) {
  final lines = _entry(key, value, '');
  // страховка: блок, который читается не тем же значением, пишется прежним видом, в JSON
  try {
    final back = loadYaml(lines.join('\n'));
    if (back is YamlMap && back.length == 1 && back.containsKey(key) && _same(_plain(back[key]), value)) return lines;
  } on YamlException {
    // ниже запасной вид
  }
  try {
    return ['${jsonEncode(key)}: ${jsonEncode(value)}'];
  } on JsonUnsupportedObjectError {
    return const [];
  }
}

List<String> _entry(String key, Object? value, String pad) {
  final name = _scalar(key);
  if (value is Map && value.isNotEmpty) {
    return ['$pad$name:', for (final MapEntry(:key, :value) in value.entries) ..._entry('$key', value, '$pad  ')];
  }
  if (value is List && value.isNotEmpty) {
    return ['$pad$name:', for (final item in value) ..._listItem(item, '$pad  ')];
  }
  final text = _scalar(value);
  return [text.isEmpty ? '$pad$name:' : '$pad$name: $text'];
}

// пункт списка: вложенный блок начинается на строке с чёрточкой
List<String> _listItem(Object? item, String pad) {
  final nested = switch (item) {
    final Map<Object?, Object?> map when map.isNotEmpty => [for (final MapEntry(:key, :value) in map.entries) ..._entry('$key', value, '$pad  ')],
    final List<Object?> list when list.isNotEmpty => [for (final inner in list) ..._listItem(inner, '$pad  ')],
    _ => null,
  };
  if (nested != null) return ['$pad- ${nested.first.substring(pad.length + 2)}', ...nested.skip(1)];
  final text = _scalar(item);
  return [text.isEmpty ? '$pad-' : '$pad- $text'];
}

String _scalar(Object? value) => switch (value) {
  null => '',
  final String text => _readsAsText(text) ? text : jsonEncode(text),
  final double number when number.isNaN => '.nan',
  final double number when number.isInfinite => number.isNegative ? '-.inf' : '.inf',
  final num number => '$number',
  final bool flag => '$flag',
  List() => '[]',
  Map() => '{}',
  _ => jsonEncode('$value'),
};

// знаки, с которых в YAML начинается не строка, и слова с числами, которые он читает по-своему
final _yamlOpening = RegExp(r'''^[-?:,\[\]{}#&*!|>'"%@`~=<\s]''');
final _yamlBreak = RegExp(r'[\x00-\x1F\x7F\u0085\u2028\u2029\uFEFF]|: | #|[:\s]$');
final _yamlWord = RegExp(r'^(null|true|false|yes|no|on|off|y|n)$', caseSensitive: false);
final _yamlNumber = RegExp(
  r'^[-+]?(\.[0-9]+|[0-9][0-9_,]*(\.[0-9_]*)?)([eE][-+]?[0-9]+)?$'
  r'|^[-+]?0[xXoObB][0-9a-fA-F_]+$'
  r'|^[-+]?[0-9][0-9_]*(:[0-5]?[0-9])+(\.[0-9_]*)?$'
  r'|^[-+]?\.(inf|nan)$',
  caseSensitive: false,
);

bool _readsAsText(String text) =>
    text.isNotEmpty && !text.startsWith('...') && !_yamlOpening.hasMatch(text) && !_yamlBreak.hasMatch(text) && !_yamlWord.hasMatch(text) && !_yamlNumber.hasMatch(text);

bool _same(Object? left, Object? right) => switch ((left, right)) {
  (final Map<Object?, Object?> a, final Map<Object?, Object?> b) => a.length == b.length && a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key])),
  (final List<Object?> a, final List<Object?> b) => a.length == b.length && Iterable<int>.generate(a.length).every((index) => _same(a[index], b[index])),
  (final double a, final double b) when a.isNaN && b.isNaN => true,
  _ => left == right,
};

/// Чужие свойства одной строкой JSON для базы; свойств нет — null.
String? packVaultProperties(Map<String, Object?> extra) {
  if (extra.isEmpty) return null;
  // в JSON нет бесконечности и «не числа»: они уходят текстом, остальные свойства целы
  return jsonEncode(extra, toEncodable: (value) => value is double ? _scalar(value) : '$value');
}

/// Чужие свойства из базы; пустое и испорченное читается как «свойств нет».
Map<String, Object?> unpackVaultProperties(String? packed) {
  if (packed == null) return const {};
  try {
    final decoded = jsonDecode(packed);
    return decoded is Map<String, Object?> ? decoded : const {};
  } on FormatException {
    return const {};
  }
}

final _embed = RegExp(r'^!\[\[(.+)\]\]$');

/// Вещь из текста файла. Нет свойств (заметка Obsidian) — заголовок из имени,
/// время из [fileModified], `id` пустой.
VaultNote readVaultNote(String text, {required String fileName, required DateTime fileModified}) {
  var properties = const <String, Object?>{};
  var content = text.replaceAll('\r\n', '\n');
  if (content.startsWith('---\n')) {
    final end = RegExp(r'^---[ \t]*$', multiLine: true).firstMatch(content.substring(4));
    if (end != null) {
      try {
        final parsed = loadYaml(content.substring(4, 4 + end.start));
        if (parsed is Map) properties = {for (final MapEntry(:key, :value) in parsed.entries) '$key': _plain(value)};
        content = content.substring(4 + end.end).replaceFirst(RegExp(r'^\n'), '');
      } on YamlException {
        // свойства сломаны: текст важнее, файл читается целиком как текст
      }
    }
  }

  // хвост из строк ![[путь/…]] — вложения, остальное — текст. Хвост Stowa пишет путями
  // от корня, а картинку в тексте — коротким именем: та остаётся в тексте на своём месте
  final lines = content.trimRight().split('\n');
  final attachments = <String>[];
  while (lines.isNotEmpty) {
    final match = _embed.firstMatch(lines.last.trim());
    if (match == null || !match.group(1)!.contains('/')) break;
    attachments.insert(0, match.group(1)!);
    lines.removeLast();
  }
  final body = lines.join('\n').trimRight();

  String? stringOf(String key) => switch (properties[key]) {
    final String value when value.isNotEmpty => value,
    _ => null,
  };
  Map<String, Object?> map(String key) => switch (properties[key]) {
    final Map<String, Object?> value => value,
    _ => const {},
  };
  final preview = map('preview');
  final place = map('place');
  final remind = map('remind_place');
  final remindKind = PlaceReminderKind.values.asNameMap()[remind['kind']];
  final tags = <String>[];
  for (final tag in [..._tagList(properties['tags']), ...extractInlineTags(body)]) {
    final name = normalizeTagName(tag);
    if (name.isNotEmpty && !tags.contains(name)) tags.add(name);
  }
  // date из шаблонов Obsidian — день записи, только если он не позже самого файла: иначе это день события
  final dated = _parseTime(properties['date']);
  final created = _parseTime(properties['created']) ?? (dated != null && !dated.isAfter(fileModified) ? dated : fileModified);
  return VaultNote(
    id: stringOf('id') ?? '',
    kind: ItemKind.values.asNameMap()[stringOf('kind')] ?? ItemKind.note,
    title: stringOf('title') ?? _stem(fileName),
    body: body,
    created: created,
    updated: _parseTime(properties['updated']) ?? (properties.containsKey('created') ? created : fileModified),
    tags: tags,
    url: stringOf('url'),
    previewSite: preview['site'] as String?,
    previewAuthor: preview['author'] as String?,
    previewText: preview['text'] as String?,
    cover: stringOf('cover'),
    durationSeconds: (properties['duration'] as num?)?.round(),
    reminder: _parseTime(properties['reminder']),
    latitude: (place['lat'] as num?)?.toDouble(),
    longitude: (place['lon'] as num?)?.toDouble(),
    placeName: place['name'] as String?,
    remindPlace: remindKind == null
        ? null
        : PlaceReminder(remindKind, latitude: (remind['lat'] as num?)?.toDouble(), longitude: (remind['lon'] as num?)?.toDouble(), name: remind['name'] as String?),
    sortedBy: SortedBy.values.asNameMap()[stringOf('sorted_by')],
    attachments: attachments,
    highlights: [
      for (final one in (properties['highlights'] as List? ?? const []).whereType<Map<String, Object?>>())
        if (one['quote'] case final String quote when quote.isNotEmpty)
          VaultHighlight(quote: quote, note: one['note'] as String?, at: _parseTime(one['at']) ?? created, position: (one['pos'] as num?)?.round() ?? 0),
    ],
    extra: {for (final MapEntry(:key, :value) in properties.entries) if (!_known.contains(key)) key: value},
  );
}

String _stem(String fileName) => fileName.endsWith('.md') ? fileName.substring(0, fileName.length - 3) : fileName;

/// Время со сдвигом пояса, до миллисекунд: «2026-11-05T18:30:32.000+02:00».
String _time(DateTime at) {
  final local = at.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  String two(int value) => value.toString().padLeft(2, '0');
  final stamp = local.toIso8601String().replaceFirstMapped(RegExp(r'(\.\d{3})\d*$'), (match) => match.group(1)!);
  return '$stamp$sign${two(minutes ~/ 60)}:${two(minutes % 60)}';
}

DateTime? _parseTime(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value.trim())?.toLocal();
}

// Obsidian пишет теги и списком, и строкой через запятую или пробел
List<String> _tagList(Object? value) => switch (value) {
  final List<Object?> list => [for (final tag in list) if (tag != null) '$tag'],
  final String line => line.split(RegExp(r'[,\s]+')).where((tag) => tag.isNotEmpty).toList(),
  _ => const [],
};

// YamlMap и YamlList — в обычные Map и List, чтобы их можно было записать обратно
Object? _plain(Object? value) => switch (value) {
  final YamlMap map => {for (final MapEntry(:key, :value) in map.entries) '$key': _plain(value)},
  final YamlList list => [for (final item in list) _plain(item)],
  _ => value,
};
