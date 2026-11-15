import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/theme/app_theme.dart' show bodyFont;
import '../../core/theme/tokens.dart';
import '../../core/widgets/file_picture.dart';
import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/excalidraw.dart';
import '../../l10n/app_localizations.dart';
import '../../services/vault/vault_layout.dart';
import '../folder/folder_sheets.dart' show showRenameSheet;
import 'excalidraw_painter.dart';

/// Рисунок Excalidraw из Obsidian: лист с рисунком, щипком крупнее, двойным касанием —
/// целиком. Только просмотр: рисунок правится в Obsidian, Stowa файл не переписывает.
class DrawingScreen extends ConsumerStatefulWidget {
  const DrawingScreen({super.key, required this.item});

  final Item item;

  @override
  ConsumerState<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends ConsumerState<DrawingScreen> {
  final _transform = TransformationController();
  var _viewport = Size.zero;
  var _fitted = false;
  late ExcalidrawScene? _scene;
  late List<String> _texts;
  late String _source;

  /// Картинки рисунка: номер файла → полный путь; ищутся по имени, как в Obsidian.
  Map<String, String> _images = const {};

  /// Готовая картинка рисунка рядом с ним («Имя.excalidraw.svg»), если свой разбор не вышел.
  String? _export;

  // поля рисунка вокруг нарисованного
  static const _margin = 48.0;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(DrawingScreen old) {
    super.didUpdateWidget(old);
    // правка в Obsidian приехала: рисунок перечитывается, масштаб остаётся
    if ((widget.item.document ?? '') != _source) setState(_read);
  }

  void _read() {
    _source = widget.item.document ?? '';
    _scene = parseExcalidraw(_source);
    _texts = excalidrawTexts(_source);
    _findFiles();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _findFiles() async {
    final root = ref.read(filesRootProvider);
    final path = await ref.read(documentsRepositoryProvider).pathOf(widget.item.id);
    final near = path == null ? '' : p.posix.dirname(path);
    final wanted = _scene?.files ?? const {};
    final found = <String, String>{};
    for (final MapEntry(key: id, value: name) in wanted.entries) {
      if (await findVaultFile(root, name, near: near) case final file?) found[id] = file;
    }
    String? export;
    if (_scene == null && path != null) {
      final stem = excalidrawTitle(p.posix.basename(path));
      for (final candidate in ['$near/$stem.excalidraw.svg', '$near/$stem.excalidraw.png', '$near/$stem.svg', '$near/$stem.png']) {
        final full = vaultAbsolute(root.path, candidate.startsWith('./') ? candidate.substring(2) : candidate);
        if (await File(full).exists()) {
          export = full;
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _images = found;
      _export = export;
    });
  }

  ({double left, double top, double right, double bottom}) get _bounds {
    final box = _scene?.bounds ?? (left: 0.0, top: 0.0, right: 400.0, bottom: 300.0);
    return (left: box.left - _margin, top: box.top - _margin, right: box.right + _margin, bottom: box.bottom + _margin);
  }

  void _fit() {
    if (_viewport.isEmpty) return;
    final box = _bounds;
    final width = box.right - box.left, height = box.bottom - box.top;
    final scale = math.min(_viewport.width / width, _viewport.height / height).clamp(0.05, 3.0);
    final dx = (_viewport.width - width * scale) / 2;
    final dy = (_viewport.height - height * scale) / 2;
    // масштаб по трём осям, как у InteractiveViewer: иначе getMaxScaleOnAxis видит 1
    _transform.value = Matrix4.translationValues(dx, dy, 0) * Matrix4.diagonal3Values(scale, scale, scale);
  }

  Future<void> _rename() async {
    final name = await showRenameSheet(context, widget.item.title);
    if (name == null || name.trim().isEmpty) return;
    await ref.read(documentsRepositoryProvider).rename(widget.item.id, name.trim());
  }

  Future<void> _showTexts() async {
    final l = L.of(context);
    await showOptionsSheetWith<void>(
      context,
      (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), child: SheetTitle(l.drawingTexts)),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              itemCount: _texts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 2),
              itemBuilder: (context, index) => Material(
                color: Tokens.containerHigh,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(index == 0 ? 20 : 6),
                  bottom: Radius.circular(index == _texts.length - 1 ? 20 : 6),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('drawing-text-$index'),
                  // касание копирует подпись: формулу или адрес из схемы не перепечатывать
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _texts[index]));
                    Navigator.pop(sheet);
                    showNote(ScaffoldMessenger.of(context), l.drawingTextCopied);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Text(_texts[index], style: Theme.of(context).textTheme.bodyLarge),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final scene = _scene;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final box = _bounds;
    final size = Size(box.right - box.left, box.bottom - box.top);
    final origin = Offset(box.left, box.top);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 6),
              child: Row(
                children: [
                  _RoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.maybePop(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('drawing-title'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: _rename,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleLarge),
                          Text(_texts.isEmpty ? l.kindDrawing : '${l.kindDrawing} · ${l.drawingTextCount(_texts.length)}', style: text.bodySmall),
                        ],
                      ),
                    ),
                  ),
                  if (_texts.isNotEmpty) ...[
                    _RoundButton(key: const ValueKey('drawing-texts'), icon: 'notes', tooltip: l.drawingTexts, onTap: _showTexts),
                    const SizedBox(width: 6),
                  ],
                  if (scene != null) _RoundButton(icon: 'fit_screen', tooltip: l.canvasFit, onTap: _fit),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 10),
              child: Row(
                children: [
                  Icon(symbolIcon('draw'), size: 18, color: Tokens.muted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(scene == null ? l.drawingUnreadable : l.drawingEditInObsidian, style: text.bodySmall!.copyWith(color: Tokens.muted))),
                ],
              ),
            ),
            Expanded(
              child: scene == null
                  ? _Fallback(export: _export, texts: _texts)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        _viewport = constraints.biggest;
                        // первый показ — рисунок целиком: размер окна известен только здесь
                        if (!_fitted && !_viewport.isEmpty) {
                          _fitted = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _fit() : null);
                        }
                        Widget paper = CustomPaint(
                          size: size,
                          painter: ExcalidrawPainter(scene, origin: origin, fontFamily: bodyFont),
                        );
                        // лист в цвет рисунка; в тёмной теме лист и линии — тем же фильтром, что в Obsidian
                        Widget sheet = DecoratedBox(decoration: BoxDecoration(color: Color(scene.background), borderRadius: BorderRadius.circular(24)));
                        if (dark) {
                          paper = ColorFiltered(colorFilter: excalidrawDarkFilter, child: paper);
                          sheet = ColorFiltered(colorFilter: excalidrawDarkFilter, child: sheet);
                        }
                        return GestureDetector(
                          onDoubleTap: _fit,
                          child: ColoredBox(
                            color: Tokens.background,
                            child: InteractiveViewer(
                              key: const ValueKey('drawing-board'),
                              transformationController: _transform,
                              constrained: false,
                              minScale: 0.05,
                              maxScale: 12,
                              boundaryMargin: const EdgeInsets.all(double.infinity),
                              child: SizedBox.fromSize(
                                size: size,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(child: sheet),
                                    // картинки снизу, как их обычно и кладут: под стрелки и подписи
                                    for (final element in scene.elements)
                                      if (element.type == 'image' && _images[element.fileId] != null)
                                        Positioned(
                                          left: element.x - origin.dx,
                                          top: element.y - origin.dy,
                                          width: element.width,
                                          height: element.height,
                                          child: Transform.rotate(
                                            angle: element.angle,
                                            child: Opacity(
                                              opacity: element.opacity,
                                              child: FilePicture(File(_images[element.fileId]!), fit: BoxFit.fill),
                                            ),
                                          ),
                                        ),
                                    Positioned.fill(child: paper),
                                  ],
                                ),
                              ),
                            ),
                          ),
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

