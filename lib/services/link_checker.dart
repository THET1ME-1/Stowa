import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';

import '../data/db/database.dart';
import '../domain/models.dart';

/// Что ответил адрес. [missing] — 404 или 410: страницы больше нет.
/// [noHost] — адреса нет (DNS): сайт закрылся или нет сети. [unsure] — 403, 5xx, срок.
enum LinkReply { alive, missing, noHost, unsure }

typedef LinkCheck = Future<LinkReply> Function(Uri uri);

/// Ссылку проверяют не чаще раза в неделю: сайты не любят частых гостей, батарея тоже.
const linkCheckInterval = Duration(days: 7);

/// За проход — не больше: остальное в следующий.
const _batch = 200;

/// Сколько адресов спрашивать разом.
const _parallel = 4;

/// Битые ссылки: коротким запросом раз в неделю. Мёртвая ссылка помечается
/// `gone_at` и попадает в «Битые ссылки»; ожившая снимает пометку сама.
class LinkChecker {
  LinkChecker(this._db, {required DateTime Function() clock, LinkCheck check = httpLinkReply})
    : _clock = clock, // ignore: prefer_initializing_formals
      _check = check; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final DateTime Function() _clock;
  final LinkCheck _check;

  /// Проверить ссылки, которые давно не проверяли; [force] — все сразу («Проверить сейчас»).
  Future<void> run({bool force = false}) async {
    final now = _clock();
    final query = _db.select(_db.items)
      ..where((t) => t.url.isNotNull() & t.deletedAt.isNull() & t.kind.isIn([ItemKind.link.name, ItemKind.video.name]))
      ..orderBy([(t) => OrderingTerm(expression: t.linkCheckedAt, nulls: NullsOrder.first)])
      ..limit(_batch);
    if (!force) query.where((t) => t.linkCheckedAt.isNull() | t.linkCheckedAt.isSmallerThanValue(now.subtract(linkCheckInterval)));
    final items = await query.get();
    if (items.isEmpty) return;

    final replies = <String, LinkReply>{};
    var next = 0;
    Future<void> worker() async {
      while (next < items.length) {
        final item = items[next++];
        final uri = Uri.tryParse(item.url!);
        replies[item.id] = uri == null || !uri.hasScheme ? LinkReply.unsure : await _check(uri).catchError((_) => LinkReply.unsure);
      }
    }

    await Future.wait([for (var index = 0; index < _parallel; index++) worker()]);
    // «адреса нет» у всех сразу — это нет сети, а не закрытые сайты
    final online = replies.values.any((reply) => reply == LinkReply.alive || reply == LinkReply.missing);
    await _db.transaction(() async {
      for (final item in items) {
        final reply = replies[item.id]!;
        if (reply == LinkReply.noHost && !online) continue;
        final dead = reply == LinkReply.missing || reply == LinkReply.noHost;
        await (_db.update(_db.items)..where((t) => t.id.equals(item.id))).write(
          ItemsCompanion(
            linkCheckedAt: Value(now),
            // умершая раньше помнит, когда умерла
            goneAt: dead ? Value(item.goneAt ?? now) : (reply == LinkReply.alive ? const Value(null) : const Value.absent()),
            goneKept: reply == LinkReply.alive ? const Value(false) : const Value.absent(),
          ),
        );
      }
    });
  }
}

/// Спросить адрес по-настоящему: только код ответа, тело не качается.
Future<LinkReply> httpLinkReply(Uri uri) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..userAgent = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36';
  try {
    final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
    final response = await request.close().timeout(const Duration(seconds: 12));
    unawaited(response.listen(null).cancel());
    final status = response.statusCode;
    if (status == 404 || status == 410) return LinkReply.missing;
    if (status >= 200 && status < 400) return LinkReply.alive;
    return LinkReply.unsure;
  } on SocketException catch (error) {
    // «Failed host lookup»: такого адреса больше нет — или нет сети, это решит проход целиком
    return error.message.contains('host lookup') || (error.osError?.message.contains('host') ?? false) ? LinkReply.noHost : LinkReply.unsure;
  } catch (_) {
    return LinkReply.unsure;
  } finally {
    client.close(force: true);
  }
}
