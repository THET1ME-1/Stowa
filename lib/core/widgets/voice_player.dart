import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../l10n/app_localizations.dart';
import '../format/duration_format.dart';
import '../icons/icon_registry.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// Скорости по кругу на кнопке плеера.
const voiceSpeeds = [1.0, 1.5, 2.0];

/// Высоты столбиков волны: одна и та же у одной записи, по её id.
List<double> voiceBars(String seedId, int count) {
  final seed = seedId.codeUnits.fold(7, (sum, unit) => (sum * 31 + unit) & 0x7fffffff);
  return [for (var bar = 0; bar < count; bar++) 6 + ((seed >> (bar % 24)) & 7) * 3.0 + (bar % 5) * 1.5];
}

/// Голосовое: круглая кнопка, волна с бегущим прогрессом и время. Касание или
/// протяжка по волне перематывает. Большой плеер страницы вещи показывает
/// прошедшее и полное время и кнопку скорости.
class VoicePlayer extends StatefulWidget {
  const VoicePlayer({super.key, required this.path, required this.seedId, this.large = false});

  /// Полный путь к файлу записи.
  final String path;
  final String seedId;
  final bool large;

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  AudioPlayer? _player;
  Duration? _length;
  Duration _position = Duration.zero;
  bool _playing = false;
  int _speed = 0;
  final _subscriptions = <StreamSubscription<Object?>>[];

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  /// Плеер поднимается при первом касании: пока не слушали, файл не трогаем.
  Future<AudioPlayer> _ready() async {
    final existing = _player;
    if (existing != null) return existing;
    final player = _player = AudioPlayer();
    _subscriptions
      ..add(
        player.playerStateStream.listen((state) {
          if (!mounted) return;
          final ended = state.processingState == ProcessingState.completed;
          setState(() => _playing = state.playing && !ended);
          if (ended) {
            player.pause();
            player.seek(Duration.zero);
          }
        }),
      )
      ..add(
        player.positionStream.listen((position) {
          if (mounted) setState(() => _position = position);
        }),
      );
    final length = await player.setFilePath(widget.path);
    if (mounted) setState(() => _length = length);
    return player;
  }

  Future<void> _toggle() async {
    final player = await _ready();
    _playing ? await player.pause() : await player.play();
  }

  Future<void> _seekTo(double share) async {
    final player = await _ready();
    final length = _length;
    if (length == null) return;
    await player.seek(length * share.clamp(0.0, 1.0));
  }

  Future<void> _nextSpeed() async {
    final player = await _ready();
    setState(() => _speed = (_speed + 1) % voiceSpeeds.length);
    await player.setSpeed(voiceSpeeds[_speed]);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final large = widget.large;
    final length = _length;
    final progress = length == null || length.inMilliseconds == 0 ? 0.0 : (_position.inMilliseconds / length.inMilliseconds).clamp(0.0, 1.0);
    final bars = voiceBars(widget.seedId, large ? 36 : 32);
    final timeStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: large ? Tokens.onSurfaceVariant : Tokens.muted);
    final button = large ? 56.0 : 44.0;

    final wave = LayoutBuilder(
      builder: (context, box) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _seekTo(details.localPosition.dx / box.maxWidth),
        onHorizontalDragUpdate: (details) => _seekTo(details.localPosition.dx / box.maxWidth),
        child: SizedBox(
          height: 32,
          child: Row(
            children: [
              for (final (index, height) in bars.indexed)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      height: height,
                      decoration: BoxDecoration(
                        color: index / bars.length < progress ? Tokens.accent : Tokens.onSurfaceVariant.withValues(alpha: large ? 0.45 : 0.75),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Row(
      children: [
        Tooltip(
          message: _playing ? l.voicePause : l.voicePlay,
          child: Pressable(
            pressedScale: 0.9,
            onTap: _toggle,
            child: Container(
              width: button,
              height: button,
              decoration: BoxDecoration(color: Tokens.accent, shape: BoxShape.circle),
              child: Icon(symbolIcon(_playing ? 'pause' : 'play_arrow', filled: true), size: large ? 30 : 24, color: Tokens.onAccent),
            ),
          ),
        ),
        SizedBox(width: large ? 14 : 12),
        Expanded(
          child: large
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    wave,
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatClock(_position), style: timeStyle),
                        Text(length == null ? '' : formatClock(length), style: timeStyle),
                      ],
                    ),
                  ],
                )
              : wave,
        ),
        if (large) ...[
          const SizedBox(width: 12),
          Tooltip(
            message: l.voiceSpeed,
            child: Material(
              color: Tokens.containerHighest,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _nextSpeed,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  child: Text('${voiceSpeeds[_speed].toString().replaceFirst('.0', '')}×', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Tokens.onSurface)),
                ),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(width: 12),
          Text(length == null ? '' : formatClock(length), style: timeStyle),
        ],
      ],
    );
  }
}
