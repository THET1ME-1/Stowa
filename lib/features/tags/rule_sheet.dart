import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/repositories/tags_repository.dart';
import '../../domain/models.dart';
import '../../domain/structured_page.dart' show PageType;
import '../../l10n/app_localizations.dart';
import '../composer/panel_text.dart';
import '../folder/folder_sheets.dart';

/// Лист правила «если — то»: новое или правка старого.
Future<void> showRuleSheet(BuildContext context, {Rule? rule}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Tokens.containerLow,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      // кнопка внизу не ложится на полоску жестов
      child: SafeArea(top: false, child: RuleSheet(rule: rule)),
    ),
  );
}

class RuleSheet extends ConsumerStatefulWidget {
  const RuleSheet({super.key, this.rule});

  final Rule? rule;

  @override
  ConsumerState<RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends ConsumerState<RuleSheet> {
  late RuleConditionKind _condition = widget.rule?.conditionKind ?? RuleConditionKind.hasTag;
  late final _value = TextEditingController(
    text: widget.rule?.conditionKind == RuleConditionKind.kind || widget.rule?.conditionKind == RuleConditionKind.pageType ? '' : widget.rule?.conditionValue ?? '',
  );
  late ItemKind _kind = ItemKind.values.asNameMap()[widget.rule?.conditionValue] ?? ItemKind.link;
  late PageType _page = PageType.values.asNameMap()[widget.rule?.conditionValue] ?? PageType.recipe;
  late RuleActionKind _action = widget.rule?.actionKind ?? RuleActionKind.toFolder;
  late String? _folderId = widget.rule?.actionKind == RuleActionKind.toFolder ? widget.rule?.actionValue : null;
  late final _tag = TextEditingController(text: widget.rule?.actionKind == RuleActionKind.addTag ? widget.rule?.actionValue : '');
  late int _remind = widget.rule?.actionKind == RuleActionKind.remindBefore ? int.tryParse(widget.rule!.actionValue) ?? _day : _day;
  late bool _enabled = widget.rule?.enabled ?? true;

  static const _hour = 60;
  static const _day = 24 * 60;
  static const _week = 7 * 24 * 60;

  // напомнить можно только о событии: у него есть начало
  bool get _canRemind => _condition == RuleConditionKind.pageType && _page == PageType.event;

  void _setCondition(RuleConditionKind condition, {PageType? page}) => setState(() {
    _condition = condition;
    if (page != null) _page = page;
    if (_action == RuleActionKind.remindBefore && !_canRemind) _action = RuleActionKind.toFolder;
  });

  @override
  void dispose() {
    _value.dispose();
    _tag.dispose();
    super.dispose();
  }

  String get _conditionValue => switch (_condition) {
    RuleConditionKind.kind => _kind.name,
    RuleConditionKind.pageType => _page.name,
    // «1 000», «1000,50» — числом; не число — пусто, сохранить нельзя
    RuleConditionKind.priceAbove || RuleConditionKind.priceBelow => _price(_value.text)?.toString() ?? '',
    _ => _value.text.trim().replaceFirst('#', ''),
  };

  static num? _price(String text) {
    final number = double.tryParse(text.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.'));
    if (number == null || number < 0) return null;
    return number == number.roundToDouble() ? number.round() : number;
  }

  String? get _actionValue => switch (_action) {
    RuleActionKind.toFolder => _folderId,
    RuleActionKind.remindBefore => '$_remind',
    RuleActionKind.addTag => _tag.text.trim().isEmpty ? null : _tag.text.trim(),
  };

  bool get _ready => _conditionValue.isNotEmpty && _actionValue != null;

  Future<void> _save() async {
    await ref.read(rulesRepositoryProvider).save(
      id: widget.rule?.id,
      condition: _condition,
      conditionValue: _conditionValue,
      action: _action,
      actionValue: _actionValue!,
      enabled: _enabled,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final rules = ref.read(rulesRepositoryProvider);
    final rule = widget.rule!;
    await rules.remove(rule.id);
    if (mounted) Navigator.pop(context);
    showUndo(messenger, message: l.ruleDeleted, label: l.restoreAction, onUndo: () => rules.restore(rule));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final folders = ref.watch(foldersProvider).value ?? const [];
    final tags = [for (final tag in ref.watch(allTagsProvider).value ?? const <TagCard>[]) tag.name];
    final conditions = {
      RuleConditionKind.hasTag: ('tag', l.ruleIfTag),
      RuleConditionKind.domain: ('link', l.ruleIfDomain),
      RuleConditionKind.keyword: ('text_fields', l.ruleIfWord),
      RuleConditionKind.kind: ('category', l.ruleIfKind),
      RuleConditionKind.pageType: ('article', l.ruleIfPage),
      RuleConditionKind.priceAbove: ('trending_up', l.ruleIfPriceAbove),
      RuleConditionKind.priceBelow: ('trending_down', l.ruleIfPriceBelow),
    };
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
      children: [
        Text(l.ruleSheetTitle, style: Theme.of(context).textTheme.titleLarge!.copyWith(fontFamily: 'Unbounded', fontWeight: FontWeight.w700, fontSize: 20)),
        const SizedBox(height: 18),
        _Label(l.ruleIf),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final MapEntry(key: kind, value: (icon, label)) in conditions.entries)
              _Choice(icon: icon, label: label, on: _condition == kind, onTap: () => _setCondition(kind)),
          ],
        ),
        const SizedBox(height: 10),
        if (_condition == RuleConditionKind.pageType)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final page in PageType.values)
                _Choice(label: pageTypeName(l, page), on: _page == page, onTap: () => _setCondition(RuleConditionKind.pageType, page: page)),
            ],
          )
        else if (_condition == RuleConditionKind.priceAbove || _condition == RuleConditionKind.priceBelow)
          TextField(
            controller: _value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: l.ruleValuePrice),
          )
        else if (_condition == RuleConditionKind.kind)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in ItemKind.values)
                _Choice(icon: kindIcon(kind), label: kindsLabel(l, kind), on: _kind == kind, onTap: () => setState(() => _kind = kind)),
            ],
          )
        else ...[
          TextField(
            controller: _value,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: switch (_condition) {
                RuleConditionKind.hasTag => l.ruleValueTag,
                RuleConditionKind.domain => l.ruleValueDomain,
                _ => l.ruleValueWord,
              },
            ),
          ),
          if (_condition == RuleConditionKind.hasTag) _TagHints(controller: _value, tags: tags, onPick: () => setState(() {})),
        ],
        const SizedBox(height: 18),
        _Label(l.ruleThen),
        Wrap(
          spacing: 8,
          children: [
            _Choice(icon: 'folder', label: l.ruleThenFolder, on: _action == RuleActionKind.toFolder, onTap: () => setState(() => _action = RuleActionKind.toFolder)),
            _Choice(icon: 'tag', label: l.ruleThenTag, on: _action == RuleActionKind.addTag, onTap: () => setState(() => _action = RuleActionKind.addTag)),
            if (_canRemind)
              _Choice(icon: 'alarm', label: l.ruleThenRemind, on: _action == RuleActionKind.remindBefore, onTap: () => setState(() => _action = RuleActionKind.remindBefore)),
          ],
        ),
        const SizedBox(height: 10),
        if (_action == RuleActionKind.remindBefore)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in const [_hour, _day, _week])
                _Choice(label: remindBeforeLabel(l, minutes), on: _remind == minutes, onTap: () => setState(() => _remind = minutes)),
            ],
          )
        else if (_action == RuleActionKind.toFolder)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final folder in folders)
                _Choice(icon: folder.icon, label: folder.name, on: _folderId == folder.id, onTap: () => setState(() => _folderId = folder.id)),
              _Choice(
                icon: 'add',
                label: l.shareNewFolder,
                on: false,
                onTap: () async {
                  final created = await askNewFolder(context, ref);
                  if (created != null && mounted) setState(() => _folderId = created.id);
                },
              ),
            ],
          )
        else ...[
          TextField(controller: _tag, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: l.ruleValueTag)),
          _TagHints(controller: _tag, tags: tags, onPick: () => setState(() {})),
        ],
        if (widget.rule != null)
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.ruleEnabled), value: _enabled, onChanged: (value) => setState(() => _enabled = value)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _ready ? _save : null, child: Text(l.save)),
        if (widget.rule != null) ...[
          const SizedBox(height: 8),
          TextButton(style: TextButton.styleFrom(foregroundColor: Tokens.error), onPressed: _delete, child: Text(l.ruleDelete)),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: Tokens.muted)),
    );
  }
}

/// Теги, которые уже есть, чипами под полем: имя не надо помнить и печатать без ошибки.
class _TagHints extends StatelessWidget {
  const _TagHints({required this.controller, required this.tags, required this.onPick});

  final TextEditingController controller;
  final List<String> tags;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final typed = controller.text.trim().replaceFirst('#', '').toLowerCase();
    final shown = [for (final tag in tags) if (tag != typed && tag.contains(typed)) tag].take(8).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in shown)
            _Choice(
              label: '#$tag',
              on: false,
              onTap: () {
                controller.text = tag;
                onPick();
              },
            ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.on, required this.onTap, this.icon});

  final String label;
  final String? icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = on ? Tokens.onAccent : Tokens.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.short,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: on ? Tokens.accent : Tokens.containerHigh, borderRadius: BorderRadius.circular(18)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(symbolIcon(icon), size: 18, color: color), const SizedBox(width: 6)],
            Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}
