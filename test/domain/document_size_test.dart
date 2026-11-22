import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/document_size.dart';

List<int> _pdf(String page) => latin1.encode('%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n$page\nendobj\n%%EOF\n');

// документ на холсте встаёт в пропорциях своей страницы (хозяин 22.11: «документы — в своём размере»)
void main() {
  test('страница A4 — книжная', () {
    expect(pdfPageSize(_pdf('<< /Type /Page /MediaBox [0 0 595 842] >>')), (width: 595, height: 842));
  });

  test('страница повёрнута на 90 — альбомная, как её видят', () {
    expect(pdfPageSize(_pdf('<< /Type /Page /MediaBox [ 0 0 595.28 841.89 ] /Rotate 90 >>')), (width: 842, height: 595));
  });

  test('рамка не от нуля, отрицательные и дробные числа', () {
    expect(pdfPageSize(_pdf('<< /Type /Page /MediaBox [-10 -20.5 590 821.5] >>')), (width: 600, height: 842));
  });

  test('не PDF или без рамки страницы — null', () {
    expect(pdfPageSize(utf8.encode('просто текст')), isNull);
    expect(pdfPageSize(_pdf('<< /Type /Page >>')), isNull);
  });
}
