import 'package:flutter/material.dart';

import '../icons/icon_registry.dart';
import '../theme/tokens.dart';

/// Листы снизу со списком — как меню «⋮» заметки: каждая строка свой блок, круглый значок,
/// подпись крупно. Устройство — `docs/specs/2026-11-13-sheet-options-design.md`.

const _outer = Radius.circular(24);
const _inner = Radius.circular(8);

/// Строка листа выбора: значение, подпись и то, что в круге.
class SheetChoice<T> {
  const SheetChoice({required this.value, required this.title, this.icon, this.mark, this.subtitle, this.badges = const [], this.danger = false});

  final T value;
  final String title;

  /// Значок в круге по имени из набора; без значка — [mark].
  final String? icon;

  /// Короткая надпись в круге, если значка по смыслу нет: «Пн», «RU», «150».
  final String? mark;
  final String? subtitle;

  /// Мелкие метки под подписью: «бесплатно», «картинки».
  final List<String> badges;
  final bool danger;
}

/// Лист со строками на выбор: касание отдаёт значение и закрывает лист, смахнули — null.
/// [selected] отмечается галочкой.
Future<T?> showOptionsSheet<T>(BuildContext context, {String? title, required List<SheetChoice<T>> options, T? selected}) {
  return showOptionsSheetWith<T>(
    context,
    (sheet) => SheetOptionsBody(
      title: title,
      children: [
        for (final option in options)
          SheetOption(
            title: option.title,
            icon: option.icon,
            mark: option.mark,
            subtitle: option.subtitle,
            badges: option.badges,
            danger: option.danger,
            selected: selected != null && option.value == selected,
            onTap: () => Navigator.pop(sheet, option.value),
          ),
      ],
    ),
  );
}

/// Тот же лист со своим содержимым: поиск над строками, строки из базы.
Future<T?> showOptionsSheetWith<T>(BuildContext context, Widget Function(BuildContext sheet) builder) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Tokens.container,
  builder: (sheet) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.75),
      child: SafeArea(top: false, child: builder(sheet)),
    ),
  ),
);

/// Заголовок и строки блоками; листается, если не помещается.
class SheetOptionsBody extends StatelessWidget {
  const SheetOptionsBody({super.key, this.title, this.top, required this.children});

  final String? title;

  /// Над строками и не листается с ними: поле поиска.
  final Widget? top;
  final List<SheetOption> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title case final title?) Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), child: SheetTitle(title)),
        if (top case final top?) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), child: top),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: SheetOptions(children: children),
          ),
        ),
      ],
    );
  }
}

/// Бледный заголовок листа одной строкой: «Сдать кровь».
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Tokens.muted));
}

/// Строки блоками со щелью 4: у первой скруглён верх, у последней низ.
class SheetOptions extends StatelessWidget {
  const SheetOptions({super.key, required this.children});

  final List<SheetOption> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const SizedBox(height: 4),
          child.withRadius(sheetRowRadius(index, children.length)),
        ],
      ],
    );
  }
}

/// Строка-блок: круглый значок (или надпись), подпись, бледная подпись и метки, галочка у выбранного.
class SheetOption extends StatelessWidget {
  const SheetOption({
    super.key,
    required this.title,
    this.icon,
    this.mark,
    this.leading,
    this.subtitle,
    this.badges = const [],
    this.selected = false,
    this.danger = false,
    this.radius = const BorderRadius.all(_inner),
    required this.onTap,
  });

  final String title;
  final String? icon;
  final String? mark;

  /// Свой круг вместо значка: значок папки, тега.
  final Widget? leading;
  final String? subtitle;
  final List<String> badges;
  final bool selected;
  final bool danger;
  final BorderRadius radius;
  final VoidCallback? onTap;

  SheetOption withRadius(BorderRadius radius) => SheetOption(
    key: key,
    title: title,
    icon: icon,
    mark: mark,
    leading: leading,
    subtitle: subtitle,
    badges: badges,
    selected: selected,
    danger: danger,
    radius: radius,
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ink = danger ? Tokens.error : Tokens.onSurface;
    final circleInk = selected ? Tokens.onAccent : ink;
    final circle = selected ? Tokens.accent : (danger ? Tokens.error.withValues(alpha: 0.14) : Tokens.graphite);
    return Material(
      color: Tokens.containerHigh,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
          child: Row(
            children: [
              leading ??
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
                    child: icon != null
                        ? Icon(symbolIcon(icon!, filled: selected), size: 20, color: circleInk)
                        : Text(mark ?? title.characters.take(1).toString().toUpperCase(), style: text.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: circleInk)),
                  ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink)),
                    if (subtitle case final subtitle?)
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: Tokens.muted)),
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final badge in badges)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Tokens.graphite, borderRadius: BorderRadius.circular(100)),
                              child: Text(badge, style: text.labelSmall!.copyWith(color: Tokens.onSurfaceVariant)),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(symbolIcon('check'), key: const ValueKey('sheet-check'), size: 22, color: Tokens.onSurface),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Скругление строки [index] из [count] для длинных списков, которые строятся по мере прокрутки.
BorderRadius sheetRowRadius(int index, int count) => BorderRadius.vertical(top: index == 0 ? _outer : _inner, bottom: index == count - 1 ? _outer : _inner);

/// «понедельник» → «Понедельник»: в листах и строках подписи с заглавной.
String capitalized(String text) => text.isEmpty ? text : text.characters.first.toUpperCase() + text.characters.skip(1).toString();
