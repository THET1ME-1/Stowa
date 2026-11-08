import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/folder_tree.dart';

void main() {
  // Дом / Ремонт / Кухня, Дом / Сад, Работа
  final tree = FolderTree([
    const FolderNode(id: 'home', name: 'Дом'),
    const FolderNode(id: 'fix', name: 'Ремонт', parentId: 'home'),
    const FolderNode(id: 'kitchen', name: 'Кухня', parentId: 'fix'),
    const FolderNode(id: 'garden', name: 'Сад', parentId: 'home'),
    const FolderNode(id: 'work', name: 'Работа'),
  ]);

  test('путь, подпись пути и глубина', () {
    expect(tree.path('kitchen'), ['Дом', 'Ремонт', 'Кухня']);
    expect(tree.pathLabel('kitchen'), 'Дом / Ремонт / Кухня');
    expect(tree.parentsLabel('kitchen'), 'Дом / Ремонт');
    expect(tree.parentsLabel('home'), isNull);
    expect(tree.depth('home'), 1);
    expect(tree.depth('kitchen'), 3);
  });

  test('дети по порядку и все потомки', () {
    expect(tree.children('home').map((node) => node.id), ['fix', 'garden']);
    expect(tree.children(null).map((node) => node.id), ['home', 'work']);
    expect(tree.descendants('home'), {'fix', 'kitchen', 'garden'});
    expect(tree.descendants('kitchen'), isEmpty);
  });

  test('внутрь можно до третьего уровня', () {
    expect(tree.canNestInside('home'), isTrue);
    expect(tree.canNestInside('fix'), isTrue);
    expect(tree.canNestInside('kitchen'), isFalse);
  });

  test('переложить можно не в себя, не в потомка и не глубже трёх', () {
    // «Ремонт» с «Кухней» — два уровня: только в верхнюю папку или наверх
    expect(tree.canMoveInto('fix', 'work'), isTrue);
    expect(tree.canMoveInto('fix', null), isTrue);
    expect(tree.canMoveInto('fix', 'garden'), isFalse);
    expect(tree.canMoveInto('fix', 'fix'), isFalse);
    expect(tree.canMoveInto('home', 'kitchen'), isFalse);
    expect(tree.canMoveInto('work', 'kitchen'), isFalse);
    expect(tree.canMoveInto('work', 'fix'), isTrue);
  });

  test('петля в данных не вешает путь', () {
    final broken = FolderTree([const FolderNode(id: 'a', name: 'А', parentId: 'b'), const FolderNode(id: 'b', name: 'Б', parentId: 'a')]);
    expect(broken.path('a').length, lessThanOrEqualTo(2));
    expect(broken.depth('a'), lessThanOrEqualTo(2));
  });

  test('родитель, которого нет, — папка верхняя', () {
    final orphan = FolderTree([const FolderNode(id: 'a', name: 'А', parentId: 'gone')]);
    expect(orphan.path('a'), ['А']);
    expect(orphan.children(null).single.id, 'a');
  });
}
