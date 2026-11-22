import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/fs/web_files.dart' show openInBrowser;
import '../../core/icons/icon_registry.dart';
import '../../core/platform.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/desk_mode.dart';
import '../../core/widgets/file_picture.dart';
import '../../core/widgets/undo_snack.dart';
import '../../l10n/app_localizations.dart';

/// Метка перелёта фото со страницы вещи в просмотр.
String photoHeroTag(String path) => 'photo:$path';

/// Сколько протянуть вниз, чтобы просмотр закрылся.
const _dismissDistance = 120.0;

/// Куда сохраняется снимок: телефон кладёт в галерею, браузер скачивает файлом,
/// компьютер спрашивает папку.
enum _SaveTarget { gallery, download, file }

_SaveTarget get _saveTarget => isAndroid || isIOS ? _SaveTarget.gallery : (isWeb ? _SaveTarget.download : _SaveTarget.file);

/// Просмотр фото во весь экран: листание, щипок и двойное касание приближают,
/// смахивание вниз закрывает, одно касание прячет и возвращает кнопки.
///
/// На мониторе — поверх всего окна, вместе с вкладками и общей строкой: кнопки небольшие
/// посередине, листают стрелки по бокам и клавиши ← →, Esc закрывает. «Поделиться» есть
/// только на телефоне: браузер и компьютер файл системе не передают.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.paths, this.initial = 0, this.desk = false});

  /// Полные пути к снимкам.
  final List<String> paths;
  final int initial;

  /// Открыт на мониторе.
  final bool desk;

  static Future<void> open(BuildContext context, List<String> paths, int initial) {
    // монитор: окно над оболочкой, а не страница во вкладке — иначе снизу налезает общая
    // строка, а сверху остаются вкладки. Окно, не страница: перелёт снимка между навигаторами
    // вкладки и окна не нужен, а одинаковая метка в двух вкладках ломала бы его
    if (DeskMode.of(context)) {
      return showGeneralDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        transitionDuration: Motion.medium,
        pageBuilder: (_, _, _) => PhotoViewer(paths: paths, initial: initial, desk: true),
        transitionBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      );
    }
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: Motion.medium,
        reverseTransitionDuration: Motion.medium,
        pageBuilder: (_, _, _) => PhotoViewer(paths: paths, initial: initial),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  bool _chrome = true;
  bool _zoomed = false;
  double _drag = 0;

  // плашка поверх просмотра на мониторе: общие плашки там живут у строки, а её закрывает просмотр
  String? _notice;
  Timer? _noticeTimer;

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _tell(String message) {
    if (!widget.desk) {
      showNote(ScaffoldMessenger.of(context), message, overDock: true);
      return;
    }
    _noticeTimer?.cancel();
    setState(() => _notice = message);
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  Future<void> _save() async {
    final l = L.of(context);
    final path = widget.paths[_index];
    // у вложения в начале имени номер места: «0_лампа.jpg» — человеку он ни к чему
    final name = p.basename(path).replaceFirst(RegExp(r'^\d+_'), '');
    final mime = lookupMimeType(path) ?? 'application/octet-stream';
    switch (_saveTarget) {
      case _SaveTarget.gallery:
        try {
          await PhotoManager.editor.saveImageWithPath(path, title: name, relativePath: 'Pictures/Stowa');
          _tell(l.photoSaved);
        } catch (_) {
          _tell(l.photoSaveFailed);
        }
      case _SaveTarget.download:
        try {
          // браузер сам показывает скачанное — своей плашки не нужно
          openInBrowser(await File(path).readAsBytes(), name: name, mime: mime, view: false);
        } catch (_) {
          _tell(l.photoFileFailed);
        }
      case _SaveTarget.file:
        try {
          await FilePicker.saveFile(fileName: name, bytes: await File(path).readAsBytes(), mimeType: mime);
        } catch (_) {
          _tell(l.photoFileFailed);
        }
    }
  }

  Future<void> _share() async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(widget.paths[_index])],
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  void _go(int index) {
    if (index < 0 || index >= widget.paths.length || index == _index) return;
    _pages.animateToPage(index, duration: Motion.medium, curve: Motion.emphasized);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        Navigator.of(context).pop();
      case LogicalKeyboardKey.arrowLeft:
        _go(_index - 1);
      case LogicalKeyboardKey.arrowRight:
        _go(_index + 1);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  String get _saveLabel {
    final l = L.of(context);
    return switch (_saveTarget) {
      _SaveTarget.gallery => l.photoToGallery,
      _SaveTarget.download => l.photoDownload,
      _SaveTarget.file => l.photoSaveAs,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final count = widget.paths.length;
    final desk = widget.desk;
    // протянули вниз — фон бледнеет, отпустили дальше порога — просмотр закрывается
    final fade = (1 - _drag.abs() / 400).clamp(0.3, 1.0);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top;
    final canShare = isAndroid || isIOS;
    final save = desk
        ? Material(
            key: const ValueKey('photo-save'),
            color: Tokens.accent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(symbolIcon('download'), size: 20, color: Tokens.onAccent),
                      const SizedBox(width: 8),
                      Text(_saveLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Tokens.onAccent)),
                    ],
                  ),
                ),
              ),
            ),
          )
        : Material(
            key: const ValueKey('photo-save'),
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
                    Text(_saveLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Tokens.onAccent)),
                  ],
                ),
              ),
            ),
          );
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
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
                            child: Text(l.photoCounter(count, _index + 1), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Tokens.onSurface)),
                          ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  // монитор: листают стрелки по бокам, мышью страницу не тянут
                  if (desk && _index > 0)
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(child: _GlassButton(icon: 'chevron_left', tooltip: l.photoPrevious, onTap: () => _go(_index - 1), size: 52)),
                    ),
                  if (desk && _index < count - 1)
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(child: _GlassButton(icon: 'chevron_right', tooltip: l.photoNext, onTap: () => _go(_index + 1), size: 52)),
                    ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: bottom + (desk ? 24 : 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_notice case final notice?) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(20)),
                            child: Text(notice, style: TextStyle(fontSize: 14, color: Tokens.onSurface)),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (count > 1) ...[
                          _Strip(paths: widget.paths, selected: _index, onPick: _go),
                          const SizedBox(height: 14),
                        ],
                        if (desk)
                          save
                        else
                          Row(
                            children: [
                              if (canShare) ...[
                                _GlassButton(icon: 'share', tooltip: l.itemShare, onTap: _share, size: 64),
                                const SizedBox(width: 10),
                              ],
                              Expanded(child: save),
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
                    child: FilePicture(File(paths[index]), fit: BoxFit.cover, cacheWidth: cache),
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
            child: FilePicture(File(widget.path), fit: BoxFit.contain, width: double.infinity, height: double.infinity),
          ),
        ),
      ),
    );
  }
}
