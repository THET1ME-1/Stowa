import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/desk_mode.dart';
import '../../core/widgets/pill_segments.dart';
import '../../core/widgets/shape_badge.dart';
import '../../core/widgets/tag_tile.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/tags_repository.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../folder/folder_screen.dart';
import '../folder/folder_sheets.dart';
import '../settings/settings_blocks.dart';
import 'rule_sheet.dart';
import 'tag_sheet.dart';

Route<void> tagsRoute() => MaterialPageRoute(builder: (_) => const TagsScreen());

enum _Tab { tags, rules, folders }

/// Теги, правила и папки — тремя вкладками. У каждой одна фраза, зачем она: хозяин 21.11
/// назвал прежний экран непонятным («как что делать и зачем»).
class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  _Tab _tab = _Tab.tags;

  Future<void> _add() async {
    switch (_tab) {
      case _Tab.tags:
        await showTagSheet(context);
      case _Tab.rules:
        await showRuleSheet(context);
      case _Tab.folders:
        final name = await showRenameSheet(context, '');
        if (name != null) await ref.read(foldersRepositoryProvider).create(name);
    }
  }

  Future<void> _delete(TagCard tag) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tags = ref.read(tagsRepositoryProvider);
    final snapshot = await tags.delete(tag.id);
    showUndo(messenger, message: l.tagDeleted(tag.name), label: l.restoreAction, onUndo: () => tags.restore(snapshot));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final addTip = switch (_tab) {
      _Tab.tags => l.tagAdd,
      _Tab.rules => l.ruleNew,
      _Tab.folders => l.folderPickNew,
    };
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            Row(
              children: [
                Expanded(child: SettingsHeader(l.settingsTooltip)),
                const SizedBox(width: 12),
                SettingsRoundButton(icon: 'add', tooltip: addTip, onTap: _add),
              ],
            ),
            const SizedBox(height: 16),
            // на узком телефоне значки съедали подписи («Прав…»): там вкладки одними словами
            LayoutBuilder(
              builder: (context, box) {
                final icons = box.maxWidth >= 340;
                return PillSegments<_Tab>(
                  options: [
                    (value: _Tab.tags, label: l.tagsTab, icon: icons ? 'sell' : null),
                    (value: _Tab.rules, label: l.rulesTab, icon: icons ? 'rule' : null),
                    (value: _Tab.folders, label: l.foldersTab, icon: icons ? 'folder' : null),
                  ],
                  selected: _tab,
                  onChanged: (tab) => setState(() => _tab = tab),
                );
              },
            ),
            // вкладки сменяются проявлением, без рывка
            AnimatedSwitcher(
              duration: Motion.medium,
              switchInCurve: Motion.emphasizedDecelerate,
              switchOutCurve: Motion.emphasizedAccelerate,
              layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: switch (_tab) {
                    _Tab.tags => _tagsTab(l),
                    _Tab.rules => _rulesTab(l),
                    _Tab.folders => _foldersTab(l),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _tagsTab(L l) {
    final text = Theme.of(context).textTheme;
    final tags = ref.watch(allTagsProvider).value ?? const <TagCard>[];
    final pinned = ref.watch(pinnedTagsProvider).value ?? const <TagCard>[];
    final filesRoot = ref.watch(filesRootProvider);
    return [
      _Intro(l.tagsIntro),
      if (pinned.isNotEmpty) ...[
        _Section(l.tagsPinned),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(l.tagsPinnedHint, style: text.bodySmall!.copyWith(color: Tokens.muted)),
        ),
        _PinnedWrap(tags: pinned, filesRoot: filesRoot, onOpen: (tag) => showTagSheet(context, tag: tag)),
      ],
      _Section(l.tagsAll),
      if (tags.isEmpty)
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 12), child: Text(l.tagsNone, style: text.bodyMedium!.copyWith(color: Tokens.muted)))
      else
        SettingsGroup(
          tint: Tokens.onSurface,
          children: [
            for (final tag in tags)
              Dismissible(
                key: ValueKey('tag-${tag.id}'),
                direction: DismissDirection.endToStart,
                // пустой тег ничего не держит: спрашивать незачем, «Вернуть» всё равно есть
                confirmDismiss: (_) async => tag.count == 0 || await _confirmDelete(tag),
                onDismissed: (_) => _delete(tag),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Tokens.error,
                  child: Icon(symbolIcon('delete'), color: Tokens.onError),
                ),
                child: _TagRow(tag: tag, filesRoot: filesRoot, onTap: () => showTagSheet(context, tag: tag)),
              ),
          ],
        ),
      const SizedBox(height: 12),
      _AddButton(label: l.tagNew, onTap: () => showTagSheet(context)),
    ];
  }

  List<Widget> _rulesTab(L l) {
    final text = Theme.of(context).textTheme;
    final rules = ref.watch(allRulesProvider).value ?? const <Rule>[];
    final folders = ref.watch(foldersProvider).value ?? const <FolderCard>[];
    String? folderName(Rule rule) => folders.where((one) => one.id == rule.actionValue).firstOrNull?.name;
    // примеры — пока правил мало; тот, что уже заведён, не повторяется
    final examples = <RuleDraft>[
      (condition: RuleConditionKind.domain, conditionValue: 'youtube.com', action: RuleActionKind.addTag, actionValue: l.ruleExampleVideoTag),
      (condition: RuleConditionKind.keyword, conditionValue: l.ruleExampleBuyWord, action: RuleActionKind.addTag, actionValue: l.ruleExampleShoppingTag),
      (condition: RuleConditionKind.pageType, conditionValue: 'event', action: RuleActionKind.remindBefore, actionValue: '1440'),
    ].where((draft) => !rules.any((rule) => rule.conditionKind == draft.condition && rule.conditionValue == draft.conditionValue)).toList();
    return [
      _Intro(l.rulesIntro),
      if (rules.isEmpty)
        Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 12), child: Text(l.rulesEmpty, style: text.bodyMedium!.copyWith(color: Tokens.muted)))
      else ...[
        const SizedBox(height: 8),
        SettingsGroup(
          tint: Tokens.onSurface,
          children: [
            for (final rule in rules)
              _RuleRow(
                key: ValueKey('rule-${rule.id}'),
                icon: ruleConditionIcon(rule.conditionKind),
                when: ruleWhenText(l, rule.conditionKind, rule.conditionValue),
                then: ruleDoText(l, rule.actionKind, rule.actionValue, folderName: folderName(rule)),
                enabled: rule.enabled,
                onTap: () => showRuleSheet(context, rule: rule),
                onToggle: (on) => ref.read(rulesRepositoryProvider).setEnabled(rule.id, on),
              ),
          ],
        ),
      ],
      const SizedBox(height: 12),
      _AddButton(label: l.ruleNew, onTap: () => showRuleSheet(context)),
      if (rules.length < 3 && examples.isNotEmpty) ...[
        _Section(l.rulesExamples),
        SettingsGroup(
          tint: Tokens.onSurface,
          children: [
            for (final draft in examples)
              _RuleRow(
                key: ValueKey('rule-example-${draft.condition.name}'),
                icon: ruleConditionIcon(draft.condition),
                when: ruleWhenText(l, draft.condition, draft.conditionValue),
                then: ruleDoText(l, draft.action, draft.actionValue),
                enabled: true,
                onTap: () => showRuleSheet(context, draft: draft),
              ),
          ],
        ),
      ],
      SettingsHint(l.rulesWhenWorks),
    ];
  }

  List<Widget> _foldersTab(L l) {
    final folders = ref.watch(foldersProvider).value ?? const <FolderCard>[];
    return [
      const SizedBox(height: 16),
      if (folders.isNotEmpty)
        SettingsGroup(
          tint: Tokens.onSurface,
          children: [
            for (final folder in folders)
              _ListRow(
                leading: ShapeBadge(
                  shape: BadgeShape.values.asNameMap()[folder.shape] ?? BadgeShape.squircle,
                  size: 40,
                  color: Tokens.containerHighest,
                  child: Icon(symbolIcon(folder.icon), size: 20, color: Tokens.onSurface),
                ),
                title: folder.name,
                subtitle: l.itemsCount(folder.count),
                onTap: () => Navigator.of(context).push(folderRoute(folder.id)),
              ),
          ],
        ),
      const SizedBox(height: 12),
      _AddButton(
        label: l.folderPickNew,
        onTap: () async {
          final name = await showRenameSheet(context, '');
          if (name != null) await ref.read(foldersRepositoryProvider).create(name);
        },
      ),
    ];
  }

  Future<bool> _confirmDelete(TagCard tag) async {
    final l = L.of(context);
    final yes = await showStowaSheet<bool>(
      context,
      maxHeightFactor: null,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.tagDeleteAsk(tag.name, tag.count), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Tokens.error, foregroundColor: Tokens.onError),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.tagDelete),
              ),
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
            ],
          ),
        ),
      ),
    );
    return yes ?? false;
  }
}

