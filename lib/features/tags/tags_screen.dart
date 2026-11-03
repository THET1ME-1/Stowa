import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pill_segments.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/shape_badge.dart';
import '../../core/widgets/tag_tile.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/tags_repository.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../composer/panel_text.dart';
import '../folder/folder_screen.dart';
import '../folder/folder_sheets.dart';
import 'rule_sheet.dart';
import 'tag_sheet.dart';

Route<void> tagsRoute() => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => const TagsScreen(),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

/// Теги и папки, как экран 10 макета: закреплённые теги, все теги, правила; папки отдельной вкладкой.
class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  bool _folders = false;

  Future<void> _add() async {
    if (!_folders) return showTagSheet(context);
    final name = await showRenameSheet(context, '');
    if (name != null) await ref.read(foldersRepositoryProvider).create(name);
  }

  Future<void> _delete(TagCard tag) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tags = ref.read(tagsRepositoryProvider);
    final snapshot = await tags.delete(tag.id);
    messenger.showSnackBar(undoSnackBar(message: l.tagDeleted(tag.name), label: l.restoreAction, onUndo: () => tags.restore(snapshot)));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final tags = ref.watch(allTagsProvider).value ?? const [];
    final pinned = ref.watch(pinnedTagsProvider).value ?? const [];
    final rules = ref.watch(allRulesProvider).value ?? const [];
    final folders = ref.watch(foldersProvider).value ?? const [];
    final filesRoot = ref.watch(filesRootProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            Row(
              children: [
                _RoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Expanded(child: Text(l.tagsTitle, style: text.titleLarge!.copyWith(fontSize: 18))),
                _RoundButton(icon: 'add', tooltip: _folders ? l.folderNew : l.tagAdd, onTap: _add),
              ],
            ),
            const SizedBox(height: 14),
            PillSegments<bool>(
              options: [(value: false, label: l.tagsTab, icon: 'label'), (value: true, label: l.foldersTab, icon: 'folder')],
              selected: _folders,
              onChanged: (folders) => setState(() => _folders = folders),
            ),
            if (_folders)
              ..._folderList(folders)
            else ...[
              if (pinned.isNotEmpty) ...[
                _Section(l.tagsPinned),
                Text(l.tagsPinnedHint, style: text.bodySmall!.copyWith(color: Tokens.muted)),
                const SizedBox(height: 10),
                _PinnedWrap(tags: pinned, filesRoot: filesRoot, onOpen: (tag) => showTagSheet(context, tag: tag)),
              ],
              _Section(l.tagsAll),
              if (tags.isEmpty) Text(l.tagsNone, style: text.bodyMedium!.copyWith(color: Tokens.muted)),
              for (final tag in tags)
                Dismissible(
                  key: ValueKey('tag-${tag.id}'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmDelete(tag),
                  onDismissed: (_) => _delete(tag),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(color: Tokens.error, borderRadius: BorderRadius.circular(Radii.tile)),
                    child: Icon(symbolIcon('delete'), color: Tokens.onError),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: TagTile(kind: tag.iconKind, value: tag.iconValue, filesRoot: filesRoot, size: 36),
                    title: Text(tag.name),
                    subtitle: Text(l.itemsCount(tag.count), style: TextStyle(color: Tokens.muted)),
                    trailing: tag.pinned ? Icon(symbolIcon('keep', filled: true), size: 18, color: Tokens.muted) : null,
                    onTap: () => showTagSheet(context, tag: tag),
                  ),
                ),
              _Section(l.rulesTitle),
              if (rules.isEmpty) Text(l.rulesNone, style: text.bodyMedium!.copyWith(color: Tokens.muted)),
              for (final rule in rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RuleCard(rule: rule, tags: tags, folders: folders, filesRoot: filesRoot, onTap: () => showRuleSheet(context, rule: rule)),
                ),
              const SizedBox(height: 4),
              OutlinedButton.icon(onPressed: () => showRuleSheet(context), icon: Icon(symbolIcon('add')), label: Text(l.ruleNew)),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(TagCard tag) async {
    final l = L.of(context);
    final yes = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
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

  List<Widget> _folderList(List<FolderCard> folders) {
    final l = L.of(context);
    return [
      const SizedBox(height: 12),
      for (final folder in folders)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: ShapeBadge(
            shape: BadgeShape.values.asNameMap()[folder.shape] ?? BadgeShape.squircle,
            size: 40,
            color: Tokens.containerHighest,
            child: Icon(symbolIcon(folder.icon), size: 20, color: Tokens.onSurface),
          ),
          title: Text(folder.name),
          subtitle: Text(l.itemsCount(folder.count), style: TextStyle(color: Tokens.muted)),
          trailing: Icon(symbolIcon('chevron_right'), color: Tokens.muted),
          onTap: () => Navigator.of(context).push(folderRoute(folder.id)),
        ),
    ];
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: Tokens.onSurfaceVariant)),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        pressedScale: 0.9,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
          child: Icon(symbolIcon(icon), color: Tokens.onSurface),
        ),
      ),
    );
  }
}

/// Тег пилюлей: плитка, имя и число, как на экране 10.
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

/// Правило карточкой «условие → действие».
class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule, required this.tags, required this.folders, required this.filesRoot, required this.onTap});

  final Rule rule;
  final List<TagCard> tags;
  final List<FolderCard> folders;
  final Directory filesRoot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    Widget tagPill(String name) {
      final tag = tags.where((one) => one.name == name).firstOrNull;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TagTile(kind: tag?.iconKind ?? TagIconKind.symbol, value: tag?.iconValue ?? 'tag', filesRoot: filesRoot, size: 26),
          const SizedBox(width: 6),
          Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: text.labelLarge!.copyWith(fontSize: 14))),
        ],
      );
    }

    Widget iconLabel(String icon, String label, {Color? color}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(symbolIcon(icon), size: 18, color: color ?? Tokens.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: text.labelLarge!.copyWith(fontSize: 14, color: color))),
      ],
    );

    final condition = switch (rule.conditionKind) {
      RuleConditionKind.hasTag => tagPill(rule.conditionValue),
      RuleConditionKind.domain => iconLabel('link', rule.conditionValue),
      RuleConditionKind.keyword => iconLabel('text_fields', '«${rule.conditionValue}»'),
      RuleConditionKind.kind => iconLabel(kindIcon(ItemKind.values.asNameMap()[rule.conditionValue] ?? ItemKind.note),
          kindsLabel(l, ItemKind.values.asNameMap()[rule.conditionValue] ?? ItemKind.note)),
    };
    final folder = folders.where((one) => one.id == rule.actionValue).firstOrNull;
    final action = switch (rule.actionKind) {
      RuleActionKind.addTag => tagPill(rule.actionValue),
      RuleActionKind.toFolder => folder == null ? iconLabel('block', l.ruleStays, color: Tokens.muted) : iconLabel(folder.icon, folder.name),
    };
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Opacity(
        opacity: rule.enabled ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.fromLTRB(Space.tile, 12, 8, 12),
          decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.tile)),
          child: Row(
            children: [
              // условие и действие делят ширину поровну, стрелка между ними
              Expanded(child: Align(alignment: Alignment.centerLeft, child: condition)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(symbolIcon('arrow_right_alt'), color: Tokens.muted)),
              Expanded(child: Align(alignment: Alignment.centerLeft, child: action)),
              Icon(symbolIcon('chevron_right'), color: Tokens.muted),
            ],
          ),
        ),
      ),
    );
  }
}
