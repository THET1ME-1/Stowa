/// Текст статьи из копии страницы, в духе Readability и без ИИ: меню, шапка,
/// подвал, боковые колонки и реклама отбрасываются, остаются заголовки, абзацы,
/// цитаты, списки, код и картинки с подписями.
library;

import 'dart:math';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

enum ArticleBlockKind { heading, paragraph, quote, item, code, image }

class ArticleBlock {
  const ArticleBlock(this.kind, this.text, {this.level = 0, this.src, this.ordered = false});

  final ArticleBlockKind kind;

  /// Текст блока; у картинки — подпись, может быть пустой.
  final String text;

  /// Уровень подзаголовка: 2 у `<h2>`.
  final int level;

  /// Адрес картинки, уже полный.
  final String? src;

  /// Пункт нумерованного списка.
  final bool ordered;
}

class Article {
  const Article({required this.blocks, this.title, this.byline, this.site, this.published});

  final String? title;
  final String? byline;
  final String? site;
  final DateTime? published;
  final List<ArticleBlock> blocks;

  /// Текст без картинок: его ищет поиск, по нему находятся цитаты.
  String get plainText => [for (final block in blocks) if (block.kind != ArticleBlockKind.image) block.text].join('\n\n');

  int get words => _words(plainText);

  int get minutes => max(1, (words / wordsPerMinute).ceil());
}

const wordsPerMinute = 200;

/// Меньше читать в читалке незачем: хватает описания страницы.
const _minWords = 200;
const _minParagraphs = 3;

/// Абзац-мысль, а не подпись или анонс.
const _paragraphChars = 80;

/// В статье абзац в среднем от 12 слов; у главной сайта — анонсы по 5–8.
const _meanParagraphWords = 12;

const _junkTags = [
  'script', 'style', 'noscript', 'iframe', 'form', 'nav', 'header', 'footer', 'aside', 'svg', 'button', //
  'input', 'select', 'textarea', 'template', 'canvas', 'object', 'embed', 'dialog',
];

final _unlikely = RegExp(
  r'comment|share|sharing|social|related|promo|subscri|newsletter|cookie|consent|banner|popup|modal|sidebar|widget|advert|\bads?\b|sponsor|'
  r'footer|header|masthead|menu|\bnav|breadcrumb|pagination|pager|author-?bio|rating|recommend|read-?more|also|toolbar|teaser|'
  // служебное Википедии: врезки, навигация, сноски, «[править]»
  r'infobox|navbox|metadata|editsection|reference|reflist|hatnote|noprint|sistersitebox',
  caseSensitive: false,
);
final _likely = RegExp(r'article|\bbody|content|entry|main|post|story|text|blog', caseSensitive: false);

const _inlineTags = {
  'a', 'b', 'strong', 'em', 'i', 'u', 's', 'span', 'code', 'small', 'sup', 'sub', 'mark', 'abbr', 'time', 'cite', 'q', 'font', 'del', 'ins', 'kbd', 'var', 'label', //
};
const _blockTags = {
  'p', 'div', 'section', 'article', 'main', 'ul', 'ol', 'li', 'blockquote', 'pre', 'figure', 'table', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'img', 'picture', 'dl', //
};
final _blockSelector = _blockTags.join(',');

/// Статья из копии страницы; не статья (товар, страница входа, короткая заметка) — null.
Article? extractArticle(String html, Uri page) {
  final document = html_parser.parse(html);
  String? meta(String key) {
    for (final element in document.querySelectorAll('meta')) {
      final name = element.attributes['property'] ?? element.attributes['name'];
      final content = element.attributes['content']?.trim();
      if (name?.toLowerCase() == key && content != null && content.isNotEmpty) return content;
    }
    return null;
  }

  final title = meta('og:title') ?? _clean(document.querySelector('title')?.text ?? '').nullIfEmpty;
  final author = meta('author') ?? meta('article:author');
  final byline = author == null || author.startsWith('http') ? null : author;
  final site = meta('og:site_name');
  final published = DateTime.tryParse(meta('article:published_time') ?? '');

  final body = document.body;
  if (body == null) return null;
  for (final element in body.querySelectorAll(_junkTags.join(','))) {
    element.remove();
  }
  final total = body.text.length;
  for (final element in body.querySelectorAll('*').toList()) {
    if (element.parent == null) continue;
    final mark = '${element.className} ${element.id}';
    if (!_unlikely.hasMatch(mark) || _likely.hasMatch(mark)) continue;
    // обёртка всей страницы с классом «has-sidebar» — не мусор: в ней сам текст
    if (element.text.length > total / 2) continue;
    element.remove();
  }

  final roots = _bestRoot(body);
  if (roots.isEmpty) return null;
  final blocks = <ArticleBlock>[];
  final walker = _Walker(page, title, blocks);
  for (final root in roots) {
    roots.length == 1 ? walker.children(root) : walker.block(root);
  }
  final article = Article(blocks: blocks, title: title, byline: byline, site: site, published: published);
  // главная сайта — десятки коротких заголовков-анонсов: слов много, абзацев-мыслей нет
  final paragraphs = blocks.where((block) => block.kind == ArticleBlockKind.paragraph && block.text.length >= _paragraphChars).toList();
  final paragraphWords = paragraphs.fold(0, (sum, block) => sum + _words(block.text));
  final all = blocks.where((block) => block.kind == ArticleBlockKind.paragraph).toList();
  final meanWords = all.isEmpty ? 0 : all.fold(0, (sum, block) => sum + _words(block.text)) / all.length;
  if (article.words < _minWords || paragraphs.length < _minParagraphs || paragraphWords < article.words / 3 || meanWords < _meanParagraphWords) return null;
  return article;
}

