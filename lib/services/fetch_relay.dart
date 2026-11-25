import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'link_checker.dart' show LinkReply;
import 'link_preview_service.dart' show FetchReply;
import 'sync/sync_http.dart' show syncServer;

/// Чужие сайты для сайта stowa.work — через сервер Stowa (`POST /v1/fetch`). Браузер не
/// пускает страницу к чужим адресам (CORS), поэтому превью, статьи, субтитры и проверку
/// мёртвых ссылок сайт делает так, а телефон — сам. Ответы те же, что у телефонных
/// `httpFetch`, `httpFetchWith`, `httpPost` и `httpLinkReply`: правила разбора общие.
class FetchRelay {
  FetchRelay({http.Client? client, this.server = syncServer}) : _client = client ?? http.Client();

  final http.Client _client;
  final String server;

  Future<Map<String, Object?>> _ask(Uri uri, {Map<String, String> headers = const {}, String? post, int? max}) async {
    final response = await _client
        .post(
          Uri.parse('$server/v1/fetch'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'url': uri.toString(), if (headers.isNotEmpty) 'headers': headers, 'post': ?post, 'max': ?max}),
        )
        // сервер пробует сайт напрямую и, если Москва не пускает, ещё раз через выход: до 45 с
        .timeout(const Duration(seconds: 60));
    // сервер занят или с адреса слишком много — для ссылки это то же, что нет сети: попробуем позже
    if (response.statusCode != 200) throw HttpException('посредник ответил ${response.statusCode}', uri: uri);
    return (jsonDecode(response.body) as Map).cast<String, Object?>();
  }

  Future<FetchReply> fetch(Uri uri, {Map<String, String> headers = const {}, String? post}) async {
    final reply = await _ask(uri, headers: headers, post: post);
    final status = reply['status'] as int? ?? 0;
    // сайт не открылся (нет имени, оборвал, закрыт для посредника): как обрыв сети у телефона
    if (status == 0) throw HttpException('страница не открылась: ${reply['reason']}', uri: uri);
    return FetchReply(status, base64.decode(reply['body'] as String? ?? ''), reply['type'] as String?);
  }

  /// Только код ответа: проверка мёртвых ссылок.
  Future<LinkReply> linkReply(Uri uri) async {
    try {
      final reply = await _ask(uri, max: 0);
      final status = reply['status'] as int? ?? 0;
      if (status == 0) return reply['reason'] == 'no_host' ? LinkReply.noHost : LinkReply.unsure;
      if (status == 404 || status == 410) return LinkReply.missing;
      if (status >= 200 && status < 400) return LinkReply.alive;
      return LinkReply.unsure;
    } on Object {
      return LinkReply.unsure;
    }
  }
}

final _relay = FetchRelay();

/// То же, что `httpFetch` телефона, через сервер.
Future<FetchReply> relayFetch(Uri uri) => _relay.fetch(uri);

/// То же, что `httpFetchWith`: свои заголовки (номер сайта Lib, Referer обложки).
Future<FetchReply> relayFetchWith(Uri uri, Map<String, String> headers) => _relay.fetch(uri, headers: headers);

/// То же, что `httpPost`: плеер YouTube за дорожками субтитров.
Future<FetchReply> relayPost(Uri uri, String json) => _relay.fetch(uri, post: json);

/// То же, что `httpLinkReply`: жива ли ссылка.
Future<LinkReply> relayLinkReply(Uri uri) => _relay.linkReply(uri);
