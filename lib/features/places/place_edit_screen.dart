import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/icons/icon_words.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/place_cue.dart' show kindOfWord;
import '../../l10n/app_localizations.dart';
import '../map/map_tiles.dart';
import '../settings/settings_blocks.dart';
import 'place_kinds.dart';

/// Экран места выезжает справа: новое — [place] null, иначе правка.
Route<void> placeEditRoute({Place? place}) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => PlaceEditScreen(place: place),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

/// Место для напоминаний: имя, вид и точка. Точку даёт «Я сейчас здесь» или карта:
/// стоять у места не нужно — квартиру друга или ресторан ставят издалека.
class PlaceEditScreen extends ConsumerStatefulWidget {
  const PlaceEditScreen({super.key, this.place});

  final Place? place;

  @override
  ConsumerState<PlaceEditScreen> createState() => _PlaceEditScreenState();
}

class _PlaceEditScreenState extends ConsumerState<PlaceEditScreen> {
  late final _name = TextEditingController(text: widget.place?.name ?? '')..addListener(_named);
  final _map = MapController();
  late PlaceType _type = widget.place == null ? builtInType(PlaceKind.other) : typeOf(widget.place!);

  /// Свой значок места поверх значка вида; null — значок вида.
  late String? _icon = widget.place?.icon;

  String get _shownIcon => _icon ?? placeTypeIcon(_type);

