import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/features/item/link_sheet.dart';

void main() {
  test('подпись заметки в листе связи — без разметки: галочки знаками, ссылки названиями', () {
    final target = (id: 'a', title: 'Дела', text: 'Дела\nСписок дел на неделю\n- [ ] позвонить в банк\n- [x] [[План отпуска]]', at: DateTime(2026, 11, 13), kind: ItemKind.note);
    expect(linkSnippet(target), 'Список дел на неделю ☐ позвонить в банк ☑ План отпуска');
  });

  test('только заголовок — подписи нет', () {
    expect(linkSnippet((id: 'b', title: 'Идеи', text: 'Идеи', at: DateTime(2026, 11, 13), kind: ItemKind.note)), isNull);
  });
}
