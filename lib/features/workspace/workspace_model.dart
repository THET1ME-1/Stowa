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

/// Готовая раскладка верхней полосы: сколько окон и какие доки видны.
class WsPreset {
  const WsPreset(this.name, {required this.icon, required this.panes, required this.left, required this.right});

  final String name;
  final String icon;
  final int panes;
  final bool left;
  final bool right;

  static const all = [
    WsPreset('normal', icon: 'dashboard', panes: 1, left: true, right: true),
    WsPreset('reading', icon: 'chrome_reader_mode', panes: 1, left: false, right: false),
    WsPreset('two', icon: 'view_column_2', panes: 2, left: true, right: false),
    WsPreset('three', icon: 'view_column', panes: 3, left: true, right: false),
  ];

  static WsPreset byName(String name) => all.firstWhere((preset) => preset.name == name, orElse: () => all.first);
}

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
  String preset = 'normal';

  /// Свёрнутые панели доков.
  final Set<String> collapsed = {};

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

  /// Готовая раскладка: вкладки всех окон делятся на [WsPreset.panes] окон в ряд.
  void arrange(WsPreset choice) {
    preset = choice.name;
    leftOpen = choice.left;
    rightOpen = choice.right;
    final focusedTab = focusedPane.activeTab;
    final tabs = <WsTab>[];
    for (final pane in panes) {
      for (final tab in pane.tabs) {
        if (!tabs.any((other) => other.key == tab.key)) tabs.add(tab);
      }
    }
    _panes.clear();
    _next = 1;
    final made = <WsPane>[for (var i = 0; i < choice.panes; i++) WsPane(_newId(), const [])];
    for (final pane in made) {
      _panes[pane.id] = pane;
    }
    // по очереди: вкладка с фокусом остаётся в первом окне
    final ordered = [?focusedTab, ...tabs.where((tab) => tab != focusedTab)];
    for (final (index, tab) in ordered.indexed) {
      made[index % made.length].tabs.add(tab);
    }
    for (final pane in made.where((pane) => pane.tabs.isEmpty)) {
      pane.tabs.add(_filler());
    }
    root = made.length == 1 ? WsLeaf(made.single.id) : WsSplit(WsAxis.row, [for (final pane in made) WsLeaf(pane.id)], List.filled(made.length, 1 / made.length));
    focusedId = made.first.id;
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
    'preset': preset,
    'collapsed': [...collapsed],
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
      ..preset = json['preset'] as String? ?? 'normal'
      ..collapsed.addAll([for (final name in json['collapsed'] as List? ?? const []) name as String]);
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
