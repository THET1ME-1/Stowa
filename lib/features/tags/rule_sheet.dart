import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/tags_repository.dart';
import '../../domain/models.dart';
import '../../domain/structured_page.dart' show PageType;
import '../../l10n/app_localizations.dart';
import '../../services/vault/vault_reader.dart' show conflictTag;
import '../composer/line_dock.dart' show FolderPickerSheet;
import '../composer/panel_text.dart';
import '../folder/folder_sheets.dart';

/// Правило без сохранения: пример на экране правил открывает лист уже заполненным.
typedef RuleDraft = ({RuleConditionKind condition, String conditionValue, RuleActionKind action, String actionValue});

/// Лист правила «когда — что сделать»: новое, по примеру или правка старого.
Future<void> showRuleSheet(BuildContext context, {Rule? rule, RuleDraft? draft}) {
  return showStowaSheet<void>(context, backgroundColor: Tokens.containerLow, maxHeightFactor: 0.92, builder: (context) => RuleSheet(rule: rule, draft: draft));
}

// пропущенное место во фразе правила
const _gap = '…';

/// Значок условия: тот же в карточке правила и в листе.
String ruleConditionIcon(RuleConditionKind kind) => switch (kind) {
  RuleConditionKind.hasTag => 'tag',
  RuleConditionKind.domain => 'link',
  RuleConditionKind.keyword => 'text_fields',
  RuleConditionKind.kind => 'category',
  RuleConditionKind.pageType => 'article',
  RuleConditionKind.priceAbove => 'trending_up',
  RuleConditionKind.priceBelow => 'trending_down',
};

String _actionIcon(RuleActionKind kind) => switch (kind) {
  RuleActionKind.toFolder => 'folder',
  RuleActionKind.addTag => 'sell',
  RuleActionKind.remindBefore => 'alarm',
};

/// Условие словами: «Есть тег #работа», «Ссылка с сайта youtube.com». Пустое значение — «…».
String ruleWhenText(L l, RuleConditionKind kind, String value) {
  final shown = value.trim().isEmpty ? _gap : value.trim();
  return switch (kind) {
    RuleConditionKind.hasTag => l.ruleWhenTag(shown),
    RuleConditionKind.domain => l.ruleWhenSite(shown),
    RuleConditionKind.keyword => l.ruleWhenWord(shown),
    RuleConditionKind.kind => l.ruleWhenKind(kindsLabel(l, ItemKind.values.asNameMap()[value] ?? ItemKind.note)),
    RuleConditionKind.pageType => l.ruleWhenPage(pageTypeName(l, PageType.values.asNameMap()[value])),
    RuleConditionKind.priceAbove => l.ruleWhenPriceAbove(shown),
    RuleConditionKind.priceBelow => l.ruleWhenPriceBelow(shown),
  };
}

/// Действие словами: «в папку «Работа»», «поставить тег #видео», «напомнить за день».
/// [folderName] — имя папки правила; папки нет (удалили) — заметка остаётся, где лежит.
String ruleDoText(L l, RuleActionKind kind, String value, {String? folderName}) {
  final shown = value.trim().isEmpty ? _gap : value.trim();
  return switch (kind) {
    RuleActionKind.toFolder => value.isEmpty ? l.ruleDoFolder(_gap) : (folderName == null ? l.ruleStays : l.ruleDoFolder(folderName)),
    RuleActionKind.addTag => l.ruleDoTag(shown),
    RuleActionKind.remindBefore => l.ruleDoRemind(remindBeforeLabel(l, int.tryParse(value) ?? 1440)),
  };
}

class RuleSheet extends ConsumerStatefulWidget {
  const RuleSheet({super.key, this.rule, this.draft});

  final Rule? rule;
  final RuleDraft? draft;

