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

  setUp(forgetPassedVariants);

  AiClient at(String baseUrl, Future<http.Response> Function(http.Request request) handler, {String key = 'k'}) =>
      AiClient(http: MockClient(handler), baseUrl: baseUrl, apiKey: key);

  http.Response json(Object body, [int code = 200]) => http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json; charset=utf-8'});

  group('Anthropic', () {
    const base = 'https://api.anthropic.com/v1';
    const schema = {
      'type': 'object',
      'properties': {
        'title': {'type': ['string', 'null']},
      },
      'required': ['title'],
      'additionalProperties': false,
    };

    test('свой язык: x-api-key, system отдельно, картинка блоком, схема в output_config, без температуры', () async {
      late http.Request seen;
      final answer = await at(base, (request) async {
        seen = request;
        return json({
          'content': [
            {'type': 'thinking', 'thinking': ''},
            {'type': 'text', 'text': '{"title":'},
            {'type': 'text', 'text': '"Чек"}'},
          ],
          'stop_reason': 'end_turn',
        });
      }, key: 'sk-ant-1').chat(
        model: 'claude-opus-5-5',
        messages: const [
          {'role': 'system', 'content': 'Раскладывай'},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Вещь'},
              {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,QUJD'}},
            ],
          },
        ],
        responseFormat: const {'type': 'json_schema', 'json_schema': {'name': 's', 'strict': true, 'schema': schema}},
      );
      expect(answer, '{"title":"Чек"}');
      expect(seen.url.toString(), '$base/messages');
      expect(seen.headers['x-api-key'], 'sk-ant-1');
      expect(seen.headers['anthropic-version'], '2023-06-01');
      expect(seen.headers['authorization'], isNull);
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body['system'], 'Раскладывай');
      expect(body.containsKey('temperature'), isFalse);
      expect(body['max_tokens'], greaterThanOrEqualTo(4096));
      final messages = body['messages'] as List<Object?>;
      expect(messages, hasLength(1));
      expect((messages.single as Map)['content'], [
        {'type': 'text', 'text': 'Вещь'},
        {'type': 'image', 'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': 'QUJD'}},
      ]);
      final config = body['output_config'] as Map<String, Object?>;
      expect(config['effort'], 'low');
      expect(config['format'], {
        'type': 'json_schema',
        'schema': {
          'type': 'object',
          'properties': {
            'title': {
              'anyOf': [
                {'type': 'string'},
                {'type': 'null'},
              ],
            },
          },
          'required': ['title'],
          'additionalProperties': false,
        },
      });
    });

    test('модель не знает силы размышлений — повтор без неё, дальше сразу без неё', () async {
      final bodies = <Map<String, Object?>>[];
      final client = at(base, (request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        bodies.add(body);
        if ((body['output_config'] as Map?)?['effort'] != null) return json({'type': 'error', 'error': {'type': 'invalid_request_error', 'message': 'effort: not supported'}}, 400);
        return json({'content': [{'type': 'text', 'text': 'ok'}], 'stop_reason': 'end_turn'});
      });
      const messages = [{'role': 'user', 'content': 'hi'}];
      expect(await client.chat(model: 'claude-haiku-4-5', messages: messages), 'ok');
      expect(await client.chat(model: 'claude-haiku-4-5', messages: messages), 'ok');
      expect(bodies, hasLength(3));
    });

    test('кончились кредиты — payment, отказ модели — badResponse', () async {
      final money = await failureOf(() => at(base, (_) async => json({'type': 'error', 'error': {'type': 'invalid_request_error', 'message': 'Your credit balance is too low to access the Anthropic API.'}}, 400)).chat(model: 'm', messages: const []));
      expect(money.kind, AiFailureKind.payment);
      final refusal = await failureOf(() => at(base, (_) async => json({'content': [], 'stop_reason': 'refusal'})).chat(model: 'm', messages: const []));
      expect(refusal.kind, AiFailureKind.badResponse);
    });

    test('ключ проверяется списком моделей, список — постранично, все видят картинки', () async {
      final asked = <String>[];
      final client = at(base, (request) async {
        asked.add(request.url.query);
        if (request.url.queryParameters['after_id'] == null && request.url.queryParameters['limit'] == '1000') {
          return json({'data': [{'id': 'claude-opus-5-5', 'display_name': 'Claude Opus 5.5'}], 'has_more': true, 'last_id': 'claude-opus-5-5'});
        }
        return json({'data': [{'id': 'claude-fable-5-2', 'display_name': 'Claude Fable 5.2'}], 'has_more': false});
      });
      await client.check();
      expect(asked.single, 'limit=1');
      final models = await client.models();
      expect([for (final model in models) model.id], ['claude-opus-5-5', 'claude-fable-5-2']);
      expect(models.every((model) => model.seesImages), isTrue);
    });
  });

  group('языком OpenAI', () {
    test('Google и xAI отвечают на чужой ключ 400 — это auth', () async {
      for (final (base, body) in [
        ('https://generativelanguage.googleapis.com/v1beta/openai', {'error': {'code': 400, 'message': 'Please pass a valid API key', 'status': 'INVALID_ARGUMENT'}}),
        ('https://api.x.ai/v1', {'code': 'invalid-argument', 'error': 'Incorrect API key provided.'}),
      ]) {
        final failure = await failureOf(() => at(base, (_) async => json(body, 400)).check());
        expect(failure.kind, AiFailureKind.auth, reason: base);
      }
    });

    test('429 insufficient_quota — деньги, а не «подождать»', () async {
      final failure = await failureOf(() => at('https://api.openai.com/v1', (_) async => json({'error': {'code': 'insufficient_quota'}}, 429)).chat(model: 'm', messages: const []));
      expect(failure.kind, AiFailureKind.payment);
    });

    test('модель не берёт температуру 0 и строгую схему — упрощается, пока не ответит', () async {
      final bodies = <Map<String, Object?>>[];
      final answer = await at('https://api.openai.com/v1', (request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        bodies.add(body);
        if (body.containsKey('temperature')) return json({'error': {'message': "Unsupported value: 'temperature'"}}, 400);
        if ((body['response_format'] as Map?)?['type'] == 'json_schema') return json({'error': {'message': 'response_format json_schema unsupported'}}, 400);
        return ok('{}');
      }).chat(model: 'gpt-x', messages: const [{'role': 'user', 'content': 'hi'}], responseFormat: const {'type': 'json_schema', 'json_schema': {'name': 's', 'schema': {}}});
      expect(answer, '{}');
      expect(bodies, hasLength(3));
      expect(bodies.last['response_format'], {'type': 'json_object'});
    });

    test('знакомый поставщик проверяет ключ сразу списком моделей, Gemini отдаёт имена без models/', () async {
      final asked = <String>[];
      final client = at('https://generativelanguage.googleapis.com/v1beta/openai', (request) async {
        asked.add(request.url.path);
        return json({'data': [{'id': 'models/gemini-2.5-flash', 'object': 'model'}]});
      });
      await client.check();
      expect(asked.single, '/v1beta/openai/models');
      expect((await client.models()).single.id, 'gemini-2.5-flash');
    });

    test('где список моделей открыт, ключ проверяет запрос в одно слово', () async {
      late http.Request seen;
      await at('https://integrate.api.nvidia.com/v1', (request) async {
        seen = request;
        return ok('o');
      }).check();
      expect(seen.url.path, '/v1/chat/completions');
      expect((jsonDecode(seen.body) as Map)['max_tokens'], 1);
      final failure = await failureOf(() => at('https://integrate.api.nvidia.com/v1', (_) async => json({}, 401)).check());
      expect(failure.kind, AiFailureKind.auth);
    });
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
