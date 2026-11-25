import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stowa/services/fetch_relay.dart';
import 'package:stowa/services/link_checker.dart';

void main() {
  late List<Map<String, Object?>> asked;
  FetchRelay relay(Map<String, Object?> Function(Map<String, Object?> body) answer, {int status = 200}) {
    asked = [];
    return FetchRelay(
      server: 'https://sync.test',
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://sync.test/v1/fetch');
        final body = (jsonDecode(request.body) as Map).cast<String, Object?>();
        asked.add(body);
        return http.Response(jsonEncode(answer(body)), status);
      }),
    );
  }

  test('страница через сервер: тот же ответ, что у телефона, заголовки и тело плеера уходят с адресом', () async {
    final page = relay((_) => {'status': 200, 'type': 'text/html', 'body': base64.encode(utf8.encode('<title>Борщ</title>'))});
    final reply = await page.fetch(Uri.parse('https://api.lib.social/api/manga/x'), headers: {'Site-Id': '1'});
    expect(reply.ok, isTrue);
    expect(utf8.decode(reply.bytes), '<title>Борщ</title>');
    expect(reply.contentType, 'text/html');
    expect(asked.single, {'url': 'https://api.lib.social/api/manga/x', 'headers': {'Site-Id': '1'}});
    await page.fetch(Uri.parse('https://www.youtube.com/youtubei/v1/player'), post: '{"videoId":"x"}');
    expect(asked.last['post'], '{"videoId":"x"}');
  });

  test('сайт не открылся или сервер занят — ошибка, как обрыв сети: ссылка подождёт', () async {
    expect(() => relay((_) => {'status': 0, 'reason': 'failed'}).fetch(Uri.parse('https://a.test')), throwsA(isA<HttpException>()));
    expect(() => relay((_) => {'error': 'too_many'}, status: 429).fetch(Uri.parse('https://a.test')), throwsA(isA<HttpException>()));
  });

  test('проверка ссылки — только код ответа; пропавшее имя отличается от обрыва', () async {
    expect(await relay((_) => {'status': 410, 'body': ''}).linkReply(Uri.parse('https://a.test')), LinkReply.missing);
    expect(asked.single['max'], 0);
    expect(await relay((_) => {'status': 0, 'reason': 'no_host'}).linkReply(Uri.parse('https://a.test')), LinkReply.noHost);
    expect(await relay((_) => {'status': 0, 'reason': 'failed'}).linkReply(Uri.parse('https://a.test')), LinkReply.unsure);
    expect(await relay((_) => {'status': 200, 'body': ''}).linkReply(Uri.parse('https://a.test')), LinkReply.alive);
  });
}