/// Зачем вкладка — одной фразой под переключателем.
class _Intro extends StatelessWidget {
  const _Intro(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w600, color: Tokens.onSurfaceVariant)),
    );
  }
}

/// Строка-блок списка: значок, имя крупно, подпись под ним, стрелка.
class _ListRow extends StatelessWidget {
  const _ListRow({required this.leading, required this.title, required this.subtitle, required this.onTap, this.trailing, this.faded = false});

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  /// Пустой тег: имя приглушено, он ничего не держит.
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Tokens.containerHigh,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: faded ? Tokens.muted : Tokens.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: text.bodyMedium!.copyWith(color: Tokens.muted)),
                  ],
                ),
              ),
              ?trailing,
              Icon(symbolIcon('chevron_right'), size: 22, color: Tokens.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tag, required this.filesRoot, required this.onTap});

  final TagCard tag;
  final Directory filesRoot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return _ListRow(
      leading: TagTile(kind: tag.iconKind, value: tag.iconValue, filesRoot: filesRoot, size: 40, tonal: true),
      title: '#${tag.name}',
      subtitle: l.itemsCount(tag.count),
      faded: tag.count == 0,
      trailing: tag.pinned
          ? Padding(padding: const EdgeInsets.only(right: 4), child: Tooltip(message: l.tagsPinned, child: Icon(symbolIcon('keep', filled: true), size: 18, color: Tokens.muted)))
          : null,
      onTap: onTap,
    );
  }
}

