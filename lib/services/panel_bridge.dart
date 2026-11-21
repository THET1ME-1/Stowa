import 'dart:async';

import '../core/fs/panel_link.dart' if (dart.library.js_interop) '../core/fs/panel_link_web.dart';

export '../core/fs/panel_link.dart' if (dart.library.js_interop) '../core/fs/panel_link_web.dart' show PanelLink, isPanelAddress, isPanelPage;

/// Найденная заметка для панели: только то, что видно в списке.
class PanelNote {
  const PanelNote({required this.id, required this.title, this.line, this.folder});

  final String id;
  final String title;

  /// Первая строка текста под заголовком.
  final String? line;
  final String? folder;

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'line': line, 'folder': folder};

  static PanelNote fromJson(Map<Object?, Object?> json) =>
      PanelNote(id: '${json['id']}', title: '${json['title'] ?? ''}', line: json['line'] as String?, folder: json['folder'] as String?);
}

/// Вкладка, которая держит хранилище, отвечает боковой панели (STOWA-9): записывает,
/// отменяет, ищет и открывает заметки. Под «Кодом на вход» ([locked]) запись
/// принимается, а поиск и папка в ответе — нет: из базы без кода ничего не показываем.
class PanelBridge {
  PanelBridge({required this.link, required this.locked, required this.capture, required this.undo, required this.search, required this.open});

  final PanelLink link;
  final bool Function() locked;

  /// Сохранить текст; ответ — id и папка, куда легло.
  final Future<({String id, String? folder})> Function(String text) capture;
  final Future<void> Function(String id) undo;
  final Future<List<PanelNote>> Function(String query) search;
  final void Function(String id) open;

  StreamSubscription<Map<String, Object?>>? _listening;

  void start() => _listening = link.messages.listen((message) => _answer(message).ignore());

  void stop() {
    _listening?.cancel();
    link.close();
  }

  Future<void> _answer(Map<String, Object?> message) async {
    final id = message['id'];
    void reply(String type, [Map<String, Object?> more = const {}]) => link.send({'type': type, 'id': id, ...more});
    switch (message['type']) {
      case 'hello':
        reply('here', {'locked': locked()});
      case 'capture':
        final text = '${message['text'] ?? ''}';
        if (text.trim().isEmpty) return reply('failed');
        try {
          final saved = await capture(text);
          reply('captured', {'item': saved.id, 'folder': locked() ? null : saved.folder});
        } catch (_) {
          reply('failed');
        }
      case 'undo':
        await undo('${message['item']}');
        reply('undone');
      case 'search':
        if (locked()) return reply('found', {'locked': true, 'notes': const <Object>[]});
        final notes = await search('${message['query'] ?? ''}');
        reply('found', {'notes': [for (final note in notes) note.toJson()]});
      case 'open':
        if (!locked()) open('${message['item']}');
        reply('opened');
    }
  }
}

/// Панель спрашивает вкладку: каждый вопрос со своим номером, ответ ждётся с [timeout].
/// Вкладка не ответила — null: старая версия или заснувшая вкладка.
class PanelClient {
  PanelClient(this.link) {
    _listening = link.messages.listen((message) {
      final waiting = _waiting.remove(message['id']);
      if (waiting != null && !waiting.isCompleted) waiting.complete(message);
    });
  }

  final PanelLink link;
  final _waiting = <String, Completer<Map<String, Object?>>>{};
  late final StreamSubscription<Map<String, Object?>> _listening;
  int _count = 0;

  // номер вопроса: свой у каждой панели, чтобы ответ одной не приняла другая
  final _prefix = DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  Future<Map<String, Object?>?> ask(String type, {Map<String, Object?> payload = const {}, Duration timeout = const Duration(milliseconds: 1500)}) async {
    final id = '$_prefix-${_count++}';
    final answer = Completer<Map<String, Object?>>();
    _waiting[id] = answer;
    link.send({'type': type, 'id': id, ...payload});
    try {
      return await answer.future.timeout(timeout);
    } on TimeoutException {
      _waiting.remove(id);
      return null;
    }
  }

  void close() {
    _listening.cancel();
    link.close();
  }
}

/// Страница, которая получила хранилище, сразу отвечает на «кто держит»: ещё до файлов и
/// базы. Иначе вкладку, перезагруженную при открытой панели, встретило бы «уже открыта»:
/// панель забрала хранилище на миг перезагрузки и ещё грузится. [panel] — адрес `?panel`.
void answerWho({required bool panel}) {
  final link = PanelLink();
  link.messages.listen((message) {
    if (message['type'] == 'who') link.send({'type': 'holder', 'id': message['id'], 'panel': panel});
  });
}

/// Держит ли хранилище панель: тогда обычная вкладка заберёт его сама, без «Открыть здесь».
Future<bool> holderIsPanel() async {
  final client = PanelClient(PanelLink());
  final answer = await client.ask('who', timeout: const Duration(milliseconds: 800));
  client.close();
  return answer?['panel'] == true;
}
