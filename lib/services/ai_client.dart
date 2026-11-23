import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/ai_providers.dart';

export '../domain/ai_providers.dart' show defaultAiBaseUrl, defaultSortModel;

enum AiFailureKind { auth, payment, rateLimit, network, timeout, server, badResponse }

/// Почему поставщик не ответил. auth и payment ставят очередь на паузу до
/// смены ключа, rateLimit — на [retryAfter]. timeout — сеть есть, но модель
/// думала дольше срока: виновата вещь, а не связь, очередь идёт дальше.
class AiFailure implements Exception {
  const AiFailure(this.kind, this.message, {this.retryAfter, this.status});

  final AiFailureKind kind;
  final String message;
  final Duration? retryAfter;

  /// Код ответа HTTP, если ответ был.
  final int? status;

  /// Поставщик не понял запрос (400, 422): без какой-то настройки он, может быть, ответит.
  bool get refused => kind == AiFailureKind.server && (status == 400 || status == 422);

  @override
  String toString() => 'AiFailure(${kind.name}): $message';
}

/// Модель в списке поставщика.
class AiModel {
  const AiModel({required this.id, required this.name, required this.free, required this.seesImages});

  final String id;
  final String name;
  final bool free;
  final bool seesImages;
}

/// Клиент поставщика по ключу человека: запросы идут с телефона прямо к нему.
/// Язык поставщика выбирается по адресу: Anthropic — свой, остальные — как OpenAI.
abstract interface class AiClient {
  factory AiClient({required http.Client http, required String baseUrl, required String apiKey}) {
    final provider = providerOfUrl(baseUrl);
    final wire = _Wire(http, baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''), apiKey.trim());
    return switch (provider?.protocol) {
      AiProtocol.anthropic => _AnthropicClient(wire),
      _ => _OpenAiClient(wire, provider),
    };
  }

  /// Ответ модели текстом.
  Future<String> chat({required String model, required List<Map<String, Object?>> messages, Map<String, Object?>? responseFormat});

  /// Ключ рабочий: поставщик ответил на запрос, закрытый ключом.
  Future<void> check();

  /// Расшифровка голосового моделью речи того же поставщика.
  Future<String> transcribe({required String model, required String audioPath});

  /// Модели поставщика: бесплатные с картинками первыми.
  Future<List<AiModel>> models();
}

/// Какой вариант запроса прошёл у модели: `адрес|модель|вид ответа` → номер варианта.
/// Помнится до перезапуска, чтобы не тратить отказ на каждую заметку.
final _passed = <String, int>{};

/// Тесты начинают с чистой памяти вариантов.
void forgetPassedVariants() => _passed.clear();

/// Запрос от полного к простому: поставщик или модель, не знающие настройку, отвечают 400,
/// и следующий вариант её снимает. Последний вариант — без картинок, он не запоминается:
/// отказ мог быть из-за одной картинки.
Future<http.Response> _relaxing(String memo, List<Map<String, Object?>> variants, Map<String, Object?>? textOnly, Future<http.Response> Function(Map<String, Object?> body) post) async {
  final distinct = <Map<String, Object?>>[];
  final seen = <String>{};
  for (final body in variants) {
    if (seen.add(jsonEncode(body))) distinct.add(body);
  }
  AiFailure? last;
  final start = _passed[memo] ?? 0;
  for (var index = start < distinct.length ? start : 0; index < distinct.length; index++) {
    try {
      final response = await post(distinct[index]);
      _passed[memo] = index;
      return response;
    } on AiFailure catch (failure) {
      if (!failure.refused) rethrow;
      last = failure;
    }
  }
  if (textOnly != null && !seen.contains(jsonEncode(textOnly))) return post(textOnly);
  throw last!;
}

/// Сообщения без картинок: модель без зрения отвечает на них отказом.
List<Map<String, Object?>> _withoutImages(List<Map<String, Object?>> messages) => [
  for (final message in messages)
    if (message['content'] case final List<Object?> parts)
      {...message, 'content': [for (final part in parts) if (part is Map && part['type'] == 'text') part]}
    else
      message,
];

bool _hasImages(List<Map<String, Object?>> messages) => messages.any((message) => message['content'] is List && (message['content'] as List).any((part) => part is Map && part['type'] != 'text'));

/// Общий транспорт: срок ответа, сеть и разбор кодов ошибок одинаковы у всех поставщиков.
class _Wire {
  _Wire(this.client, this.baseUrl, this.key);

  final http.Client client;
  final String baseUrl;
  final String key;

