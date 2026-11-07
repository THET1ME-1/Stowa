import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/repositories/highlights_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/article_text.dart';
import '../../domain/highlight_marks.dart';
import '../../l10n/app_localizations.dart';
import '../../services/vault/vault_layout.dart';

Route<void> readerRoute(String itemId, {String? highlightId}) => PageRouteBuilder(
  transitionDuration: Motion.long,
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => ReaderScreen(itemId: itemId, highlightId: highlightId),
  transitionsBuilder: (context, animation, secondary, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Motion.emphasizedDecelerate),
    child: SlideTransition(
      position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
      child: child,
    ),
  ),
);

/// Маркер цитаты: жёлтый, как у текстовыделителя; текст на нём тёмный.
final _marker = FolderPalette.colors['lemon']!;

/// Строка текста шире не читается: глаз теряет начало следующей.
const _measure = 680.0;

/// Читалка статьи из копии страницы: без сети, в шрифте и теме приложения.
/// Выделение делает цитату, касание цитаты — пометку; закрыл посреди — откроется там же.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.itemId, this.highlightId});

  final String itemId;

  /// Открыть сразу на этой цитате: касание цитаты на странице заметки.
  final String? highlightId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _scroll = ScrollController();
  final _progress = ValueNotifier(0.0);
  final _blockKeys = <int, GlobalKey>{};
  late final ItemsRepository _items = ref.read(itemsRepositoryProvider);
  late final HighlightsRepository _highlights = ref.read(highlightsRepositoryProvider);

  Article? _article;
  var _loading = true;
  Item? _item;
  SelectedContent? _selected;
  Timer? _save;
  var _placed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  Future<void> _load() async {
    final full = await ref.read(itemProvider(widget.itemId).future);
    final item = full?.item;
    if (item == null || !mounted) return;
    unawaited(_items.markOpened(item.id, ref.read(clockProvider)()));
    final article = await ref.read(articleLoaderProvider)(item.id, item.url ?? '');
    if (!mounted) return;
    setState(() {
      _item = item;
      _article = article;
      _loading = false;
    });
    if (article != null) WidgetsBinding.instance.addPostFrameCallback((_) => _place(item, article));
  }

  // открыть там, где остановился, или на цитате, по которой пришли
  void _place(Item item, Article article) {
    if (_placed || !mounted || !_scroll.hasClients) return;
    _placed = true;
    final target = widget.highlightId;
    if (target != null) {
      final highlight = (ref.read(highlightsProvider(item.id)).value ?? const <Highlight>[]).where((one) => one.id == target).firstOrNull;
      final index = highlight == null ? null : _blockOf(article, highlight.quote);
      final context = index == null ? null : _blockKeys[index]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(context, alignment: 0.2);
        return;
      }
    }
    final position = item.readPosition;
    if (position != null && position > 0) _scroll.jumpTo(position * _scroll.position.maxScrollExtent);
  }

  int? _blockOf(Article article, String quote) {
    final first = quote.split('\n').map((line) => line.trim()).firstWhere((line) => line.isNotEmpty, orElse: () => '');
    if (first.isEmpty) return null;
    for (final (index, block) in article.blocks.indexed) {
      if (block.text.contains(first)) return index;
    }
    return null;
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _progress.value = max <= 0 ? 1 : (_scroll.offset / max).clamp(0, 1).toDouble();
    _save?.cancel();
    _save = Timer(const Duration(seconds: 1), _savePosition);
  }

  void _savePosition() {
    final item = _item;
    if (item == null || _article == null) return;
    _items.setReadPosition(item.id, _progress.value).ignore();
  }

  @override
  void dispose() {
    _save?.cancel();
    _savePosition();
    _scroll.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _quote(SelectableRegionState region) async {
    final text = _selected?.plainText.trim() ?? '';
    region.hideToolbar();
    region.clearSelection();
    final article = _article;
    if (text.isEmpty || article == null) return;
    HapticFeedback.selectionClick();
    await _highlights.add(widget.itemId, text, position: quotePosition(article.plainText, text));
  }

  void _copy(SelectableRegionState region) {
    final text = _selected?.plainText ?? '';
    region.hideToolbar();
    region.clearSelection();
    if (text.isNotEmpty) Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _openHighlight(Highlight highlight) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<_HighlightAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(top: false, child: _HighlightSheet(highlight: highlight)),
      ),
    );
    if (action == null) return;
    switch (action) {
      case _SaveNote(:final note):
        await _highlights.setNote(highlight.id, note);
      case _Copy():
        await Clipboard.setData(ClipboardData(text: highlight.quote));
      case _Remove():
        final removed = await _highlights.remove(highlight.id);
        if (removed == null) return;
        showUndo(messenger, message: l.readerRemoved, label: l.undo, onUndo: () => _highlights.restore(removed));
    }
  }

  Future<void> _openOriginal() async {
    final url = Uri.tryParse(_item?.url ?? '');
    if (url != null) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final article = _article;
    final item = _item;
    final highlights = ref.watch(highlightsProvider(widget.itemId)).value ?? const <Highlight>[];
    // жива ли ссылка, проверка могла узнать, пока открыта читалка
    final gone = ref.watch(itemProvider(widget.itemId)).value?.item.goneAt != null;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen - 4, 6, Space.screen - 4, 6),
              child: Row(
                children: [
                  _TopButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.maybePop(context)),
                  const Spacer(),
                  if (item?.url != null) _TopButton(icon: 'open_in_new', tooltip: l.readerOriginal, onTap: _openOriginal),
                ],
              ),
            ),
            // сколько прочитано: тонкая полоска, а не цифры
            ValueListenableBuilder(
              valueListenable: _progress,
              builder: (context, value, _) => LinearProgressIndicator(value: article == null ? 0 : value, minHeight: 2, color: Tokens.accent, backgroundColor: Colors.transparent),
            ),
            Expanded(
              child: _loading
                  ? const SizedBox()
                  : article == null
                      ? _NoCopy(onOpen: item?.url == null ? null : _openOriginal)
                      : SelectionArea(
                          onSelectionChanged: (content) => _selected = content,
                          contextMenuBuilder: (context, region) => _SelectionBar(
                            anchors: region.contextMenuAnchors,
                            onQuote: () => _quote(region),
                            onCopy: () => _copy(region),
                          ),
                          child: SingleChildScrollView(
                            controller: _scroll,
                            padding: EdgeInsets.fromLTRB(22, 18, 22, 48 + MediaQuery.paddingOf(context).bottom),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: _measure),
                                child: _ArticleBody(
                                  article: article,
                                  gone: gone,
                                  title: article.title ?? item?.title ?? '',
                                  highlights: highlights,
                                  keyOf: (index) => _blockKeys[index] ??= GlobalKey(),
                                  imageOf: (index) => File(p.join(ref.read(filesRootProvider).path, articleImageFile(widget.itemId, index))),
                                  onHighlight: _openHighlight,
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleBody extends StatelessWidget {
  const _ArticleBody({
    required this.article,
    required this.gone,
    required this.title,
    required this.highlights,
    required this.keyOf,
    required this.imageOf,
    required this.onHighlight,
  });

  final Article article;
  final bool gone;
  final String title;
  final List<Highlight> highlights;
  final GlobalKey Function(int index) keyOf;
  final File Function(int index) imageOf;
  final void Function(Highlight highlight) onHighlight;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final byId = {for (final one in highlights) one.id: one};
    final quotes = [for (final one in highlights) (id: one.id, quote: one.quote)];
    final body = text.bodyLarge!.copyWith(fontSize: 17.5, height: 1.62, color: Tokens.onSurface);
    final date = article.published == null ? null : DateFormat.yMMMd(l.localeName).format(article.published!.toLocal());
    final meta = [?article.byline, ?date, l.readingMinutes(article.minutes)].join(' · ');

    // пометка видна под абзацем, где цитата кончается
    final notesAt = <int, List<Highlight>>{};
    for (final one in highlights) {
      if (one.note == null) continue;
      final last = one.quote.split('\n').map((line) => line.trim()).lastWhere((line) => line.isNotEmpty, orElse: () => '');
      final index = article.blocks.indexWhere((block) => last.isNotEmpty && block.text.contains(last));
      if (index >= 0) (notesAt[index] ??= []).add(one);
    }

    var images = 0;
    var number = 0;
    final children = <Widget>[];
    for (final (index, block) in article.blocks.indexed) {
      if (block.kind != ArticleBlockKind.item || !block.ordered) number = 0;
      Widget marked(TextStyle style) => _MarkedText(text: block.text, marks: marksIn(block.text, quotes), style: style, onTap: (id) => onHighlight(byId[id]!));
      final Widget child = switch (block.kind) {
        ArticleBlockKind.heading => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: marked(text.titleLarge!.copyWith(fontSize: block.level <= 2 ? 22 : 19, height: 1.3, fontWeight: FontWeight.w700, color: Tokens.onSurface)),
        ),
        ArticleBlockKind.paragraph => marked(body),
        ArticleBlockKind.quote => Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 18, 16),
          decoration: BoxDecoration(color: Tokens.containerLow, borderRadius: BorderRadius.circular(Radii.tile)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 3), child: Icon(symbolIcon('format_quote'), size: 20, color: Tokens.muted)),
              const SizedBox(width: 10),
              Expanded(child: marked(body.copyWith(fontStyle: FontStyle.italic, color: Tokens.onSurfaceVariant))),
            ],
          ),
        ),
        ArticleBlockKind.item => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 26, child: Text(block.ordered ? '${++number}.' : '•', style: body.copyWith(color: Tokens.muted))),
            Expanded(child: marked(body)),
          ],
        ),
        ArticleBlockKind.code => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Tokens.containerLowest, borderRadius: BorderRadius.circular(Radii.photo)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(block.text, style: TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.5, color: Tokens.onSurfaceVariant)),
          ),
        ),
        ArticleBlockKind.image => _ArticleImage(file: imageOf(images++), caption: block.text),
      };
      children.add(
        KeyedSubtree(
          key: keyOf(index),
          child: Padding(
            padding: EdgeInsets.only(bottom: block.kind == ArticleBlockKind.item ? 6 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                child,
                for (final one in notesAt[index] ?? const <Highlight>[]) _NoteLine(note: one.note!, onTap: () => onHighlight(one)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (article.site != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(article.site!, style: text.labelLarge!.copyWith(color: Tokens.muted, fontWeight: FontWeight.w600)),
          ),
        Text(title, style: text.headlineSmall!.copyWith(fontSize: 27, height: 1.2, letterSpacing: -0.5)),
        const SizedBox(height: 10),
        Text(meta, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
        if (gone) ...[
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
              decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(symbolIcon('link_off'), size: 18, color: Tokens.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Flexible(child: Text(l.readerGone, style: text.bodyMedium!.copyWith(color: Tokens.onSurface))),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 26),
        ...children,
      ],
    );
  }
}

/// Абзац с подсвеченными цитатами. Касание подсвеченного открывает пометку.
class _MarkedText extends StatefulWidget {
  const _MarkedText({required this.text, required this.marks, required this.style, required this.onTap});

  final String text;
  final List<HighlightMark> marks;
  final TextStyle style;
  final void Function(String id) onTap;

  @override
  State<_MarkedText> createState() => _MarkedTextState();
}

class _MarkedTextState extends State<_MarkedText> {
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final tap in _taps) {
      tap.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final tap in _taps) {
      tap.dispose();
    }
    _taps.clear();
    if (widget.marks.isEmpty) return Text(widget.text, style: widget.style);
    final spans = <InlineSpan>[];
    var at = 0;
    for (final mark in widget.marks) {
      if (mark.start > at) spans.add(TextSpan(text: widget.text.substring(at, mark.start)));
      final tap = TapGestureRecognizer()..onTap = () => widget.onTap(mark.id);
      _taps.add(tap);
      spans.add(TextSpan(text: widget.text.substring(mark.start, mark.end), style: TextStyle(backgroundColor: _marker, color: inkOn(_marker)), recognizer: tap));
      at = mark.end;
    }
    if (at < widget.text.length) spans.add(TextSpan(text: widget.text.substring(at)));
    return Text.rich(TextSpan(children: spans), key: const ValueKey('highlight-mark'), style: widget.style);
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.note, required this.onTap});

  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(symbolIcon('edit_note'), size: 18, color: FolderPalette.ink(_marker)),
              const SizedBox(width: 8),
              Expanded(child: Text(note, style: TextStyle(fontSize: 15, height: 1.45, color: Tokens.onSurfaceVariant))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Картинка статьи, если её скачали по Wi-Fi; иначе тонкая строка на её месте.
class _ArticleImage extends StatelessWidget {
  const _ArticleImage({required this.file, required this.caption});

  final File file;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final missing = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Tokens.containerLow, borderRadius: BorderRadius.circular(Radii.photo)),
      child: Row(
        children: [
          Icon(symbolIcon('image'), size: 18, color: Tokens.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(caption.isEmpty ? l.readerImageOff : caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Tokens.muted))),
        ],
      ),
    );
    if (!file.existsSync()) return missing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.photo),
          child: Image.file(
            file,
            fit: BoxFit.fitWidth,
            cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
            errorBuilder: (_, _, _) => missing,
          ),
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(caption, style: TextStyle(fontSize: 13, height: 1.4, color: Tokens.muted)),
          ),
      ],
    );
  }
}

