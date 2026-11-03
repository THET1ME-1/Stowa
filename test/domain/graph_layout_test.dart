import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/graph_layout.dart';

double distance((double, double) a, (double, double) b) => sqrt(pow(a.$1 - b.$1, 2) + pow(a.$2 - b.$2, 2));

void main() {
  final nodes = [for (var index = 0; index < 40; index++) 'n$index'];
  // четыре кучки по десять, внутри кучки цепочка и пара поперечин
  final edges = [
    for (var group = 0; group < 4; group++)
      for (var index = 0; index < 9; index++) ('n${group * 10 + index}', 'n${group * 10 + index + 1}'),
    for (var group = 0; group < 4; group++) ('n${group * 10}', 'n${group * 10 + 5}'),
  ];

  test('при одном seed раскладка та же', () {
    final first = layoutGraph(nodes, edges, seed: 7);
    final second = layoutGraph(nodes, edges, seed: 7);
    for (final node in nodes) {
      expect(first[node], second[node]);
    }
  });

  test('связанные точки в среднем ближе несвязанных', () {
    final places = layoutGraph(nodes, edges);
    final linked = {for (final (a, b) in edges) '$a|$b', for (final (a, b) in edges) '$b|$a'};
    var linkedSum = 0.0;
    var linkedCount = 0;
    var otherSum = 0.0;
    var otherCount = 0;
    for (final a in nodes) {
      for (final b in nodes) {
        if (a == b) continue;
        final gap = distance(places[a]!, places[b]!);
        if (linked.contains('$a|$b')) {
          linkedSum += gap;
          linkedCount++;
        } else {
          otherSum += gap;
          otherCount++;
        }
      }
    }
    expect(linkedSum / linkedCount, lessThan(otherSum / otherCount * 0.5));
  });

  test('точки не слипаются в одну', () {
    final places = layoutGraph(nodes, edges);
    for (final a in nodes) {
      for (final b in nodes) {
        if (a != b) expect(distance(places[a]!, places[b]!), greaterThan(4));
      }
    }
  });

  test('500 точек раскладываются меньше чем за 300 мс', () {
    final many = [for (var index = 0; index < 500; index++) 'm$index'];
    final random = Random(3);
    final links = [for (var index = 0; index < 700; index++) ('m${random.nextInt(500)}', 'm${random.nextInt(500)}')];
    layoutGraph(many, links); // прогрев
    final watch = Stopwatch()..start();
    final places = layoutGraph(many, links);
    watch.stop();
    expect(places, hasLength(500));
    expect(watch.elapsedMilliseconds, lessThan(300));
  });

  test('пустой граф и одна точка', () {
    expect(layoutGraph(const [], const []), isEmpty);
    expect(layoutGraph(const ['one'], const []), {'one': (0.0, 0.0)});
  });
}
