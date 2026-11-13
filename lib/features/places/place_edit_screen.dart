import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/icons/icon_registry.dart';
import '../../core/icons/icon_words.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/place_cue.dart' show kindOfWord;
import '../../l10n/app_localizations.dart';
import '../../services/place_search.dart';
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

/// Радиусы, из которых выбирают: дом и аптека — 100–150 м, университет и торговый центр — 300–500.
const placeRadii = [100, 150, 300, 500];
const _defaultRadius = 150;

/// Зум у поставленной точки: круг в 150 м занимает треть карты, вокруг видны улицы.
const double _pointZoom = 16;

/// Место для напоминаний. Главное — найти точку: поиск адреса поверх карты, «Я сейчас здесь»
/// или долгое нажатие на карту. Листание карты точку не двигает, перенос можно отменить.
/// Под картой адрес точки и радиус, имя со значком и строка видов. Устройство и почему так —
/// `docs/specs/2026-11-13-place-screen-design.md`.
class PlaceEditScreen extends ConsumerStatefulWidget {
  const PlaceEditScreen({super.key, this.place});

  final Place? place;

  @override
  ConsumerState<PlaceEditScreen> createState() => _PlaceEditScreenState();
}

class _PlaceEditScreenState extends ConsumerState<PlaceEditScreen> {
  late final _name = TextEditingController(text: widget.place?.name ?? '')..addListener(_named);
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _map = MapController();

  late PlaceType _type = widget.place == null ? builtInType(PlaceKind.other) : typeOf(widget.place!);

  /// Вид выбран рукой: имя его больше не меняет. У правки места вид уже свой.
  late bool _picked = widget.place != null;

  /// Свой значок места поверх значка вида; null — значок вида.
  late String? _icon = widget.place?.icon;
  String get _shownIcon => _icon ?? placeTypeIcon(_type);

  late LatLng? _point = widget.place == null ? null : LatLng(widget.place!.latitude, widget.place!.longitude);
  late int _radius = widget.place?.radius ?? _defaultRadius;

  /// Адрес точки под картой; null, пока не узнан.
  String? _address;

  /// Название найденного поиском: имя места, если своё не набрано.
  String? _foundName;

  /// Имя, подставленное из поиска: следующий найденный его заменит, набранное руками — нет.
  String? _autoName;
  String? _wifi;
  int _addressLookup = 0;

  Timer? _debounce;
  int _searchRound = 0;
  bool _searching = false;
  List<FoundPlace>? _found;
  bool _locating = false;

  LatLng _start = const LatLng(20, 0);
  double _startZoom = 2;
  String _typedName = '';