class _NoCopy extends StatelessWidget {
  const _NoCopy({required this.onOpen});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(symbolIcon('chrome_reader_mode'), size: 36, color: Tokens.muted),
            const SizedBox(height: 14),
            Text(l.readerNoCopy, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.45, color: Tokens.onSurfaceVariant)),
            if (onOpen != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonal(onPressed: onOpen, child: Text(l.readerOriginal)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  const _TopButton({required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(backgroundColor: Tokens.containerHigh, fixedSize: const Size.square(44)),
      icon: Icon(symbolIcon(icon), size: 20, color: Tokens.onSurface),
    );
  }
}

/// Над выделением: круглые «Цитата» и «Копировать» на графитовой пилюле.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.anchors, required this.onQuote, required this.onCopy});

  final TextSelectionToolbarAnchors anchors;
  final VoidCallback onQuote;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return TextSelectionToolbar(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
      toolbarBuilder: (context, child) => Material(
        color: Tokens.containerHighest,
        borderRadius: BorderRadius.circular(32),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: const EdgeInsets.all(6), child: child),
      ),
      children: [
        _RoundAction(icon: 'format_quote', tooltip: l.readerQuote, onTap: onQuote, marker: true),
        const SizedBox(width: 6),
        _RoundAction(icon: 'content_copy', tooltip: l.readerCopy, onTap: onCopy),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.tooltip, required this.onTap, this.marker = false});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Главное действие — цветом маркера.
  final bool marker;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(backgroundColor: marker ? _marker : Tokens.graphite, fixedSize: const Size.square(44)),
      icon: Icon(symbolIcon(icon), size: 20, color: marker ? inkOn(_marker) : Tokens.onSurface),
    );
  }
}

