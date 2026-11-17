import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../settings/appearance_screen.dart';
import '../settings/import_screen.dart';
import '../settings/returns_screen.dart';
import '../settings/settings_blocks.dart';
import '../settings/settings_screen.dart';
import '../settings/storage_screen.dart';
import '../settings/sync_screen.dart';
import '../tags/tags_screen.dart';
import 'workspace_keys.dart';
import 'workspace_model.dart';
import 'workspace_shell.dart';

/// Раздел настроек широкого экрана: имя, значок и цвет значка — как группы на телефоне.
typedef _Section = ({String id, String icon, String tint, String Function(L l) title});

final List<_Section> _sections = [
  (id: 'vault', icon: 'folder', tint: 'teal', title: (l) => l.settingsCatalog),
  (id: 'sync', icon: 'cloud_sync', tint: 'sky', title: (l) => l.syncTitle),
  (id: 'look', icon: 'palette', tint: 'rose', title: (l) => l.appearanceTitle),
  (id: 'ai', icon: 'auto_awesome', tint: 'violet', title: (l) => l.settingsAi),
  (id: 'returns', icon: 'replay', tint: 'violet', title: (l) => l.settingsReturns),
  (id: 'outside', icon: 'send', tint: 'sky', title: (l) => l.settingsOutside),
  (id: 'order', icon: 'label', tint: 'amber', title: (l) => l.settingsTooltip),
  (id: 'data', icon: 'delete', tint: 'teal', title: (l) => l.settingsData),
  (id: 'import', icon: 'move_down', tint: 'sky', title: (l) => l.settingsImport),
  (id: 'line', icon: 'keyboard_return', tint: 'teal', title: (l) => l.settingsLine),
  (id: 'keys', icon: 'keyboard', tint: 'blue', title: (l) => l.wsKeys),
  (id: 'start', icon: 'start', tint: 'lime', title: (l) => l.settingsStart),
  (id: 'language', icon: 'translate', tint: 'orchid', title: (l) => l.settingsLanguage),
  (id: 'help', icon: 'flag', tint: 'coral', title: (l) => l.settingsHelp),
];

/// Настройки вкладкой, как файл в редакторе: слева разделы, справа открытый. В узком
/// окне разделы встают полосой сверху.
class WorkspaceSettings extends StatelessWidget {
  const WorkspaceSettings({super.key, required this.section});

  final String? section;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final controller = WorkspaceScope.of(context);
    final current = _sections.where((one) => one.id == section).firstOrNull ?? _sections.first;
    void pick(String id) => controller.update((ws) => ws.open(WsTab.settings(id)));
    final content = AnimatedSwitcher(
      duration: Motion.medium,
      switchInCurve: Motion.emphasized,
      switchOutCurve: Motion.emphasized,
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(key: ValueKey(current.id), child: _content(current, l)),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final one in _sections)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _SectionButton(section: one, label: one.title(l), selected: one.id == current.id, compact: true, onTap: () => pick(one.id)),
                      ),
                  ],
                ),
              ),
              Expanded(child: content),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 248,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 18, 6, 18),
                children: [
                  for (final one in _sections)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _SectionButton(section: one, label: one.title(l), selected: one.id == current.id, onTap: () => pick(one.id)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: content),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _content(_Section section, L l) => switch (section.id) {
    'vault' => const StorageScreen(),
    'sync' => const SyncScreen(),
    'look' => const AppearanceScreen(),
    'ai' => const AiScreen(),
    'returns' => const ReturnsScreen(),
    'order' => const TagsScreen(),
    'import' => const ImportScreen(),
    'keys' => const KeysEditor(),
    final id => SettingsScreen(section: id, title: section.title(l)),
  };
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({required this.section, required this.label, required this.selected, required this.onTap, this.compact = false});

  final _Section section;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tint = settingsTint(section.tint);
    return AnimatedContainer(
      duration: Motion.medium,
      curve: Motion.emphasized,
      decoration: BoxDecoration(color: selected ? Tokens.containerHigh : Colors.transparent, borderRadius: BorderRadius.circular(100)),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(5, 5, compact ? 14 : 12, 5),
            child: Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                // круглый значок в цвет группы, как на телефоне
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: FolderPalette.tint(tint, 0.22), shape: BoxShape.circle),
                  child: Icon(symbolIcon(section.icon, filled: true), size: 18, color: FolderPalette.ink(tint)),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium!.copyWith(color: selected ? Tokens.onSurface : Tokens.onSurfaceVariant, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Название команды на языке приложения.
String commandTitle(L l, String id) => switch (id) {
  'find' => l.wsFind,
  'palette' => l.wsCmdPalette,
  'switch' => l.wsCmdSwitch,
  'home' => l.wsCmdHome,
  'keys' => l.wsKeys,
  'new' => l.wsCmdNew,
  'trash' => l.wsCmdTrash,
  'pin' => l.wsCmdPin,
  'move' => l.wsCmdMove,
  'close' => l.wsCloseTab,
  'reopen' => l.wsCmdReopen,
  'next' => l.wsCmdNext,
  'prev' => l.wsCmdPrev,
  'splitRight' => l.wsSplitRight,
  'splitDown' => l.wsSplitDown,
  'nextPane' => l.wsCmdNextPane,
  'prevPane' => l.wsCmdPrevPane,
  'closePane' => l.wsCmdClosePane,
  'left' => l.wsLeftDock,
  'right' => l.wsRightDock,
  'theme' => l.wsCmdTheme,
  'settings' => l.settingsTitle,
  _ => id,
};

String groupTitle(L l, String group) => switch (group) {
  'nav' => l.wsGroupNav,
  'notes' => l.wsGroupNotes,
  'tabs' => l.wsGroupTabs,
  _ => l.wsGroupDocks,
};

/// Сочетание фишками клавиш: «Ctrl» «K», «G» затем «H».
class Chord extends StatelessWidget {
  const Chord(this.chord, {super.key});

  final String chord;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final steps = chord.split(' ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, step) in steps.indexed) ...[
          if (index > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(l.wsThen, style: text.labelSmall!.copyWith(color: Tokens.muted)),
            ),
          for (final key in step.split('+'))
            Container(
              margin: const EdgeInsets.only(right: 3),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: BorderRadius.circular(7)),
              child: Text(key, style: text.labelMedium!.copyWith(fontWeight: FontWeight.w600)),
            ),
        ],
      ],
    );
  }
}

