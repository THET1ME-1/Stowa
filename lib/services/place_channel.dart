import 'package:flutter/services.dart';

/// Тревога по месту для Android: круг на карте и, у дома и работы, сеть Wi-Fi. Текст готов
/// заранее: приёмник показывает уведомление сам, даже если приложение выгружено.
class PlaceAlarm {
  const PlaceAlarm({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
    required this.latitude,
    required this.longitude,
    this.radius = 150,
    this.wifi,
    this.budget = false,
  });

  /// Уникален на весь список: `note:<id>` или `shop:<id>`.
  final String id;
  final String title;
  final String body;

  /// Куда ведёт касание: `note:<id>` или `return:shopping`.
  final String payload;
  final double latitude;
  final double longitude;
  final int radius;

  /// Сеть дома или работы: подключился — сработало, даже без GPS.
  final String? wifi;

  /// Возвращающее (покупки у магазина): в бюджете дня, одно в день на всех.
  final bool budget;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'payload': payload,
    'latitude': latitude,
    'longitude': longitude,
    'radius': radius,
    'wifi': ?wifi,
    'budget': budget,
  };

  @override
  bool operator ==(Object other) => other is PlaceAlarm && other.toJson().toString() == toJson().toString();

  @override
  int get hashCode => toJson().toString().hashCode;
}

/// Android за тонкой стенкой: разрешение на место «всегда», имя сети Wi-Fi, тревоги.
/// В тестах подменяется.
abstract interface class PlaceChannel {
  /// Место разрешено «всегда»: без этого Android не будит приложение у точки и не отдаёт имя сети.
  Future<bool> hasBackground();

  /// Спросить место «всегда». На Android 11+ это только системные настройки приложения.
  Future<void> askBackground();

  /// Имя сети Wi-Fi, к которой телефон подключён сейчас, или null.
  Future<String?> currentWifi();

  /// Поставить тревоги вместо прежних.
  Future<void> sync(List<PlaceAlarm> alarms);

  /// Какие тревоги сработали с прошлого раза; список после этого пуст.
  Future<List<String>> takeFired();
}

/// Без Android: тесты и кадры.
class SilentPlaceChannel implements PlaceChannel {
  const SilentPlaceChannel();

  @override
  Future<bool> hasBackground() async => false;

  @override
  Future<void> askBackground() async {}

  @override
  Future<String?> currentWifi() async => null;

  @override
  Future<void> sync(List<PlaceAlarm> alarms) async {}

  @override
  Future<List<String>> takeFired() async => const [];
}

/// Канал `stowa/places` к `PlaceAlarms.kt`.
class MethodPlaceChannel implements PlaceChannel {
  const MethodPlaceChannel();

  static const _channel = MethodChannel('stowa/places');

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<bool> hasBackground() async => await _call<bool>('hasBackground') ?? false;

  @override
  Future<void> askBackground() => _call<void>('askBackground');

  @override
  Future<String?> currentWifi() => _call<String>('currentWifi');

  @override
  Future<void> sync(List<PlaceAlarm> alarms) => _call<void>('sync', [for (final alarm in alarms) alarm.toJson()]);

  @override
  Future<List<String>> takeFired() async => (await _call<List<Object?>>('takeFired'))?.whereType<String>().toList() ?? const [];
}
