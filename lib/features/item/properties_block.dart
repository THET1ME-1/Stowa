import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../domain/note_properties.dart';
import '../../l10n/app_localizations.dart';

// больше строк блок сворачивает
const _shownRows = 4;

String _kindIcon(PropertyKind kind) => switch (kind) {
  PropertyKind.text => 'notes',
  PropertyKind.list => 'format_list_bulleted',
  PropertyKind.number => 'numbers',
  PropertyKind.checkbox => 'check_box',
  PropertyKind.date => 'calendar_today',
  PropertyKind.other => 'data_object',
};

String _kindName(L l, PropertyKind kind) => switch (kind) {
  PropertyKind.text || PropertyKind.other => l.propertyKindText,
  PropertyKind.list => l.propertyKindList,
  PropertyKind.number => l.propertyKindNumber,
  PropertyKind.checkbox => l.propertyKindCheckbox,
  PropertyKind.date => l.propertyKindDate,
};

String _dayLabel(L l, DateTime day) => DateFormat.yMMMMd(l.localeName).format(day);

/// Значение в строке блока: день по-человечески, галочка словом, список через запятую.
String _shown(L l, Object? value) {
  if (value is bool) return value ? l.propertyYes : l.propertyNo;
  final day = propertyDay(value);
  if (day != null) return _dayLabel(l, day);
  final text = propertyText(value, separator: ', ');
  return text.isEmpty ? '—' : text;
}

/// Лист свойства: новое или правка [name]. Возвращает набор после правки, закрыли без неё — null.
Future<Map<String, Object?>?> editProperty(BuildContext context, Map<String, Object?> properties, {String? name}) {
  return showModalBottomSheet<Map<String, Object?>>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Tokens.containerLow,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(top: false, child: _PropertySheet(properties: properties, name: name)),
    ),
  );
}

/// Свойства из файла заметки, которых Stowa не знает, как панель свойств в Obsidian.
class PropertiesBlock extends StatefulWidget {
  const PropertiesBlock({super.key, required this.properties, required this.onChanged});

  final Map<String, Object?> properties;
  final ValueChanged<Map<String, Object?>> onChanged;

  @override
  State<PropertiesBlock> createState() => _PropertiesBlockState();
}

class _PropertiesBlockState extends State<PropertiesBlock> {
  bool _open = false;

