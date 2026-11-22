import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/icons/icon_words.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/desk_mode.dart';
import '../../core/widgets/color_picker_sheet.dart';
import '../../core/widgets/shape_badge.dart';
import '../../data/repositories/folders_repository.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_blocks.dart';

typedef FolderLook = ({String name, String icon, String shape, String? color});

/// Экран «Цвет и значок» вырастает из нажатой кнопки и отдаёт выбранное или null.
Route<FolderLook> folderLookRoute(FolderCard folder) => MaterialPageRoute(builder: (_) => FolderLookScreen(folder: folder));

// весь набор один раз: тысячи имён не пересобираются на каждый кадр;
// «10k», «4g» и прочие цифры уходят в конец, иначе набор начинается с них
final List<String> _allIcons = [
  ...symbolNames.where((name) => !name.startsWith(RegExp('[0-9]'))),
  ...symbolNames.where((name) => name.startsWith(RegExp('[0-9]'))),
];

/// Ширина, с которой образец и цвета встают слева, а иконки справа.
const _wideFrom = 720.0;

/// Ширина колонки на широком экране: и поля, и «Сохранить».
const _columnWidth = 520.0;

/// Последние цвета папок в настройках: ключи палитры или `#RRGGBB`.
const _recentKey = 'folder_recent_colors';

/// Пока своих последних нет: пять разных оттенков палитры.
const _starterColors = ['coral', 'amber', 'mint', 'sky', 'violet'];

/// Цвет, форма и иконка папки. Наверху живой образец, как папка выглядит на главной;
/// иконки идут одной лентой с остальным: под имя, частые, потом весь набор.
class FolderLookScreen extends StatefulWidget {
  const FolderLookScreen({super.key, required this.folder});

  final FolderCard folder;

  @override
  State<FolderLookScreen> createState() => _FolderLookScreenState();
}

class _FolderLookScreenState extends State<FolderLookScreen> {
  late String _icon = widget.folder.icon;
  late String _shape = widget.folder.shape;
  late String? _color = widget.folder.colorKey;
  late final _name = TextEditingController(text: widget.folder.name);

