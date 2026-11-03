import 'icon_registry.dart';

// основы русских слов → иконки; основа ловит любую форму: «машина», «машины», «машинка»
const iconWords = <String, List<String>>{
  'машин': ['directions_car', 'car_repair', 'local_gas_station'],
  'авто': ['directions_car', 'car_repair'],
  'гараж': ['garage', 'car_repair'],
  'бензин': ['local_gas_station'],
  'еда': ['restaurant', 'lunch_dining', 'local_pizza'],
  'еду': ['restaurant', 'lunch_dining'],
  'рецепт': ['restaurant', 'menu_book', 'cooking'],
  'кухн': ['cooking', 'kitchen', 'restaurant'],
  'готов': ['cooking', 'restaurant'],
  'кофе': ['local_cafe', 'coffee'],
  'кафе': ['local_cafe', 'restaurant'],
  'ресторан': ['restaurant'],
  'дом': ['home', 'house', 'cottage'],
  'квартир': ['apartment', 'home'],
  'дач': ['cottage', 'yard', 'grass'],
  'ремонт': ['construction', 'build', 'handyman'],
  'инструмент': ['build', 'handyman', 'construction'],
  'работ': ['work', 'business_center', 'laptop'],
  'учеб': ['school', 'menu_book', 'edit_note'],
  'учёб': ['school', 'menu_book', 'edit_note'],
  'школ': ['school', 'backpack'],
  'универ': ['school', 'account_balance'],
  'лекци': ['school', 'co_present'],
  'книг': ['menu_book', 'auto_stories', 'book'],
  'чита': ['menu_book', 'auto_stories'],
  'кино': ['movie', 'theaters', 'local_movies'],
  'фильм': ['movie', 'theaters'],
  'сериал': ['live_tv', 'movie'],
  'видео': ['smart_display', 'videocam', 'movie'],
  'музык': ['music_note', 'headphones', 'queue_music'],
  'песн': ['music_note', 'queue_music'],
  'игр': ['sports_esports', 'casino', 'extension'],
  'спорт': ['fitness_center', 'sports_soccer', 'directions_run'],
  'трениров': ['fitness_center', 'directions_run'],
  'бег': ['directions_run'],
  'здоров': ['favorite', 'medical_services', 'healing'],
  'врач': ['medical_services', 'local_hospital', 'stethoscope'],
  'лекарств': ['medication', 'pill'],
  'аптек': ['local_pharmacy', 'medication'],
  'деньг': ['savings', 'payments', 'account_balance_wallet'],
  'финанс': ['savings', 'account_balance', 'payments'],
  'бюджет': ['savings', 'account_balance_wallet'],
  'покупк': ['shopping_cart', 'shopping_bag'],
  'магазин': ['storefront', 'shopping_cart'],
  'купить': ['shopping_cart', 'shopping_bag'],
  'подар': ['redeem', 'card_giftcard'],
  'праздник': ['celebration', 'cake'],
  'рожден': ['cake', 'celebration'],
  'путешеств': ['flight', 'luggage', 'map'],
  'поездк': ['flight', 'luggage', 'map'],
  'отпуск': ['beach_access', 'flight', 'luggage'],
  'самолет': ['flight'],
  'самолёт': ['flight'],
  'поезд': ['train'],
  'город': ['location_city', 'apartment'],
  'карт': ['map', 'credit_card'],
  'природ': ['park', 'forest', 'eco'],
  'сад': ['yard', 'local_florist', 'grass'],
  'цвет': ['local_florist', 'palette'],
  'животн': ['pets'],
  'кот': ['pets'],
  'кош': ['pets'],
  'собак': ['pets'],
  'ребен': ['child_care', 'toys'],
  'ребён': ['child_care', 'toys'],
  'дет': ['child_care', 'toys'],
  'семь': ['family_restroom', 'favorite'],
  'любов': ['favorite'],
  'идея': ['lightbulb', 'emoji_objects'],
  'иде': ['lightbulb', 'emoji_objects'],
  'замет': ['edit_note', 'sticky_note_2'],
  'код': ['code', 'terminal', 'key'],
  'программ': ['code', 'terminal'],
  'пароль': ['key', 'password', 'lock'],
  'парол': ['key', 'password', 'lock'],
  'ключ': ['key'],
  'ссылк': ['link'],
  'фото': ['photo_camera', 'image', 'photo_library'],
  'камер': ['photo_camera'],
  'телефон': ['smartphone', 'call'],
  'компьютер': ['computer', 'laptop'],
  'документ': ['description', 'folder', 'article'],
  'одежд': ['checkroom', 'apparel'],
  'мод': ['checkroom', 'apparel'],
  'красот': ['spa', 'face'],
  'рисова': ['brush', 'palette', 'draw'],
  'дизайн': ['palette', 'brush', 'design_services'],
  'искусств': ['palette', 'brush'],
  'новост': ['newspaper', 'feed'],
  'важн': ['star', 'priority_high'],
  'избран': ['star', 'favorite'],
  'дел': ['task_alt', 'checklist'],
  'задач': ['task_alt', 'checklist'],
  'список': ['checklist', 'list'],
  'встреч': ['event', 'groups'],
  'календар': ['calendar_month', 'event'],
};

/// Иконки по запросу: русские слова из словаря первыми, потом совпадения в английских именах.
List<String> searchIcons(String query, {int limit = 60}) {
  final words = query.trim().toLowerCase().replaceAll('ё', 'е').split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  final found = <String>[];
  void add(String name) {
    if (!found.contains(name) && symbolNames.contains(name)) found.add(name);
  }

  // основа совпала с началом слова или слово — начало основы (ещё печатают)
  final stems = iconWords.entries.where((entry) {
    final stem = entry.key.replaceAll('ё', 'е');
    return words.any((word) => word.startsWith(stem) || (word.length >= 3 && stem.startsWith(word)));
  }).toList()
    // длинная основа точнее короткой: «дом» не должен проиграть «дел»
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  for (final entry in stems) {
    entry.value.forEach(add);
  }
  final english = words.join('_');
  for (final name in symbolNames) {
    if (found.length >= limit) break;
    if (name.contains(english)) add(name);
  }
  return found.take(limit).toList();
}
