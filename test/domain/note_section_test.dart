import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/note_section.dart';

const _body = '''
Вступление.

## Покупки
- молоко
- хлеб

### Мелочи
- батарейки

## Ремонт
Покрасить стены. ^kraska

```
## не заголовок внутри кода
```
''';

void main() {
  test('раздел по заголовку: до следующего заголовка того же уровня, с подразделами', () {
    expect(noteSection(_body, '#Покупки'), '- молоко\n- хлеб\n\n### Мелочи\n- батарейки');
    expect(noteSection(_body, '#Мелочи'), '- батарейки');
    // путь заголовков, как пишет Obsidian: [[Заметка#Покупки#Мелочи]]
    expect(noteSection(_body, '#Покупки#Мелочи'), '- батарейки');
    // регистр и лишние пробелы не мешают
    expect(noteSection(_body, '# ремонт '), contains('Покрасить стены.'));
    // строка «## …» внутри кода — не заголовок
    expect(noteSection(_body, '#Ремонт'), contains('## не заголовок внутри кода'));
  });

  test('блок по ^метке — один абзац без самой метки; нет такого — весь текст', () {
    expect(noteSection(_body, '#^kraska'), 'Покрасить стены.');
    expect(noteSection(_body, '#Нет такого'), _body);
    expect(noteSection(_body, null), _body);
    expect(sectionTitle('#Покупки#Мелочи'), 'Мелочи');
    expect(sectionTitle('#^kraska'), isNull);
  });
}