/// Правило карточкой: фраза словами и выключатель прямо на ней. Без [onToggle] — пример:
/// вместо выключателя «+», касание открывает лист уже заполненным.
class _RuleRow extends StatelessWidget {
  const _RuleRow({super.key, required this.icon, required this.when, required this.then, required this.enabled, required this.onTap, this.onToggle});

  final String icon;
  final String when;
  final String then;
  final bool enabled;
  final VoidCallback onTap;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Material(
      color: Tokens.containerHigh,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              Expanded(child: RulePhrase(icon: icon, when: when, then: then, muted: !enabled)),
              const SizedBox(width: 8),
              if (onToggle case final toggle?)
                Tooltip(message: l.ruleEnabled, child: Switch(value: enabled, onChanged: toggle))
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Tokens.containerHighest, shape: BoxShape.circle),
                  child: Icon(symbolIcon('add'), size: 20, color: Tokens.onSurface),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «+ Новый тег», «+ Новое правило»: пилюля во всю ширину на тональной подложке.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: Tokens.containerHigh, foregroundColor: Tokens.onSurface),
      icon: Icon(symbolIcon('add')),
      label: Text(label),
    );
  }
}

/// Тег пилюлей: плитка, имя и число, как на главной.
class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag, required this.filesRoot, this.faded = false});

  final TagCard tag;
  final Directory filesRoot;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Opacity(
      opacity: faded ? 0.35 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TagTile(kind: tag.iconKind, value: tag.iconValue, filesRoot: filesRoot, size: 28),
            const SizedBox(width: 8),
            Text(tag.name, style: text.labelLarge!.copyWith(fontSize: 14, color: Tokens.onSurface)),
            const SizedBox(width: 6),
            Text('${tag.count}', style: text.labelMedium!.copyWith(color: Tokens.muted)),
          ],
        ),
      ),
    );
  }
}

/// Закреплённые теги: зажал и перетащил — порядок на главной меняется.
class _PinnedWrap extends ConsumerStatefulWidget {
  const _PinnedWrap({required this.tags, required this.filesRoot, required this.onOpen});

  final List<TagCard> tags;
  final Directory filesRoot;
  final ValueChanged<TagCard> onOpen;

  @override
  ConsumerState<_PinnedWrap> createState() => _PinnedWrapState();
}

class _PinnedWrapState extends ConsumerState<_PinnedWrap> {
  List<TagCard>? _order;

  @override
  void didUpdateWidget(_PinnedWrap old) {
    super.didUpdateWidget(old);
    _order = null;
  }

  @override
  Widget build(BuildContext context) {
    final order = _order ?? widget.tags;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in order)
          DragTarget<String>(
            onWillAcceptWithDetails: (details) => details.data != tag.id,
            onAcceptWithDetails: (details) {
              // перетащенный тег встаёт на место того, на который его бросили
              final next = [...order];
              final dragged = next.firstWhere((one) => one.id == details.data);
              next.remove(dragged);
              next.insert(next.indexOf(tag), dragged);
              setState(() => _order = next);
              ref.read(tagsRepositoryProvider).reorderPinned([for (final one in next) one.id]);
            },
            builder: (context, candidates, _) => AnimatedScale(
              scale: candidates.isEmpty ? 1 : 1.06,
              duration: Motion.short,
              child: LongPressDraggable<String>(
                data: tag.id,
                feedback: Material(color: Colors.transparent, child: _TagPill(tag: tag, filesRoot: widget.filesRoot)),
                childWhenDragging: _TagPill(tag: tag, filesRoot: widget.filesRoot, faded: true),
                child: GestureDetector(onTap: () => widget.onOpen(tag), child: _TagPill(tag: tag, filesRoot: widget.filesRoot)),
              ),
            ),
          ),
      ],
    );
  }
}
