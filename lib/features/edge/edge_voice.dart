import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

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
import '../../domain/sticker_geometry.dart' show circleSize;
import '../../domain/voice_geometry.dart';
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
///
/// Плашку можно утащить по экрану и свернуть в круг, как стикер: окно полки встаёт по
/// кругу и отдаёт касания мимо него приложению, запись идёт дальше. Касание круга или
/// корешков раскрывает её обратно.
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
  ConsumerState<EdgeVoice> createState() => EdgeVoiceState();
}

enum _Phase { starting, recording, saving, saved }

class EdgeVoiceState extends ConsumerState<EdgeVoice> with TickerProviderStateMixin {
  late final _show = AnimationController(vsync: this, duration: Motion.medium);

  /// 0 — плашка, 1 — круг.
  late final _shape = AnimationController(vsync: this, duration: Motion.long);
  VoiceSession? _session;
  _Phase _phase = _Phase.starting;
  bool _leaving = false;

  /// Окно полки стоит по кругу (или встаёт): в нём только круг.
  bool _folded = false;

  /// Левый верхний угол плашки, если её утащили; иначе — у корешков.
  Offset? _at;

  /// Где круг: куда свернулась плашка или куда его утащили.
  Rect _circle = Rect.zero;

  /// Свободная часть экрана и размер плашки — с последнего кадра во весь экран: в окне-круге
  /// их не узнать.
  Rect _area = Rect.zero;
  Size _pill = const Size(_width, _height);

  @override
  void initState() {
    super.initState();
    // подписи и «Убрать анимацию» — из контекста, а он готов только после первого кадра
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _still ? _show.value = 1 : _show.forward().ignore();
      _begin().ignore();
    });
  }

  late final EdgeChannel _channel = ref.read(edgeChannelProvider);

  bool get _still => MediaQuery.disableAnimationsOf(context);

  @override
  void dispose() {
    // окно убрали посреди записи: сказанное без «Сохранить» не остаётся висеть
    final session = _session;
    if (session != null) {
      session.cancel().ignore();
      session.dispose();
      _channel.recording(false).ignore();
    }
    _resizeGuard?.cancel();
    _show.dispose();
    _shape.dispose();
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
    if (!_still) await _show.reverse().orCancel.catchError((_) {});
    if (mounted) widget.onDone();
  }

  /// Мимо плашки или «назад»: идёт запись — сохранить, ещё не началась — просто уйти.
  void _outside() => _phase == _Phase.recording ? _save().ignore() : (_phase == _Phase.starting ? _cancel().ignore() : null);

  /// Где плашка сейчас: куда её утащили или у корешков, по их середине.
  Rect _pillRect() {
    if (_at case final at?) return voicePillAt(at, _pill, _area);
    final gap = widget.spines.width + 4;
    final left = widget.right ? _area.right - gap - _pill.width : _area.left + gap;
    return voicePillAt(Offset(left, widget.spines.center.dy - _pill.height / 2), _pill, _area);
  }

  void _drag(DragUpdateDetails details) {
    if (_folded || _shape.value > 0) return;
    setState(() => _at = voicePillAt(_pillRect().topLeft + details.delta, _pill, _area).topLeft);
  }

  /// Форма к [value] за `long`; «Убрать анимацию» — сразу.
  Future<void> _reshape(double value) async {
    if (_still) {
      _shape.value = value;
      return;
    }
    await _shape.animateTo(value).orCancel.catchError((_) {});
  }

  /// «Свернуть запись»: плашка сжимается в круг у своего края, потом окно встаёт по кругу.
  Future<void> _fold() async {
    if (_folded || _shape.isAnimating || _phase != _Phase.recording) return;
    final pill = _pillRect();
    setState(() {
      _at = pill.topLeft;
      _circle = voiceCircleOf(pill, _area);
    });
    await _reshape(1);
    if (!mounted) return;
    setState(() => _folded = true);
    await _channel.voiceFold(_circle);
    await _settle((window) => window.shortestSide < 2 * circleSize);
  }

  /// Касание круга или корешков: окно снова во весь экран, круг растёт в плашку туда, где есть место.
  Future<void> unfold() async {
    if (!_folded || _shape.isAnimating || !mounted) return;
    setState(() => _at = voicePillOf(_circle, _pill, _area).topLeft);
    await _channel.voiceUnfold();
    // рост начинается, когда окно уже большое и снимок круга убран: иначе он шёл бы под снимком
    await _settle((window) => window.shortestSide >= 2 * circleSize);
    if (!mounted) return;
    setState(() => _folded = false);
    await _reshape(0);
  }

  /// Круг утащили: раскроется оттуда.
  void moved(Offset at) {
    if (!_folded) return;
    _circle = at & _circle.size;
  }

  /// Окно меняет размер: ждём кадр, нарисованный в окне, где [ready], и говорим нативу
  /// «готово»; он убирает снимок и отвечает. Окно так и не стало новым — через 600 мс всё
  /// равно: снимок не должен висеть.
  bool Function(Size window)? _resizeReady;
  Completer<void>? _resized;
  Timer? _resizeGuard;

  Future<void> _settle(bool Function(Size window) ready) async {
    final done = Completer<void>();
    if (_resized case final previous? when !previous.isCompleted) previous.complete();
    _resizeReady = ready;
    _resized = done;
    _resizeGuard?.cancel();
    _resizeGuard = Timer(const Duration(milliseconds: 600), () {
      if (!done.isCompleted) done.complete();
    });
    if (mounted) setState(() {});
    await done.future;
    if (_resized == done) {
      _resizeGuard?.cancel();
      _resizeReady = null;
      _resized = null;
    }
    if (mounted) await _channel.voiceShown();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final window = MediaQuery.sizeOf(context);
    // этот кадр уже в новом размере окна: после него натив может убрать снимок
    if (_resizeReady case final ready? when ready(window)) {
      final done = _resized;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (done != null && !done.isCompleted) done.complete();
      });
    }
    // окно встало по кругу: в нём только круг
    if (window.shortestSide < 2 * circleSize) {
      return _Circle(session: _session, label: l.voiceUnfold, onTap: () => unfold().ignore());
    }

    final padding = MediaQuery.paddingOf(context);
    _area = Rect.fromLTRB(0, padding.top, window.width, window.height - padding.bottom);
    _pill = Size(math.min(_width, window.width - widget.spines.width - 24), _height);
    final pill = _pillRect();
    final shown = CurvedAnimation(parent: _show, curve: Motion.emphasizedDecelerate, reverseCurve: Motion.emphasizedAccelerate);
    // круг у правого края плашки — плашка сжимается к нему и растёт от него
    final anchor = _circle.center.dx > pill.center.dx ? Alignment.centerRight : Alignment.centerLeft;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _outside(),
      child: AnimatedBuilder(
        animation: Listenable.merge([shown, _shape]),
        builder: (context, _) {
          // насколько плашка свёрнута: 0 — плашка, 1 — круг
          final round = Motion.emphasized.transform(_shape.value);
          final rect = _shape.value == 0 ? pill : Rect.lerp(pill, _circle, round)!;
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _outside,
                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.18 * shown.value * (1 - round))),
                ),
              ),
              Positioned.fromRect(
                rect: rect,
                // выезжает из корешков: растёт от их края и проявляется
                child: Opacity(
                  opacity: shown.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.85 + 0.15 * shown.value,
                    alignment: widget.right ? Alignment.centerRight : Alignment.centerLeft,
                    child: _morph(round, anchor, l),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Плашка или круг при свёрнутости [round]: строка записи гаснет в первой части
  /// сворачивания, круг проступает в последней.
  Widget _morph(double round, Alignment anchor, L l) {
    final pillShown = Curves.easeOut.transform(((0.45 - round) / 0.45).clamp(0.0, 1.0));
    final circleShown = ((round - 0.55) / 0.45).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(lerpDouble(_height, circleSize, round)! / 2),
      child: ColoredBox(
        color: Tokens.containerHigh,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (pillShown > 0)
              Opacity(
                opacity: pillShown,
                // строка во всю ширину плашки, рамка её только обрезает: при сворачивании
                // кнопки не сжимаются, а уходят за край
                child: OverflowBox(
                  alignment: anchor,
                  minWidth: _pill.width,
                  maxWidth: _pill.width,
                  minHeight: _height,
                  maxHeight: _height,
                  child: GestureDetector(
                    onPanUpdate: _drag,
                    child: _Pill(
                      key: const ValueKey('edge-voice'),
                      phase: _phase,
                      session: _session,
                      cancelTooltip: l.voiceCancel,
                      foldTooltip: l.voiceFold,
                      saveTooltip: l.save,
                      savedLabel: l.voiceSaved,
                      onCancel: () => _cancel().ignore(),
                      onFold: () => _fold().ignore(),
                      onSave: () => _save().ignore(),
                    ),
                  ),
                ),
              ),
            if (circleShown > 0)
              Opacity(
                opacity: circleShown,
                child: _Circle(session: _session, label: l.voiceUnfold, onTap: null),
              ),
          ],
        ),
      ),
    );
  }
}