  Future<void> _edit([String? name]) async {
    final next = await editProperty(context, widget.properties, name: name);
    if (next == null) return;
    // новое встаёт в конец: под «Ещё» его не найти
    if (next.length > widget.properties.length && mounted) setState(() => _open = true);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final all = widget.properties.entries.toList();
    final hidden = all.length - _shownRows;
    final rows = _open || hidden <= 0 ? all : all.take(_shownRows);
    return Material(
      color: Tokens.container,
      borderRadius: BorderRadius.circular(Radii.card),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(symbolIcon('list_alt'), size: 20, color: Tokens.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text(l.propertiesTitle, style: text.titleSmall)),
                Text('${all.length}', style: TextStyle(fontSize: 13, color: Tokens.muted)),
              ],
            ),
            const SizedBox(height: 8),
            for (final entry in rows)
              InkWell(
                key: ValueKey('property-row-${entry.key}'),
                onTap: () => _edit(entry.key),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(symbolIcon(_kindIcon(propertyKind(entry.value))), size: 18, color: Tokens.muted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, height: 1.4, color: Tokens.muted)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: Text(_shown(l, entry.value), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, height: 1.35, color: Tokens.onSurface)),
                      ),
                    ],
                  ),
                ),
              ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton.icon(onPressed: _edit, icon: Icon(symbolIcon('add'), size: 18), label: Text(l.propertyAdd)),
                if (hidden > 0)
                  TextButton.icon(
                    onPressed: () => setState(() => _open = !_open),
                    icon: Icon(symbolIcon(_open ? 'expand_less' : 'expand_more'), size: 18),
                    label: Text(_open ? l.propertiesLess : l.propertiesMore(hidden)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertySheet extends ConsumerStatefulWidget {
  const _PropertySheet({required this.properties, this.name});

  final Map<String, Object?> properties;

  /// Имя свойства, которое правят; у нового его нет.
  final String? name;

  @override
  ConsumerState<_PropertySheet> createState() => _PropertySheetState();
}

class _PropertySheetState extends ConsumerState<_PropertySheet> {
  late final Object? _before;
  late PropertyKind _kind;
  late final TextEditingController _name;
  late final TextEditingController _text;
  bool _checked = false;
  String? _day;

  @override
  void initState() {
    super.initState();
    final before = widget.properties[widget.name];
    _before = before;
    _kind = propertyKind(before);
    _name = TextEditingController(text: widget.name ?? '');
    // галочка и день правятся не текстом: в поле их значению делать нечего
    _text = TextEditingController(text: before is bool || _kind == PropertyKind.date ? '' : propertyText(before));
    _checked = before == true;
    if (before is String && _kind == PropertyKind.date) _day = before;
  }

  @override
  void dispose() {
    _name.dispose();
    _text.dispose();
    super.dispose();
  }

  bool get _nameFree => propertyNameFree(_name.text, taken: {...widget.properties.keys}..remove(widget.name));

  /// Значение из того, что сейчас в листе; null — в поле числа стоит не число.
  ({Object? value})? get _typed {
    final typed = switch (_kind) {
      PropertyKind.checkbox => '$_checked',
      PropertyKind.date => _day ?? '',
      _ => _text.text,
    };
    // вложенное лист не правит: оно уходит обратно таким, каким пришло
    if (_kind == PropertyKind.other) return (value: _before);
    try {
      return (value: propertyValue(_kind, typed, previous: _before));
    } on FormatException {
      return null;
    }
  }

  void _save() {
    final typed = _typed;
    if (typed == null || !_nameFree) return;
    Navigator.pop(context, withProperty(widget.properties, was: widget.name, name: _name.text.trim(), value: typed.value));
  }

  /// Смена вида не теряет набранное: день переезжает в текст и обратно.
  void _setKind(PropertyKind kind) {
    setState(() {
      if (_kind == PropertyKind.date && _text.text.trim().isEmpty) _text.text = _day ?? '';
      if (kind == PropertyKind.date && propertyDay(_text.text.trim()) != null) _day = _text.text.trim();
      _kind = kind;
    });
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: propertyDay(_day) ?? ref.read(clockProvider)(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (picked != null && mounted) setState(() => _day = propertyDayText(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final ready = _nameFree && _typed != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.name == null ? l.propertyNew : l.propertyEdit, style: text.labelMedium!.copyWith(color: Tokens.muted)),
          TextField(
            key: const ValueKey('property-name-field'),
            controller: _name,
            autofocus: widget.name == null,
            textInputAction: TextInputAction.next,
            style: text.titleLarge!.copyWith(fontFamily: 'Unbounded', fontWeight: FontWeight.w700, fontSize: 22),
            decoration: InputDecoration.collapsed(hintText: l.propertyNameHint),
            onChanged: (_) => setState(() {}),
          ),
          if (_name.text.trim().isNotEmpty && !_nameFree)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l.propertyNameTaken, style: TextStyle(fontSize: 13, color: Tokens.error)),
            ),
          const SizedBox(height: 20),
          if (_kind != PropertyKind.other) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in const [PropertyKind.text, PropertyKind.list, PropertyKind.number, PropertyKind.checkbox, PropertyKind.date])
                  _KindChip(icon: _kindIcon(kind), label: _kindName(l, kind), on: kind == _kind, onTap: () => _setKind(kind)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          ..._editor(l),
          const SizedBox(height: 16),
          FilledButton(onPressed: ready ? _save : null, child: Text(l.save)),
          if (widget.name case final name?) ...[
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Tokens.error),
              onPressed: () => Navigator.pop(context, withoutProperty(widget.properties, name)),
              child: Text(l.propertyDelete),
            ),
          ],
        ],
      ),
    );
  }

  /// Чем правят значение: зависит от вида свойства.
  List<Widget> _editor(L l) {
    switch (_kind) {
      case PropertyKind.text || PropertyKind.list || PropertyKind.number:
        final number = _kind == PropertyKind.number;
        return [
          TextField(
            key: const ValueKey('property-value-field'),
            controller: _text,
            minLines: number ? 1 : 2,
            maxLines: number ? 1 : 6,
            keyboardType: number ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.multiline,
            decoration: InputDecoration(
              hintText: _kind == PropertyKind.list ? l.propertyListHint : l.propertyValueHint,
              errorText: _typed == null ? l.propertyNumberWrong : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ];
      case PropertyKind.checkbox:
        return [
          _Tile(
            child: SwitchListTile(
              title: Text(_checked ? l.propertyYes : l.propertyNo),
              value: _checked,
              onChanged: (value) => setState(() => _checked = value),
            ),
          ),
        ];
      case PropertyKind.date:
        final day = propertyDay(_day);
        return [
          _Tile(
            child: ListTile(
              leading: Icon(symbolIcon('calendar_today')),
              title: Text(day == null ? l.propertyDatePick : _dayLabel(l, day)),
              onTap: _pickDay,
            ),
          ),
        ];
      case PropertyKind.other:
        return [
          _Tile(
            child: Padding(
              padding: const EdgeInsets.all(Space.screen),
              child: SelectableText(propertyText(_before), style: TextStyle(fontSize: 14, height: 1.4, color: Tokens.onSurfaceVariant)),
            ),
          ),
          const SizedBox(height: 8),
          Text(l.propertyOtherHint, style: TextStyle(fontSize: 13, height: 1.35, color: Tokens.muted)),
        ];
    }
  }
}

/// Подложка строки листа: переключатель, день, вложенное значение.
class _Tile extends StatelessWidget {
  const _Tile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.tile), clipBehavior: Clip.antiAlias, child: child);
  }
}

/// Чип вида свойства: белый — выбран.
class _KindChip extends StatelessWidget {
  const _KindChip({required this.icon, required this.label, required this.on, required this.onTap});

  final String icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = on ? Tokens.onAccent : Tokens.onSurface;
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.short,
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: on ? Tokens.accent : Tokens.containerHigh, borderRadius: BorderRadius.circular(18)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(symbolIcon(icon), size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
