import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/fs/web_files.dart' show openInBrowser;
import '../../core/icons/icon_registry.dart';
import '../../core/platform.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/undo_snack.dart';
import '../../l10n/app_localizations.dart';
import 'item_media.dart' show fileTitle, openLocalFile;

enum _PdfAction { full, open, save }

/// Просмотр PDF как в Obsidian (хозяин 22.11: «предосмотр и управление PDF из приложения,
/// как в Obsidian»): страницы листаются внутри рамки, сверху панель — миниатюры страниц,
/// «мельче» и «крупнее», номер страницы «1 из 21» и «Ещё»: на весь экран, открыть программой
/// (в браузере — вкладкой), скачать или сохранить как. В заметке — рамкой своей высоты на
/// месте вставки `![[…pdf]]` или вместо строки приложенного файла; [full] — на весь экран.
///
/// Страницы рисует PDFium (пакет pdfrx): на телефоне и компьютере файл читается с диска, в
/// браузере — байтами из хранилища страницы.
class PdfPanel extends StatefulWidget {
  const PdfPanel({super.key, required this.path, this.mime = 'application/pdf', this.full = false});

  /// Полный путь к файлу.
  final String path;
  final String mime;
  final bool full;

  /// Просмотр на весь экран.
  static Future<void> open(BuildContext context, String path, {String mime = 'application/pdf'}) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => _PdfScreen(path: path, mime: mime)),
  );

  @override
  State<PdfPanel> createState() => _PdfPanelState();
}

class _PdfPanelState extends State<PdfPanel> {
  final _controller = PdfViewerController();
  final _pageField = TextEditingController(text: '1');
  final _pageFocus = FocusNode();
  PdfDocument? _document;
  int _page = 1;
  bool _thumbs = false;

  // в браузере файла на диске нет: байты из хранилища страницы
  late final Future<Uint8List>? _bytes = isWeb ? File(widget.path).readAsBytes() : null;

