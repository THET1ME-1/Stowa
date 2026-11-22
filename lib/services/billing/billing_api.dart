import 'dart:convert';

import 'package:http/http.dart' as http;

import '../sync/sync_http.dart';
import 'subscription.dart';

/// Что сервер ответил на чек магазина.
sealed class StoreVerdict {
  const StoreVerdict();
}

/// Чек принят: подписка действует или нет, до какого числа.
class StoreOk extends StoreVerdict {
  const StoreOk({required this.active, this.until});

  final bool active;
  final DateTime? until;
}

/// Покупка принадлежит другому аккаунту.
class StoreOwned extends StoreVerdict {
  const StoreOwned();
}

/// Магазин такой покупки не знает.
class StoreInvalid extends StoreVerdict {
  const StoreInvalid();
}

/// Сервер или магазин не ответили: покупка цела, проверка повторится.
class StoreUnavailable extends StoreVerdict {
  const StoreUnavailable();
}

/// Касса на сервере синхронизации.
class BillingApi {
  BillingApi(this._client, {this.base = syncServer});

  final http.Client _client;
  final String base;

  static const _timeout = Duration(seconds: 30);

  Map<String, String> _headers(String? token) => {'content-type': 'application/json', if (token != null) 'authorization': 'Bearer $token'};

  static Map<String, Object?> _json(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      return json is Map<String, Object?> ? json : const {};
    } on FormatException {
      return const {};
    }
  }

  /// Цены внешней кассы: валюта → тариф → цена. null — касса выключена.
  Future<Map<String, Map<SubPlan, num>>?> lavaPrices() async {
    final response = await _client.get(Uri.parse('$base/v1/billing/plans')).timeout(_timeout);
    if (response.statusCode != 200) throw SyncHttpError(response.statusCode);
    final lava = _json(response)['lava'];
    if (lava is! Map) return null;
    return {
      for (final MapEntry(:key, :value) in lava.entries)
        '$key': {
          for (final plan in SubPlan.values)
            if ((value as Map)[plan.name] case final num price) plan: price,
        },
    };
  }

  /// Аккаунт и подписка. Токен не принят — [SyncHttpError] 401.
  Future<Subscription> account(String token) async {
    final response = await _client.get(Uri.parse('$base/v1/account'), headers: _headers(token)).timeout(_timeout);
    if (response.statusCode != 200) throw SyncHttpError(response.statusCode);
    return Subscription.fromAccount(_json(response));
  }

  /// Счёт внешней кассы: страница оплаты и номер счёта.
  Future<({String url, String invoice})> lavaCheckout(String token, SubPlan plan, String currency, String lang) async {
    final response = await _client
        .post(Uri.parse('$base/v1/billing/lava/checkout'), headers: _headers(token), body: jsonEncode({'plan': plan.name, 'currency': currency, 'lang': lang}))
        .timeout(_timeout);
    final json = _json(response);
    if (response.statusCode != 200 || json['url'] is! String) throw SyncHttpError(response.statusCode, response.body);
    return (url: json['url'] as String, invoice: json['invoice'] as String);
  }

  /// Отменить продление внешней кассы: до какого числа доступ остаётся; null — отменять нечего.
  Future<DateTime?> lavaCancel(String token) async {
    final response = await _client.post(Uri.parse('$base/v1/billing/lava/cancel'), headers: _headers(token)).timeout(_timeout);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) throw SyncHttpError(response.statusCode);
    return DateTime.tryParse(_json(response)['until'] as String? ?? '');
  }

  Future<StoreVerdict> verifyPlay(String token, String purchaseToken) => _verify('/v1/billing/play', token, {'token': purchaseToken});

  Future<StoreVerdict> verifyApple(String token, String transactionId) => _verify('/v1/billing/apple', token, {'transaction_id': transactionId});

  Future<StoreVerdict> _verify(String path, String token, Map<String, Object?> body) async {
    final http.Response response;
    try {
      response = await _client.post(Uri.parse('$base$path'), headers: _headers(token), body: jsonEncode(body)).timeout(_timeout);
    } on Object {
      return const StoreUnavailable();
    }
    final json = _json(response);
    return switch (response.statusCode) {
      200 => StoreOk(active: json['active'] == true, until: DateTime.tryParse(json['until'] as String? ?? '')),
      409 => const StoreOwned(),
      422 => const StoreInvalid(),
      _ => const StoreUnavailable(),
    };
  }

  /// Удалить аккаунт. false — сперва надо отменить подписку внешней кассы.
  Future<bool> deleteAccount(String token) async {
    final response = await _client.delete(Uri.parse('$base/v1/account'), headers: _headers(token)).timeout(_timeout);
    if (response.statusCode == 409) return false;
    if (response.statusCode != 204) throw SyncHttpError(response.statusCode);
    return true;
  }
}
