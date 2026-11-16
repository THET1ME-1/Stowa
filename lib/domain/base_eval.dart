part of 'obsidian_base.dart';

// Вычислитель выражений Bases: строка разбирается в дерево один раз (кэш по тексту),
// дерево считается для каждой заметки. Лямбды filter, map и reduce — это тоже дерево:
// аргумент считается заново для каждого элемента с value, index и acc.

enum _T { number, string, regex, ident, op, lparen, rparen, lbracket, rbracket, comma, dot, end }

class _Token {
  const _Token(this.type, this.text, [this.value]);
  final _T type;
  final String text;
  final Object? value;
}

final _identStart = RegExp(r'[\p{L}_$]', unicode: true);
final _identRest = RegExp(r'[\p{L}\p{N}_$-]', unicode: true);

List<_Token> _lex(String source) {
  final tokens = <_Token>[];
  var i = 0;
  const twoChar = {'==', '!=', '>=', '<=', '&&', '||'};
  // «/» в начале значения — выражение /…/, после значения — деление
  bool valueExpected() => tokens.isEmpty || const {_T.op, _T.lparen, _T.lbracket, _T.comma}.contains(tokens.last.type);
  while (i < source.length) {
    final c = source[i];
    if (c.trim().isEmpty) {
      i++;
      continue;
    }
    if (c == '"' || c == "'") {
      final buffer = StringBuffer();
      i++;
      while (i < source.length && source[i] != c) {
        if (source[i] == r'\' && i + 1 < source.length) i++;
        buffer.write(source[i]);
        i++;
      }
      if (i >= source.length) throw const BaseUnsupported('строка без конца');
      i++;
      tokens.add(_Token(_T.string, buffer.toString(), buffer.toString()));
      continue;
    }
    if (c == '/' && valueExpected()) {
      final buffer = StringBuffer();
      i++;
      while (i < source.length && source[i] != '/') {
        if (source[i] == r'\' && i + 1 < source.length) {
          buffer.write(source[i]);
          i++;
        }
        buffer.write(source[i]);
        i++;
      }
      if (i >= source.length) throw const BaseUnsupported('выражение без конца');
      i++;
      final flags = RegExp('[a-z]*').matchAsPrefix(source, i)![0]!;
      i += flags.length;
      tokens.add(_Token(_T.regex, buffer.toString(), _Regex(RegExp(buffer.toString(), caseSensitive: !flags.contains('i'), unicode: true), global: flags.contains('g'))));
      continue;
    }
    if (RegExp(r'[0-9]').hasMatch(c)) {
      final match = RegExp(r'[0-9]+(\.[0-9]+)?').matchAsPrefix(source, i)!;
      tokens.add(_Token(_T.number, match[0]!, num.parse(match[0]!)));
      i = match.end;
      continue;
    }
    if (_identStart.hasMatch(c)) {
      var end = i + 1;
      while (end < source.length && _identRest.hasMatch(source[end])) {
        end++;
      }
      tokens.add(_Token(_T.ident, source.substring(i, end)));
      i = end;
      continue;
    }
    if (i + 1 < source.length && twoChar.contains(source.substring(i, i + 2))) {
      tokens.add(_Token(_T.op, source.substring(i, i + 2)));
      i += 2;
      continue;
    }
    tokens.add(switch (c) {
      '(' => const _Token(_T.lparen, '('),
      ')' => const _Token(_T.rparen, ')'),
      '[' => const _Token(_T.lbracket, '['),
      ']' => const _Token(_T.rbracket, ']'),
      ',' => const _Token(_T.comma, ','),
      '.' => const _Token(_T.dot, '.'),
      '>' || '<' || '!' || '+' || '-' || '*' || '/' || '%' => _Token(_T.op, c),
      _ => throw BaseUnsupported('знак «$c»'),
    });
    i++;
  }
  tokens.add(const _Token(_T.end, ''));
  return tokens;
}

// ── дерево ──────────────────────────────────────────────────────────────────

sealed class _Node {
  const _Node();
}

class _Lit extends _Node {
  const _Lit(this.value);
  final Object? value;
}

class _Name extends _Node {
  const _Name(this.name);
  final String name;
}

class _ListLit extends _Node {
  const _ListLit(this.items);
  final List<_Node> items;
}

class _Unary extends _Node {
  const _Unary(this.op, this.operand);
  final String op;
  final _Node operand;
}

class _Binary extends _Node {
  const _Binary(this.op, this.left, this.right);
  final String op;
  final _Node left;
  final _Node right;
}

class _Member extends _Node {
  const _Member(this.target, this.name);
  final _Node target;
  final String name;
}

class _Index extends _Node {
  const _Index(this.target, this.index);
  final _Node target;
  final _Node index;
}

class _Call extends _Node {
  const _Call(this.name, this.args);
  final String name;
  final List<_Node> args;
}

class _MethodCall extends _Node {
  const _MethodCall(this.target, this.name, this.args);
  final _Node target;
  final String name;
  final List<_Node> args;
}

final _parsed = <String, _Node>{};

_Node _parse(String source) {
  if (_parsed[source] case final node?) return node;
  final node = _Parser(_lex(source)).parse();
  if (_parsed.length > 2000) _parsed.clear();
  return _parsed[source] = node;
}

class _Parser {
  _Parser(this._tokens);

  final List<_Token> _tokens;
  var _at = 0;

  _Token get _peek => _tokens[_at];
  _Token _next() => _tokens[_at++];

  bool _op(String text) {
    if (_peek.type == _T.op && _peek.text == text) {
      _at++;
      return true;
    }
    return false;
  }

  void _expect(_T type, String what) {
    if (_next().type != type) throw BaseUnsupported('нет «$what»');
  }

  _Node parse() {
    final node = _or();
    if (_peek.type != _T.end) throw BaseUnsupported('лишнее «${_peek.text}»');
    return node;
  }

  _Node _or() {
    var left = _and();
    while (_op('||')) {
      left = _Binary('||', left, _and());
    }
    return left;
  }

  _Node _and() {
    var left = _equality();
    while (_op('&&')) {
      left = _Binary('&&', left, _equality());
    }
    return left;
  }

  _Node _equality() {
    var left = _comparison();
    while (true) {
      if (_op('==')) {
        left = _Binary('==', left, _comparison());
      } else if (_op('!=')) {
        left = _Binary('!=', left, _comparison());
      } else {
        return left;
      }
    }
  }

  _Node _comparison() {
    var left = _additive();
    while (true) {
      final op = ['>=', '<=', '>', '<'].where(_op).firstOrNull;
      if (op == null) return left;
      left = _Binary(op, left, _additive());
    }
  }

  _Node _additive() {
    var left = _multiplicative();
    while (true) {
      final op = ['+', '-'].where(_op).firstOrNull;
      if (op == null) return left;
      left = _Binary(op, left, _multiplicative());
    }
  }

  _Node _multiplicative() {
    var left = _unary();
    while (true) {
      final op = ['*', '/', '%'].where(_op).firstOrNull;
      if (op == null) return left;
      left = _Binary(op, left, _unary());
    }
  }

  _Node _unary() {
    if (_op('!')) return _Unary('!', _unary());
    if (_op('-')) return _Unary('-', _unary());
    return _postfix(_primary());
  }

  _Node _primary() {
    final token = _next();
    switch (token.type) {
      case _T.number || _T.string || _T.regex:
        return _Lit(token.value);
      case _T.lparen:
        final node = _or();
        _expect(_T.rparen, ')');
        return node;
      case _T.lbracket:
        return _ListLit(_list(_T.rbracket));
      case _T.ident:
        if (_peek.type == _T.lparen) {
          _next();
          return _Call(token.text, _list(_T.rparen));
        }
        return _Name(token.text);
      default:
        throw BaseUnsupported('«${token.text}»');
    }
  }

  /// Значения через запятую до [close]; открывающая скобка уже прочитана.
  List<_Node> _list(_T close) {
    final items = <_Node>[];
    if (_peek.type == close) {
      _next();
      return items;
    }
    while (true) {
      items.add(_or());
      final token = _next();
      if (token.type == close) return items;
      if (token.type != _T.comma) throw const BaseUnsupported('список без «,»');
    }
  }

  _Node _postfix(_Node node) {
    while (true) {
      if (_peek.type == _T.dot) {
        _next();
        final name = _next();
        if (name.type != _T.ident) throw const BaseUnsupported('точка без имени');
        if (_peek.type == _T.lparen) {
          _next();
          node = _MethodCall(node, name.text, _list(_T.rparen));
        } else {
          node = _Member(node, name.text);
        }
      } else if (_peek.type == _T.lbracket) {
        _next();
        final index = _or();
        _expect(_T.rbracket, ']');
        node = _Index(node, index);
      } else {
        return node;
      }
    }
  }
}

// ── значения ────────────────────────────────────────────────────────────────

/// Объект `file` в выражении.
class _File {
  const _File(this.note);
  final BaseNote note;
}

class _FormulaRoot {
  const _FormulaRoot();
}

class _Regex {
  const _Regex(this.pattern, {required this.global});
  final RegExp pattern;
  final bool global;
}

/// Счёт выражений для одной заметки. [vars] — value, index, acc внутри лямбды и values у итогов.
class _Eval {
  _Eval(this.note, this.base, this.now, {Set<String>? formulaDepth}) : _formulaDepth = formulaDepth ?? {};

  final BaseNote? note;
  final ObsidianBase base;
  final DateTime now;
  final Set<String> _formulaDepth;

  Object? run(String source, {Map<String, Object?> vars = const {}}) => _eval(_parse(source), vars);

  Object? _eval(_Node node, Map<String, Object?> vars) {
    switch (node) {
      case _Lit(:final value):
        return value;
      case _ListLit(:final items):
        return [for (final item in items) _eval(item, vars)];
      case _Name(:final name):
        if (vars.containsKey(name)) return vars[name];
        return switch (name) {
          'true' => true,
          'false' => false,
          'null' => null,
          'file' => note == null ? null : _File(note!),
          'note' => note?.properties,
          'formula' => const _FormulaRoot(),
          'this' => null,
          _ => _plain(note?.properties[name]),
        };
      case _Unary(:final op, :final operand):
        final value = _eval(operand, vars);
        if (op == '!') return !_truthy(value);
        return value is num ? -value : null;
      case _Binary(:final op, :final left, :final right):
        if (op == '&&') return _truthy(_eval(left, vars)) && _truthy(_eval(right, vars));
        if (op == '||') return _truthy(_eval(left, vars)) || _truthy(_eval(right, vars));
        return _binary(op, _eval(left, vars), _eval(right, vars));
      case _Member(:final target, :final name):
        return _field(_eval(target, vars), name);
      case _Index(:final target, :final index):
        final value = _eval(target, vars);
        final key = _eval(index, vars);
        if (value is List && key is num) return key >= 0 && key < value.length ? value[key.toInt()] : null;
        if (value is Map) return _plain(value['$key']);
        if (value is String && key is num) return key >= 0 && key < value.length ? value[key.toInt()] : null;
        if (value is _File) return _field(value, '$key');
        return null;
      case _Call(:final name, :final args):
        // if считает только нужную ветку
        if (name == 'if') {
          return _truthy(args.isEmpty ? null : _eval(args[0], vars))
              ? (args.length > 1 ? _eval(args[1], vars) : null)
              : (args.length > 2 ? _eval(args[2], vars) : null);
        }
        return _call(name, [for (final arg in args) _eval(arg, vars)]);
      case _MethodCall(:final target, :final name, :final args):
        final value = _eval(target, vars);
        if (value is List && const {'filter', 'map', 'reduce'}.contains(name)) return _lambda(value, name, args, vars);
        return _method(value, name, [for (final arg in args) _eval(arg, vars)]);
    }
  }

  Object? _lambda(List<Object?> list, String name, List<_Node> args, Map<String, Object?> vars) {
    if (args.isEmpty) throw BaseUnsupported('$name() без выражения');
    final body = args.first;
    switch (name) {
      case 'filter':
        return [
          for (final (index, value) in list.indexed)
            if (_truthy(_eval(body, {...vars, 'value': value, 'index': index}))) value,
        ];
      case 'map':
        return [for (final (index, value) in list.indexed) _eval(body, {...vars, 'value': value, 'index': index})];
      default:
        var acc = args.length > 1 ? _eval(args[1], vars) : null;
        for (final (index, value) in list.indexed) {
          acc = _eval(body, {...vars, 'value': value, 'index': index, 'acc': acc});
        }
        return acc;
    }
  }

  Object? _binary(String op, Object? left, Object? right) {
    switch (op) {
      case '==':
        return _equals(left, right);
      case '!=':
        return !_equals(left, right);
      case '>' || '<' || '>=' || '<=':
        final (a, b) = _align(left, right);
        if (a == null || b == null) return false;
        final order = _compare(a, b);
        return switch (op) { '>=' => order >= 0, '<=' => order <= 0, '>' => order > 0, _ => order < 0 };
      case '+':
        return switch ((left, right)) {
          (num a, num b) => a + b,
          (DateTime a, _) => a.add(_duration(right)),
          (Duration a, Duration b) => a + b,
          (String a, _) => '$a${_text(right)}',
          (_, String b) when left != null => '${_text(left)}$b',
          (List a, List b) => [...a, ...b],
          _ => null,
        };
      case '-':
        return switch ((left, right)) {
          (num a, num b) => a - b,
          (DateTime a, DateTime b) => a.difference(b),
          (DateTime a, String b) when _date(b) != null && _durationOrNull(b) == null => a.difference(_date(b)!),
          (DateTime a, _) => a.subtract(_duration(right)),
          (Duration a, Duration b) => a - b,
          _ => null,
        };
      case '*':
        return switch ((left, right)) {
          (num a, num b) => a * b,
          (Duration a, num b) => a * b,
          _ => null,
        };
      case '/':
        return left is num && right is num && right != 0 ? _whole(left / right) : null;
      case '%':
        return left is num && right is num && right != 0 ? left % right : null;
    }
    return null;
  }

  Object? _field(Object? target, String name) {
    if (target is _File) {
      final file = target.note;
      return switch (name) {
        'name' || 'basename' => file.basename,
        'fullname' => file.name,
        'path' => file.path,
        'folder' => file.folder,
        'ext' => file.ext,
        'ctime' => file.created,
        'mtime' => file.modified,
        'tags' => file.tags,
        'links' => file.links,
        'properties' => file.properties,
        'size' => file.size,
        'file' => target,
        _ => throw BaseUnsupported('file.$name'),
      };
    }
    if (target is _FormulaRoot) {
      final formula = base.formulas[name];
      // формула, ссылающаяся на себя по кругу, даёт пусто, а не зависание
      if (formula == null || _formulaDepth.contains(name)) return null;
      return _Eval(note, base, now, formulaDepth: {..._formulaDepth, name}).run(formula);
    }
    if (target is Map) return _plain(target[name]);
    if (target is DateTime) {
      return switch (name) {
        'year' => target.year,
        'month' => target.month,
        'day' => target.day,
        'hour' => target.hour,
        'minute' => target.minute,
        'second' => target.second,
        'millisecond' => target.millisecond,
        _ => throw BaseUnsupported('дата.$name'),
      };
    }
    if (target is Duration) {
      return switch (name) {
        'days' => target.inDays,
        'hours' => target.inHours,
        'minutes' => target.inMinutes,
        'seconds' => target.inSeconds,
        'milliseconds' => target.inMilliseconds,
        'weeks' => target.inDays ~/ 7,
        _ => throw BaseUnsupported('длительность.$name'),
      };
    }
    if (name == 'length') {
      if (target is String) return target.length;
      if (target is List) return target.length;
    }
    if (target == null) return null;
    throw BaseUnsupported('поле $name');
  }

  Object? _method(Object? target, String name, List<Object?> args) {
    final first = args.firstOrNull;
    // общие для всех значений
    switch (name) {
      case 'isEmpty':
        return switch (target) {
          null => true,
          String() => target.isEmpty,
          List() => target.isEmpty,
          Map() => target.isEmpty,
          _ => false,
        };
      case 'isTruthy':
        return _truthy(target);
      case 'toString':
        return _text(target);
      case 'isType':
        return _isType(target, '$first');
    }
    if (target is _File) {
      final file = target.note;
      switch (name) {
        case 'inFolder':
          final folder = '${first ?? ''}'.replaceAll(RegExp(r'^/+|/+$'), '');
          return folder.isEmpty || file.folder == folder || file.folder.startsWith('$folder/');
        case 'hasTag':
          return args.any((tag) {
            final want = '$tag'.replaceFirst('#', '').toLowerCase();
            return file.tags.any((one) => one.toLowerCase() == want || one.toLowerCase().startsWith('$want/'));
          });
        case 'hasLink':
          final want = (first is _File ? first.note.basename : '${first ?? ''}'.replaceAll(RegExp(r'^\[\[|\]\]$|\.md$'), '')).split('/').last.toLowerCase();
          return file.links.any((link) => link.toLowerCase() == want);
        case 'hasProperty':
          return file.properties.containsKey('$first');
        case 'asLink':
          return file.basename;
      }
      throw BaseUnsupported('file.$name()');
    }
    if (target is _Regex && name == 'matches') return target.pattern.hasMatch('${first ?? ''}');
    if (target == null) return null;
    if (target is String) {
      switch (name) {
        case 'contains':
          return target.contains('${first ?? ''}');
        case 'containsAll':
          return args.every((one) => target.contains('$one'));
        case 'containsAny':
          return args.any((one) => target.contains('$one'));
        case 'startsWith':
          return target.startsWith('${first ?? ''}');
        case 'endsWith':
          return target.endsWith('${first ?? ''}');
        case 'lower':
          return target.toLowerCase();
        case 'upper':
          return target.toUpperCase();
        case 'trim':
          return target.trim();
        case 'title':
          return target.replaceAllMapped(RegExp(r'(^|\s)(\S)', unicode: true), (match) => '${match[1]}${match[2]!.toUpperCase()}');
        case 'reverse':
          return String.fromCharCodes(target.runes.toList().reversed);
        case 'repeat':
          return first is num && first > 0 ? target * first.toInt() : '';
        case 'slice':
          return String.fromCharCodes(_slice(target.runes.toList(), args));
        case 'split':
          final parts = first is _Regex ? target.split(first.pattern) : target.split('${first ?? ''}');
          return args.length > 1 && args[1] is num ? parts.take((args[1] as num).toInt()).toList() : parts;
        case 'replace':
          final replacement = '${args.elementAtOrNull(1) ?? ''}';
          if (first is _Regex) {
            String fill(Match match) => replacement.replaceAllMapped(RegExp(r'\$(\d)'), (group) => match[int.parse(group[1]!)] ?? '');
            return first.global ? target.replaceAllMapped(first.pattern, fill) : target.replaceFirstMapped(first.pattern, fill);
          }
          return target.replaceAll('${first ?? ''}', replacement);
      }
    }
    if (target is num) {
      switch (name) {
        case 'abs':
          return target.abs();
        case 'ceil':
          return target.ceil();
        case 'floor':
          return target.floor();
        case 'round':
          if (first is num && first > 0) {
            final scale = _pow10(first.toInt());
            return (target * scale).round() / scale;
          }
          return target.round();
        case 'toFixed':
          return target.toStringAsFixed(first is num ? first.toInt() : 0);
      }
    }
    if (target is DateTime) {
      switch (name) {
        case 'date':
          return DateTime(target.year, target.month, target.day);
        case 'time':
          return formatMoment(target, 'HH:mm:ss');
        case 'format':
          return formatMoment(target, '${first ?? 'YYYY-MM-DD'}');
        case 'relative':
          return _relative(target, now);
      }
    }
    if (target is List) {
      switch (name) {
        case 'contains':
          return target.any((one) => _equals(one, first));
        case 'containsAny':
          return args.any((want) => target.any((one) => _equals(one, want)));
        case 'containsAll':
          return args.every((want) => target.any((one) => _equals(one, want)));
        case 'join':
          return target.map(_text).join('${first ?? ', '}');
        case 'flat':
          return [for (final one in target) ...(one is List ? one : [one])];
        case 'reverse':
          return target.reversed.toList();
        case 'slice':
          return _slice(target, args);
        case 'sort':
          return _stableSort(target, _compare);
        case 'unique':
          final seen = <Object?>[];
          for (final one in target) {
            if (!seen.any((other) => _equals(other, one))) seen.add(one);
          }
          return seen;
        // для итогов: values.mean(), values.sum() и соседи
        case 'sum' || 'mean' || 'average' || 'min' || 'max' || 'median':
          return summarizeBase(switch (name) { 'mean' => 'Average', 'average' => 'Average', _ => name[0].toUpperCase() + name.substring(1) }, target);
      }
    }
    if (target is Map) {
      switch (name) {
        case 'keys':
          return target.keys.map((key) => '$key').toList();
        case 'values':
          return target.values.map(_plain).toList();
      }
    }
    throw BaseUnsupported('$name()');
  }

  Object? _call(String name, List<Object?> args) {
    final first = args.firstOrNull;
    switch (name) {
      case 'now':
        return now;
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case 'date':
        return _date(first);
      case 'duration':
        return first is Duration ? first : _duration(first);
      case 'number':
        return switch (first) {
          num() => first,
          bool() => first ? 1 : 0,
          DateTime() => first.millisecondsSinceEpoch,
          Duration() => first.inMilliseconds,
          _ => num.tryParse('${first ?? ''}'.trim()),
        };
      case 'list':
        return first is List ? first : [first];
      case 'max' || 'min':
        final numbers = [for (final one in args) if (one is num) one];
        if (numbers.isEmpty) return null;
        return numbers.reduce((a, b) => (name == 'max' ? a >= b : a <= b) ? a : b);
      case 'link':
        return args.length > 1 && args[1] != null ? _text(args[1]) : _text(first);
      case 'file':
        return first is _File ? first : null;
      case 'image' || 'icon' || 'html' || 'escapeHTML':
        return _text(first);
      case 'random':
        return 0.5;
    }
    throw BaseUnsupported('$name()');
  }
}

List<T> _slice<T>(List<T> list, List<Object?> args) {
  int at(Object? value, int fallback) {
    if (value is! num) return fallback;
    final index = value.toInt();
    return (index < 0 ? list.length + index : index).clamp(0, list.length);
  }

  final start = at(args.firstOrNull, 0);
  final end = at(args.elementAtOrNull(1), list.length);
  return end <= start ? <T>[] : list.sublist(start, end);
}

num _pow10(int digits) {
  var result = 1;
  for (var i = 0; i < digits; i++) {
    result *= 10;
  }
  return result;
}

/// 17 / 2 = 8.5, а 8 / 2 — ровно 4, без «.0».
num _whole(num value) => value is double && value == value.truncateToDouble() && value.abs() < 1e15 ? value.toInt() : value;

bool _isType(Object? value, String type) => switch (type) {
  'null' => value == null,
  'string' => value is String,
  'number' => value is num,
  'boolean' => value is bool,
  'date' => value is DateTime,
  'list' => value is List,
  'object' => value is Map,
  'file' => value is _File,
  'duration' => value is Duration,
  _ => false,
};

String _text(Object? value) => switch (value) {
  null => '',
  _File() => value.note.basename,
  DateTime() => value.hour == 0 && value.minute == 0 && value.second == 0 ? formatMoment(value, 'YYYY-MM-DD') : formatMoment(value, 'YYYY-MM-DD HH:mm'),
  List() => value.map(_text).join(', '),
  num() => '${_whole(value)}',
  _ => '$value',
};

String _relative(DateTime date, DateTime now) {
  final difference = now.difference(date);
  final past = !difference.isNegative;
  final span = difference.abs();
  final (count, unit) = span.inDays >= 365
      ? (span.inDays ~/ 365, 'year')
      : span.inDays >= 30
      ? (span.inDays ~/ 30, 'month')
      : span.inDays >= 1
      ? (span.inDays, 'day')
      : span.inHours >= 1
      ? (span.inHours, 'hour')
      : span.inMinutes >= 1
      ? (span.inMinutes, 'minute')
      : (0, 'now');
  if (unit == 'now') return 'now';
  final words = '$count $unit${count == 1 ? '' : 's'}';
  return past ? '$words ago' : 'in $words';
}

/// Дата по образцу Moment.js: YYYY, MM, DD, HH, mm, ss, MMMM, ddd и текст в [скобках].
String formatMoment(DateTime date, String pattern) {
  const tokens = ['YYYY', 'YY', 'MMMM', 'MMM', 'MM', 'M', 'DDDD', 'DD', 'Do', 'D', 'dddd', 'ddd', 'HH', 'H', 'hh', 'h', 'mm', 'm', 'ss', 's', 'A', 'a', 'X', 'x'];
  String two(int value) => value.toString().padLeft(2, '0');
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final buffer = StringBuffer();
  var i = 0;
  while (i < pattern.length) {
    if (pattern[i] == '[') {
      final end = pattern.indexOf(']', i);
      if (end > i) {
        buffer.write(pattern.substring(i + 1, end));
        i = end + 1;
        continue;
      }
    }
    final token = tokens.where((one) => pattern.startsWith(one, i)).firstOrNull;
    if (token == null) {
      buffer.write(pattern[i]);
      i++;
      continue;
    }
    buffer.write(switch (token) {
      'YYYY' => date.year.toString().padLeft(4, '0'),
      'YY' => two(date.year % 100),
      'MMMM' => DateFormat.MMMM(Intl.getCurrentLocale()).format(date),
      'MMM' => DateFormat.MMM(Intl.getCurrentLocale()).format(date),
      'MM' => two(date.month),
      'M' => '${date.month}',
      'DDDD' => date.difference(DateTime(date.year)).inDays.toString().padLeft(3, '0'),
      'DD' => two(date.day),
      'Do' => '${date.day}',
      'D' => '${date.day}',
      'dddd' => DateFormat.EEEE(Intl.getCurrentLocale()).format(date),
      'ddd' => DateFormat.E(Intl.getCurrentLocale()).format(date),
      'HH' => two(date.hour),
      'H' => '${date.hour}',
      'hh' => two(hour12),
      'h' => '$hour12',
      'mm' => two(date.minute),
      'm' => '${date.minute}',
      'ss' => two(date.second),
      's' => '${date.second}',
      'A' => date.hour < 12 ? 'AM' : 'PM',
      'a' => date.hour < 12 ? 'am' : 'pm',
      'X' => '${date.millisecondsSinceEpoch ~/ 1000}',
      _ => '${date.millisecondsSinceEpoch}',
    });
    i += token.length;
  }
  return buffer.toString();
}

/// YAML-списки и словари — обычными.
Object? _plain(Object? value) {
  if (value is YamlList) return [for (final one in value) _plain(one)];
  if (value is YamlMap) return {for (final MapEntry(:key, :value) in value.entries) '$key': _plain(value)};
  return value;
}

DateTime? _date(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value.trim());
  return null;
}

