/// Склейка правок с двух устройств по трём версиям: общая (последняя
/// синхронизированная), своя и пришедшая. Конфликтных копий нет: где обе
/// стороны правили одно место, остаётся свежая, а вторая версия целиком
/// уходит в историю заметки.
library;

import 'dart:convert';
import 'dart:typed_data';

class MergeResult {
  const MergeResult(this.text, this.loser);

  final String text;

  /// Проигравшая версия целиком, если одно место правили обе стороны.
  final String? loser;
}

/// Склеить текст заметки построчно. [oursNewer] — своя правка свежее пришедшей.
MergeResult mergeText(String base, String ours, String theirs, {required bool oursNewer}) {
  if (ours == theirs) return MergeResult(ours, null);
  if (ours == base) return MergeResult(theirs, null);
  if (theirs == base) return MergeResult(ours, null);
  final a = ours.split('\n');
  final b = theirs.split('\n');
  if (base.isEmpty) return MergeResult(_union(a, b).join('\n'), null);

  final o = base.split('\n');
  final toA = _match(o, a);
  final toB = _match(o, b);
  final out = <String>[];
  var conflict = false;
  var i = 0, x = 0, y = 0;
  while (true) {
    // устойчивая строка: общая на месте у обеих сторон
    if (i < o.length && toA[i] == x && toB[i] == y) {
      out.add(o[i]);
      i++;
      x++;
      y++;
      continue;
    }
    // следующая строка общей, которая осталась у обеих сторон
    var j = i;
    while (j < o.length && (toA[j] == null || toB[j] == null)) {
      j++;
    }
    final endA = j < o.length ? toA[j]! : a.length;
    final endB = j < o.length ? toB[j]! : b.length;
    final chunkO = o.sublist(i, j);
    final chunkA = a.sublist(x, endA);
    final chunkB = b.sublist(y, endB);
    if (_same(chunkA, chunkO)) {
      out.addAll(chunkB);
    } else if (_same(chunkB, chunkO) || _same(chunkA, chunkB)) {
      out.addAll(chunkA);
    } else {
      conflict = true;
      out.addAll(oursNewer ? chunkA : chunkB);
    }
    if (j >= o.length) break;
    i = j;
    x = endA;
    y = endB;
  }
  return MergeResult(out.join('\n'), conflict ? (oursNewer ? theirs : ours) : null);
}

bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Две версии без общей: общие строки один раз, свои и чужие куски по порядку.
List<String> _union(List<String> a, List<String> b) {
  final toB = _match(a, b);
  final out = <String>[];
  var y = 0;
  for (var x = 0; x < a.length; x++) {
    final at = toB[x];
    if (at == null) {
      out.add(a[x]);
      continue;
    }
    out.addAll(b.sublist(y, at));
    out.add(a[x]);
    y = at + 1;
  }
  out.addAll(b.sublist(y));
  return out;
}

/// Для каждой строки [from] — номер той же строки в [to] или null.
List<int?> _match(List<String> from, List<String> to) {
  final result = List<int?>.filled(from.length, null);
  // общее начало и конец сравниваются сразу, дорогой разбор — только середина
  var start = 0;
  while (start < from.length && start < to.length && from[start] == to[start]) {
    result[start] = start;
    start++;
  }
  var endFrom = from.length, endTo = to.length;
  while (endFrom > start && endTo > start && from[endFrom - 1] == to[endTo - 1]) {
    endFrom--;
    endTo--;
    result[endFrom] = endTo;
  }
  if (endFrom == start || endTo == start) return result;

  final ids = <String, int>{};
  int id(String line) => ids.putIfAbsent(line, () => ids.length);
  final a = Int32List.fromList([for (var i = start; i < endFrom; i++) id(from[i])]);
  final b = Int32List.fromList([for (var i = start; i < endTo; i++) id(to[i])]);
  final pairs = _myers(a, b, 2000) ?? _anchors(a, b);
  for (final (x, y) in pairs) {
    result[start + x] = start + y;
  }
  return result;
}

/// Совпавшие строки по Майерсу; null — правок больше [limit], разбор слишком дорог.
List<(int, int)>? _myers(Int32List a, Int32List b, int limit) {
  final n = a.length, m = b.length, max = n + m, offset = max + 1;
  final v = Int32List(2 * max + 3);
  final trace = <Int32List>[];
  for (var d = 0; d <= max && d <= limit; d++) {
    // состояние до шага d: от k = -(d+1) до d+1
    trace.add(Int32List.fromList(v.sublist(offset - d - 1, offset + d + 2)));
    for (var k = -d; k <= d; k += 2) {
      var x = (k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1])) ? v[offset + k + 1] : v[offset + k - 1] + 1;
      var y = x - k;
      while (x < n && y < m && a[x] == b[y]) {
        x++;
        y++;
      }
      v[offset + k] = x;
      if (x >= n && y >= m) return _back(trace, n, m, d);
    }
  }
  return null;
}