sealed class _HighlightAction {
  const _HighlightAction();
}

class _SaveNote extends _HighlightAction {
  const _SaveNote(this.note);

  final String note;
}

class _Copy extends _HighlightAction {
  const _Copy();
}

class _Remove extends _HighlightAction {
  const _Remove();
}

/// Лист цитаты: сама цитата, пометка строкой, «Копировать» и «Убрать».
class _HighlightSheet extends StatefulWidget {
  const _HighlightSheet({required this.highlight});

  final Highlight highlight;

  @override
  State<_HighlightSheet> createState() => _HighlightSheetState();
}

class _HighlightSheetState extends State<_HighlightSheet> {
  late final _note = TextEditingController(text: widget.highlight.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // круглая кнопка с подписью: жать можно и по кругу, и по слову
    Widget action(String icon, String label, _HighlightAction value, {bool danger = false}) => InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
              child: Icon(symbolIcon(icon), size: 22, color: danger ? Tokens.error : Tokens.onSurface),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 13, color: danger ? Tokens.error : Tokens.onSurfaceVariant)),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: Text.rich(
                TextSpan(text: widget.highlight.quote, style: TextStyle(backgroundColor: _marker, color: inkOn(_marker))),
                style: const TextStyle(fontSize: 16, height: 1.55),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            autofocus: widget.highlight.note == null,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: l.readerNoteHint,
              prefixIcon: Icon(symbolIcon('edit_note'), color: Tokens.muted),
              filled: true,
              fillColor: Tokens.containerHigh,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              action('content_copy', l.readerCopy, const _Copy()),
              const SizedBox(width: 18),
              action('delete', l.readerRemove, const _Remove(), danger: true),
              const Spacer(),
              FilledButton(onPressed: () => Navigator.pop(context, _SaveNote(_note.text)), child: Text(l.save)),
            ],
          ),
        ],
      ),
    );
  }
}