/// Для сравнения: дата строкой рядом с датой становится датой, длительность строкой — длительностью.
(Object?, Object?) _align(Object? a, Object? b) {
  if (a is DateTime && b is String) return (a, _date(b));
  if (b is DateTime && a is String) return (_date(a), b);
  if (a is Duration && b is String) return (a, _durationOrNull(b));
  if (b is Duration && a is String) return (_durationOrNull(a), b);
  if (a is Duration && b is num) return (a.inMilliseconds, b);
  if (b is Duration && a is num) return (a, b.inMilliseconds);
  return (a, b);
}

bool _equals(Object? a, Object? b) {
  final (x, y) = _align(a, b);
  if (x is num && y is num) return x == y;
  if (x is String && y is String) return x == y;
  if (x is List && y is List) return x.length == y.length && [for (var i = 0; i < x.length; i++) _equals(x[i], y[i])].every((same) => same);
  if (x is List && y is! List) return x.any((one) => _equals(one, y));
  return x == y;
}

Duration? _durationOrNull(Object? value) {
  try {
    return _duration(value);
  } on BaseUnsupported {
    return null;
  }
}

/// «7 days», «1 week», «2d», «3M», «1 year» — длительность.
Duration _duration(Object? value) {
  if (value is Duration) return value;
  if (value is num) return Duration(milliseconds: value.round());
  final match = RegExp(r'^\s*(-?\d+)\s*([a-zA-Z]+)\s*$').firstMatch('$value');
  if (match == null) throw BaseUnsupported('длительность «$value»');
  final count = int.parse(match[1]!);
  final raw = match[2]!;
  // «M» — месяц, «m» — минута, как у Moment
  if (raw == 'M') return Duration(days: 30 * count);
  return switch (raw.toLowerCase()) {
    'ms' || 'millisecond' || 'milliseconds' => Duration(milliseconds: count),
    's' || 'sec' || 'secs' || 'second' || 'seconds' => Duration(seconds: count),
    'm' || 'min' || 'mins' || 'minute' || 'minutes' => Duration(minutes: count),
    'h' || 'hr' || 'hrs' || 'hour' || 'hours' => Duration(hours: count),
    'd' || 'day' || 'days' => Duration(days: count),
    'w' || 'week' || 'weeks' => Duration(days: 7 * count),
    'month' || 'months' => Duration(days: 30 * count),
    'y' || 'year' || 'years' => Duration(days: 365 * count),
    _ => throw BaseUnsupported('единица «$raw»'),
  };
}
