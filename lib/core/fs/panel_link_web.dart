import 'dart:async';
import 'dart:js_interop';

import 'package:stream_channel/stream_channel.dart';
import 'package:web/web.dart' as web;

/// Канал между боковой панелью браузера и вкладкой Stowa (STOWA-9): `BroadcastChannel`
/// одного сайта. Опыт 21.11: фрейм в странице расширения Chromium слышит вкладку.
class PanelLink {
  PanelLink() {
    _channel.onmessage = ((web.MessageEvent event) {
      final data = event.data.dartify();
      if (data is Map) _incoming.add({for (final entry in data.entries) '${entry.key}': entry.value});
    }).toJS;
  }

  final _channel = web.BroadcastChannel('stowa-panel');
  final _incoming = StreamController<Map<String, Object?>>.broadcast();

  Stream<Map<String, Object?>> get messages => _incoming.stream;

  void send(Map<String, Object?> message) => _channel.postMessage(message.jsify());

  void close() {
    _channel.close();
    _incoming.close();
  }
}

/// Канал базы между вкладкой и одной панелью (`panel_db.dart`): свой `BroadcastChannel` на
/// имя, его слышат только эти двое. drift шлёт по нему лишь числа, строки, байты и списки.
StreamChannel<Object?> panelDbChannel(String name) {
  final channel = web.BroadcastChannel(name);
  final pair = StreamChannelController<Object?>();
  channel.onmessage = ((web.MessageEvent event) => pair.local.sink.add(event.data.dartify())).toJS;
  pair.local.stream.listen((message) => channel.postMessage(message.jsify()), onDone: channel.close);
  return pair.foreign;
}

// уже этого окно браузера — боковая панель, а не вкладка
const _panelWidth = 600;

/// Открыта ли страница как боковая панель: адрес с `?panel` (так её открывает расширение)
/// или узкое окно (веб-панель Vivaldi, Opera, Edge с обычным адресом).
bool isPanelPage() => isPanelAddress() || web.window.innerWidth < _panelWidth;

/// Панель названа явно, адресом `?panel`. Только такую широкая вкладка выселяет сама:
/// обычное узкое окно потеряло бы набранное в строке.
bool isPanelAddress() => Uri.base.queryParameters.containsKey('panel');
