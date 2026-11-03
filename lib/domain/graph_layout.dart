import 'dart:math';
import 'dart:typed_data';

/// Длина связи, к которой стремится раскладка: под ней помещаются подписи двух соседей.
const graphEdgeLength = 120.0;

/// Силовая раскладка графа: все точки отталкиваются, связанные притягиваются,
/// шаг с каждым кругом короче. Отталкивание считается только между соседями
/// по сетке — дальние точки друг на друга почти не влияют, а 500 точек
/// иначе считались бы секунды. Одинаковый [seed] даёт одинаковую картинку.
Map<String, (double, double)> layoutGraph(List<String> nodes, List<(String, String)> edges, {int iterations = 300, int seed = 1}) {
  final count = nodes.length;
  if (count == 0) return const {};
  if (count == 1) return {nodes.single: (0.0, 0.0)};

  final index = {for (final (position, node) in nodes.indexed) node: position};
  final links = [
    for (final (a, b) in edges)
      if (index[a] case final from? when index[b] != null && a != b) (from, index[b]!),
  ];

  const k = graphEdgeLength;
  final side = sqrt(count) * k;
  final random = Random(seed);
  final x = Float64List(count);
  final y = Float64List(count);
  for (var node = 0; node < count; node++) {
    x[node] = (random.nextDouble() - 0.5) * side;
    y[node] = (random.nextDouble() - 0.5) * side;
  }
  final dx = Float64List(count);
  final dy = Float64List(count);
  const cell = k * 2;
  const reach = cell * cell;

  for (var round = 0; round < iterations; round++) {
    final temperature = side / 8 * (1 - round / iterations) + 0.5;
    dx.fillRange(0, count, 0);
    dy.fillRange(0, count, 0);

    // сетка: соседей ищем только в своей клетке и восьми вокруг
    final grid = <int, List<int>>{};
    int key(int column, int row) => column * 100003 + row;
    for (var node = 0; node < count; node++) {
      grid.putIfAbsent(key((x[node] / cell).floor(), (y[node] / cell).floor()), () => []).add(node);
    }
    for (var node = 0; node < count; node++) {
      final column = (x[node] / cell).floor();
      final row = (y[node] / cell).floor();
      for (var shiftX = -1; shiftX <= 1; shiftX++) {
        for (var shiftY = -1; shiftY <= 1; shiftY++) {
          final near = grid[key(column + shiftX, row + shiftY)];
          if (near == null) continue;
          for (final other in near) {
            if (other == node) continue;
            var deltaX = x[node] - x[other];
            var deltaY = y[node] - y[other];
            var squared = deltaX * deltaX + deltaY * deltaY;
            if (squared > reach) continue;
            if (squared < 0.0001) {
              // точки совпали: разводим в случайную сторону
              deltaX = random.nextDouble() - 0.5;
              deltaY = random.nextDouble() - 0.5;
              squared = deltaX * deltaX + deltaY * deltaY;
            }
            // сила k²/d по направлению delta/d
            final push = k * k / squared;
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
      final pull = length / k;
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
  return {for (var node = 0; node < count; node++) nodes[node]: (x[node], y[node])};
}
