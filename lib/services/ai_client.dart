import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Адрес поставщика по умолчанию: OpenRouter, протокол OpenAI chat completions.
const defaultAiBaseUrl = 'https://openrouter.ai/api/v1';

/// Модель разбора по умолчанию: бесплатная, видит картинки, держит строгий JSON.
const defaultSortModel = 'nvidia/nemotron-3.5-super-vl:free';

enum AiFailureKind { auth, payment, rateLimit, network, server, badResponse }

/// Почему поставщик не ответил. auth и payment ставят очередь на паузу до
/// смены ключа, rateLimit — на [retryAfter].
class AiFailure implements Exception {
  const AiFailure(this.kind, this.message, {this.retryAfter});

  final AiFailureKind kind;
  final String message;
  final Duration? retryAfter;

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
class AiClient {
  AiClient({required http.Client http, required String baseUrl, required String apiKey})
    : _http = http, // ignore: prefer_initializing_formals
      _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
      _apiKey = apiKey; // ignore: prefer_initializing_formals

  final http.Client _http;
  final String _baseUrl;
  final String _apiKey;

  Map<String, String> get _headers => {
    'authorization': 'Bearer $_apiKey',
    'content-type': 'application/json',
    // OpenRouter показывает в своей статистике, откуда запрос
    'x-title': 'Stowa',
    'http-referer': 'https://github.com/THET1ME-1/Stowa',
  };

  /// Ответ модели текстом.
  Future<String> chat({required String model, required List<Map<String, Object?>> messages, Map<String, Object?>? responseFormat}) async {
    final response = await _send(
      () => _http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: _headers,
        body: jsonEncode({'model': model, 'messages': messages, 'response_format': ?responseFormat, 'temperature': 0}),
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

  /// Расшифровка голосового моделью речи того же поставщика.
  Future<String> transcribe({required String model, required String audioPath}) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/audio/transcriptions'))
      ..headers.addAll({'authorization': 'Bearer $_apiKey', 'x-title': 'Stowa'})
      ..fields['model'] = model
      ..files.add(await http.MultipartFile.fromPath('file', audioPath));
    final response = await _send(() async => http.Response.fromStream(await _http.send(request)));
    try {
      final text = (jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>)['text'];
      if (text is! String) throw const FormatException('нет текста');
      return text;
    } catch (error) {
      throw AiFailure(AiFailureKind.badResponse, 'расшифровка без текста: $error');
    }
  }

  /// Ключ рабочий. У OpenRouter есть /key, у остальных поставщиков /models
  /// закрыт ключом: ответил — ключ принят.
  Future<void> check() async {
    try {
      await _send(() => _http.get(Uri.parse('$_baseUrl/key'), headers: _headers));
    } on AiFailure catch (failure) {
      if (failure.kind != AiFailureKind.server || !failure.message.startsWith('404')) rethrow;
      await _send(() => _http.get(Uri.parse('$_baseUrl/models'), headers: _headers));
    }
  }

  /// Модели поставщика: бесплатные с картинками первыми.
  Future<List<AiModel>> models() async {
    final response = await _send(() => _http.get(Uri.parse('$_baseUrl/models'), headers: _headers));
    try {
      final data = (jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>)['data'] as List<Object?>;
      final models = [
        for (final raw in data.whereType<Map<String, Object?>>())
          AiModel(
            id: raw['id'] as String,
            name: (raw['name'] as String?) ?? raw['id'] as String,
            free: (raw['id'] as String).endsWith(':free'),
            seesImages: ((raw['architecture'] as Map<String, Object?>?)?['input_modalities'] as List<Object?>? ?? const []).contains('image'),
          ),
      ];
      int rank(AiModel model) => (model.free ? 0 : 2) + (model.seesImages ? 0 : 1);
      return models..sort((a, b) => rank(a).compareTo(rank(b)));
    } catch (error) {
      throw AiFailure(AiFailureKind.badResponse, 'список моделей не разобрался: $error');
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const AiFailure(AiFailureKind.network, 'нет ответа за 30 секунд');
    } on SocketException catch (error) {
      throw AiFailure(AiFailureKind.network, error.message);
    } on http.ClientException catch (error) {
      throw AiFailure(AiFailureKind.network, error.message);
    }
    final code = response.statusCode;
    if (code >= 200 && code < 300) return response;
    final text = '$code ${utf8.decode(response.bodyBytes, allowMalformed: true)}';
    throw switch (code) {
      401 || 403 => AiFailure(AiFailureKind.auth, text),
      402 => AiFailure(AiFailureKind.payment, text),
      429 => AiFailure(AiFailureKind.rateLimit, text, retryAfter: Duration(seconds: int.tryParse(response.headers['retry-after'] ?? '') ?? 60)),
      _ => AiFailure(AiFailureKind.server, text),
    };
  }
}
