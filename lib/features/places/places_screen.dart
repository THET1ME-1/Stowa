import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/place_groups.dart';
import '../../l10n/app_localizations.dart';

Route<void> placesRoute() => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => const PlacesScreen(),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

/// Дом, работа и магазины для напоминаний по месту и покупок у магазина.
/// Без места «всегда» Android не будит Stowa у точки — об этом карточка сверху.
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

  /// Где телефон сейчас, с названием. Не вышло — плашка, почему.
  Future<({double latitude, double longitude, String? name})?> _here() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final fix = await ref.read(currentPlaceProvider)();
    if (fix == null) {
      showNote(messenger, l.placesNoFix);
      return null;
    }
    return (latitude: fix.latitude, longitude: fix.longitude, name: fix.name);
  }

  Future<void> _own(PlaceKind kind, Place? current, PlaceGuess? guess) async {
    final l = L.of(context);
    final title = kind == PlaceKind.home ? l.placesHome : l.placesWork;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Tokens.container,
      builder: (sheet) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Icon(symbolIcon('my_location')), title: Text(kind == PlaceKind.home ? l.placesImHome : l.placesImWork), onTap: () => Navigator.pop(sheet, 'here')),
            if (guess != null)
              ListTile(
                leading: Icon(symbolIcon('auto_awesome')),
                title: Text(kind == PlaceKind.home ? l.placesGuessHome(guess.name ?? l.mapPlaceUnnamed) : l.placesGuessWork(guess.name ?? l.mapPlaceUnnamed)),
                onTap: () => Navigator.pop(sheet, 'guess'),
              ),
            if (current != null)
              ListTile(
                leading: Icon(symbolIcon('delete'), color: Tokens.error),
                title: Text(l.placesRemove, style: const TextStyle(color: Tokens.error)),
                onTap: () => Navigator.pop(sheet, 'remove'),
              ),
          ],
        ),
      ),
    );
    final places = ref.read(placesRepositoryProvider);
    switch (choice) {
      case 'here':
        final here = await _here();
        if (here == null) return;
        // сеть читается только с местом «всегда» — без него просто без Wi-Fi
        final wifi = await ref.read(placeChannelProvider).currentWifi();
        await places.setOwn(kind, name: here.name ?? title, latitude: here.latitude, longitude: here.longitude, wifi: wifi);
      case 'guess':
        await places.setOwn(kind, name: guess!.name ?? title, latitude: guess.latitude, longitude: guess.longitude);
      case 'remove':
        await places.removeKind(kind);
    }
  }

  Future<void> _addShop() async {
    final l = L.of(context);
    final here = await _here();
    if (here == null || !mounted) return;
    final saved = await showDialog<String>(context: context, builder: (dialog) => _ShopNameDialog(initial: here.name ?? '', l: l));
    if (saved == null || saved.trim().isEmpty) return;
    await ref.read(placesRepositoryProvider).addShop(name: saved.trim(), latitude: here.latitude, longitude: here.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final all = ref.watch(placesProvider).value ?? const <Place>[];
    final guess = ref.watch(placeGuessProvider).value;
    final home = all.where((place) => place.kind == PlaceKind.home).firstOrNull;
    final work = all.where((place) => place.kind == PlaceKind.work).firstOrNull;
    final shops = [for (final place in all) if (place.kind == PlaceKind.shop) place];

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(title, style: text.titleSmall!.copyWith(color: Tokens.onSurfaceVariant)),
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 40),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: Tokens.containerHigh, fixedSize: const Size.square(44)),
                  icon: Icon(symbolIcon('arrow_back'), size: 20, color: Tokens.onSurface),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(l.placesTitle, style: text.titleLarge!.copyWith(fontSize: 18))),
              ],
            ),
            if (_background == false) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
                decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(28)),
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
            _PlaceTile(icon: 'home', title: l.placesHome, place: home, notSet: l.placesNotSet, onTap: () => _own(PlaceKind.home, home, guess?.home)),
            const SizedBox(height: 6),
            _PlaceTile(icon: 'work', title: l.placesWork, place: work, notSet: l.placesNotSet, onTap: () => _own(PlaceKind.work, work, guess?.work)),
            section(l.placesShops),
            for (final shop in shops)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _PlaceTile(
                  icon: 'storefront',
                  title: shop.name,
                  place: null,
                  notSet: null,
                  onRemove: () => ref.read(placesRepositoryProvider).remove(shop.id),
                  removeTooltip: l.placesRemove,
                ),
              ),
            _PlaceTile(icon: 'add_location_alt', title: l.placesImShop, place: null, notSet: null, onTap: _addShop),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
              child: Text(l.placesHint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Как назвать магазин: подсказано улицей от геокодера, человек пишет своё — «Linella».
class _ShopNameDialog extends StatefulWidget {
  const _ShopNameDialog({required this.initial, required this.l});

  final String initial;
  final L l;

  @override
  State<_ShopNameDialog> createState() => _ShopNameDialogState();
}

class _ShopNameDialogState extends State<_ShopNameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return AlertDialog(
      backgroundColor: Tokens.containerHigh,
      title: Text(l.placesShopName),
      content: TextField(controller: _name, autofocus: true, textCapitalization: TextCapitalization.sentences, onSubmitted: (value) => Navigator.pop(context, value)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _name.text), child: Text(l.placesSave)),
      ],
    );
  }
}

/// Строка места: значок, название и, у дома и работы, что отмечено и какая сеть.
class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.icon, required this.title, required this.place, required this.notSet, this.onTap, this.onRemove, this.removeTooltip});

  final String icon;
  final String title;
  final Place? place;

  /// Подпись, пока место не отмечено; null — строка без подписи (магазин, «запомнить»).
  final String? notSet;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final String? removeTooltip;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final value = place?.name ?? notSet;
    final wifi = place?.wifi;
    return Material(
      color: Tokens.containerHigh,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, onRemove == null ? 16 : 4, 12),
          child: Row(
            children: [
              Icon(symbolIcon(icon), size: 22, color: Tokens.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.bodyLarge),
                    if (value != null) Text(value, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
                    if (wifi != null) Text(l.placesWifi(wifi), style: text.bodySmall!.copyWith(color: Tokens.muted)),
                  ],
                ),
              ),
              if (onRemove != null) IconButton(tooltip: removeTooltip, onPressed: onRemove, icon: Icon(symbolIcon('close'), size: 20, color: Tokens.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
