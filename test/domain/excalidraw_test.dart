import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/excalidraw.dart';

// Рисунок Excalidraw из Obsidian. Образец собран и сжат настоящей библиотекой lz-string:
// прямоугольник с подписью, круг, ромб пунктиром, изогнутая стрелка, линия точками,
// рисунок рукой, двухстрочная подпись, картинка и стёртый элемент
void main() {
  final sample = File('test/fixtures/excalidraw/Схема.excalidraw.md').readAsStringSync();

  test('рисунок узнаётся по свойству модуля, обычная заметка — нет', () {
    expect(isExcalidrawText(sample), isTrue);
    expect(isExcalidrawText('---\ntags: [excalidraw]\n---\nпросто заметка про excalidraw-plugin'), isFalse);
    expect(isExcalidrawText('excalidraw-plugin: parsed'), isFalse);
    expect(isExcalidrawText('---\r\nexcalidraw-plugin: raw\r\n---\r\n'), isTrue);
  });

  test('имя без «.excalidraw.md», id прежней Stowa из шапки', () {
    expect(excalidrawTitle('Схема.excalidraw.md'), 'Схема');
    expect(excalidrawTitle('План.md'), 'План');
    expect(excalidrawId(sample), '');
    expect(excalidrawId('---\nexcalidraw-plugin: parsed\nid: "abc-1"\n---\n'), 'abc-1');
  });

  test('подписи — без ключей ^…, многострочная целиком, картинки — номером к имени файла', () {
    expect(excalidrawTexts(sample), ['Вход', 'f(x) = x²\nвторая строка']);
    expect(excalidrawFiles(sample), {'594f0f1ae79f10b41e20df043b288b699b14feaf': 'Фото схемы.png'});
  });

  test('сцена распакована: все виды элементов, стёртый пропущен, цвета и точки на месте', () {
    final scene = parseExcalidraw(sample)!;
    expect(scene.elements.map((element) => element.type), ['rectangle', 'text', 'ellipse', 'diamond', 'arrow', 'line', 'freedraw', 'text', 'image']);
    expect(scene.background, 0xFFFFFCE8);
    final box = scene.elements.first;
    expect((box.fill, box.fillStyle, box.rounded, box.stroke), (0xFFA5D8FF, 'hachure', true, 0xFF1E1E1E));
    final arrow = scene.elements[4];
    expect(arrow.points, [(0.0, 0.0), (50.0, -20.0), (100.0, 0.0)]);
    expect((arrow.endArrowhead, arrow.startArrowhead, arrow.rounded), ('arrow', null, true));
    expect(scene.elements[3].strokeStyle, 'dashed');
    expect(scene.elements[2].fill, 0xFFFFC9C9);
    expect(scene.elements[1].fill, isNull);
    expect(scene.elements[7].fontFamily, 3);
    expect(scene.elements[8].fileId, '594f0f1ae79f10b41e20df043b288b699b14feaf');
    // стёртый квадрат на (5000, 5000) в рамку не попал
    final bounds = scene.bounds!;
    expect(bounds.left, -150);
    expect(bounds.right, lessThan(1000));
  });

  test('рисунок несжатым JSON тоже читается', () {
    const plain = '---\nexcalidraw-plugin: parsed\n---\n# Excalidraw Data\n## Text Elements\n%%\n## Drawing\n```json\n'
        '{"type":"excalidraw","elements":[{"type":"ellipse","x":1,"y":2,"width":3,"height":4,"strokeColor":"#f00"}],"appState":{}}\n```\n%%';
    final scene = parseExcalidraw(plain)!;
    expect(scene.elements.single.stroke, 0xFFFF0000);
    expect(scene.background, 0xFFFFFFFF);
  });

  test('битые данные — null, а не падение', () {
    expect(lzDecompressFromBase64(''), isNull);
    expect(lzDecompressFromBase64('не base64!'), isNull);
    expect(parseExcalidraw('---\nexcalidraw-plugin: parsed\n---\n## Drawing\n```compressed-json\nAAAA\n```'), isNull);
    expect(parseExcalidraw('---\nexcalidraw-plugin: parsed\n---\nбез рисунка'), isNull);
  });

  test('цвета: короткие, с прозрачностью, прозрачный, имя', () {
    expect(excalidrawColor('#abc'), 0xFFAABBCC);
    expect(excalidrawColor('#11223380'), 0x80112233);
    expect(excalidrawColor('transparent'), 0x00000000);
    expect(excalidrawColor('red'), 0xFFFF0000);
    expect(excalidrawColor('rgb(1,2,3)'), isNull);
  });
}
