import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/base_edit.dart';
import 'package:stowa/domain/obsidian_base.dart';

const _courses = '''
# мой комментарий
views:
  - type: cards
    name: Сейчас
    filters:
      and:
        - file.folder == "00 Предметы - Курсы"
    order:
      - file.name
      - Курс обучения
    sort:
      - property: Экзамен
        direction: ASC
    columnSize:
      file.name: 500
    image: note.Обложка
    imageAspectRatio: 1
  - type: table
    name: Все курсы
''';

void main() {
  test('сортировка и группа ложатся в свой вид, остальное в файле не трогается', () {
    final text = (BaseEditor(_courses)
          ..setSort(0, [(property: 'file.mtime', descending: true)])
          ..setGroupBy(1, (property: 'Курс обучения', descending: false)))
        .text;
    expect(text, contains('# мой комментарий'));
    expect(text, contains('image: note.Обложка'));
    final base = ObsidianBase.parse(text);
    expect(base.views[0].sort, [(property: 'file.mtime', descending: true)]);
    expect(base.views[1].groupBy, (property: 'Курс обучения', descending: false));
    // пустая сортировка и снятая группа убирают ключ
    final cleared = ObsidianBase.parse((BaseEditor(text)..setSort(0, const [])..setGroupBy(1, null)).text);
    expect(cleared.views[0].sort, isEmpty);
    expect(cleared.views[1].groupBy, isNull);
  });

  test('фильтры: всех видов и этого вида, and/or/not с вложением', () {
    const filter = BaseAnd([BaseExpr('rating > 3'), BaseOr([BaseExpr('file.hasTag("книга")'), BaseExpr('status == "читаю"')])]);
    final text = (BaseEditor(_courses)
          ..setFilter(null, filter)
          ..setFilter(1, const BaseNot([BaseExpr('file.name.contains("Черновик")')])))
        .text;
    final base = ObsidianBase.parse(text);
    expect(describeFilter(base.filters), describeFilter(filter));
    expect(describeFilter(base.views[1].filters), 'not(file.name.contains("Черновик"))');
    expect(ObsidianBase.parse((BaseEditor(text)..setFilter(null, null)).text).filters, isNull);
  });

  test('колонки, подписи, ширина, итоги, предел', () {
    final text = (BaseEditor(_courses)
          ..setOrder(1, ['file.name', 'formula.avg'])
          ..setDisplayName('formula.avg', 'Среднее')
          ..setDisplayName('Курс обучения', 'Курс')
          ..setColumnSize(0, 'Курс обучения', 144)
          ..setSummary(1, 'formula.avg', 'Average')
          ..setLimit(1, 20))
        .text;
    final base = ObsidianBase.parse(text);
    expect(base.views[1].order, ['file.name', 'formula.avg']);
    expect(base.displayName('formula.avg'), 'Среднее');
    expect(base.displayName('note.Курс обучения'), 'Курс');
    expect(base.views[0].widthOf('Курс обучения'), 144);
    expect(base.views[0].widthOf('file.name'), 500);
    expect(base.views[1].summaryOf('formula.avg'), 'Average');
    expect(base.views[1].limit, 20);
    final back = ObsidianBase.parse((BaseEditor(text)..setDisplayName('formula.avg', null)..setSummary(1, 'formula.avg', null)..setLimit(1, null)).text);
    expect(back.displayName('formula.avg'), isNull);
    expect(back.views[1].summaryOf('formula.avg'), isNull);
    expect(back.views[1].limit, isNull);
  });

  test('формулы: новая, правка, переименование вместе с колонками, удаление', () {
    var text = (BaseEditor(_courses)..setFormula('stars', 'rating * 2')).text;
    expect(ObsidianBase.parse(text).formulas, {'stars': 'rating * 2'});
    text = (BaseEditor(text)
          ..setOrder(1, ['file.name', 'formula.stars'])
          ..renameFormula('stars', 'звёзды'))
        .text;
    final base = ObsidianBase.parse(text);
    expect(base.formulas, {'звёзды': 'rating * 2'});
    expect(base.views[1].order, ['file.name', 'formula.звёзды']);
    expect(ObsidianBase.parse((BaseEditor(text)..setFormula('звёзды', null)).text).formulas, isEmpty);
  });

  test('виды: новый, копия, имя, раскладка, настройки карточек, перенос, удаление', () {
    var editor = BaseEditor(_courses)
      ..addView(BaseViewType.kanban, 'Доска')
      ..duplicateView(0, 'Сейчас 2')
      ..renameView(1, 'Курсы')
      ..setViewType(1, BaseViewType.list)
      ..setCardOption(0, 'cardSize', 240)
      ..setCardOption(0, 'imageFit', 'contain');
    var base = ObsidianBase.parse(editor.text);
    expect(base.views.map((view) => (view.type, view.name)), [
      (BaseViewType.cards, 'Сейчас'),
      (BaseViewType.list, 'Курсы'),
      (BaseViewType.kanban, 'Доска'),
      (BaseViewType.cards, 'Сейчас 2'),
    ]);
    expect(base.views[0].cardSize, 240);
    expect(base.views[0].imageFit, BaseImageFit.contain);
    expect(base.views[3].image, 'note.Обложка');
    editor = BaseEditor(editor.text)
      ..moveView(3, 0)
      ..deleteView(1);
    base = ObsidianBase.parse(editor.text);
    expect(base.views.map((view) => view.name), ['Сейчас 2', 'Курсы', 'Доска']);
  });

  test('пустой файл: первая правка заводит вид, который база показывала сама', () {
    final text = (BaseEditor('')..setSort(0, [(property: 'file.name', descending: false)])).text;
    final base = ObsidianBase.parse(text);
    expect(base.broken, isFalse);
    expect(base.views.single.type, BaseViewType.table);
    expect(base.views.single.sort.single.property, 'file.name');
    expect(text, isNot(contains('{')));
  });
}
