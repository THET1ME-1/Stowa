import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/document_text.dart';

List<int> zip(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return ZipEncoder().encode(archive);
}

void main() {
  test('Word: абзацы по порядку, разметка и сущности убраны', () {
    final docx = zip({
      'word/document.xml':
          '<w:document><w:body><w:p><w:r><w:t>Договор аренды</w:t></w:r></w:p>'
          '<w:p><w:r><w:t xml:space="preserve">Сумма: 500 </w:t></w:r><w:r><w:t>лей &amp; залог</w:t></w:r></w:p></w:body></w:document>',
    });
    final parts = documentText(docx, name: 'dogovor.docx');
    expect(parts.single.place, isNull);
    expect(parts.single.text, 'Договор аренды\nСумма: 500 лей & залог');
  });

  test('Excel: строки по листам, имя листа — место', () {
    final xlsx = zip({
      'xl/workbook.xml': '<workbook><sheets><sheet name="Бюджет" sheetId="1" r:id="rId1"/><sheet name="Итог" sheetId="2" r:id="rId2"/></sheets></workbook>',
      'xl/sharedStrings.xml': '<sst><si><t>Аренда</t></si><si><t>Еда</t></si><si><r><t>Всего</t></r></si></sst>',
      'xl/worksheets/sheet1.xml': '<worksheet><sheetData><row><c r="A1" t="s"><v>0</v></c><c r="B1"><v>500</v></c></row><row><c r="A2" t="s"><v>1</v></c><c r="B2" t="inlineStr"><is><t>много</t></is></c></row></sheetData></worksheet>',
      'xl/worksheets/sheet2.xml': '<worksheet><sheetData><row><c r="A1" t="s"><v>2</v></c></row></sheetData></worksheet>',
    });
    final parts = documentText(xlsx, name: 'budget.xlsx');
    expect(parts.map((part) => part.place), ['sheet:Бюджет', 'sheet:Итог']);
    expect(parts.first.text, 'Аренда 500\nЕда много');
    expect(parts.last.text, 'Всего');
  });

  test('PowerPoint: слайды по номеру, а не по имени файла', () {
    final pptx = zip({
      'ppt/slides/slide10.xml': '<p:sld><a:t>Десятый</a:t></p:sld>',
      'ppt/slides/slide2.xml': '<p:sld><a:p><a:t>Второй</a:t></a:p><a:p><a:t>слайд</a:t></a:p></p:sld>',
    });
    final parts = documentText(pptx, name: 'deck.pptx');
    expect(parts.map((part) => part.place), ['slide:2', 'slide:10']);
    expect(parts.first.text, 'Второй\nслайд');
  });

  test('OpenDocument и EPUB', () {
    final odt = zip({'content.xml': '<office:document-content><text:p>Заметка из LibreOffice</text:p><text:h>Глава</text:h></office:document-content>'});
    expect(documentText(odt, name: 'note.odt').single.text, 'Заметка из LibreOffice\nГлава');

    final epub = zip({
      'META-INF/container.xml': '<container><rootfiles><rootfile full-path="OEBPS/book.opf"/></rootfiles></container>',
      'OEBPS/book.opf': '<package><manifest><item id="c2" href="two.xhtml"/><item id="c1" href="one.xhtml"/></manifest><spine><itemref idref="c1"/><itemref idref="c2"/></spine></package>',
      'OEBPS/one.xhtml': '<html><head><title>x</title><style>p{}</style></head><body><p>Первая глава</p></body></html>',
      'OEBPS/two.xhtml': '<html><body><p>Вторая&nbsp;глава</p></body></html>',
    });
    final chapters = documentText(epub, name: 'book.epub');
    expect(chapters.map((part) => part.place), ['chapter:1', 'chapter:2']);
    expect(chapters.map((part) => part.text), ['Первая глава', 'Вторая глава']);
  });

  test('простой текст, CSV, JSON и HTML как есть', () {
    expect(documentText(utf8.encode('список: хлеб, сыр'), name: 'list.txt').single.text, 'список: хлеб, сыр');
    expect(documentText(utf8.encode('имя;сумма\nАня;300'), name: 'table.csv').single.text, 'имя;сумма\nАня;300');
    expect(documentText(utf8.encode('<html><script>var a=1;</script><body><h1>Заголовок</h1><p>Текст&#33;</p></body></html>'), name: 'page.html').single.text, 'Заголовок\nТекст!');
  });

  test('чужой формат или битый файл — пусто, без падения', () {
    expect(documentText([1, 2, 3], name: 'broken.docx'), isEmpty);
    expect(documentText([1, 2, 3], name: 'photo.jpg'), isEmpty);
  });

  test('огромный текст обрезается', () {
    final parts = documentText(utf8.encode('слово ' * 100000), name: 'big.txt');
    expect(parts.single.text.length, lessThanOrEqualTo(documentTextLimit));
  });
}