// корень текста: родитель, у которого больше всего «настоящих» абзацев — длинных, с запятыми, без ссылок
List<Element> _bestRoot(Element body) {
  final scores = <Element, double>{};
  for (final candidate in body.querySelectorAll('p, pre, td, div')) {
    // у <div> считается только свой текст: абзацы без <p>, разделённые <br>
    final text = _clean(candidate.localName == 'div' ? _ownText(candidate) : candidate.text);
    if (text.length < 25) continue;
    final score = 1 + ','.allMatches(text).length + min(text.length / 100, 3);
    final parent = candidate.parent;
    if (parent == null) continue;
    scores[parent] = (scores[parent] ?? 0) + score;
    final grand = parent.parent;
    if (grand != null) scores[grand] = (scores[grand] ?? 0) + score / 2;
  }
  Element? best;
  var bestScore = 0.0;
  double weighted(Element element) => (scores[element] ?? 0) * (1 - _linkDensity(element));
  for (final element in scores.keys) {
    final score = weighted(element);
    if (score > bestScore) {
      best = element;
      bestScore = score;
    }
  }
  if (best == null) return const [];
  // лучший — один раздел из многих (вложенные <section> Википедии): подняться, пока выше заметно больше текста
  double paragraphText(Element element) =>
      element.querySelectorAll('p').where((paragraph) => _linkDensity(paragraph) < 0.5).fold(0.0, (sum, paragraph) => sum + _clean(paragraph.text).length);
  var own = paragraphText(best);
  // обёртки без своего текста (раздел внутри раздела) пропускаются: до трёх уровней подряд
  Element probe = best;
  var misses = 0;
  while (probe.parent != null && probe != body && misses < 3) {
    probe = probe.parent!;
    final above = paragraphText(probe);
    if (above > own * 1.3) {
      best = probe;
      own = above;
      bestScore = max(bestScore, weighted(probe));
      misses = 0;
    } else {
      misses++;
    }
  }
  final parent = best!.parent;
  if (parent == null || best == body) return [best];
  // статья, разбитая на разделы-соседи (Википедия): соседи с хорошим счётом идут вместе с лучшим
  final threshold = max(10, bestScore * 0.2);
  return [
    for (final sibling in parent.children)
      if (sibling == best || weighted(sibling) >= threshold || (sibling.localName == 'p' && _clean(sibling.text).length > 80 && _linkDensity(sibling) < 0.25)) sibling,
  ];
}

String _ownText(Element element) => [
  for (final node in element.nodes)
    if (node is Text) node.text else if (node is Element && _inlineTags.contains(node.localName)) node.text,
].join(' ');

double _linkDensity(Element element) {
  final text = element.text.length;
  if (text == 0) return 0;
  final links = element.querySelectorAll('a').fold(0, (sum, link) => sum + link.text.length);
  return links / text;
}

class _Walker {
  _Walker(this.page, this.title, this.blocks);

  final Uri page;
  final String? title;
  final List<ArticleBlock> blocks;

  void children(Element parent) {
    final buffer = StringBuffer();
    void flush() {
      // два <br> подряд — граница абзаца: так пишут старые сайты без <p>
      final parts = buffer.toString().split(RegExp(r'\n[ \t]*\n'));
      buffer.clear();
      for (final part in parts) {
        final text = _clean(part);
        if (text.isNotEmpty) blocks.add(ArticleBlock(ArticleBlockKind.paragraph, text));
      }
    }

    for (final node in parent.nodes) {
      if (node is Text) {
        buffer.write(_spaces(node.text));
      } else if (node is Element) {
        final tag = node.localName;
        if (tag == 'br') {
          buffer.write('\n');
        } else if (_inlineTags.contains(tag) && node.querySelector(_blockSelector) == null) {
          buffer.write(_textOf(node));
        } else {
          flush();
          block(node);
        }
      }
    }
    flush();
  }

