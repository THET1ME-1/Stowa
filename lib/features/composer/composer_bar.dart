import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/capture_service.dart';
import 'attach_sheet.dart';
import 'line_controller.dart';
import 'picked_files.dart';

/// Строка снизу: текст, вложения и чипы над ним, кнопка «Закинуть».
/// Сохраняет сама и сообщает наверх, что легло.
class ComposerBar extends ConsumerStatefulWidget {
  const ComposerBar({super.key, required this.line, required this.focusNode, this.onSaved});

  final LineController line;
  final FocusNode focusNode;
  final void Function(String id, DateTime? reminderAt)? onSaved;

  @override
  ConsumerState<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends ConsumerState<ComposerBar> {
  List<PickedFile> _files = const [];
  bool _sending = false;

  LineController get _line => widget.line;

  bool get _canSend => !_sending && (_line.text.trim().isNotEmpty || _files.isNotEmpty);

  Future<void> _attach(AttachSource? source) async {
    if (source == null) return;
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await switch (source) {
        AttachSource.gallery => pickGalleryMedia(),
        AttachSource.photo => pickCameraPhoto(),
        AttachSource.video => pickCameraVideo(),
        AttachSource.files => pickAnyFiles(),
      };
      if (picked.isEmpty || !mounted) return;
      setState(() => _files = [..._files, ...picked]);
    } on PlatformException {
      messenger.showSnackBar(SnackBar(content: Text(l.attachFailed)));
    }
  }

  Future<void> _send() async {
    if (!_canSend) return;
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final input = CaptureInput(
      text: _line.text,
      files: _files,
      forcedTagNames: _line.tags,
      detectReminder: !_line.reminderDismissed,
    );
    final reminderAt = _line.reminder?.at;
    setState(() => _sending = true);
    HapticFeedback.lightImpact();
    try {
      // строка чистится после записи: запись локальная и быстрая, а при сбое текст не пропадёт
      final id = await ref.read(captureServiceProvider).capture(input);
      _line.reset();
      if (mounted) setState(() => _files = const []);
      widget.onSaved?.call(id, reminderAt);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.saveFailed)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _line,
      builder: (context, _) {
        final reminder = _line.reminder;
        final now = ref.read(clockProvider)();
        final chips = <Widget>[
          if (reminder != null)
            _LineChip(
              key: const ValueKey('reminder'),
              icon: 'alarm',
              label: l.composerRemind(formatReminder(l, reminder.at, now)),
              removeTooltip: l.composerRemoveReminder,
              onRemove: _line.dismissReminder,
            ),
          for (final tag in _line.tags)
            _LineChip(key: ValueKey('#$tag'), icon: 'tag', label: tag, removeTooltip: l.removeAttachment, onRemove: () => _line.removeTag(tag)),
        ];
        return Container(
          decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: BorderRadius.circular(Radii.card)),
          padding: const EdgeInsets.all(8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Reveal(
              child: _files.isEmpty
                  ? null
                  : _AttachmentsRow(
                      files: _files,
                      removeTooltip: l.removeAttachment,
                      onRemove: (file) => setState(() => _files = [..._files]..remove(file)),
                    ),
            ),
            _Reveal(
              child: chips.isEmpty
                  ? null
                  // чипы не влезли — край уходит в тень, видно, что строка листается
                  : ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.white, Colors.white, Colors.transparent],
                        stops: [0, 0.9, 1],
                      ).createShader(bounds),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 4, right: 24),
                        child: Row(children: [
                          for (final chip in chips) Padding(padding: const EdgeInsets.only(right: 6), child: chip),
                        ]),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: TextField(
                controller: _line,
                focusNode: widget.focusNode,
                minLines: 1,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: Tokens.accent,
                style: text.bodyLarge!.copyWith(fontSize: 16, height: 1.45, color: Tokens.onSurface),
                decoration: InputDecoration.collapsed(
                  hintText: l.composerHint,
                  hintStyle: text.bodyLarge!.copyWith(fontSize: 16, height: 1.45, color: Tokens.muted),
                ),
              ),
            ),
            Row(children: [
              _RoundButton(
                icon: 'add',
                tooltip: l.composerAttach,
                tonal: true,
                onTap: () async => _attach(await showAttachSheet(context)),
              ),
              _RoundButton(icon: 'photo_camera', tooltip: l.attachCamera, onTap: () => _attach(AttachSource.photo)),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _SendButton(label: l.composerStow, active: _canSend, onTap: _send),
                ),
              ),
            ]),
          ]),
        );
      },
    );
  }
}