List<(int, int)> _back(List<Int32List> trace, int n, int m, int depth) {
  final pairs = <(int, int)>[];
  var x = n, y = m;
  for (var d = depth; d >= 0; d--) {
    final row = trace[d];
    int at(int k) => row[k + d + 1];
    final k = x - y;
    final prevK = (k == -d || (k != d && at(k - 1) < at(k + 1))) ? k + 1 : k - 1;
    final prevX = d == 0 ? 0 : at(prevK);
    final prevY = d == 0 ? 0 : prevX - prevK;
    while (x > prevX && y > prevY) {
      x--;
      y--;
      pairs.add((x, y));
    }
    x = prevX;
    y = prevY;
  }
  return pairs.reversed.toList();
}

/// Грубое сопоставление для сильно разошедшихся текстов: строки, единственные
/// в обеих версиях, по наибольшей возрастающей цепочке.
List<(int, int)> _anchors(Int32List a, Int32List b) {
  Map<int, int> unique(Int32List lines) {
    final count = <int, int>{}, at = <int, int>{};
    for (var i = 0; i < lines.length; i++) {
      count[lines[i]] = (count[lines[i]] ?? 0) + 1;
      at[lines[i]] = i;
    }
    return {
      for (final e in at.entries)
        if (count[e.key] == 1) e.key: e.value,
    };
  }

  final inB = unique(b);
  final candidates = [
    for (final e in unique(a).entries)
      if (inB.containsKey(e.key)) (e.value, inB[e.key]!),
  ]..sort((p, q) => p.$1.compareTo(q.$1));
  // наибольшая возрастающая по второй координате
  final tails = <int>[], previous = List<int>.filled(candidates.length, -1);
  for (var i = 0; i < candidates.length; i++) {
    var lo = 0, hi = tails.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (candidates[tails[mid]].$2 < candidates[i].$2) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo > 0) previous[i] = tails[lo - 1];
    if (lo == tails.length) {
      tails.add(i);
    } else {
      tails[lo] = i;
    }
  }
  final chain = <(int, int)>[];
  for (var i = tails.isEmpty ? -1 : tails.last; i >= 0; i = previous[i]) {
    chain.add(candidates[i]);
  }
  return chain.reversed.toList();
}

const _pretty = JsonEncoder.withIndent('  ');

/// Склеить служебный JSON вида `{"таблица": [строки]}` по ключу строки (`id`,
/// без него — вся строка). Другой вид склеивается целиком.
String mergeJsonTables(String base, String ours, String theirs, {required bool oursNewer}) {
  if (ours == theirs) return ours;
  if (ours == base) return theirs;
  if (theirs == base) return ours;
  final o = _tables(base.trim().isEmpty ? '{}' : base);
  final a = _tables(ours);
  final b = _tables(theirs);
  if (o == null || a == null || b == null) return oursNewer ? ours : theirs;

  final merged = <String, Object?>{};
  for (final table in {...a.keys, ...b.keys}) {
    final rowsO = _keyed(o[table] ?? const []);
    final rowsA = _keyed(a[table] ?? const []);
    final rowsB = _keyed(b[table] ?? const []);
    final out = <Object?>[];
    for (final key in {...rowsA.keys, ...rowsB.keys}) {
      final row = _pick(rowsO[key], rowsA[key], rowsB[key], oursNewer: oursNewer);
      if (row != null) out.add(row);
    }
    merged[table] = out;
  }
  return _pretty.convert(merged);
}

Map<String, List<Object?>>? _tables(String text) {
  try {
    final json = jsonDecode(text);
    if (json is! Map || json.values.any((v) => v is! List)) return null;
    return {for (final e in json.entries) e.key as String: e.value as List<Object?>};
  } on FormatException {
    return null;
  }
}

Map<String, Object?> _keyed(List<Object?> rows) {
  final out = <String, Object?>{};
  for (final row in rows) {
    // без id ключ — вся строка: у положения на холсте первая колонка — папка, и строки
    // одной папки слиплись бы в одну. Правка такой строки — удаление старой и новая
    final key = row is Map && row['id'] != null ? '${row['id']}' : jsonEncode(row);
    out[key] = row;
  }
  return out;
}

/// Строка по трём версиям; null — строку удалили.
Object? _pick(Object? base, Object? ours, Object? theirs, {required bool oursNewer}) {
  final o = jsonEncode(base), a = jsonEncode(ours), b = jsonEncode(theirs);
  if (a == b) return ours;
  if (a == o) return theirs;
  if (b == o) return ours;
  // правили обе стороны; удаление проигрывает правке
  if (ours == null) return theirs;
  if (theirs == null) return ours;
  return oursNewer ? ours : theirs;
}
