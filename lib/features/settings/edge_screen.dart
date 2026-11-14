import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../domain/edge_settings.dart';
import '../../l10n/app_localizations.dart';
import 'settings_blocks.dart';

Route<void> edgeRoute() => settingsPageRoute(const EdgeScreen());

/// Итог для строки в настройках: «Справа · обычные» или «Выключено».
String edgeSummary(L l, EdgeSettings settings) =>
    settings.enabled ? '${settings.side == EdgeSide.left ? l.edgeLeft : l.edgeRight} · ${spineSizeLabel(l, settings.size)}' : l.edgeOff;

String spineSizeLabel(L l, SpineSize size) => switch (size) {
  SpineSize.thin => l.edgeThin,
  SpineSize.normal => l.edgeNormal,
  SpineSize.large => l.edgeLarge,
};

/// «Под рукой»: корешки закреплённых заметок у края поверх любого приложения. Включены —
/// любая правка сразу видна на настоящих корешках у края экрана, они плавно переезжают.
class EdgeScreen extends ConsumerStatefulWidget {
  const EdgeScreen({super.key});

  @override
  ConsumerState<EdgeScreen> createState() => _EdgeScreenState();
}

class _EdgeScreenState extends ConsumerState<EdgeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // вернулись из настроек системы: право могли выдать — включатель включится сам
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.read(edgeControlProvider).resumed().ignore();
  }

  Future<void> _change(EdgeSettings next) {
    HapticFeedback.selectionClick();
    return ref.read(edgeControlProvider).change(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final settings = ref.watch(edgeSettingsProvider).value ?? const EdgeSettings();
    final control = ref.read(edgeControlProvider);
    final heightLabel = settings.height < 34 ? l.edgeHigher : (settings.height > 66 ? l.edgeLower : l.edgeMiddle);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            SettingsHeader(l.edgeTitle),
            const SizedBox(height: 14),
            SettingsGroup(
              tint: settingsTint('sky'),
              children: [
                SettingsSwitchRow(
                  key: const ValueKey('edge-switch'),
                  icon: 'view_sidebar',
                  title: l.edgeSwitch,
                  subtitle: l.edgeSwitchHint,
                  value: settings.enabled,
                  onChanged: (on) => on ? control.enable() : control.disable(),
                ),
              ],
            ),
            SettingsSection(l.edgePlace),
            _Block(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SideChoice(
                        key: const ValueKey('edge-side-left'),
                        label: l.edgeLeft,
                        selected: settings.side == EdgeSide.left,
                        onTap: () => _change(settings.copyWith(side: EdgeSide.left)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _SideChoice(
                        key: const ValueKey('edge-side-right'),
                        label: l.edgeRight,
                        selected: settings.side == EdgeSide.right,
                        onTap: () => _change(settings.copyWith(side: EdgeSide.right)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SliderRow(
                  key: const ValueKey('edge-height'),
                  label: l.edgeHeight,
                  value: heightLabel,
                  slider: Slider(
                    value: settings.height.toDouble(),
                    max: 100,
                    onChanged: (value) => ref.read(edgeControlProvider).change(settings.copyWith(height: value.round())),
                  ),
                ),
                _SliderRow(
                  key: const ValueKey('edge-size'),
                  label: l.edgeSize,
                  value: spineSizeLabel(l, settings.size),
                  slider: Slider(
                    value: settings.size.index.toDouble(),
                    max: SpineSize.values.length - 1.0,
                    divisions: SpineSize.values.length - 1,
                    onChanged: (value) => _change(settings.copyWith(size: SpineSize.values[value.round()])),
                  ),
                ),
                _SliderRow(
                  key: const ValueKey('edge-alpha'),
                  label: l.edgeAlpha,
                  value: '${settings.alpha} %',
                  slider: Slider(
                    value: settings.alpha.toDouble(),
                    min: 40,
                    max: 100,
                    onChanged: (value) => ref.read(edgeControlProvider).change(settings.copyWith(alpha: value.round())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SettingsGroup(
              tint: settingsTint('sky'),
              children: [
                SettingsSwitchRow(
                  icon: 'fullscreen',
                  title: l.edgeHideVideo,
                  subtitle: l.edgeHideVideoHint,
                  value: settings.hideInFullscreen,
                  onChanged: (on) => _change(settings.copyWith(hideInFullscreen: on)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.card)),
      // дорожка ползунка видна и в невыбранной части: на блоке она сливалась с фоном
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(activeTrackColor: Tokens.accent, inactiveTrackColor: Tokens.outline, thumbColor: Tokens.accent),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

/// «Слева» и «Справа»: выбранное — белая плашка, как выбор темы на «Оформлении».
class _SideChoice extends StatelessWidget {
  const _SideChoice({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge!;
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.96,
        child: AnimatedContainer(
          duration: Motion.short,
          curve: Motion.emphasized,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? Tokens.accent : Tokens.containerHighest, borderRadius: BorderRadius.circular(selected ? 16 : 100)),
          child: Text(label, style: style.copyWith(color: selected ? Tokens.onAccent : Tokens.onSurfaceVariant)),
        ),
      ),
    );
  }
}

/// Подпись и значение над ползунком.
class _SliderRow extends StatelessWidget {
  const _SliderRow({super.key, required this.label, required this.value, required this.slider});

  final String label;
  final String value;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(child: Text(label, style: text.bodyLarge!.copyWith(color: Tokens.onSurfaceVariant))),
              Text(value, style: text.bodyLarge!.copyWith(color: Tokens.onSurface)),
            ],
          ),
        ),
        slider,
      ],
    );
  }
}