  @override
  void initState() {
    super.initState();
    // на широком экране во весь экран миниатюры сразу видны, как в Obsidian
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.full && MediaQuery.sizeOf(context).width >= 900) setState(() => _thumbs = true);
    });
  }

  @override
  void dispose() {
    _pageField.dispose();
    _pageFocus.dispose();
    super.dispose();
  }

  int get _count => _document?.pages.length ?? 0;

  void _goTo(int page) {
    if (!_controller.isReady || _count == 0) return;
    final target = page.clamp(1, _count);
    _controller.goToPage(pageNumber: target).ignore();
    setState(() => _page = target);
    _pageField.text = '$target';
  }

  Future<void> _menu() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final action = await showOptionsSheet<_PdfAction>(
      context,
      title: fileTitle(widget.path),
      options: [
        if (!widget.full) SheetChoice(value: _PdfAction.full, title: l.pdfFullScreen, icon: 'open_in_full'),
        SheetChoice(value: _PdfAction.open, title: isWeb ? l.pdfOpenBrowser : l.pdfOpenApp, icon: 'open_in_new'),
        // на телефоне сохраняет «Открыть в программе» и «Поделиться» самой системы
        if (isWeb) SheetChoice(value: _PdfAction.save, title: l.photoDownload, icon: 'download'),
        if (!isWeb && !isAndroid && !isIOS) SheetChoice(value: _PdfAction.save, title: l.photoSaveAs, icon: 'download'),
      ],
    );
    if (action == null || !mounted) return;
    final name = fileTitle(widget.path);
    switch (action) {
      case _PdfAction.full:
        await PdfPanel.open(context, widget.path, mime: widget.mime);
      case _PdfAction.open:
        await openLocalFile(context, widget.path, widget.mime);
      case _PdfAction.save:
        try {
          final bytes = await File(widget.path).readAsBytes();
          if (isWeb) {
            openInBrowser(bytes, name: name, mime: widget.mime, view: false);
          } else {
            await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: widget.mime);
          }
        } catch (_) {
          showNote(messenger, l.photoFileFailed, overDock: true);
        }
    }
  }

  Widget _viewer(L l) {
    final params = PdfViewerParams(
      backgroundColor: Tokens.containerLowest,
      margin: 8,
      // без теней, как всё в Stowa
      pageDropShadow: null,
      onViewerReady: (document, controller) {
        if (!mounted) return;
        setState(() {
          _document = document;
          _page = controller.pageNumber ?? 1;
        });
        _pageField.text = '$_page';
      },
      onPageChanged: (page) {
        if (page == null || !mounted) return;
        setState(() => _page = page);
        if (!_pageFocus.hasFocus) _pageField.text = '$page';
      },
      loadingBannerBuilder: (context, _, _) => Center(child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Tokens.muted))),
      errorBannerBuilder: (context, _, _, _) => _Failed(onOpen: () => openLocalFile(context, widget.path, widget.mime)),
    );
    final bytes = _bytes;
    if (bytes == null) return PdfViewer.file(widget.path, controller: _controller, params: params);
    return FutureBuilder<Uint8List>(
      future: bytes,
      builder: (context, snapshot) => switch (snapshot) {
        AsyncSnapshot(hasError: true) => _Failed(onOpen: () => openLocalFile(context, widget.path, widget.mime)),
        AsyncSnapshot(:final data?) => PdfViewer.data(data, sourceName: widget.path, controller: _controller, params: params),
        _ => Center(child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Tokens.muted))),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final document = _document;
    final toolbar = Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: Tokens.container, border: Border(bottom: BorderSide(color: Tokens.outline.withValues(alpha: 0.4)))),
      child: Row(
        children: [
          _Tool(icon: 'view_sidebar', tooltip: l.pdfPages, active: _thumbs, onTap: () => setState(() => _thumbs = !_thumbs)),
          const SizedBox(width: 4),
          _Tool(icon: 'zoom_out', tooltip: l.pdfZoomOut, onTap: () => _controller.isReady ? _controller.zoomDown().ignore() : null),
          _Tool(icon: 'zoom_in', tooltip: l.pdfZoomIn, onTap: () => _controller.isReady ? _controller.zoomUp().ignore() : null),
          const SizedBox(width: 8),
          Tooltip(
            message: l.pdfPage,
            child: SizedBox(
              width: 52,
              height: 34,
              child: TextField(
                key: const ValueKey('pdf-page'),
                controller: _pageField,
                focusNode: _pageFocus,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Tokens.onSurface, fontFeatures: const [FontFeature.tabularFigures()]),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  filled: true,
                  fillColor: Tokens.containerHigh,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onSubmitted: (value) => _goTo(int.tryParse(value) ?? _page),
                onTapOutside: (_) {
                  _pageFocus.unfocus();
                  _pageField.text = '$_page';
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_count > 0) Text(l.pdfPageOf(_count), style: TextStyle(fontSize: 14, color: Tokens.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(width: 12),
          Expanded(
            child: Text(fileTitle(widget.path), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: TextStyle(fontSize: 13, color: Tokens.muted)),
          ),
          const SizedBox(width: 4),
          _Tool(icon: 'more_vert', tooltip: l.itemMore, onTap: _menu),
        ],
      ),
    );
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_thumbs && document != null)
          SizedBox(
            width: 112,
            child: ColoredBox(
              color: Tokens.container,
              child: ListView.builder(
                key: const ValueKey('pdf-thumbs'),
                padding: const EdgeInsets.all(10),
                itemCount: document.pages.length,
                itemBuilder: (context, index) {
                  final page = document.pages[index];
                  final number = index + 1;
                  final current = number == _page;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => _goTo(number),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              border: Border.all(color: current ? Tokens.accent : Colors.transparent, width: 2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: AspectRatio(
                              aspectRatio: page.width / math.max(1, page.height),
                              child: PdfPageView(document: document, pageNumber: number, maximumDpi: 48),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('$number', style: TextStyle(fontSize: 12, color: current ? Tokens.onSurface : Tokens.muted)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        Expanded(child: _viewer(l)),
      ],
    );
    final frame = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [toolbar, Expanded(child: body)]);
    if (widget.full) return frame;
    // в заметке — рамка своей высоты; страницы листаются внутри
    final height = MediaQuery.sizeOf(context).width >= 900 ? 640.0 : math.min(460.0, MediaQuery.sizeOf(context).height * 0.62);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: Tokens.outline.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(18)),
          child: SizedBox(height: height, child: frame),
        ),
      ),
    );
  }
}

/// PDF на весь экран: «назад», имя файла и тот же просмотр.
class _PdfScreen extends StatelessWidget {
  const _PdfScreen({required this.path, required this.mime});

  final String path;
  final String mime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
              child: Row(
                children: [
                  _Tool(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.maybePop(context)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(fileTitle(path), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium)),
                ],
              ),
            ),
            Expanded(child: PdfPanel(path: path, mime: mime, full: true)),
          ],
        ),
      ),
    );
  }
}

/// PDF не открылся (битый, с паролем): сказать и дать открыть программой.
class _Failed extends StatelessWidget {
  const _Failed({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(symbolIcon('picture_as_pdf'), size: 32, color: Tokens.muted),
          const SizedBox(height: 8),
          Text(l.pdfFailed, style: TextStyle(fontSize: 14, color: Tokens.onSurfaceVariant)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onOpen, child: Text(isWeb ? l.pdfOpenBrowser : l.pdfOpenApp)),
        ],
      ),
    );
  }
}

/// Кнопка панели: значок с подсказкой, включённая — подсвечена.
class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.tooltip, required this.onTap, this.active = false});

  final String icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: active ? Tokens.containerHighest : null, borderRadius: BorderRadius.circular(10)),
          child: Icon(symbolIcon(icon), size: 20, color: active ? Tokens.onSurface : Tokens.onSurfaceVariant),
        ),
      ),
    );
  }
}
