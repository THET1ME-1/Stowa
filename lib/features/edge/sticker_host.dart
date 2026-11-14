import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../domain/note_blocks.dart';
import '../../domain/note_links.dart' show shownTitle;
import '../../domain/sticker_geometry.dart';
import '../../l10n/app_localizations.dart';
import '../../services/sticker_channel.dart';

/// Пунктов на стикере: остальное — «ещё N строк», вся заметка — в Stowa.
const _linesOnSticker = 8;

/// Скругление раскрытого стикера; круг — половина своей стороны.
const _stickerRadius = 24.0;

/// Стикер поверх любого приложения: одна заметка в своём окне (движок `stickerMain`).
/// Окно двигает Kotlin, стикер рисуется по размеру окна: сворачиваясь, окно сжимается
/// к кругу в угле у ближнего края, и картинка следует за ним кадр в кадр — углы
/// скругляются, цвет переходит в цвет папки, текст гаснет, в круге проступает число.
class StickerHost extends ConsumerStatefulWidget {
  const StickerHost({super.key, required this.noteId, this.channel});

  final String noteId;

  /// В тестах — поддельный; на телефоне — канал `stowa/sticker` этого движка.
  final StickerChannel? channel;

  @override
  ConsumerState<StickerHost> createState() => _StickerHostState();
}

class _StickerHostState extends ConsumerState<StickerHost> with TickerProviderStateMixin {
  late final StickerChannel _channel = widget.channel ?? MethodStickerChannel();
  final _content = GlobalKey();

  /// Окно сейчас и свободная часть экрана, в точках.
  Rect? _window;
  Size _screen = Size.zero;

  bool _folded = false;
  bool _morphing = false;
  bool _removing = false;

  /// Высота раскрытого стикера — по содержимому.
  double _height = 0;

  /// Угол, к которому стягивается стикер: там стоит круг.
  Alignment _anchor = Alignment.topLeft;

  /// Появление: с 92 % до 100 % и проявление; уход: гаснет и сжимается до 90 %.
  late final _appear = AnimationController(vsync: this, duration: Motion.medium);
  late final _leave = AnimationController(vsync: this, duration: Motion.short);

  StreamSubscription<StickerEvent>? _events;

  @override
  void initState() {
    super.initState();
    _channel.placement().then((placement) {
      if (!mounted) return;
      setState(() {
        _window = placement.window;
        _screen = placement.screen;
        _folded = placement.window.width < stickerWidth / 2;
        _height = placement.stickerHeight ?? 0;
      });
      // поднят свёрнутым: замера не будет, круг виден сразу
      if (_folded) _still ? _appear.value = 1 : _appear.forward().ignore();
    }).ignore();
    _events = _channel.events.listen((event) {
      final window = _window;
      if (!mounted || window == null) return;
      switch (event) {
        case StickerMoved(:final at):
          _window = Rect.fromLTWH(at.dx, at.dy, window.width, window.height);
        case StickerScreen(:final placement):
          setState(() {
            _window = placement.window;
            _screen = placement.screen;
          });
      }
    });
    // заметку удалили или убрали в корзину — стикер уходит сам
    ref.listenManual(itemProvider(widget.noteId), (previous, next) {
      if (next.hasValue && (next.value == null || next.value!.item.deletedAt != null)) _remove();
    });
    // «Код на вход»: текст заметки поверх всего висеть не должен — стикер снимается,
    // ничего не показав
    if (ref.read(startLockProvider)?.appLock ?? false) _lock();
    ref.listenManual(privacyLockProvider, (previous, next) {
      if (next.value?.appLock ?? false) _lock();
    });
  }

  @override
  void dispose() {
    _events?.cancel().ignore();
    _appear.dispose();
    _leave.dispose();
    super.dispose();
  }

  bool get _still => MediaQuery.disableAnimationsOf(context);

