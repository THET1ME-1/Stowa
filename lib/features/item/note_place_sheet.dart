import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/icons/icon_registry.dart';
import '../../core/platform.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/place_search.dart';
import '../map/map_screen.dart';
import '../map/map_tiles.dart';
import '../places/place_edit_screen.dart' show MapRoundButton, PlacePin;
import '../places/place_kinds.dart';

/// Точка и как её назвать: «Strada Cornului 7/1, Chișinău», «Дом».
typedef NotePoint = ({double latitude, double longitude, String? name});

enum _Action { here, pickOnMap, showOnMap, remove }

/// Место заметки руками: готовой заметке без места или вместо неверного. Лист — свои места,
/// поиск адреса, «Я сейчас здесь», карта с булавкой; у заметки с местом ещё «Показать на
/// карте» и «Убрать место» с «Отменить».
Future<void> editNotePlace(BuildContext context, WidgetRef ref, Item item) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final items = ref.read(itemsRepositoryProvider);
  final current = item.latitude == null || item.longitude == null ? null : (latitude: item.latitude!, longitude: item.longitude!, name: item.placeName);
  final choice = await showOptionsSheetWith<Object>(context, (sheet) => _NotePlaceSheet(current: current));
  if (choice == null) return;
  switch (choice) {
    case _Action.showOnMap:
      await navigator.push(mapRoute(focusItemId: item.id));
    case _Action.remove:
      await items.setLocation(item.id, null);
      showUndo(messenger, message: l.itemPlaceRemoved, label: l.undo, onUndo: () => items.setLocation(item.id, current), overDock: true);
    case _Action.here:
      final fix = await ref.read(currentPlaceProvider)();
      if (fix == null) {
        showNote(messenger, isWeb ? l.placesNoFixBrowser : l.placesNoFix, overDock: true);
        return;
      }
      await items.setLocation(item.id, (latitude: fix.latitude, longitude: fix.longitude, name: fix.name));
    case _Action.pickOnMap:
      final start = current == null ? await _lastPoint(ref) : LatLng(current.latitude, current.longitude);
      final picked = await navigator.push<NotePoint>(MaterialPageRoute(builder: (_) => _NotePlaceMap(start: start)));
      if (picked != null) await items.setLocation(item.id, picked);
    case final NotePoint point:
      await items.setLocation(item.id, point);
  }
}

// откуда начать карту, когда у заметки места нет: последняя заметка с местом, иначе своё место
Future<LatLng?> _lastPoint(WidgetRef ref) async {
  final points = await ref.read(placesRepositoryProvider).savedPoints();
  if (points.isNotEmpty) {
    final last = points.reduce((a, b) => a.at.isAfter(b.at) ? a : b);
    return LatLng(last.latitude, last.longitude);
  }
  final places = await ref.read(placesRepositoryProvider).all();
  return places.isEmpty ? null : LatLng(places.first.latitude, places.first.longitude);
}

/// Найденное одной строкой: «Strada Cornului 7/1, Chișinău»; город, совпавший с именем, не повторяется.
String _foundName(FoundPlace found) => found.address == null || found.address == found.name ? found.name : '${found.name}, ${found.address}';

class _NotePlaceSheet extends ConsumerStatefulWidget {
  const _NotePlaceSheet({required this.current});

  final NotePoint? current;

  @override
  ConsumerState<_NotePlaceSheet> createState() => _NotePlaceSheetState();
}

class _NotePlaceSheetState extends ConsumerState<_NotePlaceSheet> {
  String _query = '';
  List<FoundPlace>? _found;
  bool _searching = false;
  Timer? _wait;

  // номер запроса: ответ на старый текст не затирает свежий
  int _round = 0;

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }

  void _changed(String text) {
    _wait?.cancel();
    final query = text.trim();
    setState(() {
      _query = query;
      _found = null;
      _searching = query.length >= 3;
    });
    if (query.length < 3) return;
    // поиск ходит в OpenStreetMap: ждём, пока человек допечатает
    _wait = Timer(const Duration(milliseconds: 350), () async {
      final round = ++_round;
      final near = widget.current;
      final found = await ref.read(placeLookupProvider).search(query, nearLatitude: near?.latitude, nearLongitude: near?.longitude);
      if (!mounted || round != _round) return;
      setState(() {
        _found = found;
        _searching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final current = widget.current;
    final places = ref.watch(placesProvider).value ?? const <Place>[];
    final typing = _query.length >= 3;
    final found = _found ?? const <FoundPlace>[];
    return KeyedSubtree(
      key: const ValueKey('note-place-sheet'),
      child: SheetOptionsBody(
        title: l.itemPlaceTitle,
        top: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('note-place-search'),
              // на телефоне клавиатура закрыла бы свои места и «Я здесь»: ищут реже, чем выбирают
              autofocus: DeskMode.of(context),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: Icon(symbolIcon('search')),
                hintText: l.placeSearchHint,
                suffixIcon: _searching
                    ? Padding(padding: const EdgeInsets.all(14), child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Tokens.muted)))
                    : null,
              ),
              onChanged: _changed,
            ),
            if (typing && !_searching && found.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: Text(l.placeSearchNone, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Tokens.muted)),
              ),
          ],
        ),
        children: typing
            ? [
                for (final place in found)
                  SheetOption(
                    title: place.name,
                    subtitle: place.address,
                    icon: 'location_on',
                    onTap: () => Navigator.pop<Object>(context, (latitude: place.latitude, longitude: place.longitude, name: _foundName(place))),
                  ),
              ]
            : [
                if (current != null)
                  SheetOption(title: l.itemPlaceShowMap, subtitle: current.name ?? l.mapPlaceUnnamed, icon: 'map', onTap: () => Navigator.pop<Object>(context, _Action.showOnMap)),
                SheetOption(title: l.placeHereNow, icon: 'my_location', onTap: () => Navigator.pop<Object>(context, _Action.here)),
                SheetOption(title: l.itemPlacePickMap, icon: 'pin_drop', onTap: () => Navigator.pop<Object>(context, _Action.pickOnMap)),
                for (final place in places)
                  SheetOption(
                    title: place.name,
                    icon: placeTypeIcon(typeOf(place)),
                    onTap: () => Navigator.pop<Object>(context, (latitude: place.latitude, longitude: place.longitude, name: place.name)),
                  ),
                if (current != null) SheetOption(title: l.itemPlaceRemove, icon: 'location_off', danger: true, onTap: () => Navigator.pop<Object>(context, _Action.remove)),
              ],
      ),
    );
  }
}

