import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../services/sync/sync_progress.dart';
import 'settings_blocks.dart';

/// Ход синхронизации на экране «Stowa Sync»: что делается сейчас, сколько из скольких и
/// какой файл идёт, под этим — полоса из четырёх этапов прохода. Стоит в группе вместо
/// «Синхронизировать сейчас», пока проход идёт.
class SyncProgressCard extends StatefulWidget {
  const SyncProgressCard({super.key, required this.progress, required this.tint});

  final SyncProgress progress;

  /// Цвет группы: им залиты пройденные отрезки.
  final Color tint;

  @override
  State<SyncProgressCard> createState() => _SyncProgressCardState();
}

class _SyncProgressCardState extends State<SyncProgressCard> with SingleTickerProviderStateMixin {
  // один круг значка — 2,4 с; на нём же бежит блик полосы, пока итог не известен
  late final _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final progress = widget.progress;
    final count = _count(l, Localizations.localeOf(context).toString());
    final file = progress.file;
    final moving = file != null && (progress.stage == SyncStage.receive || progress.stage == SyncStage.send);
    final calm = MediaQuery.disableAnimationsOf(context);
    const figures = [FontFeature.tabularFigures()];
    return Semantics(
      key: const ValueKey('sync-progress'),
      container: true,
      liveRegion: true,
      label: l.syncRunning,
      child: Material(
        color: Tokens.containerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  RotationTransition(turns: _turn, child: const SettingsIconChip('sync')),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_doing(l, progress.stage), style: text.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                        // итог стал известен — строка цифр выезжает плавно, а не толкает блок
                        AnimatedSize(
                          duration: calm ? Duration.zero : const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topLeft,
                          child: count == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(count, maxLines: 2, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, fontFeatures: figures)),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StageTrack(stage: progress.stage, fraction: progress.fraction, tint: widget.tint, sweep: calm ? null : _turn),
              const SizedBox(height: 8),
              _StageNames(stage: progress.stage),
              // какой файл идёт: имя без папок, папки съели бы строку
              AnimatedSize(
                duration: calm ? Duration.zero : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: moving
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          file.split('/').last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall!.copyWith(color: Tokens.muted),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// «1 200 из 3 873 · 130 из 633 МБ»; мелочь до мегабайта — только файлы. null — итог не известен.
  /// Внутри половинок пробелы неразрывные: узкий экран переносит строку только у точки.
  String? _count(L l, String locale) {
    final progress = widget.progress;
    final total = progress.total;
    if (total == null || total == 0) return null;
    String whole(String part) => part.replaceAll(' ', ' ');
    final number = NumberFormat.decimalPattern(locale);
    final files = whole(l.syncOf(number.format(math.min(progress.done, total)), number.format(total)));
    const mega = 1024 * 1024;
    const giga = 1024 * mega;
    if (progress.bytesTotal < mega) return files;
    final unit = progress.bytesTotal >= giga ? giga : mega;
    // от сотни единиц десятые только мешают: «130 из 633 МБ», а не «130,4 из 633,1 МБ»
    final format = NumberFormat(progress.bytesTotal / unit >= 100 ? '0' : '0.0', locale);
    final done = format.format(math.min(progress.bytesDone, progress.bytesTotal) / unit);
    final all = format.format(progress.bytesTotal / unit);
    return '$files · ${whole(unit == giga ? l.syncOfGb(done, all) : l.syncOfMb(done, all))}';
  }

  static String _doing(L l, SyncStage stage) => switch (stage) {
    SyncStage.folder => l.syncDoingFolder,
    SyncStage.receive => l.syncDoingReceive,
    SyncStage.send => l.syncDoingSend,
    SyncStage.place => l.syncDoingPlace,
  };
}

/// Высота отрезка полосы.
const _trackHeight = 8.0;

/// Полоса этапов: пройденные залиты, текущий — на свою долю, впереди — пустые. Углы крупные
/// только снаружи, между отрезками узкая щель — как сцепленные кнопки шапки.
class _StageTrack extends StatelessWidget {
  const _StageTrack({required this.stage, required this.fraction, required this.tint, required this.sweep});

  final SyncStage stage;
  final double? fraction;
  final Color tint;

  /// Бег блика, пока итог этапа не известен; null — без движения.
  final Animation<double>? sweep;

  @override
  Widget build(BuildContext context) {
    final track = Color.alphaBlend(tint.withValues(alpha: 0.16), Tokens.containerHigh);
    const stages = SyncStage.values;
    return Row(
      children: [
        for (final (index, each) in stages.indexed) ...[
          if (index > 0) const SizedBox(width: 3),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(index == 0 ? _trackHeight / 2 : 2),
                right: Radius.circular(index == stages.length - 1 ? _trackHeight / 2 : 2),
              ),
              child: SizedBox(
                height: _trackHeight,
                child: ColoredBox(
                  color: track,
                  child: each.index < stage.index
                      ? _Fill(value: 1, color: tint)
                      : each == stage
                      ? (fraction == null ? _Sweep(color: tint, sweep: sweep) : _Fill(value: fraction!, color: tint))
                      : const _Fill(value: 0, color: Colors.transparent),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Заливка отрезка на долю [value]: доля меняется плавно, без рывка от каждой части файла.
class _Fill extends StatelessWidget {
  const _Fill({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: calm ? Duration.zero : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, share, _) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: share.clamp(0.0, 1.0),
        child: ColoredBox(color: color),
      ),
    );
  }
}

/// Итог этапа ещё не известен: по отрезку мягко бежит блик. Без движения — бледная заливка.
class _Sweep extends StatelessWidget {
  const _Sweep({required this.color, required this.sweep});

  final Color color;
  final Animation<double>? sweep;

  @override
  Widget build(BuildContext context) {
    final sweep = this.sweep;
    if (sweep == null) return ColoredBox(color: color.withValues(alpha: 0.35));
    return AnimatedBuilder(
      animation: sweep,
      builder: (context, _) {
        // блик шириной в 40 % входит слева и уходит справа, туда и обратно за круг значка
        final wave = Curves.easeInOutSine.transform(1 - (sweep.value * 2 - 1).abs());
        return FractionallySizedBox(
          alignment: Alignment(-1.4 + 2.8 * wave, 0),
          widthFactor: 0.4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.85), color.withValues(alpha: 0)]),
            ),
          ),
        );
      },
    );
  }
}

/// Подписи под отрезками: текущий этап ярко, пройденные спокойно, будущие бледно.
class _StageNames extends StatelessWidget {
  const _StageNames({required this.stage});

  final SyncStage stage;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final style = Theme.of(context).textTheme.labelMedium!;
    final names = [l.syncStepFolder, l.syncStepReceive, l.syncStepSend, l.syncStepPlace];
    return Row(
      children: [
        for (final (index, name) in names.indexed) ...[
          if (index > 0) const SizedBox(width: 3),
          Expanded(
            // щель до соседней подписи: на 320 точках «Отправка» иначе упиралась в «Заметки»
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                name,
                maxLines: 1,
                  style: index == stage.index
                      ? style.copyWith(color: Tokens.onSurface, fontWeight: FontWeight.w700)
                      : style.copyWith(color: index < stage.index ? Tokens.onSurfaceVariant : Tokens.muted),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
