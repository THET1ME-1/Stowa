import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/features/workspace/workspace_model.dart';

void main() {
  test('новое рабочее пространство: одно окно с главной, оба дока открыты', () {
    final ws = Workspace.initial();
    expect(ws.panes, hasLength(1));
    expect(ws.focusedPane.tabs.single, const WsTab.home());
    expect(ws.leftOpen && ws.rightOpen, isTrue);
  });

  test('открыть заметку — новая вкладка; второй раз та же заметка не двоится, а получает фокус', () {
    final ws = Workspace.initial();
    ws.open(const WsTab.item('a'));
    ws.open(const WsTab.folder('dom'));
    expect(ws.focusedPane.tabs, [const WsTab.home(), const WsTab.item('a'), const WsTab.folder('dom')]);
    ws.open(const WsTab.item('a'));
    expect(ws.focusedPane.tabs, hasLength(3));
    expect(ws.focusedPane.activeTab, const WsTab.item('a'));
  });

  test('заметка, открытая в другом окне, получает фокус там', () {
    final ws = Workspace.initial();
    ws.open(const WsTab.item('a'));
    final first = ws.focusedId;
    ws.split(first, WsAxis.row);
    expect(ws.panes, hasLength(2));
    expect(ws.focusedId, isNot(first));
    ws.open(const WsTab.item('a'));
    expect(ws.focusedId, first);
    expect(ws.panes.where((pane) => pane.tabs.contains(const WsTab.item('a'))), hasLength(1));
  });

  test('закрыли последнюю вкладку окна — окно уходит, деление схлопывается', () {
    final ws = Workspace.initial();
    ws.split(ws.focusedId, WsAxis.row);
    final second = ws.focusedId;
    ws.close(second, 0);
    expect(ws.panes, hasLength(1));
    expect(ws.root, isA<WsLeaf>());
  });

  test('последнее окно не закрывается: без вкладок в нём главная', () {
    final ws = Workspace.initial();
    ws.close(ws.focusedId, 0);
    expect(ws.focusedPane.tabs.single, const WsTab.home());
  });

  test('вкладку к правому краю окна — окно делится, вкладка встаёт новым окном справа', () {
    final ws = Workspace.initial();
    ws.open(const WsTab.item('a'));
    final first = ws.focusedId;
    ws.drop(first, 1, first, WsDrop.right);
    final split = ws.root as WsSplit;
    expect(split.axis, WsAxis.row);
    expect(ws.panes.map((pane) => pane.tabs), [
      [const WsTab.home()],
      [const WsTab.item('a')],
    ]);
    expect(ws.focusedPane.tabs.single, const WsTab.item('a'));
  });

  test('к верхнему краю — деление вниз, новое окно сверху', () {
    final ws = Workspace.initial();
    ws.open(const WsTab.item('a'));
    ws.drop(ws.focusedId, 1, ws.focusedId, WsDrop.top);
    expect((ws.root as WsSplit).axis, WsAxis.column);
    expect(ws.panes.first.tabs.single, const WsTab.item('a'));
  });

  test('единственную вкладку окна к его же краю — ничего не меняется', () {
    final ws = Workspace.initial();
    ws.drop(ws.focusedId, 0, ws.focusedId, WsDrop.left);
    expect(ws.root, isA<WsLeaf>());
  });

  test('вкладку в другое окно — переезжает, опустевшее окно уходит', () {
    final ws = Workspace.initial();
    ws.open(const WsTab.item('a'));
    final first = ws.focusedId;
    ws.drop(first, 1, first, WsDrop.right);
    final second = ws.focusedId;
    ws.drop(second, 0, first, WsDrop.center);
    expect(ws.panes, hasLength(1));
    expect(ws.focusedPane.tabs, [const WsTab.home(), const WsTab.item('a')]);
  });

  test('рядом с окном в том же ряду — его доля делится пополам, соседи не трогаются', () {
    final ws = Workspace.initial();
    ws.open(const WsTab.item('a'));
    ws.open(const WsTab.item('b'));
    final first = ws.focusedId;
    ws.drop(first, 2, first, WsDrop.right);
    final split = ws.root as WsSplit;
    ws.resize(split, 0, 0.7);
    ws.drop(first, 1, first, WsDrop.right);
    final after = ws.root as WsSplit;
    expect(after.children, hasLength(3));
    expect(after.ratios[0], closeTo(0.35, 1e-9));
    expect(after.ratios[1], closeTo(0.35, 1e-9));
    expect(after.ratios[2], closeTo(0.3, 1e-9));
  });

  test('перетаскивание по полосе вкладок меняет порядок', () {
    final ws = Workspace.initial();
    ws.open(const WsTab.item('a'));
    ws.open(const WsTab.item('b'));
    ws.drop(ws.focusedId, 2, ws.focusedId, WsDrop.center, at: 0);
    expect(ws.focusedPane.tabs, [const WsTab.item('b'), const WsTab.home(), const WsTab.item('a')]);
    expect(ws.focusedPane.activeTab, const WsTab.item('b'));
  });

  test('новое окно открывает то, чего ещё нет на экране, а не вторую главную', () {
    final ws = Workspace.initial();
    ws.split(ws.focusedId, WsAxis.row);
    ws.split(ws.focusedId, WsAxis.row);
    expect(ws.panes, hasLength(3));
    expect({for (final pane in ws.panes) ...pane.tabs}, hasLength(3));
  });

  test('раскладка переживает перезапуск', () {
    final ws = Workspace.initial();
    ws.open(const WsTab.item('a'));
    ws.split(ws.focusedId, WsAxis.column);
    ws.open(const WsTab.settings('keys'));
    ws.leftOpen = false;
    ws.collapsed.add('pinned');
    final back = Workspace.fromJson(jsonDecode(jsonEncode(ws.toJson())) as Map<String, dynamic>);
    expect(back.panes.map((pane) => pane.tabs), ws.panes.map((pane) => pane.tabs));
    expect(back.focusedId, ws.focusedId);
    expect(back.leftOpen, isFalse);
    expect(back.collapsed, contains('pinned'));
    expect((back.root as WsSplit).axis, WsAxis.column);
  });

  test('сломанная запись раскладки — начинаем с чистой', () {
    final back = Workspace.fromJsonOrInitial('{не json');
    expect(back.panes.single.tabs.single, const WsTab.home());
  });

  test('панели доков: убрать, вернуть в другой док, перетащить на место', () {
    final ws = Workspace.initial();
    expect(ws.left, ['sections', 'pinned', 'folders']);
    expect(ws.right, ['later', 'yearAgo', 'sync']);
    ws.hidePanel('pinned');
    expect(ws.left, ['sections', 'folders']);
    expect(ws.hiddenPanels, ['pinned']);
    ws.placePanel('pinned', left: false, index: 0);
    expect(ws.right, ['pinned', 'later', 'yearAgo', 'sync']);
    // перетащили внутри дока ниже
    ws.placePanel('pinned', left: false, index: 3);
    expect(ws.right, ['later', 'yearAgo', 'pinned', 'sync']);
    // и в другой док
    ws.placePanel('sync', left: true, index: 1);
    expect(ws.left, ['sections', 'sync', 'folders']);
    expect(ws.right, ['later', 'yearAgo', 'pinned']);
    final back = Workspace.fromJson(jsonDecode(jsonEncode(ws.toJson())) as Map<String, dynamic>);
    expect(back.left, ws.left);
    expect(back.right, ws.right);
  });

  test('доля деления меняется перетаскиванием и не уходит за края', () {
    final ws = Workspace.initial();
    ws.split(ws.focusedId, WsAxis.row);
    final split = ws.root as WsSplit;
    ws.resize(split, 0, 0.95);
    expect(split.ratios.first, lessThanOrEqualTo(0.85));
    ws.resize(split, 0, 0.3);
    expect(split.ratios.first, closeTo(0.3, 1e-9));
    expect(split.ratios.reduce((a, b) => a + b), closeTo(1, 1e-9));
  });
}
