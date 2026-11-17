import 'dart:convert';

/// Что открыто во вкладке: главная, заметка, папка, настройки и т. д.
class WsTab {
  const WsTab._(this.kind, [this.id]);

  const WsTab.home() : this._('home');

  /// Всё без папки.
  const WsTab.inbox() : this._('inbox');

  const WsTab.folder(String id) : this._('folder', id);

  const WsTab.item(String id) : this._('item', id);

  /// Настройки; [section] — открытый раздел.
  const WsTab.settings([String? section]) : this._('settings', section);

  const WsTab.map() : this._('map');

  const WsTab.graph() : this._('graph');

  /// «Посмотреть потом».
  const WsTab.later() : this._('later');

  final String kind;
  final String? id;

  /// Одна заметка — одна вкладка на всё пространство: два редактора писали бы один файл.
  /// Настройки тоже одни, раздел внутри них не делает их другой вкладкой.
  String get key => kind == 'settings' ? 'settings' : '$kind:${id ?? ''}';

  static WsTab? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = json['k'];
    if (kind is! String) return null;
    return WsTab._(kind, json['i'] as String?);
  }

  Map<String, Object?> toJson() => {'k': kind, if (id != null) 'i': id};

  @override
  bool operator ==(Object other) => other is WsTab && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'WsTab($kind${id == null ? '' : ', $id'})';
}

/// Окно центра: свои вкладки и открытая из них.
class WsPane {
  WsPane(this.id, List<WsTab> tabs, [this.active = 0]) : tabs = [...tabs];

  final String id;
  final List<WsTab> tabs;
  int active;

  WsTab? get activeTab => tabs.isEmpty ? null : tabs[active.clamp(0, tabs.length - 1)];
}

/// Деление центра: вправо (row) или вниз (column).
enum WsAxis { row, column }

sealed class WsNode {}

class WsLeaf extends WsNode {
  WsLeaf(this.paneId);

  final String paneId;
}

class WsSplit extends WsNode {
  WsSplit(this.axis, this.children, this.ratios);

  final WsAxis axis;
  final List<WsNode> children;

  /// Доля каждого ребёнка, в сумме 1.
  final List<double> ratios;
}

/// Куда бросили вкладку на окне: в само окно или к краю — тогда окно делится в ту сторону.
enum WsDrop { center, left, right, top, bottom }

/// Рабочее пространство широкого экрана, как в Obsidian и Blender: левый док, центр
/// из окон с вкладками, правый док. Только состояние, без виджетов: его легко проверить
/// и сохранить между запусками.
class Workspace {
  Workspace._(this.root, this._panes, this.focusedId);

  factory Workspace.initial() {
    final pane = WsPane('p1', const [WsTab.home()]);
    return Workspace._(WsLeaf(pane.id), {pane.id: pane}, pane.id);
  }

  WsNode root;
  final Map<String, WsPane> _panes;
  String focusedId;
  bool leftOpen = true;
  bool rightOpen = true;
  double leftWidth = 296;
  double rightWidth = 320;

  /// Свёрнутые панели доков.
  final Set<String> collapsed = {};

  /// Все панели доков; какие где — [left] и [right], остальные убраны.
  static const allPanels = ['sections', 'pinned', 'folders', 'later', 'yearAgo', 'sync'];

  final List<String> left = ['sections', 'pinned', 'folders'];
  final List<String> right = ['later', 'yearAgo', 'sync'];

  /// Убранные панели: их возвращает «+ Панель».
  List<String> get hiddenPanels => [for (final id in allPanels) if (!left.contains(id) && !right.contains(id)) id];

  void hidePanel(String id) {
    left.remove(id);
    right.remove(id);
  }

  /// Поставить панель в док на место [index] (считая без неё самой): перетаскивание,
  /// перенос в другой док и возврат убранной.
  void placePanel(String id, {required bool left, required int index}) {
    final target = left ? this.left : right;
    final from = target.indexOf(id);
    hidePanel(id);
    // внутри того же дока места после неё сдвигаются на одно
    final at = from >= 0 && from < index ? index - 1 : index;
    target.insert(at.clamp(0, target.length), id);
  }

