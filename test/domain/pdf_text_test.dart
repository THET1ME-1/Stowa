import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:stowa/domain/document_text.dart';
import 'package:stowa/domain/pdf_text.dart';

/// Объект PDF: словарь и, если есть, поток. Поток со [zip] сжимается, как у настоящих файлов.
class _Object {
  const _Object(this.dictionary, {this.stream, this.zip = false});

  final String dictionary;
  final List<int>? stream;
  final bool zip;
}

/// PDF с таблицей ссылок, как его пишут программы: объекты по номерам с первого.
Uint8List _pdf(List<_Object> objects, {String trailerExtra = '', int root = 1}) {
  final out = BytesBuilder()..add(latin1.encode('%PDF-1.5\n'));
  final offsets = <int>[];
  for (final (index, object) in objects.indexed) {
    offsets.add(out.length);
    var data = object.stream;
    var dictionary = object.dictionary;
    if (data != null) {
      if (object.zip) {
        data = const ZLibEncoder().encode(data);
        dictionary = dictionary.replaceFirst('<<', '<< /Filter /FlateDecode');
      }
      dictionary = dictionary.replaceFirst('<<', '<< /Length ${data.length}');
    }
    out.add(latin1.encode('${index + 1} 0 obj\n$dictionary\n'));
    if (data != null) {
      out
        ..add(latin1.encode('stream\n'))
        ..add(data)
        ..add(latin1.encode('\nendstream\n'));
    }
    out.add(latin1.encode('endobj\n'));
  }
  final xref = out.length;
  out.add(latin1.encode('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n'));
  for (final offset in offsets) {
    out.add(latin1.encode('${offset.toString().padLeft(10, '0')} 00000 n \n'));
  }
  out.add(latin1.encode('trailer\n<< /Size ${objects.length + 1} /Root $root 0 R $trailerExtra>>\nstartxref\n$xref\n%%EOF\n'));
  return out.toBytes();
}

List<int> _text(String content) => latin1.encode(content);