  Future<void> _pickIcon() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Tokens.container,
      builder: (sheet) => _IconSheet(name: _name.text, current: _shownIcon),
    );
    if (picked == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _icon = picked);
  }
  String _typedName = '';
  late LatLng? _point = widget.place == null ? null : LatLng(widget.place!.latitude, widget.place!.longitude);

  /// Название точки от геокодера: имя места, если своё не написали.
  String? _pointName;
  String? _wifi;
  LatLng _start = const LatLng(20, 0);
  double _startZoom = 2;

  @override
  void initState() {
    super.initState();
    if (_point != null) {
      _start = _point!;
      _startZoom = 16;
    } else {
      _startNearNotes();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _map.dispose();
    super.dispose();
  }

  /// Вид выбран рукой: имя его больше не меняет. У правки места вид уже свой.
  late bool _picked = widget.place != null;

  // имя ведёт вид, пока его не выбрали рукой: «Универ» — учёба
  void _named() {
    if (_name.text == _typedName) return;
    setState(() {
      _typedName = _name.text;
      if (_picked) return;
      final guessed = [
        for (final word in RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(_name.text)) ?kindOfWord(word.group(0)!),
      ].firstOrNull;
      _type = builtInType(guessed ?? PlaceKind.other);
    });
  }

  void _pick(PlaceType type) {
    HapticFeedback.selectionClick();
    setState(() {
      _type = type;
      _picked = true;
    });
  }

  /// Вторая плитка: вид по слову из имени, иначе свой вид из уже отмеченных, иначе дом или работа.
  PlaceType _suggested(List<Place> places) {
    final candidates = <PlaceType>[
      for (final word in RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(_name.text))
        if (kindOfWord(word.group(0)!) case final kind?) builtInType(kind),
      for (final place in places) if (place.label != null) typeOf(place),
      builtInType(PlaceKind.home),
      builtInType(PlaceKind.work),
    ];
    return candidates.firstWhere((type) => !sameType(type, _type));
  }

  /// Лист всех видов с поиском: готовые, свои из отмеченных мест и «Создать «…»».
  Future<void> _findType(List<Place> places) async {
    final picked = await showModalBottomSheet<PlaceType>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Tokens.container,
      builder: (sheet) => _TypeSheet(places: places),
    );
    if (picked != null && mounted) _pick(picked);
  }

  // новое место: карта открывается там, где последний раз сохраняли заметку, без запроса разрешения
  Future<void> _startNearNotes() async {
    final points = await ref.read(placesRepositoryProvider).savedPoints();
    if (points.isEmpty || !mounted) return;
    final last = points.reduce((a, b) => a.at.isAfter(b.at) ? a : b);
    // карта ещё могла не встать: начало задаётся заново, карта пересоздаётся по ключу
    setState(() {
      _start = LatLng(last.latitude, last.longitude);
      _startZoom = 14;
    });
  }

  Future<void> _here() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final fix = await ref.read(currentPlaceProvider)();
    if (!mounted) return;
    if (fix == null) {
      showNote(messenger, l.placesNoFix);
      return;
    }
    // сеть читается только с местом «всегда» — без него просто без Wi-Fi
    final wifi = await ref.read(placeChannelProvider).currentWifi();
    if (!mounted) return;
    setState(() {
      _point = LatLng(fix.latitude, fix.longitude);
      _pointName = fix.name;
      _wifi = wifi;
    });
    _map.move(_point!, 17);
  }

  Future<void> _save() async {
    final point = _point;
    if (point == null) return;
    final l = L.of(context);
    final places = ref.read(placesRepositoryProvider);
    final typed = _name.text.trim();
    final name = typed.isNotEmpty ? typed : (_pointName ?? placeTypeLabel(l, _type));
    HapticFeedback.selectionClick();
    final current = widget.place;
    final type = _type;
    if (current == null) {
      // Wi-Fi узнаёт дом и работу без GPS; у кафе и друзей сеть чужая
      final ownNetwork = type.label == null && (type.kind == PlaceKind.home || type.kind == PlaceKind.work);
      await places.add(type.kind, name: name, label: type.label, icon: _icon ?? type.icon, latitude: point.latitude, longitude: point.longitude, wifi: ownNetwork ? _wifi : null);
    } else {
      await places.update(current.id, name: name, kind: type.kind, label: type.label, icon: _icon ?? type.icon, latitude: point.latitude, longitude: point.longitude);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _remove() async {
    await ref.read(placesRepositoryProvider).remove(widget.place!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final places = ref.watch(placesProvider).value ?? const <Place>[];
    final suggested = _suggested(places);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 0),
              child: SettingsHeader(widget.place == null ? l.placeNewTitle : l.placeEditTitle),
            ),
            // поля сверху листаются, если не влезают; карта забирает остальное
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Space.screen, 14, Space.screen, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        // значок места: касание — выбор из всего набора
                        IconButton(
                          tooltip: l.placeIcon,
                          onPressed: _pickIcon,
                          style: IconButton.styleFrom(backgroundColor: Tokens.accent, foregroundColor: Tokens.onAccent, fixedSize: const Size.square(56)),
                          icon: Icon(symbolIcon(_shownIcon, filled: true), size: 26),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _name,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(hintText: l.placeNameHint),
                          ),
                        ),
                      ],
                    ),
                    SettingsSection(l.placeKindTitle),
                    // три плитки одной ширины: выбранный вид, подходящий к имени и все остальные поиском
                    IntrinsicHeight(
                      key: const ValueKey('type-row'),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _TypeTile(key: ValueKey('tile-selected-${placeTypeLabel(l, _type)}'), icon: placeTypeIcon(_type), label: placeTypeLabel(l, _type), selected: true, onTap: () => _findType(places)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _TypeTile(
                              key: ValueKey('tile-suggested-${placeTypeLabel(l, suggested)}'),
                              icon: placeTypeIcon(suggested),
                              label: placeTypeLabel(l, suggested),
                              selected: false,
                              onTap: () => _pick(suggested),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _TypeTile(key: const ValueKey('tile-more'), icon: 'search', label: l.placeKindMore, selected: false, onTap: () => _findType(places)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.card),
                  child: Stack(
                    children: [
                      FlutterMap(
                        key: ValueKey(_start),
                        mapController: _map,
                        options: MapOptions(
                          initialCenter: _start,
                          initialZoom: _startZoom,
                          backgroundColor: Tokens.container,
                          // палец сдвинул карту — место там, где точка в центре
                          onPositionChanged: (camera, hasGesture) {
                            if (!hasGesture) return;
                            setState(() {
                              _point = camera.center;
                              _pointName = null;
                              _wifi = null;
                            });
                          },
                        ),
                        children: [
                          const NightTiles(),
                          // карта OpenStreetMap требует подписи
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text('© OpenStreetMap', style: TextStyle(fontSize: 10, color: Tokens.muted)),
                            ),
                          ),
                        ],
                      ),
                      IgnorePointer(
                        child: Center(
                          child: Icon(symbolIcon(_shownIcon, filled: true), size: 36, color: _point == null ? Tokens.muted : Tokens.accent),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: FilledButton.tonalIcon(onPressed: _here, icon: Icon(symbolIcon('my_location'), size: 18), label: Text(l.placeHereNow)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen + 4, 8, Space.screen, 0),
              child: Text(l.placeMapHint, style: text.bodySmall!.copyWith(color: Tokens.muted)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 10, Space.screen, 12),
              child: Row(
                children: [
                  if (widget.place != null) ...[
                    TextButton(onPressed: _remove, style: TextButton.styleFrom(foregroundColor: Tokens.error), child: Text(l.placesRemove)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(onPressed: _point == null ? null : _save, child: Text(l.placesSave)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Плитка вида: значок над подписью. Выбранная — белая, касание открывает поиск видов.
class _TypeTile extends StatelessWidget {
  const _TypeTile({super.key, required this.icon, required this.label, required this.selected, required this.onTap});

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? Tokens.onAccent : Tokens.onSurface;
    return Material(
      color: selected ? Tokens.accent : Tokens.containerHigh,
      borderRadius: BorderRadius.circular(Radii.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(symbolIcon(icon, filled: selected), size: 24, color: ink),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge!.copyWith(color: ink, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// весь набор один раз; «10k», «4g» и прочие цифры в конце
final List<String> _allIcons = [
  ...symbolNames.where((name) => !name.startsWith(RegExp('[0-9]'))),
  ...symbolNames.where((name) => name.startsWith(RegExp('[0-9]'))),
];

/// Значок места поиском по всему набору: без запроса — подходящие к имени, частые, потом все.
class _IconSheet extends StatefulWidget {
  const _IconSheet({required this.name, required this.current});

  final String name;
  final String current;

  @override
  State<_IconSheet> createState() => _IconSheetState();
}

class _IconSheetState extends State<_IconSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final query = _query.trim();
    final icons = query.isEmpty
        ? {...searchIcons(widget.name, limit: 18), ...pickableSymbols, ..._allIcons}.toList()
        : searchIcons(query, limit: 120);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 8),
                child: TextField(
                  decoration: InputDecoration(prefixIcon: Icon(symbolIcon('search')), hintText: l.iconSearch),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: icons.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(Space.screen),
                        child: Text(l.iconsNone, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(Space.screen, 4, Space.screen, Space.screen),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 60, mainAxisSpacing: 8, crossAxisSpacing: 8),
                        itemCount: icons.length,
                        itemBuilder: (context, index) {
                          final name = icons[index];
                          final chosen = name == widget.current;
                          return Material(
                            key: ValueKey('icon-$name'),
                            color: chosen ? Tokens.accent : Tokens.containerHigh,
                            borderRadius: BorderRadius.circular(chosen ? 30 : 18),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => Navigator.pop(context, name),
                              child: Icon(symbolIcon(name, filled: chosen), size: 26, color: chosen ? Tokens.onAccent : Tokens.onSurface),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Все виды поиском: готовые, свои из отмеченных мест; не нашлось — «Создать «…»» со значком по слову.
class _TypeSheet extends StatefulWidget {
  const _TypeSheet({required this.places});

  final List<Place> places;

  @override
  State<_TypeSheet> createState() => _TypeSheetState();
}

class _TypeSheetState extends State<_TypeSheet> {
  String _query = '';

  // значок своего вида: по слову готового вида, иначе поиском по набору иконок
  String _iconFor(String name) {
    for (final word in RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(name)) {
      final kind = kindOfWord(word.group(0)!);
      if (kind != null) return placeKindIcon(kind);
    }
    return searchIcons(name).firstOrNull ?? 'location_on';
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final query = _query.trim();
    final all = <PlaceType>[
      for (final kind in PlaceKind.values) builtInType(kind),
      for (final place in widget.places) if (place.label != null) typeOf(place),
    ];
    // свой вид, отмеченный у нескольких мест, — одной строкой
    final types = <PlaceType>[];
    for (final type in all) {
      if (!types.any((one) => sameType(one, type))) types.add(type);
    }
    final shown = query.isEmpty ? types : types.where((type) => placeTypeLabel(l, type).toLowerCase().contains(query.toLowerCase())).toList();
    final exact = types.any((type) => placeTypeLabel(l, type).toLowerCase() == query.toLowerCase());
    final created = query.isEmpty ? '' : query[0].toUpperCase() + query.substring(1);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 8),
                child: TextField(
                  decoration: InputDecoration(prefixIcon: Icon(symbolIcon('search')), hintText: l.placeKindSearchHint),
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Flexible(
                child: ListView(
                  key: const ValueKey('type-sheet'),
                  shrinkWrap: true,
                  children: [
                    if (query.isNotEmpty && !exact)
                      ListTile(
                        leading: Icon(symbolIcon('add')),
                        title: Text(l.placeKindCreate(created)),
                        onTap: () => Navigator.pop(context, (kind: PlaceKind.other, label: created, icon: _iconFor(created))),
                      ),
                    for (final type in shown)
                      ListTile(
                        key: ValueKey('type-${placeTypeLabel(l, type)}'),
                        leading: Icon(symbolIcon(placeTypeIcon(type))),
                        title: Text(placeTypeLabel(l, type)),
                        onTap: () => Navigator.pop(context, type),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
