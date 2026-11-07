import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';

/// Цвет значков группы из палитры папок: разделы различаются с первого взгляда.
Color settingsTint(String key) => FolderPalette.colors[key]!;

/// Заголовок раздела заглавными.
class SettingsSection extends StatelessWidget {
  const SettingsSection(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 26, 8, 10),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium!.copyWith(color: Tokens.onSurfaceVariant, fontWeight: FontWeight.w700, letterSpacing: 1.1),
      ),
    );
  }
}

/// Каждая строка — свой блок: крайние скруглены крупно, средние слегка, между ними щель.
/// [tint] — цвет круглых значков всей группы, из палитры папок.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.tint, required this.children});

  final Color tint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const outer = Radius.circular(Radii.card);
    const inner = Radius.circular(8);
    return _GroupTint(
      color: tint,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 4),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: index == 0 ? outer : inner, bottom: index == children.length - 1 ? outer : inner),
                child: children[index],
              ),
            ),
        ],
      ),
    );
  }
}

/// Цвет значков группы для её строк.
class _GroupTint extends InheritedWidget {
  const _GroupTint({required this.color, required super.child});

  final Color color;

  static Color of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_GroupTint>()?.color ?? Tokens.onSurface;

  @override
  bool updateShouldNotify(_GroupTint old) => old.color != color;
}

/// Круглый значок строки: цвет группы на его же приглушённой подложке.
class SettingsIconChip extends StatelessWidget {
  const SettingsIconChip(this.icon, {super.key, this.color});

  final String icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? _GroupTint.of(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: FolderPalette.tint(tint, 0.22), shape: BoxShape.circle),
      child: Icon(symbolIcon(icon, filled: true), size: 22, color: FolderPalette.ink(tint)),
    );
  }
}

/// Заголовок строки крупно, значение подписью под ним.
class _RowText extends StatelessWidget {
  const _RowText({required this.title, this.value});

  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
        if (value != null) ...[
          const SizedBox(height: 2),
          Text(value!, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
        ],
      ],
    );
  }
}

/// Строка-переход: значок, название, значение подписью, стрелка.
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.icon, required this.title, this.value, required this.onTap});

  final String icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tokens.containerHigh,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              SettingsIconChip(icon),
              const SizedBox(width: 16),
              Expanded(child: _RowText(title: title, value: value)),
              const SizedBox(width: 8),
              Icon(symbolIcon('chevron_right'), size: 22, color: Tokens.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка с переключателем: касание по всей строке переключает.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({super.key, required this.icon, required this.title, this.subtitle, required this.value, required this.onChanged});

  final String icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tokens.containerHigh,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              SettingsIconChip(icon),
              const SizedBox(width: 16),
              Expanded(child: _RowText(title: title, value: subtitle)),
              const SizedBox(width: 8),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Круглая кнопка шапки экрана.
class SettingsRoundButton extends StatelessWidget {
  const SettingsRoundButton({super.key, required this.icon, required this.tooltip, required this.onTap});

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
          decoration: BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
          child: Icon(symbolIcon(icon), color: Tokens.onSurface),
        ),
      ),
    );
  }
}

/// Шапка экрана настроек: «назад» и название.
class SettingsHeader extends StatelessWidget {
  const SettingsHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SettingsRoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.pop(context)),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge!.copyWith(fontSize: 22))),
      ],
    );
  }
}