  Uri url(String path) => Uri.parse('$baseUrl$path');

  Future<http.Response> send(Future<http.Response> Function() request, {Duration wait = const Duration(seconds: 30)}) async {
    final http.Response response;
    try {
      response = await request().timeout(wait);
    } on TimeoutException {
      throw AiFailure(AiFailureKind.timeout, 'нет ответа за ${wait.inSeconds} секунд');
    } on SocketException catch (error) {
      throw AiFailure(AiFailureKind.network, error.message);
    } on http.ClientException catch (error) {
      throw AiFailure(AiFailureKind.network, error.message);
    }
    final code = response.statusCode;
    if (code >= 200 && code < 300) return response;
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final text = '$code $body';
    final lower = body.toLowerCase();
    // деньги кончились: OpenAI отвечает 429 insufficient_quota, Anthropic — 400 про баланс
    if (code == 402 || lower.contains('insufficient_quota') || lower.contains('credit balance') || lower.contains('insufficient balance')) {
      throw AiFailure(AiFailureKind.payment, text, status: code);
    }
    // Google и xAI отвечают на чужой ключ 400, а не 401
    if (code == 401 || code == 403 || (code == 400 && (lower.contains('api key') || lower.contains('api_key_invalid')))) {
      throw AiFailure(AiFailureKind.auth, text, status: code);
    }
    if (code == 429) {
      throw AiFailure(AiFailureKind.rateLimit, text, status: code, retryAfter: Duration(seconds: int.tryParse(response.headers['retry-after'] ?? '') ?? 60));
    }
    throw AiFailure(AiFailureKind.server, text, status: code);
  }
}

/// OpenRouter, OpenAI и все, кто говорит на языке OpenAI.
class _OpenAiClient implements AiClient {
  _OpenAiClient(this._wire, this._provider);

  final _Wire _wire;

  /// Знакомый поставщик или null для своего адреса.
  final AiProvider? _provider;

  Map<String, String> get _headers => {
    'authorization': 'Bearer ${_wire.key}',
    'content-type': 'application/json',
    // OpenRouter показывает в своей статистике, откуда запрос
    'x-title': 'Stowa',
    'http-referer': 'https://github.com/THET1ME-1/Stowa',
  };

