import 'dart:async';

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

/// Открыта ли страница как боковая панель: адрес с `?panel` (так её открывает расширение)
/// или узкое окно (веб-панель Vivaldi, Opera, Edge с обычным адресом). Вне браузера — нет.
bool isPanelPage() => false;
