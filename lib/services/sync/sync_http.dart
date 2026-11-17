import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sync_ports.dart';

const syncServer = 'https://sync.stowa.work';

/// Сервер ответил не тем, чего ждали: код ответа и тело.
class SyncHttpError implements Exception {
  const SyncHttpError(this.status, [this.body = '']);

  final int status;
  final String body;

  @override
  String toString() => 'SyncHttpError($status)';
}

/// Чем кончилась просьба прислать код.
sealed class CodeRequest {
  const CodeRequest();
}

class CodeSent extends CodeRequest {
  const CodeSent();
}

/// Рано просить снова: подождать [seconds].
class CodeWait extends CodeRequest {
  const CodeWait(this.seconds);

  final int seconds;
}

/// Письмо не ушло или сети нет.
class CodeFailed extends CodeRequest {
  const CodeFailed();
}

class SignedIn {
  const SignedIn({required this.token, required this.email, required this.active});

  final String token;
  final String email;

  /// Подписка действует.
  final bool active;
}

/// Вход и ключ хранилища.
class SyncAccountApi {
  SyncAccountApi(this._client, {this.base = syncServer});

  final http.Client _client;
  final String base;

  static const _timeout = Duration(seconds: 30);

  Map<String, String> _headers([String? token]) => {'content-type': 'application/json', if (token != null) 'authorization': 'Bearer $token'};

  Future<CodeRequest> requestCode(String email, {required String lang, required String device, required int tzOffset}) async {
    try {
      final response = await _client
          .post(Uri.parse('$base/v1/auth/start'), headers: _headers(), body: jsonEncode({'email': email, 'lang': lang, 'device': device, 'tz_offset': tzOffset}))
          .timeout(_timeout);
      if (response.statusCode == 204) return const CodeSent();
      if (response.statusCode == 429) return CodeWait((jsonDecode(response.body) as Map)['retry_after'] as int? ?? 60);
      return const CodeFailed();
    } on Object {
      return const CodeFailed();
    }
  }

  /// Код верный — вход; неверный или устарел — null. Сеть упала — бросает.
  Future<SignedIn?> verify(String email, String code, {required String device}) async {
    final response = await _client.post(Uri.parse('$base/v1/auth/verify'), headers: _headers(), body: jsonEncode({'email': email, 'code': code, 'device': device})).timeout(_timeout);
    if (response.statusCode == 401) return null;
    if (response.statusCode != 200) throw SyncHttpError(response.statusCode, response.body);
    final json = jsonDecode(response.body) as Map<String, Object?>;
    return SignedIn(token: json['token'] as String, email: json['email'] as String, active: json['active'] as bool);
  }

  /// Подписка действует; токен не принят — [SyncHttpError] 401.
  Future<bool> active(String token) async {
    final response = await _client.get(Uri.parse('$base/v1/account'), headers: _headers(token)).timeout(_timeout);
    if (response.statusCode != 200) throw SyncHttpError(response.statusCode);
    return (jsonDecode(response.body) as Map)['active'] as bool;
  }

  Future<List<int>?> key(String token) async {
    final response = await _client.get(Uri.parse('$base/v1/key'), headers: _headers(token)).timeout(_timeout);
    if (response.statusCode != 200) throw SyncHttpError(response.statusCode);
    final key = (jsonDecode(response.body) as Map)['key'] as String?;
    return key == null ? null : base64.decode(key);
  }

  /// Положить ключ. false — ключ уже есть (положил другой телефон), его надо забрать.
  Future<bool> putKey(String token, List<int> key) async {
    final response = await _client.put(Uri.parse('$base/v1/key'), headers: _headers(token), body: jsonEncode({'key': base64.encode(key)})).timeout(_timeout);
    if (response.statusCode == 409) return false;
    if (response.statusCode != 204) throw SyncHttpError(response.statusCode);
    return true;
  }

