import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/capture_service.dart';
import '../../services/edge_channel.dart';
import '../composer/voice_session.dart';
import '../composer/voice_wave.dart';

/// Ширина плашки записи; на узком экране — меньше.
const _width = 300.0;
const _height = 64.0;

/// Сколько плашка показывает «Голосовое легло», прежде чем уйти.
const _savedShown = Duration(milliseconds: 900);

/// Запись с удержания корешков «Под рукой»: плашка выезжает у корешков, полка не открывается.
/// Палец можно убрать — запись идёт, пока не нажмут «Сохранить» или «Отменить запись».
/// Касание мимо плашки и «назад» сохраняют: случайно потерять сказанное нельзя.
class EdgeVoice extends ConsumerStatefulWidget {
  const EdgeVoice({super.key, required this.spines, required this.right, required this.onDone, required this.onElsewhere});

  /// Где корешки на экране: плашка встаёт рядом, по их середине.
  final Rect spines;
  final bool right;

  /// Плашка ушла: окно можно убирать.
  final VoidCallback onDone;

  /// Права на микрофон нет: записывать будет окно виджета.
  final VoidCallback onElsewhere;

  @override
  ConsumerState<EdgeVoice> createState() => _EdgeVoiceState();
}

enum _Phase { starting, recording, saving, saved }

