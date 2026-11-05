import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/place_groups.dart';
import '../../l10n/app_localizations.dart';
import '../composer/panel_text.dart';
import '../home/recent_strip.dart';
import '../item/adult_veil.dart';
import '../item/item_screen.dart';

/// Карта заметок. [focusItemId] — открыть сразу на этой вещи (касание места на её странице).
Route<void> mapRoute({String? focusItemId}) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => MapScreen(focusItemId: focusItemId),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

/// Насыщенность карты 45 %: парки ещё зелёные, но улицы не спорят с метками.
const _calm = ColorFilter.matrix([
  0.567, 0.393, 0.040, 0, 0, //
  0.117, 0.843, 0.040, 0, 0, //
  0.117, 0.393, 0.490, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// Где что сохранено. Вещи рядом склеены в одно место, снизу — вещи выбранного.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.focusItemId});

  final String? focusItemId;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _map = MapController();
  PlaceGroup? _selected;
  bool _focused = false;

  Future<void> _goToMe() async {
    final me = await ref.read(whereAmIProvider)();
    if (me == null || !mounted) return;
    _map.move(LatLng(me.$1, me.$2), 15);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final cards = ref.watch(placedItemsProvider).value;
    final filesRoot = ref.watch(filesRootProvider);
    final now = ref.read(clockProvider)();
    final byId = {for (final card in cards ?? const <ItemCard>[]) card.id: card};
    final groups = groupPlaces([
      for (final card in cards ?? const <ItemCard>[]) (id: card.id, latitude: card.latitude!, longitude: card.longitude!),
    ]);
    // вещь, с которой пришли, выбрана сразу
    if (!_focused && widget.focusItemId != null && groups.isNotEmpty) {
      _focused = true;
      _selected = groups.where((group) => group.ids.contains(widget.focusItemId)).firstOrNull;
    }
    final selected = _selected == null ? null : groups.where((group) => group.ids.first == _selected!.ids.first).firstOrNull;
    final selectedCards = [for (final id in selected?.ids ?? const <String>[]) ?byId[id]];
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        children: [
          if (cards != null && groups.isNotEmpty)
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCameraFit: selected != null
                    ? CameraFit.coordinates(coordinates: [LatLng(selected.latitude, selected.longitude)], maxZoom: 16)
                    : CameraFit.coordinates(
                        coordinates: [for (final group in groups) LatLng(group.latitude, group.longitude)],
                        padding: const EdgeInsets.fromLTRB(60, 140, 60, 260),
                        maxZoom: 15,
                      ),
                backgroundColor: Tokens.background,
                onTap: (_, _) => setState(() => _selected = null),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'app.stowa',
                  // светлую карту OSM темним под графит приложения и приглушаем: метки заметок важнее улиц
                  tileBuilder: (context, tile, image) => ColorFiltered(colorFilter: _calm, child: darkModeTileBuilder(context, tile, image)),
                ),
                MarkerLayer(
                  markers: [
                    for (final group in groups)
                      Marker(
                        point: LatLng(group.latitude, group.longitude),
                        width: 64,
                        height: 64,
                        child: _PlaceMark(
                          cards: [for (final id in group.ids) ?byId[id]],
                          filesRoot: filesRoot,
                          selected: selected?.ids.first == group.ids.first,
                          onTap: () => setState(() => _selected = group),
                        ),
                      ),
                  ],
                ),
                // карта OpenStreetMap требует подписи: тихо в углу, над панелью места
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(8, 0, 8, (selected != null ? 260 : 8) + bottom),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Tokens.background.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
                      child: const Text('© OpenStreetMap', style: TextStyle(fontSize: 10, color: Tokens.muted)),
                    ),
                  ),
                ),
              ],
            )
          else if (cards != null)
            // мест пока нет: сказать, откуда они возьмутся
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
                      child: Icon(symbolIcon('map'), size: 32, color: Tokens.muted),
                    ),
                    const SizedBox(height: 16),
                    Text(l.mapEmpty, textAlign: TextAlign.center, style: text.bodyLarge!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
                  ],
                ),
              ),
            ),
          // шапка поверх карты
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 0),
              child: Row(
                children: [
                  _RoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(22)),
                    child: Text(l.mapTitle, style: text.titleMedium),
                  ),
                  const Spacer(),
                  if (groups.isNotEmpty) _RoundButton(icon: 'my_location', tooltip: l.mapWhereAmI, onTap: _goToMe),
                ],
              ),
            ),
          ),
          // вещи выбранного места снизу
          if (selected != null && selectedCards.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(top: 16, bottom: bottom + 16),
                decoration: const BoxDecoration(color: Tokens.containerLow, borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.screen + 4, 0, Space.screen, 12),
                      child: Row(
                        children: [
                          Icon(symbolIcon('location_on', filled: true), size: 20, color: Tokens.onSurface),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedCards.first.placeName ?? l.mapPlaceUnnamed,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium,
                            ),
                          ),
                          Text(l.itemsCount(selectedCards.length), style: text.bodyMedium!.copyWith(color: Tokens.muted)),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: recentCardHeight(MediaQuery.textScalerOf(context)),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                        itemCount: selectedCards.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => RecentCard(
                          item: selectedCards[index],
                          filesRoot: filesRoot,
                          now: now,
                          onTap: () => Navigator.of(context).push(itemRoute(selectedCards[index].id)),
                        ),
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

/// Метка места: фото, если есть, иначе значок вида; число, если вещей несколько.
class _PlaceMark extends StatelessWidget {
  const _PlaceMark({required this.cards, required this.filesRoot, required this.selected, required this.onTap});

  final List<ItemCard> cards;
  final Directory filesRoot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pictured = cards.where((card) => card.thumbPath != null).firstOrNull;
    final photo = pictured?.thumbPath;
    final size = selected ? 52.0 : 44.0;
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: Motion.short,
              curve: Motion.emphasized,
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Tokens.graphite,
                shape: BoxShape.circle,
                border: Border.all(color: selected ? Tokens.accent : Tokens.onSurfaceVariant, width: selected ? 3 : 2),
              ),
              child: ClipOval(
                child: photo != null
                    ? AdultVeil(
                        itemId: pictured!.id,
                        compact: true,
                        child: Image.file(File(p.join(filesRoot.path, photo)), fit: BoxFit.cover, cacheWidth: 160, errorBuilder: (_, _, _) => const SizedBox()),
                      )
                    : Icon(symbolIcon(kindIcon(cards.first.kind)), size: 20, color: Tokens.onSurface),
              ),
            ),
            if (cards.length > 1)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(11), border: Border.all(color: Tokens.background, width: 2)),
                  child: Text('${cards.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Tokens.onAccent)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

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
          decoration: const BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
          child: Icon(symbolIcon(icon), color: Tokens.onSurface),
        ),
      ),
    );
  }
}
