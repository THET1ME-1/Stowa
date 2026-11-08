/// Текст из документов без движков: DOCX, XLSX, PPTX, ODT, ODS, ODP и EPUB — это
/// zip с XML внутри; TXT, MD, CSV, JSON, XML и HTML читаются как есть; PDF — свой
/// разбор текстового слоя (`pdf_text.dart`).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'pdf_text.dart';

/// Больше текста одной вещи поиску не нужно, а индекс не раздувается.
const documentTextLimit = 200000;

/// Кусок документа и где он: `sheet:Бюджет`, `slide:3`, `chapter:2`. Без места — весь документ.
class DocumentPart {
  const DocumentPart(this.text, {this.place});

  final String text;
  final String? place;
}

const _plain = {'txt', 'md', 'markdown', 'csv', 'tsv', 'json', 'log', 'ini', 'yaml', 'yml'};
const _markup = {'html', 'htm', 'xhtml', 'xml', 'svg'};
const _zipped = {'docx', 'xlsx', 'pptx', 'odt', 'ods', 'odp', 'epub'};

/// Читается ли текст файла с таким именем.
bool hasDocumentText(String name) {
  final extension = _extensionOf(name);
  return _plain.contains(extension) || _markup.contains(extension) || _zipped.contains(extension) || extension == 'pdf';
}

String _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

/// Текст документа по кускам. Чужой формат или битый файл — пусто.
List<DocumentPart> documentText(List<int> bytes, {required String name}) {
  final extension = _extensionOf(name);
  try {
    final parts = switch (extension) {
      _ when _plain.contains(extension) => [DocumentPart(_decode(bytes).trim())],
      _ when _markup.contains(extension) => [DocumentPart(_htmlText(_decode(bytes)))],
      'docx' => _docx(ZipDecoder().decodeBytes(bytes)),
      'xlsx' => _xlsx(ZipDecoder().decodeBytes(bytes)),
      'pptx' => _pptx(ZipDecoder().decodeBytes(bytes)),
      'odt' || 'ods' || 'odp' => _openDocument(ZipDecoder().decodeBytes(bytes)),
      'epub' => _epub(ZipDecoder().decodeBytes(bytes)),
      // текстовый слой по страницам; скан без текста — пусто
      'pdf' => [for (final (index, page) in pdfPages(Uint8List.fromList(bytes)).indexed) DocumentPart(page, place: 'page:${index + 1}')],
      _ => const <DocumentPart>[],
    };
    return _limited([for (final part in parts) if (part.text.isNotEmpty) part]);
  } catch (_) {
    // битый архив или кодировка: вещь остаётся, просто без текста файла
    return const [];
  }
}

List<DocumentPart> _limited(List<DocumentPart> parts) {
  var left = documentTextLimit;
  final kept = <DocumentPart>[];
  for (final part in parts) {
    if (left <= 0) break;
    final text = part.text.length > left ? part.text.substring(0, left) : part.text;
    kept.add(DocumentPart(text, place: part.place));
    left -= text.length;
  }
  return kept;
}

String _decode(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);

String? _file(Archive archive, String name) {
  final file = archive.findFile(name);
  return file == null ? null : _decode(file.content);
}

final _entity = RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos|nbsp);');