  int _next = 2;

  /// Окна по порядку дерева: слева направо, сверху вниз.
  List<WsPane> get panes => [for (final id in _leaves(root)) _panes[id]!];

  WsPane get focusedPane => _panes[focusedId]!;

  WsPane pane(String id) => _panes[id]!;

  static Iterable<String> _leaves(WsNode node) sync* {
    switch (node) {
      case WsLeaf(:final paneId):
        yield paneId;
      case WsSplit(:final children):
        for (final child in children) {
          yield* _leaves(child);
        }
    }
  }

  String _newId() {
    while (_panes.containsKey('p$_next')) {
      _next++;
    }
    return 'p${_next++}';
  }

  // чем заполнить новое окно: то, чего ещё нет на экране, главная — первой
  static const _fillers = [WsTab.home(), WsTab.inbox(), WsTab.later(), WsTab.map(), WsTab.graph()];

  WsTab _filler() {
    final open = {for (final pane in _panes.values) ...pane.tabs.map((tab) => tab.key)};
    return _fillers.firstWhere((tab) => !open.contains(tab.key), orElse: () => const WsTab.home());
  }

  /// Открыть [tab]. Уже открыта где-то — фокус туда (у настроек меняется раздел).
  /// Иначе — новой вкладкой рядом с открытой в окне [paneId] (по умолчанию в окне с фокусом).
  void open(WsTab tab, {String? paneId}) {
    for (final pane in _panes.values) {
      final index = pane.tabs.indexWhere((other) => other.key == tab.key);
      if (index < 0) continue;
      pane.tabs[index] = tab;
      pane.active = index;
      focusedId = pane.id;
      return;
    }
    final target = _panes[paneId ?? focusedId]!;
    final at = target.tabs.isEmpty ? 0 : target.active + 1;
    target.tabs.insert(at, tab);
    target.active = at;
    focusedId = target.id;
  }

  /// Заменить открытую вкладку окна (переход внутри вкладки, как ссылка в той же вкладке).
  void replace(String paneId, WsTab tab) {
    final pane = _panes[paneId]!;
    final existing = pane.tabs.indexWhere((other) => other.key == tab.key);
    if (existing >= 0 || pane.tabs.isEmpty) return open(tab, paneId: paneId);
    final elsewhere = _panes.values.any((other) => other.id != paneId && other.tabs.any((t) => t.key == tab.key));
    if (elsewhere) return open(tab);
    pane.tabs[pane.active] = tab;
    focusedId = paneId;
  }

  void activate(String paneId, int index) {
    final pane = _panes[paneId]!;
    pane.active = index.clamp(0, pane.tabs.length - 1);
    focusedId = paneId;
  }

  void focus(String paneId) {
    if (_panes.containsKey(paneId)) focusedId = paneId;
  }

  /// Закрыть вкладку. Пустое окно уходит, последнее окно получает главную.
  void close(String paneId, int index) {
    final pane = _panes[paneId]!;
    pane.tabs.removeAt(index);
    if (pane.active >= pane.tabs.length || pane.active > index) pane.active = (pane.active - 1).clamp(0, 1 << 20);
    if (pane.tabs.isNotEmpty) return;
    if (_panes.length == 1) {
      pane.tabs.add(const WsTab.home());
      pane.active = 0;
      return;
    }
    _removeLeaf(paneId);
  }

  void _removeLeaf(String paneId) {
    _panes.remove(paneId);
    root = _without(root, paneId)!;
    if (!_panes.containsKey(focusedId)) focusedId = _leaves(root).first;
  }