  /// Пять последних цветов, которые ставили папкам; пока их нет — пять разных из палитры.
  List<String> _recent = _starterColors;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getStringList(_recentKey);
      if (saved != null && saved.isNotEmpty && mounted) setState(() => _recent = saved);
    } on Object {
      // без настроек (тесты, сбой диска) строка живёт на палитре
    }
  }

  /// Выбранный цвет — первым в последних, без повторов, не больше пяти.
  Future<void> _rememberColor() async {
    final key = _color;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentKey, [key, ..._recent.where((one) => one != key)].take(5).toList());
    } on Object {
      // не запомнилось — не беда, папка уже сохранена
    }
  }

  /// Своё в строке: нынешний цвет папки первым, дальше последние — всего пять.
  List<String> get _row {
    final current = _color ?? FolderPalette.colors.keys.elementAt(widget.folder.order % FolderPalette.colors.length);
    return [current, ..._recent.where((key) => key != current && FolderPalette.of(key, 0) != FolderPalette.of(current, 0))].take(5).toList();
  }

  Future<void> _pickOnWheel(L l) async {
    final picked = await showColorPickerSheet(context, initial: _fill, title: l.lookColor);
    if (picked == null || !mounted) return;
    final key = FolderPalette.colors.entries.where((entry) => entry.value.toARGB32() == picked.toARGB32()).firstOrNull?.key ?? FolderPalette.keyOf(picked);
    _pick(() => _color = key);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  late final List<String> _forName = searchIcons(widget.folder.name, limit: 18);

  Color get _fill => FolderPalette.of(_color, widget.folder.order);

  BadgeShape get _badgeShape => BadgeShape.values.asNameMap()[_shape] ?? BadgeShape.squircle;

  void _pick(VoidCallback change) {
    HapticFeedback.selectionClick();
    setState(change);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      key: const ValueKey('folder-look'),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 6),
              child: Row(
                children: [
                  SettingsRoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.folderEdit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(fontSize: 22),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final list = ListView(
                    key: const ValueKey('look-scroll'),
                    padding: const EdgeInsets.fromLTRB(Space.screen, 8, Space.screen, 16),
                    children: _setup(l),
                  );
                  if (constraints.maxWidth < _wideFrom) return list;
                  // планшет и телефон боком: строки цвета, формы и иконок не тянутся во всю ширину
                  return Center(
                    key: const ValueKey('look-wide'),
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _columnWidth), child: list),
                  );
                },
              ),
            ),
            // под большим пальцем; на широком экране — по той же колонке, что поля, а не от
            // края до края (хозяин 22.11 про сайт: «широкая, не адаптированная»)
            LayoutBuilder(
              builder: (context, constraints) => Center(
                child: ConstrainedBox(
                  // та же мера, что у списка выше: ширина окна вкладки, а не всего экрана
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth < _wideFrom ? double.infinity : _columnWidth),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(Space.screen, 8, Space.screen, 12 + MediaQuery.paddingOf(context).bottom),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () {
                          _rememberColor().ignore();
                          Navigator.pop<FolderLook>(context, (name: _name.text, icon: _icon, shape: _shape, color: _color));
                        },
                        child: Text(l.save),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Образец, название, цвет и форма. Название здесь же: «Переименовать» и «Цвет и значок»
  /// были двумя пунктами меню об одном.
  List<Widget> _setup(L l) => [
    _Preview(name: _name.text.trim().isEmpty ? widget.folder.name : _name.text.trim(), icon: _icon, shape: _badgeShape, fill: _fill),
    const SizedBox(height: 20),
    TextField(
      key: const ValueKey('folder-name-field'),
      controller: _name,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: l.folderNameLabel),
      onChanged: (_) => setState(() {}),
    ),
    SettingsSection(l.lookColor),
    // одна строка: круг оттенков с любым цветом и пять последних. Двенадцать готовых кружков
    // в два ряда не давали своего цвета и занимали полэкрана
    Row(
      children: [
        Expanded(
          child: AspectRatio(aspectRatio: 1, child: _WheelButton(key: const ValueKey('color-wheel'), tooltip: l.colorCustom, onTap: () => _pickOnWheel(l))),
        ),
        for (final key in _row) ...[
          const SizedBox(width: 10),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: _Swatch(key: ValueKey('color-$key'), color: FolderPalette.of(key, 0), chosen: FolderPalette.of(key, 0) == _fill, onTap: () => _pick(() => _color = key)),
            ),
          ),
        ],
        for (var i = _row.length; i < 5; i++) ...[const SizedBox(width: 10), const Expanded(child: SizedBox())],
      ],
    ),
    SettingsSection(l.lookShape),
    Row(
      children: [
        for (final (index, shape) in BadgeShape.values.indexed) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: _ShapeChoice(
              key: ValueKey('shape-${shape.name}'),
              shape: shape,
              icon: _icon,
              fill: _fill,
              chosen: shape == _badgeShape,
              onTap: () => _pick(() => _shape = shape.name),
            ),
          ),
        ],
      ],
    ),
    SettingsSection(l.lookIcon),
    // одна строка, как у цвета: поиск по всему набору и пять иконок под рукой
    Row(
      children: [
        Expanded(
          child: AspectRatio(aspectRatio: 1, child: _IconSearchButton(key: const ValueKey('icon-search'), tooltip: l.iconSearch, onTap: _searchIcons)),
        ),
        for (final name in _iconRow) ...[
          const SizedBox(width: 10),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: _IconTile(key: ValueKey('icon-$name'), name: name, chosen: name == _icon, fill: _fill, onTap: () => _pick(() => _icon = name)),
            ),
          ),
        ],
      ],
    ),
  ];

  /// Иконки строки: нынешняя первой, дальше подходящие к имени, потом частые — всего пять.
  List<String> get _iconRow => {_icon, ..._forName, ...pickableSymbols}.take(5).toList();

  Future<void> _searchIcons() async {
    final picked = await showStowaSheet<String>(
      context,
      backgroundColor: Tokens.container,
      maxHeightFactor: null,
      builder: (sheet) => SizedBox(
        height: MediaQuery.sizeOf(sheet).height * 0.85,
        child: _IconSheet(current: _icon, fill: _fill, forName: _forName),
      ),
    );
    if (picked != null && mounted) _pick(() => _icon = picked);
  }
}

/// Иконка в строке и в сетке: выбранная — на цвете папки и кругом.
class _IconTile extends StatelessWidget {
  const _IconTile({super.key, required this.name, required this.chosen, required this.fill, required this.onTap});

  final String name;
  final bool chosen;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: chosen,
      label: name.replaceAll('_', ' '),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.short,
          curve: Motion.emphasized,
          decoration: BoxDecoration(color: chosen ? fill : Tokens.containerHigh, borderRadius: BorderRadius.circular(chosen ? 30 : 18)),
          child: Icon(symbolIcon(name, filled: chosen), size: 26, color: chosen ? inkOn(fill) : Tokens.onSurface),
        ),
      ),
    );
  }
}

/// Круглая кнопка поиска иконок: залита цветом акцента, чтобы её не приняли за лупу-иконку папки.
class _IconSearchButton extends StatelessWidget {
  const _IconSearchButton({super.key, required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Tokens.accent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Icon(symbolIcon('search'), size: 24, color: Tokens.onAccent)),
        ),
      ),
    );
  }
}

/// Лист всего набора иконок: поиск сверху, ниже подходящие к имени, частые и все.
/// Касание иконки отдаёт её имя и закрывает лист.
class _IconSheet extends StatefulWidget {
  const _IconSheet({required this.current, required this.fill, required this.forName});

