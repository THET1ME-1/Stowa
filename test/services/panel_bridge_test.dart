import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/services/panel_bridge.dart';

// STOWA-9: боковая панель браузера пишет и ищет через вкладку, которая держит хранилище
void main() {
  late List<String> saved;
  late List<String> undone;
  late List<String> opened;
  late bool locked;

  PanelBridge bridge() => PanelBridge(
    link: PanelLink(),
    locked: () => locked,
    capture: (text) async {
      saved.add(text);
      return (id: 'n${saved.length}', folder: 'Работа');
    },
    undo: (id) async => undone.add(id),
    search: (query) async => [PanelNote(id: 'a', title: 'Шины на зиму', line: 'замена в ноябре', folder: 'Машина')],
    open: opened.add,
  );

  setUp(() {
    saved = [];
    undone = [];
    opened = [];
    locked = false;
  });

  test('вкладка отвечает: здесь, записала в папку, нашла, открыла, отменила', () async {
    final tab = bridge()..start();
    addTearDown(tab.stop);
    final panel = PanelClient(PanelLink());
    addTearDown(panel.close);

    expect((await panel.ask('hello'))?['type'], 'here');
    final captured = await panel.ask('capture', payload: {'text': 'купить фильтр'});
    expect((captured?['type'], captured?['item'], captured?['folder']), ('captured', 'n1', 'Работа'));
    expect(saved, ['купить фильтр']);

    final found = await panel.ask('search', payload: {'query': 'шины'});
    final notes = [for (final note in found!['notes']! as List) PanelNote.fromJson(note as Map)];
    expect(notes.single.title, 'Шины на зиму');
    expect(notes.single.folder, 'Машина');

    await panel.ask('open', payload: {'item': 'a'});
    expect(opened, ['a']);
    await panel.ask('undo', payload: {'item': 'n1'});
    expect(undone, ['n1']);
  });

  test('«Код на вход»: запись принимается без папки в ответе, поиска и открытия нет', () async {
    locked = true;
    final tab = bridge()..start();
    addTearDown(tab.stop);
    final panel = PanelClient(PanelLink());
    addTearDown(panel.close);

    expect((await panel.ask('hello'))?['locked'], isTrue);
    final captured = await panel.ask('capture', payload: {'text': 'мысль'});
    expect(captured?['type'], 'captured');
    expect(captured?['folder'], isNull, reason: 'куда легло — тоже из базы');
    final found = await panel.ask('search', payload: {'query': 'шины'});
    expect(found?['locked'], isTrue);
    expect(found?['notes'], isEmpty);
    await panel.ask('open', payload: {'item': 'a'});
    expect(opened, isEmpty);
  });

  test('пустой текст не записывается', () async {
    final tab = bridge()..start();
    addTearDown(tab.stop);
    final panel = PanelClient(PanelLink());
    addTearDown(panel.close);
    expect((await panel.ask('capture', payload: {'text': '   '}))?['type'], 'failed');
    expect(saved, isEmpty);
  });

  test('вкладка молчит — ответа нет, без зависания', () async {
    final panel = PanelClient(PanelLink());
    addTearDown(panel.close);
    expect(await panel.ask('hello', timeout: const Duration(milliseconds: 100)), isNull);
  });

  // «кто держит» отвечает страница сразу после захвата хранилища, ещё до моста главной
  test('кто держит хранилище: панель отвечает «панель», а молчание — не панель', () async {
    expect(await holderIsPanel(), isFalse, reason: 'никто не ответил');
    answerWho(panel: true);
    expect(await holderIsPanel(), isTrue);
  });
}
