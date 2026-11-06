import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/home/recent_strip.dart';

void main() {
  test('первая строка уходит из подписи, только когда она и есть заголовок', () {
    expect(notePreview('Борщ\nсвёкла\nкапуста', title: 'Борщ'), 'свёкла\nкапуста');
    // заголовок из имени файла Obsidian: первая строка — уже текст
    expect(notePreview('Заметка из Obsidian\n\nТекст снаружи.', title: 'Снаружи 3'), 'Заметка из Obsidian\nТекст снаружи.');
    expect(notePreview('Одна строка', title: 'Одна строка'), '');
  });
}