/// Свёрнутая запись: точка и время. Касание раскрывает плашку; тащит круг натив.
class _Circle extends StatelessWidget {
  const _Circle({required this.session, required this.label, required this.onTap});

  final VoiceSession? session;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final seconds = session?.elapsed.inSeconds ?? 0;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: onTap == null ? null : const ValueKey('edge-voice-circle'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Dot(size: 8),
                const SizedBox(height: 3),
                Text(
                  _clock(seconds),
                  style: Theme.of(context).textTheme.labelMedium!.copyWith(fontFamily: 'Unbounded', fontWeight: FontWeight.w600, fontSize: 11, color: Tokens.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.phase,
    required this.session,
    required this.cancelTooltip,
    required this.foldTooltip,
    required this.saveTooltip,
    required this.savedLabel,
    required this.onCancel,
    required this.onFold,
    required this.onSave,
  });

  final _Phase phase;
  final VoiceSession? session;
  final String cancelTooltip;
  final String foldTooltip;
  final String saveTooltip;
  final String savedLabel;
  final VoidCallback onCancel;
  final VoidCallback onFold;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final time = _clock(session?.elapsed.inSeconds ?? 0);
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
                  IconButton(
                    tooltip: foldTooltip,
                    onPressed: phase == _Phase.recording ? onFold : null,
                    icon: Icon(symbolIcon('remove'), color: Tokens.onSurfaceVariant),
                  ),
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
  const _Dot({this.size = 10});

  final double size;

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
      child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(color: Tokens.accent, shape: BoxShape.circle)),
    );
  }
}
