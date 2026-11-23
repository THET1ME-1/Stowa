/// История заметки для экрана: сеансы правки из облака и снимки этого устройства одним
/// списком. Облако — когда вошли в Stowa Sync этого хранилища и подписка действует.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/vault_note.dart';
import '../../services/sync/cloud_history.dart';
import '../../services/sync/sync_http.dart';

/// Что с облачной историей у этой заметки.
enum CloudAccess {
  /// Версии с сервера в списке.
  on,

  /// Сервер не ответил: в списке только снимки устройства.
  offline,

  /// Вошли, но подписки нет.
  noSubscription,

  /// Не вошли в Stowa Sync (или вошли в другом хранилище).
  signedOut,
}

/// Строка истории: сеанс правки в облаке или снимок этого устройства.
class HistoryEntry {
  const HistoryEntry({required this.title, required this.body, required this.at, this.from, this.device, this.local, this.cloud, this.session, this.path});

  final String title;
  final String body;

  /// Каким текст был к этому времени: конец сеанса или время снимка.
  final DateTime at;

  /// Начало сеанса, если в нём больше одной правки.
  final DateTime? from;

  /// С какого устройства; у снимка — этого.
  final String? device;
  final NoteVersion? local;
  final CloudVersion? cloud;
  final VersionSession? session;

  /// Путь файла у облачной версии: другой, чем сейчас, — заметка тогда лежала иначе.
  final String? path;

  /// Снимок этого устройства, которого нет на сервере.
  bool get localOnly => local != null;

  /// Сколько правок в сеансе.
  int get edits => session?.versions.length ?? 1;

  bool sameText(String otherTitle, String otherBody) => title == otherTitle && body == otherBody;
}

/// Облачная часть истории заметки.
class CloudNoteHistory {
  const CloudNoteHistory(this.access, {this.entries = const [], this.more = false});

  final CloudAccess access;

  /// Сеансы из облака, новые первыми.
  final List<HistoryEntry> entries;

  /// Есть версии старше: загрузились не все, бюджет кончился.
  final bool more;
}

/// Облако и снимки одним списком, новые первыми. Снимок, чей текст уже есть в облаке, не
/// повторяется. Подряд одинаковый текст (переезд, возврат той же версии) — одна строка, самая
/// ранняя: тогда текст и появился. Верх, совпавший с нынешним текстом, — это «Сейчас».
List<HistoryEntry> mergeHistory({required String title, required String body, required List<NoteVersion> local, required List<HistoryEntry> cloud}) {
  final inCloud = {for (final entry in cloud) (entry.title, entry.body)};
  final all = [
    ...cloud,
    for (final version in local)
      if (!inCloud.contains((version.title, version.body))) HistoryEntry(title: version.title, body: version.body, at: version.savedAt, local: version),
  ]..sort((a, b) => b.at.compareTo(a.at));
  final out = <HistoryEntry>[];
  for (final entry in all) {
    if (out.isNotEmpty && out.last.sameText(entry.title, entry.body)) {
      out[out.length - 1] = entry;
    } else {
      out.add(entry);
    }
  }
  while (out.isNotEmpty && out.first.sameText(title, body)) {
    out.removeAt(0);
  }
  return out;
}

/// Заголовок и текст заметки из файла версии — тем же разбором, что у сверки хранилища.
/// У холста, базы и рисунка [document]: текст — то, что в нём ищется (карточки, подписи, виды).
({String title, String body}) noteTextOf(String fileText, CloudVersion version, {bool document = false}) {
  final name = p.posix.basename(version.path);
  final note = document ? readVaultDocument(fileText, fileName: name, fileModified: version.at) : readVaultNote(fileText, fileName: name, fileModified: version.at);
  return (title: note.title, body: note.body);
}

/// Сколько байт текстов версий грузить за раз: заметка на мегабайты не тянет сотни версий.
const historyBudget = 24 * 1024 * 1024;

/// Сеансы из облака: тексты концов сеансов, пока не кончится [budget] байт.
Future<CloudNoteHistory> loadCloudNoteHistory(CloudHistory history, String path, {int budget = historyBudget, bool document = false}) async {
  try {
    final versions = await history.versions(path);
    final entries = <HistoryEntry>[];
    var spent = 0;
    var more = false;
    for (final session in sessionsOf(versions)) {
      final last = session.last;
      if (spent + last.size > budget && entries.isNotEmpty) {
        more = true;
        break;
      }
      spent += last.size;
      final text = noteTextOf(await history.text(last), last, document: document);
      entries.add(
        HistoryEntry(
          title: text.title,
          body: text.body,
          at: session.to,
          from: session.versions.length > 1 ? session.from : null,
          device: last.device,
          cloud: last,
          session: session,
          path: last.path,
        ),
      );
    }
    return CloudNoteHistory(CloudAccess.on, entries: entries, more: more);
  } on SyncHttpError catch (error) {
    return CloudNoteHistory(switch (error.status) {
      402 => CloudAccess.noSubscription,
      401 => CloudAccess.signedOut,
      _ => CloudAccess.offline,
    });
  } on SocketException {
    return const CloudNoteHistory(CloudAccess.offline);
  } on Object {
    return const CloudNoteHistory(CloudAccess.offline);
  }
}

/// Облачная история заметки: (id заметки, бюджет байт, документ ли). «Показать раньше» удваивает
/// бюджет; уже открытые тексты берутся из памяти службы.
final cloudNoteHistoryProvider = FutureProvider.autoDispose.family<CloudNoteHistory, (String, int, bool)>((ref, key) async {
  final (itemId, budget, document) = key;
  if (!await ref.watch(syncSignedInProvider.future)) return const CloudNoteHistory(CloudAccess.signedOut);
  final subscription = await ref.watch(subscriptionProvider.future);
  if (!subscription.activeNow) return const CloudNoteHistory(CloudAccess.noSubscription);
  final history = await ref.watch(cloudHistoryProvider.future);
  if (history == null) return const CloudNoteHistory(CloudAccess.signedOut);
  final path = await ref.read(historyRepositoryProvider).pathOf(itemId);
  if (path == null) return const CloudNoteHistory(CloudAccess.on);
  return loadCloudNoteHistory(history, path, budget: budget, document: document);
});
