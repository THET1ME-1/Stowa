/// Папки деревом: путь «Дом / Ремонт / Кухня», глубина, дети, куда можно переложить.
/// Чистые правила без базы: их же зовут экраны, писатель хранилища и ИИ.
library;

/// Своими руками папки вкладываются до трёх уровней. Из файлов читается любая глубина.
const maxFolderDepth = 3;

class FolderNode {
  const FolderNode({required this.id, required this.name, this.parentId});

  final String id;
  final String name;

  /// Родитель; null — папка верхняя.
  final String? parentId;
}

class FolderTree {
  /// [nodes] — в том порядке, в каком папки показываются: дети идут в нём же.
  FolderTree(List<FolderNode> nodes) : _byId = {for (final node in nodes) node.id: node}, _order = nodes;

  final Map<String, FolderNode> _byId;
  final List<FolderNode> _order;

  FolderNode? operator [](String id) => _byId[id];

  /// Родитель, который есть в дереве; потерянный родитель делает папку верхней.
  String? parentOf(String id) {
    final parent = _byId[id]?.parentId;
    return parent != null && _byId.containsKey(parent) ? parent : null;
  }

  /// Цепочка id от верхней папки до этой. Петля в данных обрывается.
  List<String> chain(String id) {
    final ids = <String>[];
    String? current = _byId.containsKey(id) ? id : null;
    while (current != null && !ids.contains(current)) {
      ids.insert(0, current);
      current = parentOf(current);
    }
    return ids;
  }

  List<String> path(String id) => [for (final one in chain(id)) _byId[one]!.name];

  String pathLabel(String id) => path(id).join(' / ');

  /// Родители через «/»; у верхней папки — null.
  String? parentsLabel(String id) {
    final names = path(id);
    return names.length < 2 ? null : names.sublist(0, names.length - 1).join(' / ');
  }

  int depth(String id) => chain(id).length;

  List<FolderNode> children(String? parentId) => [
    for (final node in _order)
      if (parentOf(node.id) == parentId) node,
  ];

  Set<String> descendants(String id) {
    final found = <String>{};
    final queue = [id];
    while (queue.isNotEmpty) {
      for (final child in children(queue.removeLast())) {
        if (child.id != id && found.add(child.id)) queue.add(child.id);
      }
    }
    return found;
  }

  bool canNestInside(String id) => depth(id) < maxFolderDepth;

  /// Сколько уровней занимает папка со своими вложенными: одна — 1.
  int height(String id) {
    final base = depth(id);
    var deepest = base;
    for (final one in descendants(id)) {
      final level = depth(one);
      if (level > deepest) deepest = level;
    }
    return deepest - base + 1;
  }

  /// Папку [moving] можно положить в [target] (null — наверх).
  bool canMoveInto(String moving, String? target) {
    if (target == null) return height(moving) <= maxFolderDepth;
    if (target == moving || descendants(moving).contains(target)) return false;
    return depth(target) + height(moving) <= maxFolderDepth;
  }
}
