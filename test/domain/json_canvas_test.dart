import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/json_canvas.dart';

// файл, как его пишет Obsidian: табуляция, целые координаты, свои поля у узлов
const _obsidian = '''
{
	"nodes":[
		{"id":"a1b2c3d4e5f60718","type":"text","text":"# План\\nкупить плитку","x":-120,"y":-60,"width":250,"height":140,"color":"4"},
		{"id":"f00dfeedcafe0001","type":"file","file":"Дом/Ремонт кухни.md","x":200,"y":-60,"width":400,"height":400},
		{"id":"g1","type":"group","label":"Этап 1","x":-160,"y":-100,"width":800,"height":520,"background":"Дом/фон.png","backgroundStyle":"cover"},
		{"id":"l1","type":"link","url":"https://example.com/tile","x":-120,"y":120,"width":250,"height":100,"styleAttributes":{"shape":"pill"}}
	],
	"edges":[
		{"id":"e1","fromNode":"a1b2c3d4e5f60718","fromSide":"right","toNode":"f00dfeedcafe0001","toSide":"left","label":"см. заметку","color":"#ff8800"}
	],
	"metadata":{"version":"1.0-1.0"}
}''';

void main() {
  test('читает узлы всех видов, стрелку и цвета', () {
    final doc = CanvasDoc.parse(_obsidian);
    expect(doc.broken, isFalse);
    expect(doc.nodes.map((node) => node.type), [CanvasNodeType.text, CanvasNodeType.file, CanvasNodeType.group, CanvasNodeType.link]);
    final text = doc.nodes.first;
    expect(text.text, '# План\nкупить плитку');
    expect((text.x, text.y, text.width, text.height), (-120, -60, 250, 140));
    expect(text.color, '4');
    expect(doc.node('f00dfeedcafe0001')!.file, 'Дом/Ремонт кухни.md');
    expect(doc.node('g1')!.label, 'Этап 1');
    expect(doc.node('l1')!.url, 'https://example.com/tile');
    final edge = doc.edges.single;
    expect((edge.fromNode, edge.toNode, edge.fromSide, edge.toSide, edge.label), ('a1b2c3d4e5f60718', 'f00dfeedcafe0001', CanvasSide.right, CanvasSide.left, 'см. заметку'));
    expect(edge.toEnd, CanvasEnd.arrow);
    expect(edge.fromEnd, CanvasEnd.none);
  });

  test('правка не теряет чужих полей и порядка, файл — табуляцией и целыми числами', () {
    final doc = CanvasDoc.parse(_obsidian).moveNode('l1', 10.4, 20.6);
    final json = jsonDecode(doc.encode()) as Map<String, Object?>;
    expect(json['metadata'], {'version': '1.0-1.0'});
    final nodes = (json['nodes'] as List).cast<Map<String, Object?>>();
    expect(nodes.map((node) => node['id']), ['a1b2c3d4e5f60718', 'f00dfeedcafe0001', 'g1', 'l1']);
    expect(nodes.last['styleAttributes'], {'shape': 'pill'});
    expect((nodes.last['x'], nodes.last['y']), (-110, 141));
    expect(nodes[2]['backgroundStyle'], 'cover');
    expect(doc.encode(), contains('\n\t"nodes"'));
  });

  test('группа тянет с собой всё, что лежит внутри неё целиком', () {
    final doc = CanvasDoc.parse(_obsidian).moveNode('g1', 100, 0, withContents: true);
    expect(doc.node('g1')!.x, -60);
    expect(doc.node('a1b2c3d4e5f60718')!.x, -20);
    expect(doc.node('l1')!.x, -20);
    // заметка 200..600 по x внутри группы -160..640 — тоже едет
    expect(doc.node('f00dfeedcafe0001')!.x, 300);
  });

  test('удаление узла убирает и его стрелки', () {
    final doc = CanvasDoc.parse(_obsidian).removeNode('f00dfeedcafe0001');
    expect(doc.nodes, hasLength(3));
    expect(doc.edges, isEmpty);
  });

  test('новая карточка и стрелка получают id по 16 знаков, стрелка к себе не ставится', () {
    var doc = CanvasDoc.empty().addText('Мысль', x: 0, y: 0);
    doc = doc.addText('Вторая', x: 300, y: 0);
    final [first, second] = doc.nodes;
    expect(first.id, matches(RegExp(r'^[0-9a-f]{16}$')));
    doc = doc.connect(first.id, second.id);
    expect(doc.edges.single.fromSide, CanvasSide.right);
    expect(doc.edges.single.toSide, CanvasSide.left);
    expect(doc.connect(first.id, first.id).edges, hasLength(1));
  });

  test('текст для поиска: карточки, подписи групп и стрелок, имена файлов и адреса', () {
    final text = CanvasDoc.parse(_obsidian).plainText();
    expect(text, contains('купить плитку'));
    expect(text, contains('Этап 1'));
    expect(text, contains('см. заметку'));
    expect(text, contains('Ремонт кухни'));
    expect(text, contains('https://example.com/tile'));
  });

  test('битый файл не роняет: пустой холст с пометкой, пустой текст — тоже пустой холст', () {
    expect(CanvasDoc.parse('{"nodes": [').broken, isTrue);
    expect(CanvasDoc.parse('').nodes, isEmpty);
    expect(CanvasDoc.parse('').broken, isFalse);
    // узел без id или без чисел пропускается, остальное читается
    final doc = CanvasDoc.parse('{"nodes":[{"type":"text","text":"x"},{"id":"ok","type":"text","text":"y","x":0,"y":0,"width":10,"height":10}]}');
    expect(doc.nodes.single.id, 'ok');
  });

  test('цвета Obsidian: шесть готовых и свой', () {
    expect(canvasPresetKey('1'), 'coral');
    expect(canvasPresetKey('6'), 'violet');
    expect(canvasPresetKey('#ff0000'), isNull);
    expect(canvasHex('#ff8800'), 0xFFFF8800);
    expect(canvasHex('5'), isNull);
  });
}
