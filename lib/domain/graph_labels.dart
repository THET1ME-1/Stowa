/// Подпись узла графа на экране: середина по горизонтали, верх, ширина в точках экрана
/// и сколько у узла связей.
typedef GraphLabel = ({String id, double x, double y, double width, int degree});

/// Высота строки подписи на экране.
const graphLabelHeight = 16.0;

/// Какие подписи графа рисовать, чтобы их можно было прочесть.
///
/// На графе всей базы подписи двух тысяч узлов лежат друг на друге сплошным пятном.
/// Берём узлы от самых связных: подпись остаётся, если не наезжает на уже взятые, и всего
/// их не больше [limit]. Издалека видны имена главных узлов, вблизи — всех, кто на экране.
Set<String> pickGraphLabels(List<GraphLabel> labels, {int limit = 160}) {
  if (labels.isEmpty) return const {};
  // самые связные первыми; при равенстве — как в списке
  final order = List.generate(labels.length, (index) => index)
    ..sort((a, b) {
      final byDegree = labels[b].degree.compareTo(labels[a].degree);
      return byDegree != 0 ? byDegree : a.compareTo(b);
    });
  final shown = <String>{};
  // занятые места по строкам сетки: соседей ищем только в своей строке и двух рядом
  final rows = <int, List<(double, double, double)>>{};
  for (final index in order) {
    if (shown.length >= limit) break;
    final label = labels[index];
    final left = label.x - label.width / 2;
    final right = label.x + label.width / 2;
    final row = (label.y / graphLabelHeight).floor();
    var free = true;
    for (var near = row - 1; near <= row + 1 && free; near++) {
      for (final (takenLeft, takenRight, takenTop) in rows[near] ?? const <(double, double, double)>[]) {
        if (left < takenRight && takenLeft < right && (label.y - takenTop).abs() < graphLabelHeight) {
          free = false;
          break;
        }
      }
    }
    if (!free) continue;
    (rows[row] ??= []).add((left, right, label.y));
    shown.add(label.id);
  }
  return shown;
}
