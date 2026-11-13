import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';

/// Значок вида места: на карточке места, в листе «Напомнить» и в выборе вида.
String placeKindIcon(PlaceKind kind) => switch (kind) {
  PlaceKind.home => 'home',
  PlaceKind.work => 'work',
  PlaceKind.study => 'school',
  PlaceKind.shop => 'storefront',
  PlaceKind.pharmacy => 'local_pharmacy',
  PlaceKind.food => 'restaurant',
  PlaceKind.sport => 'fitness_center',
  PlaceKind.guests => 'groups',
  PlaceKind.other => 'location_on',
};

String placeKindLabel(L l, PlaceKind kind) => switch (kind) {
  PlaceKind.home => l.placeKindHome,
  PlaceKind.work => l.placeKindWork,
  PlaceKind.study => l.placeKindStudy,
  PlaceKind.shop => l.placeKindShop,
  PlaceKind.pharmacy => l.placeKindPharmacy,
  PlaceKind.food => l.placeKindFood,
  PlaceKind.sport => l.placeKindSport,
  PlaceKind.guests => l.placeKindGuests,
  PlaceKind.other => l.placeKindOther,
};

/// Значок напоминания по месту: у вида — значок вида, у точки — «здесь».
String remindPlaceIcon(PlaceReminderKind kind) => switch (kind) {
  PlaceReminderKind.point => 'my_location',
  PlaceReminderKind.place => 'location_on',
  _ => placeKindIcon(placeKindOf(kind)!),
};
