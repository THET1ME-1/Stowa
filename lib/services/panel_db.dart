import 'dart:async';

import 'package:drift/drift.dart';
// протокол drift между сервером и клиентом меняется от версии к версии: вкладка и панель —
// одна сборка сайта, а разные сборки рукопожатие моста не пускает к базе
// ignore: experimental_member_use
import 'package:drift/remote.dart';

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
  PanelDbServer(this._db) : _server = DriftServer(_db.executor.interceptWith(_ReadOnly()), closeConnectionAfterShutdown: false);

  final AppDatabase _db;
  final DriftServer _server;
  StreamSubscription<Set<TableUpdate>>? _changes;

  /// Отдать базу панели, которая ждёт на канале [name].
  void serve(String name) => _server.serve(panelDbChannel(name)).ignore();

  /// Правки вкладки — панелям: их слежка за таблицами просыпается сама.
  void relayChanges(PanelLink link) {
    _changes ??= _db.tableUpdates(const TableUpdateQuery.any()).listen((updates) {
      link.send({'type': 'tables', 'names': [for (final update in updates) update.table]});
    });
  }

  /// Остановить: открытые панели перестают получать ответы и перезагружаются по пульсу.
  /// База вкладки остаётся открытой; ждать конца нельзя — канал браузера не закрывается.
  void stop() {
    _changes?.cancel().ignore();
    _server.shutdown().ignore();
  }
}

/// Подключиться к базе вкладки, которая слушает канал [name]. О правках вкладки панель
/// узнаёт сообщениями моста ([followPanelDb]), поэтому слежка своя, обычная;
/// [closeStreamsSynchronously] — для тестов, как у `AppDatabase.memory`.
Future<AppDatabase> openPanelDb(String name, {bool closeStreamsSynchronously = false}) async {
  final remote = await connectToRemoteAndInitialize(panelDbChannel(name));
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
