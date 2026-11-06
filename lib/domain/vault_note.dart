/// Вещь Stowa как файл `.md` в хранилище: свойства между `---`, текст,
/// вложения строками `![[путь]]` в конце. Тот же файл открывает Obsidian.
library;

import 'dart:convert';

import 'package:yaml/yaml.dart';

import 'inline_tags.dart';
import 'models.dart';
import 'tag_name.dart';

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

  /// Чужие свойства (Obsidian и другие): возвращаются в файл как были.
  final Map<String, Object?> extra;
}

const _known = {'id', 'kind', 'title', 'created', 'updated', 'tags', 'url', 'preview', 'cover', 'duration', 'reminder', 'place', 'remind_place', 'sorted_by'};

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
  void put(String key, Object? value) {
    if (value == null) return;
    if (value is String && value.isEmpty) return;
    if (value is List && value.isEmpty) return;
    if (value is Map && value.isEmpty) return;
    lines.add('$key: ${jsonEncode(value)}');
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
  for (final MapEntry(:key, :value) in note.extra.entries) {
    put(key, value);
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

  // хвост из строк ![[…]] — вложения, остальное — текст
  final lines = content.trimRight().split('\n');
  final attachments = <String>[];
  while (lines.isNotEmpty) {
    final match = _embed.firstMatch(lines.last.trim());
    if (match == null) break;
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
  final created = _parseTime(properties['created']) ?? fileModified;
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
