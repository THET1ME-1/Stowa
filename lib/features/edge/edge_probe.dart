import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens.dart';

/// Пробная полка этапа 1 (docs/plans/2026-11-14-edge-panel-plan.md, задача 2): окно поверх
/// других приложений с полем ввода. Проверяет, что клавиатура приходит в окно поверх и уходит
/// из него, не ломая приложение под полкой. В задаче 9 её место займёт настоящая полка.
class EdgeProbe extends StatefulWidget {
  const EdgeProbe({super.key});

  @override
  State<EdgeProbe> createState() => _EdgeProbeState();
}

class _EdgeProbeState extends State<EdgeProbe> {
  static const _edge = MethodChannel('stowa/edge');
  final _field = FocusNode();

  @override
  void initState() {
    super.initState();
    // окно берёт клавиатуру только на время набора
    _field.addListener(() => _edge.invokeMethod('setFocusable', _field.hasFocus));
    // время до первого кадра — для замера холодного и тёплого открытия
    SchedulerBinding.instance.addPostFrameCallback((_) => debugPrint('StowaEdge first frame ${DateTime.now().toIso8601String()}'));
    // кадры дольше 16 мс — в журнал: замер плавности
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final frame in timings) {
        if (frame.totalSpan.inMilliseconds > 16) debugPrint('StowaEdge slow frame ${frame.totalSpan.inMilliseconds} ms');
      }
    });
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.transparent, canvasColor: Colors.transparent),
      home: Material(
        type: MaterialType.transparency,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 312,
            margin: const EdgeInsets.fromLTRB(0, 12, 8, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF141517), borderRadius: BorderRadius.circular(Radii.card)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Stowa',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFF2F2F0)),
                ),
                const Spacer(),
                TextField(
                  key: const ValueKey('edge-probe-field'),
                  focusNode: _field,
                  style: const TextStyle(color: Color(0xFFF2F2F0)),
                  decoration: const InputDecoration(hintText: 'Закинь что угодно или найди', filled: true, fillColor: Color(0xFF2E2F33)),
                ),
                const SizedBox(height: 12),
                FilledButton(key: const ValueKey('edge-probe-close'), onPressed: () => _edge.invokeMethod('close'), child: const Text('Закрыть')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