  WsNode? _without(WsNode node, String paneId) {
    switch (node) {
      case WsLeaf():
        return node.paneId == paneId ? null : node;
      case WsSplit(:final axis, :final children, :final ratios):
        final kept = <WsNode>[];
        final keptRatios = <double>[];
        for (var i = 0; i < children.length; i++) {
          final child = _without(children[i], paneId);
          if (child != null) {
            kept.add(child);
            keptRatios.add(ratios[i]);
          }
        }
        if (kept.isEmpty) return null;
        if (kept.length == 1) return kept.single;
        final sum = keptRatios.reduce((a, b) => a + b);
        return WsSplit(axis, kept, [for (final ratio in keptRatios) ratio / sum]);
    }
  }

  /// Разделить окно [paneId] вправо или вниз; новое окно получает фокус.
  void split(String paneId, WsAxis axis) {
    final pane = WsPane(_newId(), [_filler()]);
    _panes[pane.id] = pane;
    root = _splitAt(root, paneId, axis, pane.id);
    focusedId = pane.id;
  }

  WsNode _splitAt(WsNode node, String paneId, WsAxis axis, String added) {
    switch (node) {
      case WsLeaf():
        return node.paneId == paneId ? WsSplit(axis, [node, WsLeaf(added)], [0.5, 0.5]) : node;
      case WsSplit():
        final index = node.children.indexWhere((child) => child is WsLeaf && child.paneId == paneId);
        // соседнее окно в том же направлении — в тот же ряд, доли поровну
        if (index >= 0 && node.axis == axis) {
          final children = [...node.children]..insert(index + 1, WsLeaf(added));
          return WsSplit(axis, children, List.filled(children.length, 1 / children.length));
        }
        return WsSplit(node.axis, [for (final child in node.children) _splitAt(child, paneId, axis, added)], node.ratios);
    }
  }

  /// Потянули границу между [index] и следующим ребёнком: [index] получает [ratio] от их пары.
  /// Окно не ужимается меньше 15% пары: иначе его не найти и не вытянуть обратно.
  void resize(WsSplit split, int index, double ratio) {
    final pair = split.ratios[index] + split.ratios[index + 1];
    final first = ratio.clamp(0.15, 0.85) * pair;
    split.ratios[index] = first;
    split.ratios[index + 1] = pair - first;
  }

  // вынуть вкладку из окна, открытой остаётся соседняя
  WsTab _take(WsPane pane, int index) {
    final tab = pane.tabs.removeAt(index);
    if (pane.active > index || pane.active >= pane.tabs.length) pane.active = (pane.active - 1).clamp(0, 1 << 20);
    return tab;
  }

  /// Вкладку номер [index] окна [fromId] перетащили на окно [toId]. В середину — она
  /// переезжает в это окно (на место [at], если бросили на полосу вкладок); к краю —
  /// окно делится в ту сторону, и вкладка встаёт новым окном. Так человек сам собирает
  /// раскладку: готовых нет.
  void drop(String fromId, int index, String toId, WsDrop where, {int? at}) {
    final from = _panes[fromId]!;
    final to = _panes[toId]!;
    if (where == WsDrop.center) {
      if (fromId == toId) {
        if (at == null) return;
        final tab = _take(from, index);
        final place = (at > index ? at - 1 : at).clamp(0, from.tabs.length);
        from.tabs.insert(place, tab);
        from.active = place;
        focusedId = fromId;
        return;
      }
      final tab = _take(from, index);
      final place = (at ?? to.active + 1).clamp(0, to.tabs.length);
      to.tabs.insert(place, tab);
      to.active = place;
      focusedId = toId;
    } else {
      // единственную вкладку окна к его же краю — делить нечего
      if (fromId == toId && from.tabs.length == 1) return;
      final pane = WsPane(_newId(), [_take(from, index)]);
      _panes[pane.id] = pane;
      final axis = where == WsDrop.left || where == WsDrop.right ? WsAxis.row : WsAxis.column;
      root = _beside(root, toId, pane.id, axis, before: where == WsDrop.left || where == WsDrop.top);
      focusedId = pane.id;
    }
    if (from.tabs.isEmpty) _removeLeaf(fromId);
  }