/// Карта с булавкой посередине: двигают карту, а не булавку, внизу — адрес середины и
/// «Поставить сюда». Отдаёт точку с адресом или null, если ушли назад.
class _NotePlaceMap extends ConsumerStatefulWidget {
  const _NotePlaceMap({required this.start});

  /// Откуда начать; не знаем ничего — вся карта мира.
  final LatLng? start;

  @override
  ConsumerState<_NotePlaceMap> createState() => _NotePlaceMapState();
}

class _NotePlaceMapState extends ConsumerState<_NotePlaceMap> {
  final _map = MapController();
  late LatLng _center = widget.start ?? const LatLng(30, 10);

  // адрес середины: ищется, когда карта остановилась; пока ищется — null и _naming
  String? _address;
  Future<String?>? _naming;
  Timer? _wait;
  bool _locating = false;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    if (widget.start != null) _name(_center);
  }

  @override
  void dispose() {
    _wait?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _name(LatLng point) {
    final naming = ref.read(placeLookupProvider).nameAt(point.latitude, point.longitude);
    _naming = naming;
    naming.then((name) {
      if (!mounted || _naming != naming) return;
      setState(() => _address = name);
    }).ignore();
  }

  void _moved(MapCamera camera, bool byHand) {
    _center = camera.center;
    _wait?.cancel();
    if (_address != null || _naming != null) {
      _address = null;
      _naming = null;
      // карта зовёт это и посреди раскладки (узнала свой размер): перерисовка — после кадра
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    // адрес спрашиваем у OpenStreetMap, когда карту отпустили, а не на каждый кадр
    _wait = Timer(const Duration(milliseconds: 500), () => _name(_center));
  }

  Future<void> _here() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    final fix = await ref.read(currentPlaceProvider)();
    if (!mounted) return;
    setState(() => _locating = false);
    if (fix == null) {
      showNote(messenger, isWeb ? l.placesNoFixBrowser : l.placesNoFix);
      return;
    }
    _map.move(LatLng(fix.latitude, fix.longitude), 17);
  }

  Future<void> _set() async {
    setState(() => _placing = true);
    final center = _center;
    _wait?.cancel();
    if (_naming == null) _name(center);
    String? name;
    try {
      name = await _naming!.timeout(const Duration(seconds: 6));
    } catch (_) {
      // адрес не нашёлся — место без названия, точка важнее
    }
    if (!mounted) return;
    Navigator.pop<NotePoint>(context, (latitude: center.latitude, longitude: center.longitude, name: name));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      key: const ValueKey('note-place-map'),
      backgroundColor: Tokens.container,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.start == null ? 3 : 16,
              backgroundColor: Tokens.container,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onPositionChanged: _moved,
            ),
            children: [
              const NightTiles(),
              // карта OpenStreetMap требует подписи
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(8, 8, 8, 132 + bottom),
                  child: Text('© OpenStreetMap', style: TextStyle(fontSize: 10, color: Tokens.muted)),
                ),
              ),
            ],
          ),
          // булавка стоит в середине карты остриём: сдвинута вверх на свою высоту
          IgnorePointer(
            child: Center(child: Transform.translate(offset: const Offset(0, -28), child: const PlacePin(icon: 'location_on'))),
          ),
          Positioned(
            left: 12,
            top: top + 12,
            child: MapRoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, busy: false, onTap: () => Navigator.maybePop(context)),
          ),
          Positioned(
            right: 12,
            top: top + 12,
            child: MapRoundButton(icon: 'my_location', tooltip: l.placeHereNow, busy: _locating, onTap: _locating ? null : _here),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12 + bottom,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                  decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.card)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.itemPlaceTitle, style: text.labelMedium!.copyWith(color: Tokens.muted)),
                      const SizedBox(height: 4),
                      Text(
                        _address ?? (_naming != null ? '…' : l.itemPlaceMapHint),
                        key: const ValueKey('note-place-address'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall!.copyWith(color: Tokens.onSurface),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          key: const ValueKey('note-place-set'),
                          onPressed: _placing ? null : _set,
                          icon: Icon(symbolIcon('check')),
                          label: Text(l.itemPlaceSetHere),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
