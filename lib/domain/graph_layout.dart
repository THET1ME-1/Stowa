import 'dart:math';
import 'dart:typed_data';

/// Длина связи, к которой стремится раскладка: под ней помещаются подписи двух соседей.
const graphEdgeLength = 120.0;

/// Силовая раскладка графа: все точки отталкиваются, связанные притягиваются,
/// шаг с каждым кругом короче. Отталкивание считается только между соседями
/// по сетке — дальние точки друг на друга почти не влияют, а 500 точек
/// иначе считались бы секунды. Одинаковый [seed] даёт одинаковую картинку.
Map<String, (double, double)> layoutGraph(List<String> nodes, List<(String, String)> edges, {int iterations = 300, int seed = 1}) {
  if (nodes.isEmpty) return const {};
  if (nodes.length == 1) return {nodes.single: (0.0, 0.0)};
  final run = _Run(nodes, edges, iterations: iterations, seed: seed);
  for (var round = 0; round < iterations; round++) {
    run.step(round);
  }
  return run.places();
}

/// [layoutGraph] с передышками между кругами: та же картинка, но поток не занят дольше
/// кадра подряд. Для браузера: изолятов там нет, и раскладка идёт на потоке экрана.
Future<Map<String, (double, double)>> layoutGraphPaced(List<String> nodes, List<(String, String)> edges, {int iterations = 300, int seed = 1}) async {
  if (nodes.isEmpty) return const {};
  if (nodes.length == 1) return {nodes.single: (0.0, 0.0)};
  final run = _Run(nodes, edges, iterations: iterations, seed: seed);
  final busy = Stopwatch()..start();
  for (var round = 0; round < iterations; round++) {
    run.step(round);
    if (busy.elapsedMilliseconds <= 8) continue;
    await Future<void>.delayed(Duration.zero);
    busy.reset();
  }
  return run.places();
}

/// Одна раскладка: места точек и круг за кругом их сдвиги.
class _Run {
  _Run(this.nodes, List<(String, String)> edges, {required this.iterations, required int seed})
    : count = nodes.length,
      random = Random(seed),
      x = Float64List(nodes.length),
      y = Float64List(nodes.length),
      dx = Float64List(nodes.length),
      dy = Float64List(nodes.length) {
    final index = {for (final (position, node) in nodes.indexed) node: position};
    links = [
      for (final (a, b) in edges)
        if (index[a] case final from? when index[b] != null && a != b) (from, index[b]!),
    ];
    side = sqrt(count) * _k;
    for (var node = 0; node < count; node++) {
      x[node] = (random.nextDouble() - 0.5) * side;
      y[node] = (random.nextDouble() - 0.5) * side;
    }
  }

  static const _k = graphEdgeLength;
  static const _cell = _k * 2;
  static const _reach = _cell * _cell;

  final List<String> nodes;
  final int iterations;
  final int count;
  final Random random;
  final Float64List x;
  final Float64List y;
  final Float64List dx;
  final Float64List dy;
  late final List<(int, int)> links;
  late final double side;

  static int _key(int column, int row) => column * 100003 + row;

  void step(int round) {
    final temperature = side / 8 * (1 - round / iterations) + 0.5;
    dx.fillRange(0, count, 0);
    dy.fillRange(0, count, 0);

    // сетка: соседей ищем только в своей клетке и восьми вокруг
    final grid = <int, List<int>>{};
    for (var node = 0; node < count; node++) {
      grid.putIfAbsent(_key((x[node] / _cell).floor(), (y[node] / _cell).floor()), () => []).add(node);
    }
    for (var node = 0; node < count; node++) {
      final column = (x[node] / _cell).floor();
      final row = (y[node] / _cell).floor();
      for (var shiftX = -1; shiftX <= 1; shiftX++) {
        for (var shiftY = -1; shiftY <= 1; shiftY++) {
          final near = grid[_key(column + shiftX, row + shiftY)];
          if (near == null) continue;
          for (final other in near) {
            if (other == node) continue;
            var deltaX = x[node] - x[other];
            var deltaY = y[node] - y[other];
            var squared = deltaX * deltaX + deltaY * deltaY;
            if (squared > _reach) continue;
            if (squared < 0.0001) {
              // точки совпали: разводим в случайную сторону
              deltaX = random.nextDouble() - 0.5;
              deltaY = random.nextDouble() - 0.5;
              squared = deltaX * deltaX + deltaY * deltaY;
            }
            // сила k²/d по направлению delta/d
            final push = _k * _k / squared;
            dx[node] += deltaX * push;
            dy[node] += deltaY * push;
          }
        }
      }
    }
    for (final (from, to) in links) {
      final deltaX = x[from] - x[to];
      final deltaY = y[from] - y[to];
      final length = sqrt(deltaX * deltaX + deltaY * deltaY) + 0.01;
      // сила d²/k по направлению delta/d
      final pull = length / _k;
      dx[from] -= deltaX * pull;
      dy[from] -= deltaY * pull;
      dx[to] += deltaX * pull;
      dy[to] += deltaY * pull;
    }
    for (var node = 0; node < count; node++) {
      // лёгкое притяжение к центру держит отдельные кучки рядом
      dx[node] -= x[node] * 0.02;
      dy[node] -= y[node] * 0.02;
      final length = sqrt(dx[node] * dx[node] + dy[node] * dy[node]);
      if (length < 0.0001) continue;
      final step = min(length, temperature);
      x[node] += dx[node] / length * step;
      y[node] += dy[node] / length * step;
    }
  }

  Map<String, (double, double)> places() => {for (var node = 0; node < count; node++) nodes[node]: (x[node], y[node])};
}
