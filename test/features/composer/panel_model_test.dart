import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/repositories/folders_repository.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/data/repositories/tags_repository.dart';
import 'package:stowa/domain/folder_guess.dart';
import 'package:stowa/domain/line_query.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/domain/search_rank.dart';
import 'package:stowa/domain/sort_rules.dart';
import 'package:stowa/features/composer/panel_model.dart';

const _keys = {
  LineCommand.remind: ['напомнить'],
  LineCommand.task: ['задача'],
  LineCommand.list: ['список'],
  LineCommand.find: ['найти'],
  LineCommand.inbox: ['входящие'],
};

const _car = FolderCard(id: 'car', name: 'Машина', icon: 'directions_car', shape: 'pill', count: 3, covers: [], recentTitles: [], createdByAi: false);
const _refs = FolderCard(id: 'refs', name: 'Референсы', icon: 'palette', shape: 'squircle', count: 9, covers: [], recentTitles: [], createdByAi: false);
const _light = TagCard(id: 't1', name: 'свет', iconKind: TagIconKind.symbol, iconValue: 'emoji_objects', count: 5);

SearchResult _found(String id, String title, {bool strong = false, int matched = 1, ItemKind kind = ItemKind.note}) => SearchResult(
      card: ItemCard(id: id, title: title, kind: kind, folderId: null, sortState: SortState.sorted, createdAt: DateTime(2026)),
      hit: SearchHit(doc: SearchDoc(id: id, title: title), score: 1, matched: matched, strong: strong, marks: const {}),
    );

PanelState _panel(String text, {List<SearchResult> found = const [], List<SortRule> rules = const [], List<String> chosen = const [], DateTime? remind}) =>
    buildPanel(PanelInput(
      text: text,
      caret: text.length,
      commandKeys: _keys,
      tags: const [_light],
      folders: const [_car, _refs],
      rules: rules,
      found: found,
      chosenTags: chosen,
      remindAt: remind,
    ));