  @override
  void initState() {
    super.initState();
    _typedName = _name.text;
    _searchFocus.addListener(() => setState(() {}));
    if (_point != null) {
      _start = _point!;
      _startZoom = _pointZoom;
      _lookupAddress(_point!);
    } else {
      _startNearNotes();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _search.dispose();
    _searchFocus.dispose();
    _map.dispose();
    super.dispose();
  }

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

  /// Лист всех видов с поиском: готовые, свои и «Создать «…»».
  Future<void> _findType(List<Place> places) async {
    final picked = await showOptionsSheetWith<PlaceType>(context, (sheet) => _TypeSheet(places: places));
    if (picked != null && mounted) _pick(picked);
  }

  Future<void> _pickRadius() async {
    final l = L.of(context);
    final picked = await showOptionsSheet<int>(
      context,
      title: l.placeRadiusTitle,
      selected: _radius,
      options: [for (final meters in placeRadii) SheetChoice(value: meters, title: l.placeRadiusValue(meters), mark: '$meters')],
    );
    if (picked != null && mounted) setState(() => _radius = picked);
  }

  // новое место: карта открывается там, где последний раз сохраняли заметку, без запроса разрешения
  Future<void> _startNearNotes() async {
    final points = await ref.read(placesRepositoryProvider).savedPoints();
    if (points.isEmpty || !mounted || _point != null) return;
    final last = points.reduce((a, b) => a.at.isAfter(b.at) ? a : b);
    // карта ещё могла не встать: начало задаётся заново, карта пересоздаётся по ключу
    setState(() {
      _start = LatLng(last.latitude, last.longitude);
      _startZoom = 14;
    });
  }

  /// Точка поставлена: адрес известен сразу (поиск, «я здесь») или узнаётся.
  void _setPoint(LatLng point, {String? address, String? wifi, String? foundName}) {
    setState(() {
      _point = point;
      _address = address;
      _wifi = wifi;
      _foundName = foundName;
    });
    if (address == null) _lookupAddress(point);
  }

  Future<void> _lookupAddress(LatLng point) async {
    final round = ++_addressLookup;
    final name = await ref.read(placeLookupProvider).nameAt(point.latitude, point.longitude);
    if (!mounted || round != _addressLookup || _point != point) return;
    setState(() => _address = name);
  }

  Future<void> _here() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    final fix = await ref.read(currentPlaceProvider)();
    // сеть читается только с местом «всегда» — без него просто без Wi-Fi
    final wifi = fix == null ? null : await ref.read(placeChannelProvider).currentWifi();
    if (!mounted) return;
    setState(() => _locating = false);
    if (fix == null) {
      showNote(messenger, l.placesNoFix);
      return;
    }
    final point = LatLng(fix.latitude, fix.longitude);
    _setPoint(point, address: fix.name, wifi: wifi);
    if (fix.name == null) _lookupAddress(point);
    _moveMap(point, _pointZoom);
  }

  // долгое нажатие ставит точку под палец; перенос уже стоявшей можно отменить
  void _drop(LatLng point) {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    HapticFeedback.mediumImpact();
    _closeSearch();
    final before = (point: _point, address: _address, wifi: _wifi, found: _foundName);
    _setPoint(point);
    if (before.point == null) return;
    showUndo(
      messenger,
      message: l.placePointMoved,
      label: l.undo,
      onUndo: () {
        if (!mounted) return;
        _addressLookup++;
        setState(() {
          _point = before.point;
          _address = before.address;
          _wifi = before.wifi;
          _foundName = before.found;
        });
      },
    );
  }

  void _moveMap(LatLng point, double zoom) {
    try {
      _map.move(point, zoom);
    } catch (_) {
      // карта ещё не встала: откроется на точке, начало берётся из неё
      setState(() {
        _start = point;
        _startZoom = zoom;
      });
    }
  }

