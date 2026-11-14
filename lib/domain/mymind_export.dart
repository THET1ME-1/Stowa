import 'package:mime/mime.dart';

import 'imported_note.dart';

// названия столбцов mymind нигде не описаны: столбец узнаётся по любому из имён
const _titleNames = {'title', 'name'};
const _urlNames = {'url', 'link', 'source', 'source_url', 'sourceurl'};
const _textNames = {'content', 'text', 'note', 'notes', 'body', 'description', 'highlight', 'quote'};
const _tagNames = {'tags', 'tag', 'labels'};
const _dateNames = {'created', 'created_at', 'createdat', 'date', 'added', 'added_at'};

/// Карточки mymind из `cards.csv`: заголовок, адрес и текст — строками заметки, теги — тегами.
/// Ячейка, равная имени файла из папки выгрузки ([files]), — вложение. Без столбцов текста и
/// адреса — [FormatException]. Нет даты — [now].
List<ImportedNote> parseMymindCsv(String csv, {Set<String> files = const {}, DateTime? now}) {
  final rows = _rows(csv);
  if (rows.isEmpty) throw const FormatException('пустой файл');
  final header = [for (final cell in rows.first) cell.trim().toLowerCase().replaceAll(' ', '_')];
  List<int> columns(Set<String> names) => [
    for (final (index, name) in header.indexed)
      if (names.contains(name)) index,
  ];
  final titles = columns(_titleNames);
  final urls = columns(_urlNames);
  final texts = columns(_textNames);
  final tags = columns(_tagNames);
  final dates = columns(_dateNames);
  if (titles.isEmpty && urls.isEmpty && texts.isEmpty) throw const FormatException('нет столбцов текста и адреса');

  final notes = <ImportedNote>[];
  for (final row in rows.skip(1)) {
    String cell(int index) => index < row.length ? row[index].trim() : '';
    final lines = <String>[
      for (final index in [...titles, ...urls, ...texts])
        if (cell(index) case final value when value.isNotEmpty) value,
    ];
    final attached = [
      for (final value in row.map((value) => value.trim()))
        if (files.contains(value)) ExportedFile(path: value, mime: lookupMimeType(value) ?? 'application/octet-stream'),
    ];
    if (lines.isEmpty && attached.isEmpty) continue;
    final at = [for (final index in dates) DateTime.tryParse(cell(index))].nonNulls.firstOrNull;
    notes.add(
      ImportedNote(
        text: lines.toSet().join('\n'),
        files: attached,
        at: at ?? now ?? DateTime.now(),
        tags: [
          for (final index in tags)
            for (final tag in cell(index).split(RegExp('[,;]')))
              if (tag.trim().isNotEmpty) tag.trim(),
        ],
      ),
    );
  }
  return notes;
}

/// CSV по RFC 4180: ячейка в кавычках может держать запятые, переносы строк и `""`.
List<List<String>> _rows(String source) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  final text = source.startsWith('﻿') ? source.substring(1) : source;
  for (var index = 0; index < text.length; index++) {
    final char = text[index];
    if (quoted) {
      if (char != '"') {
        cell.write(char);
      } else if (index + 1 < text.length && text[index + 1] == '"') {
        cell.write('"');
        index++;
      } else {
        quoted = false;
      }
      continue;
    }
    switch (char) {
      case '"':
        quoted = true;
      case ',':
        row.add(cell.toString());
        cell.clear();
      case '\r':
        break;
      case '\n':
        row.add(cell.toString());
        cell.clear();
        if (row.any((value) => value.isNotEmpty)) rows.add(row);
        row = <String>[];
      default:
        cell.write(char);
    }
  }
  row.add(cell.toString());
  if (row.any((value) => value.isNotEmpty)) rows.add(row);
  return rows;
}