  @override
  Future<String> chat({required String model, required List<Map<String, Object?>> messages, Map<String, Object?>? responseFormat}) async {
    Map<String, Object?> body(List<Map<String, Object?>> messages, {bool temperature = true, Map<String, Object?>? format}) => {
      'model': model,
      'messages': messages,
      'response_format': ?format,
      if (temperature) 'temperature': 0,
    };
    // строгая схема → просто JSON → без требований к виду; температуру 0 новые модели OpenAI не берут
    final plainJson = responseFormat == null ? null : const <String, Object?>{'type': 'json_object'};
    final variants = [
      body(messages, format: responseFormat),
      body(messages, temperature: false, format: responseFormat),
      body(messages, temperature: false, format: plainJson),
      body(messages, temperature: false),
    ];
    final response = await _relaxing(
      '${_wire.baseUrl}|$model|${responseFormat?['type']}',
      variants,
      _hasImages(messages) ? body(_withoutImages(messages), temperature: false) : null,
      (body) => _wire.send(
        () => _wire.client.post(_wire.url('/chat/completions'), headers: _headers, body: jsonEncode(body)),
        // бесплатные модели с размышлениями думают над картинкой минуту и дольше
        wait: const Duration(seconds: 90),
      ),
    );
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
      final choices = json['choices'] as List<Object?>;
      final content = ((choices.first as Map<String, Object?>)['message'] as Map<String, Object?>)['content'];
      if (content is! String) throw const FormatException('нет текста');
      return content;
    } catch (error) {
      throw AiFailure(AiFailureKind.badResponse, 'ответ без choices: $error');
    }
  }

  @override
  Future<String> transcribe({required String model, required String audioPath}) async {
    final request = http.MultipartRequest('POST', _wire.url('/audio/transcriptions'))
      ..headers.addAll({'authorization': 'Bearer ${_wire.key}', 'x-title': 'Stowa'})
      ..fields['model'] = model
      ..files.add(await http.MultipartFile.fromPath('file', audioPath));
    final response = await _wire.send(() async => http.Response.fromStream(await _wire.client.send(request)), wait: const Duration(seconds: 90));
    try {
      final text = (jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>)['text'];
      if (text is! String) throw const FormatException('нет текста');
      return text;
    } catch (error) {
      throw AiFailure(AiFailureKind.badResponse, 'расшифровка без текста: $error');
    }
  }

  /// У OpenRouter есть /key. Где список моделей открыт и без ключа (NVIDIA, Hugging Face),
  /// ключ проверяет запрос в одно слово. У остальных /models закрыт ключом: ответил — ключ принят.
  /// Свой адрес — сперва /key, его нет — /models.
  @override
  Future<void> check() async {
    final provider = _provider;
    if (provider != null && provider.openModels) {
      final body = jsonEncode({
        'model': provider.model,
        'messages': [
          {'role': 'user', 'content': 'ok'},
        ],
        'max_tokens': 1,
      });
      try {
        await _wire.send(() => _wire.client.post(_wire.url('/chat/completions'), headers: _headers, body: body), wait: const Duration(seconds: 60));
      } on AiFailure catch (failure) {
        // ключ принят, а модели нет или она занята — ключ всё равно рабочий
        if (failure.kind != AiFailureKind.server && failure.kind != AiFailureKind.rateLimit) rethrow;
      }
      return;
    }
    if (provider != null && provider != openRouter) {
      await _wire.send(() => _wire.client.get(_wire.url('/models'), headers: _headers));
      return;
    }
    try {
      await _wire.send(() => _wire.client.get(_wire.url('/key'), headers: _headers));
    } on AiFailure catch (failure) {
      if (failure.kind != AiFailureKind.server || failure.status != 404) rethrow;
      await _wire.send(() => _wire.client.get(_wire.url('/models'), headers: _headers));
    }
  }

  @override
  Future<List<AiModel>> models() async {
    final response = await _wire.send(() => _wire.client.get(_wire.url('/models'), headers: _headers));
    try {
      final data = (jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>)['data'] as List<Object?>;
      final models = [
        for (final raw in data.whereType<Map<String, Object?>>())
          if (raw['id'] case final String rawId)
            // Gemini отдаёт «models/gemini-2.5-flash», а в запросе ждёт имя без приставки
            AiModel(
              id: rawId.replaceFirst(RegExp(r'^models/'), ''),
              name: (raw['name'] as String?) ?? (raw['display_name'] as String?) ?? rawId.replaceFirst(RegExp(r'^models/'), ''),
              free: rawId.endsWith(':free'),
              seesImages: ((raw['architecture'] as Map<String, Object?>?)?['input_modalities'] as List<Object?>? ?? const []).contains('image'),
            ),
      ];
      int rank(AiModel model) => (model.free ? 0 : 2) + (model.seesImages ? 0 : 1);
      return models..sort((a, b) => rank(a).compareTo(rank(b)));
    } catch (error) {
      throw AiFailure(AiFailureKind.badResponse, 'список моделей не разобрался: $error');
    }
  }
}

/// Anthropic: Messages API. `system` — отдельным полем, картинки — блоками `image`,
/// схема ответа — `output_config.format`, температуры у новых моделей нет.
class _AnthropicClient implements AiClient {
  _AnthropicClient(this._wire);

  final _Wire _wire;

  Map<String, String> get _headers => {
    'x-api-key': _wire.key,
    'anthropic-version': '2023-06-01',
    'content-type': 'application/json',
    // сайт Stowa зовёт API прямо из браузера: без согласия Anthropic такой запрос не пускает
    'anthropic-dangerous-direct-browser-access': 'true',
  };