  // поиск — через полсекунды после последней буквы и от трёх букв; ответ на старый запрос отбрасывается
  void _searchChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.length < 3) {
      setState(() {
        _found = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final round = ++_searchRound;
      LatLng? near;
      try {
        near = _map.camera.center;
      } catch (_) {
        near = _point;
      }
      final found = await ref.read(placeLookupProvider).search(query, nearLatitude: near?.latitude, nearLongitude: near?.longitude);
      if (!mounted || round != _searchRound) return;
      setState(() {
        _found = found;
        _searching = false;
      });
    });
  }

  void _closeSearch() {
    _debounce?.cancel();
    _searchFocus.unfocus();
    setState(() {
      _found = null;
      _searching = false;
    });
  }

  void _choose(FoundPlace place) {
    HapticFeedback.selectionClick();
    _search.clear();
    _closeSearch();
    final point = LatLng(place.latitude, place.longitude);
    _setPoint(point, address: place.address ?? place.name, foundName: place.name);
    // имя не набрано руками — им становится найденное, и по нему угадывается вид
    final typed = _name.text.trim();
    if (typed.isEmpty || typed == _autoName) {
      _autoName = place.name;
      _name.text = place.name;
    }
    _moveMap(point, _pointZoom);
  }

  Future<void> _save() async {
    final point = _point;
    if (point == null) return;
    final l = L.of(context);
    final places = ref.read(placesRepositoryProvider);
    final typed = _name.text.trim();
    final name = typed.isNotEmpty ? typed : (_foundName ?? _address ?? placeTypeLabel(l, _type));
    HapticFeedback.selectionClick();
    final current = widget.place;
    final type = _type;
    if (current == null) {
      // Wi-Fi узнаёт дом и работу без GPS; у кафе и друзей сеть чужая
      final ownNetwork = type.label == null && (type.kind == PlaceKind.home || type.kind == PlaceKind.work);
      await places.add(
        type.kind,
        name: name,
        label: type.label,
        icon: _icon ?? type.icon,
        latitude: point.latitude,
        longitude: point.longitude,
        wifi: ownNetwork ? _wifi : null,
        radius: _radius,
      );
    } else {
      await places.update(current.id, name: name, kind: type.kind, label: type.label, icon: _icon ?? type.icon, latitude: point.latitude, longitude: point.longitude, radius: _radius);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _remove() async {
    await ref.read(placesRepositoryProvider).remove(widget.place!.id);
    if (mounted) Navigator.pop(context);
  }

  /// Виды строкой: девять готовых, свои из отмеченных мест и выбранный свой, если он новый.
  List<PlaceType> _types(List<Place> places) {
    final types = <PlaceType>[for (final kind in PlaceKind.values) builtInType(kind)];
    for (final type in [for (final place in places) if (place.label != null) typeOf(place), _type]) {
      if (!types.any((one) => sameType(one, type))) types.add(type);
    }
    return types;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final places = ref.watch(placesProvider).value ?? const <Place>[];
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 12),
              child: SettingsHeader(widget.place == null ? l.placeNewTitle : l.placeEditTitle),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: ClipRRect(borderRadius: BorderRadius.circular(Radii.card), child: _mapArea(context)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 12, Space.screen, 0),
              child: _AddressRow(
                address: _point == null ? l.placeNoPoint : (_address ?? '…'),
                hint: _point == null ? null : l.placeMapMove,
                radius: l.placeRadiusValue(_radius),
                onRadius: _pickRadius,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 12, Space.screen, 0),
              child: Row(
                children: [
                  // значок места: касание — выбор из всего набора
                  IconButton(
                    tooltip: l.placeIcon,
                    onPressed: _pickIcon,
                    style: IconButton.styleFrom(backgroundColor: Tokens.accent, foregroundColor: Tokens.onAccent, fixedSize: const Size.square(52)),
                    icon: Icon(symbolIcon(_shownIcon, filled: true), size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('place-name'),
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(hintText: l.placeNameHint),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _KindRow(
              types: _types(places),
              selected: _type,
              onPick: _pick,
              onOwn: () => _findType(places),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 14, Space.screen, 12),
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

  Widget _mapArea(BuildContext context) {
    final l = L.of(context);
    final point = _point;
    final showFound = _searchFocus.hasFocus && _search.text.trim().length >= 3 && (_found != null || _searching);
    return Stack(
      children: [
        FlutterMap(
          key: ValueKey(_start),
          mapController: _map,
          options: MapOptions(
            initialCenter: _start,
            initialZoom: _startZoom,
            backgroundColor: Tokens.container,
            // палец листает и приближает только вид; поворот карте места не нужен
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onTap: (_, _) => _closeSearch(),
            onLongPress: (_, point) => _drop(point),
          ),
          children: [
            const NightTiles(),
            if (point != null) ...[
              // круг, в котором сработает напоминание
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: point,
                    radius: _radius.toDouble(),
                    useRadiusInMeter: true,
                    color: Tokens.accent.withValues(alpha: 0.12),
                    borderColor: Tokens.accent.withValues(alpha: 0.7),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // низ острия — сама точка
                  Marker(point: point, width: 44, height: 56, alignment: Alignment.topCenter, child: _Pin(icon: _shownIcon)),
                ],
              ),
            ],
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
        if (point == null)
          Positioned(
            left: 12,
            right: 64,
            bottom: 28,
            child: IgnorePointer(child: _MapHint(text: l.placeMapEmpty)),
          ),
        Positioned(
          right: 10,
          bottom: 10,
          child: _RoundButton(icon: 'my_location', tooltip: l.placeHereNow, busy: _locating, onTap: _locating ? null : _here),
        ),
        Positioned(
          left: 10,
          right: 10,
          top: 10,
          bottom: 66,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SearchField(
                controller: _search,
                focus: _searchFocus,
                hint: l.placeSearchHint,
                busy: _searching,
                onChanged: _searchChanged,
                onClear: () {
                  _search.clear();
                  _searchChanged('');
                },
              ),
              if (showFound) ...[
                const SizedBox(height: 6),
                Flexible(child: _FoundList(found: _found ?? const [], searching: _searching, none: l.placeSearchNone, onChoose: _choose)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Булавка точки: круг цвета акцента со значком места и острие вниз.
class _Pin extends StatelessWidget {
  const _Pin({required this.icon});

  final String icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: Tokens.accent, shape: BoxShape.circle, border: Border.all(color: Tokens.container, width: 3)),
          child: Icon(symbolIcon(icon, filled: true), size: 22, color: Tokens.onAccent),
        ),
        CustomPaint(size: const Size(14, 12), painter: _PinTip(Tokens.accent)),
      ],
    );
  }
}

class _PinTip extends CustomPainter {
  _PinTip(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinTip oldDelegate) => oldDelegate.color != color;
}

/// Поиск поверх карты: пилюля со значком, крестиком и крутилкой.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focus, required this.hint, required this.busy, required this.onChanged, required this.onClear});

  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final bool busy;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tokens.containerHigh,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(symbolIcon('search'), size: 20, color: Tokens.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const ValueKey('place-search'),
                controller: controller,
                focusNode: focus,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: hint,
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (busy)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Tokens.onSurfaceVariant)),
              )
            else
              ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox(width: 14)
                    : IconButton(onPressed: onClear, icon: Icon(symbolIcon('close'), size: 20, color: Tokens.onSurfaceVariant)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Найденное под полем поиска: название и адрес; пусто — «Ничего не нашлось».
class _FoundList extends StatelessWidget {
  const _FoundList({required this.found, required this.searching, required this.none, required this.onChoose});

  final List<FoundPlace> found;
  final bool searching;
  final String none;
  final ValueChanged<FoundPlace> onChoose;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Tokens.containerHigh,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: found.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Text(searching ? '…' : none, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
            )
          : ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                for (final place in found)
                  InkWell(
                    onTap: () => onChoose(place),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Row(
                        children: [
                          Icon(symbolIcon('location_on'), size: 20, color: Tokens.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                                if (place.address case final address?)
                                  Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Подсказка на карте, пока точки нет.
class _MapHint extends StatelessWidget {
  const _MapHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Tokens.onSurface)),
      ),
    );
  }
}

/// Круглая кнопка на карте: «Я сейчас здесь». Пока ищет — крутилка.
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.busy, required this.onTap});

  final String icon;
  final String tooltip;
  final bool busy;
  final VoidCallback? onTap;

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
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: busy
                  ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Tokens.onSurface))
                  : Icon(symbolIcon(icon), size: 22, color: Tokens.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

/// Адрес точки и радиус: «Strada Alexei Mateevici 60, Chișinău» · «150 м».
class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.hint, required this.radius, required this.onRadius});

  final String address;
  final String? hint;
  final String radius;
  final VoidCallback onRadius;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final row = Row(
      children: [
        Icon(symbolIcon('location_on', filled: true), size: 20, color: Tokens.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyLarge)),
        const SizedBox(width: 8),
        Material(
          color: Tokens.containerHigh,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onRadius,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(symbolIcon('radio_button_checked'), size: 16, color: Tokens.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(radius, style: text.labelLarge),
                  Icon(symbolIcon('expand_more'), size: 18, color: Tokens.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    if (hint == null) return row;
    // подсказка во всю ширину под адресом, вровень с его текстом
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        Padding(
          padding: const EdgeInsets.only(left: 30, top: 2),
          child: Text(hint!, style: text.bodySmall!.copyWith(color: Tokens.muted)),
        ),
      ],
    );
  }
}

/// Виды одной строкой вбок: порядок постоянный, выбранный подсвечен и всегда в видимой части.
class _KindRow extends StatefulWidget {
  const _KindRow({required this.types, required this.selected, required this.onPick, required this.onOwn});

  final List<PlaceType> types;
  final PlaceType selected;
  final ValueChanged<PlaceType> onPick;
  final VoidCallback onOwn;

  @override
  State<_KindRow> createState() => _KindRowState();
}

class _KindRowState extends State<_KindRow> {
  final _keys = <String, GlobalKey>{};

  @override
  void didUpdateWidget(_KindRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!sameType(oldWidget.selected, widget.selected)) WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void initState() {
    super.initState();
    // у нового места выбрано «Другое» в конце строки: начало с «Дома» и «Работы» важнее
    final fresh = widget.selected.kind == PlaceKind.other && widget.selected.label == null;
    if (!fresh) WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  // выбранный вид прокручивается в видимую часть строки
  void _reveal() {
    if (!mounted) return;
    final chip = _keys[_id(widget.selected)]?.currentContext;
    if (chip != null) Scrollable.ensureVisible(chip, duration: Motion.medium, curve: Motion.emphasized, alignment: 0.5);
  }

  String _id(PlaceType type) => '${type.kind.name}:${type.label ?? ''}';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // чипов десяток с небольшим: строятся все сразу, иначе выбранный за краем нечем прокрутить
    return SizedBox(
      key: const ValueKey('kind-row'),
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
        child: Row(
          children: [
            for (final type in widget.types) ...[
              KindChip(
                key: _keys.putIfAbsent(_id(type), GlobalKey.new),
                label: placeTypeLabel(l, type),
                icon: placeTypeIcon(type),
                selected: sameType(type, widget.selected),
                onTap: () => widget.onPick(type),
              ),
              const SizedBox(width: 8),
            ],
            KindChip(label: l.placeKindOwn, icon: 'add', selected: false, onTap: widget.onOwn),
          ],
        ),
      ),
    );
  }
}