  @override
  ConsumerState<RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends ConsumerState<RuleSheet> {
  // откуда взять начальные значения: старое правило, пример или пусто
  late final RuleDraft? _start = widget.rule == null
      ? widget.draft
      : (condition: widget.rule!.conditionKind, conditionValue: widget.rule!.conditionValue, action: widget.rule!.actionKind, actionValue: widget.rule!.actionValue);

  late RuleConditionKind _condition;
  late final TextEditingController _value;
  late ItemKind _kind;
  late PageType _page;
  late RuleActionKind _action;
  late String? _folderId;
  late final TextEditingController _tag;
  late int _remind;
  late final bool _enabled = widget.rule?.enabled ?? true;

  static const _hour = 60;
  static const _day = 24 * 60;
  static const _week = 7 * 24 * 60;

  @override
  void initState() {
    super.initState();
    final start = _start;
    _condition = start?.condition ?? RuleConditionKind.hasTag;
    final listed = _condition == RuleConditionKind.kind || _condition == RuleConditionKind.pageType;
    _value = TextEditingController(text: listed ? '' : start?.conditionValue ?? '');
    _kind = ItemKind.values.asNameMap()[start?.conditionValue] ?? ItemKind.link;
    _page = PageType.values.asNameMap()[start?.conditionValue] ?? PageType.recipe;
    _action = start?.action ?? RuleActionKind.toFolder;
    _folderId = start?.action == RuleActionKind.toFolder && (start?.actionValue.isNotEmpty ?? false) ? start!.actionValue : null;
    _tag = TextEditingController(text: start?.action == RuleActionKind.addTag ? start!.actionValue : '');
    _remind = start?.action == RuleActionKind.remindBefore ? int.tryParse(start!.actionValue) ?? _day : _day;
  }

  @override
  void dispose() {
    _value.dispose();
    _tag.dispose();
    super.dispose();
  }

  // напомнить можно только о событии: у него есть начало
  bool get _canRemind => _condition == RuleConditionKind.pageType && _page == PageType.event;

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
    RuleActionKind.addTag => _tag.text.trim().replaceFirst('#', '').isEmpty ? null : _tag.text.trim().replaceFirst('#', ''),
  };

  bool get _ready => _conditionValue.isNotEmpty && _actionValue != null;

  void _setCondition(RuleConditionKind condition) => setState(() {
    if (condition != _condition) _value.clear();
    _condition = condition;
    if (_action == RuleActionKind.remindBefore && !_canRemind) _action = RuleActionKind.toFolder;
  });

  void _setPage(PageType page) => setState(() {
    _page = page;
    if (_action == RuleActionKind.remindBefore && !_canRemind) _action = RuleActionKind.toFolder;
  });

  /// «Когда»: список условий, у каждого пояснение и пример.
  Future<void> _pickCondition() async {
    final l = L.of(context);
    final picked = await showOptionsSheet<RuleConditionKind>(
      context,
      title: l.ruleStepWhen,
      selected: _condition,
      options: [
        for (final (kind, title, hint) in [
          (RuleConditionKind.hasTag, l.ruleCondTag, l.ruleCondTagHint),
          (RuleConditionKind.domain, l.ruleCondSite, l.ruleCondSiteHint),
          (RuleConditionKind.keyword, l.ruleCondWord, l.ruleCondWordHint),
          (RuleConditionKind.kind, l.ruleCondKind, l.ruleCondKindHint),
          (RuleConditionKind.pageType, l.ruleCondPage, l.ruleCondPageHint),
          (RuleConditionKind.priceAbove, l.ruleCondPriceAbove, l.ruleCondPriceAboveHint),
          (RuleConditionKind.priceBelow, l.ruleCondPriceBelow, l.ruleCondPriceBelowHint),
        ])
          SheetChoice(value: kind, title: title, subtitle: hint, icon: ruleConditionIcon(kind)),
      ],
    );
    if (picked != null && mounted) _setCondition(picked);
  }

  /// «Что сделать»: список действий; «напомнить» — только у события.
  Future<void> _pickAction() async {
    final l = L.of(context);
    final picked = await showOptionsSheet<RuleActionKind>(
      context,
      title: l.ruleStepDo,
      selected: _action,
      options: [
        SheetChoice(value: RuleActionKind.toFolder, title: l.ruleActFolder, subtitle: l.ruleActFolderHint, icon: _actionIcon(RuleActionKind.toFolder)),
        SheetChoice(value: RuleActionKind.addTag, title: l.ruleActTag, subtitle: l.ruleActTagHint, icon: _actionIcon(RuleActionKind.addTag)),
        if (_canRemind) SheetChoice(value: RuleActionKind.remindBefore, title: l.ruleActRemind, subtitle: l.ruleActRemindHint, icon: _actionIcon(RuleActionKind.remindBefore)),
      ],
    );
    if (picked != null && mounted) setState(() => _action = picked);
  }

  /// Папку выбирают тем же окном, что «Переложить», с «Новой папкой» внизу.
  Future<void> _pickFolder() async {
    final l = L.of(context);
    final folders = ref.read(foldersProvider).value ?? const <FolderCard>[];
    final picked = await showOptionsSheetWith<FolderCard>(
      context,
      (sheet) => FolderPickerSheet(title: l.ruleFolderPick, folders: folders, onNew: () => askNewFolder(sheet, ref)),
    );
    if (picked != null && mounted) setState(() => _folderId = picked.id);
  }

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
    final text = Theme.of(context).textTheme;
    final folders = ref.watch(foldersProvider).value ?? const <FolderCard>[];
    // служебный тег копий сверки правилу ни к чему
    final tags = [for (final tag in ref.watch(allTagsProvider).value ?? const <TagCard>[]) if (tag.name != conflictTag) tag.name];
    final folder = folders.where((one) => one.id == _folderId).firstOrNull;
    final whenValue = switch (_condition) {
      RuleConditionKind.kind => _kind.name,
      RuleConditionKind.pageType => _page.name,
      _ => _value.text.replaceFirst('#', ''),
    };