  // новое окно рядом с [target]: в том же ряду делит его долю пополам, иначе — новое деление
  WsNode _beside(WsNode node, String target, String added, WsAxis axis, {required bool before}) {
    switch (node) {
      case WsLeaf():
        if (node.paneId != target) return node;
        return WsSplit(axis, before ? [WsLeaf(added), node] : [node, WsLeaf(added)], [0.5, 0.5]);
      case WsSplit():
        final index = node.children.indexWhere((child) => child is WsLeaf && child.paneId == target);
        if (index >= 0 && node.axis == axis) {
          final half = node.ratios[index] / 2;
          final at = before ? index : index + 1;
          final children = [...node.children]..insert(at, WsLeaf(added));
          final ratios = [...node.ratios]
            ..[index] = half
            ..insert(at, half);
          return WsSplit(axis, children, ratios);
        }
        return WsSplit(node.axis, [for (final child in node.children) _beside(child, target, added, axis, before: before)], node.ratios);
    }
  }

  // ——— сохранение ———

  Map<String, Object?> toJson() => {
    'root': _nodeJson(root),
    'panes': {
      for (final pane in _panes.values) pane.id: {'tabs': [for (final tab in pane.tabs) tab.toJson()], 'active': pane.active},
    },
    'focused': focusedId,
    'left': leftOpen,
    'right': rightOpen,
    'leftWidth': leftWidth,
    'rightWidth': rightWidth,
    'collapsed': [...collapsed],
    'leftPanels': left,
    'rightPanels': right,
  };

  static Object _nodeJson(WsNode node) => switch (node) {
    WsLeaf(:final paneId) => paneId,
    WsSplit(:final axis, :final children, :final ratios) => {'axis': axis.name, 'children': [for (final child in children) _nodeJson(child)], 'ratios': ratios},
  };

  static WsNode _nodeFrom(Object? json) {
    if (json is String) return WsLeaf(json);
    final map = json as Map<String, dynamic>;
    return WsSplit(
      WsAxis.values.byName(map['axis'] as String),
      [for (final child in map['children'] as List) _nodeFrom(child)],
      [for (final ratio in map['ratios'] as List) (ratio as num).toDouble()],
    );
  }

  factory Workspace.fromJson(Map<String, dynamic> json) {
    final panes = <String, WsPane>{
      for (final MapEntry(:key, :value) in (json['panes'] as Map<String, dynamic>).entries)
        key: WsPane(key, [for (final tab in (value as Map)['tabs'] as List) ?WsTab.fromJson(tab)], (value['active'] as num?)?.toInt() ?? 0),
    };
    final root = _nodeFrom(json['root']);
    final leaves = _leaves(root).toList();
    if (leaves.isEmpty || leaves.any((id) => panes[id] == null || panes[id]!.tabs.isEmpty)) throw const FormatException('окна без вкладок');
    final focused = json['focused'] as String?;
    return Workspace._(root, panes, focused != null && panes.containsKey(focused) ? focused : leaves.first)
      ..leftOpen = json['left'] as bool? ?? true
      ..rightOpen = json['right'] as bool? ?? true
      ..leftWidth = (json['leftWidth'] as num?)?.toDouble() ?? 296
      ..rightWidth = (json['rightWidth'] as num?)?.toDouble() ?? 320
      ..collapsed.addAll([for (final name in json['collapsed'] as List? ?? const []) name as String])
      .._restorePanels(json['leftPanels'], json['rightPanels']);
  }

  void _restorePanels(Object? leftJson, Object? rightJson) {
    if (leftJson is! List || rightJson is! List) return;
    left
      ..clear()
      ..addAll([for (final id in leftJson) if (allPanels.contains(id)) id as String]);
    right
      ..clear()
      ..addAll([for (final id in rightJson) if (allPanels.contains(id) && !left.contains(id)) id as String]);
  }

  /// Раскладка из сохранённого текста; сломана — с чистого листа.
  static Workspace fromJsonOrInitial(String? text) {
    if (text == null) return Workspace.initial();
    try {
      return Workspace.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } on Object {
      return Workspace.initial();
    }
  }
}
