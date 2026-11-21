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
/// свой `BroadcastChannel` на имя, здесь — пара концов в памяти: первый, кто назвал имя,
/// получает один конец, второй — другой.
StreamChannel<Object?> panelDbChannel(String name) {
  final waiting = _dbChannels.remove(name);
  if (waiting != null) return waiting.foreign;
  final pair = StreamChannelController<Object?>();
  _dbChannels[name] = pair;
  return pair.local;
}

final _dbChannels = <String, StreamChannelController<Object?>>{};

/// Открыта ли страница как боковая панель: адрес с `?panel` (так её открывает расширение)
/// или узкое окно (веб-панель Vivaldi, Opera, Edge с обычным адресом). Вне браузера — нет.
bool isPanelPage() => false;

/// Панель названа явно, адресом `?panel`. Только такую широкая вкладка выселяет сама:
/// обычное узкое окно потеряло бы набранное в строке.
bool isPanelAddress() => false;
