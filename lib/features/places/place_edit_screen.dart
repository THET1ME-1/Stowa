import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
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

// карта темнится под графит приложения и приглушается, как на экране карты
const _calm = ColorFilter.matrix([
  0.567, 0.393, 0.040, 0, 0, //
  0.117, 0.843, 0.040, 0, 0, //
  0.117, 0.393, 0.490, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// Место для напоминаний: имя, вид и точка. Точку даёт «Я сейчас здесь» или карта:
/// стоять у места не нужно — квартиру друга или ресторан ставят издалека.
class PlaceEditScreen extends ConsumerStatefulWidget {
  const PlaceEditScreen({super.key, this.place});

  final Place? place;

  @override
  ConsumerState<PlaceEditScreen> createState() => _PlaceEditScreenState();
}

class _PlaceEditScreenState extends ConsumerState<PlaceEditScreen> {
  late final _name = TextEditingController(text: widget.place?.name ?? '');
  final _map = MapController();
  late PlaceKind _kind = widget.place?.kind ?? PlaceKind.other;
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
    final name = typed.isNotEmpty ? typed : (_pointName ?? placeKindLabel(l, _kind));
    HapticFeedback.selectionClick();
    final current = widget.place;
    if (current == null) {
      // Wi-Fi узнаёт дом и работу без GPS; у кафе и друзей сеть чужая
      final ownNetwork = _kind == PlaceKind.home || _kind == PlaceKind.work;
      await places.add(_kind, name: name, latitude: point.latitude, longitude: point.longitude, wifi: ownNetwork ? _wifi : null);
    } else {
      await places.update(current.id, name: name, kind: _kind, latitude: point.latitude, longitude: point.longitude);
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
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(hintText: l.placeNameHint),
                    ),
                    SettingsSection(l.placeKindTitle),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final kind in PlaceKind.values)
                          ChoiceChip(
                            avatar: Icon(symbolIcon(placeKindIcon(kind), filled: kind == _kind), size: 18, color: kind == _kind ? Tokens.onAccent : Tokens.onSurfaceVariant),
                            label: Text(placeKindLabel(l, kind)),
                            labelStyle: TextStyle(color: kind == _kind ? Tokens.onAccent : Tokens.onSurface),
                            selectedColor: Tokens.accent,
                            selected: kind == _kind,
                            showCheckmark: false,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setState(() => _kind = kind);
                            },
                          ),
                      ],
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
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'app.stowa',
                            tileBuilder: (context, tile, image) => ColorFiltered(colorFilter: _calm, child: darkModeTileBuilder(context, tile, image)),
                          ),
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
                          child: Icon(symbolIcon(placeKindIcon(_kind), filled: true), size: 36, color: _point == null ? Tokens.muted : Tokens.accent),
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