void main() {
  test('# под курсором показывает теги и «Создать», если такого нет', () {
    final panel = _panel('лампа #св');
    expect(panel.header, PanelHeader.tags);
    expect(panel.rows.first, isA<TagRow>());
    expect(panel.rows.last, isA<NewTagRow>());
    expect(_panel('лампа #свет').rows, hasLength(1));
  });

  test('@ показывает папки по началу любого слова', () {
    final panel = _panel('@реф');
    expect(panel.header, PanelHeader.folders);
    expect((panel.rows.first as FolderRow).folder.id, 'refs');
    expect(panel.rows.last, isA<NewFolderRow>());
  });

  test('незнакомая папка после @ — «Создать папку» с именем как набрано', () {
    final panel = _panel('@Книги');
    expect((panel.rows.single as NewFolderRow).name, 'Книги');
    expect(_panel('@машина').rows.whereType<NewFolderRow>(), isEmpty);
  });

  test('папка с пробелами: создать целиком, найти существующую по началу имени', () {
    expect((_panel('@Беспроводные возможности').rows.single as NewFolderRow).name, 'Беспроводные возможности');
    const gifts = FolderCard(id: 'gifts', name: 'Подарки Сане', icon: 'redeem', shape: 'gem', count: 1, covers: [], recentTitles: [], createdByAi: false);
    final panel = buildPanel(const PanelInput(text: '@подарки с', caret: 10, commandKeys: _keys, folders: [_car, gifts]));
    expect((panel.rows.first as FolderRow).folder.id, 'gifts');
  });

  test('/ в начале показывает команды', () {
    final panel = _panel('/за');
    expect((panel.rows.single as CommandRow).command, LineCommand.task);
  });

  test('слово ставит тег, тег кладёт в «Машину», причина — тег', () {
    final rules = [
      const SortRule(id: 'a', condition: RuleConditionKind.keyword, conditionValue: 'шиномонтаж', action: RuleActionKind.addTag, actionValue: 'машина'),
      const SortRule(id: 'b', condition: RuleConditionKind.hasTag, conditionValue: 'машина', action: RuleActionKind.toFolder, actionValue: 'car'),
    ];
    final plan = _panel('записаться на шиномонтаж', rules: rules).plan!;
    expect(plan.folder?.id, 'car');
    expect(plan.reason, SaveReason.tag);
    expect(plan.reasonValue, 'машина');
    expect(plan.autoTags, ['машина']);
  });

  test('без правила имя героя находит его книгу, причина — имя', () {
    const novel = FolderCard(id: 'novel', name: 'Роман', icon: 'menu_book', shape: 'squircle', count: 2, covers: [], recentTitles: [], createdByAi: false);
    final index = FolderIndex(const [
      FolderDoc(folderId: 'novel', text: 'Милтон работает курьером'),
      FolderDoc(folderId: 'novel', text: 'Сцена: Милтон спорит с сестрой'),
      FolderDoc(folderId: 'car', text: 'Замена масла'),
    ]);
    final plan = buildPanel(PanelInput(
      text: 'Пусть у Милтона будет личная проблема',
      caret: 37,
      commandKeys: _keys,
      folders: const [_car, novel],
      folderIndex: index,
    )).plan!;
    expect(plan.folder?.id, 'novel');
    expect(plan.reason, SaveReason.name);
    expect(plan.reasonValue, 'Милтона');
  });

  test('без правила папку подберёт ключ ИИ, а новое — новое', () {
    final panel = _panel('купить батарейки');
    expect(panel.plan!.reason, SaveReason.none);
    expect(panel.header, PanelHeader.fresh);
    expect(panel.pick, 0);
  });

  test('строка без поиска не говорит «Похожего нет»: она не искала', () {
    final panel = buildPanel(const PanelInput(text: 'купить батарейки', caret: 16, commandKeys: _keys, writeOnly: true));
    expect(panel.plan, isNotNull);
    expect(panel.header, PanelHeader.none);
  });

  test('строка «только закинуть» причину не называет: папку она знает, но молчит', () {
    final panel = buildPanel(const PanelInput(text: 'купить батарейки', caret: 16, commandKeys: _keys, writeOnly: true));
    expect(panel.plan!.reason, SaveReason.quiet);
  });

  test('строка «только закинуть» после @ ничего не предлагает: ни папок, ни «Создать»', () {
    final panel = buildPanel(const PanelInput(text: '@маш', caret: 4, commandKeys: _keys, folders: [_car], writeOnly: true));
    expect(panel.rows, isEmpty);
    expect(buildPanel(const PanelInput(text: '@Книги', caret: 6, commandKeys: _keys, writeOnly: true)).rows, isEmpty);
  });

  test('точное совпадение короткого запроса делает белым найденное', () {
    final panel = _panel('пароль', found: [_found('w', 'Пароль от Wi-Fi', strong: true)]);
    expect(panel.rows, hasLength(2));
    expect(panel.pick, 1);
    expect(panel.header, PanelHeader.found);
  });

  test('дописать можно в любую найденную заметку, даже по одному слову; в ссылку — нет', () {
    final panel = _panel(
      'Дипломная: ключевые слова оставить',
      found: [_found('d', 'Разработка архитектуры', matched: 1), _found('e', 'Ещё заметка', matched: 1), _found('l', 'Ссылка', kind: ItemKind.link)],
    );
    expect([for (final row in panel.rows.whereType<ResultRow>()) row.canAppend], [true, true, false]);
  });

  test('похожее, но не точное: белое у «Закинуть», первой заметке можно дописать', () {
    final panel = _panel('виджет погоды для пары в togetherly', found: [_found('w', 'Погода для пары', matched: 3)]);
    expect(panel.pick, 0);
    expect(panel.header, PanelHeader.similar);
    expect((panel.rows[1] as ResultRow).canAppend, isTrue);
  });

  test('«/найти» только ищет', () {
    final panel = _panel('/найти пароль', found: [_found('w', 'Пароль')]);
    expect(panel.plan, isNull);
    expect(panel.rows.single, isA<ResultRow>());
  });

  test('«/список» считает пункты', () {
    expect(_panel('/список молоко, хлеб\nяйца').plan!.listCount, 3);
  });

  test('дата в тексте мешает открыть найденное: это запись', () {
    final panel = _panel('пароль', found: [_found('w', 'Пароль', strong: true)], remind: DateTime(2026, 11, 3, 10));
    expect(panel.pick, 0);
  });

  test('фильтр видов, когда найдено разное', () {
    final panel = _panel('паста', found: [
      _found('a', 'Паста', kind: ItemKind.video),
      _found('b', 'Паста с тыквой'),
      _found('c', 'Паста фото', kind: ItemKind.image),
    ]);
    expect(panel.kinds, [ItemKind.video, ItemKind.note, ItemKind.image]);
  });
}
