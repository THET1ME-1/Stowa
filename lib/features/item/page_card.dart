import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format/duration_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/database.dart';
import '../../domain/models.dart';
import '../../domain/structured_page.dart' show PageType;
import '../../domain/video_text.dart' show videoAt;
import '../../l10n/app_localizations.dart';

/// Вид страницы ссылки по фактам: рецепт, товар, событие… Не узнана — null.
PageType? pageTypeOf(List<Fact> facts) {
  final detail = facts.where((fact) => fact.kind == FactKind.pageType).map((fact) => fact.detail).firstOrNull;
  return PageType.values.asNameMap()[detail];
}

List<Fact> _of(List<Fact> facts, FactKind kind) => [for (final fact in facts) if (fact.kind == kind) fact];
Fact? _first(List<Fact> facts, FactKind kind) => facts.where((fact) => fact.kind == kind).firstOrNull;

/// Что страница сказала о себе, карточкой: время и порции рецепта, цена товара,
/// когда и где событие, адрес и часы заведения, время чтения статьи, год фильма.
class PageCard extends StatelessWidget {
  const PageCard({super.key, required this.facts, required this.now, required this.onShopping});

  final List<Fact> facts;
  final DateTime now;

  /// Ингредиенты рецепта — в новую заметку-список «Купить».
  final void Function(List<String> ingredients) onShopping;

