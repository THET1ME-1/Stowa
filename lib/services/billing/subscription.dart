import 'package:flutter/foundation.dart';

/// Срок подписки.
enum SubPlan { month, quarter, year }

/// Откуда подписка: выдана вручную, внешняя касса, Google Play, App Store.
enum SubSource { grant, lava, play, apple }

T? _byName<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

/// Снимок подписки аккаунта. Сохраняется на устройстве: настройки, Stowa Sync и панель
/// знают его с первого кадра и без сети.
@immutable
class Subscription {
  const Subscription({
    required this.signedIn,
    this.email,
    this.active = false,
    this.paidUntil,
    this.source,
    this.plan,
    this.autoRenew = false,
    this.cancellable = false,
    this.test = false,
    this.buyerId,
  });

  /// Не вошли.
  static const none = Subscription(signedIn: false);

  /// Ответ `/v1/account`.
  factory Subscription.fromAccount(Map<String, Object?> json) => Subscription(
    signedIn: true,
    email: json['email'] as String?,
    active: json['active'] == true,
    paidUntil: DateTime.tryParse(json['paid_until'] as String? ?? ''),
    source: _byName(SubSource.values, json['source']),
    plan: _byName(SubPlan.values, json['plan']),
    autoRenew: json['auto_renew'] == true,
    cancellable: json['cancellable'] == true,
    test: json['test'] == true,
    buyerId: json['buyer_id'] as String?,
  );

  final bool signedIn;
  final String? email;

  /// Сервер считал подписку действующей в момент снимка.
  final bool active;
  final DateTime? paidUntil;
  final SubSource? source;
  final SubPlan? plan;
  final bool autoRenew;

  /// Продление можно отменить из приложения (внешняя касса).
  final bool cancellable;

  /// Тестовая покупка: песочница Apple, тестировщик Google.
  final bool test;

  /// Номер покупателя: магазин возвращает его в чеке, так сервер узнаёт своего.
  final String? buyerId;

  /// Действует сейчас: снимок мог устареть, срок сверяется с часами.
  bool get activeNow => signedIn && active && paidUntil != null && paidUntil!.isAfter(DateTime.now());

  Map<String, Object?> toJson() => {
    'signed_in': signedIn,
    'email': email,
    'active': active,
    'paid_until': paidUntil?.toUtc().toIso8601String(),
    'source': source?.name,
    'plan': plan?.name,
    'auto_renew': autoRenew,
    'cancellable': cancellable,
    'test': test,
    'buyer_id': buyerId,
  };

  static Subscription fromJson(Map<String, Object?> json) => json['signed_in'] == false ? none : Subscription.fromAccount(json);

  @override
  bool operator ==(Object other) => other is Subscription && mapEquals(toJson(), other.toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}
