import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/color_picker_sheet.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../domain/appearance.dart';
import '../../l10n/app_localizations.dart';
import 'settings_blocks.dart';

Route<void> appearanceRoute() => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => const AppearanceScreen(),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

String themeChoiceLabel(L l, ThemeChoice choice) => switch (choice) {
  ThemeChoice.light => l.themeLight,
  ThemeChoice.dark => l.themeDark,
  ThemeChoice.system => l.themeSystem,
  ThemeChoice.byTime => l.themeByTime,
};

/// «Тёмная · Графит» — подпись строки «Оформление» в настройках.
String appearanceSummary(L l, Appearance appearance) {
  final color = appearance.wallpaper
      ? l.colorFromWallpaper
      : appearance.seed == null
      ? l.colorGraphite
      : l.colorCustom;
  return '${themeChoiceLabel(l, appearance.choice)} · $color';
}

const _modeIcons = {
  ThemeChoice.light: 'light_mode',
  ThemeChoice.dark: 'dark_mode',
  ThemeChoice.system: 'brightness_auto',
  ThemeChoice.byTime: 'schedule',
};

/// «Оформление»: режим темы, цвет и насыщенность, обои, чёрный фон. Всё
/// применяется сразу, экран перекрашивается вместе с приложением.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final appearance = ref.watch(appearanceProvider).value ?? const Appearance();
    final wallpaperAvailable = ref.watch(wallpaperProvider).value != null;
    final usesWallpaper = appearance.wallpaper && wallpaperAvailable;
    Future<void> save(Appearance value) {
      HapticFeedback.selectionClick();
      return ref.read(settingsRepositoryProvider).setAppearance(value);
    }

    final hintStyle = text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            SettingsHeader(l.appearanceTitle),
            SettingsSection(l.appearanceTheme),
            _Block(
              children: [
                Row(
                  children: [
                    for (final (index, choice) in ThemeChoice.values.indexed) ...[
                      if (index > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _ModeButton(
                          key: ValueKey('mode-${choice.name}'),
                          icon: _modeIcons[choice]!,
                          label: themeChoiceLabel(l, choice),
                          selected: appearance.choice == choice,
                          onTap: () => save(appearance.copyWith(choice: choice)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(themeChoiceLabel(l, appearance.choice), style: text.titleMedium),
                if (appearance.choice == ThemeChoice.byTime) ...[const SizedBox(height: 2), Text(l.themeByTimeHint, style: hintStyle)],
              ],
            ),
            if (!usesWallpaper) ...[
              SettingsSection(l.appearanceColor),
              _Block(
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _GraphiteSwatch(key: const ValueKey('seed-graphite'), selected: appearance.seed == null, onTap: () => save(appearance.copyWith(seed: () => null))),
                      for (final (index, seed) in kThemeSeeds.indexed)
                        _SeedSwatch(
                          key: ValueKey('seed-$index'),
                          seed: seed,
                          selected: appearance.seed == seed.toARGB32(),
                          onTap: () => save(appearance.copyWith(seed: () => seed.toARGB32())),
                        ),
                      _CustomSwatch(
                        key: const ValueKey('seed-custom'),
                        seed: appearance.seed == null || kThemeSeeds.any((seed) => seed.toARGB32() == appearance.seed) ? null : Color(appearance.seed!),
                        tooltip: l.colorCustom,
                        onTap: () async {
                          final picked = await showColorPickerSheet(context, initial: Color(appearance.seed ?? 0xFF92BFFF), title: l.colorCustom);
                          if (picked != null) await save(appearance.copyWith(seed: () => picked.toARGB32()));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    appearance.seed == null
                        ? l.colorGraphite
                        : kThemeSeeds.any((seed) => seed.toARGB32() == appearance.seed)
                        ? l.appearanceColor
                        : l.colorCustom,
                    style: text.titleMedium,
                  ),
                  if (appearance.seed != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _TextChoice(
                            key: const ValueKey('intensity-vibrant'),
                            label: l.intensityVibrant,
                            selected: appearance.vibrant,
                            onTap: () => save(appearance.copyWith(vibrant: true)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _TextChoice(
                            key: const ValueKey('intensity-faithful'),
                            label: l.intensityFaithful,
                            selected: !appearance.vibrant,
                            onTap: () => save(appearance.copyWith(vibrant: false)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(l.intensityHint, style: hintStyle),
                  ],
                ],
              ),
            ],
            if (wallpaperAvailable || Tokens.palette.isDark) ...[
              const SizedBox(height: 8),
              SettingsGroup(
                tint: settingsTint('rose'),
                children: [
                  if (wallpaperAvailable)
                    SettingsSwitchRow(
                      icon: 'wallpaper',
                      title: l.wallpaperColors,
                      subtitle: l.wallpaperColorsHint,
                      value: appearance.wallpaper,
                      onChanged: (on) => save(appearance.copyWith(wallpaper: on)),
                    ),
                  if (Tokens.palette.isDark)
                    SettingsSwitchRow(
                      icon: 'contrast',
                      title: l.amoledTitle,
                      subtitle: l.amoledHint,
                      value: appearance.amoled,
                      onChanged: (on) => save(appearance.copyWith(amoled: on)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Блок раздела: та же ступень и скругление, что у групп настроек.
class _Block extends StatelessWidget {
  const _Block({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

/// Кнопка режима: значок в пилюле, выбранная залита акцентом.
class _ModeButton extends StatelessWidget {
  const _ModeButton({super.key, required this.icon, required this.label, required this.selected, required this.onTap});

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.short,
            curve: Motion.emphasized,
            height: 52,
            decoration: BoxDecoration(color: selected ? Tokens.accent : Tokens.containerHighest, borderRadius: BorderRadius.circular(selected ? 18 : 100)),
            child: Icon(symbolIcon(icon, filled: selected), size: 24, color: selected ? Tokens.onAccent : Tokens.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// Выбор словом: «Сочно» или «Точь-в-точь».
class _TextChoice extends StatelessWidget {
  const _TextChoice({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.short,
          curve: Motion.emphasized,
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: selected ? Tokens.accent : Tokens.containerHighest, borderRadius: BorderRadius.circular(selected ? 16 : 100)),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(color: selected ? Tokens.onAccent : Tokens.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// Круг образца с кольцом и галочкой у выбранного.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.selected, required this.onTap, required this.child, this.tooltip});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String? tooltip;

  static const size = 48.0;

  @override
  Widget build(BuildContext context) {
    final swatch = Pressable(
      onTap: onTap,
      pressedScale: 0.9,
      child: AnimatedContainer(
        duration: Motion.short,
        width: size,
        height: size,
        padding: EdgeInsets.all(selected ? 4 : 0),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? Tokens.onSurface : Colors.transparent, width: 2.5)),
        child: ClipOval(child: child),
      ),
    );
    return Semantics(button: true, selected: selected, child: tooltip == null ? swatch : Tooltip(message: tooltip, child: swatch));
  }
}

/// «Графит»: тёмная и светлая половины — серый в обеих темах.
class _GraphiteSwatch extends StatelessWidget {
  const _GraphiteSwatch({super.key, required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Swatch(
      selected: selected,
      onTap: onTap,
      tooltip: L.of(context).colorGraphite,
      child: CustomPaint(painter: _QuadrantPainter([StowaPalette.graphiteLight.containerHighest, StowaPalette.graphiteDark.accent, StowaPalette.graphiteDark.graphite, StowaPalette.graphiteDark.containerHigh])),
    );
  }
}

/// Цвет четырьмя долями схемы от него: светлая и насыщенная, два оттенка.
class _SeedSwatch extends StatelessWidget {
  const _SeedSwatch({super.key, required this.seed, required this.selected, required this.onTap});

  final Color seed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return _Swatch(
      selected: selected,
      onTap: onTap,
      child: CustomPaint(painter: _QuadrantPainter([scheme.primaryContainer, scheme.primary, scheme.tertiaryContainer, scheme.tertiary])),
    );
  }
}

/// «Свой цвет»: пипетка, а когда свой цвет выбран — круг этого цвета.
class _CustomSwatch extends StatelessWidget {
  const _CustomSwatch({super.key, required this.seed, required this.tooltip, required this.onTap});

  final Color? seed;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = seed ?? Tokens.containerHighest;
    return _Swatch(
      selected: seed != null,
      onTap: onTap,
      tooltip: tooltip,
      child: ColoredBox(
        color: fill,
        child: Center(child: Icon(symbolIcon('colorize'), size: 22, color: seed == null ? Tokens.onSurfaceVariant : inkOn(fill))),
      ),
    );
  }
}

class _QuadrantPainter extends CustomPainter {
  _QuadrantPainter(this.colors);

  /// Слева сверху, справа сверху, слева снизу, справа снизу.
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final half = Size(size.width / 2, size.height / 2);
    for (final (index, color) in colors.indexed) {
      final origin = Offset(index.isOdd ? half.width : 0, index >= 2 ? half.height : 0);
      canvas.drawRect(origin & half, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_QuadrantPainter old) => !listEquals(old.colors, colors);
}
