import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../l10n/app_localizations.dart';

/// Метка перелёта фото со страницы вещи в просмотр.
String photoHeroTag(String path) => 'photo:$path';

/// Сколько протянуть вниз, чтобы просмотр закрылся.
const _dismissDistance = 120.0;

/// Просмотр фото во весь экран: листание, щипок и двойное касание приближают,
/// смахивание вниз закрывает, одно касание прячет и возвращает кнопки.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.paths, this.initial = 0});

  /// Полные пути к снимкам.
  final List<String> paths;
  final int initial;

  static Future<void> open(BuildContext context, List<String> paths, int initial) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: Motion.medium,
      reverseTransitionDuration: Motion.medium,
      pageBuilder: (_, _, _) => PhotoViewer(paths: paths, initial: initial),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  );

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  bool _chrome = true;
  bool _zoomed = false;
  double _drag = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final path = widget.paths[_index];
    try {
      await PhotoManager.editor.saveImageWithPath(path, title: p.basename(path), relativePath: 'Pictures/Stowa');
      showNote(messenger, l.photoSaved, overDock: true);
    } catch (_) {
      showNote(messenger, l.photoSaveFailed, overDock: true);
    }
  }

  Future<void> _share() async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(widget.paths[_index])],
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final count = widget.paths.length;
    // протянули вниз — фон бледнеет, отпустили дальше порога — просмотр закрывается
    final fade = (1 - _drag.abs() / 400).clamp(0.3, 1.0);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: fade),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _chrome = !_chrome),
            onVerticalDragUpdate: _zoomed ? null : (details) => setState(() => _drag += details.delta.dy),
            onVerticalDragEnd: _zoomed
                ? null
                : (details) {
                    if (_drag.abs() > _dismissDistance || (details.primaryVelocity ?? 0).abs() > 900) {
                      Navigator.of(context).pop();
                    } else {
                      setState(() => _drag = 0);
                    }
                  },
            child: AnimatedContainer(
              duration: _drag == 0 ? Motion.short : Duration.zero,
              transform: Matrix4.translationValues(0, _drag, 0),
              child: PageView.builder(
                controller: _pages,
                physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                itemCount: count,
                onPageChanged: (index) => setState(() {
                  _index = index;
                  _zoomed = false;
                }),
                itemBuilder: (context, index) => _ZoomablePhoto(
                  path: widget.paths[index],
                  onZoomChanged: (zoomed) {
                    if (index == _index && zoomed != _zoomed) setState(() => _zoomed = zoomed);
                  },
                ),
              ),
            ),
          ),
          // кнопки уезжают вместе с касанием и пока фото тянут вниз
          AnimatedOpacity(
            duration: Motion.short,
            opacity: _chrome && _drag == 0 ? 1 : 0,
            child: IgnorePointer(
              ignoring: !_chrome || _drag != 0,
              child: Stack(
                children: [
                  Positioned(
                    left: 10,
                    right: 10,
                    top: top + 10,
                    child: Row(
                      children: [
                        _GlassButton(icon: 'close', tooltip: l.photoClose, onTap: () => Navigator.of(context).pop()),
                        const Spacer(),
                        if (count > 1)
                          Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Tokens.containerHigh.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(18)),
                            child: Text(l.photoCounter(count, _index + 1), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Tokens.onSurface)),
                          ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: bottom + 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (count > 1) ...[
                          _Strip(paths: widget.paths, selected: _index, onPick: (index) => _pages.animateToPage(index, duration: Motion.medium, curve: Motion.emphasized)),
                          const SizedBox(height: 14),
                        ],
                        Row(
                          children: [
                            _GlassButton(icon: 'share', tooltip: l.itemShare, onTap: _share, size: 64),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Material(
                                color: Tokens.accent,
                                borderRadius: BorderRadius.circular(32),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: _save,
                                  child: SizedBox(
                                    height: 64,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(symbolIcon('download'), size: 22, color: Tokens.onAccent),
                                        const SizedBox(width: 8),
                                        Text(l.photoToGallery, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Tokens.onAccent)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Круглая кнопка поверх фото: полупрозрачная подложка, чтобы читалась на любом кадре.
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.tooltip, required this.onTap, this.size = 48});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Tokens.containerHigh.withValues(alpha: 0.82),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(dimension: size, child: Icon(symbolIcon(icon), size: 22, color: Tokens.onSurface)),
        ),
      ),
    );
  }
}

/// Лента снимков внизу: текущий светлее и в рамке.
class _Strip extends StatelessWidget {
  const _Strip({required this.paths, required this.selected, required this.onPick});

  final List<String> paths;
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final cache = (44 * MediaQuery.devicePixelRatioOf(context)).round();
    return SizedBox(
      height: 48,
      child: Center(
        child: ListView.separated(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          itemCount: paths.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final current = index == selected;
            return GestureDetector(
              onTap: () => onPick(index),
              child: AnimatedContainer(
                duration: Motion.short,
                width: 44,
                height: 44,
                padding: EdgeInsets.all(current ? 2 : 0),
                decoration: BoxDecoration(color: current ? Tokens.accent : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                child: AnimatedOpacity(
                  duration: Motion.short,
                  opacity: current ? 1 : 0.5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(current ? 12 : 14),
                    child: Image.file(File(paths[index]), fit: BoxFit.cover, cacheWidth: cache),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Один снимок: щипок до пяти раз, двойное касание приближает туда, куда ткнули.
class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({required this.path, required this.onZoomChanged});

  final String path;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final _animation = AnimationController(vsync: this, duration: Motion.medium);
  Animation<Matrix4>? _zoom;
  Offset _tap = Offset.zero;

  @override
  void initState() {
    super.initState();
    _animation.addListener(() {
      final zoom = _zoom;
      if (zoom != null) _transform.value = zoom.value;
    });
    _transform.addListener(() => widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01));
  }

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    const scale = 2.5;
    final target = zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..translateByDouble(-_tap.dx * (scale - 1), -_tap.dy * (scale - 1), 0, 1)
          ..scaleByDouble(scale, scale, 1, 1));
    _zoom = Matrix4Tween(begin: _transform.value, end: target).animate(CurvedAnimation(parent: _animation, curve: Motion.emphasized));
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _tap = details.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        maxScale: 5,
        child: Center(
          child: Hero(
            tag: photoHeroTag(widget.path),
            child: Image.file(File(widget.path), fit: BoxFit.contain, width: double.infinity, height: double.infinity),
          ),
        ),
      ),
    );
  }
}
