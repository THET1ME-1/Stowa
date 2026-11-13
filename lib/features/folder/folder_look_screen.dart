import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/icons/icon_words.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/shape_badge.dart';
import '../../data/repositories/folders_repository.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_blocks.dart';

typedef FolderLook = ({String icon, String shape, String? color});

/// Экран «Цвет и значок» выезжает справа и отдаёт выбранное или null.
Route<FolderLook> folderLookRoute(FolderCard folder) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => FolderLookScreen(folder: folder),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

// весь набор один раз: тысячи имён не пересобираются на каждый кадр;
// «10k», «4g» и прочие цифры уходят в конец, иначе набор начинается с них
final List<String> _allIcons = [
  ...symbolNames.where((name) => !name.startsWith(RegExp('[0-9]'))),
  ...symbolNames.where((name) => name.startsWith(RegExp('[0-9]'))),
];

/// Ширина, с которой образец и цвета встают слева, а иконки справа.
const _wideFrom = 720.0;

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
  String _query = '';

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
                      l.folderLook,
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
                  if (constraints.maxWidth < _wideFrom) {
                    return CustomScrollView(
                      key: const ValueKey('look-scroll'),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(Space.screen, 8, Space.screen, 0),
                          sliver: SliverList.list(children: _setup(l)),
                        ),
                        ..._icons(l),
                      ],
                    );
                  }
                  // планшет и телефон боком: образец с цветом и формой слева, иконки справа
                  return Row(
                    key: const ValueKey('look-wide'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 360,
                        child: ListView(padding: const EdgeInsets.fromLTRB(Space.screen, 8, 8, 32), children: _setup(l)),
                      ),
                      Expanded(child: CustomScrollView(slivers: _icons(l))),
                    ],
                  );
                },
              ),
            ),
            // под большим пальцем и на любой ширине, иконки листаются над ней
            Padding(
              padding: EdgeInsets.fromLTRB(Space.screen, 8, Space.screen, 12 + MediaQuery.paddingOf(context).bottom),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(onPressed: () => Navigator.pop<FolderLook>(context, (icon: _icon, shape: _shape, color: _color)), child: Text(l.save)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Образец, цвет и форма.
  List<Widget> _setup(L l) => [
    _Preview(name: widget.folder.name, icon: _icon, shape: _badgeShape, fill: _fill),
    SettingsSection(l.lookColor),
    // двенадцать кружков ровными рядами: по шесть на телефоне, все в ряд, если влезают
    LayoutBuilder(
      builder: (context, constraints) => GridView.count(
        crossAxisCount: constraints.maxWidth >= 12 * 52 ? 12 : 6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          for (final MapEntry(key: key, value: color) in FolderPalette.colors.entries)
            _Swatch(key: ValueKey('color-$key'), color: color, chosen: color == _fill, onTap: () => _pick(() => _color = key)),
        ],
      ),
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
  ];

  /// Заголовок «Иконка», поиск под шапкой и сетки иконок.
  List<Widget> _icons(L l) {
    final query = _query.trim();
    final found = query.isEmpty ? const <String>[] : searchIcons(query, limit: 120);
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
        sliver: SliverToBoxAdapter(child: SettingsSection(l.lookIcon)),
      ),
      // поиск остаётся под шапкой, пока листаешь иконки
      SliverPersistentHeader(
        pinned: true,
        delegate: _SearchBar(hint: l.iconSearch, onChanged: (value) => setState(() => _query = value)),
      ),
      if (query.isNotEmpty) ...[
        if (found.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.screen + 4, 12, Space.screen, 0),
            sliver: SliverToBoxAdapter(
              child: Text(l.iconsNone, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
            ),
          )
        else
          _grid(found),
      ] else ...[
        if (_forName.isNotEmpty) ...[_label(l.lookSuggested), _grid(_forName)],
        _label(l.lookPopular),
        _grid(pickableSymbols),
        _label(l.lookAll),
        _grid(_allIcons),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ];
  }

  Widget _label(String text) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(Space.screen + 4, 14, Space.screen, 8),
    sliver: SliverToBoxAdapter(
      child: Text(text, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Tokens.onSurfaceVariant)),
    ),
  );

  Widget _grid(List<String> names) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: Space.screen),
    sliver: SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 60, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: names.length,
      itemBuilder: (context, index) {
        final name = names[index];
        final chosen = name == _icon;
        return Semantics(
          button: true,
          selected: chosen,
          label: name.replaceAll('_', ' '),
          child: GestureDetector(
            key: ValueKey('icon-$name'),
            onTap: () => _pick(() => _icon = name),
            child: AnimatedContainer(
              duration: Motion.short,
              curve: Motion.emphasized,
              decoration: BoxDecoration(color: chosen ? _fill : Tokens.container, borderRadius: BorderRadius.circular(chosen ? 30 : 18)),
              child: Icon(symbolIcon(name, filled: chosen), size: 26, color: chosen ? inkOn(_fill) : Tokens.onSurface),
            ),
          ),
        );
      },
    ),
  );
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

class _SearchBar extends SliverPersistentHeaderDelegate {
  _SearchBar({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  double get minExtent => 68;

  @override
  double get maxExtent => 68;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // ровно по высоте шапки: иначе закреплённая шапка рисуется на точку ниже своего места
    return Container(
      height: maxExtent,
      color: Tokens.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 6),
        child: TextField(
          decoration: InputDecoration(prefixIcon: Icon(symbolIcon('search')), hintText: hint),
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // поле живёт своим состоянием, пересобирать шапку незачем
  @override
  bool shouldRebuild(_SearchBar oldDelegate) => hint != oldDelegate.hint;
}