    final conditionTitle = switch (_condition) {
      RuleConditionKind.hasTag => l.ruleCondTag,
      RuleConditionKind.domain => l.ruleCondSite,
      RuleConditionKind.keyword => l.ruleCondWord,
      RuleConditionKind.kind => l.ruleCondKind,
      RuleConditionKind.pageType => l.ruleCondPage,
      RuleConditionKind.priceAbove => l.ruleCondPriceAbove,
      RuleConditionKind.priceBelow => l.ruleCondPriceBelow,
    };
    final actionTitle = switch (_action) {
      RuleActionKind.toFolder => l.ruleActFolder,
      RuleActionKind.addTag => l.ruleActTag,
      RuleActionKind.remindBefore => l.ruleActRemind,
    };

    return Column(
      key: const ValueKey('rule-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 12),
            children: [
              Text(
                widget.rule == null ? l.ruleNew : l.ruleSheetTitle,
                style: text.titleLarge!.copyWith(fontFamily: 'Unbounded', fontWeight: FontWeight.w700, fontSize: 20),
              ),
              const SizedBox(height: 14),
              // что выйдет из правила — целой фразой, пропущенное место «…»
              RulePhrase(
                key: const ValueKey('rule-preview'),
                icon: ruleConditionIcon(_condition),
                when: ruleWhenText(l, _condition, whenValue),
                then: ruleDoText(l, _action, _actionValue ?? '', folderName: folder?.name),
                big: true,
              ),
              const SizedBox(height: 22),
              _StepLabel(number: 1, text: l.ruleStepWhen),
              _StepButton(key: const ValueKey('rule-when'), icon: ruleConditionIcon(_condition), title: conditionTitle, onTap: _pickCondition),
              const SizedBox(height: 10),
              _conditionValueField(l, tags),
              const SizedBox(height: 22),
              _StepLabel(number: 2, text: l.ruleStepDo),
              _StepButton(key: const ValueKey('rule-do'), icon: _actionIcon(_action), title: actionTitle, onTap: _pickAction),
              const SizedBox(height: 10),
              switch (_action) {
                RuleActionKind.toFolder => _StepButton(
                  key: const ValueKey('rule-folder'),
                  icon: folder?.icon ?? 'create_new_folder',
                  title: folder?.name ?? l.ruleFolderPick,
                  muted: folder == null,
                  onTap: _pickFolder,
                ),
                RuleActionKind.addTag => _TagField(key: const ValueKey('rule-tag'), controller: _tag, tags: tags, hint: l.ruleValueTagHint, onChanged: () => setState(() {})),
                RuleActionKind.remindBefore => _ChoiceRow(
                  children: [
                    for (final minutes in const [_hour, _day, _week])
                      _Choice(label: remindBeforeLabel(l, minutes), on: _remind == minutes, onTap: () => setState(() => _remind = minutes)),
                  ],
                ),
              },
            ],
          ),
        ),
        // кнопка всегда на виду, вне прокрутки: раньше до неё надо было листать
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, 4, Space.screen, Space.screen),
          child: Row(
            children: [
              if (widget.rule != null) ...[
                SheetDeleteButton(tooltip: l.ruleDelete, onTap: _delete),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  key: const ValueKey('rule-save'),
                  onPressed: _ready ? _save : null,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: Text(l.ruleSaveButton),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Значение условия под строкой «Когда»: поле, тег с подсказками или пилюли одной строкой вбок.
  Widget _conditionValueField(L l, List<String> tags) {
    void changed() => setState(() {});
    return switch (_condition) {
      RuleConditionKind.hasTag => _TagField(key: const ValueKey('rule-value'), controller: _value, tags: tags, hint: l.ruleValueTagHint, onChanged: changed),
      RuleConditionKind.domain => TextField(
        key: const ValueKey('rule-value'),
        controller: _value,
        keyboardType: TextInputType.url,
        autocorrect: false,
        onChanged: (_) => changed(),
        decoration: InputDecoration(prefixIcon: Icon(symbolIcon('link')), hintText: l.ruleValueSiteHint),
      ),
      RuleConditionKind.keyword => TextField(
        key: const ValueKey('rule-value'),
        controller: _value,
        onChanged: (_) => changed(),
        decoration: InputDecoration(prefixIcon: Icon(symbolIcon('text_fields')), hintText: l.ruleValueWordHint),
      ),
      RuleConditionKind.priceAbove || RuleConditionKind.priceBelow => TextField(
        key: const ValueKey('rule-value'),
        controller: _value,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => changed(),
        decoration: InputDecoration(prefixIcon: Icon(symbolIcon('payments')), hintText: l.ruleValuePrice),
      ),
      RuleConditionKind.kind => _ChoiceRow(
        children: [
          for (final kind in ItemKind.values)
            _Choice(icon: kindIcon(kind), label: kindsLabel(l, kind), on: _kind == kind, onTap: () => setState(() => _kind = kind)),
        ],
      ),
      RuleConditionKind.pageType => _ChoiceRow(
        children: [
          for (final page in PageType.values) _Choice(label: pageTypeName(l, page), on: _page == page, onTap: () => _setPage(page)),
        ],
      ),
    };
  }
}

/// Правило фразой: значок условия, «Есть тег #работа» и под ней «→ в папку «Работа»».
/// [big] — в листе правила, крупнее и на подложке; в списке — строка карточки.
class RulePhrase extends StatelessWidget {
  const RulePhrase({super.key, required this.icon, required this.when, required this.then, this.big = false, this.muted = false});

  final String icon;
  final String when;
  final String then;
  final bool big;

  /// Правило выключено: фраза приглушена.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ink = muted ? Tokens.muted : Tokens.onSurface;
    final phrase = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: big ? 44 : 40,
          height: big ? 44 : 40,
          decoration: BoxDecoration(color: Tokens.containerHighest, shape: BoxShape.circle),
          child: Icon(symbolIcon(icon), size: 20, color: ink),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(when, style: (big ? text.titleMedium! : text.titleSmall!).copyWith(fontSize: big ? 17 : 15, fontWeight: FontWeight.w600, color: ink, height: 1.3)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 1), child: Icon(symbolIcon('subdirectory_arrow_right'), size: 18, color: Tokens.muted)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(then, style: text.bodyMedium!.copyWith(fontSize: big ? 15 : 14, color: muted ? Tokens.muted : Tokens.onSurfaceVariant, height: 1.35))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    if (!big) return phrase;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 16),
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.tile)),
      child: phrase,
    );
  }
}

