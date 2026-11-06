import 'package:drift/drift.dart';

import '../data/db/database.dart';
import '../data/repositories/items_repository.dart';
import '../data/repositories/places_repository.dart';
import '../data/repositories/return_repository.dart';
import '../domain/models.dart';
import '../domain/return_plan.dart';
import '../l10n/app_localizations.dart';
import 'place_channel.dart';
import 'reminder_service.dart' show reminderText;

// в уведомлении покупок — первые пункты, остальное «и ещё N»
const _shownItems = 3;

/// Держит тревоги Android в согласии с базой: заметки с напоминанием по месту и покупки
/// у отмеченных магазинов. Сработавшие снимает в базе, как «Готово».
class PlaceAlarmService {
  PlaceAlarmService(this._db, {required PlaceChannel channel, required ReturnSettings Function() settings, required L Function() l})
    : _channel = channel, // ignore: prefer_initializing_formals
      _settings = settings, // ignore: prefer_initializing_formals
      _l = l; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final PlaceChannel _channel;
  final ReturnSettings Function() _settings;
  final L Function() _l;

  /// Снять сработавшее, собрать тревоги заново и отдать их Android.
  Future<void> sync() async {
    final items = ItemsRepository(_db);
    for (final id in await _channel.takeFired()) {
      // «note:<id>» или «note:<id>@<магазин>»: напоминание одно, сколько бы магазинов ни было
      if (!id.startsWith('note:')) continue;
      await items.setPlaceReminder(id.substring(5).split('@').first, null);
    }
    await _channel.sync(await build(), channelName: _l().placeChannel);
  }

  /// Тревоги из базы. Дом или работа не отмечены — их заметки ждут, тревоги нет.
  Future<List<PlaceAlarm>> build() async {
    final l = _l();
    final places = await PlacesRepository(_db).all();
    final home = places.where((place) => place.kind == PlaceKind.home).firstOrNull;
    final work = places.where((place) => place.kind == PlaceKind.work).firstOrNull;
    final shops = [for (final place in places) if (place.kind == PlaceKind.shop) place];
    final notes = await (_db.select(_db.items)..where((t) => t.remindPlace.isNotNull() & t.deletedAt.isNull())).get();

    final alarms = <PlaceAlarm>[];
    PlaceAlarm alarm(Item item, {required String id, required double latitude, required double longitude, int radius = 150, String? wifi}) => PlaceAlarm(
      id: id,
      title: item.title,
      body: reminderText(item.title, item.body),
      payload: 'note:${item.id}',
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      wifi: wifi,
    );
    for (final item in notes) {
      switch (item.remindPlace!) {
        case PlaceReminderKind.point:
          if (item.remindLatitude == null || item.remindLongitude == null) continue;
          alarms.add(alarm(item, id: 'note:${item.id}', latitude: item.remindLatitude!, longitude: item.remindLongitude!));
        case PlaceReminderKind.home || PlaceReminderKind.work:
          final place = item.remindPlace == PlaceReminderKind.home ? home : work;
          if (place == null) continue;
          alarms.add(alarm(item, id: 'note:${item.id}', latitude: place.latitude, longitude: place.longitude, radius: place.radius, wifi: place.wifi));
        case PlaceReminderKind.shop:
          for (final shop in shops) {
            alarms.add(alarm(item, id: 'note:${item.id}@${shop.id}', latitude: shop.latitude, longitude: shop.longitude, radius: shop.radius));
          }
      }
    }

    // покупки всплывают у любого отмеченного магазина — это возвращающее, в бюджете дня
    if (_settings().shopping && shops.isNotEmpty) {
      final lists = await ReturnRepository(_db).shopping();
      if (lists.isNotEmpty) {
        final wanted = [for (final list in lists) ...(list.items.isEmpty ? [list.title] : list.items)];
        final shown = wanted.take(_shownItems).join(', ');
        final body = wanted.length > _shownItems ? l.returnShopMore(shown, wanted.length - _shownItems) : shown;
        final payload = lists.length == 1 ? 'note:${lists.single.id}' : 'return:${ReturnKind.shopping.name}';
        for (final shop in shops) {
          alarms.add(
            PlaceAlarm(
              id: 'shop:${shop.id}',
              title: l.returnShopTitle(shop.name),
              body: body,
              payload: payload,
              latitude: shop.latitude,
              longitude: shop.longitude,
              radius: shop.radius,
              budget: true,
            ),
          );
        }
      }
    }
    return alarms;
  }
}