  void block(Element element) {
    final tag = element.localName ?? '';
    switch (tag) {
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        final text = _clean(_textOf(element));
        // заголовок статьи уже стоит над текстом
        if (text.isEmpty || _same(text, title)) return;
        blocks.add(ArticleBlock(ArticleBlockKind.heading, text, level: int.parse(tag.substring(1))));
      case 'p':
        // абзац из одних ссылок — кусок меню или «читайте также»
        if (_linkDensity(element) > 0.5 && element.text.length < 300) return;
        children(element);
      case 'ul' || 'ol':
        for (final item in element.children.where((child) => child.localName == 'li')) {
          final text = _clean(_textOf(item));
          if (text.isNotEmpty) blocks.add(ArticleBlock(ArticleBlockKind.item, text, ordered: tag == 'ol'));
        }
      case 'blockquote':
        final text = _clean(_textOf(element));
        if (text.isNotEmpty) blocks.add(ArticleBlock(ArticleBlockKind.quote, text));
      case 'pre':
        final text = element.text.trimRight().replaceFirst(RegExp(r'^\n+'), '');
        if (text.trim().isNotEmpty) blocks.add(ArticleBlock(ArticleBlockKind.code, text));
      case 'figure':
        final caption = _clean(_textOf(element.querySelector('figcaption') ?? Element.tag('span')));
        final image = element.querySelector('img');
        final src = image == null ? null : _imageSource(image);
        if (src != null) blocks.add(ArticleBlock(ArticleBlockKind.image, caption, src: src));
      case 'img':
        final src = _imageSource(element);
        if (src != null) blocks.add(ArticleBlock(ArticleBlockKind.image, _clean(element.attributes['alt'] ?? ''), src: src));
      case 'picture':
        final image = element.querySelector('img');
        if (image != null) block(image);
      case 'table':
        // таблица из ссылок — навигация, а не данные
        if (_linkDensity(element) > 0.5) return;
        for (final row in element.querySelectorAll('tr')) {
          final cells = [for (final cell in row.children) _clean(_textOf(cell))].where((cell) => cell.isNotEmpty);
          if (cells.isNotEmpty) blocks.add(ArticleBlock(ArticleBlockKind.paragraph, cells.join(' · ')));
        }
      case 'dl':
        children(element);
      default:
        if (_linkDensity(element) > 0.5 && element.text.length < 300 && !element.children.any((child) => child.localName == 'img')) return;
        children(element);
    }
  }

  // ленивые картинки держат адрес в data-*, а в src — прозрачную заглушку
  String? _imageSource(Element image) {
    final width = int.tryParse(image.attributes['width'] ?? '');
    final height = int.tryParse(image.attributes['height'] ?? '');
    // счётчики и иконки
    if ((width != null && width < 48) || (height != null && height < 48)) return null;
    final srcset = image.attributes['data-srcset'] ?? image.attributes['srcset'];
    final candidates = [
      image.attributes['data-src'],
      image.attributes['data-lazy-src'],
      image.attributes['data-original'],
      if (srcset != null) srcset.split(',').first.trim().split(' ').first,
      image.attributes['src'],
    ];
    for (final candidate in candidates) {
      if (candidate == null || candidate.trim().isEmpty || candidate.startsWith('data:')) continue;
      final uri = Uri.tryParse(candidate.trim());
      if (uri == null) continue;
      final full = page.resolveUri(uri);
      if (full.scheme == 'http' || full.scheme == 'https') return full.toString();
    }
    return null;
  }
}

// текст узла: перенос строки на <br> и на границе блоков
String _textOf(Node node) {
  final buffer = StringBuffer();
  void walk(Node current) {
    for (final child in current.nodes) {
      if (child is Text) {
        buffer.write(_spaces(child.text));
      } else if (child is Element) {
        if (child.localName == 'br') {
          buffer.write('\n');
          continue;
        }
        final block = _blockTags.contains(child.localName);
        if (block) buffer.write('\n');
        walk(child);
        if (block) buffer.write('\n');
      }
    }
  }

  walk(node);
  return buffer.toString();
}

// перенос строки в исходнике страницы — просто пробел; строку переносит только <br>
String _spaces(String text) => text.replaceAll(RegExp(r'\s+'), ' ');

// пробелы внутри строки — один, пустые строки уходят
String _clean(String text) => text
    .replaceAll(' ', ' ')
    .split('\n')
    .map((line) => line.replaceAll(RegExp(r'[ \t\r\f\v]+'), ' ').trim())
    .where((line) => line.isNotEmpty)
    .join('\n');

bool _same(String text, String? title) {
  if (title == null) return false;
  String plain(String value) => value.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');
  final heading = plain(text);
  final full = plain(title);
  // «Кофе без турки» в <h1> и «Кофе без турки — Блог» в <title>
  return heading.isNotEmpty && full.startsWith(heading);
}

int _words(String text) => RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(text).length;

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