/// Корзина круглой кнопкой рядом с «Сохранить»: словами «Удалить правило» не помещалось,
/// и «Сохранить» рвалась на две строки.
class SheetDeleteButton extends StatelessWidget {
  const SheetDeleteButton({super.key, required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Tokens.containerHigh,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(dimension: 52, child: Icon(symbolIcon('delete'), color: Tokens.error)),
        ),
      ),
    );
  }
}

/// «1 Когда», «2 Что сделать»: шаг с номером в кружке.
class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Tokens.containerHighest, shape: BoxShape.circle),
            child: Text('$number', style: style.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: Tokens.onSurface)),
          ),
          const SizedBox(width: 8),
          Text(text, style: style.titleSmall!.copyWith(fontWeight: FontWeight.w600, color: Tokens.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Строка выбора: значок, выбранное и стрелка вниз — касание открывает список.
class _StepButton extends StatelessWidget {
  const _StepButton({super.key, required this.icon, required this.title, required this.onTap, this.muted = false});

  final String icon;
  final String title;
  final VoidCallback onTap;

  /// Ещё ничего не выбрано: подпись приглушена.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Tokens.containerHigh,
      borderRadius: BorderRadius.circular(Radii.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Icon(symbolIcon(icon), size: 22, color: muted ? Tokens.muted : Tokens.onSurface),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall!.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: muted ? Tokens.muted : Tokens.onSurface),
                ),
              ),
              Icon(symbolIcon('unfold_more'), size: 20, color: Tokens.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Поле тега с «#» и подсказками своих тегов одной строкой вбок: имя не надо помнить.
class _TagField extends StatelessWidget {
  const _TagField({super.key, required this.controller, required this.tags, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final List<String> tags;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final typed = controller.text.trim().replaceFirst('#', '').toLowerCase();
    final shown = [for (final tag in tags) if (tag != typed && tag.contains(typed)) tag].take(12).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          autocorrect: false,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Text('#', style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Tokens.muted)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            hintText: hint,
          ),
        ),
        if (shown.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ChoiceRow(
            children: [
              for (final tag in shown)
                _Choice(
                  label: '#$tag',
                  on: false,
                  onTap: () {
                    controller.text = tag;
                    controller.selection = TextSelection.collapsed(offset: tag.length);
                    onChanged();
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Пилюли одной строкой вбок: на телефоне не растут столбиком вниз.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => Center(child: children[index]),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
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
      ),
    );
  }
}