  /// Высота содержимого после кадра: окно встаёт по ней, первое появление — тогда же.
  void _measure() {
    final window = _window;
    final box = _content.currentContext?.findRenderObject() as RenderBox?;
    if (window == null || box == null || !box.hasSize || _folded || _morphing || _removing) return;
    final height = box.size.height;
    if ((height - _height).abs() > 0.5 || (window.height - height).abs() > 0.5) {
      _height = height;
      final at = clampTo(window.topLeft, Size(stickerWidth, height), _screen);
      _window = Rect.fromLTWH(at.dx, at.dy, stickerWidth, height);
      _channel.frame(_window!).ignore();
    }
    if (_appear.value == 0 && !_appear.isAnimating) {
      _still ? _appear.value = 1 : _appear.forward().ignore();
    }
  }

  /// Угол [big], ближний к [small]: туда стягивается стикер и оттуда раскрывается.
  Alignment _anchorOf(Rect big, Rect small) => Alignment(small.center.dx > big.center.dx ? 1 : -1, small.center.dy > big.center.dy ? 1 : -1);

  Future<void> _morph(Rect target) async {
    _morphing = true;
    await _channel.morph(target, _still ? Duration.zero : Motion.long);
    _window = target;
    _morphing = false;
    if (mounted) setState(() {});
  }

  /// «—»: круг на том же месте, в углу стикера у ближнего края экрана.
  Future<void> _fold() async {
    final window = _window;
    if (window == null || _folded || _morphing) return;
    final circle = circleOf(window.topLeft, _screen);
    final target = Rect.fromLTWH(circle.dx, circle.dy, circleSize, circleSize);
    setState(() {
      _folded = true;
      _height = window.height;
      _anchor = _anchorOf(window, target);
    });
    await _morph(target);
  }

  /// Касание круга: стикер раскрывается туда, где есть место.
  Future<void> _unfold() async {
    final window = _window;
    if (window == null || !_folded || _morphing) return;
    final at = stickerOf(window.topLeft, _height, _screen);
    final target = Rect.fromLTWH(at.dx, at.dy, stickerWidth, _height);
    setState(() {
      _folded = false;
      _anchor = _anchorOf(target, window);
    });
    await _morph(target);
  }

  /// Замок: содержимое пропадает сразу, окно уходит.
  bool _locked = false;

  void _lock() {
    if (_locked) return;
    _locked = true;
    _removing = true;
    if (mounted) setState(() {});
    _channel.remove().ignore();
  }

  void _remove() {
    if (_removing) return;
    _removing = true;
    if (_still) {
      _channel.remove().ignore();
      return;
    }
    _leave.forward().then((_) => _channel.remove()).ignore();
  }