/// Плавно раскрывает и прячет полосу над строкой.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Motion.medium,
      curve: Motion.emphasized,
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: Motion.short,
        child: child ?? const SizedBox(width: double.infinity),
      ),
    );
  }
}

class _LineChip extends StatelessWidget {
  const _LineChip({super.key, required this.icon, required this.label, required this.removeTooltip, required this.onRemove});

  final String icon;
  final String label;
  final String removeTooltip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Pop(
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(10)),
            child: Icon(symbolIcon(icon, filled: true), size: 18, color: Tokens.onAccent),
          ),
          const SizedBox(width: 8),
          Text(label, style: text.labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: Tokens.onSurface)),
          IconButton(
            tooltip: removeTooltip,
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            color: Tokens.muted,
            icon: Icon(symbolIcon('close')),
          ),
        ]),
      ),
    );
  }
}

/// Чип и вложение появляются с пружинкой, а не возникают.
class _Pop extends StatelessWidget {
  const _Pop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: Motion.long,
      curve: Motion.spatial,
      builder: (context, scale, child) => Opacity(
        opacity: ((scale - 0.6) / 0.4).clamp(0.0, 1.0),
        child: Transform.scale(scale: scale, child: child),
      ),
      child: child,
    );
  }
}

class _AttachmentsRow extends StatelessWidget {
  const _AttachmentsRow({required this.files, required this.removeTooltip, required this.onRemove});

  final List<PickedFile> files;
  final String removeTooltip;
  final ValueChanged<PickedFile> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
        itemCount: files.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final file = files[index];
          return _Pop(
            key: ValueKey(file.path),
            child: Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(Radii.photo), child: SizedBox.square(dimension: 60, child: _Preview(file: file))),
              Positioned(
                right: 4,
                top: 4,
                child: Tooltip(
                  message: removeTooltip,
                  child: Pressable(
                    onTap: () => onRemove(file),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(color: Tokens.accent, shape: BoxShape.circle),
                      child: Icon(symbolIcon('close'), size: 16, color: Tokens.onAccent),
                    ),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

/// Картинка показывает себя, остальное — значок вида и расширение.
class _Preview extends StatelessWidget {
  const _Preview({required this.file});

  final PickedFile file;

  @override
  Widget build(BuildContext context) {
    if (file.mime.startsWith('image/')) {
      return Image.file(
        File(file.path),
        fit: BoxFit.cover,
        cacheWidth: (60 * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (_, _, _) => const ColoredBox(color: Tokens.graphite),
      );
    }
    final icon = switch (file.mime.split('/').first) {
      'video' => 'play_arrow',
      'audio' => 'graphic_eq',
      'text' => 'notes',
      _ => 'description',
    };
    final extension = p.extension(file.path).replaceFirst('.', '').toUpperCase();
    return ColoredBox(
      color: Tokens.graphite,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(symbolIcon(icon, filled: true), size: 22, color: Tokens.onSurface),
        if (extension.isNotEmpty && extension.length <= 5)
          Text(extension, style: Theme.of(context).textTheme.labelSmall!.copyWith(fontSize: 10, color: Tokens.onSurfaceVariant)),
      ]),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap, this.tonal = false});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        backgroundColor: tonal ? Tokens.graphite : Colors.transparent,
        foregroundColor: tonal ? Tokens.onSurface : Tokens.onSurfaceVariant,
      ),
      icon: Icon(symbolIcon(icon)),
    );
  }
}

/// Кнопка отправки: пустая строка — тихий кружок, есть что закинуть —
/// белая пилюля с подписью.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = active ? Tokens.onAccent : Tokens.muted;
    return Pressable(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.emphasized,
        height: 48,
        padding: EdgeInsets.only(left: active ? 20 : 12, right: 12),
        decoration: BoxDecoration(color: active ? Tokens.accent : Tokens.graphite, borderRadius: BorderRadius.circular(24)),
        child: AnimatedSize(
          duration: Motion.medium,
          curve: Motion.emphasized,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (active) ...[
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: color),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(symbolIcon('arrow_upward'), size: 24, color: color),
          ]),
        ),
      ),
    );
  }
}
