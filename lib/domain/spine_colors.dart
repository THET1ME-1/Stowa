import 'dart:ui';

/// Закреплённая заметка для корешка: цвет её папки (без папки — null) и длина текста.
typedef PinnedSpine = ({Color? color, int length});

/// Корешок у края: цвет и доля высоты подложки.
class Spine {
  const Spine(this.color, this.weight);

  final Color color;
  final double weight;

  @override
  bool operator ==(Object other) => other is Spine && other.color == color && other.weight == weight;

  @override
  int get hashCode => Object.hash(color, weight);

  @override
  String toString() => 'Spine($color, $weight)';
}

/// Больше корешков у края не помещается: они станут тоньше полоски.
const maxSpines = 5;

/// Корешки закреплённых заметок сверху вниз: цвет папки ([plain] — без папки), толщина по
/// длине заметки от 1,6 до 3. Закреплённых нет или стоит замок — один корешок [accent]:
/// цвета папок у края не должны выдавать, что закреплено.
List<Spine> spinesFor(List<PinnedSpine> pinned, {required bool locked, required Color plain, required Color accent}) {
  if (locked || pinned.isEmpty) return [Spine(accent, 1)];
  return [
    for (final note in pinned.take(maxSpines)) Spine(note.color ?? plain, 1.6 + 1.4 * (note.length / 600).clamp(0.0, 1.0)),
  ];
}