  /// Есть ли что показать карточкой.
  static bool hasAny(List<Fact> facts) => pageTypeOf(facts) != null && pageTypeOf(facts) != PageType.video;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final type = pageTypeOf(facts)!;
    final ingredients = [for (final fact in _of(facts, FactKind.ingredient)) fact.value];
    // автора пишут и превью, и разметка страницы: одно имя показываем один раз
    final authors = {for (final fact in _of(facts, FactKind.author)) fact.value}.toList();
    final rating = _first(facts, FactKind.rating)?.number;
    final price = _first(facts, FactKind.price);
    final stock = _first(facts, FactKind.inStock)?.number;
    final shops = [for (final fact in _of(facts, FactKind.shop)) fact.value];
    // адрес часто уже начинается с названия места: второй раз его не пишем
    final venue = _first(facts, FactKind.venue)?.value;
    final street = _first(facts, FactKind.address)?.value;
    final address = venue != null && street != null && street.startsWith(venue) ? street : [?venue, ?street].join(', ');
    final place = _first(facts, FactKind.venuePlace);
    final hours = _first(facts, FactKind.openingHours)?.value;
    final rows = <Widget>[
      if (type == PageType.recipe) ...[
        if (_first(facts, FactKind.timeNeeded)?.number case final minutes?) _line('schedule', l.minutesShort(minutes.round())),
        if (_first(facts, FactKind.servings)?.number case final servings?) _line('restaurant', l.servings(servings.round())),
      ],
      if (type == PageType.product) ...[
        if (stock != null) _line('inventory_2', stock > 0 ? l.inStock : l.outOfStock),
        if (shops.isNotEmpty) _line('storefront', shops.join(' · ')),
      ],
      if (type == PageType.event) ?_eventLine(l),
      if (address.isNotEmpty) _line('location_on', address, onTap: () => _openMap(place, address)),
      if (hours != null) _line('schedule', hours),
      if (type == PageType.article) ...[
        // сохранённый текст статьи считает минуты точнее разметки: число то же, что на «Читать»
        if (int.tryParse(_first(facts, FactKind.articleText)?.detail ?? '') ?? _first(facts, FactKind.readingTime)?.number?.round() case final minutes?)
          _line('schedule', l.readingMinutes(minutes)),
        if (_first(facts, FactKind.published)?.at case final published?) _line('calendar_today', _day(l, published)),
      ],
      if (const {PageType.movie, PageType.series, PageType.comic, PageType.book}.contains(type))
        if (_first(facts, FactKind.year)?.number case final year?) _line('calendar_today', '${year.round()}'),
      if (authors.isNotEmpty && type != PageType.product) _line('person', authors.join(', ')),
      if (rating != null) _line('star', rating.toStringAsFixed(rating == rating.roundToDouble() ? 0 : 1)),
    ];
    return Container(
      key: const ValueKey('item-page-card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_capitalized(_kind(l, type)), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Tokens.onSurfaceVariant)),
          if (price != null && type == PageType.product) ...[
            const SizedBox(height: 6),
            Text(price.value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Tokens.onSurface, height: 1.1)),
          ],
          for (final row in rows) ...[const SizedBox(height: 10), row],
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final ingredient in ingredients)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8, right: 10),
                      child: SizedBox(width: 5, height: 5, child: DecoratedBox(decoration: BoxDecoration(color: Tokens.onSurfaceVariant, shape: BoxShape.circle))),
                    ),
                    Expanded(child: Text(ingredient, style: const TextStyle(fontSize: 15, height: 1.4, color: Tokens.onSurface))),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('recipe-shopping'),
              onPressed: () => onShopping(ingredients),
              style: FilledButton.styleFrom(backgroundColor: Tokens.accent, foregroundColor: Tokens.onAccent),
              icon: Icon(symbolIcon('shopping_cart'), size: 18),
              label: Text(l.toShoppingList),
            ),
          ],
        ],
      ),
    );
  }

  String _kind(L l, PageType type) => switch (type) {
    PageType.recipe => l.pageRecipe,
    PageType.product => l.pageProduct,
    PageType.event => l.pageEvent,
    PageType.place => l.pagePlace,
    PageType.movie => l.pageMovie,
    PageType.series => l.pageSeries,
    PageType.comic => l.pageComic,
    PageType.book => l.pageBook,
    PageType.video => l.pageVideo,
    PageType.article => l.pageArticle,
  };

  String _capitalized(String text) => text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

  String _day(L l, DateTime at) => (at.year == now.year ? DateFormat.MMMMd(l.localeName) : DateFormat.yMMMMd(l.localeName)).format(at);

  // «Пятница, 20 ноября, 19:00–22:00»
  Widget? _eventLine(L l) {
    final start = _first(facts, FactKind.eventStart)?.at;
    if (start == null) return null;
    final end = _first(facts, FactKind.eventEnd)?.at;
    final day = (start.year == now.year ? DateFormat.MMMMEEEEd(l.localeName) : DateFormat.yMMMMEEEEd(l.localeName)).format(start);
    final time = DateFormat.Hm(l.localeName);
    final sameDay = end != null && end.year == start.year && end.month == start.month && end.day == start.day;
    final midnight = start.hour == 0 && start.minute == 0;
    final label = midnight ? day : '$day, ${time.format(start)}${sameDay ? '–${time.format(end)}' : ''}';
    return _line('event', '${label[0].toUpperCase()}${label.substring(1)}');
  }

  Widget _line(String icon, String label, {VoidCallback? onTap}) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(symbolIcon(icon), size: 18, color: Tokens.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 15, height: 1.35, color: Tokens.onSurface, decoration: onTap == null ? null : TextDecoration.underline, decorationColor: Tokens.onSurfaceVariant),
          ),
        ),
      ],
    );
    return onTap == null ? row : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }

  // карта телефона: по координатам, а нет их — по адресу
  Future<void> _openMap(Fact? place, String address) async {
    final latitude = place?.number;
    final longitude = double.tryParse(place?.detail ?? '');
    final uri = latitude != null && longitude != null
        ? Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude(${Uri.encodeComponent(address)})')
        : Uri.parse('geo:0,0?q=${Uri.encodeComponent(address)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  }
}

/// Главы ролика: касание открывает его с начала главы.
class ChaptersBlock extends StatelessWidget {
  const ChaptersBlock({super.key, required this.facts, required this.url});

  final List<Fact> facts;
  final String url;

  static bool hasAny(List<Fact> facts) => facts.any((fact) => fact.kind == FactKind.chapter);

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final video = Uri.tryParse(url);
    final chapters = [for (final fact in facts) if (fact.kind == FactKind.chapter && fact.number != null) fact];
    return Container(
      key: const ValueKey('item-chapters'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: Text(l.chaptersTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Tokens.onSurfaceVariant)),
          ),
          for (final chapter in chapters)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: video == null ? null : () => launchUrl(videoAt(video, chapter.number!.floor()), mode: LaunchMode.externalApplication).ignore(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        formatClock(Duration(seconds: chapter.number!.floor())),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Tokens.onSurface, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ),
                    Expanded(child: Text(chapter.value, style: const TextStyle(fontSize: 15, color: Tokens.onSurface))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Хэштеги автора, которых у вещи ещё нет: касание ставит тег.
class SuggestedTags extends StatelessWidget {
  const SuggestedTags({super.key, required this.facts, required this.own, required this.onAdd});

  final List<Fact> facts;
  final Set<String> own;
  final ValueChanged<String> onAdd;

  static List<String> of(List<Fact> facts, Set<String> own) {
    final lower = {for (final tag in own) tag.toLowerCase()};
    return {for (final fact in facts) if (fact.kind == FactKind.hashtag && !lower.contains(fact.value.toLowerCase())) fact.value}.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tags = of(facts, own);
    return Wrap(
      key: const ValueKey('item-suggested-tags'),
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l.authorTags, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Tokens.onSurfaceVariant)),
        for (final tag in tags)
          Tooltip(
            message: l.tagAdd,
            child: Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Tokens.containerHighest)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onAdd(tag),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(symbolIcon('add'), size: 16, color: Tokens.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('#$tag', style: const TextStyle(fontSize: 14, color: Tokens.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