// каталог, страницы, одна страница со шрифтом Helvetica и потоком 4
List<_Object> _onePage(String content, {bool zip = false}) => [
  const _Object('<< /Type /Catalog /Pages 2 0 R >>'),
  const _Object('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
  const _Object('<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>'),
  _Object('<< >>', stream: _text(content), zip: zip),
  const _Object('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'),
];

void main() {
  test('простой шрифт: строки по сдвигу, скобки и восьмеричные коды в строке', () {
    final bytes = _pdf(_onePage(r'BT /F1 12 Tf 72 700 Td (Caf\351 \(test\)) Tj 0 -14 Td (Second line) Tj ET'));
    expect(pdfPages(bytes), ['Café (test)\nSecond line']);
  });

  test('сжатый поток и TJ с промежутками: крупный отступ — пробел', () {
    final bytes = _pdf(_onePage('BT /F1 12 Tf 72 700 Td [(Hel) -20 (lo) -400 (World)] TJ ET', zip: true));
    expect(pdfPages(bytes), ['Hello World']);
  });

  test('кириллица: составной шрифт Identity-H с таблицей ToUnicode, коды по два байта', () {
    const cmap = '''
/CIDInit /ProcSet findresource begin
12 dict begin
begincmap
1 begincodespacerange
<0000> <FFFF>
endcodespacerange
3 beginbfchar
<0001> <041F>
<0002> <0440>
<0003> <0020>
endbfchar
1 beginbfrange
<0004> <0006> <0438>
endbfrange
1 beginbfrange
<0010> <0011> [<043C> <0442>]
endbfrange
endcmap
CMapName currentdict /CMap defineresource pop
end
end''';
    final bytes = _pdf([
      const _Object('<< /Type /Catalog /Pages 2 0 R >>'),
      const _Object('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
      const _Object('<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>'),
      // «При» — 0001 0002 0004, пробел 0003, «мит» — 0010 0004 0011
      _Object('<< >>', stream: _text('BT /F1 12 Tf 72 700 Td <000100020004000300100004 0011> Tj ET'), zip: true),
      const _Object('<< /Type /Font /Subtype /Type0 /BaseFont /Onest /Encoding /Identity-H /ToUnicode 6 0 R >>'),
      _Object('<< >>', stream: _text(cmap), zip: true),
    ]);
    expect(pdfPages(bytes), ['При мит']);
  });

  test('страницы по порядку дерева, а не по номерам объектов; ресурсы наследуются от родителя', () {
    final bytes = _pdf([
      const _Object('<< /Type /Catalog /Pages 2 0 R >>'),
      const _Object('<< /Type /Pages /Kids [4 0 R 3 0 R] /Count 2 /Resources << /Font << /F1 7 0 R >> >> >>'),
      const _Object('<< /Type /Page /Parent 2 0 R /Contents 6 0 R >>'),
      const _Object('<< /Type /Page /Parent 2 0 R /Contents [5 0 R] >>'),
      _Object('<< >>', stream: _text('BT /F1 12 Tf (Page one) Tj ET')),
      _Object('<< >>', stream: _text('BT /F1 12 Tf (Page two) Tj ET')),
      const _Object('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'),
    ]);
    expect(pdfPages(bytes), ['Page one', 'Page two']);
  });

  test('объекты в сжатом потоке объектов (PDF 1.5) тоже читаются', () {
    // объекты 2, 3 и 5 лежат в потоке 6; ссылки и номера — как у Word и Chrome
    const packed = [
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    ];
    final header = StringBuffer();
    final body = StringBuffer();
    for (final (index, number) in [2, 3, 5].indexed) {
      header.write('$number ${body.length} ');
      body.write('${packed[index]}\n');
    }
    final first = header.length;
    final bytes = _pdf([
      const _Object('<< /Type /Catalog /Pages 2 0 R >>'),
      const _Object('<< /Type /Null >>'),
      const _Object('<< /Type /Null >>'),
      _Object('<< >>', stream: _text('BT /F1 12 Tf (Packed text) Tj ET'), zip: true),
      const _Object('<< /Type /Null >>'),
      _Object('<< /Type /ObjStm /N 3 /First $first >>', stream: _text('$header$body'), zip: true),
    ]);
    expect(pdfPages(bytes), ['Packed text']);
  });

  test('текст внутри формы (Do) со своими ресурсами, как у Chrome и TeX', () {
    final bytes = _pdf([
      const _Object('<< /Type /Catalog /Pages 2 0 R >>'),
      const _Object('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
      const _Object('<< /Type /Page /Parent 2 0 R /Resources << /XObject << /Fm1 5 0 R >> >> /Contents 4 0 R >>'),
      _Object('<< >>', stream: _text('q 1 0 0 1 0 0 cm /Fm1 Do Q')),
      _Object('<< /Type /XObject /Subtype /Form /BBox [0 0 600 800] /Resources << /Font << /F1 6 0 R >> >> >>', stream: _text('BT /F1 12 Tf (Inside form) Tj ET'), zip: true),
      const _Object('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'),
    ]);
    expect(pdfPages(bytes), ['Inside form']);
  });

  test('зашифрованный PDF и мусор — пусто, без ошибки', () {
    expect(pdfPages(_pdf(_onePage('BT /F1 12 Tf (Secret) Tj ET'), trailerExtra: '/Encrypt 9 0 R ')), isEmpty);
    expect(pdfPages(Uint8List.fromList(utf8.encode('not a pdf at all'))), isEmpty);
    expect(pdfPages(Uint8List(0)), isEmpty);
  });

  test('настоящий PDF с кириллицей: две страницы, текст ищется по страницам', () async {
    final font = pw.Font.ttf(File('assets/fonts/Onest.ttf').readAsBytesSync().buffer.asByteData());
    final document = pw.Document()
      ..addPage(pw.Page(pageFormat: pdf.PdfPageFormat.a4, build: (context) => pw.Text('Смета на ремонт кухни: плитка и клей', style: pw.TextStyle(font: font))))
      ..addPage(pw.Page(pageFormat: pdf.PdfPageFormat.a4, build: (context) => pw.Text('Итого 12 400 лей', style: pw.TextStyle(font: font))));
    final bytes = await document.save();
    final pages = pdfPages(bytes);
    expect(pages, hasLength(2));
    expect(pages.first, contains('Смета на ремонт кухни'));
    expect(pages.last, contains('Итого 12 400 лей'));

    final parts = documentText(bytes, name: 'Смета.pdf');
    expect([for (final part in parts) part.place], ['page:1', 'page:2']);
    expect(hasDocumentText('Смета.PDF'), isTrue);
  });
}
