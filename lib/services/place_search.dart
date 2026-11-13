import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import 'place_service.dart' show lookupPlaceName, placeLabel, streetOf;

/// Найденное по запросу: название, адрес под ним и точка.
class FoundPlace {
  const FoundPlace({required this.name, this.address, required this.latitude, required this.longitude});

  final String name;
  final String? address;
  final double latitude;
  final double longitude;
}

/// Поиск адреса и места по названию и название точки на карте. Тесты подменяют.
abstract interface class PlaceLookup {
  /// До шести мест; [nearLatitude] и [nearLongitude] — где карта: ближние выше.
  Future<List<FoundPlace>> search(String query, {double? nearLatitude, double? nearLongitude});

  /// Как назвать точку: «Strada Alexei Mateevici 60, Chișinău».
  Future<String?> nameAt(double latitude, double longitude);
}

/// Места из ответа Photon (`photon.komoot.io/api`, GeoJSON по OpenStreetMap).
List<FoundPlace> placesFromPhoton(Map<String, Object?> json) {
  final features = json['features'];
  if (features is! List) return const [];
  final found = <FoundPlace>[];
  for (final feature in features.whereType<Map>()) {
    final properties = feature['properties'];
    final geometry = feature['geometry'];
    if (properties is! Map || geometry is! Map) continue;
    final point = geometry['coordinates'];
    if (point is! List || point.length < 2 || point[0] is! num || point[1] is! num) continue;
    String? field(String key) => properties[key] is String && (properties[key] as String).trim().isNotEmpty ? (properties[key] as String).trim() : null;
    final street = [field('street'), field('housenumber')].nonNulls.join(' ');
    final city = field('city') ?? field('locality') ?? field('county') ?? field('state');
    final name = field('name') ?? (street.isEmpty ? city : street);
    if (name == null) continue;
    // под названием — улица с домом и город, без повтора названия
    final address = [if (street.isNotEmpty && street != name) street, if (city != null && city != name) city].join(', ');
    found.add(FoundPlace(name: name, address: address.isEmpty ? null : address, latitude: (point[1] as num).toDouble(), longitude: (point[0] as num).toDouble()));
  }
  return found;
}

/// Photon (места и адреса OpenStreetMap, без ключа) и геокодер телефона: он понимает
/// адрес на языке человека («Пушкина 52»), когда в OpenStreetMap улица записана латиницей.
class OnlinePlaceLookup implements PlaceLookup {
  OnlinePlaceLookup({required this.client, required this.language});

  final http.Client client;
  final String Function() language;

  static const _limit = 6;

  @override
  Future<List<FoundPlace>> search(String query, {double? nearLatitude, double? nearLongitude}) async {
    final text = query.trim();
    if (text.length < 3) return const [];
    final results = await Future.wait([_photon(text, nearLatitude, nearLongitude), _device(text)]);
    // адрес с номером дома телефон находит точнее, название места — OpenStreetMap
    final ordered = RegExp(r'\d').hasMatch(text) ? [...results[1], ...results[0]] : [...results[0], ...results[1]];
    final unique = <FoundPlace>[];
    for (final place in ordered) {
      final near = unique.any((one) => (one.latitude - place.latitude).abs() < 0.0005 && (one.longitude - place.longitude).abs() < 0.0005);
      if (!near) unique.add(place);
    }
    return unique.take(_limit).toList();
  }

  Future<List<FoundPlace>> _photon(String query, double? latitude, double? longitude) async {
    try {
      final uri = Uri.https('photon.komoot.io', '/api', {
        'q': query,
        'limit': '$_limit',
        if (latitude != null && longitude != null) ...{
          'lat': latitude.toStringAsFixed(4),
          'lon': longitude.toStringAsFixed(4),
          // ближнее сильно важнее известного: «Linella» — та, что в твоём городе
          'zoom': '12',
          'location_bias_scale': '0.1',
        },
      });
      final response = await client.get(uri, headers: {'user-agent': 'Stowa/0.1 (github.com/THET1ME-1/Stowa)'}).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return const [];
      return placesFromPhoton(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>);
    } catch (_) {
      return const [];
    }
  }

  Future<List<FoundPlace>> _device(String query) async {
    try {
      final geocoding = Geocoding();
      final locale = Locale(language());
      final points = await geocoding.locationFromAddress(query, locale: locale).timeout(const Duration(seconds: 5));
      final found = <FoundPlace>[];
      for (final point in points.take(2)) {
        final marks = await geocoding.placemarkFromCoordinates(point.latitude, point.longitude, locale: locale).timeout(const Duration(seconds: 4));
        final mark = marks.firstOrNull;
        final street = mark == null ? null : streetOf(street: mark.street, thoroughfare: mark.thoroughfare, subThoroughfare: mark.subThoroughfare);
        final name = street ?? placeLabel(subLocality: mark?.subLocality, locality: mark?.locality, administrativeArea: mark?.administrativeArea) ?? query;
        final city = mark?.locality ?? mark?.administrativeArea;
        found.add(FoundPlace(name: name, address: city == name ? null : city, latitude: point.latitude, longitude: point.longitude));
      }
      return found;
    } catch (_) {
      // геокодера на прошивке нет или он ничего не знает
      return const [];
    }
  }

  @override
  Future<String?> nameAt(double latitude, double longitude) => lookupPlaceName(client, language(), latitude, longitude);
}
