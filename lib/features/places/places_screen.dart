import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/place_groups.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_blocks.dart';
import 'place_edit_screen.dart';
import 'place_kinds.dart';

Route<void> placesRoute() => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => const PlacesScreen(),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

// цвет значка вида из палитры папок: дом и аптека различаются с первого взгляда
const _kindColors = {
  PlaceKind.home: 'tangerine',
  PlaceKind.work: 'blue',
  PlaceKind.study: 'violet',
  PlaceKind.shop: 'lime',
  PlaceKind.pharmacy: 'mint',
  PlaceKind.food: 'coral',
  PlaceKind.sport: 'sky',
  PlaceKind.guests: 'rose',
  PlaceKind.other: 'lemon',
};

Color placeKindColor(PlaceKind kind) => FolderPalette.colors[_kindColors[kind]]!;

/// Свои места для напоминаний по месту: сколько угодно, любого вида — две работы,
/// курсы, кафе, квартира друга. Без места «всегда» Android не будит Stowa у точки — об этом карточка сверху.
class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({super.key});

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> with WidgetsBindingObserver {
  bool? _background;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // вернулся из системных настроек — разрешение могло появиться
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final background = await ref.read(placeChannelProvider).hasBackground();
    if (mounted) setState(() => _background = background);
  }

  Future<void> _allow() async {
    await ref.read(placeChannelProvider).askBackground();
    await _check();
  }

  /// Догадка по заметкам: где их сохраняют ночью — дом, днём в будни — работа.
  Future<void> _takeGuess(PlaceKind kind, PlaceGuess guess) async {
    final l = L.of(context);
    await ref.read(placesRepositoryProvider).add(kind, name: placeKindLabel(l, kind), latitude: guess.latitude, longitude: guess.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final all = ref.watch(placesProvider).value ?? const <Place>[];
    final guess = ref.watch(placeGuessProvider).value;
    bool has(PlaceKind kind) => all.any((place) => place.kind == kind);
    final guesses = [
      if (guess?.home case final home? when !has(PlaceKind.home)) (PlaceKind.home, home, l.placesGuessHome(home.name ?? l.mapPlaceUnnamed)),
      if (guess?.work case final work? when !has(PlaceKind.work)) (PlaceKind.work, work, l.placesGuessWork(work.name ?? l.mapPlaceUnnamed)),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            SettingsHeader(l.placesTitle),
            if (_background == false) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
                decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.card)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.placesPermissionTitle, style: text.titleMedium),
                    const SizedBox(height: 8),
                    Text(l.placesPermissionBody, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
                    Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _allow, child: Text(l.placesPermissionAllow))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(l.placesEmpty, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
              ),
            for (final place in all)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PlaceCard(
                  icon: placeKindIcon(place.kind),
                  color: placeKindColor(place.kind),
                  title: place.name,
                  subtitle: _subtitle(l, place),
                  onTap: () => Navigator.of(context).push(placeEditRoute(place: place)),
                ),
              ),
            for (final (kind, found, label) in guesses)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PlaceCard(icon: 'auto_awesome', color: placeKindColor(kind), title: label, subtitle: null, dashed: true, onTap: () => _takeGuess(kind, found)),
              ),
            const SizedBox(height: 4),
            SizedBox(
              height: 52,
              child: FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(placeEditRoute()),
                icon: Icon(symbolIcon('add_location_alt')),
                label: Text(l.placesAdd),
              ),
            ),
            SettingsHint(l.placesHint),
          ],
        ),
      ),
    );
  }
}

/// «Работа · Wi-Fi: Office»; вид не повторяет имя: у «Дома» — только сеть.
String? _subtitle(L l, Place place) {
  final kind = placeKindLabel(l, place.kind);
  final parts = [if (kind != place.name) kind, if (place.wifi != null) l.placesWifi(place.wifi!)];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Карточка места: значок вида в его цвете, имя, вид и сеть. Догадка — без заливки, с рамкой.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap, this.dashed = false});

  final String icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: dashed ? Colors.transparent : Tokens.containerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.tile),
        side: dashed ? BorderSide(color: Tokens.outline) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(symbolIcon(icon, filled: true), size: 22, color: inkOn(color)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyLarge),
                    if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(symbolIcon(dashed ? 'add' : 'chevron_right'), size: 20, color: Tokens.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
