import 'dart:async';

import 'package:drift/drift.dart';
// протокол drift между сервером и клиентом меняется от версии к версии: вкладка и панель —
// одна сборка сайта, а разные сборки рукопожатие моста не пускает к базе
// ignore: experimental_member_use
import 'package:drift/remote.dart';
import 'package:stream_channel/stream_channel.dart';

import '../data/db/database.dart';
import 'panel_bridge.dart';

/// База вкладки для боковой панели браузера (STOWA-9, хозяин 21.11: «почти ни одной функции
/// не перенёс»). В панели стоит строка телефона целиком, а она читает базу: поиск, папки,
/// теги, догадка папки. База одна и живёт во вкладке, которая держит хранилище; панель
/// получает её через drift `DriftServer` по своему каналу (`panelDbChannel`) и только на
/// чтение. Всё, что пишет, — «Закинуть», «Дописать», новая папка, холст, вложения и голос —
/// панель просит у вкладки мостом (`PanelBridge`): писатель хранилища, факты, превью и ИИ
/// работают там, а в панели нет ни одной службы. Без этого панель взялась бы за очередь
/// хранилища, которую ей нечем записать в файлы.
class PanelDbServer {
  PanelDbServer(this._db, {this.quiet = const Duration(milliseconds: 200)})
    : _server = DriftServer(_db.executor.interceptWith(_ReadOnly()), closeConnectionAfterShutdown: false);

  final AppDatabase _db;
  final DriftServer _server;

  /// Правки вкладки копятся столько, прежде чем уйти панелям одним сообщением: фон разбирает
  /// заметки пачками, и на каждую запись панель перечитывала бы папки и теги через канал.
  final Duration quiet;
  StreamSubscription<Set<TableUpdate>>? _changes;
  final _pending = <String>{};
  Timer? _send;

  /// Отдать базу панели, которая ждёт на канале [name].
  void serve(String name) => _server.serve(panelDbChannel(name)).ignore();

  /// Правки вкладки — панелям: их слежка за таблицами просыпается сама.
  void relayChanges(PanelLink link) {
    _changes ??= _db.tableUpdates(const TableUpdateQuery.any()).listen((updates) {
      _pending.addAll([for (final update in updates) update.table]);
      _send ??= Timer(quiet, () {
        _send = null;
        link.send({'type': 'tables', 'names': _pending.toList()});
        _pending.clear();
      });
    });
  }

  /// Остановить. База вкладки остаётся открытой; ждать конца нельзя — канал браузера не
  /// закрывается.
  void stop() {
    _send?.cancel();
    _changes?.cancel().ignore();
    _server.shutdown().ignore();
  }
}

/// Номер договорённости вкладки и панели: формат просьб моста и протокол drift. Меняется
/// формат — растёт номер, и панель другой сборки остаётся лёгкой, а не шлёт непонятное.
const panelProtocol = 1;

/// База вкладки для панели: вкладка той же сборки ответила и кода на вход нет —
/// подключиться. Иначе null: панель останется лёгкой.
///
/// Свой конец канала панель открывает ДО просьбы `db-open`: вкладка, начав отдавать базу,
/// сразу шлёт первое сообщение, а `BroadcastChannel` не копит сообщения для тех, кто ещё
/// не открыл канал. В обратном порядке подключение ждало вечно (поймано в браузере 21.11).
Future<AppDatabase?> connectTabDatabase(PanelClient client, {bool closeStreamsSynchronously = false, Duration wait = const Duration(seconds: 5), int tries = 8}) async {
  // вкладку могли только что перезагрузить: она отвечает, только подняв файлы и базу
  Map<String, Object?>? hello;
  for (var attempt = 0; attempt < tries && hello == null; attempt++) {
    hello = await client.ask('hello');
  }
  if (hello == null || hello['schema'] != AppDatabase.schema || hello['protocol'] != panelProtocol) return null;
  final name = 'stowa-db-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
  final channel = panelDbChannel(name);
  final ready = await client.ask('db-open', payload: {'channel': name, 'schema': AppDatabase.schema});
  if (ready?['type'] != 'db-ready') {
    await channel.sink.close();
    return null;
  }
  try {
    return await openPanelDb(channel, closeStreamsSynchronously: closeStreamsSynchronously).timeout(wait);
  } catch (_) {
    await channel.sink.close();
    return null;
  }
}

/// Подключиться к базе вкладки по уже открытому [channel]. О правках вкладки панель
/// узнаёт сообщениями моста ([followPanelDb]), поэтому слежка своя, обычная;
/// [closeStreamsSynchronously] — для тестов, как у `AppDatabase.memory`.
Future<AppDatabase> openPanelDb(StreamChannel<Object?> channel, {bool closeStreamsSynchronously = false}) async {
  final remote = await connectToRemoteAndInitialize(channel);
  return AppDatabase(closeStreamsSynchronously ? DatabaseConnection(remote.executor, closeStreamsSynchronously: true) : remote);
}

/// Панель узнаёт о правках вкладки сообщениями `tables` и будит свою слежку.
StreamSubscription<Map<String, Object?>> followPanelDb(AppDatabase db, Stream<Map<String, Object?>> messages) => messages.listen((message) {
  if (message['type'] != 'tables') return;
  final names = (message['names'] as List?) ?? const [];
  if (names.isNotEmpty) db.notifyUpdates({for (final name in names) TableUpdate('$name')});
});

/// Запросы панели: читать можно, писать нельзя. Транзакция тоже запрещена: панель могут
/// закрыть посреди неё, и база вкладки встала бы навсегда.
class _ReadOnly extends QueryInterceptor {
  Never _refuse() => throw StateError('panel database is read-only');

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) => _refuse();

  @override
  QueryExecutor beginExclusive(QueryExecutor parent) => _refuse();

  @override
  Future<int> runInsert(QueryExecutor executor, String statement, List<Object?> args) => _refuse();

  @override
  Future<int> runUpdate(QueryExecutor executor, String statement, List<Object?> args) => _refuse();

  @override
  Future<int> runDelete(QueryExecutor executor, String statement, List<Object?> args) => _refuse();

  @override
  Future<void> runCustom(QueryExecutor executor, String statement, List<Object?> args) => _refuse();

  @override
  Future<void> runBatched(QueryExecutor executor, BatchedStatements statements) => _refuse();
}
