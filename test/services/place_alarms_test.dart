import 'dart:ui';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/places_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/return_plan.dart';
import 'package:stowa/l10n/app_localizations.dart';
import 'package:stowa/services/place_alarms.dart';
import 'package:stowa/services/place_channel.dart' show PlaceAlarm;

import '../helpers/test_app.dart' show FakePlaceChannel;

void main() {
  late AppDatabase db;
  late FakePlaceChannel channel;
  late PlacesRepository places;
  var settings = const ReturnSettings();
  // пятница, 6 ноября 2026, полдень
  final now = DateTime(2026, 11, 6, 12);

  setUp(() {
    db = AppDatabase.memory();
    channel = FakePlaceChannel();
    places = PlacesRepository(db, clock: () => now);
    settings = const ReturnSettings();
  });
  tearDown(() => db.close());

  PlaceAlarmService service() => PlaceAlarmService(db, channel: channel, settings: () => settings, l: () => lookupL(const Locale('ru')), clock: () => now);

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
          remindPlaceRef: Value(place?.ref),
          remindPlaceDay: Value(place?.day),
          deletedAt: Value(deleted ? now : null),
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<Map<String, PlaceAlarm>> alarms() async {
    await service().sync();
    return {for (final alarm in channel.alarms) alarm.id: alarm};
  }

  test('точка, дом с сетью Wi-Fi и магазин: у каждой заметки своя тревога, текст готов заранее', () async {
    final home = await places.add(PlaceKind.home, name: 'Дом', latitude: 47.0, longitude: 28.8, wifi: 'HomeNet');
    final shop = await places.add(PlaceKind.shop, name: 'Linella', latitude: 47.01, longitude: 28.86);
    await note('Купить кофе', body: 'Купить кофе\nв зёрнах', place: const PlaceReminder(PlaceReminderKind.point, latitude: 47.02, longitude: 28.83));
    await note('Полить цветы', place: const PlaceReminder(PlaceReminderKind.home));
    await note('Батарейки', place: const PlaceReminder(PlaceReminderKind.shop));
    // работы нет — напоминание на работе ждёт, тревоги нет; удалённое — тоже нет
    await note('Ключи', place: const PlaceReminder(PlaceReminderKind.work));
    await note('Удалено', place: const PlaceReminder(PlaceReminderKind.home), deleted: true);

    final found = await alarms();
    expect(found.keys, unorderedEquals(['note:Купить кофе', 'note:Полить цветы@$home', 'note:Батарейки@$shop']));
    final coffee = found['note:Купить кофе']!;
    expect((coffee.title, coffee.body, coffee.payload, coffee.latitude, coffee.radius, coffee.budget), ('Купить кофе', 'в зёрнах', 'note:Купить кофе', 47.02, 150, false));
    expect((found['note:Полить цветы@$home']!.wifi, found['note:Полить цветы@$home']!.latitude), ('HomeNet', 47.0));
    expect(found['note:Батарейки@$shop']!.latitude, 47.01);
  });

  test('две работы и две аптеки: напоминание вида звенит у каждой, своё место — только у него', () async {
    final office = await places.add(PlaceKind.work, name: 'Офис', latitude: 47.0, longitude: 28.8);
    final store = await places.add(PlaceKind.work, name: 'Склад', latitude: 47.1, longitude: 28.9);
    final pharmacyA = await places.add(PlaceKind.pharmacy, name: 'Felicia', latitude: 47.2, longitude: 28.7);
    final pharmacyB = await places.add(PlaceKind.pharmacy, name: 'Hippocrates', latitude: 47.3, longitude: 28.6);
    final sasha = await places.add(PlaceKind.guests, name: 'Саша', latitude: 47.4, longitude: 28.5);
    await note('Ключи', place: const PlaceReminder(PlaceReminderKind.work));
    await note('Витамины', place: const PlaceReminder(PlaceReminderKind.pharmacy));
    await note('Отдать книгу', place: PlaceReminder(PlaceReminderKind.place, ref: sasha, name: 'Саша'));
    // место удалили — напоминание ждёт, тревоги нет
    await note('Забрать зонт', place: const PlaceReminder(PlaceReminderKind.place, ref: 'нет-такого', name: 'Курсы'));

    final found = await alarms();
    expect(found.keys, unorderedEquals(['note:Ключи@$office', 'note:Ключи@$store', 'note:Витамины@$pharmacyA', 'note:Витамины@$pharmacyB', 'note:Отдать книгу@$sasha']));
    expect(found['note:Отдать книгу@$sasha']!.latitude, 47.4);
  });

  test('свой вид «Дача»: напоминание звенит у каждой дачи, а не у других мест «другое»', () async {
    final first = await places.add(PlaceKind.other, name: 'Дача родителей', label: 'Дача', icon: 'cottage', latitude: 47.1, longitude: 28.7);
    final second = await places.add(PlaceKind.other, name: 'Дача Саши', label: 'Дача', icon: 'cottage', latitude: 47.2, longitude: 28.6);
    await places.add(PlaceKind.other, name: 'Гараж', latitude: 47.3, longitude: 28.5);
    await note('Полить огурцы', place: PlaceReminder(PlaceReminderKind.place, ref: placeTypeRef('Дача'), name: 'Дача'));
    final found = await alarms();
    expect(found.keys, unorderedEquals(['note:Полить огурцы@$first', 'note:Полить огурцы@$second']));
  });

  test('день: сегодняшнее звенит, завтрашнее ждёт, вчерашнее снимается', () async {
    final shop = await places.add(PlaceKind.shop, name: 'Linella', latitude: 47.01, longitude: 28.86);
    await note('Хлеб сегодня', place: PlaceReminder(PlaceReminderKind.shop, day: DateTime(2026, 11, 6)));
    await note('Хлеб завтра', place: PlaceReminder(PlaceReminderKind.shop, day: DateTime(2026, 11, 7)));
    await note('Хлеб вчера', place: PlaceReminder(PlaceReminderKind.shop, day: DateTime(2026, 11, 5)));

    final found = await alarms();
    expect(found.keys, ['note:Хлеб сегодня@$shop']);
    Future<Item> read(String id) => (db.select(db.items)..where((t) => t.id.equals(id))).getSingle();
    expect((await read('Хлеб вчера')).remindPlace, isNull);
    expect((await read('Хлеб завтра')).remindPlace, PlaceReminderKind.shop);
  });

  test('сработало — напоминание снимается, тревога больше не ставится', () async {
    final home = await places.add(PlaceKind.home, name: 'Дом', latitude: 47.0, longitude: 28.8);
    final shop = await places.add(PlaceKind.shop, name: 'Linella', latitude: 47.01, longitude: 28.86);
    await note('Полить цветы', place: const PlaceReminder(PlaceReminderKind.home));
    await note('Батарейки', place: const PlaceReminder(PlaceReminderKind.shop));
    channel.fired.addAll(['note:Полить цветы@$home', 'note:Батарейки@$shop']);
    await service().sync();
    final items = await db.select(db.items).get();
    expect(items.every((item) => item.remindPlace == null), isTrue);
    expect(channel.alarms, isEmpty);
  });

  test('покупки у магазина: по тревоге на магазин, в бюджете дня, с первыми пунктами', () async {
    final shop = await places.add(PlaceKind.shop, name: 'Linella', latitude: 47.01, longitude: 28.86);
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
    await places.add(PlaceKind.home, name: 'Дом', latitude: 47.0, longitude: 28.8);
    await note('Полить цветы', place: const PlaceReminder(PlaceReminderKind.home));
    final alarms = await service().build();
    expect(alarms, hasLength(1));
  });
}
