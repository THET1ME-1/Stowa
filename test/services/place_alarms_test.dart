import 'dart:ui';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/places_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/return_plan.dart';
import 'package:stowa/l10n/app_localizations.dart';
import 'package:stowa/services/place_alarms.dart';

import '../helpers/test_app.dart' show FakePlaceChannel;

void main() {
  late AppDatabase db;
  late FakePlaceChannel channel;
  late PlacesRepository places;
  var settings = const ReturnSettings();
  final now = DateTime(2026, 11, 6, 12);

  setUp(() {
    db = AppDatabase.memory();
    channel = FakePlaceChannel();
    places = PlacesRepository(db, clock: () => now);
    settings = const ReturnSettings();
  });
  tearDown(() => db.close());

  PlaceAlarmService service() => PlaceAlarmService(db, channel: channel, settings: () => settings, l: () => lookupL(const Locale('ru')));

  Future<void> note(String id, {String? body, PlaceReminder? place, bool deleted = false}) => db.into(db.items).insert(
        ItemsCompanion.insert(
          id: id,
          kind: ItemKind.note,
          title: id,
          body: Value(body ?? id),
          remindPlace: Value(place?.kind),
          remindLatitude: Value(place?.latitude),
          remindLongitude: Value(place?.longitude),
          remindPlaceName: Value(place?.name),
          deletedAt: Value(deleted ? now : null),
          createdAt: now,
          updatedAt: now,
        ),
      );

  test('точка, дом с сетью Wi-Fi и магазин: у каждой заметки своя тревога, текст готов заранее', () async {
    await places.setOwn(PlaceKind.home, name: 'Дом', latitude: 47.0, longitude: 28.8, wifi: 'HomeNet');
    final shop = await places.addShop(name: 'Linella', latitude: 47.01, longitude: 28.86);
    await note('Купить кофе', body: 'Купить кофе\nв зёрнах', place: const PlaceReminder(PlaceReminderKind.point, latitude: 47.02, longitude: 28.83));
    await note('Полить цветы', place: const PlaceReminder(PlaceReminderKind.home));
    await note('Батарейки', place: const PlaceReminder(PlaceReminderKind.shop));
    // работы нет — напоминание на работе ждёт, тревоги нет; удалённое — тоже нет
    await note('Ключи', place: const PlaceReminder(PlaceReminderKind.work));
    await note('Удалено', place: const PlaceReminder(PlaceReminderKind.home), deleted: true);

    await service().sync();
    final alarms = {for (final alarm in channel.alarms) alarm.id: alarm};
    expect(alarms.keys, unorderedEquals(['note:Купить кофе', 'note:Полить цветы', 'note:Батарейки@$shop']));
    final coffee = alarms['note:Купить кофе']!;
    expect((coffee.title, coffee.body, coffee.payload, coffee.latitude, coffee.radius, coffee.budget), ('Купить кофе', 'в зёрнах', 'note:Купить кофе', 47.02, 150, false));
    expect((alarms['note:Полить цветы']!.wifi, alarms['note:Полить цветы']!.latitude), ('HomeNet', 47.0));
    expect(alarms['note:Батарейки@$shop']!.latitude, 47.01);
  });

  test('сработало — напоминание снимается, тревога больше не ставится', () async {
    await places.setOwn(PlaceKind.home, name: 'Дом', latitude: 47.0, longitude: 28.8);
    final shop = await places.addShop(name: 'Linella', latitude: 47.01, longitude: 28.86);
    await note('Полить цветы', place: const PlaceReminder(PlaceReminderKind.home));
    await note('Батарейки', place: const PlaceReminder(PlaceReminderKind.shop));
    channel.fired.addAll(['note:Полить цветы', 'note:Батарейки@$shop']);
    await service().sync();
    final items = await db.select(db.items).get();
    expect(items.every((item) => item.remindPlace == null), isTrue);
    expect(channel.alarms, isEmpty);
  });

  test('покупки у магазина: по тревоге на магазин, в бюджете дня, с первыми пунктами', () async {
    final shop = await places.addShop(name: 'Linella', latitude: 47.01, longitude: 28.86);
    await note('Купить: Борщ', body: 'Купить: Борщ\n- [ ] свёкла\n- [ ] морковь\n- [ ] капуста\n- [ ] лук');
    await service().sync();
    final alarm = channel.alarms.single;
    expect((alarm.id, alarm.title, alarm.body, alarm.payload, alarm.budget), ('shop:$shop', 'В магазине «Linella»', 'свёкла, морковь, капуста и ещё 1', 'note:Купить: Борщ', true));

    // выключили покупки у магазина — тревоги нет
    settings = const ReturnSettings(shopping: false);
    await service().sync();
    expect(channel.alarms, isEmpty);
  });

  test('тревоги собираются и без Android: разрешение проверяет приёмник, когда ставит их', () async {
    await places.setOwn(PlaceKind.home, name: 'Дом', latitude: 47.0, longitude: 28.8);
    await note('Полить цветы', place: const PlaceReminder(PlaceReminderKind.home));
    final alarms = await service().build();
    expect(alarms, hasLength(1));
  });
}
