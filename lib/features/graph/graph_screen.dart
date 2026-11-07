import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/graph_layout.dart';
import '../../l10n/app_localizations.dart';
import '../item/item_screen.dart';

/// Граф связей папки или тега.
Route<void> graphRoute({String? folderId, String? tag, required String title}) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => GraphScreen(folderId: folderId, tag: tag, title: title),
  transitionsBuilder: (context, animation, secondary, child) => FadeTransition(opacity: animation, child: child),
);

/// 500 точек считаются заметную долю секунды: не на потоке экрана. Функция верхнего
/// уровня нарочно — замыкание внутри состояния утащило бы в поток весь экран, а его
/// переслать нельзя.
Future<Map<String, (double, double)>> _layoutApart(List<String> ids, List<(String, String)> edges) => Isolate.run(() => layoutGraph(ids, edges));

/// Поля вокруг графа, чтобы крайние подписи не резались.
const _pad = 80.0;

class _Layout {
  const _Layout({required this.data, required this.places, required this.size, required this.degree});

  final GraphData data;
  final Map<String, Offset> places;
  final Size size;
  final Map<String, int> degree;
}

/// Вещи точками, связи линиями. Щипок приближает, касание по точке открывает вещь.
/// Чем больше у вещи связей, тем крупнее и светлее точка.
class GraphScreen extends ConsumerStatefulWidget {
  const GraphScreen({super.key, this.folderId, this.tag, required this.title});

  final String? folderId;
  final String? tag;
  final String title;

  @override
  ConsumerState<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends ConsumerState<GraphScreen> {
  final _transform = TransformationController();
  late final Future<_Layout> _layout = _load();
  Size _viewport = Size.zero;
  bool _fitted = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<_Layout> _load() async {
    final data = await ref.read(itemsRepositoryProvider).graph(folderId: widget.folderId, tag: widget.tag);
    final raw = await _layoutApart([for (final card in data.nodes) card.id], data.edges);
    final edges = data.edges;
    if (raw.isEmpty) return _Layout(data: data, places: const {}, size: Size.zero, degree: const {});
    final left = raw.values.map((place) => place.$1).reduce(min);
    final top = raw.values.map((place) => place.$2).reduce(min);
    final right = raw.values.map((place) => place.$1).reduce(max);
    final bottom = raw.values.map((place) => place.$2).reduce(max);
    final degree = <String, int>{};
    for (final (a, b) in edges) {
      degree[a] = (degree[a] ?? 0) + 1;
      degree[b] = (degree[b] ?? 0) + 1;
    }
    return _Layout(
      data: data,
      places: {for (final MapEntry(:key, :value) in raw.entries) key: Offset(value.$1 - left + _pad, value.$2 - top + _pad)},
      size: Size(right - left + _pad * 2, bottom - top + _pad * 2),
      degree: degree,
    );
  }

  void _fit(_Layout layout) {
    if (_viewport.isEmpty || layout.size.isEmpty) return;
    final scale = min(_viewport.width / layout.size.width, _viewport.height / layout.size.height).clamp(0.05, 1.5);
    final dx = (_viewport.width - layout.size.width * scale) / 2;
    final dy = (_viewport.height - layout.size.height * scale) / 2;
    _transform.value = Matrix4.translationValues(dx, dy, 0) * Matrix4.diagonal3Values(scale, scale, scale);
  }

  void _tap(_Layout layout, Offset at) {
    final scale = _transform.value.getMaxScaleOnAxis();
    String? hit;
    var best = 28 / scale;
    for (final MapEntry(key: id, value: place) in layout.places.entries) {
      final distance = (place - at).distance;
      if (distance < best) {
        best = distance;
        hit = id;
      }
    }
    if (hit != null) Navigator.of(context).push(itemRoute(hit));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 8),
              child: Row(
                children: [
                  Tooltip(
                    message: MaterialLocalizations.of(context).backButtonTooltip,
                    child: Pressable(
                      pressedScale: 0.9,
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
                        child: Icon(symbolIcon('arrow_back'), color: Tokens.onSurface),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.graphTitle, style: text.titleLarge!.copyWith(fontSize: 18)),
                        Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: Tokens.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder(
                future: _layout,
                builder: (context, snapshot) {
                  final layout = snapshot.data;
                  if (snapshot.hasError) {
                    return Center(child: Text(l.graphFailed, style: text.bodyLarge!.copyWith(color: Tokens.muted)));
                  }
                  if (layout == null) return const Center(child: CircularProgressIndicator());
                  if (layout.data.edges.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(l.graphEmpty, textAlign: TextAlign.center, style: text.bodyLarge!.copyWith(color: Tokens.muted, height: 1.4)),
                      ),
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      _viewport = constraints.biggest;
                      if (!_fitted) {
                        _fitted = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) => _fit(layout));
                      }
                      return InteractiveViewer(
                        transformationController: _transform,
                        constrained: false,
                        minScale: 0.05,
                        maxScale: 4,
                        boundaryMargin: const EdgeInsets.all(4000),
                        child: GestureDetector(
                          onTapUp: (details) => _tap(layout, details.localPosition),
                          child: CustomPaint(size: layout.size, painter: _GraphPainter(layout, _transform, text.labelSmall!)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter(this.layout, this.transform, this.style) : super(repaint: transform);

  final _Layout layout;
  final TransformationController transform;
  final TextStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = transform.value.getMaxScaleOnAxis();
    final line = Paint()
      ..color = Tokens.outline
      ..strokeWidth = 1.4 / scale.clamp(0.4, 2);
    for (final (a, b) in layout.data.edges) {
      final from = layout.places[a];
      final to = layout.places[b];
      if (from != null && to != null) canvas.drawLine(from, to, line);
    }
    final titles = {for (final card in layout.data.nodes) card.id: card.title};
    for (final MapEntry(key: id, value: place) in layout.places.entries) {
      final degree = layout.degree[id] ?? 0;
      final radius = 6 + 2.5 * sqrt(degree);
      // одиночки тусклые, узлы со многими связями светлые
      final color = degree == 0 ? Tokens.graphite : (degree >= 3 ? Tokens.accent : Tokens.onSurfaceVariant);
      canvas.drawCircle(place, radius, Paint()..color = color);
      // подписи постоянного размера на экране; издалека — только у узлов
      if (scale < 0.45 && degree < 3) continue;
      final title = titles[id] ?? '';
      final painter = TextPainter(
        text: TextSpan(text: title.length > 32 ? '${title.substring(0, 31)}…' : title, style: style.copyWith(fontSize: 12 / scale, color: degree == 0 ? Tokens.muted : Tokens.onSurfaceVariant)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      painter.paint(canvas, place + Offset(-painter.width / 2, radius + 4 / scale));
    }
  }

  @override
  bool shouldRepaint(_GraphPainter oldDelegate) => oldDelegate.layout != layout;
}
