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

  test('раскладка «Два окна»: вкладки делятся на два окна; «Обычная» собирает их обратно', () {
    final ws = Workspace.initial();
    ws.open(const WsTab.item('a'));
    ws.open(const WsTab.item('b'));
    ws.arrange(WsPreset.byName('two'));
    expect(ws.panes, hasLength(2));
    final all = [for (final pane in ws.panes) ...pane.tabs];
    expect(all.toSet(), {const WsTab.home(), const WsTab.item('a'), const WsTab.item('b')});
    ws.arrange(WsPreset.byName('normal'));
    expect(ws.panes, hasLength(1));
    expect(ws.focusedPane.tabs.toSet(), all.toSet());
  });

  test('раскладка «Чтение» прячет доки, «Обычная» возвращает', () {
    final ws = Workspace.initial();
    ws.arrange(WsPreset.byName('reading'));
    expect(ws.leftOpen || ws.rightOpen, isFalse);
    ws.arrange(WsPreset.byName('normal'));
    expect(ws.leftOpen && ws.rightOpen, isTrue);
  });

  test('окон в раскладке больше, чем вкладок, — лишние окна открывают главную', () {
    final ws = Workspace.initial();
    ws.arrange(WsPreset.byName('three'));
    expect(ws.panes, hasLength(3));
    expect(ws.panes.every((pane) => pane.tabs.isNotEmpty), isTrue);
    // главная одна: в лишних окнах «Без папки» и «Посмотреть потом», а не три главных
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