class _EdgeVoiceState extends ConsumerState<EdgeVoice> with SingleTickerProviderStateMixin {
  late final _show = AnimationController(vsync: this, duration: Motion.medium);
  VoiceSession? _session;
  _Phase _phase = _Phase.starting;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    // подписи и «Убрать анимацию» — из контекста, а он готов только после первого кадра
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      MediaQuery.disableAnimationsOf(context) ? _show.value = 1 : _show.forward().ignore();
      _begin().ignore();
    });
  }

  late final EdgeChannel _channel = ref.read(edgeChannelProvider);

  @override
  void dispose() {
    // окно убрали посреди записи: сказанное без «Сохранить» не остаётся висеть
    final session = _session;
    if (session != null) {
      session.cancel().ignore();
      session.dispose();
      _channel.recording(false).ignore();
    }
    _show.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    final l = L.of(context);
    if (!await _channel.micGranted()) return widget.onElsewhere();
    // служба с микрофоном — до старта записи: иначе Android её глушит
    await _channel.recording(true, channel: l.edgeVoiceChannel, text: l.edgeVoiceNow);
    final session = VoiceSession(Directory(p.join(ref.read(scratchRootProvider).path, 'tmp')));
    var started = false;
    try {
      // право проверено выше: плагин записи без Activity его не видит
      started = await session.start(checked: true);
    } catch (_) {
      started = false;
    }
    if (!mounted || _leaving) {
      if (started) await session.cancel().catchError((_) {});
      session.dispose();
      _channel.recording(false).ignore();
      return;
    }
    if (!started) {
      session.dispose();
      _channel.recording(false).ignore();
      return widget.onElsewhere();
    }
    HapticFeedback.mediumImpact();
    session.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() {
      _session = session;
      _phase = _Phase.recording;
    });
  }

  Future<void> _save() async {
    final session = _session;
    if (session == null || _phase != _Phase.recording) return;
    setState(() => _phase = _Phase.saving);
    _session = null;
    final file = await session.stop();
    session.dispose();
    _channel.recording(false).ignore();
    if (file != null) {
      final title = mounted ? L.of(context).voiceTitle : '';
      await ref.read(captureServiceProvider).capture(CaptureInput(files: [file], title: title));
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _phase = _Phase.saved);
    await Future<void>.delayed(_savedShown);
    await _leave();
  }

  Future<void> _cancel() async {
    final session = _session;
    _session = null;
    if (session != null) {
      await session.cancel().catchError((_) {});
      session.dispose();
      _channel.recording(false).ignore();
    }
    await _leave();
  }

  Future<void> _leave() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    if (!MediaQuery.disableAnimationsOf(context)) await _show.reverse().orCancel.catchError((_) {});
    if (mounted) widget.onDone();
  }

  /// Мимо плашки или «назад»: идёт запись — сохранить, ещё не началась — просто уйти.
  void _outside() => _phase == _Phase.recording ? _save().ignore() : (_phase == _Phase.starting ? _cancel().ignore() : null);

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final screen = MediaQuery.sizeOf(context);
    final width = math.min(_width, screen.width - widget.spines.width - 24);
    // по середине корешков, не выше и не ниже экрана
    final top = (widget.spines.center.dy - _height / 2).clamp(MediaQuery.paddingOf(context).top + 8, screen.height - _height - 8);
    final gap = widget.spines.width + 4;
    final shown = CurvedAnimation(parent: _show, curve: Motion.emphasizedDecelerate, reverseCurve: Motion.emphasizedAccelerate);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _outside(),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _outside,
              child: AnimatedBuilder(
                animation: shown,
                builder: (context, _) => ColoredBox(color: Colors.black.withValues(alpha: 0.18 * shown.value)),
              ),
            ),
          ),
          Positioned(
            top: top,
            left: widget.right ? null : gap,
            right: widget.right ? gap : null,
            width: width,
            height: _height,
            child: AnimatedBuilder(
              animation: shown,
              // выезжает из корешков: растёт от их края и проявляется
              builder: (context, child) => Opacity(
                opacity: shown.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.85 + 0.15 * shown.value,
                  alignment: widget.right ? Alignment.centerRight : Alignment.centerLeft,
                  child: child,
                ),
              ),
              child: _Pill(
                key: const ValueKey('edge-voice'),
                phase: _phase,
                session: _session,
                cancelTooltip: l.voiceCancel,
                saveTooltip: l.save,
                savedLabel: l.voiceSaved,
                onCancel: () => _cancel().ignore(),
                onSave: () => _save().ignore(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.phase,
    required this.session,
    required this.cancelTooltip,
    required this.saveTooltip,
    required this.savedLabel,
    required this.onCancel,
    required this.onSave,
  });

  final _Phase phase;
  final VoiceSession? session;
  final String cancelTooltip;
  final String saveTooltip;
  final String savedLabel;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final seconds = session?.elapsed.inSeconds ?? 0;
    final time = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(_height / 2)),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: AnimatedSwitcher(
        duration: Motion.short,
        switchInCurve: Motion.emphasizedDecelerate,
        switchOutCurve: Motion.emphasizedAccelerate,
        child: phase == _Phase.saved
            ? Row(
                key: const ValueKey('saved'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(symbolIcon('graphic_eq'), size: 20, color: Tokens.onSurface),
                  const SizedBox(width: 10),
                  Flexible(child: Text(savedLabel, overflow: TextOverflow.ellipsis, style: text.titleSmall!.copyWith(color: Tokens.onSurface))),
                ],
              )
            : Row(
                key: const ValueKey('recording'),
                children: [
                  IconButton(
                    tooltip: cancelTooltip,
                    onPressed: phase == _Phase.saving ? null : onCancel,
                    icon: Icon(symbolIcon('close'), color: Tokens.onSurfaceVariant),
                  ),
                  const _Dot(),
                  const SizedBox(width: 8),
                  Text(time, style: text.titleSmall!.copyWith(fontFamily: 'Unbounded', fontWeight: FontWeight.w600, fontSize: 15, color: Tokens.onSurface)),
                  const SizedBox(width: 10),
                  Expanded(child: session == null ? const SizedBox() : VoiceWave(levels: session!.levels)),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: saveTooltip,
                    child: Pressable(
                      onTap: phase == _Phase.recording ? onSave : null,
                      pressedScale: 0.9,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: Tokens.onSurface, shape: BoxShape.circle),
                        child: phase == _Phase.saving
                            ? Padding(padding: const EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: inkOn(Tokens.onSurface)))
                            : Icon(symbolIcon('check'), size: 24, color: inkOn(Tokens.onSurface)),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Точка записи: мягко гаснет и проступает, пока идёт запись.
class _Dot extends StatefulWidget {
  const _Dot();

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.25).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Tokens.accent, shape: BoxShape.circle)),
    );
  }
}
