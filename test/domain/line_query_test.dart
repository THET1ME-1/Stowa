import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/line_query.dart';

const _keys = {
  LineCommand.remind: ['напомнить', 'remind'],
  LineCommand.task: ['задача', 'task'],
  LineCommand.list: ['список', 'list'],
  LineCommand.find: ['найти', 'find'],
  LineCommand.inbox: ['входящие', 'inbox'],
};

void main() {
  group('слово под курсором', () {
    test('решётка открывает теги, запрос без решётки', () {
      final token = caretToken('лампа #св', 9)!;
      expect(token.kind, CaretKind.tag);
      expect(token.query, 'св');
      expect((token.start, token.end), (6, 9));
    });

    test('собака открывает папки, хвост слова после курсора входит в замену', () {
      final token = caretToken('@реф лампа', 2)!;
      expect(token.kind, CaretKind.folder);
      expect(token.query, 'р');
      expect((token.start, token.end), (0, 4));
    });

    test('косая черта в начале открывает команды', () {
      final token = caretToken('/за', 3)!;
      expect(token.kind, CaretKind.command);
      expect(token.query, 'за');
    });

    test('после пробела подсказок тега нет', () {
      expect(caretToken('#свет ', 6), isNull);
      expect(caretToken('адрес почты me@site', 19), isNull);
    });

    test('имя папки может быть из нескольких слов', () {
      final token = caretToken('лампа @Беспроводные возм', 24)!;
      expect(token.kind, CaretKind.folder);
      expect(token.query, 'беспроводные возм');
      expect((token.start, token.end), (6, 24));
    });

    test('после четырёх слов строка уже не ищет папку', () {
      expect(caretToken('@раз два три четыре пять', 24), isNull);
    });
  });

  group('команда', () {
    test('узнаётся на любом из языков и отрезается от текста', () {
      final parsed = parseCommand('/задача купить хлеб', _keys);
      expect(parsed.command, LineCommand.task);
      expect(parsed.rest, 'купить хлеб');
      expect(parseCommand('/inbox note', _keys).command, LineCommand.inbox);
    });

    test('незнакомая команда — просто текст', () {
      final parsed = parseCommand('/путь/к/файлу', _keys);
      expect(parsed.command, isNull);
      expect(parsed.rest, '/путь/к/файлу');
    });
  });

  group('слова для поиска', () {
    test('нижний регистр, ё как е, без служебных слов и повторов', () {
      expect(searchWords('Пароль от Wi-Fi и ЁЛКА ёлка'), ['пароль', 'wi', 'fi', 'елка']);
    });

    test('окончания срезаются у длинных слов', () {
      expect(stem('рецепты'), 'рецепт');
      expect(stem('машину'), 'машин');
      expect(stem('кот'), 'кот');
      expect(stem('wifi'), 'wifi');
    });

    test('одна опечатка прощается', () {
      expect(nearWords('пароль', 'паролб'), isTrue);
      expect(nearWords('пароль', 'пароли'), isTrue);
      expect(nearWords('пароль', 'парль'), isTrue);
      expect(nearWords('пароль', 'перели'), isFalse);
    });
  });

  group('список из строки', () {
    test('каждая строка или запятая — пункт', () {
      expect(checklistItems('молоко, хлеб\nяйца'), ['молоко', 'хлеб', 'яйца']);
      expect(checklistBody(['молоко', 'хлеб']), '- [ ] молоко\n- [ ] хлеб');
    });
  });
}