  @override
  Widget build(BuildContext context) {
    if (_locked) return const Scaffold(backgroundColor: Colors.transparent);
    final full = ref.watch(itemProvider(widget.noteId)).value;
    final folders = ref.watch(foldersProvider).value ?? const <FolderCard>[];
    final item = full?.item;
    final folderId = item?.folderId;
    final color = folderId == null ? null : folders.where((folder) => folder.id == folderId).firstOrNull?.color;
    final lines = item == null ? const <NoteLine>[] : noteLinesUnderTitle(item.body, item.title);
    final left = lines.where((line) => line.done == false).length;
    final circleFill = color ?? Tokens.accent;

    // насколько стикер раскрыт: по ширине окна, которую ведёт Kotlin
    final width = MediaQuery.sizeOf(context).width;
    final open = ((width - circleSize) / (stickerWidth - circleSize)).clamp(0.0, 1.0);
    // текст гаснет в первой части сворачивания, число проступает в последней
    final textShown = Curves.easeOut.transform(((open - 0.55) / 0.45).clamp(0.0, 1.0));
    final faceShown = ((0.45 - open) / 0.45).clamp(0.0, 1.0);
    if (!_folded && !_morphing) WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: Listenable.merge([_appear, _leave]),
        builder: (context, child) {
          final appear = Motion.emphasizedDecelerate.transform(_appear.value);
          final leave = Motion.emphasizedAccelerate.transform(_leave.value);
          return Opacity(
            opacity: (appear * (1 - leave)).clamp(0.0, 1.0),
            child: Transform.scale(scale: (0.92 + 0.08 * appear) * (1 - 0.1 * leave), alignment: _anchor, child: child),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(lerpDouble(circleSize / 2, _stickerRadius, open)!),
          child: ColoredBox(
            color: Color.lerp(circleFill, color == null ? Tokens.container : FolderPalette.tint(color), open)!,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (textShown > 0 && item != null)
                  Opacity(
                    opacity: textShown,
                    // текст во всю ширину стикера, окно его только обрезает: при сворачивании
                    // строки не переливаются, а уходят за край вместе с окном
                    child: OverflowBox(
                      alignment: _anchor,
                      minWidth: stickerWidth,
                      maxWidth: stickerWidth,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: KeyedSubtree(
                        key: _content,
                        child: _Card(
                          noteId: widget.noteId,
                          title: shownTitle(item.title),
                          body: item.body,
                          lines: lines,
                          onFold: _fold,
                          onRemove: _remove,
                          onOpen: () => _channel.openApp(widget.noteId).ignore(),
                        ),
                      ),
                    ),
                  ),
                if (faceShown > 0)
                  Opacity(
                    opacity: faceShown,
                    child: GestureDetector(
                      key: const ValueKey('sticker-circle'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _unfold,
                      child: Center(
                        child: left > 0
                            ? Text('$left', style: Theme.of(context).textTheme.titleMedium!.copyWith(color: inkOn(circleFill), fontWeight: FontWeight.w700))
                            : Icon(symbolIcon('sticky_note_2', filled: true), size: 22, color: inkOn(circleFill)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Раскрытый стикер: заголовок, «—» и «×», пункты с галочками или строки текста.
class _Card extends ConsumerWidget {
  const _Card({
    required this.noteId,
    required this.title,
    required this.body,
    required this.lines,
    required this.onFold,
    required this.onRemove,
    required this.onOpen,
  });

  final String noteId;
  final String title;
  final String body;
  final List<NoteLine> lines;
  final VoidCallback onFold;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final shown = lines.take(_linesOnSticker).toList();
    final rest = lines.length - shown.length;

    void toggle(int line) {
      final next = toggleCheckLine(body, line);
      if (next != body) ref.read(itemsRepositoryProvider).setBody(noteId, next, ref.read(clockProvider)()).ignore();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onOpen,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: Tokens.onSurface)),
                  ),
                ),
              ),
              _Mini(icon: 'remove', tooltip: l.fullCollapse, onTap: onFold),
              _Mini(icon: 'close', tooltip: l.edgeUnstick, onTap: onRemove),
            ],
          ),
          for (final line in shown)
            if (line.done case final done?)
              _Check(key: ValueKey('sticker-check-${line.index}'), text: renderMarkup(line.text, const []).text, done: done, onTap: () => toggle(line.index))
            else
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(renderMarkup(line.text, const []).text, maxLines: 3, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
              ),
          if (rest > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l.homeMoreLines(rest), style: text.labelMedium!.copyWith(color: Tokens.muted)),
            ),
        ],
      ),
    );
  }
}

/// Пункт списка: кружок заливается и строка зачёркивается за `short`, как на главной.
class _Check extends StatelessWidget {
  const _Check({super.key, required this.text, required this.done, required this.onTap});

  final String text;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, right: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: Motion.short,
              curve: Motion.emphasized,
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? Tokens.onSurface : Colors.transparent,
                border: Border.all(color: done ? Tokens.onSurface : Tokens.muted, width: 1.6),
              ),
              child: done ? Icon(symbolIcon('check'), size: 14, color: inkOn(Tokens.onSurface)) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: Motion.short,
                style: style.copyWith(
                  color: done ? Tokens.muted : Tokens.onSurface,
                  decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: Tokens.muted,
                ),
                child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Маленькая круглая кнопка в шапке стикера.
class _Mini extends StatelessWidget {
  const _Mini({required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.88,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(child: Icon(symbolIcon(icon), size: 20, color: Tokens.onSurfaceVariant)),
        ),
      ),
    );
  }
}