/// Сочетания клавиш: у каждой команды фишки сочетаний. Фишка — заменить её, крестик —
/// убрать, плюс — добавить ещё одно, стрелка — вернуть как было.
class KeysEditor extends StatefulWidget {
  const KeysEditor({super.key});

  @override
  State<KeysEditor> createState() => _KeysEditorState();
}

class _KeysEditorState extends State<KeysEditor> {
  // какое сочетание ждёт нажатия: команда и номер фишки, -1 — новое
  (String, int)? _recording;

  @override
  void dispose() {
    keyCapture = null;
    super.dispose();
  }

  void _record(String id, int index) {
    setState(() => _recording = (id, index));
    keyCapture = (chord) {
      final controller = WorkspaceScope.of(context);
      final l = L.of(context);
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _recording = null);
      keyCapture = null;
      if (chord == 'Esc') return;
      try {
        final taken = controller.updateKeys((keys) => index < 0 ? keys.add(id, chord) : keys.replace(id, index, chord));
        if (taken != null) messenger.showSnackBar(SnackBar(content: Text(l.wsKeysTaken(commandTitle(l, taken)))));
      } on BrowserChord {
        messenger.showSnackBar(SnackBar(content: Text(l.wsKeysBrowser)));
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final controller = WorkspaceScope.of(context);
    final keys = controller.keys;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
        children: [
          SettingsHeader(l.wsKeys),
          const SizedBox(height: 6),
          SettingsHint(l.wsKeysHint),
          if (keys.changed.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => controller.updateKeys((keys) {
                  keys.resetAll();
                  return null;
                }),
                icon: Icon(symbolIcon('restart_alt'), size: 18),
                label: Text(l.wsKeysResetAll),
              ),
            ),
          for (final group in wsGroups) ...[
            SettingsSection(groupTitle(l, group)),
            SettingsGroup(
              tint: settingsTint('blue'),
              children: [
                for (final command in wsCommands.where((command) => command.group == group))
                  Material(
                    color: Tokens.containerHigh,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                      child: Row(
                        children: [
                          SettingsIconChip(command.icon),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(commandTitle(l, command.id), style: text.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                                if (keys.changed.contains(command.id)) Text(l.wsChanged, style: text.labelSmall!.copyWith(color: Tokens.muted)),
                              ],
                            ),
                          ),
                          Flexible(
                            flex: 2,
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final (index, chord) in keys.of(command.id).indexed)
                                  _recording == (command.id, index)
                                      ? _Waiting(label: l.wsKeysPress)
                                      : _ChordChip(
                                          chord: chord,
                                          removeTooltip: l.wsKeysRemove,
                                          onTap: () => _record(command.id, index),
                                          onRemove: () => controller.updateKeys((keys) {
                                            keys.remove(command.id, index);
                                            return null;
                                          }),
                                        ),
                                if (_recording == (command.id, -1)) _Waiting(label: l.wsKeysPress),
                                IconButton(tooltip: l.wsKeysAdd, onPressed: () => _record(command.id, -1), icon: Icon(symbolIcon('add'), size: 20, color: Tokens.muted)),
                                if (keys.changed.contains(command.id))
                                  IconButton(
                                    tooltip: l.wsKeysReset,
                                    onPressed: () => controller.updateKeys((keys) {
                                      keys.reset(command.id);
                                      return null;
                                    }),
                                    icon: Icon(symbolIcon('restart_alt'), size: 20, color: Tokens.muted),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChordChip extends StatelessWidget {
  const _ChordChip({required this.chord, required this.removeTooltip, required this.onTap, required this.onRemove});

  final String chord;
  final String removeTooltip;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tokens.container,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5, 4, 2, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Chord(chord),
              Tooltip(
                message: removeTooltip,
                child: InkResponse(onTap: onRemove, radius: 14, child: Padding(padding: const EdgeInsets.all(3), child: Icon(symbolIcon('close'), size: 15, color: Tokens.muted))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: Color.alphaBlend(Tokens.accent.withValues(alpha: 0.16), Tokens.containerHighest), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

/// Пока ждём нажатия сочетания в настройках, клавиши идут сюда, а не командам.
void Function(String chord)? keyCapture;

/// Палитра: команды с их сочетаниями и заметки по названию. [notes] — сразу заметки (Ctrl+O).
Future<void> showPalette(
  BuildContext context, {
  required KeyMap keys,
  required List<({String id, String title})> items,
  required void Function(String command) onCommand,
  required void Function(String itemId) onItem,
  bool notes = false,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: Motion.medium,
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Motion.emphasized);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(position: Tween(begin: const Offset(0, -0.02), end: Offset.zero).animate(curved), child: child),
      );
    },
    pageBuilder: (context, _, _) => _Palette(keys: keys, items: items, onCommand: onCommand, onItem: onItem, notes: notes),
  );
}

class _Palette extends StatefulWidget {
  const _Palette({required this.keys, required this.items, required this.onCommand, required this.onItem, required this.notes});

  final KeyMap keys;
  final List<({String id, String title})> items;
  final void Function(String command) onCommand;
  final void Function(String itemId) onItem;
  final bool notes;

  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  final _query = TextEditingController();
  int _selected = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<({String? command, String? item, String title, String icon})> _rows(L l) {
    final query = _query.text.trim().toLowerCase();
    bool fits(String title) => query.isEmpty || title.toLowerCase().contains(query);
    return [
      if (!widget.notes)
        for (final command in wsCommands)
          if (fits(commandTitle(l, command.id))) (command: command.id, item: null, title: commandTitle(l, command.id), icon: command.icon),
      if (widget.notes || query.isNotEmpty)
        for (final item in widget.items.where((item) => fits(item.title)).take(30)) (command: null, item: item.id, title: item.title, icon: 'description'),
    ];
  }

  void _run(({String? command, String? item, String title, String icon}) row) {
    Navigator.of(context).pop();
    if (row.command case final command?) widget.onCommand(command);
    if (row.item case final item?) widget.onItem(item);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final rows = _rows(l);
    final selected = rows.isEmpty ? 0 : _selected.clamp(0, rows.length - 1);
    return Align(
      alignment: const Alignment(0, -0.55),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 460),
        child: Material(
          color: Tokens.containerHigh,
          borderRadius: BorderRadius.circular(Radii.card),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    Icon(symbolIcon('search'), size: 20, color: Tokens.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Focus(
                        onKeyEvent: (node, event) {
                          if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                            setState(() => _selected = (selected + 1).clamp(0, rows.length - 1));
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                            setState(() => _selected = (selected - 1).clamp(0, rows.length - 1));
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.enter && rows.isNotEmpty) {
                            _run(rows[selected]);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: _query,
                          autofocus: true,
                          onChanged: (_) => setState(() => _selected = 0),
                          style: text.bodyLarge,
                          decoration: InputDecoration.collapsed(hintText: l.wsPaletteHint, hintStyle: text.bodyLarge!.copyWith(color: Tokens.muted)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                  children: [
                    for (final (index, row) in rows.indexed)
                      AnimatedContainer(
                        duration: Motion.short,
                        curve: Motion.emphasized,
                        decoration: BoxDecoration(color: index == selected ? Tokens.containerHighest : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _run(row),
                          onHover: (on) {
                            if (on) setState(() => _selected = index);
                          },
                          child: SizedBox(
                            height: 44,
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                Icon(symbolIcon(row.icon), size: 19, color: Tokens.onSurfaceVariant),
                                const SizedBox(width: 12),
                                Expanded(child: Text(row.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium)),
                                if (row.command case final command? when widget.keys.of(command).isNotEmpty) Chord(widget.keys.of(command).first),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
