import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../data/repositories/items_repository.dart' show ItemCard;
import '../../domain/edge_settings.dart';
import '../../domain/spine_colors.dart';
import '../../l10n/app_localizations.dart';
import 'edge_preview.dart';
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
    final text = Theme.of(context).textTheme;
    // те же корешки, что служба получает от полки: цвета папок закреплённых, под замком — один
    final pinned = ref.watch(pinnedItemsProvider).value ?? const <ItemCard>[];
    final lock = ref.watch(privacyLockProvider).value ?? ref.read(startLockProvider);
    final spines = spinesFor(
      [for (final card in pinned) (color: card.folderColor, length: card.title.length + card.body.length)],
      locked: lock?.appLock ?? false,
      plain: Tokens.muted,
      accent: Tokens.accent,
    );

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
            SettingsSection(l.edgeLook),
            _Block(
              children: [
                EdgePreview(
                  settings: settings,
                  spines: spines,
                  screen: MediaQuery.sizeOf(context),
                  heightLabel: (height) => _heightLabel(l, height),
                  onHeight: (height) => _change(settings.copyWith(height: height)),
                ),
                const SizedBox(height: 10),
                Text(l.edgeDragHint, textAlign: TextAlign.center, style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    for (final (index, side) in EdgeSide.values.indexed) ...[
                      if (index > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _SideChoice(
                          key: ValueKey('edge-side-${side.name}'),
                          label: side == EdgeSide.left ? l.edgeLeft : l.edgeRight,
                          selected: settings.side == side,
                          onTap: () => _change(settings.copyWith(side: side)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final (index, size) in SpineSize.values.indexed) ...[
                      if (index > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _SizeChoice(
                          key: ValueKey('edge-size-${size.name}'),
                          size: size,
                          spines: spines,
                          label: _sentence(spineSizeLabel(l, size)),
                          selected: settings.size == size,
                          onTap: () => _change(settings.copyWith(size: size)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                _SliderRow(
                  key: const ValueKey('edge-alpha'),
                  label: l.edgeAlpha,
                  value: '${settings.alpha} %',
                  slider: Slider(
                    // дорожка от края до края блока, ровно под подписью
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
            SettingsSection(l.edgeGestures),
            SettingsGroup(
              tint: settingsTint('violet'),
              children: [
                SettingsSwitchRow(
                  key: const ValueKey('edge-gesture-swipe'),
                  icon: 'keyboard',
                  title: l.edgeGestureSwipe,
                  subtitle: l.edgeGestureSwipeHint,
                  value: settings.swipeDownTypes,
                  onChanged: (on) => _change(settings.copyWith(swipeDownTypes: on)),
                ),
                SettingsSwitchRow(
                  key: const ValueKey('edge-gesture-hold'),
                  icon: 'mic',
                  title: l.edgeGestureHold,
                  subtitle: l.edgeGestureHoldHint,
                  value: settings.holdRecords,
                  onChanged: (on) => _change(settings.copyWith(holdRecords: on)),
                ),
                SettingsSwitchRow(
                  key: const ValueKey('edge-gesture-double'),
                  icon: 'history',
                  title: l.edgeGestureDouble,
                  subtitle: l.edgeGestureDoubleHint,
                  value: settings.doubleTapLast,
                  onChanged: (on) => _change(settings.copyWith(doubleTapLast: on)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Высота корешков словом: верхняя треть — «выше», нижняя — «ниже».
String _heightLabel(L l, int height) => height < 34 ? l.edgeHigher : (height > 66 ? l.edgeLower : l.edgeMiddle);

/// «тонкие» → «Тонкие»: на кнопке слово стоит само по себе.
String _sentence(String word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);

/// Кнопка размера: корешки этой толщины и длины, нарисованные как на экране, и слово под ними.
class _SizeChoice extends StatelessWidget {
  const _SizeChoice({super.key, required this.size, required this.spines, required this.label, required this.selected, required this.onTap});

  final SpineSize size;
  final List<Spine> spines;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.96,
        child: AnimatedContainer(
          duration: Motion.short,
          curve: Motion.emphasized,
          height: 116,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          decoration: BoxDecoration(color: selected ? Tokens.accent : Tokens.containerHighest, borderRadius: BorderRadius.circular(selected ? 18 : 28)),
          child: Column(
            children: [
              Expanded(child: CustomPaint(size: Size.infinite, painter: _SizeGlyph(size: size, spines: spines))),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge!.copyWith(color: selected ? Tokens.onAccent : Tokens.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Корешки размера [size] в одном масштабе для всех трёх кнопок: разница видна сразу.
class _SizeGlyph extends CustomPainter {
  _SizeGlyph({required this.size, required this.spines});

  final SpineSize size;
  final List<Spine> spines;

  @override
  void paint(Canvas canvas, Size area) {
    // крупные — во всю высоту кнопки, остальные в том же масштабе; толщина нагляднее в 2,2 раза
    final unit = area.height / SpineSize.large.height;
    const thicker = 2.2;
    final width = size.width * unit * thicker;
    final tall = size.height * unit;
    final rect = Rect.fromLTWH(area.width / 2 - width / 2, area.height - tall, width, tall);
    paintSpineHandle(canvas, rect, right: true, spines: spines, alpha: 1, unit: unit, across: unit * thicker);
  }

  @override
  bool shouldRepaint(_SizeGlyph old) => old.size != size || old.spines != spines;
}

class _Block extends StatelessWidget {
  const _Block({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
        Row(
          children: [
            Expanded(child: Text(label, style: text.titleMedium)),
            Text(value, style: text.titleMedium!.copyWith(color: Tokens.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
        slider,
      ],
    );
  }
}