  Future<void> signOut(String token) async {
    await _client.delete(Uri.parse('$base/v1/session'), headers: _headers(token)).timeout(_timeout);
  }
}

/// Порт движка поверх HTTP.
class HttpSyncRemote implements SyncRemote {
  HttpSyncRemote(this._client, this._token, {this.base = syncServer});

  final http.Client _client;
  final String _token;
  final String base;

  Map<String, String> get _auth => {'authorization': 'Bearer $_token'};

  static RemoteChange _change(Map<String, Object?> json) => RemoteChange(
    file: json['file'] as String,
    rev: json['rev'] as int,
    deleted: json['deleted'] as bool,
    meta: json['meta'] as String,
    blobs: [for (final b in json['blobs'] as List) b as String],
    size: json['size'] as int,
  );

  void _check(http.Response response, [List<int> ok = const [200]]) {
    if (!ok.contains(response.statusCode)) throw SyncHttpError(response.statusCode);
  }

  /// Запрос с повтором: обрыв, таймаут и 5xx — ещё две попытки с паузой. Повтор правки
  /// безопасен: если первая дошла, сервер ответит отказом по ревизии, и движок дочитает файл.
  Future<http.Response> _send(Future<http.Response> Function() request, Duration timeout) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await request().timeout(timeout);
        if (response.statusCode < 500 || attempt >= 2) return response;
      } on Object {
        if (attempt >= 2) rethrow;
      }
      await Future<void>.delayed(Duration(seconds: 1 + attempt * 2));
    }
  }

  @override
  Future<ChangePage> changes(int since, {int wait = 0}) async {
    final response = await _send(() => _client.get(Uri.parse('$base/v1/changes?since=$since&wait=$wait'), headers: _auth), Duration(seconds: 30 + wait));
    _check(response);
    final json = jsonDecode(response.body) as Map<String, Object?>;
    return ChangePage(cursor: json['cursor'] as int, more: json['more'] as bool, changes: [for (final c in json['changes'] as List) _change(c as Map<String, Object?>)]);
  }

  @override
  Future<bool> hasBlob(String hash) async {
    final response = await _send(() => _client.head(Uri.parse('$base/v1/blobs/$hash'), headers: _auth), const Duration(seconds: 30));
    _check(response, [200, 404]);
    return response.statusCode == 200;
  }

  @override
  Future<void> putBlob(String hash, List<int> data) async {
    final response = await _send(() => _client.put(Uri.parse('$base/v1/blobs/$hash'), headers: {..._auth, 'content-type': 'application/octet-stream'}, body: data), const Duration(minutes: 3));
    _check(response, [204]);
  }

  @override
  Future<List<int>> getBlob(String hash) async {
    final response = await _send(() => _client.get(Uri.parse('$base/v1/blobs/$hash'), headers: _auth), const Duration(minutes: 3));
    _check(response);
    return response.bodyBytes;
  }

  @override
  Future<CommitResult> commit(String file, {required int baseRev, required String meta, required List<String> blobs, required int size, bool deleted = false}) async {
    final response = await _send(
      () => _client.post(
        Uri.parse('$base/v1/files/$file'),
        headers: {..._auth, 'content-type': 'application/json'},
        body: jsonEncode({'base_rev': baseRev, 'deleted': deleted, 'meta': meta, 'blobs': blobs, 'size': size}),
      ),
      const Duration(seconds: 30),
    );
    if (response.statusCode == 409) return Conflict((jsonDecode(response.body) as Map)['rev'] as int);
    _check(response);
    return Committed((jsonDecode(response.body) as Map)['rev'] as int);
  }

  @override
  Future<RemoteChange?> file(String file) async {
    final response = await _send(() => _client.get(Uri.parse('$base/v1/files/$file'), headers: _auth), const Duration(seconds: 30));
    if (response.statusCode == 404) return null;
    _check(response);
    return _change(jsonDecode(response.body) as Map<String, Object?>);
  }
}