  @override
  Future<String> chat({required String model, required List<Map<String, Object?>> messages, Map<String, Object?>? responseFormat}) async {
    final (system, turns) = _anthropicMessages(messages);
    final wrapped = responseFormat == null ? null : responseFormat['json_schema'];
    final schema = responseFormat != null && responseFormat['type'] == 'json_schema' && wrapped is Map ? wrapped['schema'] : null;
    Map<String, Object?> body(List<Map<String, Object?>> turns, {bool effort = true, bool format = true}) => {
      'model': model,
      // размышления у новых моделей включены всегда и тратят тот же запас
      'max_tokens': 16000,
      'system': ?system,
      'messages': turns,
      if (effort || (format && schema != null))
        'output_config': {
          // разложить заметку — работа на минуту: долгие размышления тут только тратят деньги
          if (effort) 'effort': 'low',
          if (format && schema != null) 'format': {'type': 'json_schema', 'schema': _anyOfTypes(schema)},
        },
    };
    // старые модели не знают силы размышлений, совсем старые — схемы ответа
    final variants = [body(turns), body(turns, effort: false), body(turns, effort: false, format: false)];
    final response = await _relaxing(
      '${_wire.baseUrl}|$model|${responseFormat?['type']}',
      variants,
      _hasImages(turns) ? body(_withoutImages(turns), effort: false, format: false) : null,
      (body) => _wire.send(() => _wire.client.post(_wire.url('/messages'), headers: _headers, body: jsonEncode(body)), wait: const Duration(seconds: 90)),
    );
    final Map<String, Object?> json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
    } catch (error) {
      throw AiFailure(AiFailureKind.badResponse, 'ответ не JSON: $error');
    }
    final stop = json['stop_reason'];
    if (stop == 'refusal') throw const AiFailure(AiFailureKind.badResponse, 'модель отказалась отвечать');
    final text = [
      for (final block in (json['content'] as List<Object?>? ?? const []).whereType<Map<String, Object?>>())
        if (block['type'] == 'text' && block['text'] is String) block['text'] as String,
    ].join();
    if (text.trim().isEmpty) throw AiFailure(AiFailureKind.badResponse, 'ответ без текста ($stop)');
    return text;
  }

  @override
  Future<String> transcribe({required String model, required String audioPath}) async =>
      throw const AiFailure(AiFailureKind.badResponse, 'у Anthropic нет расшифровки голоса');

  @override
  Future<void> check() async {
    await _wire.send(() => _wire.client.get(_wire.url('/models?limit=1'), headers: _headers));
  }

  /// Все модели постранично: Anthropic отдаёт до 1000 за раз и говорит, есть ли ещё.
  @override
  Future<List<AiModel>> models() async {
    final models = <AiModel>[];
    String? after;
    for (var page = 0; page < 10; page++) {
      final path = after == null ? '/models?limit=1000' : '/models?limit=1000&after_id=$after';
      final response = await _wire.send(() => _wire.client.get(_wire.url(path), headers: _headers));
      try {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
        for (final raw in (json['data'] as List<Object?>).whereType<Map<String, Object?>>()) {
          final id = raw['id'] as String;
          // все модели Claude видят картинки
          models.add(AiModel(id: id, name: (raw['display_name'] as String?) ?? id, free: false, seesImages: true));
        }
        if (json['has_more'] != true || models.isEmpty) break;
        after = (json['last_id'] as String?) ?? models.last.id;
      } catch (error) {
        throw AiFailure(AiFailureKind.badResponse, 'список моделей не разобрался: $error');
      }
    }
    return models;
  }
}

/// Сообщения языка OpenAI → `system` и ходы Anthropic.
(String?, List<Map<String, Object?>>) _anthropicMessages(List<Map<String, Object?>> messages) {
  final system = <String>[];
  final turns = <Map<String, Object?>>[];
  for (final message in messages) {
    final content = message['content'];
    if (message['role'] == 'system') {
      system.add(content is String ? content : _textOf(content));
      continue;
    }
    turns.add({
      'role': message['role'],
      'content': content is List ? [for (final part in content.whereType<Map<String, Object?>>()) _anthropicPart(part)] : content,
    });
  }
  return (system.isEmpty ? null : system.join('\n\n'), turns);
}

String _textOf(Object? content) => content is List ? [for (final part in content) if (part is Map && part['text'] is String) part['text']].join('\n') : '$content';

/// Кусок сообщения: картинка из `data:`-адреса — блоком base64, по ссылке — блоком url.
Map<String, Object?> _anthropicPart(Map<String, Object?> part) {
  if (part['type'] != 'image_url') return part;
  final url = ((part['image_url'] as Map?)?['url'] as String?) ?? '';
  final data = RegExp(r'^data:([^;]+);base64,(.*)$', dotAll: true).firstMatch(url);
  if (data != null) {
    return {
      'type': 'image',
      'source': {'type': 'base64', 'media_type': data.group(1), 'data': data.group(2)},
    };
  }
  return {
    'type': 'image',
    'source': {'type': 'url', 'url': url},
  };
}

/// `"type": ["string", "null"]` → `anyOf`: так схему точно примет любой разборщик.
Object? _anyOfTypes(Object? schema) {
  if (schema is List) return [for (final item in schema) _anyOfTypes(item)];
  if (schema is! Map) return schema;
  final copy = <String, Object?>{for (final entry in schema.entries) entry.key as String: _anyOfTypes(entry.value)};
  if (copy['type'] case final List<Object?> types) {
    copy.remove('type');
    return {
      'anyOf': [for (final type in types) {...copy, 'type': type}],
    };
  }
  return copy;
}
