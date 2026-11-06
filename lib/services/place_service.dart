import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:drift/drift.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../data/db/database.dart';
import '../domain/models.dart';

/// Где человек сейчас: координаты и, если нашлось, название места.
class PlaceFix {
  const PlaceFix({required this.latitude, required this.longitude, this.name});

  final double latitude;
  final double longitude;
  final String? name;
}

/// Откуда берётся место. Настоящий — GPS телефона, в тестах — подставной.
abstract interface class PlaceSource {
  Future<PlaceFix?> current();
}

/// Одно место живёт столько: заметки подряд не дёргают GPS каждый раз.
const _fixFresh = Duration(minutes: 2);

/// Ставит вещи место, где её сохранили. Сохранение этого не ждёт: место
/// дописывается следом, когда телефон его нашёл. Нет разрешения или выключено
/// в настройках — вещь просто без места.
class PlaceService {
  PlaceService(this._db, {required PlaceSource source, required DateTime Function() clock, required bool Function() enabled})
    : _source = source, // ignore: prefer_initializing_formals
      _clock = clock, // ignore: prefer_initializing_formals
      _enabled = enabled; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final PlaceSource _source;
  final DateTime Function() _clock;
  final bool Function() _enabled;

  PlaceFix? _last;
  DateTime? _lastAt;
  Future<PlaceFix?>? _asking;

  /// Место, где сохранено, — если оно включено в настройках. «Напомни тут» берёт точку
  /// напоминания всегда: о ней человек попросил сам.
  Future<void> stamp(String itemId) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
    final remindHere = item?.remindPlace == PlaceReminderKind.point && item?.remindLatitude == null;
    final enabled = _enabled();
    if (!enabled && !remindHere) return;
    final fix = await _fix();
    if (fix == null) return;
    await (_db.update(_db.items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(
        latitude: enabled ? Value(fix.latitude) : const Value.absent(),
        longitude: enabled ? Value(fix.longitude) : const Value.absent(),
        placeName: enabled ? Value(fix.name) : const Value.absent(),
        remindLatitude: remindHere ? Value(fix.latitude) : const Value.absent(),
        remindLongitude: remindHere ? Value(fix.longitude) : const Value.absent(),
        remindPlaceName: remindHere ? Value(fix.name) : const Value.absent(),
      ),
    );
  }

  Future<PlaceFix?> _fix() async {
    final at = _lastAt;
    if (_last != null && at != null && _clock().difference(at) < _fixFresh) return _last;
    // две вещи за секунду: второй запрос ждёт первый, а не просит GPS снова
    final fix = await (_asking ??= _source.current().whenComplete(() => _asking = null));
    if (fix != null) {
      _last = fix;
      _lastAt = _clock();
    }
    return fix;
  }
}

/// Короткое название: улица или район и город — «Ботаника, Кишинёв», без индекса и страны.
String? placeLabel({String? street, String? subLocality, String? locality, String? administrativeArea}) {
  String? clean(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
  final near = clean(street) ?? clean(subLocality);
  final city = clean(locality) ?? clean(administrativeArea);
  if (near == null) return city;
  if (city == null || city == near) return near;
  return '$near, $city';
}

/// То же из ответа OpenStreetMap (`/reverse?format=jsonv2`).
String? placeLabelFromNominatim(Map<String, Object?> json) {
  final address = json['address'];
  if (address is! Map) return null;
  String? field(List<String> keys) => keys.map((key) => address[key]).whereType<String>().firstOrNull;
  return placeLabel(
    street: field(['road', 'pedestrian', 'square']),
    subLocality: field(['suburb', 'neighbourhood', 'quarter']),
    locality: field(['city', 'town', 'village', 'hamlet']),
  );
}

/// Место с телефона: последнее известное, если свежее, иначе новое. Через
/// системный LocationManager, без сервисов Google: работает и на прошивках без них.
class DevicePlaceSource implements PlaceSource {
  const DevicePlaceSource({required this.client, required this.language});

  final http.Client client;

  /// Язык названий: «Кишинёв» по-русски, «Chișinău» по-румынски.
  final String Function() language;

  @override
  Future<PlaceFix?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;

      var position = await Geolocator.getLastKnownPosition(forceAndroidLocationManager: true);
      if (position == null || DateTime.now().difference(position.timestamp) > const Duration(minutes: 5)) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(accuracy: LocationAccuracy.medium, forceLocationManager: true, timeLimit: const Duration(seconds: 15)),
        );
      }
      final name = await _name(position.latitude, position.longitude);
      return PlaceFix(latitude: position.latitude, longitude: position.longitude, name: name);
    } catch (_) {
      // нет сенсора, нет разрешения, не успел — вещь обойдётся без места
      return null;
    }
  }

  Future<String?> _name(double latitude, double longitude) async {
    try {
      final marks = await Geocoding().placemarkFromCoordinates(latitude, longitude, locale: Locale(language())).timeout(const Duration(seconds: 6));
      final mark = marks.firstOrNull;
      final label = mark == null ? null : placeLabel(street: mark.street, subLocality: mark.subLocality, locality: mark.locality, administrativeArea: mark.administrativeArea);
      if (label != null) return label;
    } catch (_) {
      // на прошивке без геокодера спросим OpenStreetMap
    }
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': latitude.toStringAsFixed(5),
        'lon': longitude.toStringAsFixed(5),
        'zoom': '17',
        'accept-language': language(),
      });
      final response = await client.get(uri, headers: {'user-agent': 'Stowa/0.1 (github.com/THET1ME-1/Stowa)'}).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      return placeLabelFromNominatim(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>);
    } catch (_) {
      return null;
    }
  }
}