String _entities(String text) => text.replaceAllMapped(_entity, (match) {
  final name = match.group(1)!;
  if (name.startsWith('#x')) return String.fromCharCode(int.parse(name.substring(2), radix: 16));
  if (name.startsWith('#')) return String.fromCharCode(int.parse(name.substring(1)));
  return const {'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' '}[name]!;
});

// строки без лишних пробелов, пустые выброшены
String _lines(String text) => text
    .split('\n')
    .map((line) => line.replaceAll(RegExp(r'[ \t ]+'), ' ').trim())
    .where((line) => line.isNotEmpty)
    .join('\n');

final _tag = RegExp(r'<[^>]*>');

/// Тексты внутри тега: `<w:t>`, `<a:t>`, `<t>`, по порядку и вместе.
String _runs(String xml, String tag) => [
  for (final match in RegExp('<$tag(?:\\s[^>]*)?>(.*?)</$tag>', dotAll: true).allMatches(xml)) _entities(match.group(1)!.replaceAll(_tag, '')),
].join();

String _htmlText(String html) {
  final cleaned = html
      .replaceAll(RegExp(r'<(script|style|head)\b.*?</\1>', caseSensitive: false, dotAll: true), ' ')
      .replaceAll(RegExp(r'<(br|/p|/div|/h[1-6]|/li|/tr|/title|/section|/article)\b[^>]*>', caseSensitive: false), '\n')
      .replaceAll(_tag, ' ');
  return _lines(_entities(cleaned));
}

List<DocumentPart> _docx(Archive archive) {
  final xml = _file(archive, 'word/document.xml') ?? '';
  final paragraphs = [for (final paragraph in xml.split('</w:p>')) _runs(paragraph, 'w:t')];
  return [DocumentPart(_lines(paragraphs.join('\n')))];
}

List<DocumentPart> _xlsx(Archive archive) {
  final shared = [
    for (final match in RegExp(r'<si>(.*?)</si>', dotAll: true).allMatches(_file(archive, 'xl/sharedStrings.xml') ?? '')) _runs(match.group(1)!, 't'),
  ];
  final names = [for (final match in RegExp(r'<sheet\b[^>]*\bname="([^"]*)"').allMatches(_file(archive, 'xl/workbook.xml') ?? '')) _entities(match.group(1)!)];
  final parts = <DocumentPart>[];
  for (var index = 0; index < names.length; index++) {
    final sheet = _file(archive, 'xl/worksheets/sheet${index + 1}.xml');
    if (sheet == null) continue;
    final rows = <String>[];
    for (final row in RegExp(r'<row\b[^>]*>(.*?)</row>', dotAll: true).allMatches(sheet)) {
      final cells = <String>[];
      for (final cell in RegExp(r'<c\b([^>]*)>(.*?)</c>', dotAll: true).allMatches(row.group(1)!)) {
        final attributes = cell.group(1)!;
        final inner = cell.group(2)!;
        final value = RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(inner)?.group(1);
        if (attributes.contains('t="s"') && value != null) {
          final at = int.tryParse(value);
          if (at != null && at < shared.length) cells.add(shared[at]);
        } else if (attributes.contains('t="inlineStr"')) {
          cells.add(_runs(inner, 't'));
        } else if (value != null) {
          cells.add(_entities(value));
        }
      }
      rows.add(cells.join(' '));
    }
    parts.add(DocumentPart(_lines(rows.join('\n')), place: 'sheet:${names[index]}'));
  }
  return parts;
}

List<DocumentPart> _pptx(Archive archive) {
  final slide = RegExp(r'^ppt/slides/slide(\d+)\.xml$');
  final numbered = [
    for (final file in archive.files)
      if (slide.firstMatch(file.name) case final match?) (int.parse(match.group(1)!), _decode(file.content)),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [
    for (final (number, xml) in numbered) DocumentPart(_lines([for (final paragraph in xml.split('</a:p>')) _runs(paragraph, 'a:t')].join('\n')), place: 'slide:$number'),
  ];
}

List<DocumentPart> _openDocument(Archive archive) {
  final xml = (_file(archive, 'content.xml') ?? '').replaceAll(RegExp(r'</text:(p|h)>|</table:table-row>|<text:line-break/>'), '\n').replaceAll(RegExp(r'</table:table-cell>'), ' ');
  return [DocumentPart(_lines(_entities(xml.replaceAll(_tag, ''))))];
}

List<DocumentPart> _epub(Archive archive) {
  final opfPath = RegExp(r'full-path="([^"]+)"').firstMatch(_file(archive, 'META-INF/container.xml') ?? '')?.group(1);
  if (opfPath == null) return const [];
  final opf = _file(archive, opfPath) ?? '';
  final folder = opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1) : '';
  final hrefs = <String, String>{};
  for (final item in RegExp(r'<item\b[^>]*>').allMatches(opf)) {
    final tag = item.group(0)!;
    final id = RegExp(r'\bid="([^"]+)"').firstMatch(tag)?.group(1);
    final href = RegExp(r'\bhref="([^"]+)"').firstMatch(tag)?.group(1);
    if (id != null && href != null) hrefs[id] = href;
  }
  final parts = <DocumentPart>[];
  var chapter = 0;
  for (final ref in RegExp(r'<itemref\b[^>]*\bidref="([^"]+)"').allMatches(opf)) {
    final href = hrefs[ref.group(1)!];
    if (href == null) continue;
    final html = _file(archive, '$folder${Uri.decodeComponent(href)}');
    if (html == null) continue;
    final text = _htmlText(html);
    if (text.isEmpty) continue;
    chapter++;
    parts.add(DocumentPart(text, place: 'chapter:$chapter'));
  }
  return parts;
}