/// Чип вида: значок и подпись; выбранный — белый со значком-заливкой.
class KindChip extends StatelessWidget {
  const KindChip({super.key, required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? Tokens.onAccent : Tokens.onSurface;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        key: ValueKey('kind-$label'),
        color: selected ? Tokens.accent : Tokens.containerHigh,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(symbolIcon(icon, filled: selected), size: 18, color: ink),
                const SizedBox(width: 6),
                Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: ink)),
              ],
            ),
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
    return KeyedSubtree(
      key: const ValueKey('type-sheet'),
      child: SheetOptionsBody(
        top: TextField(
          key: const ValueKey('type-search'),
          autofocus: true,
          decoration: InputDecoration(prefixIcon: Icon(symbolIcon('search')), hintText: l.placeKindSearchHint),
          textCapitalization: TextCapitalization.sentences,
          onChanged: (value) => setState(() => _query = value),
        ),
        children: [
          if (query.isNotEmpty && !exact)
            SheetOption(
              title: l.placeKindCreate(created),
              icon: 'add',
              onTap: () => Navigator.pop(context, (kind: PlaceKind.other, label: created, icon: _iconFor(created))),
            ),
          for (final type in shown)
            SheetOption(
              key: ValueKey('type-${placeTypeLabel(l, type)}'),
              title: placeTypeLabel(l, type),
              icon: placeTypeIcon(type),
              onTap: () => Navigator.pop(context, type),
            ),
        ],
      ),
    );
  }
}
