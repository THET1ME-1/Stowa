import 'dart:async';

import 'package:stream_channel/stream_channel.dart';

/// Канал между боковой панелью браузера и вкладкой Stowa, которая держит хранилище
/// (STOWA-9). В браузере это `BroadcastChannel` (`panel_link_web.dart`), здесь — шина в
/// памяти процесса: на ней тесты связывают панель и вкладку. Своё сообщение отправитель,
/// как и в браузере, не получает.
class PanelLink {
  PanelLink() {
    _hub.add(this);
  }

  static final _hub = <PanelLink>[];
  final _incoming = StreamController<Map<String, Object?>>.broadcast();

  Stream<Map<String, Object?>> get messages => _incoming.stream;

  void send(Map<String, Object?> message) {
    for (final other in List.of(_hub)) {
      // как у браузера: сообщение приходит следующей задачей, не посреди отправки
      if (!identical(other, this)) scheduleMicrotask(() => other._incoming.add(Map.of(message)));
    }
  }

  void close() {
    _hub.remove(this);
    _incoming.close();
  }
}

/// Канал базы между вкладкой и одной панелью по имени (`panel_db.dart`). В браузере —
/// свой `BroadcastChannel` на имя, здесь — шина в памяти с тем же поведением: сообщение
/// получают только концы, уже открытые к моменту отправки, а открытый конец копит
/// пришедшее, пока его не начали слушать.
StreamChannel<Object?> panelDbChannel(String name) {
  final pair = StreamChannelController<Object?>();
  final bus = _dbBuses.putIfAbsent(name, () => []);
  bus.add(pair);
  pair.local.stream.listen(
    (message) {
      for (final other in List.of(bus)) {
        if (!identical(other, pair)) scheduleMicrotask(() => other.local.sink.add(message));
      }
    },
    onDone: () => bus.remove(pair),
  );
  return pair.foreign;
}

final _dbBuses = <String, List<StreamChannelController<Object?>>>{};

/// Открыта ли страница как боковая панель: адрес с `?panel` (так её открывает расширение)
/// или узкое окно (веб-панель Vivaldi, Opera, Edge с обычным адресом). Вне браузера — нет.
bool isPanelPage() => false;

/// Панель названа явно, адресом `?panel`. Только такую широкая вкладка выселяет сама:
/// обычное узкое окно потеряло бы набранное в строке.
bool isPanelAddress() => false;