/// Свой разбор не вышел: готовая картинка рисунка из Obsidian или хотя бы его подписи.
class _Fallback extends StatelessWidget {
  const _Fallback({required this.export, required this.texts});

  final String? export;
  final List<String> texts;

  @override
  Widget build(BuildContext context) {
    final export = this.export;
    if (export != null) {
      return InteractiveViewer(maxScale: 8, child: Center(child: FilePicture(File(export), fit: BoxFit.contain)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.screen, 4, Space.screen, 24),
      children: [for (final one in texts) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(one, style: Theme.of(context).textTheme.bodyLarge))],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(symbolIcon(icon)),
    style: IconButton.styleFrom(backgroundColor: Tokens.containerHigh, fixedSize: const Size.square(44)),
  );
}

/// Файл хранилища по имени из `[[…]]`, как ищет Obsidian: путём от корня, рядом с
/// заметкой, потом где угодно в хранилище, кроме служебного. Нет — null.
Future<String?> findVaultFile(Directory root, String name, {String near = ''}) async {
  final clean = name.split('#').first.trim();
  for (final candidate in [clean, if (near.isNotEmpty && near != '.') '$near/$clean']) {
    final full = vaultAbsolute(root.path, candidate);
    if (await File(full).exists()) return full;
  }
  final wanted = p.posix.basename(clean).toLowerCase();
  if (!await root.exists()) return null;
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File || p.basename(entity.path).toLowerCase() != wanted) continue;
    final relative = p.relative(entity.path, from: root.path).split(p.separator).join('/');
    if (!isServicePath(relative)) return entity.path;
  }
  return null;
}
