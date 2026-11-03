import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stowa/services/ai_client.dart';

void main() {
  AiClient client(Future<http.Response> Function(http.Request request) handler) =>
      AiClient(http: MockClient(handler), baseUrl: 'https://openrouter.ai/api/v1', apiKey: 'sk-test');

  Future<AiFailure> failureOf(Future<Object?> Function() call) async {
    try {
      await call();
    } on AiFailure catch (failure) {
      return failure;
    }
    fail('ошибки не было');
  }

  http.Response ok(String content) => http.Response(jsonEncode({'choices': [{'message': {'content': content}}]}), 200, headers: {'content-type': 'application/json; charset=utf-8'});

  test('401 и 403 дают auth, 402 — payment', () async {
    for (final (code, kind) in [(401, AiFailureKind.auth), (403, AiFailureKind.auth), (402, AiFailureKind.payment)]) {
      final failure = await failureOf(() => client((_) async => http.Response('{}', code)).chat(model: 'm', messages: const []));
      expect(failure.kind, kind);
    }
  });

  test('429 с retry-after: 30 даёт rateLimit и паузу 30 секунд', () async {
    final failure = await failureOf(() => client((_) async => http.Response('{}', 429, headers: {'retry-after': '30'})).chat(model: 'm', messages: const []));
    expect(failure.kind, AiFailureKind.rateLimit);
    expect(failure.retryAfter, const Duration(seconds: 30));
  });

  test('ответ без choices даёт badResponse', () async {
    final failure = await failureOf(() => client((_) async => http.Response('{"id":"x"}', 200)).chat(model: 'm', messages: const []));
    expect(failure.kind, AiFailureKind.badResponse);
  });

  test('заголовки: Bearer-ключ и X-Title: Stowa, тело с моделью и нулевой температурой', () async {
    late http.Request seen;
    final answer = await client((request) async {
      seen = request;
      return ok('привет');
    }).chat(model: 'nvidia/x:free', messages: const [{'role': 'user', 'content': 'hi'}], responseFormat: const {'type': 'json_object'});
    expect(answer, 'привет');
    expect(seen.url.toString(), 'https://openrouter.ai/api/v1/chat/completions');
    expect(seen.headers['authorization'], 'Bearer sk-test');
    expect(seen.headers['x-title'], 'Stowa');
    final body = jsonDecode(seen.body) as Map<String, Object?>;
    expect(body['model'], 'nvidia/x:free');
    expect(body['temperature'], 0);
    expect(body['response_format'], {'type': 'json_object'});
  });

  test('нет сети даёт network', () async {
    final failure = await failureOf(() => client((_) async => throw const SocketException('нет сети')).chat(model: 'm', messages: const []));
    expect(failure.kind, AiFailureKind.network);
  });

  test('500 — server, проверка ключа ходит в /models', () async {
    final failure = await failureOf(() => client((_) async => http.Response('oops', 503)).chat(model: 'm', messages: const []));
    expect(failure.kind, AiFailureKind.server);
    late Uri asked;
    await client((request) async {
      asked = request.url;
      return http.Response('{"data":[]}', 200);
    }).check();
    expect(asked.path, '/api/v1/key');
  });
}