  final String current;
  final Color fill;
  final List<String> forName;

  @override
  State<_IconSheet> createState() => _IconSheetState();
}

class _IconSheetState extends State<_IconSheet> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final query = _query.trim();
    final found = query.isEmpty ? const <String>[] : searchIcons(query, limit: 120);

    Widget label(String text) => SliverPadding(
      padding: const EdgeInsets.fromLTRB(Space.screen + 4, 14, Space.screen, 8),
      sliver: SliverToBoxAdapter(child: Text(text, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Tokens.onSurfaceVariant))),
    );

    Widget grid(List<String> names) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 60, mainAxisSpacing: 8, crossAxisSpacing: 8),
        itemCount: names.length,
        itemBuilder: (context, index) => _IconTile(
          key: ValueKey('icon-${names[index]}'),
          name: names[index],
          chosen: names[index] == widget.current,
          fill: widget.fill,
          onTap: () => Navigator.pop(context, names[index]),
        ),
      ),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 4),
          child: TextField(
            key: const ValueKey('icon-search-field'),
            autofocus: true,
            decoration: InputDecoration(hintText: l.iconSearch, prefixIcon: Icon(symbolIcon('search'))),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            key: const ValueKey('icons-scroll'),
            slivers: [
              if (query.isNotEmpty) ...[
                if (found.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(Space.screen + 4, 12, Space.screen, 0),
                    sliver: SliverToBoxAdapter(
                      child: Text(l.iconsNone, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
                    ),
                  )
                else
                  grid(found),
              ] else ...[
                if (widget.forName.isNotEmpty) ...[label(l.lookSuggested), grid(widget.forName)],
                label(l.lookPopular),
                grid(pickableSymbols),
                label(l.lookAll),
                grid(_allIcons),
              ],
              SliverToBoxAdapter(child: SizedBox(height: 16 + MediaQuery.paddingOf(context).bottom)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Как папка будет выглядеть: крупный значок на её цвете и пилюля с полки главной.
class _Preview extends StatelessWidget {
  const _Preview({required this.name, required this.icon, required this.shape, required this.fill});

  final String name;
  final String icon;
  final BadgeShape shape;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: Motion.medium,
      curve: Motion.emphasized,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: FolderPalette.tint(fill), borderRadius: BorderRadius.circular(Radii.card)),
      child: Row(
        children: [
          ShapeBadge(
            shape: shape,
            size: 88,
            color: fill,
            child: Icon(symbolIcon(icon, filled: true), size: 40, color: inkOn(fill)),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleLarge),
                const SizedBox(height: 10),
                // пилюля как на полке главной
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
                  decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(symbolIcon(icon, filled: true), size: 18, color: inkOn(fill)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelLarge!.copyWith(color: inkOn(fill)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Круг всех оттенков: касание открывает выбор любого цвета.
class _WheelButton extends StatelessWidget {
  const _WheelButton({super.key, required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              // оттенки той же светлоты, что палитра папок: круг не кричит рядом с ними
              gradient: SweepGradient(
                colors: [Color(0xFFFFA098), Color(0xFFFEC766), Color(0xFFB5E285), Color(0xFF51D5CE), Color(0xFF92BFFF), Color(0xFFDFA5EC), Color(0xFFFFA098)],
              ),
            ),
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 0.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Tokens.background, shape: BoxShape.circle),
                  child: Icon(symbolIcon('add'), size: 18, color: Tokens.onSurface),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({super.key, required this.color, required this.chosen, required this.onTap});

  final Color color;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: chosen,
      child: GestureDetector(
        onTap: onTap,
        // выбранный — кольцом цвета текста вокруг и галочкой: видно на любом цвете
        child: AnimatedContainer(
          duration: Motion.short,
          curve: Motion.emphasized,
          padding: EdgeInsets.all(chosen ? 4 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: chosen ? Tokens.onSurface : Colors.transparent, width: 2),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(child: chosen ? Icon(symbolIcon('check'), size: 20, color: inkOn(color)) : null),
          ),
        ),
      ),
    );
  }
}

class _ShapeChoice extends StatelessWidget {
  const _ShapeChoice({super.key, required this.shape, required this.icon, required this.fill, required this.chosen, required this.onTap});

  final BadgeShape shape;
  final String icon;
  final Color fill;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: chosen,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.short,
          curve: Motion.emphasized,
          height: 64,
          decoration: BoxDecoration(color: chosen ? FolderPalette.tint(fill, 0.3) : Tokens.container, borderRadius: BorderRadius.circular(Radii.tile)),
          child: Center(
            child: ShapeBadge(
              shape: shape,
              size: 40,
              color: chosen ? fill : Tokens.containerHighest,
              child: Icon(symbolIcon(icon), size: 20, color: chosen ? inkOn(fill) : Tokens.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

